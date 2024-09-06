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


rm -rf "$TMP_DIR"
