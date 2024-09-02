#!/usr/bin/env bash

set -e

PREFIX_X264="${PREFIX_PROJECT}/phoenix-rtos-ports/x264"
PREFIX_X264_BUILD="${PREFIX_BUILD}/x264"
PREFIX_X264_CONFIG="${PREFIX_X264}/patches"
PREFIX_X264_MARKERS="$PREFIX_X264_BUILD/markers"

b_log "Building x264"

#
# Download and unpack
#
if [ ! -d "$PREFIX_X264_BUILD" ]; then
	if ! git clone https://code.videolan.org/videolan/x264.git "$PREFIX_X264_BUILD"; then
        echo "No mirror available"
        exit 1
	fi
    (cd "$PREFIX_X264_BUILD" && git checkout master && git reset --hard 4613ac3c15fd75cebc4b9f65b7fb95e70a3acce1)
    mkdir -p "$PREFIX_X264_MARKERS"
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
export LDFLAGS_EXTRA="${CFLAGS} ${LDFLAGS}"
export CFLAGS_EXTRA="${CFLAGS}"
export LDFLAGS=""
export CFLAGS=""

#
# Build and install x264 binary
#
(cd "$PREFIX_X264_BUILD" && ./configure --extra-cflags="$CFLAGS_EXTRA" --extra-ldflags="$LDFLAGS_EXTRA" --cross-prefix="$CROSS" --sysroot="$PREFIX_BUILD/sysroot/" --host=arm-linux --disable-asm --disable-avs --disable-lavf --enable-pic --enable-static --disable-opencl)
(cd "$PREFIX_X264_BUILD" && make)

cp -a "${PREFIX_X264_BUILD}/x264" "$PREFIX_PROG_STRIPPED"
b_install "$PREFIX_PORTS_INSTALL/x264" /bin/
