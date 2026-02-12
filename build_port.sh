#!/bin/bash

load_port_def "${1?def_dir missing}"

export PREFIX_H="${PREFIX_PORT_INSTALL}/include"
export PREFIX_A="${PREFIX_PORT_INSTALL}/lib"

license_file_path="${PREFIX_PORT_WORKDIR}/${license_file}"
if [ ! -f "${license_file_path}" ]; then
  b_die "license not found under ${license_file_path}"
fi

# shellcheck disable=2317 # may be used in p_* functions
# b_optional_dir(dep_name)
#  Returns installation directory of an optional dependency named ${dep_name}.
#  This directory is a root to `lib` and `include` directories containing
#  dependency libraries and headers. If optional dependency is not installed,
#  returns empty string.
function b_optional_dir() {
  local dependency_name_env_name="PORT_DEP_${1?dependency_name}"
  echo "${!dependency_name_env_name}"
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

# TODO: p_clean() ?
# [[ $(type -t p_common) == function ]] && p_common # definition is optional
# p_prepare
p_build

port_dirname=$(basename "${def_dir}")
port_test_env_name="PORTS_TEST_${port_dirname^^}"
if [ "${!port_test_env_name}" = "y" ]; then
  [[ $(type -t p_build_test) == function ]] || b_die "${port_test_env_name}=y but p_build_test undefined"
  p_build_test
fi
