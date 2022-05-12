#!/bin/bash

set -e

MBEDTLS_VER="2.28.0"
MBEDTLS="mbedtls-${MBEDTLS_VER}"

PREFIX_MBEDTLS="${TOPDIR}/phoenix-rtos-ports/mbedtls"
PREFIX_MBEDTLS_REPO="${PREFIX_MBEDTLS}/${MBEDTLS}"
PREFIX_MBEDTLS_BUILD="${PREFIX_BUILD}/mbedtls"
PREFIX_MBEDTLS_PATCHES="${PREFIX_MBEDTLS}/patches"

b_log "Building mbedtls"

# Download and unpack
if ! [ -d "${PREFIX_MBEDTLS_REPO}" ]; then
	git clone -b "v${MBEDTLS_VER}" https://github.com/Mbed-TLS/mbedtls.git "${PREFIX_MBEDTLS_REPO}"
fi

rm -rf "${PREFIX_MBEDTLS_BUILD}"

# Apply patches
for patchfile in "${PREFIX_MBEDTLS_PATCHES}"/*.patch; do
	if ! [ -f "${PREFIX_MBEDTLS_PATCHES}/$(basename "$patchfile").applied" ]; then
		echo "applying patch: $patchfile"
		patch -d "${PREFIX_MBEDTLS}" -p0 -i "$patchfile" && touch "${PREFIX_MBEDTLS_PATCHES}/$(basename "$patchfile").applied"
	fi
done

# Copy files to _build directory
if ! [ -d "${PREFIX_MBEDTLS_BUILD}" ]; then
	mkdir -p "${PREFIX_MBEDTLS_BUILD}"
	cp -r "${PREFIX_MBEDTLS_REPO}" "${PREFIX_MBEDTLS_BUILD}"
fi

# Convert ldflags to format recognizable by gcc, for example -q -> -Wl,-q
LDFLAGS=$(echo " ${LDFLAGS}" | sed "s/\s/,/g" | sed "s/,-/ -Wl,-/g")

# Build
export phoenix=1
(cd "${PREFIX_MBEDTLS_BUILD}/${MBEDTLS}" && make install no_test)
