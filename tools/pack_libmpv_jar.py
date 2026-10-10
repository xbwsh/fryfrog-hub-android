#!/usr/bin/env python3
"""把新编译的 libmpv.so 打进 jar，并做硬性符号校验。

用法（在仓库根目录，构建完 libmpv 之后）::

    python3 tools/pack_libmpv_jar.py            # 自动找 libmpv.so
    python3 tools/pack_libmpv_jar.py <libmpv.so 路径>

做三件事：

1. **校验** 新 so 必须导出 ``mpv_lavc_set_java_vm``（media_kit 启动强依赖，
   缺了 Android 上直接播放失败）且带 fontconfig 痕迹（本仓库编译的核心目的）。
   校验不过绝不打包，避免把坏库提交上去。
2. 用新 so 替换 ``libs/libmpv-arm64-fontconfig.jar`` 里的
   ``lib/arm64-v8a/libmpv.so``；``libmediakitandroidhelper.so`` 保持原样。
3. 打印替换前后的大小与校验结果，便于肉眼复核。
"""

from __future__ import annotations

import io
import os
import struct
import sys
import zipfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
JAR = os.path.join(
    REPO, "third_party", "media_kit_libs_android_video", "libs",
    "libmpv-arm64-fontconfig.jar",
)
DEFAULT_SO_CANDIDATES = [
    # build-inline.sh 的落点（NATIVE 目录）
    os.path.join(
        REPO, "third_party", "media_kit_libs_android_video",
        "libmpv", "src", "main", "jniLibs", "arm64-v8a", "libmpv.so",
    ),
    # meson 安装前缀里的原始产物
    os.path.join(
        REPO, "third_party", "media_kit_libs_android_video",
        "build-scripts", "prefix", "arm64-v8a", "lib", "libmpv.so",
    ),
]
MPV_SO = "lib/arm64-v8a/libmpv.so"
HELPER_SO = "lib/arm64-v8a/libmediakitandroidhelper.so"


def dynsym_exports(data: bytes) -> set[str]:
    """返回 ELF 动态符号表里的全局/弱符号名集合。"""
    if data[:4] != b"\x7fELF" or data[4] != 2:  # ELFCLASS64
        raise ValueError("不是 ELF64 文件")
    (e_shoff,) = struct.unpack_from("<Q", data, 40)
    e_shentsize, e_shnum, e_shstrndx = struct.unpack_from("<HHH", data, 58)
    sections = [
        struct.unpack_from("<IIQQQQIIQQ", data, e_shoff + i * e_shentsize)
        for i in range(e_shnum)
    ]
    shstr = sections[e_shstrndx]
    strtab = data[shstr[4]:shstr[4] + shstr[5]]

    def name(off: int) -> str:
        return strtab[off:strtab.index(b"\0", off)].decode()

    dynsym = dynstr = None
    for sh in sections:
        n = name(sh[0])
        if n == ".dynsym":
            dynsym = sh
        elif n == ".dynstr":
            dynstr = sh
    if dynsym is None or dynstr is None:
        raise ValueError("缺少 .dynsym/.dynstr（不是动态库？）")
    dstr = data[dynstr[4]:dynstr[4] + dynstr[5]]
    out: set[str] = set()
    ent = dynsym[9] or 24
    for off in range(dynsym[4], dynsym[4] + dynsym[5], ent):
        st_name, st_info, _, st_shndx, _, _ = struct.unpack_from(
            "<IBBHQQ", data, off
        )
        if st_shndx == 0 or (st_info >> 4) not in (1, 2):  # GLOBAL/WEAK
            continue
        out.add(dstr[st_name:dstr.index(b"\0", st_name)].decode())
    return out


def verify(so: bytes) -> list[str]:
    """返回问题列表；空列表 = 通过。"""
    problems: list[str] = []
    try:
        exports = dynsym_exports(so)
    except ValueError as e:
        return [f"ELF 解析失败：{e}"]
    if "mpv_lavc_set_java_vm" not in exports:
        problems.append(
            "未导出 mpv_lavc_set_java_vm —— 上游 mpv 补丁没打上，"
            "media_kit 启动会注入 JavaVM 失败 → 播放失败"
            "（检查 build-scripts/patches/mpv/）"
        )
    if not any(s.startswith(("FcInit", "FcConfig", "FcFontMatch")) for s in exports) \
            and b"FcInit" not in so:
        problems.append("没有 fontconfig 痕迹（FcInit）—— 字幕修复白编了")
    if b"/system/fonts" not in so:
        problems.append("缺少 /system/fonts 默认字体目录 —— fontconfig 没配对")
    return problems


def find_so(argv: list[str]) -> str:
    if len(argv) > 1:
        return argv[1]
    for c in DEFAULT_SO_CANDIDATES:
        if os.path.isfile(c):
            return c
    raise SystemExit(
        "✗ 找不到 libmpv.so，已尝试：\n  "
        + "\n  ".join(DEFAULT_SO_CANDIDATES)
        + "\n  或用法：python3 tools/pack_libmpv_jar.py <libmpv.so>"
    )


def main(argv: list[str]) -> int:
    so_path = find_so(argv)
    so = open(so_path, "rb").read()

    problems = verify(so)
    if problems:
        print(f"✗ 校验失败，拒绝打包：{so_path}", file=sys.stderr)
        for p in problems:
            print(f"    - {p}", file=sys.stderr)
        return 1
    print(f"✓ 校验通过：{so_path}（{len(so)} 字节）")

    if not os.path.isfile(JAR):
        print(f"✗ 找不到现有 jar：{JAR}", file=sys.stderr)
        return 1
    old = zipfile.ZipFile(JAR)
    helper = old.read(HELPER_SO)  # 打不开说明现有 jar 结构变了，直接抛错
    old_so_size = old.getinfo(MPV_SO).file_size
    old.close()

    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr(HELPER_SO, helper)
        z.writestr(MPV_SO, so)
    with open(JAR, "wb") as f:
        f.write(buf.getvalue())

    print(f"✓ 已打包：{JAR}")
    print(f"    libmpv.so: {old_so_size} → {len(so)} 字节")
    print(f"    {HELPER_SO}: 保持原样")
    print("下一步：python3 tools/patch_libmpv_jar.py 后重新 flutter build apk")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
