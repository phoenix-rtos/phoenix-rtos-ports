#!/usr/bin/env bash

set -e

version="${PORTS_HEATSHRINK_VERSION:-0.4.1}"
archive_filename="heatshrink-${version}"
PKG_URL="https://github.com/atomicobject/heatshrink/archive/refs/tags/"
PREFIX_PORT_SRC="${PREFIX_PORT_BUILD}/${archive_filename}"
PREFIX_HEATSHRINK_INSTALL="${PREFIX_PORT_BUILD}/install"

b_port_download "${PKG_URL}" "${archive_filename}.tar.gz" "v${version}.tar.gz"

if [ ! -d "${PREFIX_PORT_SRC}" ]; then
	echo "Extracting sources from ${archive_filename}.tar.gz"
	mkdir -p "${PREFIX_PORT_SRC}"
	tar -axf "${PREFIX_PORT}/${archive_filename}.tar.gz" --strip-components 1 -C "${PREFIX_PORT_SRC}"
fi

# Copy custom config.h
if [ -n "$PORTS_HEATSHRINK_CONFIG_DIR" ] && [ -f "${PORTS_HEATSHRINK_CONFIG_DIR}/config.h" ]; then
	if ! cmp -s "${PORTS_HEATSHRINK_CONFIG_DIR}/config.h" "${PREFIX_PORT_SRC}/heatshrink_config.h"; then
		echo "copying config.h"
		cp -a "${PORTS_HEATSHRINK_CONFIG_DIR}/config.h" "${PREFIX_PORT_SRC}/heatshrink_config.h"
	fi
fi

mkdir -p "$PREFIX_HEATSHRINK_INSTALL" "$PREFIX_HEATSHRINK_INSTALL/bin" "$PREFIX_HEATSHRINK_INSTALL/lib" "$PREFIX_HEATSHRINK_INSTALL/include"

pushd "${PREFIX_PORT_SRC}"
make install PREFIX="$PREFIX_HEATSHRINK_INSTALL" OPTIMIZE="-Os"
popd

# Copy built libraries and heatshrink header files to `lib` and `include` dirs
cp -a "$PREFIX_HEATSHRINK_INSTALL/lib"/* "${PREFIX_A}"
cp -a "$PREFIX_HEATSHRINK_INSTALL/include"/* "${PREFIX_H}"

# Strip and install heatshrink binary
cp -a "${PREFIX_HEATSHRINK_INSTALL}/bin/"* "$PREFIX_PROG"
$STRIP -o "$PREFIX_PROG_STRIPPED/heatshrink" "${PREFIX_PROG}/heatshrink"
b_install "${PREFIX_PORTS_INSTALL}/heatshrink" /usr/bin
