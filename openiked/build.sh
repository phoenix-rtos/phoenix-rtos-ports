#!/usr/bin/env bash

set -e

OPENIKED=openiked-portable-6.9.0

b_log "Building openiked"
PREFIX_OPENIKED=${TOPDIR}/phoenix-rtos-ports/openiked
PREFIX_OPENIKED_BUILD=${PREFIX_BUILD}/openiked
PREFIX_OPENIKED_SRC="${PREFIX_OPENIKED_BUILD}/${OPENIKED}"
PREFIX_OPENIKED_MARKERS="${PREFIX_OPENIKED_BUILD}/markers"
PREFIX_OPENIKED_INSTALL="${PREFIX_OPENIKED_BUILD}/install"

#
# Download and unpack
#
mkdir -p "$PREFIX_OPENIKED_BUILD"

[ -f "${PREFIX_OPENIKED}/v6.9.0.tar.gz" ] || wget https://github.com/openiked/openiked-portable/archive/refs/tags/v6.9.0.tar.gz -P "$PREFIX_OPENIKED" --no-check-certificate
[ -d "$PREFIX_OPENIKED_SRC" ] || tar zxf "${PREFIX_OPENIKED}/v6.9.0.tar.gz" -C "$PREFIX_OPENIKED_BUILD"

#
# Apply patches
#
mkdir -p "$PREFIX_OPENIKED_MARKERS"

for patchfile in "${PREFIX_OPENIKED}"/patches/*.patch; do
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
"${CROSS}strip" -s "${PREFIX_PROG}/ikectl" -o "${PREFIX_PROG_STRIPPED}/ikectl"
"${CROSS}strip" -s "${PREFIX_PROG}/iked" -o "${PREFIX_PROG_STRIPPED}/iked"
b_install "${PREFIX_PORTS_INSTALL}/ikectl" /usr/bin
b_install "${PREFIX_PORTS_INSTALL}/iked" /usr/bin
