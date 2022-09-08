#!/bin/bash

set -e

AZURE_VER="lts_01_2022"
AZURE="azure-iot-sdk-c"

PREFIX_AZURE="${TOPDIR}/phoenix-rtos-ports/azure_sdk"
PREFIX_AZURE_RAW="${PREFIX_AZURE}/${AZURE}"
PREFIX_AZURE_BUILD="${PREFIX_BUILD}/azure_sdk"
PREFIX_AZURE_SRC="${PREFIX_AZURE_BUILD}/${AZURE}-${AZURE_VER}"
PREFIX_AZURE_MARKERS="${PREFIX_AZURE_BUILD}/markers"
PREFIX_AZURE_ROOT="${PREFIX_AZURE_BUILD}/root"
PREFIX_AZURE_LIB="${PREFIX_AZURE_ROOT}/lib"
PREFIX_AZURE_INC="${PREFIX_AZURE_ROOT}/include"
PREFIX_AZURE_BIN="${PREFIX_AZURE_ROOT}/bin"
PREFIX_AZURE_PATCHES="${PREFIX_AZURE}/patches"

CONNECTION_STRING_PATCH="${PREFIX_AZURE_PATCHES}/04_connection_string.patch"

b_log "Building azure iot sdk"

if [ "${LONG_TEST}" = "y" ];then
	recursive=" --recursive"
else
	recursive=""
fi

# Download in the specified version, it can't be done via wget, because tar.gz does not include submodules
mkdir -p "${PREFIX_AZURE_BUILD}" "${PREFIX_AZURE_MARKERS}"
if ! [ -d "${PREFIX_AZURE_RAW}" ]; then
	git clone -b "${AZURE_VER}" https://github.com/Azure/azure-iot-sdk-c.git "${PREFIX_AZURE_RAW}"
fi

# Copy the repository, add version suffix and update submodules
if ! [ -d "${PREFIX_AZURE_SRC}" ]; then
	cp -r "${PREFIX_AZURE_RAW}" "$PREFIX_AZURE_BUILD"
	mv "${PREFIX_AZURE_BUILD}/${AZURE}" "${PREFIX_AZURE_SRC}"
	(cd "${PREFIX_AZURE_SRC}" && git submodule update --init${recursive})
fi

# Set the entered connection string in patch file (if specified)
if [[ $AZURE_CONNECTION_STRING ]] && [[ -f "${CONNECTION_STRING_PATCH}" ]]; then
	sed -i "s/\"Your IoTHub Connection String\"/\"${AZURE_CONNECTION_STRING}\"/g" "${CONNECTION_STRING_PATCH}" \
	&& echo "Connection string has been set properly."
fi

# Apply patches
for patchfile in "${PREFIX_AZURE_PATCHES}"/*.patch; do
	if ! [ -f "${PREFIX_AZURE_MARKERS}/$(basename "$patchfile").applied" ]; then
		echo "applying patch: $patchfile"
		[[ "${LONG_TEST}" != "y" ]] && [[ $(basename "$patchfile") == "06_c-utility_utests.patch" ]] && continue
		[[ "${TARGET}" != "armv7m7-imxrt106x"* ]] && [[ $(basename "$patchfile") == "05_armv7m7-imxrt106x.patch" ]] && continue
		patch -d "${PREFIX_AZURE_BUILD}" -p0 -i "$patchfile" && touch "${PREFIX_AZURE_MARKERS}/$(basename "$patchfile").applied"
	fi
	# There are some cpp sources, which is currently not supported in Phoenix-RTOS
	[[ "${LONG_TEST}" = "y" ]] && rm -rf "${PREFIX_AZURE_SRC}/c-utility/testtools/micromock"
done

# Clear set connection string in patch file
if [[ $AZURE_CONNECTION_STRING ]] && [[ -f "${CONNECTION_STRING_PATCH}" ]]; then
	sed -i "s/\"${AZURE_CONNECTION_STRING}\"/\"Your IoTHub Connection String\"/g" "${CONNECTION_STRING_PATCH}"
fi

# Set phoenix c compiler and system root
PHOENIX_COMPILER_CMD=${CC}
PHOENIX_SYSROOT=$(${CC} --print-sysroot)
export PHOENIX_COMPILER_CMD
export PHOENIX_SYSROOT

# Convert ldflags to format recognizable by gcc, for example -q -> -Wl,-q
LDFLAGS=$(echo " ${LDFLAGS}" | sed "s/\s/,/g" | sed "s/,-/ -Wl,-/g")

# Build (# http and amqp protocols are currently not supported yet)
# Treat Phoenix-RTOS as Linux and providing toolchain file was the most suitable solution
(cd "${PREFIX_AZURE_SRC}/build_all/linux" && ./build.sh \
--toolchain-file "${PREFIX_AZURE}/toolchain-phoenix.cmake" -cl --sysroot="${PHOENIX_SYSROOT}" \
--no-http --no-amqp)

# Create azure root directory with provided libs, includes and binaries
mkdir -p "${PREFIX_AZURE_ROOT}" "${PREFIX_AZURE_LIB}" "${PREFIX_AZURE_INC}" "${PREFIX_AZURE_BIN}"

# Copy azure sdk libraries
(cd "${PREFIX_AZURE_SRC}/cmake/" && \
echo "${PREFIX_BUILD}/lib" "${PREFIX_AZURE_LIB}" | xargs -n 1 cp "iothub_client/"*.a "deps/umock-c/libumock_c.a" \
"umqtt/libumqtt.a" "c-utility/libaziotsharedutil.a")

# Copy azure sdk headers
(cd "${PREFIX_AZURE_SRC}/" && \
echo "${PREFIX_BUILD}/include" "${PREFIX_AZURE_INC}" | xargs -n 1 cp -r "iothub_client/inc/." \
"deps/umock-c/inc/." "deps/azure-macro-utils-c/inc/." "c-utility/inc/.")

# Install iothub client sample and c-utility tests (if built) in file system
cp "${PREFIX_AZURE_SRC}/cmake/iothub_client/samples/iothub_ll_telemetry_sample/iothub_ll_telemetry_sample" "${PREFIX_AZURE_BIN}"
b_install "${PREFIX_AZURE_BIN}/iothub_ll_telemetry_sample" /bin
for dir in "${PREFIX_AZURE_SRC}/cmake/c-utility/tests"/*
do
	if [[ $dir == *_ut* ]]; then
		if [[ $dir == *crtabstractions_ut ]] || [[ $dir == *httpapicompact_ut ]] || [[ $dir == *uniqueid_ut ]]; then
			[[ $dir == *crtabstractions_ut ]] && test_executable="crt_abstractions_ut_exe"
			[[ $dir == *httpapicompact_ut ]] && test_executable="httpapi_compact_ut_exe"
			[[ $dir == *uniqueid_ut ]] && test_executable="uniqueid_ut_linux_exe"
		else
			test_executable="$(basename "$dir")_exe"
		fi

		cp "$dir/$test_executable" "${PREFIX_AZURE_BIN}"
		b_install "$dir/$test_executable" /bin
	fi
done
