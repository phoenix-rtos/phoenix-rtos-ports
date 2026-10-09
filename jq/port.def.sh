#!/usr/bin/env bash
:
#shellcheck disable=2034
{
	ports_api=1

	name="jq"
	version="1.8.2"
	desc="Command-line JSON processor"

	source="https://github.com/jqlang/jq/releases/download/jq-${version}/"
	archive_filename="${name}-${version}.tar.gz"
	src_path="${name}-${version}/"

	size="1959950"
	sha256="71b8d6e8f5fe81f6c6d0d110e3892251f6ce76ed095abd315e26e6e1193af3af"

	license="MIT" # and other BSD-like licenses for parts of code
	license_file="COPYING"

	conflicts=""
	depends=""

	supports="phoenix>=3.3"
}

p_prepare() {
	cd "${PREFIX_PORT_WORKDIR}"
	autoreconf -i -v -f
	./configure CFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS}" --host="${HOST}" --bindir="$PREFIX_PROG"
}

p_build() {
	cd "${PREFIX_PORT_WORKDIR}"
	make
	make install-binaries

	$STRIP -o "$PREFIX_PROG_STRIPPED/jq" "$PREFIX_PROG/jq"
	b_install "$PREFIX_PROG_TO_INSTALL/jq" /usr/bin/
}
