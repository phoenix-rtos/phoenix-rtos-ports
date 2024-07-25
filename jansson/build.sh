#!/usr/bin/env bash

set -e

JANSSON=jansson-2.12
PKG_URL="http://www.digip.org/jansson/releases/${JANSSON}.tar.bz2"
PKG_MIRROR_URL="https://files.phoesys.com/ports/${JANSSON}.tar.bz2"

PREFIX_JANSSON_SRC="${PREFIX_PORT_BUILD}/${JANSSON}"

#
# Download and unpack
#
mkdir -p "$PREFIX_PORT_BUILD"
if [ ! -f "$PREFIX_PORT/${JANSSON}.tar.bz2" ]; then
	if ! wget "$PKG_URL" -P "${PREFIX_PORT}" --no-check-certificate; then
		wget "$PKG_MIRROR_URL" -P "${PREFIX_PORT}" --no-check-certificate
	fi
fi
[ -d "$PREFIX_JANSSON_SRC" ] || tar jxf "$PREFIX_PORT/${JANSSON}.tar.bz2" -C "$PREFIX_PORT_BUILD"


#
# Configure
#
# hacks for incremental build:
# - use "install -p" to preserve timestamps in headers
# - use "echo" instead of "ranlib" to not overwrite static lib with every recompile (note: using ar -s while linking instead)
if [ ! -f "$PREFIX_PORT_BUILD/config.status" ]; then
	( cd "${PREFIX_PORT_BUILD}" && "${PREFIX_JANSSON_SRC}/configure" CFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS}" ARFLAGS="\"-r -s\"" RANLIB="echo" INSTALL="$(which install) -p" \
		--enable-static --disable-shared --host="$HOST" \
		--prefix="${PREFIX_PORT_BUILD}" --libdir="${PREFIX_BUILD}/lib" \
		--includedir="${PREFIX_BUILD}/include" )

fi

#
# Make
#
make -C "$PREFIX_PORT_BUILD" install
