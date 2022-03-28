#!/bin/bash

set -e

OPENSSL=openssl-1.1.1a

b_log "Building openssl"
PREFIX_OPENSSL="${PREFIX_PROJECT}/phoenix-rtos-ports/openssl"
PREFIX_OPENSSL_BUILD="${PREFIX_BUILD}/openssl"
PREFIX_OPENSSL_SRC="${PREFIX_OPENSSL_BUILD}/${OPENSSL}"
PREFIX_OPENSSL_INSTALL="$PREFIX_OPENSSL_BUILD/install"
PREFIX_OPENSSL_MARKERS="$PREFIX_OPENSSL_BUILD/markers/"

#
# Download and unpack
#
mkdir -p "$PREFIX_OPENSSL_BUILD" "$PREFIX_OPENSSL_INSTALL" "$PREFIX_OPENSSL_MARKERS"
[ -f "$PREFIX_OPENSSL/${OPENSSL}.tar.gz" ] || wget https://www.openssl.org/source/${OPENSSL}.tar.gz -P "$PREFIX_OPENSSL" --no-check-certificate
[ -d "$PREFIX_OPENSSL_SRC" ] || tar zxf "$PREFIX_OPENSSL/${OPENSSL}.tar.gz" -C "$PREFIX_OPENSSL_BUILD"

#
# Apply patches
#
for patchfile in "$PREFIX_OPENSSL"/*.patch; do
	if [ ! -f "$PREFIX_OPENSSL_MARKERS/$(basename "$patchfile").applied" ]; then
		echo "applying patch: $patchfile"
		patch -d "$PREFIX_OPENSSL_SRC" -p1 < "$patchfile"
		touch "$PREFIX_OPENSSL_MARKERS/$(basename "$patchfile").applied"
	fi
done

#
# Configure
#
if [ ! -f "${PREFIX_OPENSSL_BUILD}/Makefile" ]; then
	cp "$PREFIX_OPENSSL/30-phoenix.conf" "$PREFIX_OPENSSL_SRC/Configurations/"
	(cd "${PREFIX_OPENSSL_BUILD}" && "${PREFIX_OPENSSL_SRC}/Configure" "phoenix-${TARGET_FAMILY}-${TARGET_SUBFAMILY}" --prefix="$PREFIX_OPENSSL_INSTALL")
fi


#
# Make
#
make -C "$PREFIX_OPENSSL_BUILD" all
make -C "$PREFIX_OPENSSL_BUILD" install_sw

cp -a "$PREFIX_OPENSSL_INSTALL/include/openssl" "$PREFIX_H"
cp -a "$PREFIX_OPENSSL_INSTALL/lib/libcrypto.a" "$PREFIX_A"
cp -a "$PREFIX_OPENSSL_INSTALL/lib/libssl.a"  "$PREFIX_A"
cp -a "$PREFIX_OPENSSL_INSTALL/lib/pkgconfig" "$PREFIX_A"
sed -i "s/openssl\/install$/lib\/pkgconfg/" "$PREFIX_A/pkgconfig/"*

cp -a "$PREFIX_OPENSSL_INSTALL/bin/openssl"  "$PREFIX_PROG"
"${CROSS}strip" -s "$PREFIX_PROG/openssl" -o "$PREFIX_PROG_STRIPPED/openssl"
b_install "$PREFIX_PORTS_INSTALL/openssl" /usr/bin/
