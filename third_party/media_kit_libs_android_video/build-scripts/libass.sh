#!/bin/bash -e

. ../../include/depinfo.sh
. ../../include/path.sh

if [ "$1" == "build" ]; then
	true
elif [ "$1" == "clean" ]; then
	rm -rf _build$ndk_suffix
	exit 0
else
	exit 255
fi

[ -f configure ] || ./autogen.sh

mkdir -p _build$ndk_suffix
cd _build$ndk_suffix

# --enable-fontconfig 是本仓库的本地改动：
# 上游用的是 --disable-require-system-font-provider，等于**放弃**系统字体发现，
# 结果 libass 只认内嵌字体子集，找不到任何系统字体 → ASS 特效字幕
# （尤其日式竖排 \\fscx/\\frz）全部渲染错乱。
# 改为显式链接 fontconfig，让 libass 能枚举 /system/fonts。
../configure \
	CFLAGS=-fPIC CXXFLAGS=-fPIC \
	--host=$ndk_triple \
	--with-pic \
	--disable-asm \
	--enable-static\
	--disable-shared \
	--enable-fontconfig

make -j$cores
make DESTDIR="$prefix_dir" install
