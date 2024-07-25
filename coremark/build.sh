#!/usr/bin/env bash

set -e

COREMARK_VER="1.0"
COREMARK=coremark-${COREMARK_VER}
COREMARK_COMMIT="d5fad6bd094899101a4e5fd53af7298160ced6ab"
PKG_URL="https://github.com/eembc/coremark/archive/${COREMARK_COMMIT}.tar.gz"
PKG_MIRROR_URL="https://files.phoesys.com/ports/${COREMARK}.tar.gz"

PREFIX_COREMARK_SRC="${PREFIX_PORT_BUILD}/${COREMARK}"
PREFIX_COREMARK_MARKERS="${PREFIX_PORT_BUILD}/markers"

#
# Download and unpack
#
mkdir -p "$PREFIX_PORT_BUILD"
if ! [ -f "${PREFIX_PORT}/${COREMARK}.tar.gz" ]; then
	if ! wget "$PKG_URL" -O "${PREFIX_PORT}/${COREMARK}.tar.gz" --no-check-certificate; then
		wget "$PKG_MIRROR_URL" -P "${PREFIX_PORT}" --no-check-certificate
	fi
fi

if ! [ -d "${PREFIX_COREMARK_SRC}" ]; then
	tar xzf "${PREFIX_PORT}/${COREMARK}.tar.gz" -C "${PREFIX_PORT_BUILD}" && mv "${PREFIX_PORT_BUILD}"/coremark-"${COREMARK_COMMIT}" "${PREFIX_PORT_BUILD}"/${COREMARK}
fi

#
# Apply patches
#
mkdir -p "$PREFIX_COREMARK_MARKERS"

for patchfile in "$PREFIX_PORT"/*.patch; do
	if [ ! -f "$PREFIX_PORT_BUILD/markers/$(basename "$patchfile").applied" ]; then
		echo "applying patch: $patchfile"
		patch -d "$PREFIX_COREMARK_SRC" -p1 < "$patchfile"
		touch "$PREFIX_COREMARK_MARKERS/$(basename "$patchfile").applied"
	fi
done

#
# Configure
#
mkdir -p "${PREFIX_PORT_BUILD}/${COREMARK}/phoenix"
cp -a "$PREFIX_PORT/core-portme.mak" "$PREFIX_PORT_BUILD/${COREMARK}/phoenix/core_portme.mak"

cd "${PREFIX_PORT_BUILD}/${COREMARK}"

if [ -z ${PORTS_COREMARK_THREADS+x} ]; then
	PORTS_COREMARK_THREADS="1"
fi

export XCFLAGS="${CFLAGS} -DUSE_PTHREAD -DMULTITHREAD=${PORTS_COREMARK_THREADS} ${LDFLAGS}"

# Build coremark
PORT_DIR=phoenix make compile

cp -a "$PREFIX_PORT_BUILD/${COREMARK}/coremark" "$PREFIX_PROG/coremark"
$STRIP -o "${PREFIX_PROG_STRIPPED}/coremark" "${PREFIX_PROG}/coremark"
b_install "$PREFIX_PORTS_INSTALL/coremark" /bin
