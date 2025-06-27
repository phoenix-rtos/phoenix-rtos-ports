#!/usr/bin/env bash

set -e

ETHTOOL=ethtool-6.14
PKG_URL="https://git.kernel.org/pub/scm/network/ethtool/ethtool.git/snapshot/${ETHTOOL}.tar.gz"
PKG_MIRROR_URL="https://files.phoesys.com/ports/${ETHTOOL}.tar.gz"

PREFIX_ETHTOOL_SRC="${PREFIX_PORT_BUILD}/${ETHTOOL}"
PREFIX_ETHTOOL_MARKERS="${PREFIX_PORT_BUILD}/markers/"
PREFIX_ETHTOOL_INSTALL="${PREFIX_PORT_BUILD}/install"

#
# Download and unpack
#
mkdir -p "$PREFIX_PORT_BUILD"

if [ ! -f "${PREFIX_PORT}/${ETHTOOL}.tar.gz" ]; then
	if ! wget "$PKG_URL" -P "${PREFIX_PORT}" --no-check-certificate; then
		wget "$PKG_MIRROR_URL" -o "${PREFIX_ETHTOOL_SRC}.tar.gz" -P "${PREFIX_PORT}" --no-check-certificate
	fi
fi
[ -d "$PREFIX_ETHTOOL_SRC" ] || tar zxf "${PREFIX_PORT}/${ETHTOOL}.tar.gz" -C "$PREFIX_PORT_BUILD"

#
# Apply patches
#
mkdir -p "$PREFIX_ETHTOOL_MARKERS"

for patchfile in "${PREFIX_PORT}"/patches/*.patch; do
	if [ ! -f "${PREFIX_ETHTOOL_MARKERS}/$(basename "$patchfile").applied" ]; then
		echo "applying patch: $patchfile"
		patch -d "$PREFIX_ETHTOOL_SRC" -p1 < "$patchfile"
		touch "${PREFIX_ETHTOOL_MARKERS}/$(basename "$patchfile").applied"
	fi
done

#
# Autogen
#
if [ ! -f "${PREFIX_ETHTOOL_SRC}/configure" ]; then
	( cd "${PREFIX_ETHTOOL_SRC}" && "${PREFIX_ETHTOOL_SRC}/autogen.sh" )
fi

#
# Configure
#
if [ ! -f "${PREFIX_ETHTOOL_SRC}/Makefile" ]; then
	( cd "${PREFIX_PORT_BUILD}" && "${PREFIX_ETHTOOL_SRC}/configure" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
		--host="${HOST}" --prefix="${PREFIX_ETHTOOL_INSTALL}" --disable-netlink )
fi

#
# Make
#
make -C "$PREFIX_PORT_BUILD"
make -C "$PREFIX_PORT_BUILD" install

cp -a "$PREFIX_PORT_BUILD/ethtool"  "$PREFIX_PROG/ethtool"
$STRIP -o "$PREFIX_PROG_STRIPPED/ethtool" "$PREFIX_PROG/ethtool"
b_install "$PREFIX_PORTS_INSTALL/ethtool" /usr/bin/
