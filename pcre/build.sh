#!/usr/bin/env bash

set -e

PCRE=pcre-8.42
PKG_URL="http://ftp.exim.org/pub/pcre/${PCRE}.tar.bz2"
PKG_MIRROR_URL="https://files.phoesys.com/ports/${PCRE}.tar.bz2"

PREFIX_PCRE_SRC="${PREFIX_PORT_BUILD}/${PCRE}"

#
# Download and unpack
#
mkdir -p "$PREFIX_PORT_BUILD"
if [ ! -f "$PREFIX_PORT/${PCRE}.tar.bz2" ]; then
	if ! wget "$PKG_URL" -P "${PREFIX_PORT}" --no-check-certificate; then
		wget "$PKG_MIRROR_URL" -P "${PREFIX_PORT}" --no-check-certificate
	fi
fi
[ -d "$PREFIX_PCRE_SRC" ] || tar jxf "$PREFIX_PORT/${PCRE}.tar.bz2" -C "$PREFIX_PORT_BUILD"


#
# Configure
#
if [ ! -f "${PREFIX_PORT_BUILD}/config.h" ]; then
	( cd "${PREFIX_PORT_BUILD}" && "${PREFIX_PCRE_SRC}/configure" CFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS}" ARFLAGS="-r" --enable-static --disable-shared --host="$HOST" \
		--disable-cpp --prefix="${PREFIX_PORT_BUILD}" --libdir="${PREFIX_A}"  \
		--includedir="${PREFIX_H}" )
fi

#
# Make
#
make -C "$PREFIX_PORT_BUILD" install
