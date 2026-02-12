#!/bin/bash

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

export -f load_port_def

PREFIX_PORTS_BUILD_ROOT="${PREFIX_BUILD?}/port-sources"

def_path="${1?def_path missing}"
fd="${2}"

reset_env

if [ ! -f "${def_path}" ]; then
  b_die "WARNING: port.def.sh not found: ${def_path}"
fi

load_port_def "${def_path}"

export PREFIX_PORT="$(dirname ${def_path})"
export PREFIX_PORT_BUILD="${PREFIX_PORTS_BUILD_ROOT?}/${name}-${version}"

# shellcheck disable=1091
source "${PREFIX_PROJECT?}/phoenix-rtos-ports/build.subr"

# at this point the port.def.sh is assumed valid

export PREFIX_PORT_WORKDIR="${PREFIX_PORT_BUILD?}/${src_path}"

if [ ! -d "${PREFIX_PORT_WORKDIR}" ]; then
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

export PREFIX_H="${PREFIX_PORT_INSTALL}/include"
export PREFIX_A="${PREFIX_PORT_INSTALL}/lib"

mkdir -p "${PREFIX_H}"
mkdir -p "${PREFIX_A}"

[[ $(type -t p_common) == function ]] && p_common # definition is optional
p_prepare

printenv -0 >&${fd}
