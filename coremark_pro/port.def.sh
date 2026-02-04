#!/usr/bin/env bash
:
#shellcheck disable=2034
{
  name="coremark_pro"
  version="1.0"

  commit="4832cc67b0926c7a80a4b7ce0ce00f4640ea6bec"

  source="https://codeload.github.com/eembc/coremark-pro/tar.gz/"
  archive_filename="coremark-pro-${commit}.tar.gz"
  src_path="coremark-pro-${commit}/"

  size="13792200"
  sha256="f687d3e964132056f00b9f67c0b7f91dd6ac6211239cf63c67b695df71d24e80"

  license="Apache-2.0"
  license_file="LICENSE.md"

  conflicts=""
  depends=""
  optional=""
}

p_prepare() {
  b_port_apply_patches "${PREFIX_PORT_WORKDIR}"
  cp -a "${PREFIX_PORT}/make/"*.mak "${PREFIX_PORT_WORKDIR}/util/make/"
}

p_build() {
  make -C "${PREFIX_PORT_WORKDIR}" TARGET="${HOST}" build

  # Remove empty data directory (not needed)
  rmdir "${PREFIX_PORT_WORKDIR}/builds/${HOST}/phoenix-gcc/bin/data"
  mkdir -p "${PREFIX_PROG}/coremark-pro"
  cp -a "${PREFIX_PORT_WORKDIR}/builds/${HOST}/phoenix-gcc/bin/"* "${PREFIX_PROG}/coremark-pro/"
  mkdir -p "${PREFIX_PROG_STRIPPED}/coremark-pro"

  # Strip the binaries
  for bin in "${PREFIX_PROG}/coremark-pro/"*; do
    $STRIP -o "${PREFIX_PROG_STRIPPED}/coremark-pro/$(basename "$bin")" "$bin"
  done

  # Install the binaries
  for bin in "${PREFIX_PROG_TO_INSTALL}/coremark-pro/"*; do
    b_install "$bin" /usr/bin/coremark-pro
  done
}
