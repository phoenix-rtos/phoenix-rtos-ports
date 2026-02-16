#!/usr/bin/env bash

def_path="${1?def_path missing}"

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

# TODO: add patch sources here instead of b_apply_patches

unset p_common
unset p_prepare
unset p_build
unset p_build_test

source "${def_path}"

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

jq -n \
  --arg namever "${name}-${version}" \
  --arg requires "${depends}" \
  --arg optional "${optional}" \
  --arg conflicts "${conflicts}" \
  '{namever: $namever, requires: $requires, optional: $optional, conflicts: $conflicts}'
