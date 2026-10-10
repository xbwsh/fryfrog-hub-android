#!/usr/bin/env python3
"""把自编译的 libmpv.so（arm64，带 fontconfig 字体支持）注入 media_kit 插件。

背景
----
上游 media_kit_libs_android_video 预编译的 libmpv 在构建 libass 时用了
`--disable-require-system-font-provider`，导致 libass 完全没有系统字体发现
能力（二进制里 fontconfig 符号 FcInit/FcFontMatch 全为 0）。后果是 ASS 特效
字幕渲染错乱——实测日式竖排字幕（靠 \\fscx/\\frz/\\an9 标签）被逐字堆叠、
描边特效全丢。

我们自行交叉编译了 libmpv（libass 启用 fontconfig，默认字体目录
/system/fonts），产物见 third_party/media_kit_libs_android_video/libs/。

为什么用 patch pub-cache 而不是 dependency_overrides
----------------------------------------------------
实测 dependency_overrides 指向本地 path 时，Flutter 不会把该插件接入
Gradle 构建（构建出的 APK 里完全没有 libmpv.so，其他原生库也一起丢了）。
所以改为直接修改 pub cache 里插件的 build.gradle：让 arm64 的 jar 从本仓库
读取，其余架构仍走官方下载。

注意
----
* 这是对 pub cache 的修改，`flutter pub get` 不会还原（除非插件版本变化
  或 cache 被清理）。插件升级后需重新运行本脚本。
* 脚本只改 arm64 一个条目，可重复执行（幂等）。
"""

# macOS 自带 python3 可能还是 3.9，注解里的 str | None 需要延迟求值。
from __future__ import annotations

import os
import re
import shutil
import sys

PLUGIN_VERSION = "1.3.8"
PLUGIN_REL = os.path.join(
    "hosted", "pub.dev",
    f"media_kit_libs_android_video-{PLUGIN_VERSION}", "android", "build.gradle",
)

MARK_BEGIN = "// >>> fryfrog: 使用自编译的 arm64 libmpv（带 fontconfig 字体支持）"
MARK_END = "// <<< fryfrog"


def find_build_gradle() -> tuple[str | None, list[str]]:
    """按 PUB_CACHE 环境变量 → 平台默认路径 依次探测插件的 build.gradle。

    Windows 上 flutter 默认把 pub cache 放在 %LOCALAPPDATA%\\Pub\\Cache，
    而不是 ~/.pub-cache——写死后者的旧版脚本在这台机器上永远找不到插件。
    """
    candidates: list[str] = []
    env = os.environ.get("PUB_CACHE")
    if env:
        candidates.append(env)
    if sys.platform == "win32":
        local = os.environ.get("LOCALAPPDATA")
        if local:
            candidates.append(os.path.join(local, "Pub", "Cache"))
    candidates.append(os.path.expanduser("~/.pub-cache"))
    if sys.platform == "darwin":
        candidates.append(
            os.path.expanduser("~/Library/Application Support/pub/cache")
        )

    tried: list[str] = []
    seen: set[str] = set()
    for c in candidates:
        c = os.path.abspath(c)
        if c in seen:
            continue
        seen.add(c)
        path = os.path.join(c, PLUGIN_REL)
        tried.append(path)
        if os.path.isfile(path):
            return path, tried
    return None, tried



def main() -> int:
    repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    jar = os.path.join(
        repo_root,
        "third_party",
        "media_kit_libs_android_video",
        "libs",
        "libmpv-arm64-fontconfig.jar",
    )

    if not os.path.isfile(jar):
        print(f"✗ 找不到自编译的 jar：{jar}", file=sys.stderr)
        print("  请先按 third_party/media_kit_libs_android_video/README.md 构建。",
              file=sys.stderr)
        return 1

    build_gradle, tried = find_build_gradle()
    if build_gradle is None:
        print("✗ 找不到插件 build.gradle，已尝试以下路径：", file=sys.stderr)
        for p in tried:
            print(f"    {p}", file=sys.stderr)
        print("  先跑一次 `flutter pub get` 让 pub 把插件解压出来；", file=sys.stderr)
        print("  若自定义了 pub cache，设置 PUB_CACHE 环境变量后重试。", file=sys.stderr)
        return 1

    src = open(build_gradle, encoding="utf-8").read()

    if MARK_BEGIN in src:
        print("✓ 已经 patch 过，跳过（幂等）")
        return 0

    # 备份一次
    backup = build_gradle + ".orig"
    if not os.path.exists(backup):
        shutil.copy2(build_gradle, backup)
        print(f"  已备份原文件到 {os.path.basename(backup)}")

    # 把 arm64 的下载条目整体替换成从仓库取本地 jar。
    # 上游条目形如：
    #   ["url": "...default-arm64-v8a.jar", "md5": "...", "destination": file("$buildDir/v1.1.7/default-arm64-v8a.jar")],
    pattern = re.compile(
        r'\[\s*"url"\s*:\s*"[^"]*default-arm64-v8a\.jar"\s*,\s*'
        r'"md5"\s*:\s*"[^"]*"\s*,\s*'
        r'"destination"\s*:\s*file\("[^"]*"\)\s*\]',
        re.S,
    )
    m = pattern.search(src)
    if not m:
        print("✗ 在 build.gradle 里找不到 arm64 的下载条目（上游格式可能变了）",
              file=sys.stderr)
        print("  请检查 third_party/media_kit_libs_android_video/README.md",
              file=sys.stderr)
        return 1

    # 用 projectDir 推导仓库路径，避免硬编码绝对路径。
    # rootProject.projectDir 指向 <repo>/android。
    replacement = (
        f'{MARK_BEGIN}\n'
        f'            // 自编译版：libass 启用 fontconfig，默认字体目录 /system/fonts，\n'
        f'            // 修复 ASS 特效字幕（尤其日式竖排）渲染错乱。\n'
        f'            ["local": file("$rootProject.projectDir/../third_party/'
        f'media_kit_libs_android_video/libs/libmpv-arm64-fontconfig.jar"),\n'
        f'             "destination": file("$buildDir/v1.1.7/default-arm64-v8a.jar")],\n'
        f'            {MARK_END}'
    )
    src = src[: m.start()] + replacement + src[m.end() :]

    # 让下载循环支持 "local" 条目（存在则直接复制，不走网络与 MD5 校验）
    loop_anchor = "filesToDownload.each { fileInfo ->"
    if loop_anchor not in src:
        print("✗ 找不到 downloadDependencies 的循环体", file=sys.stderr)
        return 1
    local_handling = (
        f'{loop_anchor}\n'
        f'        // fryfrog: "local" 条目从仓库复制，跳过网络下载与 MD5 校验。\n'
        f'        // 注意要复制两次：一次落到 $buildDir/v1.1.7/（与原流程的落点\n'
        f'        // 一致，便于排查），一次落到 outputDir——后者才是真正被\n'
        f'        // `fileTree(dir: outputDir)` 收进 APK 的地方。\n'
        f'        // （早先只复制前者、然后 return，结果 arm64 的 jar 没进 APK）\n'
        f'        if (fileInfo["local"] != null) {{\n'
        f'            def localJar = fileInfo["local"] as File\n'
        f'            if (!localJar.exists()) {{\n'
        f'                throw new GradleException("缺少自编译的 libmpv jar: ${{localJar}}")\n'
        f'            }}\n'
        f'            fileInfo["destination"].parentFile.mkdirs()\n'
        f'            copy {{ from localJar; into fileInfo["destination"].parentFile }}\n'
        f'            copy {{ from localJar; into outputDir }}\n'
        f'            return\n'
        f'        }}'
    )
    src = src.replace(loop_anchor, local_handling, 1)

    open(build_gradle, "w", encoding="utf-8").write(src)
    print("✓ 已 patch 插件 build.gradle：arm64 将使用自编译的 libmpv")
    print(f"  jar: {jar}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
