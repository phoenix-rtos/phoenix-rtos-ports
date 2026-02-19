#!/usr/bin/env bash
:
#shellcheck disable=2034
{
  ports_api=1

  name="jansson"
  version="2.12"

  source="http://www.digip.org/jansson/releases/"
  archive_filename="${name}-${version}.tar.bz2"
  src_path="${name}-${version}/"

  size="404669"
  sha256="645d72cc5dbebd4df608d33988e55aa42a7661039e19a379fcbe5c79d1aee1d2"

  license="MIT"
  license_file="LICENSE"

  conflicts=""
  depends=""
  optional=""

  supports="phoenix>=3.3"
}

p_prepare() {
  # hacks for incremental build:
  # - use "install -p" to preserve timestamps in headers
  # - use "echo" instead of "ranlib" to not overwrite static lib with every recompile (note: using ar -s while linking instead)
  if [ ! -f "$PREFIX_PORT_WORKDIR/config.status" ]; then
    (cd "${PREFIX_PORT_WORKDIR}" && "./configure" CFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS}" ARFLAGS="\"-r -s\"" RANLIB="echo" INSTALL="$(which install) -p" \
      --enable-static --disable-shared --host="$HOST" \
      --prefix="${PREFIX_PORT_INSTALL}" --libdir="${PREFIX_A}" --includedir="${PREFIX_H}")
  fi
}

p_build() {
  make -C "$PREFIX_PORT_WORKDIR" install
}
