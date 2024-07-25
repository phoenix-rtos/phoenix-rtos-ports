#!/usr/bin/env bash

set -e

LZO=lzo-2.10
PKG_URL="http://www.oberhumer.com/opensource/lzo/download/${LZO}.tar.gz"
PKG_MIRROR_URL="https://files.phoesys.com/ports/${LZO}.tar.gz"

PREFIX_LZO_SRC="${PREFIX_PORT_BUILD}/${LZO}"

#
# Download and unpack
#
mkdir -p "$PREFIX_PORT_BUILD"
if [ ! -f "$PREFIX_PORT/${LZO}.tar.gz" ]; then
	if ! wget "$PKG_URL" -P "${PREFIX_PORT}" --no-check-certificate; then
		wget "$PKG_MIRROR_URL" -P "${PREFIX_PORT}" --no-check-certificate
	fi
fi
[ -d "$PREFIX_LZO_SRC" ] || tar zxf "$PREFIX_PORT/${LZO}.tar.gz" -C "$PREFIX_PORT_BUILD"

#
# Configure
#
if [ ! -f "$PREFIX_PORT_BUILD/config.h" ]; then
	 ( cd "$PREFIX_PORT_BUILD" && "$PREFIX_LZO_SRC/configure" --prefix="$PREFIX_PORT_BUILD" --exec-prefix="$PREFIX_PORT_BUILD" --libdir="$PREFIX_A" --includedir="$PREFIX_H" \
		 --host="${HOST}"  CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" )
fi

make -C "$PREFIX_PORT_BUILD" install
