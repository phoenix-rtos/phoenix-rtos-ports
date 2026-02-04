#!/usr/bin/env bash
:
#shellcheck disable=2034
{
  name="lzo"
  version="2.10"

  source="http://www.oberhumer.com/opensource/lzo/download/"
  archive_filename="${name}-${version}.tar.gz"
  src_path="${name}-${version}/"

  size="600622"
  sha256="c0f892943208266f9b6543b3ae308fab6284c5c90e627931446fb49b4221a072"

  license="GPL-2.0-only"
  license_file="COPYING"

  conflicts=""
  depends=""
  optional=""
}

p_prepare() {
  if [ ! -f "$PREFIX_PORT_WORKDIR/config.h" ]; then
    (cd "$PREFIX_PORT_WORKDIR" && "./configure" --prefix="$PREFIX_PORT_INSTALL" \
      --exec-prefix="$PREFIX_PORT_INSTALL" --libdir="$PREFIX_A" --includedir="$PREFIX_H" \
      --host="${HOST}")
  fi
}

p_build() {
  make -C "$PREFIX_PORT_WORKDIR" install
}
