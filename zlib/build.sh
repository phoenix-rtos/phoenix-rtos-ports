#!/usr/bin/env bash

set -e

ZLIB=zlib-1.2.11

b_log "Building zlib"
PREFIX_ZLIB="${PREFIX_PROJECT}/phoenix-rtos-ports/zlib"
PREFIX_ZLIB_BUILD="${PREFIX_BUILD}/zlib"
PREFIX_ZLIB_SRC="${PREFIX_ZLIB_BUILD}/${ZLIB}"
PREFIX_ZLIB_MARKERS="${PREFIX_ZLIB_BUILD}/markers"

#
# Download and unpack
#
mkdir -p "$PREFIX_ZLIB_BUILD"

[ -f "${PREFIX_ZLIB}/${ZLIB}.tar.gz" ] || wget https://zlib.net/fossils/${ZLIB}.tar.gz -P "$PREFIX_ZLIB" --no-check-certificate
[ -d "$PREFIX_ZLIB_SRC" ] || tar zxf "${PREFIX_ZLIB}/${ZLIB}.tar.gz" -C "$PREFIX_ZLIB_BUILD"

#
# Apply patches
#
mkdir -p "$PREFIX_ZLIB_MARKERS"

for patchfile in "${PREFIX_ZLIB}"/patches/*.patch; do
	if [ ! -f "${PREFIX_ZLIB_MARKERS}/$(basename "$patchfile").applied" ]; then
		echo "applying patch: $patchfile"
		patch -d "$PREFIX_ZLIB_SRC" -p1 < "$patchfile"
		touch "${PREFIX_ZLIB_MARKERS}/$(basename "$patchfile").applied"
	fi
done

# changing LDFLAGS from "ld" params format to "gcc" params - prefixing with -Wl, and changing spaces to colons
LDFLAGS_VAR=$(echo " ${LDFLAGS}" | sed "s/\s/,/g" | sed "s/,-/ -Wl,-/g")
LDFLAGS="${CFLAGS} $LDFLAGS_VAR"

#
# Make
#
pushd "$PREFIX_ZLIB_SRC"
mkdir -p build
cd build
cmake -DCMAKE_INSTALL_PREFIX="$PREFIX_BUILD" -DCMAKE_BUILD_TYPE=Release -DSKIP_BUILD_EXAMPLES=ON -DSKIP_INSTALL_MAN=ON ..
make install
popd
