#!/usr/bin/env bash

set -e

SSCEP_VER=0.9.0
SSCEP="sscep-${SSCEP_VER}"
PKG_URL="https://github.com/certnanny/sscep/archive/refs/tags/v${SSCEP_VER}.tar.gz"
PKG_MIRROR_URL="https://files.phoesys.com/ports/${SSCEP}.tar.gz"

b_log "Building sscep"
PREFIX_SSCEP=${PREFIX_PROJECT}/phoenix-rtos-ports/sscep
PREFIX_SSCEP_BUILD=${PREFIX_BUILD}/sscep
PREFIX_SSCEP_SRC="${PREFIX_SSCEP_BUILD}/${SSCEP}"
PREFIX_SSCEP_MARKERS="${PREFIX_SSCEP_BUILD}/markers"
PREFIX_SSCEP_INSTALL="${PREFIX_SSCEP_BUILD}/install"

#
# Download and unpack
#
mkdir -p "$PREFIX_SSCEP_BUILD"

if [ ! -f "$PREFIX_SSCEP/${SSCEP}.tar.gz" ]; then
	if ! wget "$PKG_URL" -O "${PREFIX_SSCEP}/${SSCEP}.tar.gz" --no-check-certificate; then
		wget "$PKG_MIRROR_URL" -P "${PREFIX_SSCEP}" --no-check-certificate
	fi
fi
[ -d "$PREFIX_SSCEP_SRC" ] || tar zxf "$PREFIX_SSCEP/${SSCEP}.tar.gz" -C "$PREFIX_SSCEP_BUILD"

#
# Apply patches
#
mkdir -p "$PREFIX_SSCEP_MARKERS"

for patchfile in "${PREFIX_SSCEP}"/patches/*.patch; do
	if [ ! -f "${PREFIX_SSCEP_MARKERS}/$(basename "$patchfile").applied" ]; then
		echo "applying patch: $patchfile"
		patch -d "$PREFIX_SSCEP_SRC" -p1 < "$patchfile"
		touch "${PREFIX_SSCEP_MARKERS}/$(basename "$patchfile").applied"
	fi
done

#
# Make
#
mkdir -p "$PREFIX_SSCEP_INSTALL"

pushd "$PREFIX_SSCEP_SRC"
[ -f "${PREFIX_SSCEP_SRC}/configure" ] || ./bootstrap.sh
[ -f "${PREFIX_SSCEP_SRC}/Makefile" ] || ./configure --disable-shared --prefix="" --host="$HOST" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" PKG_CONFIG_LIBDIR="${PREFIX_BUILD}/lib/pkgconfig"
make install DESTDIR="$PREFIX_SSCEP_INSTALL"
popd

cp -a "${PREFIX_SSCEP_INSTALL}/bin/sscep" "${PREFIX_PROG}/sscep"
$STRIP -s "${PREFIX_PROG}/sscep" -o "${PREFIX_PROG_STRIPPED}/sscep"
b_install "${PREFIX_PORTS_INSTALL}/sscep" /usr/bin
