#!/bin/bash
# ============================================================================
# libmpv for Android (arm64) — 内联构建脚本
#
# 为什么不用上游 scripts/*.sh + build.sh：
#   上游脚本在 out-of-source 构建时会污染源码目录（config.status 落到 src，
#   导致 "source directory already configured"），且 expat.pc 生成失败。
#   这里每个库的构建步骤全部内联、cwd 与路径全部用绝对路径，行为可预测。
#
# 相对上游的唯一功能改动：libass 用 --enable-fontconfig 取代
#   --disable-require-system-font-provider，让 libass 能枚举 /system/fonts，
#   从而正确渲染 ASS 特效字幕（尤其日式竖排 \fscx/\frz）。
#
# 用法：./build-inline.sh [start-stage]
#   start-stage 可选，指定从哪个库开始（断点续跑），如 ./build-inline.sh fontconfig
# ============================================================================
set -o pipefail

B="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
D="$B/deps"
PREFIX="$B/prefix/arm64-v8a"
NATIVE="$B/../libmpv/src/main/jniLibs/arm64-v8a"
NDKROOT="$B/sdk/android-sdk-linux/ndk/28.2.13676358"
CORES=$(sysctl -n hw.ncpu)

export PATH="$HOME/bin:/opt/homebrew/bin:$PATH"
toolchain=$(echo "$NDKROOT/toolchains/llvm/prebuilt/"*)
export PATH="$toolchain/bin:$NDKROOT:$PATH"

export CC=aarch64-linux-android21-clang
export CXX=aarch64-linux-android21-clang++
export AR=llvm-ar
export RANLIB=llvm-ranlib
export NM=llvm-nm
export STRIP=llvm-strip

mkdir -p "$PREFIX" "$NATIVE"
[ -e "$PREFIX/usr" ] || ln -s . "$PREFIX/usr"
[ -e "$PREFIX/local" ] || ln -s . "$PREFIX/local"

# meson 交叉编译配置（cwd 无关，写绝对路径）
cat > "$PREFIX/crossfile.txt" <<CROSS
[built-in options]
buildtype = 'release'
default_library = 'static'
wrap_mode = 'nodownload'
[binaries]
c = '$CC'
cpp = '$CXX'
ar = '$AR'
nm = '$NM'
strip = '$STRIP'
pkg-config = 'pkg-config'
[host_machine]
system = 'android'
cpu_family = 'aarch64'
cpu = 'aarch64'
endian = 'little'
CROSS

log() { echo ""; echo "############ $* ############"; }

# pkg-config 只看我们的 prefix，避免误用宿主机库
pc_env() {
	export PKG_CONFIG_SYSROOT_DIR="$PREFIX"
	export PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig"
	unset PKG_CONFIG_PATH
}

skip_until() { # 若指定了起始库，跳过它之前的
	[ -z "$START" ] && return 1
	[ "$START" == "$1" ] && { START=""; return 1; }
	return 0
}

START="$1"

# ---------------------------------------------------------------- expat
if ! skip_until expat; then
	log "expat"
	if [ -f "$PREFIX/lib/libexpat.a" ]; then
		echo "已构建，跳过"
	else
		cd "$D/expat"
		find . -maxdepth 1 -name '_build*' -exec rm -rf {} + 2>/dev/null
		rm -f expat.pc config.status config.log Makefile
		mkdir -p _build-arm64 && cd "$D/expat/_build-arm64"
		"$D/expat/configure" --host=aarch64-linux-android \
			--enable-static --disable-shared \
			--without-docbook --without-examples --without-tests --without-xmlwf \
			|| exit 1
		make -j$CORES || exit 1
		make DESTDIR="$PREFIX" install || exit 1
	fi
fi

# ------------------------------------------------------------- freetype
if ! skip_until freetype; then
	log "freetype"
	if [ -f "$PREFIX/lib/libfreetype.a" ]; then
		echo "已构建，跳过"
	else
		cd "$D/freetype"
		find . -maxdepth 1 -name '_build*' -exec rm -rf {} + 2>/dev/null
		unset CC CXX
		meson setup _b --prefix=/usr/local --cross-file "$PREFIX/crossfile.txt" \
			-Dtests=disabled -Dbrotli=disabled -Dbzip2=disabled \
			-Dpng=disabled -Dharfbuzz=disabled -Dzlib=disabled || exit 1
		ninja -C _b -j$CORES || exit 1
		DESTDIR="$PREFIX" ninja -C _b install || exit 1
		export CC=aarch64-linux-android21-clang CXX=aarch64-linux-android21-clang++
	fi
fi

# -------------------------------------------------------------- fribidi
if ! skip_until fribidi; then
	log "fribidi"
	if [ -f "$PREFIX/lib/libfribidi.a" ]; then
		echo "已构建，跳过"
	else
		cd "$D/fribidi"
		find . -maxdepth 1 -name '_build*' -exec rm -rf {} + 2>/dev/null
		unset CC CXX
		meson setup _b --prefix=/usr/local --cross-file "$PREFIX/crossfile.txt" \
			-Dtests=false -Ddocs=false -Dbin=false || exit 1
		ninja -C _b -j$CORES || exit 1
		DESTDIR="$PREFIX" ninja -C _b install || exit 1
		export CC=aarch64-linux-android21-clang CXX=aarch64-linux-android21-clang++
	fi
fi

# ------------------------------------------------------------- harfbuzz
if ! skip_until harfbuzz; then
	log "harfbuzz"
	if [ -f "$PREFIX/lib/libharfbuzz.a" ]; then
		echo "已构建，跳过"
	else
		cd "$D/harfbuzz"
		find . -maxdepth 1 -name '_build*' -exec rm -rf {} + 2>/dev/null
		unset CC CXX
		meson setup _b --prefix=/usr/local --cross-file "$PREFIX/crossfile.txt" \
			-Dtests=disabled -Ddocs=disabled \
			-Dglib=disabled -Dgobject=disabled -Dicu=disabled \
			-Dcairo=disabled -Dchafa=disabled -Dgraphite=disabled \
			-Dfreetype=disabled -Dgdi=disabled \
			-Ddirectwrite=disabled -Dcoretext=disabled \
			-Dintrospection=disabled -Dutilities=disabled \
			-Dbenchmark=disabled || exit 1
		ninja -C _b -j$CORES || exit 1
		DESTDIR="$PREFIX" ninja -C _b install || exit 1
		export CC=aarch64-linux-android21-clang CXX=aarch64-linux-android21-clang++
	fi
fi

# ----------------------------------------------------------- fontconfig
if ! skip_until fontconfig; then
	log "fontconfig"
	if [ -f "$PREFIX/lib/libfontconfig.a" ]; then
		echo "已构建，跳过"
	else
		pc_env
		cd "$D/fontconfig"
		find . -maxdepth 1 -name '_build*' -exec rm -rf {} + 2>/dev/null
		unset CC CXX
		meson setup _b --prefix=/usr/local --cross-file "$PREFIX/crossfile.txt" \
			-Ddefault-fonts-dirs=[] \
			-Ddefault-hinting=none \
			-Ddoc=disabled -Ddoc-txt=disabled -Ddoc-man=disabled \
			-Ddoc-pdf=disabled -Ddoc-html=disabled \
			-Dnls=disabled -Dtests=disabled \
			-Dtools=disabled -Dcache-build=disabled || exit 1
		ninja -C _b -j$CORES || exit 1
		DESTDIR="$PREFIX" ninja -C _b install || exit 1
		export CC=aarch64-linux-android21-clang CXX=aarch64-linux-android21-clang++
	fi
fi

# --------------------------------------------------------------- libass
if ! skip_until libass; then
	log "libass  ★ 关键：--enable-fontconfig"
	if [ -f "$PREFIX/lib/libass.a" ]; then
		echo "已构建，跳过"
	else
		# libass 需要 pkg-config 找到 freetype2/fribidi/harfbuzz/fontconfig
		pc_env
		cd "$D/libass"
		find . -maxdepth 1 -name '_build*' -exec rm -rf {} + 2>/dev/null
		[ -f configure ] || ./autogen.sh
		mkdir -p _build-arm64 && cd "$D/libass/_build-arm64"
		CFLAGS="-fPIC" "$D/libass/configure" \
			--host=aarch64-linux-android \
			--with-pic \
			--disable-asm \
			--enable-static \
			--disable-shared \
			--enable-fontconfig \
			|| exit 1
		make -j$CORES || exit 1
		make DESTDIR="$PREFIX" install || exit 1
	fi
fi

# --------------------------------------------------------------- dav1d
if ! skip_until dav1d; then
	log "dav1d（ffmpeg 的 AV1 解码依赖）"
	if [ -f "$PREFIX/lib/libdav1d.a" ]; then
		echo "已构建，跳过"
	else
		cd "$D/dav1d"
		find . -maxdepth 1 -name '_b' -exec rm -rf {} + 2>/dev/null
		unset CC CXX
		meson setup _b --prefix=/usr/local --cross-file "$PREFIX/crossfile.txt" \
			-Denable_tests=false -Db_lto=true -Dstack_alignment=16 || exit 1
		ninja -C _b -j$CORES || exit 1
		DESTDIR="$PREFIX" ninja -C _b install || exit 1
		export CC=aarch64-linux-android21-clang CXX=aarch64-linux-android21-clang++
	fi
fi

# -------------------------------------------------------------- mbedtls
if ! skip_until mbedtls; then
	log "mbedtls（ffmpeg 的 TLS 依赖）"
	if [ -f "$PREFIX/lib/libmbedtls.a" ] || [ -f "$PREFIX/lib/libmbedcrypto.a" ]; then
		echo "已构建，跳过"
	else
		cd "$D/mbedtls"
		make clean >/dev/null 2>&1 || true
		# mbedtls 的 AArch64 AES 代码调用 vget_high_p64 等 crypto 扩展内建函数，
		# 而 NDK clang 默认 target 是纯 armv8-a（不含 +crypto）→ 编译报
		# "requires target feature 'crypto'"。显式打开该特性。
		# （armv8-a 的 AES/SHA 扩展在 2016 年后的 arm64 设备上普遍可用）
		MBFLAGS="-fPIC -march=armv8-a+crypto"
		make CFLAGS="$MBFLAGS" CXXFLAGS="$MBFLAGS" -j$CORES no_test || exit 1
		make CFLAGS="$MBFLAGS" CXXFLAGS="$MBFLAGS" DESTDIR="$PREFIX" install || exit 1
	fi
fi

# -------------------------------------------------------------- libxml2
if ! skip_until libxml2; then
	log "libxml2（ffmpeg 依赖）"
	if [ -f "$PREFIX/lib/libxml2.a" ]; then
		echo "已构建，跳过"
	else
		pc_env
		cd "$D/libxml2"
		find . -maxdepth 1 -name '_build*' -exec rm -rf {} + 2>/dev/null
		rm -f config.status config.log Makefile
		[ -f configure ] || { ./autogen.sh --help >/dev/null 2>&1; autoreconf -fi >/dev/null 2>&1; }
		mkdir -p _build-arm64 && cd "$D/libxml2/_build-arm64"
		CFLAGS=-fPIC CXXFLAGS=-fPIC "$D/libxml2/configure" \
			--host=aarch64-linux-android \
			--disable-shared --enable-static \
			--with-minimum --with-threads --with-tree --without-lzma \
			|| exit 1
		make -j$CORES || exit 1
		make DESTDIR="$PREFIX" install || exit 1
	fi
fi

# --------------------------------------------------------------- ffmpeg
if ! skip_until ffmpeg; then
	log "ffmpeg（最耗时，可能要 30-60 分钟）"
	if [ -f "$PREFIX/lib/libavcodec.a" ]; then
		echo "已构建，跳过"
	else
		pc_env
		cd "$D/ffmpeg"
		find . -maxdepth 1 -name '_build*' -exec rm -rf {} + 2>/dev/null
		# ⚠️ 不要删源码目录的 Makefile！它是 ffmpeg 构建系统的一部分
		# （out-of-source 时 _build/Makefile 会 include 它），
		# 删掉会导致 make 报 "No rule to make target .../ffmpeg/Makefile"。
		mkdir -p _build-arm64 && cd "$D/ffmpeg/_build-arm64"
		# ffmpeg 参数里引用了这些变量（原本在 flavors/default.sh 顶部定义）
		ndk_triple=aarch64-linux-android
		cpu=armv8-a
		cpuflags=
		ARGS=$(cat "$B/ffmpeg-configure-args.txt")
		eval "\"$D/ffmpeg/configure\" $ARGS --extra-cflags=\"-I$PREFIX/include $cpuflags\" --extra-ldflags=\"-L$PREFIX/lib\"" || exit 1
		make -j$CORES || exit 1
		make DESTDIR="$PREFIX" install || exit 1
	fi
fi

# ------------------------------------------------------------------ mpv
if ! skip_until mpv; then
	log "mpv → libmpv.so"
	cd "$D/mpv"
	find . -maxdepth 1 -name '_build*' -exec rm -rf {} + 2>/dev/null
	pc_env
	unset CC CXX
	meson setup _b --prefix=/usr/local --cross-file "$PREFIX/crossfile.txt" \
		--prefer-static \
		--default-library shared \
		-Dgpl=false \
		-Dlibmpv=true \
		-Dlua=disabled \
		-Dcplayer=false \
		-Diconv=disabled \
		-Dvulkan=disabled \
		-Dlibplacebo=disabled \
		-Dmanpage-build=disabled || exit 1
	ninja -C _b -j$CORES || exit 1
	DESTDIR="$PREFIX" ninja -C _b install || exit 1
	cp -f "$PREFIX/lib/libmpv.so" "$NATIVE/" 2>/dev/null || true
fi

log "全部完成"
echo "libmpv.so："
ls -la "$PREFIX/lib/libmpv.so" 2>/dev/null || echo "  (未生成)"
echo "native 目录："
ls -la "$NATIVE" 2>/dev/null
