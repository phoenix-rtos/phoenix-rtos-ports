#!/usr/bin/env bash

set -e


extract_sources() {
  if [ ! -d "${PREFIX_PORT_SRC}" ]; then
    echo "Extracting sources from ${archive_filename}"
    mkdir -p "${PREFIX_PORT_SRC}"
    tar -axf "${PREFIX_PORT}/${archive_filename}" --strip-components 1 -C "${PREFIX_PORT_SRC}"
  fi
}


exec_configure() {
  (cd "${PREFIX_PORT_SRC}" && autoreconf -vfi &&
    "${PREFIX_PORT_SRC}/configure" CFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS}" \
    --host="${HOST%phoenix}linux" --bindir="${PREFIX_PROG}" --sbindir="${PREFIX_PROG}" \
    --libdir="${PREFIX_A}" --includedir="${PREFIX_H}" \
    --prefix="${PREFIX_PORT_INSTALL}" --datarootdir="${PREFIX_A}" "${@}" \
    --disable-shared --enable-static --enable-silent-rules
  )
}


build_libpng() {
  appname="libpng"
  version="1.6.44"

  b_log "png: building ${appname}"

  archive_filename="${appname}-${version}.tar.gz"
  PREFIX_PORT_SRC="${PREFIX_PORT_BUILD}/${appname}/${version}"
  b_port_download "http://prdownloads.sourceforge.net/libpng/" "${archive_filename}"

  extract_sources

  echo  "${appname}/${version}"
  b_port_apply_patches "${PREFIX_PORT_SRC}" "${appname}/${version}"

  if [ ! -f "${PREFIX_PORT_SRC}/config.status" ]; then
    exec_configure
  fi

  make -C "${PREFIX_PORT_SRC}" PREFIX="${PREFIX_PORT_BUILD}"
  make -C "${PREFIX_PORT_SRC}" PREFIX="${PREFIX_PORT_BUILD}" install
}


build_libpng


rm -rf "$TMP_DIR"
