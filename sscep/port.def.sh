#!/usr/bin/env bash
:
#shellcheck disable=2034
{
  name="sscep"
  version="0.9.0"

  source="https://github.com/certnanny/sscep/archive/refs/tags/v"
  archive_filename="${version}.tar.gz"
  src_path="${name}-${version}/"

  size="97647"
  sha256="79361fc7560e55c6fa2fedec7e054ac3d882dadb0ab6951172c3e0e22cf61b1c"

  license="OpenSSL"
  license_file="COPYING"

  conflicts=""
  depends="openssl>=1.1.1a"
  optional=""
}

p_prepare() {
  b_port_apply_patches "${PREFIX_PORT_WORKDIR}"

  if [ ! -f "$PREFIX_PORT_WORKDIR/configure" ]; then
    (cd "$PREFIX_PORT_WORKDIR" && ./bootstrap.sh)
  fi

  if [ ! -f "$PREFIX_PORT_WORKDIR/config.status" ]; then
    (cd "$PREFIX_PORT_WORKDIR" && ./configure --disable-shared --prefix="${PREFIX_PORT_INSTALL}" --host="$HOST" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS")
  fi
}

p_build() {
  make -C "$PREFIX_PORT_WORKDIR"
  make -C "$PREFIX_PORT_WORKDIR" install

  cp -a "${PREFIX_PORT_INSTALL}/bin/sscep" "${PREFIX_PROG}/sscep"
  $STRIP -o "${PREFIX_PROG_STRIPPED}/sscep" "${PREFIX_PROG}/sscep"

  b_install "${PREFIX_PROG_TO_INSTALL}/sscep" /usr/bin
}
