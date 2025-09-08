#!/usr/bin/env bash
:
#shellcheck disable=2034
{
	ports_api=1

	name="wamr"
	version="2.4.2"
	desc="Lightweight standalone WebAssembly runtime with small footprint, high performance and highly configurable features for applications"

	source="https://github.com/bytecodealliance/wasm-micro-runtime/archive/refs/tags/"
	archive_filename="WAMR-${version}.tar.gz"
	src_path="wasm-micro-runtime-WAMR-${version}"

	size="5970328"
	sha256="73380561a01f4863506e855c2c265cf03c5b6efb17bbb8c9bbafe80745fd00ef"

	license="Apache-2.0"
	license_file="LICENSE"

	conflicts=""
	depends=""
	optional=""

	supports="phoenix>=3.3"

	iuse="debug low_memory"
}

p_prepare() {
	: "${WAMR_THREAD_STACK_SIZE_MAX=8388608}" # Default from WAMR

	b_port_apply_patches "${PREFIX_PORT_WORKDIR}"

	# @FIXME(michal.lach): Kind of ugly to keep it that way.
	# This should get upstreamed at some point.
	mkdir -p "${PREFIX_PORT_WORKDIR}/core/shared/platform/phoenix"
	cp "${PREFIX_PORT_WORKDIR}/core/shared/platform/linux/platform_internal.h" "${PREFIX_PORT_WORKDIR}/core/shared/platform/phoenix/"
	cp "${PREFIX_PORT_WORKDIR}/core/shared/platform/linux/platform_init.c" "${PREFIX_PORT_WORKDIR}/core/shared/platform/phoenix/"
	cp "${PREFIX_PORT_WORKDIR}/core/shared/platform/linux/shared_platform.cmake" "${PREFIX_PORT_WORKDIR}/core/shared/platform/phoenix/"

	mkdir -p "${PREFIX_PORT_WORKDIR}/product-mini/platforms/phoenix"
	cp "${PREFIX_PORT_WORKDIR}/product-mini/platforms/posix/main.c" "${PREFIX_PORT_WORKDIR}/product-mini/platforms/phoenix/"
	cp "${PREFIX_PORT_WORKDIR}/product-mini/platforms/linux/CMakeLists.txt" "${PREFIX_PORT_WORKDIR}/product-mini/platforms/phoenix/"
	rm -rf "${PREFIX_PORT_WORKDIR}/product-mini/platforms/phoenix/native_libs"
	cp "${PREFIX_PORT_WORKDIR}/product-mini/platforms/linux/CMakeLists.txt" "${PREFIX_PORT_WORKDIR}/product-mini/platforms/phoenix/"
	cp -rf "${PREFIX_PORT}/platform_files/native_libs" "${PREFIX_PORT_WORKDIR}/product-mini/platforms/phoenix/"

	CMAKE_FLAGS="-DWAMR_BUILD_PLATFORM=phoenix \
		-DWAMR_BUILD_AOT=0 \
		-DWAMR_DISABLE_HW_BOUND_CHECK=1 \
		-DWAMR_BUILD_MULTI_MODULE=1 \
		-DWAMR_BUILD_SHRUNK_MEMORY=1 \
		-DWAMR_BUILD_EXTENDED_CONST_EXPR=1 \
		-DWAMR_BUILD_TAIL_CALL=1"

	case "${TARGET_FAMILY}" in
		arm*)
			CMAKE_FLAGS="${CMAKE_FLAGS} -DWAMR_BUILD_TARGET=THUMB -DWAMR_BUILD_INVOKE_NATIVE_GENERAL=1"
			if [[ "${TARGET_FAMILY}" =~ "armv7m" || "${TARGET_FAMILY}" =~ "armv7m" ]]; then
				CMAKE_FLAGS="${CMAKE_FLAGS} -DTARGET_HAS_TLS=1"
			fi
			;;
		aarch64*)
			CMAKE_FLAGS="${CMAKE_FLAGS} -DWAMR_BUILD_TARGET=AARCH64"
			;;
		riscv*)
			CMAKE_FLAGS="${CMAKE_FLAGS} -DWAMR_BUILD_TARGET=RISCV64"
			;;
		*)
			b_log "Building WAMR for unsupported Phoenix target"
			;;
	esac

	if b_use "debug"; then
		CMAKE_FLAGS="${CMAKE_FLAGS} -DCMAKE_BUILD_TYPE=Debug"
	fi

	if b_use "low_memory"; then
		CMAKE_FLAGS="${CMAKE_FLAGS} -DWAMR_BUILD_LIBC_WASI=0 -DWAMR_BUILD_FAST_INTERP=0 -DWAMR_BUILD_SIMD=0 -DWAMR_BUILD_LIB_WASI_THREADS=0"
		WAMR_THREAD_STACK_SIZE_MAX="131072" # As per recommendations from WAMR build documentation
	else
		CMAKE_FLAGS="${CMAKE_FLAGS} -DWAMR_BUILD_LIB_WASI_THREADS=1 -DWAMR_BUILD_BULK_MEMORY=1 -DWAMR_BUILD_LIB_SIMDE=1 -DWAMR_BUILD_SIMD=1"
	fi

	CMAKE_FLAGS="${CMAKE_FLAGS} -DWAMR_APP_THREAD_STACK_SIZE_MAX=${WAMR_THREAD_STACK_SIZE_MAX}"

	mkdir -p "${PREFIX_PORT_WORKDIR}/product-mini/platforms/phoenix/build"
	(cd "${PREFIX_PORT_WORKDIR}/product-mini/platforms/phoenix/build" && cmake "${WAMR_FLAGS}" ..)
}

p_build() {
	make -C "${PREFIX_PORT_WORKDIR}/product-mini/platforms/phoenix/build"

	if ! b_use "debug"; then
		$STRIP -o "${PREFIX_PROG_STRIPPED}/iwasm" "${PREFIX_PORT_WORKDIR}/product-mini/platforms/phoenix/build/iwasm"
		b_install "${PREFIX_PROG_STRIPPED}/iwasm" "/usr/bin/"
	else
		b_install "${PREFIX_PORT_WORKDIR}/product-mini/platforms/phoenix/build/iwasm" /usr/bin/
	fi
}
