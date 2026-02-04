#!/usr/bin/env bash
:
#shellcheck disable=2034
{
  name="lighttpd"
  version="1.4.79"

  source="https://download.lighttpd.net/lighttpd/releases-1.4.x/"
  archive_filename="${name}-${version}.tar.gz"
  src_path="${name}-${version}/"

  size="1237430"
  sha256="72a625243de607802b74bd6ae243716cb65757aba8e74a40321cbd74cf12c9c8"

  license="BSD-3-Clause"
  license_file="COPYING"

  conflicts=""
  depends="pcre>=8.42 openssl>=1.1.1a"
  optional="zlib>=1.2.11"
}

p_prepare() {
  b_port_apply_patches "${PREFIX_PORT_WORKDIR}"

  if [ ! -f "$PREFIX_PORT_WORKDIR/config.h" ]; then
    CONFIGFILE=$(find "${PREFIX_ROOTFS:?PREFIX_ROOTFS not set!}/etc" -name "lighttpd.conf")
    grep mod_ "$CONFIGFILE" | cut -d'"' -f2 | xargs -L1 -I{} echo "PLUGIN_INIT({})" >"$PREFIX_PORT_WORKDIR"/src/plugin-static.h

    LIGHTTPD_CFLAGS="-DLIGHTTPD_STATIC -DPHOENIX"

    WITH_ZLIB="no"
    zlib_dir=$(b_optional_dir "zlib")
    if [ -n "${zlib_dir}" ]; then
      WITH_ZLIB="yes"
      CFLAGS+=" -I${zlib_dir}/include"
      LDFLAGS+=" -L${zlib_dir}/lib"
    fi

    # Increase the stack size. A 32 kB array allocated on the stack was causing a stack overflow on the Phoenix-RTOS.
    LDFLAGS="${LDFLAGS} -z stack-size=65536"

    # FIXME: lighttpd ./configure ignores custom openssl location provided by pkg-config
    (cd "$PREFIX_PORT_WORKDIR" && "./autogen.sh")
    (cd "$PREFIX_PORT_WORKDIR" && "./configure" LIGHTTPD_STATIC=yes CFLAGS="${LIGHTTPD_CFLAGS} ${CFLAGS}" CPPFLAGS="" LDFLAGS="${LDFLAGS}" AR_FLAGS="-r" \
      -C --disable-ipv6 --disable-mmap --with-bzip2=no \
      --with-zlib="$WITH_ZLIB" --enable-shared=no --enable-static=yes --disable-shared --host="$HOST" \
      --with-openssl="$(b_dependency_dir 'openssl')" \
      --with-pcre="$(b_dependency_dir "pcre")" \
      --enable-silent-rules \
      --prefix="$PREFIX_PORT_WORKDIR" --sbindir="$PREFIX_PROG")

    set +e
    ex "+/HAVE_MMAP 1/d" "+/HAVE_MUNMAP 1/d" "+/HAVE_GETRLIMIT 1/d" "+/HAVE_SYS_POLL_H 1/d" \
      "+/HAVE_SIGACTION 1/d" "+/HAVE_DLFCN_H 1/d" -cwq "$PREFIX_PORT_WORKDIR/config.h"
    set -e
  fi
}

p_build() {
  make -C "${PREFIX_PORT_WORKDIR}" install

  $STRIP -o "$PREFIX_PROG_STRIPPED/lighttpd" "$PREFIX_PROG/lighttpd"
  b_install "$PREFIX_PROG_TO_INSTALL/lighttpd" /usr/sbin
}
