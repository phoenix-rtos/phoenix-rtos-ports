#!/usr/bin/env bash

set -e

LZO=lzo-2.10
PKG_URL="http://www.oberhumer.com/opensource/lzo/download/${LZO}.tar.gz"
PKG_MIRROR_URL="https://files.phoesys.com/ports/${LZO}.tar.gz"

b_log "Building lzo"
PREFIX_LZO="${PREFIX_PROJECT}/phoenix-rtos-ports/lzo"
PREFIX_LZO_BUILD="${PREFIX_BUILD}/lzo"
PREFIX_LZO_SRC="${PREFIX_LZO_BUILD}/${LZO}"

#
# Download and unpack
#
mkdir -p "$PREFIX_LZO_BUILD"
if [ ! -f "$PREFIX_LZO/${LZO}.tar.gz" ]; then
	if ! wget "$PKG_URL" -P "${PREFIX_LZO}" --no-check-certificate; then
		wget "$PKG_MIRROR_URL" -P "${PREFIX_LZO}" --no-check-certificate
	fi
fi
[ -d "$PREFIX_LZO_SRC" ] || tar zxf "$PREFIX_LZO/${LZO}.tar.gz" -C "$PREFIX_LZO_BUILD"

#
# Configure
#
if [ ! -f "$PREFIX_LZO_BUILD/config.h" ]; then
	 ( cd "$PREFIX_LZO_BUILD" && "$PREFIX_LZO_SRC/configure" --prefix="$PREFIX_LZO_BUILD" --exec-prefix="$PREFIX_LZO_BUILD" --libdir="$PREFIX_A" --includedir="$PREFIX_H" \
		 --host="${HOST}"  CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" )
fi

make -C "$PREFIX_LZO_BUILD" install
