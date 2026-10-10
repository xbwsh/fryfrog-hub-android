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

自编译版本相对上游的编译改动：

| 位置 | 上游 | 本仓库 |
|---|---|---|
| `libass` configure | `--disable-require-system-font-provider` | **`--enable-fontconfig`** |
| `fontconfig` 构建 | （未参与） | **`-Ddefault-fonts-dirs=/system/fonts`** |

新增了 `expat` + `fontconfig` 两个交叉编译依赖，串进 `dep_libass`。
此外**必须**原样打上游的 `patches/{mpv,ffmpeg}` 补丁（见第四节）——
早期漏打导致播放失败。

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

脚本做的事：修改 pub cache 里插件的 `build.gradle`（`media_kit_libs_android_video-1.3.8`），
让 **arm64-v8a** 从这个仓库的 `libs/` 取 jar（其余架构仍走官方下载）。
脚本幂等，可重复执行；原文件会备份成 `build.gradle.orig`。

> pub cache 路径按 `PUB_CACHE` 环境变量 → 平台默认
> （Windows `%LOCALAPPDATA%\Pub\Cache`、类 Unix `~/.pub-cache`）自动探测，
> 找不到时会把尝试过的路径全部列出。

> **注意**：这是对 pub cache 的修改，`flutter pub get` 不会还原。但
> **插件版本升级**（当前锁定 1.3.8）或 **pub cache 被清理**后需要重跑脚本。

验证是否生效：

```bash
# 构建后确认 APK 里的 arm64 库来自我们（大小约 10MB，官方是 12.4MB）
unzip -l build/app/outputs/flutter-apk/app-debug.apk | grep arm64-v8a/libmpv
```

---

## 四、重新编译 libmpv（一般不需要）

产物已提交，**正常开发无需重编**。只有要改编译选项、或改补丁时才需要。

`build-scripts/` 是构建脚本的存档（从
[media-kit/libmpv-android-video-build](https://github.com/media-kit/libmpv-android-video-build)
改造而来）。关键改动见 `build-scripts/build-inline.sh` 顶部注释与
`build-scripts/libass.sh`。

### 上游补丁（必打，漏打必翻车）

`build-scripts/patches/{mpv,ffmpeg}/*.patch` 是从上游原样 vendor 的，
`build-inline.sh` 构建前会自动幂等应用，**mpv 构建完还会硬校验
`mpv_lavc_set_java_vm` 符号，缺了直接失败**。三个补丁分别是：

| 补丁 | 作用 |
|---|---|
| `mpv/mpv_lavc_set_java_vm.patch` | **必须**。media_kit 启动时在 libmpv 里查 `mpv_lavc_set_java_vm` 来注入 JavaVM（设备上没有独立 libavcodec.so，没有 fallback）。缺失 → 注入中断 → mediacodec 硬解不可用 + 解码错误日志被 media_kit 当致命错误抛给 App → **播放失败** |
| `ffmpeg/dash_base_url_escape.patch` | DASH base URL 转义修复 |
| `ffmpeg/hls_mp4_seek.patch` | HLS mp4 seek 时重取 init segment |

### 重编 → 打包 → 注入

**首选：GitHub Actions 云端构建（Windows 也适用，本机零依赖）**

workflow：`.github/workflows/build-libmpv.yml`。`build-scripts/**` 或该
workflow 有 push 时自动跑，也可在 Actions 页手动 `workflow_dispatch`。
流程：ubuntu runner → `fetch-deps.sh` 拉源码（全走 GitHub，避开
gitlab 反爬）→ `build-inline.sh`（自动打补丁 + 符号硬校验）→
`pack_libmpv_jar.py`（坏库拒绝出厂）→ 产物以 artifact
`libmpv-arm64-fontconfig-jar` 上传（保留 30 天）。

拿到 artifact 后：

```bash
# 下载的 jar 覆盖仓库同名文件
# third_party/media_kit_libs_android_video/libs/libmpv-arm64-fontconfig.jar
python3 tools/patch_libmpv_jar.py   # 注入 pub cache（幂等）
flutter build apk --debug           # 重装复测
```

NDK、依赖源码、静态库在 runner 上都有 cache，二次构建只需重编 mpv
（几分钟）。`fetch-deps.sh` 也可本地跑（Git Bash / WSL / macOS 均可），
版本从 `depinfo.sh` 读取、幂等。

**备选：本地构建（macOS / Linux / WSL）**

```bash
cd third_party/media_kit_libs_android_video/build-scripts
bash fetch-deps.sh                  # 拉依赖源码（幂等）
# NDK 放任意路径后指过去（默认路径是 build-scripts/sdk/... ）：
export LIBMPV_NDKROOT=/path/to/android-ndk-r28b
bash build-inline.sh                # 或 ./build-inline.sh mpv 只重编 mpv
                                   # ffmpeg 想吃到补丁需先删 prefix 下的
                                   # libavcodec.a 触发重建（mpv 每次都重编）

# 回仓库根目录：校验符号 + 重新打包 jar（坏库会被拒绝）
python3 tools/pack_libmpv_jar.py

python3 tools/patch_libmpv_jar.py   # 重新注入 pub cache（幂等）
flutter build apk --debug
```

> 纯原生 Windows（不带 WSL）不支持本地构建：依赖里的 autotools 工程
> 需要 make/autoconf，NDK 工具链在原生 Windows 下 meson 解析也有问题。
> Windows 用户请走 Actions 或 WSL。

`pack_libmpv_jar.py` 会硬校验新 so 必须导出 `mpv_lavc_set_java_vm`、
带 fontconfig（`FcInit`）与 `/system/fonts`，任何一项缺失都拒绝写入 jar。

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

**⚠️ 播放失败根因（已定位，待重编验证）**：早期自编译**漏打了上游
`mpv_lavc_set_java_vm.patch`**（对照：官方 jar 里该符号存在、我们编的没有，
二者其余 `mpv_*` 导出符号完全一致）。media_kit 的 `AndroidHelper.ensureInitialized`
在 libmpv 里查不到该符号、libavcodec.so 又不存在 → JavaVM 注入中断 →
mediacodec 硬解初始化失败，相关 error 日志被 media_kit 转发到
`player.stream.error`，App 收到任意一条就把 UI 切到「播放失败」页。
现在补丁已 vendor 进 `build-scripts/patches/`，构建时自动打入并硬校验符号。
**修复动作：按第四节重编 mpv → `pack_libmpv_jar.py` 打包 → 重装 APK 复测。**

**另一条独立线索（与 libmpv 无关）**：此前抓到的
`Failed to open <stream url>` + curl 复测 `401 Unauthorized`、而重新经 API
取的 URL 返回 206 —— 这是**签名流地址过期**（App 直接用了 DTO 里的
`streamUrl`，见 `api_client.dart: videoStreamUrl`）。若重编后仍失败且错误是
401，应走 App/后端的签名有效期这条线（open 前刷新 URL），不要再怀疑 mpv。

**下一步**：重编后复现路径：首页 → 《更衣人偶坠入爱河》→ 继续播放，
确认①能正常播放 ②字幕变为正常横排（字形回退 Noto Sans CJK，描边等 ASS
样式保留）。

**其他架构**：`armeabi-v7a` / `x86` / `x86_64` 仍用官方库，字幕问题在这些
架构上依然存在。若需要，按同样流程各编一份。
