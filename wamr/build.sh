#!/usr/bin/env bash

set -e

version="${PORTS_WAMR_VERSION:-2.4.2}"
archive_filename="WAMR-${version}.tar.gz"
PREFIX_PORT_SRC="${PREFIX_PORT_BUILD}/${version}"
PRODUCT_MINI_DIR=${PREFIX_PORT_SRC}/product-mini/platforms/phoenix/build
PLATFORMS_BUILD_PATH="${PREFIX_PORT_SRC}/core/shared/platform"
DEBUG=0

if [ $DEBUG = 1 ]; then
    DEBUG_FLAG="-DCMAKE_BUILD_TYPE=Debug"
fi

if ! [[ "${TARGET_FAMILY}" =~ "armv7m" || "${TARGET_FAMILY}" =~ "armv8m" ]]; then
    TLS_FLAG="-DTARGET_HAS_TLS=1"
fi

if [[ "${TARGET_FAMILY}" =~ "arm" ]]; then
    TARGET_FLAG="-DWAMR_BUILD_TARGET=THUMB"
    INVOKE_GENERAL_FLAG="-DWAMR_BUILD_INVOKE_NATIVE_GENERAL=1"
elif [[ "${TARGET_FAMILY}" =~ "aarch" ]]; then
    TARGET_FLAG="-DWAMR_BUILD_TARGET=AARCH64" 
elif [[ "${TARGET_FAMILY}" =~ "riscv" ]]; then
    TARGET_FLAG="-DWAMR_BUILD_TARGET=RISCV64" 
fi

b_port_download "https://github.com/bytecodealliance/wasm-micro-runtime/archive/refs/tags/" "${archive_filename}"

if [ ! -d "${PREFIX_PORT_SRC}" ]; then
	echo "Extracting sources from ${archive_filename}"
	mkdir -p "${PREFIX_PORT_SRC}"
	tar -axf "${PREFIX_PORT}/${archive_filename}" --strip-components 1 -C "${PREFIX_PORT_SRC}"
fi

b_port_apply_patches "${PREFIX_PORT_SRC}" "${version}"

mkdir -p "${PLATFORMS_BUILD_PATH}/phoenix"
cp "${PLATFORMS_BUILD_PATH}/linux/platform_internal.h" "${PLATFORMS_BUILD_PATH}/phoenix/platform_internal.h"
cp "${PLATFORMS_BUILD_PATH}/linux/platform_init.c" "${PLATFORMS_BUILD_PATH}/phoenix/platform_init.c"
cp "${PLATFORMS_BUILD_PATH}/linux/shared_platform.cmake" "${PLATFORMS_BUILD_PATH}/phoenix/shared_platform.cmake"

mkdir -p "${PREFIX_PORT_SRC}/product-mini/platforms/phoenix"
cp "${PREFIX_PORT_SRC}/product-mini/platforms/posix/main.c" "${PREFIX_PORT_SRC}/product-mini/platforms/phoenix/"
cp "${PREFIX_PORT_SRC}/product-mini/platforms/linux/CMakeLists.txt" "${PREFIX_PORT_SRC}/product-mini/platforms/phoenix/"
rm -rf "${PREFIX_PORT_SRC}/product-mini/platforms/phoenix/native_libs"
cp -r "${PREFIX_PROJECT}/${WAMR_NATIVE_LIBS_DIR:-phoenix-rtos-ports/wamr/platform_files/native_libs}" "${PREFIX_PORT_SRC}/product-mini/platforms/phoenix/native_libs"

WAMR_FLAGS="-DWAMR_BUILD_PLATFORM=phoenix $TARGET_FLAG \
    -DWAMR_BUILD_AOT=0 \
    -DWAMR_DISABLE_HW_BOUND_CHECK=1 ${INVOKE_GENERAL_FLAG} -DWAMR_BUILD_MULTI_MODULE=1 \
    -DWAMR_BUILD_SHRUNK_MEMORY=1 -DWAMR_BUILD_EXTENDED_CONST_EXPR=1  -DWAMR_BUILD_TAIL_CALL=1 \
    ${DEBUG_FLAG}  ${TLS_FLAG}"

if [[ ${WAMR_LOW_MEMORY} = 1 ]]; then
    echo "Compiling in low memory mode"
    WAMR_FLAGS="${WAMR_FLAGS} -DWAMR_BUILD_LIBC_WASI=0 -DWAMR_APP_THREAD_STACK_SIZE_MAX=131072 \
    -DWAMR_BUILD_FAST_INTERP=0 -DWAMR_BUILD_SIMD=0 -DWAMR_BUILD_LIB_WASI_THREADS=0"
else
    WAMR_FLAGS="${WAMR_FLAGS} -DWAMR_BUILD_LIB_WASI_THREADS=1 -DWAMR_BUILD_BULK_MEMORY=1  \
        -DWAMR_BUILD_LIB_SIMDE=1 -DWAMR_BUILD_SIMD=1"
fi

mkdir -p "${PRODUCT_MINI_DIR}"
(cd "${PRODUCT_MINI_DIR}" &&  cmake ${WAMR_FLAGS} .. && make)

mkdir -p "${PREFIX_ROOTFS}"usr/bin

if [ ${DEBUG} = 0 ]; then
    $STRIP -o "${PRODUCT_MINI_DIR}/iwasm" "${PRODUCT_MINI_DIR}/iwasm-${version}" 
    b_install "${PRODUCT_MINI_DIR}/iwasm" /usr/bin/
else
    mv "${PRODUCT_MINI_DIR}/iwasm-${version}" "${PREFIX_ROOTFS}usr/bin/iwasm"
fi

