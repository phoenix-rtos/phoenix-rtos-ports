#!/usr/bin/env bash

set -e

# The latest version that is compatible with azure iot sdk lts_01_2022
MBEDTLS_VER="2.28.0"
MBEDTLS="mbedtls-${MBEDTLS_VER}"
PKG_URL="https://github.com/Mbed-TLS/mbedtls/archive/v${MBEDTLS_VER}.tar.gz"
PKG_MIRROR_URL="https://files.phoesys.com/ports/${MBEDTLS}.tar.gz"

PREFIX_MBEDTLS_SRC="${PREFIX_PORT_BUILD}/${MBEDTLS}"
PREFIX_MBEDTLS_PATCHES="${PREFIX_PORT}/patches"
PREFIX_MBEDTLS_MARKERS="${PREFIX_PORT_BUILD}/markers/"
PREFIX_MBEDTLS_DESTDIR="${PREFIX_PORT_BUILD}/root/"
PREFIX_MBEDTLS_TESTS="${PREFIX_MBEDTLS_SRC}/tests"

# Download and unpack
mkdir -p "${PREFIX_PORT_BUILD}" "${PREFIX_MBEDTLS_MARKERS}"
if ! [ -f "${PREFIX_PORT}/${MBEDTLS}.tar.gz" ]; then
	if ! wget "$PKG_URL" -O "${PREFIX_PORT}/${MBEDTLS}.tar.gz" --no-check-certificate; then
		wget "$PKG_MIRROR_URL" -P "${PREFIX_PORT}" --no-check-certificate
	fi
fi

if ! [ -d "${PREFIX_MBEDTLS_SRC}" ]; then
	tar xf "${PREFIX_PORT}/${MBEDTLS}.tar.gz" -C "${PREFIX_PORT_BUILD}"
fi

# Apply patches
for patchfile in "${PREFIX_MBEDTLS_PATCHES}"/*.patch; do
	if ! [ -f "${PREFIX_MBEDTLS_MARKERS}/$(basename "${patchfile}").applied" ]; then
		echo "applying patch: ${patchfile}"
		patch -d "${PREFIX_PORT_BUILD}" -p0 -i "${patchfile}" && touch "${PREFIX_MBEDTLS_MARKERS}/$(basename "${patchfile}").applied"
	fi
done

# Flag that can be checked in makefiles
export phoenix=1

# Build mbedtls without tests
(cd "${PREFIX_PORT_BUILD}/${MBEDTLS}" && make install no_test DESTDIR="$PREFIX_MBEDTLS_DESTDIR")

# Build and install tests if needed
if [ "${LONG_TEST}" = "y" ]; then
	(cd "${PREFIX_PORT_BUILD}/${MBEDTLS}" && make tests)

	mkdir -p "${PREFIX_FS}/root/mbedtls_test_configs/"

	for file in "${PREFIX_MBEDTLS_TESTS}"/*; do
		# Each .datax file is related to a test with the same name
		if [[ $file == *\.datax ]]; then
			config_filename="$(basename "${file}")"
			test_executable=${config_filename::-6}
			# test_suite_asn1parse have cases that assume `long` type is 64bit long, which isn't True for some Phoenix-RTOS targets
			if ! [ "${test_executable}" = "test_suite_asn1parse" ]; then
				cp "${file}" "${PREFIX_FS}/root/mbedtls_test_configs/"
				b_install "${PREFIX_MBEDTLS_TESTS}/${test_executable}" /bin/
			fi
		fi
	done
	# Files required for some tests
	cp -r "${PREFIX_MBEDTLS_SRC}/tests/data_files" "${PREFIX_FS}/root/"
fi

# Copy built libraries and mbedtls header files to `lib` and `include` dirs
cp -a "${PREFIX_MBEDTLS_DESTDIR}/lib"/* "${PREFIX_A}"
cp -a "${PREFIX_MBEDTLS_DESTDIR}/include"/* "${PREFIX_H}"
