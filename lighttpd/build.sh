#!/usr/bin/env bash

set -e

PKG_NAME=lighttpd
PKG_VERSION=1.4.79
PKG_SOURCE=${PKG_NAME}-${PKG_VERSION}.tar.xz
PKG_SOURCE_URL="https://download.lighttpd.net/lighttpd/releases-1.4.x/"
PKG_BUILD_DIR=${PREFIX_PORT_BUILD}/${PKG_NAME}-${PKG_VERSION}

PREFIX_PORT_SRC="${PKG_BUILD_DIR}"

PREFIX_OPENSSL=${PREFIX_BUILD}
PREFIX_PCRE=${PREFIX_BUILD}

#
# Download, unpack, and apply patches
#
if [ ! -d "$PREFIX_PORT_SRC" ]; then
	b_port_download "$PKG_SOURCE_URL" "$PKG_SOURCE"
	tar xJf "$PREFIX_PORT/$PKG_SOURCE" -C "$PREFIX_PORT_BUILD"
	b_port_apply_patches "$PREFIX_PORT_SRC"
fi

#
# Configure
#
if [ ! -f "$PREFIX_PORT_BUILD/config.h" ]; then
	# Note: using CONFIGFILE from phoenix-rtos-project sample project
	#   is a Phoenix RTOS bootstrap heuristic to populate lighttpd
	#   ${PREFIX_PORT_SRC}/src/plugin-static.h for the static build.
	#   This logic can be replaced with custom list in src/plugin-static.h
	#   and, as needed, appropriate modifications to ./configure below.
	# Note: assumes one "mod_xxxx" per line in lighttpd.conf server.modules
	CONFIGFILE=$(find "${PREFIX_ROOTFS:?PREFIX_ROOTFS not set!}/etc" -name "lighttpd.conf")
	grep '"mod_' "$CONFIGFILE" | grep -v '\s*#' | cut -d'"' -f2 | xargs -L1 -I{} echo "PLUGIN_INIT({})" > "$PREFIX_PORT_SRC"/src/plugin-static.h

	WITH_ZLIB="no" && [ "$PORTS_ZLIB" = "y" ] && WITH_ZLIB="yes"

	( cd "$PREFIX_PORT_SRC" && "./autogen.sh" )
	( cd "$PREFIX_PORT_BUILD" && "$PREFIX_PORT_SRC/configure" \
		CFLAGS="${CFLAGS} -DLIGHTTPD_STATIC" LDFLAGS="${LDFLAGS}" AR_FLAGS="-r" \
		-C --host="$HOST" \
		--prefix="$PREFIX_PORT_BUILD" --sbindir="$PREFIX_PROG" \
		--enable-shared=no --enable-static=yes --disable-shared \
		LIGHTTPD_STATIC=yes \
		--disable-ipv6 --disable-mmap \
		--with-openssl="${PREFIX_OPENSSL}" \
		--with-pcre="${PREFIX_PCRE}" \
		--with-zlib="$WITH_ZLIB" )

	set +e
	ex "+/HAVE_MMAP 1/d" "+/HAVE_MUNMAP 1/d" "+/HAVE_GETRLIMIT 1/d" "+/HAVE_SYS_POLL_H 1/d" \
	   "+/HAVE_SIGACTION 1/d" "+/HAVE_DLFCN_H 1/d" -cwq "$PREFIX_PORT_BUILD/config.h"
	set -e
fi

#
# Make
#

make -C "${PREFIX_PORT_BUILD}" install

$STRIP -o "$PREFIX_PROG_STRIPPED/lighttpd" "$PREFIX_PROG/lighttpd"
b_install "$PREFIX_PORTS_INSTALL/lighttpd" /usr/sbin
