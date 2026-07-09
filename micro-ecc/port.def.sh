#!/usr/bin/env bash
:
#shellcheck disable=2034
{
	ports_api=1

	name="micro_ecc"
	version="1.1.0+git.541b3a7"
	desc="A small and fast ECDH and ECDSA implementation for 8-bit, 32-bit, and 64-bit processors."

	commit="541b3a78026420a3e369c4c9281c396b5e531113"
	git_source="https://github.com/kmackay/micro-ecc.git"
	source="https://github.com/kmackay/micro-ecc/archive"
	archive_filename=("micro-ecc-${commit}.tar.gz" "${commit}.tar.gz")

	src_path="micro-ecc-541b3a78026420a3e369c4c9281c396b5e531113"

	size="90435"
	sha256="48b36c6ae7401dd27f5b478764cad8e42ca601e4e81f9984d07ec1c7f1251329"
	license="BSD-2-Clause"
	license_file="LICENSE.txt"

	conflicts=""
	depends=""

	supports="phoenix>=3.3"
}

p_prepare() {
	# No need to prepare
	true
}

p_build() {
	# -DuECC_OPTIMIZATION_LEVEL=2 ensures assembly optimizations are not used by default
	# -DuECC_POSIX=1 ensures dev/urandom is used as RNG by default
	local uECC_flags="-DuECC_OPTIMIZATION_LEVEL=2 -DuECC_POSIX=1"

	# shellcheck disable=SC2086
	(cd "${PREFIX_PORT_WORKDIR}" &&
		"${CROSS}gcc" ${CFLAGS} ${uECC_flags} -I"${PREFIX_H}" -c uECC.c -o uECC.o)

	(cd "${PREFIX_PORT_WORKDIR}" &&
		"${CROSS}ar" rcs libuecc.a uECC.o)

	cp -a "${PREFIX_PORT_WORKDIR}/libuecc.a" "${PREFIX_A}/"
	cp -a "${PREFIX_PORT_WORKDIR}/uECC.h" "${PREFIX_H}/"
}
