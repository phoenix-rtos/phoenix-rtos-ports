#!/bin/bash

set -e

AZURE_VER="lts_01_2022"
AZURE="azure-iot-sdk-c"

PREFIX_AZURE="${TOPDIR}/phoenix-rtos-ports/azure_sdk"
PREFIX_AZURE_BUILD="${PREFIX_BUILD}/azure_sdk"
TOOLCHAIN_FILE_PATH="${PREFIX_AZURE}/toolchain-phoenix.cmake"
PREFIX_AZURE_PATCHES="${PREFIX_AZURE}/patches"

b_log "Building azure iot sdk"

# Download and unpack
if ! [ -d "${PREFIX_AZURE}/${AZURE}" ]; then
	git clone -b "${AZURE_VER}" https://github.com/Azure/azure-iot-sdk-c.git "${PREFIX_AZURE}/${AZURE}" && \
	(cd "$PREFIX_AZURE/$AZURE" && git submodule update --init)
fi

# Apply patches
for patchfile in "${PREFIX_AZURE_PATCHES}"/*.patch; do
	if ! [ -f "${PREFIX_AZURE_PATCHES}/$(basename "$patchfile").applied" ]; then
		patch -d "${PREFIX_AZURE}" -p0 -i "$patchfile" && touch "${PREFIX_AZURE_PATCHES}/$(basename "$patchfile").applied"
	fi
done

# Copy files
if ! [ -d "${PREFIX_AZURE_BUILD}" ]; then
	mkdir -p "${PREFIX_AZURE_BUILD}"
	cp -r "${PREFIX_AZURE}/${AZURE}" "$PREFIX_AZURE_BUILD"
fi

# Set phoenix c compiler, generate Makefile and build
export PHOENIX_COMPILER_CMD=${CC}
export PHOENIX_SYSROOT=$(${CC} --print-sysroot)

(cd "${PREFIX_AZURE_BUILD}/${AZURE}/build_all/linux" && ./build.sh \
--toolchain-file ${TOOLCHAIN_FILE_PATH} -cl --sysroot=${PHOENIX_SYSROOT} \
--no-amqp --no-mqtt)

b_install "${PREFIX_AZURE_BUILD}/azure-iot-sdk-c/cmake/iothub_client/samples/iothub_client_sample_upload_to_blob/iothub_client_sample_upload_to_blob" /az/
