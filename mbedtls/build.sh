#!/bin/bash

set -e

MBEDTLS_VER="2.28.0"
MBEDTLS="mbedtls-${MBEDTLS_VER}"

PREFIX_MBEDTLS="${TOPDIR}/phoenix-rtos-ports/mbedtls"
PREFIX_MBEDTLS_BUILD="${PREFIX_BUILD}/mbedtls"
PREFIX_MBEDTLS_SRC="${PREFIX_MBEDTLS_BUILD}/${MBEDTLS}"
PREFIX_MBEDTLS_PATCHES="${PREFIX_MBEDTLS}/patches"
PREFIX_MBEDTLS_MARKERS="$PREFIX_MBEDTLS_BUILD/markers/"
PREFIX_MBEDTLS_TESTS="${PREFIX_MBEDTLS_SRC}/tests"
b_log "Building mbedtls"

#temp: place repo in ports
PREFIX_MBEDTLS_REPO="${PREFIX_MBEDTLS}/${MBEDTLS}"

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

# Flag that can be checked in makefiles
export phoenix=1
# Build
(cd "${PREFIX_MBEDTLS_BUILD}/${MBEDTLS}" && make install all)

# cp $PREFIX_MBEDTLS_SRC/tests/* "${TOPDIR}/_fs/ia32-generic/root/"
# b_install "$PREFIX_MBEDTLS_SRC/tests" /

mkdir -p "${PREFIX_FS}/root/mbedtls_test_configs/"

for file in $PREFIX_MBEDTLS_TESTS/*
do
	if [[ $file == *\.datax ]]; then
		cp $file "${PREFIX_FS}/root/mbedtls_test_configs/"
		config_filename="$(basename "$file")"
		test_executable=${config_filename::-6}
		b_install "$PREFIX_MBEDTLS_TESTS/$test_executable" /bin
	fi
done

cp -r "${PREFIX_MBEDTLS_SRC}/tests/include/test" "${PREFIX_BUILD}/include"
cp -r "${PREFIX_MBEDTLS_SRC}/library/"*.h "${PREFIX_BUILD}/include"

#####################
# PREFIX_MBEDTLS="${TOPDIR}/phoenix-rtos-ports/mbedtls"
# PREFIX_MBEDTLS_REPO="${PREFIX_MBEDTLS}/${MBEDTLS}"
# PREFIX_MBEDTLS_BUILD="${PREFIX_BUILD}/mbedtls"
# PREFIX_MBEDTLS_PATCHES="${PREFIX_MBEDTLS}/patches"

# b_log "Building mbedtls"

# # Download and unpack
# if ! [ -d "${PREFIX_MBEDTLS_REPO}" ]; then
# 	git clone -b "v${MBEDTLS_VER}" https://github.com/Mbed-TLS/mbedtls.git "${PREFIX_MBEDTLS_REPO}"
# fi

# rm -rf "${PREFIX_MBEDTLS_BUILD}"

# # Apply patches
# for patchfile in "${PREFIX_MBEDTLS_PATCHES}"/*.patch; do
# 	if ! [ -f "${PREFIX_MBEDTLS_PATCHES}/$(basename "$patchfile").applied" ]; then
# 		echo "applying patch: $patchfile"
# 		patch -d "${PREFIX_MBEDTLS}" -p0 -i "$patchfile" && touch "${PREFIX_MBEDTLS_PATCHES}/$(basename "$patchfile").applied"
# 	fi
# done

# # Copy files to _build directory
# if ! [ -d "${PREFIX_MBEDTLS_BUILD}" ]; then
# 	mkdir -p "${PREFIX_MBEDTLS_BUILD}"
# 	cp -r "${PREFIX_MBEDTLS_REPO}" "${PREFIX_MBEDTLS_BUILD}"
# fi