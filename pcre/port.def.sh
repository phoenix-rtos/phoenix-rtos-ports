#!/usr/bin/env bash
:
#shellcheck disable=2034
{
	name="pcre"
	version="8.42"

	source="http://ftp.exim.org/pub/pcre/"
	archive_filename="${name}-${version}.tar.bz2"
	archive_src_path="${name}-${version}"

	size="1570171"
	sha256="2cd04b7c887808be030254e8d77de11d3fe9d4505c39d4b15d2664ffe8bf9301"

	license="BSD"
	license_file="LICENCE"

	conflicts=""
	depends=""
	optional=""
}

p_common() {
	return
}

p_prepare() {
	if [ ! -f "${PREFIX_PORT_WORKDIR}/config.h" ]; then
		(cd "${PREFIX_PORT_WORKDIR}" && "${PREFIX_PORT_WORKDIR}/configure" CFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS}" ARFLAGS="-r" --enable-static --disable-shared --host="$HOST" \
			--disable-cpp --prefix="${PREFIX_PORT_WORKDIR}" --libdir="${PREFIX_A}" \
			--includedir="${PREFIX_H}")
	fi
}

p_build() {
	make -C "$PREFIX_PORT_WORKDIR" install
}
