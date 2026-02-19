#!/usr/bin/env bash
:
#shellcheck disable=2034
{
  ports_api=1

  name="picocom"
  version="3.1"

  source="https://github.com/npat-efault/picocom/archive/refs/tags/"
  archive_filename="${version}.tar.gz"
  src_path="${name}-${version}/"

  size="121686"
  sha256="e6761ca932ffc6d09bd6b11ff018bdaf70b287ce518b3282d29e0270e88420bb"

  license="GPL-2.0-only"
  license_file="LICENSE.txt"

  conflicts=""
  depends=""
  optional=""

  supports="phoenix>=3.3"
}

p_prepare() {
  b_port_apply_patches "${PREFIX_PORT_WORKDIR}"
}

p_build() {
  LDFLAGS="${CFLAGS} $LDFLAGS" make -C "${PREFIX_PORT_WORKDIR}"

  cp -a "${PREFIX_PORT_WORKDIR}/picocom" "$PREFIX_PROG"
  $STRIP -o "$PREFIX_PROG_STRIPPED/picocom" "${PREFIX_PROG}/picocom"
  b_install "${PREFIX_PROG_TO_INSTALL}/picocom" /bin
}
