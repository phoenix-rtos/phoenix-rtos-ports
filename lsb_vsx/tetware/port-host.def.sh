#!/usr/bin/env bash
:
#shellcheck disable=2034
{
	ports_api=1

	name="tetware_host"
	version="2.0"
	desc="A universal, multi-platform test execution management system used to automate, sequence, and report on software tests"

	lsb_version="${version}-1"

	source="http://www.opengroup.org/infosrv/lsb/ogdeliverables/LSB-VSX${lsb_version}"
	archive_filename="tet_vsxgen_3.02.tgz"
	src_path="/"

	size="1146294"
	sha256="56d406833c209aa175065af83e26246f85468da6e1bdbf65b4d2e0cb0db41c62"

	license="Artistic-1.0"
	license_file="Licence"

	conflicts=""
	depends=""

	supports="host"
}

p_common() {
	# TODO(adamgreloch): the install_path is then shared by any test suites on top
	# of TET, e.g. VSX. Is there any better way to handle this other than
	# hardcoding across these ports?
	export lsb_install_path="${PREFIX_BUILD}/lsb_vsx_host"
	export test_sets_path="${lsb_install_path}/test_sets"
	export TET_EXECUTE="${test_sets_path}/TESTROOT"
	export TET_ROOT="${lsb_install_path}"
	export VSXDIR="${test_sets_path}/SRC"
}

p_prepare() {
	# Fix permissions
	chmod -R u+w .
	chmod +x configure
	chmod +x test_sets/setup_testsets.sh

	./configure -t lite >/dev/null

	sed -e "s|^COPTS =\(.*\)$|COPTS = \1 -std=gnu89|" \
		-e "s|^THR_COPTS =\(.*\)$|THR_COPTS =\1 -std=gnu89|" \
		-e "s|^SHLIB_COPTS =.*$|SHLIB_COPTS = SHLIB_NOT_SUPPORTED|" \
		-e "s|^C_PLUS = .*$|C_PLUS = CPLUSPLUS_NOT_SUPPORTED|" \
		"${PREFIX_PORT}/files/defines.mk" >src/defines.mk

	b_port_apply_patches . "host"
}

p_build() {
	# Disable parallel building as it is not supported and may cause build failures
	export MAKEFLAGS="${MAKEFLAGS}${MAKEFLAGS:+ }-j1"

	mkdir -p "${lsb_install_path}"

	make -C src all
	make -C src install

	b_install_host "bin/tcc"

	chmod -R u+w "${lsb_install_path}"

	cp -ap . "${lsb_install_path}"
}
