#!/usr/bin/env bash
#
# Port management
#
# port.def.sh to JSON loading script (invoked by port_manager.py)
#
# Copyright 2026 Phoenix Systems
# Author: Adam Greloch
#
# SPDX-License-Identifier: BSD-3-Clause
#

def_path="${1?def_path missing}"
source_dir="$(dirname "${BASH_SOURCE[0]}")"

source "${source_dir}/port_internal.subr"
load_port_def "${def_path}"

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

# shellcheck disable=2154 # variables loaded from port.def.sh
jq -n \
  --arg namever "${name}-${version}" \
  --arg requires "${depends}" \
  --arg optional "${optional}" \
  --arg conflicts "${conflicts}" \
  --arg iuse "${iuse}" \
  '{namever: $namever, requires: $requires, optional: $optional, conflicts: $conflicts, iuse: $iuse}'
