#!/usr/bin/env bash
:
#shellcheck disable=2034
{
  name="busybox"
  version="1.27.2"

  source="https://busybox.net/downloads/"
  archive_filename="${name}-${version}.tar.bz2"
  src_path="${name}-${version}/"

  size="2216527"
  sha256="9d4be516b61e6480f156b11eb42577a13529f75d3383850bb75c50c285de63df"

  license="GPL-2.0-only"
  license_file="LICENSE"

  conflicts=""
  depends=""
  optional=""
}

p_prepare() {
  : "${BUSYBOX_CONFIG:="${PREFIX_PORT}/config"}"

  b_port_apply_patches "${PREFIX_PORT_WORKDIR}"

  if [ ! -f "${PREFIX_PORT_WORKDIR}/.config" ] || [ "${BUSYBOX_CONFIG}" -nt "${PREFIX_PORT_WORKDIR}/.config" ]; then
    cp -a "${BUSYBOX_CONFIG}" "${PREFIX_PORT_WORKDIR}"/.config
    make -C "${PREFIX_PORT_WORKDIR}" CROSS_COMPILE="$CROSS" CONFIG_PREFIX="$PREFIX_FS/root" clean
  fi

  # hackish: remove the final binary to re-link potential libc changes
  rm -rf "$PREFIX_PORT_WORKDIR/busybox_unstripped" "$PREFIX_PORT_WORKDIR/busybox"
}

p_build() {
  # For MacOS
  export LC_CTYPE=C
  if [ -n "$PORTS_INSTALL_STRIPPED" ] && [ "$PORTS_INSTALL_STRIPPED" = "n" ]; then
    UNSTRIPPED=y
  else
    UNSTRIPPED=n
  fi

  make -C "${PREFIX_PORT_WORKDIR}" CROSS_COMPILE="$CROSS" CONFIG_PREFIX="$PREFIX_FS/root" SKIP_STRIP="$UNSTRIPPED" all
  make -C "${PREFIX_PORT_WORKDIR}" CROSS_COMPILE="$CROSS" CONFIG_PREFIX="$PREFIX_FS/root" SKIP_STRIP="$UNSTRIPPED" install
  cp -a "$PREFIX_PORT_WORKDIR/busybox_unstripped" "$PREFIX_PROG"
}

p_build_test() {
  mkdir -p "$PREFIX_ROOTFS/usr/test/busybox"
  cp -a "$PREFIX_PORT_WORKDIR/testsuite" "$PREFIX_ROOTFS/usr/test/busybox"
  # busybox test suite requires .config file and busybox binary in the same bin directory
  cp "$PREFIX_PORT_WORKDIR/.config" "$PREFIX_ROOTFS/bin"
}
