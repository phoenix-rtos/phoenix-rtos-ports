#!/bin/bash

set -e

# The latest version that is compatible with azure iot sdk lts_01_2022
MBEDTLS_VER="2.28.0"
MBEDTLS="mbedtls-${MBEDTLS_VER}"

PREFIX_MBEDTLS="${TOPDIR}/phoenix-rtos-ports/mbedtls"
PREFIX_MBEDTLS_BUILD="${PREFIX_BUILD}/mbedtls"
PREFIX_MBEDTLS_SRC="${PREFIX_MBEDTLS_BUILD}/${MBEDTLS}"
PREFIX_MBEDTLS_PATCHES="${PREFIX_MBEDTLS}/patches"
PREFIX_MBEDTLS_MARKERS="${PREFIX_MBEDTLS_BUILD}/markers/"
PREFIX_MBEDTLS_DESTDIR="${PREFIX_MBEDTLS_BUILD}/root/"
PREFIX_MBEDTLS_TESTS="${PREFIX_MBEDTLS_SRC}/tests"
b_log "Building mbedtls"

# Download and unpack
mkdir -p "${PREFIX_MBEDTLS_BUILD}" "${PREFIX_MBEDTLS_MARKERS}"
if ! [ -f "${PREFIX_MBEDTLS}/${MBEDTLS}.tar.gz" ]; then
	wget https://github.com/Mbed-TLS/mbedtls/archive/v${MBEDTLS_VER}.tar.gz -O "${PREFIX_MBEDTLS}/${MBEDTLS}.tar.gz"
fi

if ! [ -d "${PREFIX_MBEDTLS_SRC}" ]; then
	tar xf "${PREFIX_MBEDTLS}/${MBEDTLS}.tar.gz" -C "${PREFIX_MBEDTLS_BUILD}"
fi

# Apply patches
for patchfile in "${PREFIX_MBEDTLS_PATCHES}"/*.patch; do
	if ! [ -f "${PREFIX_MBEDTLS_MARKERS}/$(basename "${patchfile}").applied" ]; then
		echo "applying patch: ${patchfile}"
		patch -d "${PREFIX_MBEDTLS_BUILD}" -p0 -i "${patchfile}" && touch "${PREFIX_MBEDTLS_MARKERS}/$(basename "${patchfile}").applied"
	fi
done

# Convert ldflags to format recognizable by gcc, for example -q -> -Wl,-q
LDFLAGS=$(echo " ${LDFLAGS}" | sed "s/\s/,/g" | sed "s/,-/ -Wl,-/g")

# Flag that can be checked in makefiles
export phoenix=1

# Build mbedtls without tests
(cd "${PREFIX_MBEDTLS_BUILD}/${MBEDTLS}" && make install no_test DESTDIR="$PREFIX_MBEDTLS_DESTDIR")

# Build and install tests if needed
if [ "${LONG_TEST}" = "y" ]; then
	(cd "${PREFIX_MBEDTLS_BUILD}/${MBEDTLS}" && make tests)

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
