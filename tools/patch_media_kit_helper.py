#!/usr/bin/env python3
"""给 media_kit 的 AndroidHelper 打兜底补丁（Windows 免重编方案）。

背景
----
media_kit 启动时（``AndroidHelper.ensureInitialized``）必须把 JavaVM 注入
ffmpeg，否则 mediacodec 硬解初始化失败，解码错误日志经
``player.stream.error`` 让 App 显示「播放失败」。原逻辑找注入函数的顺序是：

1. ``libmpv.so`` 里的 ``mpv_lavc_set_java_vm``（上游 media-kit 给预编译
   库打的补丁提供的包装函数）
2. ``libavcodec.so`` 里的 ``av_jni_set_java_vm`` —— **Android 上不存在
   独立的 libavcodec.so**（静态链进 libmpv），这条永远落空

我们自编译的 libmpv 没打上游 mpv 补丁 → 1、2 都找不到 → 注入中断。
但实际上自编译库**同样导出了 ffmpeg 的 ``av_jni_set_java_vm``
（静态链接后全局可见，已用 ELF dynsym 核验 bind=GLOBAL）**，
只是 media_kit 不会去 libmpv 里找它。

本脚本在 pub cache 的 ``android_helper.dart`` 里补一次「从 libmpv 查
``av_jni_set_java_vm``」的尝试（幂等，原文件备份 ``*.orig``）。
这样**无需重新编译 libmpv** 即可恢复 JavaVM 注入。

注意：这是对 pub cache 的修改，media_kit 版本升级或 cache 清理后需重跑；
正式解法仍是给 libmpv 打上游补丁重编（见
third_party/media_kit_libs_android_video/README.md 第四节）。
"""

from __future__ import annotations

import os
import shutil
import sys

MEDIA_KIT_VERSION = "1.2.6"
TARGET_REL = os.path.join(
    "hosted", "pub.dev", f"media_kit-{MEDIA_KIT_VERSION}",
    "lib", "src", "player", "native", "utils", "android_helper.dart",
)

MARK_BEGIN = "// >>> fryfrog: 从 libmpv 兜底查 av_jni_set_java_vm（免重编方案）"
MARK_END = "// <<< fryfrog"

# 锚点：media_kit 1.2.6 原始代码里 libavcodec 查找块（逐字符匹配）。
ANCHOR = """        try {
          _av_jni_set_java_vm = libavcodec
              ?.lookupFunction<av_jni_set_java_vmCXX, av_jni_set_java_vmDart>(
            'av_jni_set_java_vm',
          );
        } catch (_) {}
"""

FALLBACK = ANCHOR + """        // >>> fryfrog: 从 libmpv 兜底查 av_jni_set_java_vm（免重编方案）
        // 自编译 libmpv 未打上游 mpv_lavc_set_java_vm 补丁时，上面两步都会
        // 落空（Android 无独立 libavcodec.so）→ JavaVM 注入中断 → 硬解失败
        // → 播放报错。我们编的 libmpv 静态链了 ffmpeg，同样全局导出
        // av_jni_set_java_vm，补一次从 libmpv 里找的尝试即可。
        if (_av_jni_set_java_vm == null) {
          try {
            _av_jni_set_java_vm = libmpv?.lookupFunction<
                av_jni_set_java_vmCXX, av_jni_set_java_vmDart>(
              'av_jni_set_java_vm',
            );
          } catch (_) {}
        }
        // <<< fryfrog
"""


def find_target() -> tuple[str | None, list[str]]:
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
        path = os.path.join(c, TARGET_REL)
        tried.append(path)
        if os.path.isfile(path):
            return path, tried
    return None, tried


def main() -> int:
    path, tried = find_target()
    if path is None:
        print("✗ 找不到 android_helper.dart，已尝试：", file=sys.stderr)
        for p in tried:
            print(f"    {p}", file=sys.stderr)
        print("  先跑 `flutter pub get`；若自定义 pub cache，设 PUB_CACHE 后重试。",
              file=sys.stderr)
        return 1

    src = open(path, encoding="utf-8").read()
    if MARK_BEGIN in src:
        print("✓ 已经 patch 过，跳过（幂等）")
        return 0
    if ANCHOR not in src:
        print(f"✗ 在 {path} 里找不到锚点代码（media_kit 版本变了？"
              f"当前锁定 {MEDIA_KIT_VERSION}）", file=sys.stderr)
        return 1

    backup = path + ".orig"
    if not os.path.exists(backup):
        shutil.copy2(path, backup)
        print(f"  已备份原文件到 {os.path.basename(backup)}")

    src = src.replace(ANCHOR, FALLBACK, 1)
    open(path, "w", encoding="utf-8", newline="\n").write(src)
    print("✓ 已 patch android_helper.dart：JavaVM 注入增加 libmpv 兜底查找")
    print(f"  {path}")
    print("  重新 flutter build apk 即生效；正式解法仍是重编 libmpv（见 README 第四节）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
