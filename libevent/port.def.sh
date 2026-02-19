#!/usr/bin/env bash
:
#shellcheck disable=2034
{
  ports_api=1

  name="libevent"
  version="2.1.12"

  source="https://github.com/libevent/libevent/releases/download/release-${version}-stable/"
  archive_filename="${name}-${version}-stable.tar.gz"
  src_path="${name}-${version}-stable/"

  size="1100847"
  sha256="92e6de1be9ec176428fd2367677e61ceffc2ee1cb119035037a27d346b0403bb"

  license="BSD-3-Clause"
  license_file="LICENSE"

  conflicts=""
  depends=""
  optional=""

  supports="phoenix>=3.3"
}

p_prepare() {
  b_port_apply_patches "${PREFIX_PORT_WORKDIR}"

  if [ ! -f "${PREFIX_PORT_WORKDIR}/config.status" ]; then
    (cd "${PREFIX_PORT_WORKDIR}" && ./configure INSTALL="/usr/bin/install -p" CPPFLAGS="$CFLAGS" --host="$HOST" \
      --disable-thread-support --disable-openssl --disable-debug-mode --disable-libevent-regress \
      --disable-samples --enable-function-sections --disable-clock-gettime --disable-shared \
      --prefix="${PREFIX_PORT_INSTALL}" --includedir="${PREFIX_H}" --libdir="${PREFIX_A}")
  fi
}

p_build() {
  make -C "${PREFIX_PORT_WORKDIR}" install
}
