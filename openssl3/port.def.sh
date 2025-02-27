#!/usr/bin/env bash
:
#shellcheck disable=2034
{
	ports_api=1

	name="openssl"
	version="3.4.1"
	desc="TLSv1.3 capable SSL and crypto library"

	source="https://www.openssl.org/source/"
	archive_filename="${name}-${version}.tar.gz"
	src_path="${name}-${version}/"

	sha256="002a2d6b30b58bf4bea46c43bdd96365aaf8daa6c428782aa4feee06da197df3"
	size="18346056"

	license="Apache-2.0"
	license_file="LICENSE.txt"

	conflicts="openssl<3"
	depends=""
	optional=""

	supports="phoenix>=3.3"
}

p_prepare() {
	b_port_apply_patches "${PREFIX_PORT_WORKDIR}"

	if [ ! -f "${PREFIX_PORT_WORKDIR}/Makefile" ]; then
		cp "$PREFIX_PORT/30-phoenix.conf" "$PREFIX_PORT_WORKDIR/Configurations/"
		(cd "${PREFIX_PORT_WORKDIR}" && "${PREFIX_PORT_WORKDIR}/Configure" "phoenix-${TARGET_FAMILY}-${TARGET_SUBFAMILY}" --prefix="$PREFIX_PORT_INSTALL" --openssldir="/etc/ssl" no-docs)
	fi
}

p_build() {
	make -C "$PREFIX_PORT_WORKDIR" all
	make -C "$PREFIX_PORT_WORKDIR" install_sw

	cp -a "$PREFIX_PORT_INSTALL/bin/openssl" "$PREFIX_PROG"
	$STRIP -o "$PREFIX_PROG_STRIPPED/openssl" "$PREFIX_PROG/openssl"

	b_install "$PREFIX_PROG_TO_INSTALL/openssl" /usr/bin/
}
