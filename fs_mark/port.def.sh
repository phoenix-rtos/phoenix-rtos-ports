#!/usr/bin/env bash
:
#shellcheck disable=2034
{
  ports_api=1

  name="fs_mark"
  version="3.3"

  commit="2628be58146de63a13260ff64550f84275556c0e"

  source="https://github.com/josefbacik/fs_mark/archive/"
  archive_filename="${commit}.tar.gz"
  src_path="${name}-${commit}/"

  size="22433"
  sha256="b64f723b388c1b7c5a2bb4fb28aaf9371214227c439a3ff5c6e71a0eb9ead011"

  license="GPL-2.0-only"
  license_file="COPYING"

  conflicts=""
  depends=""
  optional=""

  supports="phoenix>=3.3"
}

p_prepare() {
  b_port_apply_patches "${PREFIX_PORT_WORKDIR}"
}

p_build() {
  make -C "${PREFIX_PORT_WORKDIR}"

  cp -a "$PREFIX_PORT_WORKDIR/fs_mark" "$PREFIX_PROG/fs_mark"
  $STRIP -o "${PREFIX_PROG_STRIPPED}/fs_mark" "${PREFIX_PROG}/fs_mark"
  b_install "$PREFIX_PROG_TO_INSTALL/fs_mark" /bin
}
