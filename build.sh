#!/usr/bin/env bash
#
# Shell script for building Phoenix-RTOS ports
#
# Copyright 2019, 2024, 2026 Phoenix Systems
# Author: Pawel Pisarczyk, Daniel Sawka, Adam Greloch
#

set -e

reset_env() {
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
  CFLAGS="${EXPORT_CFLAGS}"
  LDFLAGS="${EXPORT_LDFLAGS}"
  STRIP="${EXPORT_STRIP}"
  export CFLAGS LDFLAGS STRIP

  export PORTS_MIRROR_BASEURL="https://files.phoesys.com/ports/"

  if [ -n "$PORTS_INSTALL_STRIPPED" ] && [ "$PORTS_INSTALL_STRIPPED" = "n" ]; then
    export PREFIX_PROG_TO_INSTALL="$PREFIX_PROG"
  else
    export PREFIX_PROG_TO_INSTALL="$PREFIX_PROG_STRIPPED"
  fi
}

PORTS_DB="${PREFIX_BUILD}/ports.json"
PORT_MANAGER_FLAGS=(
  "--db=${PORTS_DB}"
)
PORT_MANAGER="${PREFIX_PROJECT}/phoenix-rtos-ports/port_manager.py"
PREFIX_PORTS_BUILD_ROOT="${PREFIX_BUILD}/port-sources"

function port_manager() {
  "${PORT_MANAGER}" "${PORT_MANAGER_FLAGS[@]}" "$@"
}

function load_port_def() {
  local def_path="${1?def_path missing}"

  unset name
  unset version
  unset source
  unset archive_filename
  unset sha256
  unset size

  # must follow https://spdx.github.io/spdx-spec/v3.0.1/annexes/spdx-license-expressions/
  # https://spdx.org/licenses/
  unset license
  unset license_file

  unset src_path

  unset conflicts

  unset depends
  unset optional

  # TODO: add host dependencies fields
  uses=
  test_uses=

  unset p_common
  unset p_prepare
  unset p_build
  unset p_build_test

  source "${def_path}"
}

function _build_port() {
  local def_dir="${1?def_dir missing}"
  local dependency_of="${2}"

  reset_env

  local def_path="${def_dir}/port.def.sh"

  if [ ! -f "${def_path}" ]; then
    b_die "WARNING: port.def.sh not found: ${def_path}"
  fi

  load_port_def "${def_path}"

  if [ -n "${dependency_of}" ]; then
    b_log "Building ${name}-${version} (dependency of ${dependency_of})"
  else
    b_log "Building ${name}-${version}"
  fi

  export PREFIX_PORT="${def_dir}"
  export PREFIX_PORT_BUILD="${PREFIX_PORTS_BUILD_ROOT}/${name}-${version}"

  # shellcheck disable=1091
  source "${PREFIX_PROJECT}/phoenix-rtos-ports/build.subr"

  # at this point the port.def.sh is assumed valid

  export PREFIX_PORT_WORKDIR="${PREFIX_PORT_BUILD}/${src_path}"

  if [ ! -d "${PREFIX_PORT_WORKDIR}" ]; then
    local archive_path actual_size actual_sha256
    if [ -z "${source}" ]; then
      p_source
      actual_sha256="$(git archive --format=tar HEAD | sha256sum | cut -d' ' -f1)"
      actual_size="$(find "${PREFIX_PORT_WORKDIR}" -type f ! -path '*/.git/*' -exec stat -c %s {} + |
        awk '{sum+=$1} END {print sum}')"
    else
      b_port_download "${source}" "${archive_filename}"

      archive_path="${PREFIX_PORT}/${archive_filename}"
      actual_size="$(wc -c <"${archive_path}")"
      actual_sha256="$( (sha256sum <"${archive_path}") | cut -d' ' -f1)"
    fi

    if [ "${actual_size}" != "${size}" ]; then
      rm -rf "${PREFIX_PORT_WORKDIR?}"
      b_die "size mismatch: expected '${size}', got '${actual_size}'"
    fi

    if [ "${actual_sha256}" != "${sha256}" ]; then
      rm -rf "${PREFIX_PORT_WORKDIR?}"
      b_die "sha256 mismatch: expected '${sha256}', got '${actual_sha256}'"
    fi

    if [ -n "${archive_path}" ]; then
      mkdir -p "${PREFIX_PORT_WORKDIR}"
      tar xf "${archive_path}" -C "${PREFIX_PORT_BUILD}"
    fi
  fi

  local to_build

  port_manager resolve "${name}-${version}"

  to_build="$(port_manager query deps-to-install "${name}-${version}")"

  for dep_port_def_dir in ${to_build}; do
    build_port "${dep_port_def_dir}" "${name}-${version}"
  done

  echo "${name}-${version}"
  to_build="$(port_manager query deps-to-install "${name}-${version}")"

  if [ -n "${to_build}" ]; then
    b_die "dependencies are still not installed: ${to_build}"
  fi

  local license_file_path="${PREFIX_PORT_WORKDIR}/${license_file}"
  if [ ! -f "${license_file_path}" ]; then
    b_die "license not found under ${license_file_path}"
  fi

  local port_install_path
  port_install_path="$(port_manager query install-path "${name}-${version}")"
  export PREFIX_PORT_INSTALL="${port_install_path}"
  PREFIX_H="${PREFIX_PORT_INSTALL}/include"
  PREFIX_A="${PREFIX_PORT_INSTALL}/lib"

  mkdir -p "${PREFIX_H}"
  mkdir -p "${PREFIX_A}"

  # shellcheck disable=2317 # may be used in p_* functions
  # b_optional_dir(dep_name)
  #  Returns installation directory of an optional dependency named ${dep_name}.
  #  This directory is a root to `lib` and `include` directories containing
  #  dependency libraries and headers. If optional dependency is not installed,
  #  returns empty string.
  function b_optional_dir() {
    local dependency_name="${1?dependency_name}"
    port_manager query dep-install-path "${name}-${version}" "${dependency_name}"
  }

  # shellcheck disable=2317 # as above
  # b_dependency_dir(dep_name)
  #  Returns installation directory of a required dependency named ${dep_name}.
  #  This directory is a root to `lib` and `include` directories containing
  #  dependency libraries and headers. If a required dependency is not
  #  installed, returns empty string (but if this happens, your port.def.sh is
  #  wrong!).
  function b_dependency_dir() {
    local dependency_name="${1?dependency_name}"
    local res="$(b_optional_dir "${dependency_name}")"
    if [[ -z "$res" ]]; then
      b_die "dependency for ${dependency_name} required but not installed!"
    fi
    echo "${res}"
  }

  export PKG_CONFIG_PATH="$(port_manager query deps-pkg-config-path "${name}-${version}")"

  # TODO: p_clean() ?
  [[ $(type -t p_common) == function ]] && p_common # definition is optional
  p_prepare
  p_build

  local port_dirname port_test_env_name
  port_dirname=$(basename "${def_dir}")
  port_test_env_name="PORTS_TEST_${port_dirname^^}"
  if [ "${!port_test_env_name}" = "y" ]; then
    [[ $(type -t p_build_test) == function ]] || b_die "${port_test_env_name}=y but p_build_test undefined"
    p_build_test
  fi

  port_manager installed "${name}-${version}"
}

function build_port() {
  (_build_port "$@")
}

b_log "Discovering ports"

port_defs=$(cd "${PREFIX_PROJECT}/phoenix-rtos-ports" && find . -name "port.def.sh" -exec realpath {} \;)

for port_def in $port_defs; do
  echo "found port definition: $port_def"

  load_port_def "${port_def}"

  : "${name?name missing}"
  : "${version?version missing}"

  if [ -z "${source}" ]; then
    [[ $(type -t p_source) == function ]] || b_die "source and p_source undefined"
  else
    : "${archive_filename?archive_filename missing}"
  fi

  : "${sha256?sha256 missing}"
  : "${size?size missing}"
  : "${license?license missing}"
  : "${license_file?license_file missing}"

  : "${src_path?src_path missing}"
  : "${conflicts?conflicts missing}"
  : "${depends?depends missing}"

  [[ $(type -t p_prepare) == function ]] || b_die "p_prepare undefined"
  [[ $(type -t p_build) == function ]] || b_die "p_build undefined"

  port_manager \
    discover "${name}-${version}" --def-dir "$(dirname "${port_def}")" \
    --requires "${depends}" \
    --optional "${optional}" \
    --conflicts "${conflicts}"
done

b_log "Building ports"

for port_def in $port_defs; do
  (
    def_dir="$(dirname "${port_def}")"
    port="$(basename "${def_dir}")"
    port_env_name="PORTS_${port^^}"
    if [ "${!port_env_name}" = "y" ]; then
      build_port "${def_dir}"
    fi
  )
done

b_log "Ports installed"

echo "Installed packages:"
port_manager query summary

exit 0
