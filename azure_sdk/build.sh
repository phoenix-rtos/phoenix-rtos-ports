#!/usr/bin/env bash

set -e

install_binary () {
	BINARY_NAME="$(basename "$1")"

	cp "$1" "${PREFIX_PROG}"
	$STRIP  -o "$PREFIX_PROG_STRIPPED/${BINARY_NAME}" "${PREFIX_PROG}/${BINARY_NAME}"
	b_install "${PREFIX_PROG_STRIPPED}/${BINARY_NAME}" /bin
}

AZURE_VER="lts_01_2022"
AZURE="azure-iot-sdk-c"

PREFIX_AZURE_SRC="${PREFIX_PORT_BUILD}/${AZURE}-${AZURE_VER}"
PREFIX_AZURE_MARKERS="${PREFIX_PORT_BUILD}/markers"
PREFIX_AZURE_ROOT="${PREFIX_PORT_BUILD}/root"
PREFIX_AZURE_LIB="${PREFIX_AZURE_ROOT}/lib"
PREFIX_AZURE_INC="${PREFIX_AZURE_ROOT}/include"
PREFIX_AZURE_PATCHES="${PREFIX_PORT}/patches"

update_options=(--init)
if [ "${LONG_TEST}" = "y" ]; then
	update_options=("${update_options[@]}" --recursive)
fi

# Download in the specified version, it can't be done via wget, because tar.gz does not include submodules
mkdir -p "${PREFIX_PORT_BUILD}" "${PREFIX_AZURE_MARKERS}"
if ! [ -d "${PREFIX_AZURE_SRC}" ]; then
	git clone -b "${AZURE_VER}" https://github.com/Azure/azure-iot-sdk-c.git "${PREFIX_AZURE_SRC}"
	# Get the extended version only if the LONG_TEST option was set
	(cd "${PREFIX_AZURE_SRC}" && git submodule update "${update_options[@]}")
fi

# Apply patches
for patchfile in "${PREFIX_AZURE_PATCHES}"/*.patch; do
	if [ ! -f "${PREFIX_AZURE_MARKERS}/$(basename "$patchfile").applied" ]; then
		PATCH_NAME=$(basename "$patchfile")

		[ "${LONG_TEST}" != "y" ] && [ "${PATCH_NAME}" = "06_c-utility_utests.patch" ] && continue
		if [ "${PATCH_NAME}" == "05_armv7m7-imxrt106x.patch" ]; then
			grep -q "armv7m7-imxrt106x" <<< "${TARGET}" || continue
		fi
		echo "applying patch: $patchfile"
		patch -d "${PREFIX_PORT_BUILD}" -p0 -i "$patchfile" && touch "${PREFIX_AZURE_MARKERS}/${PATCH_NAME}.applied"
	fi
	# There are some cpp sources, which is currently not supported in Phoenix-RTOS
	[ "${LONG_TEST}" = "y" ] && rm -rf "${PREFIX_AZURE_SRC}/c-utility/testtools/micromock"
done

# Set the entered connection string in sample's source (if specified)
if [ -n "$AZURE_CONNECTION_STRING" ]; then
	sed -i "s/\"\[device connection string\]\"/\"${AZURE_CONNECTION_STRING}\"/g" \
	"${PREFIX_AZURE_SRC}/iothub_client/samples/iothub_ll_telemetry_sample/iothub_ll_telemetry_sample.c" \
	&& echo "Connection string has been set properly."
fi

# Set phoenix c compiler and system root
PHOENIX_COMPILER_CMD=${CC}
# shellcheck disable=SC2086
PHOENIX_SYSROOT=$(${CC} ${CFLAGS} --print-sysroot)
export PHOENIX_COMPILER_CMD PHOENIX_SYSROOT


# Build (http and amqp protocols are currently not supported yet)
# Treat Phoenix-RTOS as Linux and providing toolchain file was the most suitable solution
(cd "${PREFIX_AZURE_SRC}/build_all/linux" && ./build.sh \
--toolchain-file "${PREFIX_PORT}/toolchain-phoenix.cmake" -cl --sysroot="${PHOENIX_SYSROOT}" \
--no-http --no-amqp)

# Create azure root directory with provided libs, includes and binaries
mkdir -p "${PREFIX_AZURE_ROOT}" "${PREFIX_AZURE_LIB}" "${PREFIX_AZURE_INC}"

# Copy azure sdk libraries
(cd "${PREFIX_AZURE_SRC}/cmake/" && cp "iothub_client/"*.a \
"umqtt/libumqtt.a" "c-utility/libaziotsharedutil.a" "${PREFIX_AZURE_LIB}")
cp -r "${PREFIX_AZURE_LIB}"/* "${PREFIX_A}"

# Copy azure sdk headers
(cd "${PREFIX_AZURE_SRC}/" && cp -r "iothub_client/inc/." \
"deps/azure-macro-utils-c/inc/." "deps/umock-c/inc/." "c-utility/inc/." "${PREFIX_AZURE_INC}")
cp -r "${PREFIX_AZURE_INC}"/* "${PREFIX_H}"

# Install iothub client sample and c-utility tests (if built) in file system
install_binary "${PREFIX_AZURE_SRC}/cmake/iothub_client/samples/iothub_ll_telemetry_sample/iothub_ll_telemetry_sample"

declare -A CUSTOM_DIRS=(
    [crtabstractions_ut]="crt_abstractions_ut_exe"
    [httpapicompact_ut]="httpapi_compact_ut_exe"
    [uniqueid_ut]="uniqueid_ut_linux_exe"
)

for dir in "${PREFIX_AZURE_SRC}/cmake/c-utility/tests"/*; do
	DIR_NAME="$(basename "$dir")"

	# There may be other files, which are not test directories - skip them
	grep -q "_ut" <<< "$dir" || continue

	if [ -n "${CUSTOM_DIRS[$DIR_NAME]}" ]; then
		test_executable="${CUSTOM_DIRS[$DIR_NAME]}"
	else
		test_executable="${DIR_NAME}_exe"
	fi

	install_binary "$dir/$test_executable"
done
