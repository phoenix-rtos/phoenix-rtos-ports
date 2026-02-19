#!/usr/bin/env bash
:
#shellcheck disable=2034
{
  ports_api=1

  name="smolrtsp"
  version="0.1.3"

  source="https://github.com/OpenIPC/smolrtsp/archive/refs/tags/v"
  archive_filename="${version}.tar.gz"
  src_path="${name}-${version}/"

  size="1471348"
  sha256="cc4376569b687e03385664584b57697076e6772a1c52de2d24389014e016ad1e"

  license="MIT"
  license_file="LICENSE"

  conflicts=""
  depends=""
  optional=""

  supports="phoenix>=3.3"
}

p_prepare() {
  b_port_apply_patches "${PREFIX_PORT_WORKDIR}"
}

p_build() {
  build_dir="${PREFIX_PORT_WORKDIR}/build"
  cmake -DCMAKE_INSTALL_PREFIX="$PREFIX_PORT_INSTALL" -DCMAKE_BUILD_TYPE=Release -S "${PREFIX_PORT_WORKDIR}" -B "${build_dir}"
  cmake --build "${build_dir}"
  cmake --install "${build_dir}"
}
