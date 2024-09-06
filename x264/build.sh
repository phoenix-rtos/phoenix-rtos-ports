#!/usr/bin/env bash

set -e

PREFIX_X264="${PREFIX_PROJECT}/phoenix-rtos-ports/x264"
PREFIX_X264_BUILD="${PREFIX_BUILD}/x264"
PREFIX_X264_CONFIG="${PREFIX_X264}/patches"
PREFIX_X264_MARKERS="${PREFIX_X264_BUILD}/markers"

PKG_NAME="x264-master.tar.bz2"
PKG_URL="https://code.videolan.org/videolan/x264/-/archive/master"

b_log "Building x264"

#
# Download archived source code
#
if [ ! -f "$PREFIX_X264/${PKG_NAME}" ]; then
	if ! wget "${PKG_URL}/${PKG_NAME}" -O "${PREFIX_X264}/${PKG_NAME}" --no-check-certificate; then
		echo "Mirror unavailable"
		exit 1
	fi
fi

#
# Unpack source code
#
if [ ! -d "${PREFIX_X264_BUILD}" ]; then
	tar -xjf "${PREFIX_X264}/${PKG_NAME}" -C "${PREFIX_BUILD}"
	(cd "${PREFIX_BUILD}" && mv x264-master x264)
	mkdir -p "${PREFIX_X264_MARKERS}"
fi

#
# Apply patches
#
for patchfile in "$PREFIX_X264_CONFIG"/*.patch; do
	if [ ! -f "$PREFIX_X264_MARKERS/$(basename "$patchfile").applied" ]; then
		echo "applying patch: $patchfile"
		patch -d "$PREFIX_X264_BUILD" -p1 < "$patchfile"
		touch "$PREFIX_X264_MARKERS/$(basename "$patchfile").applied"
	fi
done

#
# Prepare CFLAGS and LDFLAGS for x264 configure & Makefile
# 
export LDFLAGS_EXTRA="${CFLAGS} ${LDFLAGS} -Wl,-z,stack-size=65536"
export CFLAGS_EXTRA="${CFLAGS}"
export LDFLAGS=""
export CFLAGS=""

#
# Build and install x264 binary
#
(cd "$PREFIX_X264_BUILD" && ./configure --extra-cflags="$CFLAGS_EXTRA" --extra-ldflags="$LDFLAGS_EXTRA" --cross-prefix="$CROSS" --sysroot="$PREFIX_BUILD/sysroot/" --disable-thread --host=arm-linux --disable-asm --disable-avs --disable-lavf --enable-pic --enable-static --disable-opencl)
(cd "$PREFIX_X264_BUILD" && make)

cp -a "${PREFIX_X264_BUILD}/x264" "$PREFIX_PROG_STRIPPED"
b_install "$PREFIX_PORTS_INSTALL/x264" /bin/
