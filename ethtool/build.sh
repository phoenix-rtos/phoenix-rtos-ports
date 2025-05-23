#!/usr/bin/env bash

set -e

ETHTOOL=ethtool-6.14
PKG_URL="https://ftp.ntu.edu.tw/pub/software/network/ethtool/${ETHTOOL}.tar.gz"
# TODO: add mirror URL
# PKG_MIRROR_URL="https://files.phoesys.com/ports/${ETHTOOL}.tar.gz"

PREFIX_ETHTOOL_SRC="${PREFIX_PORT_BUILD}/${ETHTOOL}"
PREFIX_ETHTOOL_MARKERS="${PREFIX_PORT_BUILD}/markers/"
PREFIX_ETHTOOL_INSTALL="${PREFIX_PORT_BUILD}/install"

#
# Download and unpack
#
mkdir -p "$PREFIX_PORT_BUILD"

if [ ! -f "${PREFIX_PORT}/${ETHTOOL}.tar.gz" ]; then
	if ! wget "$PKG_URL" -P "${PREFIX_PORT}" --no-check-certificate; then
		# TODO: add ethtool to mirror
		exit -1 # wget "$PKG_MIRROR_URL" -o "${PREFIX_ETHTOOL_SRC}.tar.gz" -P "${PREFIX_PORT}" --no-check-certificate
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

# changing LDFLAGS from "ld" params format to "gcc" params - prefixing with -Wl, and changing spaces to colons
LDFLAGS="${CFLAGS} $LDFLAGS"

cd "${PREFIX_ETHTOOL_SRC}"

#
# Autogen
#
if [ ! -f "${PREFIX_ETHTOOL_SRC}/configure" ]; then
	./autogen.sh
fi

#
# Configure
#
if [ ! -f "${PREFIX_ETHTOOL_SCR}/Makefile" ]; then
	./configure --host="phoenix-${TARGET_FAMILY}-${TARGET_SUBFAMILY}" --prefix="${PREFIX_ETHTOOL_INSTALL}" --disable-netlink
fi

#
# Make
#

make -C "$PREFIX_ETHTOOL_SRC"
make -C "$PREFIX_ETHTOOL_SRC" install

cp -a "$PREFIX_ETHTOOL_INSTALL/sbin/ethtool"  "$PREFIX_PROG"
$STRIP -o "$PREFIX_PROG_STRIPPED/ethtool" "$PREFIX_PROG/ethtool"
b_install "$PREFIX_PORTS_INSTALL/ethtool" /usr/bin/
