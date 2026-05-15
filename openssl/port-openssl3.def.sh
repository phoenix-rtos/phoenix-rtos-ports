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

p_common() {
	source "${PREFIX_PORT}/openssl-common.subr"
}

p_prepare() {
	openssl_prepare no-docs
}

p_build() {
	openssl_build
}
