#!/bin/bash

set -e

AZURE_VER="lts_01_2022"
AZURE="azure-iot-sdk-c"

PREFIX_AZURE="${TOPDIR}/phoenix-rtos-ports/azure_sdk"
PREFIX_AZURE_REPO="${PREFIX_AZURE}/${AZURE}"
PREFIX_AZURE_BUILD="${PREFIX_BUILD}/azure_sdk"
TOOLCHAIN_FILE_PATH="${PREFIX_AZURE}/toolchain-phoenix.cmake"
PREFIX_AZURE_PATCHES="${PREFIX_AZURE}/patches"
C_UTILITY_TESTS="${PREFIX_AZURE_BUILD}/azure-iot-sdk-c/cmake/c-utility/tests"

b_log "Building azure iot sdk"

if [ "${B_TEST}" = "y" ];then
	recursive=" --recursive"
else
	recursive=""
fi

# Download and unpack
if ! [ -d "${PREFIX_AZURE_REPO}" ]; then
	git clone -b "${AZURE_VER}" https://github.com/Azure/azure-iot-sdk-c.git "${PREFIX_AZURE_REPO}" && \
	(cd "${PREFIX_AZURE_REPO}" && git submodule update --init$recursive)
fi

# Apply patches
for patchfile in "${PREFIX_AZURE_PATCHES}"/*.patch; do
	if ! [ -f "${PREFIX_AZURE_PATCHES}/$(basename "$patchfile").applied" ]; then
		[[ "${B_TEST}" != "y" ]] && [[ $(basename "$patchfile") == "c-utility_building_utests.patch" ]] && continue
		[[ "${B_TEST}" != "y" ]] && [[ $(basename "$patchfile") == "c-utility_runnng_utests.patch" ]] && continue
		patch -d "${PREFIX_AZURE}" -p0 -i "$patchfile" && touch "${PREFIX_AZURE_PATCHES}/$(basename "$patchfile").applied"
	fi
	[[ "${B_TEST}" = "y" ]] && rm -rf "${PREFIX_AZURE_REPO}/c-utility/testtools/micromock"
done

# Set phoenix c compiler and system root
export PHOENIX_COMPILER_CMD=${CC}
export PHOENIX_SYSROOT=$(${CC} --print-sysroot)
# Convert ldflags to format recognizable by gcc, for example -q -> -Wl,-q
LDFLAGS=$(echo " ${LDFLAGS}" | sed "s/\s/,/g" | sed "s/,-/ -Wl,-/g")

# Copy files, generate Makefile and build azure sdk iot
if ! [ -d "${PREFIX_AZURE_BUILD}" ]; then
	mkdir -p "${PREFIX_AZURE_BUILD}"
	cp -r "${PREFIX_AZURE_REPO}" "$PREFIX_AZURE_BUILD"
	(cd "${PREFIX_AZURE_BUILD}/${AZURE}/build_all/linux" && ./build.sh \
	--toolchain-file ${TOOLCHAIN_FILE_PATH} -cl --sysroot=${PHOENIX_SYSROOT} \
	--no-amqp$run_unittests)
fi

# Install iothub client sample and c-utility tests (if built) in file system
b_install "${PREFIX_AZURE_BUILD}/azure-iot-sdk-c/cmake/iothub_client/samples/iothub_ll_telemetry_sample/iothub_ll_telemetry_sample" /
for dir in $C_UTILITY_TESTS/*
do
	if [[ $dir == *_ut* ]]; then
		if [[ $dir == *crtabstractions_ut ]] || [[ $dir == *httpapicompact_ut ]] || [[ $dir == *uniqueid_ut ]]; then
			[[ $dir == *crtabstractions_ut ]] && test_executable="crt_abstractions_ut_exe"
			[[ $dir == *httpapicompact_ut ]] && test_executable="httpapi_compact_ut_exe"
			[[ $dir == *uniqueid_ut ]] && test_executable="uniqueid_ut_linux_exe"
		else
			test_executable=""$(basename "$dir")"_exe"
		fi
		b_install "$dir/$test_executable" /az/
	fi
done
