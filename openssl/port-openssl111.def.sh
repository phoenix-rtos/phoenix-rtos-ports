#!/usr/bin/env bash
:
#shellcheck disable=2034
{
	ports_api=1

	name="openssl"
	version="1.1.1a"
	desc="TLSv1.3 capable SSL and crypto library"

	source="https://www.openssl.org/source/"
	archive_filename="${name}-${version}.tar.gz"
	src_path="${name}-${version}/"

	sha256="fc20130f8b7cbd2fb918b2f14e2f429e109c31ddd0fb38fc5d71d9ffed3f9f41"
	size="8350547"

	license="OpenSSL"
	license_file="LICENSE"

	conflicts="openssl>=3"
	depends=""
	optional=""

	supports="phoenix>=3.3"
}

p_common() {
	source "${PREFIX_PORT}/openssl-common.subr"
}

p_prepare() {
	#shellcheck disable=2119 # no arguments to pass
	openssl_prepare
}

p_build() {
	openssl_build
}
