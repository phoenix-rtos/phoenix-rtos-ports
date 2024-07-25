#!/usr/bin/env bash

set -e

OPENVPN=openvpn-2.4.7
PKG_URL="https://swupdate.openvpn.org/community/releases/${OPENVPN}.tar.gz"
PKG_MIRROR_URL="https://files.phoesys.com/ports/${OPENVPN}.tar.gz"

PREFIX_OPENVPN_SRC="${PREFIX_PORT_BUILD}/${OPENVPN}"
PREFIX_OPENVPN_MARKERS="${PREFIX_PORT_BUILD}/markers"

#
# Download and unpack
#
mkdir -p "$PREFIX_PORT_BUILD" "$PREFIX_OPENVPN_MARKERS"
if [ ! -f "$PREFIX_PORT/${OPENVPN}.tar.gz" ]; then
	if ! wget "$PKG_URL" -P "${PREFIX_PORT}" --no-check-certificate; then
		wget "$PKG_MIRROR_URL" -P "${PREFIX_PORT}" --no-check-certificate
	fi
fi
[ -d "$PREFIX_OPENVPN_SRC" ] || tar zxf "$PREFIX_PORT/${OPENVPN}.tar.gz" -C "$PREFIX_PORT_BUILD"

#
#  Apply patches
#
for patchfile in "$PREFIX_PORT"/*.patch; do
	if [ ! -f "$PREFIX_OPENVPN_MARKERS/$(basename "$patchfile").applied" ]; then
		echo "applying patch: $patchfile"
		patch -d "$PREFIX_OPENVPN_SRC" -p1 < "$patchfile"
		touch "$PREFIX_OPENVPN_MARKERS/$(basename "$patchfile").applied"
	fi
done

#
# Configure
#
if [ ! -f "$PREFIX_PORT_BUILD/config.h" ]; then
	OPENVPN_CFLAGS="-std=gnu99 -I${PREFIX_H}"
	(cd "$PREFIX_OPENVPN_SRC" && autoreconf -i -v -f)
	(cd "$PREFIX_PORT_BUILD" && PKG_CONFIG="" "$PREFIX_OPENVPN_SRC/configure" CFLAGS="$CFLAGS $OPENVPN_CFLAGS" LDFLAGS="$LDFLAGS" --host="${HOST}" --sbindir="$PREFIX_PROG")
fi

#
# Make
#
make -C "$PREFIX_PORT_BUILD"
make -C "$PREFIX_PORT_BUILD" install-exec

$STRIP -o "$PREFIX_PROG_STRIPPED/openvpn" "$PREFIX_PROG/openvpn"
b_install "$PREFIX_PORTS_INSTALL/openvpn" /sbin/
