#!/usr/bin/env bash
:
#shellcheck disable=2034
{
	name="zlib"
	version="1.2.11"

	source="https://zlib.net/fossils/"
	archive_filename="${name}-${version}.tar.gz"
	archive_src_path="${name}-${version}/"

	size="607698"
	sha256="c3e5e9fdd5004dcb542feda5ee4f0ff0744628baf8ed2dd5d66f8ca1197cb1a1"

	license="Zlib"
	license_file="zlib.h"

	conflicts=""
	depends=""
	optional=""
}

p_common() {
	return
}

p_prepare() {
	b_port_apply_patches "${PREFIX_PORT_WORKDIR}"
}

p_build() {
	# changing LDFLAGS from "ld" params format to "gcc" params - prefixing with -Wl, and changing spaces to colons
	LDFLAGS="${CFLAGS} $LDFLAGS"

	if [ ! -f "${PREFIX_PORT_WORKDIR}/build/Makefile" ]; then
		mkdir -p "${PREFIX_PORT_WORKDIR}/build"
		(cd "${PREFIX_PORT_WORKDIR}/build" && cmake -DCMAKE_INSTALL_PREFIX="${PREFIX_PORT_INSTALL}" -DCMAKE_BUILD_TYPE=Release -DSKIP_BUILD_EXAMPLES=ON -DSKIP_INSTALL_MAN=ON .. && make install)
	fi

	(cd "${PREFIX_PORT_WORKDIR}/build" && make install)
}
