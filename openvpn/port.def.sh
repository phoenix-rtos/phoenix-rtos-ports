#!/usr/bin/env bash
:
#shellcheck disable=2034
{
  name="openvpn"
  version="2.4.7"

  source="https://swupdate.openvpn.org/community/releases/"
  archive_filename="${name}-${version}.tar.gz"
  src_path="${name}-${version}/"

  size="1457784"
  sha256="73dce542ed3d6f0553674f49025dfbdff18348eb8a25e6215135d686b165423c"

  # TODO: verify whether it is GPL v2 *only*
  license="GPL-2.0-only"
  license_file="COPYING"

  conflicts=""
  depends="openssl>=1.1.1a lzo>=2.10"
  optional=""
}

p_prepare() {
  b_port_apply_patches "${PREFIX_PORT_WORKDIR}"

  if [ ! -f "$PREFIX_PORT_WORKDIR/config.h" ]; then
    OPENVPN_CFLAGS="-std=gnu99 -I${PREFIX_H}"
    (cd "$PREFIX_PORT_WORKDIR" && autoreconf -i -v -f)
    (cd "$PREFIX_PORT_WORKDIR" && "./configure" CFLAGS="$CFLAGS $OPENVPN_CFLAGS" LDFLAGS="$LDFLAGS" --host="${HOST}" --sbindir="$PREFIX_PROG" PKG_CONFIG_LIBDIR="${PKG_CONFIG_PATH}")
  fi
}

p_build() {
  make -C "$PREFIX_PORT_WORKDIR"
  make -C "$PREFIX_PORT_WORKDIR" install-exec

  $STRIP -o "$PREFIX_PROG_STRIPPED/openvpn" "$PREFIX_PROG/openvpn"
  b_install "$PREFIX_PROG_TO_INSTALL/openvpn" /sbin/
}
