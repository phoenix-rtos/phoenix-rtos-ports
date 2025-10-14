#!/usr/bin/env bash
:
#shellcheck disable=2034
{
	name="openssl"
	version="1.1.1a"

	source="https://www.openssl.org/source/"
	archive_filename="${name}-${version}.tar.gz"
	archive_src_path="${name}-${version}/"

	sha256="fc20130f8b7cbd2fb918b2f14e2f429e109c31ddd0fb38fc5d71d9ffed3f9f41"
	size="8350547"

	license="OpenSSL"
	license_file="LICENSE"

	conflicts="openssl3>=0.0"
	depends=""
	optional=""
}

p_common() {
	export PREFIX_OPENSSL_INSTALL="${PREFIX_PORT_WORKDIR}/install"
}

p_prepare() {
	b_port_apply_patches "${PREFIX_PORT_WORKDIR}"

	if [ ! -f "${PREFIX_PORT_WORKDIR}/Makefile" ]; then
		cp "$PREFIX_PORT/30-phoenix.conf" "$PREFIX_PORT_WORKDIR/Configurations/"
		(cd "${PREFIX_PORT_WORKDIR}" && "${PREFIX_PORT_WORKDIR}/Configure" "phoenix-${TARGET_FAMILY}-${TARGET_SUBFAMILY}" --prefix="$PREFIX_OPENSSL_INSTALL" --openssldir="/etc/ssl")
	fi
}

p_build() {
	make -C "$PREFIX_PORT_WORKDIR" all
	make -C "$PREFIX_PORT_WORKDIR" install_sw

	mkdir -p "${PREFIX_OPENSSL_INSTALL}"

	cp -a "$PREFIX_OPENSSL_INSTALL/include/openssl" "$PREFIX_H"
	cp -a "$PREFIX_OPENSSL_INSTALL/lib/libcrypto.a" "$PREFIX_A"
	cp -a "$PREFIX_OPENSSL_INSTALL/lib/libssl.a" "$PREFIX_A"
	cp -a "$PREFIX_OPENSSL_INSTALL/lib/pkgconfig" "$PREFIX_A"
	sed -i "s/openssl\/install$/lib\/pkgconfig/" "$PREFIX_A/pkgconfig/"*

	cp -a "$PREFIX_OPENSSL_INSTALL/bin/openssl" "$PREFIX_PROG"
	$STRIP -o "$PREFIX_PROG_STRIPPED/openssl" "$PREFIX_PROG/openssl"

	b_install "$PREFIX_PROG/openssl" /usr/bin/
}
