#!/bin/bash

set -e

MBEDTLS_VER="2.28.0"
MBEDTLS="mbedtls-${MBEDTLS_VER}"

PREFIX_MBEDTLS="${TOPDIR}/phoenix-rtos-ports/mbedtls"
PREFIX_MBEDTLS_BUILD="${PREFIX_BUILD}/mbedtls"
PREFIX_MBEDTLS_SRC="${PREFIX_MBEDTLS_BUILD}/${MBEDTLS}"
PREFIX_MBEDTLS_PATCHES="${PREFIX_MBEDTLS}/patches"
PREFIX_MBEDTLS_MARKERS="$PREFIX_MBEDTLS_BUILD/markers/"
b_log "Building mbedtls"

# Download and unpack
mkdir -p "$PREFIX_MBEDTLS_BUILD" "$PREFIX_MBEDTLS_MARKERS"
if ! [ -f "${PREFIX_MBEDTLS}/${MBEDTLS}.tar.gz" ]; then
	wget https://github.com/Mbed-TLS/mbedtls/archive/v${MBEDTLS_VER}.tar.gz -O "${PREFIX_MBEDTLS}/${MBEDTLS}.tar.gz"
fi

if ! [ -d "${PREFIX_MBEDTLS_SRC}" ]; then
	tar xf "$PREFIX_MBEDTLS/${MBEDTLS}.tar.gz" -C "${PREFIX_MBEDTLS_BUILD}"
fi

# Apply patches
for patchfile in "${PREFIX_MBEDTLS_PATCHES}"/*.patch; do
	if ! [ -f "${PREFIX_MBEDTLS_MARKERS}/$(basename "$patchfile").applied" ]; then
		[[ "${TARGET}" != "armv7m7-imxrt106x" ]] &&  [[ $(basename "$patchfile") == "armv7m7-imxrt106x.patch" ]] && continue
		echo "applying patch: $patchfile"
		patch -d "${PREFIX_MBEDTLS_BUILD}" -p0 -i "$patchfile" && touch "${PREFIX_MBEDTLS_MARKERS}/$(basename "$patchfile").applied"
	fi
done

# Convert ldflags to format recognizable by gcc, for example -q -> -Wl,-q
LDFLAGS=$(echo " ${LDFLAGS}" | sed "s/\s/,/g" | sed "s/,-/ -Wl,-/g")

# Flag that can be checked in makefiles
export phoenix=1
# Build
(cd "${PREFIX_MBEDTLS_BUILD}/${MBEDTLS}" && make install no_test)
