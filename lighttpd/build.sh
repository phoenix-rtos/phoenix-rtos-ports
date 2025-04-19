#!/usr/bin/env bash

set -e

LIGHTTPD="lighttpd-1.4.79"
PKG_URL="https://download.lighttpd.net/lighttpd/releases-1.4.x/${LIGHTTPD}.tar.gz"
PKG_MIRROR_URL="https://files.phoesys.com/ports/${LIGHTTPD}.tar.gz"

PREFIX_PORT_SRC="${PREFIX_PORT_BUILD}/${LIGHTTPD}"
PREFIX_LIGHTTPD_MARKERS="$PREFIX_PORT_BUILD/markers/"

PREFIX_OPENSSL=${PREFIX_BUILD}
PREFIX_PCRE=${PREFIX_BUILD}

#
# Download and unpack
#
mkdir -p "$PREFIX_PORT_BUILD" "$PREFIX_LIGHTTPD_MARKERS"
if [ ! -f "$PREFIX_PORT/${LIGHTTPD}.tar.gz" ]; then
	if ! wget "$PKG_URL" -P "${PREFIX_PORT}" --no-check-certificate; then
		wget "$PKG_MIRROR_URL" -P "${PREFIX_PORT}" --no-check-certificate
	fi
fi
[ -d "$PREFIX_PORT_SRC" ] || tar zxf "$PREFIX_PORT/${LIGHTTPD}.tar.gz" -C "$PREFIX_PORT_BUILD"

#
# Apply patches
#
for patchfile in "${PREFIX_PORT}"/patches/*.patch; do
	if [ ! -f "$patchfile" ]; then
		continue;
	fi
	if [ ! -f "$PREFIX_LIGHTTPD_MARKERS/$(basename "$patchfile").applied" ]; then
		echo "applying patch: $patchfile"
		patch -d "$PREFIX_PORT_SRC" -p1 < "$patchfile"
		touch "$PREFIX_LIGHTTPD_MARKERS/$(basename "$patchfile").applied"
	fi
done

#
# Configure
#
if [ ! -f "$PREFIX_PORT_BUILD/config.h" ]; then
	# FIXME: take into account commented-out modules
	CONFIGFILE=$(find "${PREFIX_ROOTFS:?PREFIX_ROOTFS not set!}/etc" -name "lighttpd.conf")
	grep mod_ "$CONFIGFILE" | cut -d'"' -f2 | xargs -L1 -I{} echo "PLUGIN_INIT({})" > "$PREFIX_PORT_SRC"/src/plugin-static.h

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
