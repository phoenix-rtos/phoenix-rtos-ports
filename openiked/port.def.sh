#!/usr/bin/env bash
:
#shellcheck disable=2034
{
  ports_api=1

  name="openiked_portable"
  version="6.9.0"

  source="https://github.com/openiked/openiked-portable/archive/refs/tags/v"
  archive_filename="${version}.tar.gz"
  src_path="openiked-portable-${version}/"

  size="296532"
  sha256="091fb7bb3a1f708b8d620cb11dd5509091c0326293fb38f020a7b6c8909d19af"

  license="ISC"
  license_file="LICENSE"

  conflicts=""
  depends="openssl>=1.1.1a"
  optional=""

  supports="phoenix>=3.3"
}

p_prepare() {
  b_port_apply_patches "${PREFIX_PORT_WORKDIR}"
}

p_build() {
  build_dir="${PREFIX_PORT_WORKDIR}/build"

  # TODO: investigate cmake/autoconf being unable to find openssl on its own
  # despite PKG_CONFIG_PATH set. Well, we could just append CFLAGS/LDFLAGS in
  # build.sh and not care about pkg conf
  openssl_dir=$(b_dependency_dir "openssl")
  CFLAGS+=" -I${openssl_dir}/include"
  LDFLAGS+=" -L${openssl_dir}/lib"

  CFLAGS="-D__linux__ ${CFLAGS}"
  cmake -DCMAKE_SYSTEM_NAME=Linux -DCMAKE_BUILD_TYPE=Release -S "${PREFIX_PORT_WORKDIR}" -B "${build_dir}"
  make -C "${build_dir}" install DESTDIR="${build_dir}"

  cp -a "${build_dir}/usr/local/sbin/ikectl" "${PREFIX_PROG}/ikectl"
  cp -a "${build_dir}/usr/local/sbin/iked" "${PREFIX_PROG}/iked"

  $STRIP -o "${PREFIX_PROG_STRIPPED}/ikectl" "${PREFIX_PROG}/ikectl"
  $STRIP -o "${PREFIX_PROG_STRIPPED}/iked" "${PREFIX_PROG}/iked"

  b_install "${PREFIX_PROG_TO_INSTALL}/ikectl" /usr/bin
  b_install "${PREFIX_PROG_TO_INSTALL}/iked" /usr/bin
}
