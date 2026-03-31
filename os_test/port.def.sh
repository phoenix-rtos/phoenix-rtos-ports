#!/usr/bin/env bash
:
#shellcheck disable=2034
{
	ports_api=1

	# TODO: allow `-` in names?
	name="os_test"
	tag="7e8f0082ab0b58ad3383a8abbf47dc4b40dcf25d"

	version="1.0+${tag:0:8}"
	desc="Set of test suites for POSIX operating systems"

	source="https://gitlab.com/sortix/os-test/-/archive/${tag}/"
	archive_filename="os-test-${tag}.tar.gz"
	src_path="os-test-${tag}/"

	size="386109"
	sha256="7b9d5ab2d514816d50c87da02b8c28ba18ff2032a77420d38ade99d375b46d60"

	license="0BSD"
	license_file="LICENSE"

	conflicts=""
	depends="busybox>=1.27.2"
	optional=""

	supports="phoenix>=3.3"
}

p_prepare() {
	b_port_apply_patches "${PREFIX_PORT_WORKDIR}"
}

p_build() {
	local suite test_bin suite_dir
	local install_dir="/usr/os-test"
	set -e

	# TODO: test recompilation requires clean build
	if [ ! -d "${PREFIX_FS}/root/${install_dir}" ]; then
		make -C "$PREFIX_PORT_WORKDIR" NO_SHARED=1 OS="Phoenix-RTOS" CPPFLAGS='' LDFLAGS="${LDFLAGS}" all
		cp -rap "${PREFIX_PORT_WORKDIR}" "${PREFIX_FS}/root/${install_dir}"
	fi

	(cd "${PREFIX_PORT_WORKDIR}" &&
		find . -type f -name '*.c' -not -path '*pty*' -exec sh -c '
    for f do
      bin=${f%.c}
      [ -f "$bin" ] && printf "%s\n" "$f"
    done
  ' sh {} + >tests.list)

	# some tests must be skipped as they cause the test executing thread to block
	# forever on IPC call, making it unkillable...
	# REVISIT: once IPC becomes fully interruptible
	(cd "${PREFIX_PORT_WORKDIR}" && grep -vxFf "${PREFIX_PORT}/skipped.list" tests.list >tmp && mv tmp tests.list)

	b_install "${PREFIX_PORT_WORKDIR}/tests.list" "${install_dir}"
	b_install "${PREFIX_PORT}/run_tests.sh" "${install_dir}"

	while IFS= read -r file; do
		echo "SKIPPED" >"${PREFIX_FS}/root/${install_dir}/out/phoenix-rtos/${file%.c}.out"
	done <"${PREFIX_PORT}/skipped.list"
}
