#!/bin/bash
# 下载 build-inline.sh 需要的全部依赖源码到 build-scripts/deps/（幂等）。
#
# * 版本号统一从 depinfo.sh 读取，不在此处硬编码。
# * 源一律走 GitHub：gitlab.freedesktop.org 有 Anubis 反爬挑战，
#   CI/无浏览器环境下 git clone 会被拦（README 踩坑记录）。
# * 可重复执行：目录已存在即跳过。
#
# 用法：bash fetch-deps.sh
set -euo pipefail

B="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=depinfo.sh
. "$B/depinfo.sh"
D="$B/deps"
mkdir -p "$D"

log() { echo ""; echo "── $* ──"; }

# 网络不稳（GitHub git/asset 下载偶发 stall）→ 统一 3 次重试。
retry() { # <描述> <cmd...>
	local desc="$1" attempt
	shift
	for attempt in 1 2 3; do
		if "$@"; then
			return 0
		fi
		echo "✗ $desc 第 $attempt 次失败，5s 后重试…" >&2
		sleep 5
	done
	echo "✗ $desc 重试 3 次仍失败" >&2
	return 1
}

have() {
	if [ -e "$D/$1" ]; then
		echo "已有 $1，跳过"
		return 0
	fi
	return 1
}

clone_git() { # <dir> <url> <ref(tag/branch)>
	have "$1" && return 0
	log "git clone $1 @ $3"
	rm -rf "$D/$1.tmp"
	retry "clone $1" git clone --depth 1 -b "$3" "$2" "$D/$1.tmp"
	mv "$D/$1.tmp" "$D/$1"
}

clone_sha() { # <dir> <url> <commit-sha>
	have "$1" && return 0
	log "git fetch $1 @ $3"
	rm -rf "$D/$1.tmp"
	git init -q "$D/$1.tmp"
	git -C "$D/$1.tmp" remote add origin "$2"
	retry "fetch $1" git -C "$D/$1.tmp" fetch --depth 1 origin "$3"
	git -C "$D/$1.tmp" checkout -q FETCH_HEAD
	mv "$D/$1.tmp" "$D/$1"
}

fetch_tar() { # <dir> <url>
	have "$1" && return 0
	log "tarball $1"
	rm -rf "$D/$1.tmp" "$D/$1.archive"
	mkdir -p "$D/$1.tmp"
	retry "download $1" curl -fsSL --connect-timeout 20 --retry 3 \
		-o "$D/$1.archive" "$2"
	tar -xf "$D/$1.archive" -C "$D/$1.tmp" --strip-components=1
	rm -f "$D/$1.archive"
	mv "$D/$1.tmp" "$D/$1"
}

# ── 按 depinfo.sh 的版本拉取 ────────────────────────────────────────────
# expat：发布 tag 是 R_x_y_z（下划线），tarball 自带 configure。
fetch_tar expat "https://github.com/libexpat/libexpat/releases/download/R_$(echo "$v_expat" | tr . _)/expat-$v_expat.tar.bz2"

# freetype：GitHub 官方镜像，tag 形如 VER-2-13-0（v_freetype 本身就是连字符）。
clone_git freetype "https://github.com/freetype/freetype.git" "VER-$v_freetype"

# fribidi / harfbuzz：GitHub release tarball（meson 源码树完整）。
fetch_tar fribidi "https://github.com/fribidi/fribidi/releases/download/v$v_fribidi/fribidi-$v_fribidi.tar.xz"
fetch_tar harfbuzz "https://github.com/harfbuzz/harfbuzz/releases/download/$v_harfbuzz/harfbuzz-$v_harfbuzz.tar.xz"

# fontconfig：GitHub 镜像（gitlab.freedesktop.org 反爬，勿换回去）。
clone_git fontconfig "https://github.com/fontconfig/fontconfig.git" "$v_fontconfig"

clone_git libass "https://github.com/libass/libass.git" "$v_libass"
clone_git dav1d "https://github.com/videolan/dav1d.git" "$v_dav1d"
clone_git mbedtls "https://github.com/Mbed-TLS/mbedtls.git" "v$v_mbedtls"
clone_git libxml2 "https://github.com/GNOME/libxml2.git" "v$v_libxml2"

# ffmpeg：必须 git clone——GitHub 源码 archive 缺 tests/、libav*/Makefile 等
# （.gitattributes export-ignore），configure 会中途报缺文件（README 踩坑记录）。
clone_git ffmpeg "https://github.com/FFmpeg/FFmpeg.git" "n$v_ffmpeg"

# mpv：按 depinfo.sh 记录的完整 commit 拉取（GitHub 允许按 SHA fetch）。
clone_sha mpv "https://github.com/mpv-player/mpv.git" "$v_mpv"

echo ""
echo "✓ 依赖源码就绪：$D"
ls "$D"
