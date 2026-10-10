#!/bin/bash
# ============================================================================
# libmpv for Android (arm64) — 内联构建脚本
#
# 为什么不用上游 scripts/*.sh + build.sh：
#   上游脚本在 out-of-source 构建时会污染源码目录（config.status 落到 src，
#   导致 "source directory already configured"），且 expat.pc 生成失败。
#   这里每个库的构建步骤全部内联、cwd 与路径全部用绝对路径，行为可预测。
#
# 相对上游的功能改动：
#   1. libass 用 --enable-fontconfig 取代
#      --disable-require-system-font-provider，让 libass 能枚举 /system/fonts，
#      从而正确渲染 ASS 特效字幕（尤其日式竖排 \fscx/\frz）。
#   2. 打上游 media-kit 的补丁（patches/{mpv,ffmpeg}/*.patch）——之前漏打了，
#      导致缺 mpv_lavc_set_java_vm 导出符号，media_kit 启动时注入 JavaVM
#      失败 → mediacodec 硬解不可用，播放器报「播放失败」。详见 README。
#
# 用法：./build-inline.sh [start-stage]
#   start-stage 可选，指定从哪个库开始（断点续跑），如 ./build-inline.sh fontconfig
# ============================================================================
set -o pipefail

B="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
D="$B/deps"
PREFIX="$B/prefix/arm64-v8a"
NATIVE="$B/../libmpv/src/main/jniLibs/arm64-v8a"
# NDK 路径可用 LIBMPV_NDKROOT 覆盖（CI / WSL 不把 NDK 放仓库目录里）。
NDKROOT="${LIBMPV_NDKROOT:-$B/sdk/android-sdk-linux/ndk/28.2.13676358}"
# Linux 没有 sysctl（macOS 没有 nproc——brew coreutils 装的是 g 前缀）。
CORES=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)

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

# 给 $1（源码目录）打 $2（补丁目录）下的全部 *.patch，幂等。
# 上游 buildscripts/patch.sh 的等价物（那边会先 git reset --hard，这里不做
# 破坏性操作：已打过就跳过，没打过才应用）。
apply_patches() {
	local dep_dir="$1" pdir="$2" p
	[ -d "$pdir" ] || return 0
	for p in "$pdir"/*.patch; do
		[ -e "$p" ] || continue
		cd "$dep_dir" || exit 1
		if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
			if git apply --reverse --check "$p" >/dev/null 2>&1; then
				echo "已打过补丁，跳过：$(basename "$p")"
				continue
			fi
			if git apply --check "$p" >/dev/null 2>&1; then
				git apply "$p" || exit 1
				echo "✓ 已打补丁：$(basename "$p")"
				continue
			fi
		fi
		# 非 git 目录或 git apply 不适用 → 退回 patch(1)
		if patch -p1 -N -s --dry-run < "$p" >/dev/null 2>&1; then
			patch -p1 -N -s < "$p" || exit 1
			echo "✓ 已打补丁(patch)：$(basename "$p")"
		elif patch -p1 -R -s --dry-run < "$p" >/dev/null 2>&1; then
			echo "已打过补丁，跳过：$(basename "$p")"
		else
			echo "✗ 打补丁失败：$p（源码状态与补丁上下文不符）" >&2
			exit 1
		fi
	done
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
		# 上游 ffmpeg 补丁（dash URL 转义、hls mp4 seek）；已打过会自动跳过。
		apply_patches "$D/ffmpeg" "$B/patches/ffmpeg"
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
	# ★ 关键：上游 mpv 补丁（mpv_lavc_set_java_vm）——media_kit 启动强依赖该
	#   导出符号；缺失时 JavaVM 注入中断 → mediacodec 硬解不可用 → 播放失败。
	apply_patches "$D/mpv" "$B/patches/mpv"
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
	# 构建后硬校验：media_kit 启动要查这个符号，缺了必播放失败。
	# （不用 grep -q：pipefail 下它首个匹配就退出会给 nm 造成 SIGPIPE 误报）
	if ! llvm-nm -D --defined-only "$PREFIX/lib/libmpv.so" 2>/dev/null | grep mpv_lavc_set_java_vm > /dev/null; then
		echo "✗ libmpv.so 未导出 mpv_lavc_set_java_vm —— mpv 补丁没打上！" >&2
		echo "  检查 $B/patches/mpv/*.patch 是否存在、apply_patches 是否报错。" >&2
		exit 1
	fi
	echo "✓ 符号核验通过：mpv_lavc_set_java_vm 已导出"
fi

log "全部完成"
echo "libmpv.so："
ls -la "$PREFIX/lib/libmpv.so" 2>/dev/null || echo "  (未生成)"
echo "native 目录："
ls -la "$NATIVE" 2>/dev/null
