#!/usr/bin/env bash
:
#shellcheck disable=2034
{
  ports_api=1

  name="coreMQTT"
  version="2.3.0"

  source="https://github.com/FreeRTOS/coreMQTT/archive/refs/tags/"
  archive_filename="${name}-${version}.tar.gz"
  src_path="${name}-${version}/"

  size="831617"
  sha256="88fa0be88045a9f4895d688f286fc19a28fa539c503c7fc28b1248b9a8cf2c90"

  license="MIT"
  license_file="LICENSE"

  conflicts=""
  depends=""
  optional=""

  supports="phoenix>=3.3"
}

p_prepare() {
  cp -a "${PREFIX_PORT}/CMakeLists.txt" "${PREFIX_PORT_BUILD}/CMakeLists.txt"
}

p_build() {
  build_dir="${PREFIX_PORT_WORKDIR}/build"

  cmake -S "${PREFIX_PORT_BUILD}" -B "${build_dir}"
  make -C "${build_dir}"
  cmake --install "${build_dir}" --prefix "${PREFIX_PORT_INSTALL}"
}
