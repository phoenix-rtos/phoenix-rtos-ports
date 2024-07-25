#!/usr/bin/env bash

set -e

ZLIB=zlib-1.2.11
PKG_URL="https://zlib.net/fossils/${ZLIB}.tar.gz"
PKG_MIRROR_URL="https://files.phoesys.com/ports/${ZLIB}.tar.gz"

PREFIX_ZLIB_SRC="${PREFIX_PORT_BUILD}/${ZLIB}"
PREFIX_ZLIB_MARKERS="${PREFIX_PORT_BUILD}/markers"

#
# Download and unpack
#
mkdir -p "$PREFIX_PORT_BUILD"

if [ ! -f "$PREFIX_PORT/${ZLIB}.tar.gz" ]; then
	if ! wget "$PKG_URL" -P "${PREFIX_PORT}" --no-check-certificate; then
		wget "$PKG_MIRROR_URL" -P "${PREFIX_PORT}" --no-check-certificate
	fi
fi
[ -d "$PREFIX_ZLIB_SRC" ] || tar zxf "${PREFIX_PORT}/${ZLIB}.tar.gz" -C "$PREFIX_PORT_BUILD"

#
# Apply patches
#
mkdir -p "$PREFIX_ZLIB_MARKERS"

for patchfile in "${PREFIX_PORT}"/patches/*.patch; do
	if [ ! -f "${PREFIX_ZLIB_MARKERS}/$(basename "$patchfile").applied" ]; then
		echo "applying patch: $patchfile"
		patch -d "$PREFIX_ZLIB_SRC" -p1 < "$patchfile"
		touch "${PREFIX_ZLIB_MARKERS}/$(basename "$patchfile").applied"
	fi
done

# changing LDFLAGS from "ld" params format to "gcc" params - prefixing with -Wl, and changing spaces to colons
LDFLAGS="${CFLAGS} $LDFLAGS"

#
# Make
#
pushd "$PREFIX_ZLIB_SRC"
mkdir -p build
cd build
cmake -DCMAKE_INSTALL_PREFIX="$PREFIX_BUILD" -DCMAKE_BUILD_TYPE=Release -DSKIP_BUILD_EXAMPLES=ON -DSKIP_INSTALL_MAN=ON ..
make install
popd
