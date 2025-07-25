#!/usr/bin/env bash

set -e

OPENSSL=openssl-1.1.1a
PKG_URL="https://www.openssl.org/source/${OPENSSL}.tar.gz"
PKG_MIRROR_URL="https://files.phoesys.com/ports/${OPENSSL}.tar.gz"

PREFIX_OPENSSL_SRC="${PREFIX_PORT_BUILD}/${OPENSSL}"
PREFIX_OPENSSL_INSTALL="$PREFIX_PORT_BUILD/install"
PREFIX_OPENSSL_MARKERS="$PREFIX_PORT_BUILD/markers/"

PREFIX_H+="/ports/openssl/1.1.1a"
PREFIX_A+="/ports/openssl/1.1.1a"

#
# Download and unpack
#
mkdir -p "$PREFIX_PORT_BUILD" "$PREFIX_OPENSSL_INSTALL" "$PREFIX_OPENSSL_MARKERS" "${PREFIX_H}" "${PREFIX_A}"
if [ ! -f "$PREFIX_PORT/${OPENSSL}.tar.gz" ]; then
	if ! wget "$PKG_URL" -P "${PREFIX_PORT}" --no-check-certificate; then
		wget "$PKG_MIRROR_URL" -P "${PREFIX_PORT}" --no-check-certificate
	fi
fi
[ -d "$PREFIX_OPENSSL_SRC" ] || tar zxf "$PREFIX_PORT/${OPENSSL}.tar.gz" -C "$PREFIX_PORT_BUILD"

#
# Apply patches
#
for patchfile in "$PREFIX_PORT"/*.patch; do
	if [ ! -f "$PREFIX_OPENSSL_MARKERS/$(basename "$patchfile").applied" ]; then
		echo "applying patch: $patchfile"
		patch -d "$PREFIX_OPENSSL_SRC" -p1 < "$patchfile"
		touch "$PREFIX_OPENSSL_MARKERS/$(basename "$patchfile").applied"
	fi
done

#
# Configure
#
if [ ! -f "${PREFIX_PORT_BUILD}/Makefile" ]; then
	cp "$PREFIX_PORT/30-phoenix.conf" "$PREFIX_OPENSSL_SRC/Configurations/"
	(cd "${PREFIX_PORT_BUILD}" && "${PREFIX_OPENSSL_SRC}/Configure" "phoenix-${TARGET_FAMILY}-${TARGET_SUBFAMILY}" --prefix="$PREFIX_OPENSSL_INSTALL" --openssldir="/etc/ssl")
fi


#
# Make
#
make -C "$PREFIX_PORT_BUILD" all
make -C "$PREFIX_PORT_BUILD" install_sw

cp -a "$PREFIX_OPENSSL_INSTALL/include/openssl" "$PREFIX_H"
cp -a "$PREFIX_OPENSSL_INSTALL/lib/libcrypto.a" "$PREFIX_A"
cp -a "$PREFIX_OPENSSL_INSTALL/lib/libssl.a"  "$PREFIX_A"
cp -a "$PREFIX_OPENSSL_INSTALL/lib/pkgconfig" "$PREFIX_A"
sed -i "s/openssl\/install$/lib\/pkgconfg/" "$PREFIX_A/pkgconfig/"*

cp -a "$PREFIX_OPENSSL_INSTALL/bin/openssl"  "$PREFIX_PROG"
$STRIP -o "$PREFIX_PROG_STRIPPED/openssl" "$PREFIX_PROG/openssl"
b_install "$PREFIX_PORTS_INSTALL/openssl" /usr/bin/
