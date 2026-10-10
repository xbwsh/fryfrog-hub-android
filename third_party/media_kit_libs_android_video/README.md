# 自编译 libmpv（Android arm64，带字体支持）

本目录存放**自行交叉编译**的 `libmpv.so`，用于修复 Android 端 ASS 特效字幕
渲染错乱的问题。产物是 `libs/libmpv-arm64-fontconfig.jar`。

---

## 一、为什么需要它

上游 `media_kit_libs_android_video` 的预编译 libmpv 在构建 **libass** 时传了：

```
--disable-require-system-font-provider
```

这等于**放弃系统字体发现能力**。用二进制核对过：旧 `libmpv.so` 里 fontconfig
的符号 `FcInit` / `FcFontMatch` / `FcConfigBuildFonts` **全部为 0**。

后果（实测《更衣人偶坠入爱河》EP1，内嵌 ASS 简体轨）：

* 该 ASS 用了 3892 处 `\fscx/\fscy`、4901 处 `\frz/\an9/\an10`（日式竖排特效）
* 字体是内嵌子集（`HYXuanSong 65S` 等私有字体），设备上没有
* libass 找不到字体 → 回退到匿名 fallback → **字幕被逐字竖排堆叠、描边特效全丢**

iOS 端正常是因为它自带完整的 freetype/fribidi/harfbuzz 链路。

---

## 二、改了什么

自编译版本相对上游只动两处：

| 位置 | 上游 | 本仓库 |
|---|---|---|
| `libass` configure | `--disable-require-system-font-provider` | **`--enable-fontconfig`** |
| `fontconfig` 构建 | （未参与） | **`-Ddefault-fonts-dirs=/system/fonts`** |

新增了 `expat` + `fontconfig` 两个交叉编译依赖，串进 `dep_libass`。

验证（新 `libmpv.so`）：

```
FcInit              x18      <- 旧版 x0
FcConfigBuildFonts   x3      <- 旧版 x0
FcFontMatch          x4      <- 旧版 x0
/system/fonts        x1      <- 默认字体目录（即使 Android 没有 /etc/fonts/fonts.conf）
ass_set_fonts        x2
FT_                  x399
```

---

## 三、换电脑 / 新克隆仓库后必做

**这一步不能省**，否则用的还是官方旧库。

```bash
flutter pub get                                  # 让 pub 解压出插件
python3 tools/patch_libmpv_jar.py                # 把自编译 jar 注入插件构建流程
flutter build apk --debug                        # 正常构建
```

脚本做的事：修改 `~/.pub-cache/.../media_kit_libs_android_video-1.3.8/android/build.gradle`，
让 **arm64-v8a** 从这个仓库的 `libs/` 取 jar（其余架构仍走官方下载）。
脚本幂等，可重复执行；原文件会备份成 `build.gradle.orig`。

> **注意**：这是对 pub cache 的修改，`flutter pub get` 不会还原。但
> **插件版本升级**（当前锁定 1.3.8）或 **pub cache 被清理**后需要重跑脚本。

验证是否生效：

```bash
# 构建后确认 APK 里的 arm64 库来自我们（大小约 10MB，官方是 12.4MB）
unzip -l build/app/outputs/flutter-apk/app-debug.apk | grep arm64-v8a/libmpv
```

---

## 四、重新编译 libmpv（一般不需要）

产物已提交，**正常开发无需重编**。只有要改编译选项时才需要。

`build-scripts/` 是构建脚本的存档（从
[media-kit/libmpv-android-video-build](https://github.com/media-kit/libmpv-android-video-build)
改造而来）。关键改动见 `build-scripts/build-inline.sh` 顶部注释与
`build-scripts/libass.sh`。

### 环境要求（macOS）

```bash
export PATH="/opt/homebrew/bin:$PATH"
brew install meson ninja pkg-config autoconf automake gnu-sed coreutils
# NDK：28.2.13676358（脚本里改过版本号，上游默认 25.2）
# 说明：只编 arm64 时 nasm / cmake 都不需要
```

### 踩过的坑（重编时注意）

1. **ffmpeg 的源码 `Makefile` 不能删** —— 它是构建系统的一部分，
   out-of-source 构建时 `_build/Makefile` 会 include 它。删掉会报
   `No rule to make target .../ffmpeg/Makefile`。
2. **GitHub 的 FFmpeg source archive 不含 `tests/`、各 `libav*/Makefile`、
   `libav*/version.h`**（被 `.gitattributes` 的 export-ignore 排除）。
   必须用 `git clone` 拿完整源码，否则 make 中途报缺文件。
3. **上游 `build.sh` 会把 configure 跑在错误目录**（报
   `cannot find input file: Makefile.in`），且用了 `sudo chmod`。
   所以改用自写的 `build-inline.sh`（每步都是绝对路径 + 显式 cwd）。
4. **meson 必须显式 `--prefix=/usr/local`**，否则会装到宿主机的
   homebrew 路径（`opt/homebrew/...`）。
5. `mbedtls` 需要 `-march=armv8-a+crypto`，否则 AES 代码报
   `requires target feature 'crypto'`。
6. 各库的 meson 选项名要核对 `meson_options.txt`：
   - `freetype` **没有** `docs` 选项
   - `harfbuzz` **没有** `fontconfig` 选项
   - `fontconfig` 是 `doc`（单数）不是 `docs`
7. 依赖源码可走代理拉取（本机 HTTP 代理不通时用 socks5：
   `curl --socks5-hostname 127.0.0.1:7897`，git 用 `-c http.proxy=socks5h://...`
   并配 `-c http.version=HTTP/1.1`）。

---

## 五、当前状态与遗留问题

**已完成**：编译、打包、注入流程全部打通，APK 内的 arm64 `libmpv.so`
经符号核验确实带 fontconfig 与 `/system/fonts`。

**对照实验（已完成，结论有效）**：用**官方 libmpv** 的 APK 播放同一集，
**复现了竖排堆叠现象**。这证实：用户报告的问题真实存在，根因分析指向正确。

**未完成**：自编译版的实机画面对比验证。测试中播放失败，抓到的错误是
`Failed to open <stream url>`，而该 URL 用 curl 复测返回 `401 Unauthorized`
（同一时刻通过 API 重新获取的 URL 返回 206 正常）。**判断是签名 URL 过期/
失效，与本 libmpv 修改无关。**

**下一步**：装自编译版后重跑同样的播放路径，确认字幕变为正常横排
（字形会回退到 Noto Sans CJK，描边等 ASS 样式保留）。
复现路径：首页 → 《更衣人偶坠入爱河》→ 继续播放。

**其他架构**：`armeabi-v7a` / `x86` / `x86_64` 仍用官方库，字幕问题在这些
架构上依然存在。若需要，按同样流程各编一份。
