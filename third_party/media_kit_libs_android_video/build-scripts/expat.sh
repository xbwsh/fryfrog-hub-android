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

# fontconfig 依赖 expat 的XML 解析器来读 fonts.conf，必须先静态编出来，
# 否则 fontconfig 的 meson 会去找系统 expat（Android 上没有）而失败。
mkdir -p _build$ndk_suffix
cd _build$ndk_suffix

../configure \
	--host=$ndk_triple \
	--enable-static \
	--disable-shared \
	--without-docbook \
	--without-examples \
	--without-tests \
	--without-xmlwf

make -j$cores
make DESTDIR="$prefix_dir" install