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
# default-fonts-dirs 必须显式给 /system/fonts：传 [] 会得到「空目录列表」
# （FC_DEFAULT_FONTS 为空，设备上扫不到任何系统字体，字幕修复失效）；
# 不传（默认 ['yes']）会按构建宿主给 /usr/share/fonts 等 Android 上不存在
# 的路径。cross-compile 只能显式指定目标系统的字体目录。
meson setup $build \
	--cross-file "$prefix_dir"/crossfile.txt \
	-Ddefault-fonts-dirs=/system/fonts \
	-Ddefault-hinting=none \
	-Ddocs=disabled \
	-Dnls=disabled \
	-Dtests=disabled \
	-Dtools=disabled \
	-Dcache-build=disabled

ninja -C $build -j$cores
DESTDIR="$prefix_dir" ninja -C $build install