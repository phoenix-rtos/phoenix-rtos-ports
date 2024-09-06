#!/usr/bin/env bash

set -e

PREFIX_X264="${PREFIX_PROJECT}/phoenix-rtos-ports/x264"
PREFIX_X264_BUILD="${PREFIX_BUILD}/x264"
PREFIX_X264_CONFIG="${PREFIX_X264}/patches"
PREFIX_X264_MARKERS="${PREFIX_X264_BUILD}/markers"

PKG_COMMIT="31e19f92f00c7003fa115047ce50978bc98c3a0d"
PKG_NAME="x264-${PKG_COMMIT}.tar.gz"
PKG_URL="https://code.videolan.org/videolan/x264/-/archive/${PKG_COMMIT}"

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
	tar -xf "${PREFIX_X264}/${PKG_NAME}" -C "${PREFIX_BUILD}"
	(cd "${PREFIX_BUILD}" && mv "${PKG_NAME%.tar.gz}" x264)
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
# Run configuration script
# 
CFG_OPT="--host=arm-linux --enable-pic --enable-static "   # mimic linux platform, enable position independent code, and generate libx264.a
CFG_OPT+="--disable-avs --disable-lavf  --disable-opencl " # these options force dynamic linking, thus they're disabled.

#TODO: rewrite parts of x264/common/cpu.c to support Phoenix-RTOS multithreading
# x264 implementation uses GNU specific processor counting method for multithreading.
# Remove this flag and see where compilation stops to start working on it.
CFG_OPT+="--disable-thread " 

# TODO: enable platform specific assembly optimization code 
# asm optimization code generation causes build script to silent-crash. This was not investigated in-depth.
CFG_OPT+="--disable-asm "
(cd "$PREFIX_X264_BUILD" && ./configure --extra-cflags="$CFLAGS_EXTRA" --extra-ldflags="$LDFLAGS_EXTRA" --cross-prefix="$CROSS" --sysroot="$PREFIX_BUILD/sysroot/" $CFG_OPT)

#
# Build and install x264 binary
#
(cd "$PREFIX_X264_BUILD" && make)

cp -a "${PREFIX_X264_BUILD}/x264" "$PREFIX_PROG_STRIPPED"
b_install "$PREFIX_PORTS_INSTALL/x264" /bin/
