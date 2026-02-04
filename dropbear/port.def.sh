#!/usr/bin/env bash
:
#shellcheck disable=2034
{
  name="dropbear"
  version="2018.76"

  source="https://matt.ucc.asn.au/dropbear/releases/"
  archive_filename="${name}-${version}.tar.bz2"
  src_path="${name}-${version}/"

  size="2688697"
  sha256="f2fb9167eca8cf93456a5fc1d4faf709902a3ab70dd44e352f3acbc3ffdaea65"

  license="MIT"
  license_file="LICENSE"

  conflicts=""
  depends=""
  optional="zlib>=1.2.11"
}

p_prepare() {
  b_port_apply_patches "${PREFIX_PORT_WORKDIR}"

  if [ ! -f "$PREFIX_PORT_WORKDIR/config.h" ]; then
    cp -a "$PREFIX_PORT/localoptions.h" "$PREFIX_PORT_WORKDIR"

    DROPBEAR_CFLAGS="-DENDIAN_LITTLE -DUSE_DEV_PTMX ${DROPBEAR_CUSTOM_CFLAGS}"
    DROPBEAR_LDFLAGS=""

    ENABLE_ZLIB="no"
    zlib_dir=$(b_optional_dir "zlib")
    if [ -n "${zlib_dir}" ]; then
      ENABLE_ZLIB="yes"
    fi

    export OLDCFLAGS="-v" # HACKISH: fix ./configure script not detecting externally-provided CFLAGS

    # FIXME: -Wno-error=incompatible-pointer-types needed as dropbear uses uint* instead of enum* in cli-kex.c:117.
    (cd "${PREFIX_PORT_WORKDIR}" && ./configure CFLAGS="${CFLAGS} ${DROPBEAR_CFLAGS} -Wno-error=incompatible-pointer-types" \
      LDFLAGS="${CFLAGS} ${LDFLAGS} ${DROPBEAR_LDFLAGS}" ARFLAGS="-r" \
      --host="${HOST}" --prefix="${PREFIX_PORT_INSTALL}" --enable-zlib="$ENABLE_ZLIB" --enable-static \
      --disable-lastlog --disable-utmp --disable-utmpx --disable-wtmp --disable-wtmpx --disable-harden)
  fi
}

p_build() {
  # create multi-binary and hardlinks
  make PROGRAMS="dropbear dbclient dropbearkey scp" -C "${PREFIX_PORT_WORKDIR}" CROSS_COMPILE="$CROSS" MULTI=1 NO_ADDTL_WARNINGS=1

  $STRIP -o "$PREFIX_PROG_STRIPPED/dropbearmulti" "$PREFIX_PORT_WORKDIR/dropbearmulti"
  cp -a "$PREFIX_PORT_WORKDIR/dropbearmulti" "$PREFIX_PROG/dropbearmulti"

  b_install "$PREFIX_PROG_TO_INSTALL/dropbearmulti" /usr/bin

  mkdir -p "$PREFIX_ROOTFS/usr/sbin"
  ln -vf "$PREFIX_ROOTFS/usr/bin/dropbearmulti" "$PREFIX_ROOTFS/usr/sbin/dropbear"
  ln -vf "$PREFIX_ROOTFS/usr/bin/dropbearmulti" "$PREFIX_ROOTFS/usr/bin/dbclient"
  ln -vf "$PREFIX_ROOTFS/usr/bin/dropbearmulti" "$PREFIX_ROOTFS/usr/bin/scp"
}
