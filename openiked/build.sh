#!/usr/bin/env bash

set -e

OPENIKED_VER=6.9.0
OPENIKED="openiked-portable-${OPENIKED_VER}"
PKG_URL="https://github.com/openiked/openiked-portable/archive/refs/tags/v${OPENIKED_VER}.tar.gz"
PKG_MIRROR_URL="https://files.phoesys.com/ports/${OPENIKED}.tar.gz"

PREFIX_OPENIKED_SRC="${PREFIX_PORT_BUILD}/${OPENIKED}"
PREFIX_OPENIKED_MARKERS="${PREFIX_PORT_BUILD}/markers"
PREFIX_OPENIKED_INSTALL="${PREFIX_PORT_BUILD}/install"

#
# Download and unpack
#
mkdir -p "$PREFIX_PORT_BUILD"

if [ ! -f "${PREFIX_PORT}/${OPENIKED}.tar.gz" ]; then
	if ! wget "$PKG_URL" -O "${PREFIX_PORT}/${OPENIKED}.tar.gz" --no-check-certificate; then
		wget "$PKG_MIRROR_URL" -P "${PREFIX_PORT}" --no-check-certificate
	fi
fi
[ -d "$PREFIX_OPENIKED_SRC" ] || tar zxf "${PREFIX_PORT}/${OPENIKED}.tar.gz" -C "$PREFIX_PORT_BUILD"

#
# Apply patches
#
mkdir -p "$PREFIX_OPENIKED_MARKERS"

for patchfile in "${PREFIX_PORT}"/patches/*.patch; do
    if [ ! -f "${PREFIX_OPENIKED_MARKERS}/$(basename "$patchfile").applied" ]; then
        echo "applying patch: $patchfile"
        patch -d "$PREFIX_OPENIKED_SRC" -p1 < "$patchfile"
        touch "${PREFIX_OPENIKED_MARKERS}/$(basename "$patchfile").applied"
    fi
done

#
# Make
#
mkdir -p "$PREFIX_OPENIKED_INSTALL"

pushd "$PREFIX_OPENIKED_SRC"
mkdir -p build
cd build
CFLAGS="-D__linux__ ${CFLAGS}"
cmake -DCMAKE_SYSTEM_NAME=Linux -DCMAKE_BUILD_TYPE=Release ..
make -j 1 install DESTDIR="$PREFIX_OPENIKED_INSTALL"
popd

cp -a "${PREFIX_OPENIKED_INSTALL}/usr/local/sbin/ikectl" "${PREFIX_PROG}/ikectl"
cp -a "${PREFIX_OPENIKED_INSTALL}/usr/local/sbin/iked" "${PREFIX_PROG}/iked"
$STRIP -o "${PREFIX_PROG_STRIPPED}/ikectl" "${PREFIX_PROG}/ikectl"
$STRIP -o "${PREFIX_PROG_STRIPPED}/iked" "${PREFIX_PROG}/iked"
b_install "${PREFIX_PORTS_INSTALL}/ikectl" /usr/bin
b_install "${PREFIX_PORTS_INSTALL}/iked" /usr/bin
