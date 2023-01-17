#!/usr/bin/env bash

set -e

LIGHTTPD="lighttpd-1.4.53"
PKG_URL="https://download.lighttpd.net/lighttpd/releases-1.4.x/${LIGHTTPD}.tar.gz"
PKG_MIRROR_URL="https://files.phoesys.com/ports/${LIGHTTPD}.tar.gz"

b_log "Building lighttpd"
PREFIX_LIGHTTPD="${PREFIX_PROJECT}/phoenix-rtos-ports/lighttpd"
PREFIX_LIGHTTPD_BUILD="${PREFIX_BUILD}/lighttpd"
PREFIX_LIGHTTPD_SRC="${PREFIX_LIGHTTPD_BUILD}/${LIGHTTPD}"
PREFIX_LIGHTTPD_MARKERS="$PREFIX_LIGHTTPD_BUILD/markers/"

PREFIX_OPENSSL=${PREFIX_BUILD}
PREFIX_PCRE=${PREFIX_BUILD}

#
# Download and unpack
#
mkdir -p "$PREFIX_LIGHTTPD_BUILD" "$PREFIX_LIGHTTPD_MARKERS"
if [ ! -f "$PREFIX_LIGHTTPD/${LIGHTTPD}.tar.gz" ]; then
	if ! wget "$PKG_URL" -P "${PREFIX_LIGHTTPD}" --no-check-certificate; then
		wget "$PKG_MIRROR_URL" -P "${PREFIX_LIGHTTPD}" --no-check-certificate
	fi
fi
[ -d "$PREFIX_LIGHTTPD_SRC" ] || tar zxf "$PREFIX_LIGHTTPD/${LIGHTTPD}.tar.gz" -C "$PREFIX_LIGHTTPD_BUILD"

#
# Apply patches
#
for patchfile in "${PREFIX_LIGHTTPD}"/patches/*.patch; do
	if [ ! -f "$PREFIX_LIGHTTPD_MARKERS/$(basename "$patchfile").applied" ]; then
		echo "applying patch: $patchfile"
		patch -d "$PREFIX_LIGHTTPD_SRC" -p1 < "$patchfile"
		touch "$PREFIX_LIGHTTPD_MARKERS/$(basename "$patchfile").applied"
	fi
done

#
# Configure
#
if [ ! -f "$PREFIX_LIGHTTPD_BUILD/config.h" ]; then
	# FIXME: take into account commented-out modules
	CONFIGFILE=$(find "${PREFIX_ROOTFS:?PREFIX_ROOTFS not set!}/etc" -name "lighttpd.conf")
	grep mod_ "$CONFIGFILE" | cut -d'"' -f2 | xargs -L1 -I{} echo "PLUGIN_INIT({})" > "$PREFIX_LIGHTTPD_SRC"/src/plugin-static.h

	LIGHTTPD_CFLAGS="-DLIGHTTPD_STATIC -DPHOENIX"
	WITH_ZLIB="no" && [ "$PORTS_ZLIB" = "y" ] && WITH_ZLIB="yes"

	( cd "$PREFIX_LIGHTTPD_BUILD" && "$PREFIX_LIGHTTPD_SRC/configure" LIGHTTPD_STATIC=yes CFLAGS="${LIGHTTPD_CFLAGS} ${CFLAGS}" CPPFLAGS="" LDFLAGS="${LDFLAGS}" AR_FLAGS="-r" \
		-C --disable-ipv6 --disable-mmap --with-bzip2=no \
		--with-zlib="$WITH_ZLIB" --enable-shared=no --enable-static=yes --disable-shared  --host="$HOST" --with-openssl="${PREFIX_OPENSSL}" --with-pcre="${PREFIX_PCRE}" \
		--prefix="$PREFIX_LIGHTTPD_BUILD" --sbindir="$PREFIX_PROG")

	set +e
	ex "+/HAVE_MMAP 1/d" "+/HAVE_MUNMAP 1/d" "+/HAVE_GETRLIMIT 1/d" "+/HAVE_SYS_POLL_H 1/d" \
	   "+/HAVE_SIGACTION 1/d" "+/HAVE_DLFCN_H 1/d" -cwq "$PREFIX_LIGHTTPD_BUILD/config.h"
	set -e
fi

#
# Make
#

make -C "${PREFIX_LIGHTTPD_BUILD}" install

"${CROSS}strip" -s "$PREFIX_PROG/lighttpd" -o "$PREFIX_PROG_STRIPPED/lighttpd"
b_install "$PREFIX_PORTS_INSTALL/lighttpd" /usr/sbin
