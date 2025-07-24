#!/usr/bin/env bash
#
# Shell script for building Phoenix-RTOS ports
#
# Copyright 2019, 2024 Phoenix Systems
# Author: Pawel Pisarczyk, Daniel Sawka
#

set -e

# unset phoenix-rtos DEBUG variable as it changes how ports are compiled
unset DEBUG

if [ "$TARGET_FAMILY" = "ia32" ]; then
	HOST_TARGET="i386"
	HOST="i386-pc-phoenix"
elif [[ "$TARGET_FAMILY" == "arm"* ]]; then
	HOST_TARGET="arm"
	HOST="arm-phoenix"
elif [ "$TARGET_FAMILY" = "sparcv8leon" ]; then
	HOST_TARGET="sparc"
	HOST="sparc-phoenix"
else
	HOST_TARGET="$TARGET_FAMILY"
	HOST="${TARGET_FAMILY}-phoenix"
fi
export HOST_TARGET HOST

# use CFLAGS/LDFLAGS/STRIP taken from make
CFLAGS="$EXPORT_CFLAGS"
LDFLAGS="$EXPORT_LDFLAGS"
STRIP="$EXPORT_STRIP"
export CFLAGS LDFLAGS STRIP

export PORTS_MIRROR_BASEURL="https://files.phoesys.com/ports/"

if [ -n "$PORTS_INSTALL_STRIPPED" ] && [ "$PORTS_INSTALL_STRIPPED" = "n" ]; then
	# TODO: extremely similar to PREFIX_PORT_INSTALL, find better name
	export PREFIX_PORTS_INSTALL="$PREFIX_PROG"
else
	export PREFIX_PORTS_INSTALL="$PREFIX_PROG_STRIPPED"
fi

# List of directories with ports. Built in this order
# TODO: generate dynamically using port_manager
ports=(
	# "mbedtls"
	# "busybox"
	# "pcre"
	# "openssl111"
	# "zlib"
	"lighttpd"
	# "dropbear"
	# "lua"
	# "lzo"
	# "openvpn"
	# "curl"
	# "jansson"
	# "micropython"
	# "sscep"
	# "wpa_supplicant"
	# "libevent"
	# "openiked"
	# "azure_sdk"
	# "picocom"
	# "fs_mark"
	# "coremark"
	# "coremark_pro"
	# "coreMQTT"
	# "lsb_vsx"
	# "heatshrink"
)

PORTS_DB="${PREFIX_BUILD}/ports.json"

PORT_MANAGER="${PREFIX_PROJECT}/phoenix-rtos-ports/port_manager.py"

# TODO: python's argparse fails if empty string passed
PORT_MANAGER_FLAGS=(
	"--db=${PORTS_DB}"
	"-v"
)

# TODO: maybe not needed
FRESH_CFLAGS=${CFLAGS}
FRESH_CPPFLAGS=${CPPFLAGS}
FRESH_LDFLAGS=${LDFLAGS}

function load_port_def() {
	local def_path="${1?def_path missing}"

	name=
	version=
	source=
	archive_filename=
	sha256=
	size=

	# must follow https://spdx.github.io/spdx-spec/v3.0.1/annexes/spdx-license-expressions/
	# https://spdx.org/licenses/
	license=
	license_file=

	archive_src_path=

	conflicts=

	depends=
	optional=

	# TODO: add host dependencies fields
	uses=
	test_uses=

	unset p_common
	unset p_prepare
	unset p_build

	source "${def_path}"
}

function _build_port() {
	local def_dir="${1?def_dir missing}"
	local dependency_of="${2}"

	local def_path="${def_dir}/port.def.sh"

	if [ ! -f "${def_path}" ]; then
		b_die "port.def.sh not found: ${def_path}"
	fi

	load_port_def "${def_path}"

	if [ -n "${dependency_of}" ]; then
		b_log "Building ${name}-${version} (dependency of ${dependency_of})"
	else
		b_log "Building ${name}-${version}"
	fi

	export PREFIX_PORT="${def_dir}"
	export PREFIX_PORT_BUILD="${PREFIX_BUILD}/${name}-${version}"

	# shellcheck disable=1091
	source "${PREFIX_PROJECT}/phoenix-rtos-ports/build.subr"

	# at this point the port.def.sh is assumed valid

	b_port_download "${source}" "${archive_filename}"

	local archive_path="${PREFIX_PORT}/${archive_filename}"

	local archive_size archive_sha256
	archive_size="$(wc -c <"${archive_path}")"
	archive_sha256="$( (sha256sum <"${archive_path}") | cut -d' ' -f1)"

	if [ "${archive_size}" != "${size}" ]; then
		b_die "archive size mismatch: expected '${size}', got '${archive_size}'"
	fi

	if [ "${archive_sha256}" != "${sha256}" ]; then
		b_die "archive sha256 mismatch: expected '${sha256}', got '${archive_sha256}'"
	fi

	local to_build

	to_build="$("${PORT_MANAGER}" --list-deps-to-install "${name}-${version}" \
		--optional "${PORT_MANAGER_FLAGS[@]}")"

	for dep_port_def_dir in ${to_build}; do
		build_port "${dep_port_def_dir}" "${name}-${version}"
	done

	to_build="$("${PORT_MANAGER}" --list-deps-to-install "${name}-${version}" \
		--optional "${PORT_MANAGER_FLAGS[@]}" --quiet)"

	if [ -n "${to_build}" ]; then
		b_die "dependencies are still not installed: ${to_build}"
	fi

	local unpack_dir="${PREFIX_PORT_BUILD}/${version}"
	export PREFIX_PORT_WORKDIR="${unpack_dir}/${archive_src_path}"

	mkdir -p "${PREFIX_PORT_WORKDIR}"
	tar xf "${archive_path}" -C "${unpack_dir}"

	local license_file_path="${PREFIX_PORT_WORKDIR}/${license_file}"
	if [ ! -f "${license_file_path}" ]; then
		b_die "license not found under ${license_file_path}"
	fi

	local prefix_ports_build="${PREFIX_BUILD}/ports"

	# TODO: distinguish normal ports from versioned (e.g. openssl3 vs openssl111) ports
	# by checking `conflicts` var
	# normal ports will install to /include /lib normally, while versioned will be
	# have their own header/lib space

	export PREFIX_PORT_INSTALL="${prefix_ports_build}/${name}-${version}"
	PREFIX_H="${PREFIX_PORT_INSTALL}/include"
	PREFIX_A="${PREFIX_PORT_INSTALL}/lib"

	mkdir -p "${PREFIX_H}"
	mkdir -p "${PREFIX_A}"

	# shellcheck disable=2317 # may be used in p_* functions
	function b_dependency_dir() {
		local dependency_name="${1?dependency_name}"
		"${PORT_MANAGER}" --resolve-dep "${name}-${version}" "${dependency_name}" \
			--build-prefix="${prefix_ports_build}" "${PORT_MANAGER_FLAGS[@]}"
	}

	# shellcheck disable=2317 # as above
	function b_optional_dir() {
		local dependency_name="${1?dependency_name}"
		"${PORT_MANAGER}" --resolve-dep "${name}-${version}" "${dependency_name}" \
			--optional --build-prefix="${prefix_ports_build}" "${PORT_MANAGER_FLAGS[@]}"
	}

	CFLAGS=${FRESH_CFLAGS}
	CPPFLAGS=${FRESH_CPPFLAGS}
	LDFLAGS=${FRESH_LDFLAGS}

	# TODO: p_clean() ?
	p_common
	p_prepare
	p_build

	"${PORT_MANAGER}" --mark-as-installed "${name}-${version}" "${PORT_MANAGER_FLAGS[@]}"
}

function build_port() {
	(_build_port "$@")
}

b_log "Discovering ports"

# TODO: don't destroy db on every run
if [ -f "${PORTS_DB}" ]; then
	rm -v "${PORTS_DB}"
fi

for port_dir in "${PREFIX_PROJECT}/phoenix-rtos-ports"/*; do
	port_def="${port_dir}/port.def.sh"
	if [ -f "${port_def}" ]; then
		echo "found port definition: $port_def"

		load_port_def "${port_def}"

		# TODO: ensure these are non-empty
		: "${name?name missing}"
		: "${version?version missing}"
		: "${source?source missing}"
		: "${archive_filename?archive_filename missing}"
		: "${sha256?sha256 missing}"
		: "${size?size missing}"
		: "${license?license missing}"
		: "${license_file?license_file missing}"

		# these are optional, but must be defined
		: "${archive_src_path?archive_src_path missing}"
		: "${conflicts?conflicts missing}"
		: "${depends?depends missing}"

		[[ $(type -t p_prepare) == function ]] || b_die "p_prepare undefined"
		[[ $(type -t p_build) == function ]] || b_die "p_build undefined"

		echo "version: ${version}"
		echo "source: ${source}"
		echo "archive_filename: ${archive_filename}"

		"${PORT_MANAGER}" --discover-port "${name}-${version}" \
			--def-dir "${port_dir}" --add-depends "${depends}" --add-optional "${optional}" \
			"${PORT_MANAGER_FLAGS[@]}"
	fi
done

b_log "Building ports"

for port in "${ports[@]}"; do
	(
		port_env_name="PORTS_${port^^}"
		if [ "${!port_env_name}" = "y" ]; then
			build_port "${PREFIX_PROJECT}/phoenix-rtos-ports/${port}"
		fi
	)
done

exit 0
