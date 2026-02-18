#!/bin/bash
#
# Port management
#
# Port preparation script (invoked by port_manager.py)
#
# Copyright 2026 Phoenix Systems
# Author: Adam Greloch
#
# SPDX-License-Identifier: BSD-3-Clause
#

function check_size_sha256() {
  local actual_size="${1?}"
  local actual_sha256="${2?}"

  # shellcheck disable=2154 # size loaded from port.def.sh
  if [ "${actual_size}" != "${size}" ]; then
    rm -rf "${PREFIX_PORT_WORKDIR?}"
    b_die "size mismatch: expected '${size}', got '${actual_size}'"
  fi

  # shellcheck disable=2154 # sha256 loaded from port.def.sh
  if [ "${actual_sha256}" != "${sha256}" ]; then
    rm -rf "${PREFIX_PORT_WORKDIR?}"
    b_die "sha256 mismatch: expected '${sha256}', got '${actual_sha256}'"
  fi
}

set -e

source_dir="$(dirname "${BASH_SOURCE[0]}")"

source "${source_dir}/port.subr"
source "${source_dir}/port_internal.subr"

PREFIX_PORTS_BUILD_ROOT="${PREFIX_BUILD?}/port-sources"

def_path="${1?def_path missing}"
fd="${2}"

reset_env

if [ ! -f "${def_path}" ]; then
  b_die "WARNING: port.def.sh not found: ${def_path}"
fi

load_port_def "${def_path}"

unset_internal_env

PREFIX_PORT="$(dirname "${def_path}")"
export PREFIX_PORT

# shellcheck disable=2154 # name, version loaded from port.def.sh
export PREFIX_PORT_BUILD="${PREFIX_PORTS_BUILD_ROOT?}/${name}-${version}"

# shellcheck disable=1091
source "${PREFIX_PROJECT?}/phoenix-rtos-ports/build.subr"

# shellcheck disable=2154 # def_path loaded from port.def.sh
export PREFIX_PORT_WORKDIR="${PREFIX_PORT_BUILD?}/${src_path}"

if [ ! -d "${PREFIX_PORT_WORKDIR}" ]; then
  if [ -z "${source}" ]; then
    p_source
    actual_sha256="$(git archive --format=tar HEAD | sha256sum | cut -d' ' -f1)"
    actual_size="$(find "${PREFIX_PORT_WORKDIR}" -type f ! -path '*/.git/*' -exec stat -c %s {} + |
      awk '{sum+=$1} END {print sum}')"

    check_size_sha256 "${actual_size}" "${actual_sha256}"
  else
    # shellcheck disable=2154 # archive_filename loaded from port.def.sh
    b_port_download "${source}/" "${archive_filename}"

    archive_path="${PREFIX_PORT}/${archive_filename}"
    actual_size="$(wc -c <"${archive_path}")"
    actual_sha256="$( (sha256sum <"${archive_path}") | cut -d' ' -f1)"

    check_size_sha256 "${actual_size}" "${actual_sha256}"

    mkdir -p "${PREFIX_PORT_WORKDIR}"
    tar xf "${archive_path}" -C "${PREFIX_PORT_BUILD}"
  fi
fi

# shellcheck disable=2154 # license_file loaded from port.def.sh
license_file_path="${PREFIX_PORT_WORKDIR}/${license_file}"
if [ ! -f "${license_file_path}" ]; then
  b_die "license not found under ${license_file_path}"
fi

export PREFIX_H="${PREFIX_PORT_INSTALL}/include"
export PREFIX_A="${PREFIX_PORT_INSTALL}/lib"

mkdir -p "${PREFIX_H}"
mkdir -p "${PREFIX_A}"

[[ $(type -t p_common) == function ]] && p_common # definition is optional
p_prepare

printenv -0 >&"${fd}"
