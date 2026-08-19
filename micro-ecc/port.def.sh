#!/usr/bin/env bash
:
#shellcheck disable=2034
{
	ports_api=1

	name="micro_ecc"
	commit="541b3a78026420a3e369c4c9281c396b5e531113"
	version_base="1.1.0"
	version="${version_base}+git.${commit:0:8}"
	desc="A small and fast ECDH and ECDSA implementation for 8-bit, 32-bit, and 64-bit processors."
	cpe23="cpe:2.3:a:micro-ecc_project:micro-ecc:${version_base}:*:*:*:*:*:*:*"

	source="https://github.com/kmackay/micro-ecc/archive"
	archive_filename=("micro-ecc-${commit}.tar.gz" "${commit}.tar.gz")

	src_path="micro-ecc-${commit}"

	size="90435"
	sha256="48b36c6ae7401dd27f5b478764cad8e42ca601e4e81f9984d07ec1c7f1251329"
	license="BSD-2-Clause"
	license_file="LICENSE.txt"

	conflicts=""
	depends=""

	supports="phoenix>=3.3"

	unset -v version_base commit
}

p_prepare() {
	# No need to prepare
	true
}

p_build() {
	local -a cflagsArray
	IFS=" " read -r -a cflagsArray <<<"${CFLAGS:?}"
	cflagsArray+=(
		"-DuECC_OPTIMIZATION_LEVEL=2" # highest optimization level without assembly code
		"-DuECC_POSIX=1"              # use /dev/urandom as RNG source
	)
	(
		set -e
		cd "${PREFIX_PORT_WORKDIR:?}"
		"${CC:?}" "${cflagsArray[@]}" -I"${PREFIX_H:?}" -c uECC.c -o uECC.o
		"${AR:?}" rcs libuecc.a uECC.o
		install -p -t "${PREFIX_A:?}" libuecc.a
		install -p -t "${PREFIX_H:?}" uECC.h
	)
}
