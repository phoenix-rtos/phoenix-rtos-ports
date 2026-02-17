#!/bin/bash
#
# Port management
#
# Port building script (invoked by port_manager.py)
#
# Copyright 2026 Phoenix Systems
# Author: Adam Greloch
#
# SPDX-License-Identifier: BSD-3-Clause
#

set -e

def_dir="${1?def_dir missing}"
log_file="${2?log_file missing}"

exec > >(tee -a "${log_file}") 2>&1

source "$(dirname "${BASH_SOURCE[0]}")/port_internal.subr"

load_port_def "${def_dir}"

unset_internal_env

export PREFIX_H="${PREFIX_PORT_INSTALL}/include"
export PREFIX_A="${PREFIX_PORT_INSTALL}/lib"

# TODO: p_clean() ?
# [[ $(type -t p_common) == function ]] && p_common # definition is optional

p_build

if [ "${PORT_BUILD_TESTS}" = "y" ]; then
  [[ $(type -t p_build_test) == function ]] || b_die "\`tests: true\` but p_build_test undefined"
  p_build_test
fi
