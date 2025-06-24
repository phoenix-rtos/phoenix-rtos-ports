#!/usr/bin/env bash

set -e

CURL=curl-7.64.1
PKG_URL="https://curl.haxx.se/download/${CURL}.tar.gz"
PKG_MIRROR_URL="https://files.phoesys.com/ports/${CURL}.tar.gz"

PREFIX_CURL_SRC="${PREFIX_PORT_BUILD}/${CURL}"
PREFIX_CURL_INSTALL="$PREFIX_PORT_BUILD/install"

#
# Download and unpack
#
mkdir -p "$PREFIX_PORT_BUILD" "$PREFIX_CURL_INSTALL"
if [ ! -f "$PREFIX_PORT/${CURL}.tar.gz" ]; then
	if ! wget "$PKG_URL" -P "${PREFIX_PORT}" --no-check-certificate; then
		wget "$PKG_MIRROR_URL" -P "${PREFIX_PORT}" --no-check-certificate
	fi
fi
[ -d "$PREFIX_CURL_SRC" ] || tar zxf "$PREFIX_PORT/${CURL}.tar.gz" -C "$PREFIX_PORT_BUILD"


#
# Configure
#
CONFIGURE_PARAMS=(--host="${HOST}" --sbindir="$PREFIX_PROG" --disable-pthreads --disable-threaded-resolver \
		--disable-ipv6 --prefix="$PREFIX_CURL_INSTALL" --disable-ntlm-wb --without-zlib)

[[ "$PORTS_CURL_USE_MBEDTLS" = "y" ]] && CONFIGURE_PARAMS+=( --without-ssl --with-mbedtls )

if [ ! -f "$PREFIX_PORT_BUILD/config.status" ]; then
	( cd "$PREFIX_PORT_BUILD" && PKG_CONFIG="" "$PREFIX_CURL_SRC/configure" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
	"${CONFIGURE_PARAMS[@]}")
fi

#
# Make
#
make -C "$PREFIX_PORT_BUILD"
make -C "$PREFIX_PORT_BUILD" install

cp -a "$PREFIX_CURL_INSTALL/include/curl" "$PREFIX_H"
cp -a "$PREFIX_CURL_INSTALL/lib/"* "$PREFIX_A"
cp -a "$PREFIX_CURL_INSTALL/bin/curl" "$PREFIX_PROG/curl"
$STRIP -o "$PREFIX_PROG_STRIPPED/curl" "$PREFIX_PROG/curl"
b_install "$PREFIX_PORTS_INSTALL/curl" /usr/bin/
