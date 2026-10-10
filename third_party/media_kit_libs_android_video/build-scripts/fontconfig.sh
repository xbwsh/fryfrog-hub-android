#!/bin/bash -e

. ../../include/depinfo.sh
. ../../include/path.sh

build=_build$ndk_suffix

if [ "$1" == "build" ]; then
	true
elif [ "$1" == "clean" ]; then
	rm -rf $build
	exit 0
else
	exit 255
fi

# meson 要求 CC/CXX 置空（它从 crossfile 读）
unset CC CXX

# 关掉一切非必需功能：只要 libfontconfig + 它依赖的 freetype/expat。
# -Ddefault-fonts-dirs=[] 很关键：不指定时 meson 会去探测宿主机的字体目录
# （/usr/share/fonts 等），那些路径在 Android 上不存在，还会拖进一堆
# 桌面字体进去。
meson setup $build \
	--cross-file "$prefix_dir"/crossfile.txt \
	-Ddefault-fonts-dirs=[] \
	-Ddefault-hinting=none \
	-Ddocs=disabled \
	-Dnls=disabled \
	-Dtests=disabled \
	-Dtools=disabled \
	-Dcache-build=disabled

ninja -C $build -j$cores
DESTDIR="$prefix_dir" ninja -C $build install