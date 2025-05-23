#!/usr/bin/env bash

set -e

version="${PORTS_ETHTOOL_VERSION:-6.14}"
archive_filename="ethtool-${version}.tar.gz"

PREFIX_PORT_SRC="${PREFIX_PORT_BUILD}/${version}"
b_port_download "https://git.kernel.org/pub/scm/network/ethtool/ethtool.git/snapshot/" "${archive_filename}"

if [ ! -d "${PREFIX_PORT_SRC}" ]; then
	echo "Extracting sources from ${archive_filename}"
	mkdir -p "${PREFIX_PORT_SRC}"
	tar -axf "${PREFIX_PORT}/${archive_filename}" --strip-components 1 -C "${PREFIX_PORT_SRC}"
fi

b_port_apply_patches "${PREFIX_PORT_SRC}" "${version}"

#
# Autogen
#
if [ ! -f "${PREFIX_PORT_SRC}/configure" ]; then
	( cd "${PREFIX_PORT_SRC}" && "${PREFIX_PORT_SRC}/autogen.sh" )
fi

#
# Configure
#
if [ ! -f "${PREFIX_PORT_SRC}/Makefile" ]; then
	( cd "${PREFIX_PORT_SRC}" && "${PREFIX_PORT_SRC}/configure" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
		--host="${HOST}" --prefix="${PREFIX_PORTS_INSTALL}" --disable-netlink )
fi

#
# Make
#
make -C "$PREFIX_PORT_SRC"
make -C "$PREFIX_PORT_SRC" install

cp -a "$PREFIX_PORT_SRC/ethtool"  "$PREFIX_PROG/ethtool"
$STRIP -o "$PREFIX_PROG_STRIPPED/ethtool" "$PREFIX_PROG/ethtool"
b_install "$PREFIX_PORTS_INSTALL/ethtool" /usr/bin/
