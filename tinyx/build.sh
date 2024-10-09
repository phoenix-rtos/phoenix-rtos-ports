#!/usr/bin/env bash

set -e

PREFIX_SHARE="${PREFIX_A}/share/"

# FIXME there *should* be a clean way to disable doc building via autotools config
TMP_DIR=$(mktemp -d)

inner_log() {
  echo -e "$1"
}


extract_sources() {
  if [ ! -d "${PREFIX_PORT_SRC}" ]; then
    echo "Extracting sources from ${archive_filename}"
    mkdir -p "${PREFIX_PORT_SRC}"
    tar -axf "${PREFIX_PORT}/${archive_filename}" --strip-components 1 -C "${PREFIX_PORT_SRC}"
  fi
}


exec_configure() {
  (cd "${PREFIX_PORT_SRC}" &&
    autoreconf -vfi && # reconf, as there may be patches to configure.ac
    "${PREFIX_PORT_SRC}/configure" CFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS}" \
    --host="${HOST%phoenix}linux" --sbindir="${PREFIX_PROG}" \
    --libdir="${PREFIX_A}" --includedir="${PREFIX_H}" \
    --prefix="${PREFIX_PORT_INSTALL}" --datarootdir="${PREFIX_A}" "${@}" \
    --disable-shared --enable-static --enable-silent-rules
  )
}


md5_checksum() {
  if [ ! -d "$1" ]; then
    echo "no patches"
  else
    tar cfP - "$1" | md5sum
  fi
}


port_cleanup() {
  if [ -z "${1}" ]; then
    echo "port_cleanup: no arg provided"
  fi
  rm -rf "${PREFIX_PORT_SRC}"
  rm -rf "${PREFIX_PORT_BUILD}/markers/${1}"
}


# TODO: add dependency rebuild on patch change, i.e. tinyxlib rebuild -> tinyx,
#  ico rebuild
should_reconfigure() {
  patch_subdir="${1}"
  marker_dir="${PREFIX_PORT_BUILD}/markers/${patch_subdir}"
  patch_dir="${PREFIX_PORT}/patches/${patch_subdir}"

  built_md5_path="${marker_dir}/built.md5"

  if [ ! -f "${built_md5_path}" ]; then
    inner_log "Patch and configure ${patch_subdir} from scratch"
    port_cleanup "${patch_subdir}"

    true
  else
    patch_md5=$(md5_checksum "${patch_dir}")
    if [ "${patch_md5}" = "$(cat "${built_md5_path}")" ]; then
      inner_log "${patch_subdir} up-to-date, not reconfiguring"
      false
    else
      inner_log "Cleaning ${patch_subdir} up after previous patch set"
      port_cleanup "${patch_subdir}"

      inner_log "Patch and reconfigure ${patch_subdir} from scratch"
      true
    fi
  fi
}


mark_as_configured() {
  patch_subdir="${1}"
  marker_dir="${PREFIX_PORT_BUILD}/markers/${patch_subdir}"
  mkdir -p "${marker_dir}"

  patch_dir="${PREFIX_PORT}/patches/${patch_subdir}"

  built_md5_path="${marker_dir}/built.md5"
  md5_checksum "${patch_dir}" > "${built_md5_path}"
}


_build_xorgproto() {
  b_log "tinyx: building xorgproto"

  version="2023.1"
  archive_filename="xorgproto-${version}.tar.gz"

  PREFIX_PORT_SRC="${PREFIX_PORT_BUILD}/xorgproto/${version}"
  b_port_download "https://www.x.org/archive/individual/proto/" "${archive_filename}"

  port_cleanup "xorgproto/${version}"

  extract_sources

  if [ ! -f "${PREFIX_PORT_SRC}/config.status" ]; then
    exec_configure --disable-specs --docdir="${TMP_DIR}/doc"
  fi

  b_port_apply_patches "${PREFIX_PORT_SRC}" "xorgproto/${version}"

  make -C "${PREFIX_PORT_SRC}"
  make -C "${PREFIX_PORT_SRC}" install

  rm -rf "${PREFIX_H}/GL" # GL headers (possibly) unnecessary for now
}


build_tinyxlib() {
  b_log "tinyx: building tinyxlib"

  ref="9862f359a745be8ee8f6505571e09c38e2439c6d"
  short_ref=$(echo ${ref} | cut -c -6)
  archive_filename="${ref}.tar.gz"

  PREFIX_PORT_SRC="${PREFIX_PORT_BUILD}/tinyxlib/${short_ref}"
  b_port_download "https://github.com/idunham/tinyxlib/archive/" "${archive_filename}"

  # TODO move make outside of reconfigure block
  if should_reconfigure "tinyxlib/${short_ref}"; then
    extract_sources

    b_port_apply_patches "${PREFIX_PORT_SRC}" "tinyxlib/${short_ref}"

    # set up a dir for X11 files (currently just for XKeysymDB)
    mkdir -p "$PREFIX_SHARE/X11" # FIXME path chosen arbitrarily

    make -C "${PREFIX_PORT_SRC}"
    make -C "${PREFIX_PORT_SRC}" LIBDIR="${PREFIX_A}" INCDIR="${PREFIX_H}" install

    # Install libxtrans
    cp -ar "${PREFIX_PORT_SRC}/libxtrans/." "${PREFIX_H}/X11/Xtrans"
    ln -sf "${PREFIX_H}/X11/Xtrans.h" "${PREFIX_H}/X11/Xtrans/Xtrans.h"

    # remove sync.h, syncstr.h to avoid conflict with xorgproto
    rm "${PREFIX_H}/X11/extensions/sync.h"
    rm "${PREFIX_H}/X11/extensions/syncstr.h"

    _build_xorgproto

    mark_as_configured "tinyxlib/${short_ref}"
  fi
}


build_a_lib() {
  libname="$1"
  version="$2"
  configure_opts=${@:3}

  b_log "tinyx: building ${libname}"

  archive_filename="${libname}-${version}.tar.gz"

  PREFIX_PORT_SRC="${PREFIX_PORT_BUILD}/${libname}/${version}"

  b_port_download "https://www.x.org/archive/individual/lib/" "${archive_filename}"

  if should_reconfigure "${libname}/${version}"; then
    extract_sources

    b_port_apply_patches "${PREFIX_PORT_SRC}" "${libname}/${version}"

    if [ ! -f "${PREFIX_PORT_SRC}/config.status" ]; then
      exec_configure ${configure_opts}
    fi

    mark_as_configured "${libname}/${version}"
  fi

  make -C "${PREFIX_PORT_SRC}"
  make -C "${PREFIX_PORT_SRC}" install
}


build_tinyx() {
  b_log "tinyx: building xserver"

  ref="eed4902840732f170a7020cedb381017de99f2e6"
  short_ref=$(echo ${ref} | cut -c -6)
  archive_filename="${ref}.tar.gz"

  PREFIX_PORT_SRC="${PREFIX_PORT_BUILD}/tinyx/${short_ref}"
  b_port_download "https://github.com/tinycorelinux/tinyx/archive/" "${archive_filename}"

  if should_reconfigure "tinyx/${short_ref}"; then
    extract_sources

    if [ ! -d "${PREFIX_PORT_SRC}/kdrive/phoenix/" ]; then
      mkdir -p "${PREFIX_PORT_SRC}/kdrive/phoenix/"
      cp "${PREFIX_PORT_SRC}/kdrive/linux/mouse.c" "${PREFIX_PORT_SRC}/kdrive/phoenix/mouse.c"
    fi

    b_port_apply_patches "${PREFIX_PORT_SRC}" "tinyx/${short_ref}"

    if [ ! -f "${PREFIX_PORT_SRC}/config.status" ]; then
      exec_configure --disable-xres --disable-screensaver --disable-xdmcp \
        --disable-dpms --disable-xf86bigfont --disable-xdm-auth-1 \
        --disable-dbe --host="${HOST}" \
        --with-default-font-path="built-ins" # otherwise won't find 'fixed'. libxfont/src/fontfile.c:FontFileNameCheck()

      # (brutally) force static compilation in generated Makefiles
      # FIXME do it properly by patching configure.ac instead?
      find . -name 'Makefile' -print0 | xargs -0 sed -i 's/ -lz/ -l:libz.a/g;s/ -lXfont/ -l:libXfont.a/g;s/ -lfontenc/ -l:libfontenc.a/g;s/-lm//g'
    fi
    mark_as_configured "tinyx/${short_ref}"
  fi

  make -C "${PREFIX_PORT_SRC}"

  ${STRIP} -o "${PREFIX_PROG_STRIPPED}/Xfbdev" "${PREFIX_PORT_SRC}/kdrive/fbdev/Xfbdev"
  cp -a "${PREFIX_PORT_SRC}/kdrive/fbdev/Xfbdev" "${PREFIX_PROG}/Xfbdev"

  b_install "${PREFIX_PORTS_INSTALL}/Xfbdev" /usr/bin
}


build_x11_app() {
  appname="$1"
  version="$2"
  configure_opts=${@:3}

  b_log "tinyx: building ${appname}"

  archive_filename="${appname}-${version}.tar.gz"

  PREFIX_PORT_SRC="${PREFIX_PORT_BUILD}/${appname}/${version}"

  b_port_download "https://www.x.org/archive/individual/app/" "${archive_filename}"

  if should_reconfigure "${appname}/${version}"; then
    extract_sources

    b_port_apply_patches "${PREFIX_PORT_SRC}" "${appname}/${version}"

    if [ ! -f "${PREFIX_PORT_SRC}/config.status" ]; then
      exec_configure ${configure_opts}
    fi

    # FIXME: this is brutal, see build_tinyx note
    sedexpr='s/ -lXaw7/ -l:libXaw.a/g;s/ -lXt/ -l:libXt.a/g;'
    sedexpr+='s/ -lX11/ -l:libXmu.a -l:libXext.a -l:libSM.a -l:libICE.a -l:libXdmcp.a -l:libXpm.a -l:libX11.a/g;'
    sedexpr+='s/ -lXmuu/ -l:libXmuu.a -l:libXcursor.a -l:libXrender.a/g;s/ -lXcursor//g'

    find . -name 'Makefile' -print0 | xargs -0 sed -i "${sedexpr}"

    mark_as_configured "${appname}/${version}"
  fi

  make -C "${PREFIX_PORT_SRC}"

  binpath="${PREFIX_PORT_SRC}/${appname}"
  if [ ! -f "${binpath}" ]; then
    binpath="${PREFIX_PORT_SRC}/src/${appname}"
  fi
  $STRIP -o "${PREFIX_PROG_STRIPPED}/${appname}" "${binpath}"

  b_install "${PREFIX_PORTS_INSTALL}/${appname}" /usr/bin
}


build_suckless() {
  appname="$1"
  version="$2"

  b_log "tinyx: building ${appname}"

  archive_filename="${appname}-${version}.tar.gz"
  PREFIX_PORT_SRC="${PREFIX_PORT_BUILD}/${appname}/${version}"

  b_port_download "https://dl.suckless.org/${appname}/" "${archive_filename}"

  extract_sources

  b_port_apply_patches "${PREFIX_PORT_SRC}" "${appname}/${version}"

  make -C "${PREFIX_PORT_SRC}" PREFIX="${PREFIX_PORT_BUILD}"

  $STRIP -o "${PREFIX_PROG_STRIPPED}/${appname}" "${PREFIX_PORT_SRC}/${appname}"

  b_install "${PREFIX_PORTS_INSTALL}/${appname}" /usr/bin
}


build_xbill() {
  appname="xbill"
  version="2.1"

  b_log "tinyx: building ${appname}"

  archive_filename="${appname}-${version}.tar.gz"
  PREFIX_PORT_SRC="${PREFIX_PORT_BUILD}/${appname}/${version}"

  b_port_download "http://www.xbill.org/download/" "${archive_filename}"

  if should_reconfigure "${appname}/${version}"; then
    extract_sources

    b_port_apply_patches "${PREFIX_PORT_SRC}" "${appname}/${version}"

    if [ ! -f "${PREFIX_PORT_SRC}/config.status" ]; then
      exec_configure --datadir="/usr/share/"
    fi

    # FIXME: this is brutal, see build_tinyx note
    sedexpr='s/ -lXaw/ -l:libXaw.a/g;s/ -lXt/ -l:libXt.a/g;'
    sedexpr+='s/ -lX11/ -l:libXmu.a -l:libXext.a -l:libSM.a -l:libICE.a -l:libXdmcp.a -l:libXpm.a -l:libX11.a/g;'
    sedexpr+='s/ -lXmuu/ -l:libXmuu.a -l:libXcursor.a -l:libXrender.a/g;s/ -lXcursor//g'

    find . -name 'Makefile' -print0 | xargs -0 sed -i "${sedexpr}"

    mark_as_configured "${appname}/${version}"
  fi

  make -C "${PREFIX_PORT_SRC}" PREFIX="${PREFIX_PORT_BUILD}"

  $STRIP -o "${PREFIX_PROG_STRIPPED}/${appname}" "${PREFIX_PORT_SRC}/${appname}"

  b_install "${PREFIX_PORT_SRC}/pixmaps"/* /usr/share/xbill/pixmaps/
  b_install "${PREFIX_PORT_SRC}/bitmaps"/* /usr/share/xbill/bitmaps/
  b_install "${PREFIX_PORTS_INSTALL}/${appname}" /usr/bin
}


# Build xlib and xserver (call ordering is important here)

build_tinyxlib
build_a_lib     libfontenc  1.1.8
build_a_lib     libXfont    1.5.4 --disable-freetype # libXfont depends on libfontenc and headers from xorgproto/tinyxlib

build_tinyx

# Build window managers

build_suckless  dwm         5.1
build_x11_app   twm         1.0.12 # requires yacc

# Build client apps

build_suckless  st          0.2
build_x11_app   ico         1.0.4 # requires gettext
build_x11_app   xmessage    1.0.7
build_x11_app   xclock      1.1.1 --without-xft --without-xkb
build_x11_app   xeyes       1.1.1 --without-xrender
build_x11_app   xsetroot    1.1.1
build_x11_app   xinit       1.3.3
build_x11_app   xrdb        1.2.2
build_x11_app   xgc         1.0.6

# Fun stuff

build_xbill

rm -rf "$TMP_DIR"
