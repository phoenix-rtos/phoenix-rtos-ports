#!/usr/bin/env bash

set -e

WPA_SUPPLICANT=wpa_supplicant-2.9
PKG_URL="https://w1.fi/releases/${WPA_SUPPLICANT}.tar.gz"
PKG_MIRROR_URL="https://files.phoesys.com/ports/${WPA_SUPPLICANT}.tar.gz"

PREFIX_WPA_SUPPLICANT_SRC="${PREFIX_BUILD}/wpa_supplicant/${WPA_SUPPLICANT}"
PREFIX_WPA_SUPPLICANT_MARKERS="${PREFIX_PORT_BUILD}/markers"
PREFIX_WPA_SUPPLICANT_INSTALL="${PREFIX_PORT_BUILD}/install"

#
# Download and unpack
#
mkdir -p "$PREFIX_PORT_BUILD"

if [ ! -f "$PREFIX_PORT/${WPA_SUPPLICANT}.tar.gz" ]; then
	if ! wget "$PKG_URL" -P "${PREFIX_PORT}" --no-check-certificate; then
		wget "$PKG_MIRROR_URL" -P "${PREFIX_PORT}" --no-check-certificate
	fi
fi
[ -d "$PREFIX_WPA_SUPPLICANT_SRC" ] || tar zxf "${PREFIX_PORT}/${WPA_SUPPLICANT}.tar.gz" -C "$PREFIX_PORT_BUILD"

#
# Apply patches
#
mkdir -p "$PREFIX_WPA_SUPPLICANT_MARKERS"

for patchfile in "${PREFIX_PORT}"/patches/*.patch; do
	if [ ! -f "${PREFIX_WPA_SUPPLICANT_MARKERS}/$(basename "$patchfile").applied" ]; then
		echo "applying patch: $patchfile"
		patch -d "$PREFIX_WPA_SUPPLICANT_SRC" -p1 < "$patchfile"
		touch "${PREFIX_WPA_SUPPLICANT_MARKERS}/$(basename "$patchfile").applied"
	fi
done

#
# Make
#
mkdir -p "$PREFIX_WPA_SUPPLICANT_INSTALL"

pushd "${PREFIX_WPA_SUPPLICANT_SRC}/wpa_supplicant"
cp -a "$PREFIX_PORT/config" .config
make install DESTDIR="$PREFIX_WPA_SUPPLICANT_INSTALL" LIBDIR="/lib" INCDIR="/include" BINDIR="/bin"
popd

cp -a "${PREFIX_WPA_SUPPLICANT_INSTALL}/bin/wpa_cli" "${PREFIX_PROG}/wpa_cli"
cp -a "${PREFIX_WPA_SUPPLICANT_INSTALL}/bin/wpa_supplicant" "${PREFIX_PROG}/wpa_supplicant"
$STRIP -o "${PREFIX_PROG_STRIPPED}/wpa_cli" "${PREFIX_PROG}/wpa_cli"
$STRIP -o "${PREFIX_PROG_STRIPPED}/wpa_supplicant" "${PREFIX_PROG}/wpa_supplicant"
b_install "${PREFIX_PORTS_INSTALL}/wpa_cli" /usr/bin
b_install "${PREFIX_PORTS_INSTALL}/wpa_supplicant" /usr/bin
