#!/usr/bin/env bash
:
#shellcheck disable=2034
{
  ports_api=1

  name="tetware_phoenix"
  version="2.0"

  lsb_version="${version}-1"

  source="http://www.opengroup.org/infosrv/lsb/ogdeliverables/LSB-VSX${lsb_version}"
  archive_filename="tet_vsxgen_3.02.tgz"
  src_path="/"

  size="1146294"
  sha256="56d406833c209aa175065af83e26246f85468da6e1bdbf65b4d2e0cb0db41c62"

  license="Artistic-1.0"
  license_file="Licence"

  conflicts=""
  depends="vsx_host>=2.0"
  optional=""

  supports="phoenix>=3.3"
}

p_common() {
  # TODO(adamgreloch): the install_path is then shared by any test suites on top
  # of TET, e.g. VSX. Is there any better way to handle this other than
  # hardcoding across these ports?
  export lsb_install_path="${PREFIX_BUILD}/lsb_vsx_phoenix"
  export test_sets_path="${lsb_install_path}/test_sets"
  export TET_EXECUTE="${test_sets_path}/TESTROOT"
  export TET_ROOT="${lsb_install_path}"
  export VSXDIR="${test_sets_path}/SRC"
}

p_prepare() {
  # Fix permissions
  chmod -R u+w "${PREFIX_PORT_WORKDIR}"
  chmod +x "${PREFIX_PORT_WORKDIR}/configure"
  chmod +x "${PREFIX_PORT_WORKDIR}/src/tetconfig"
  chmod +x "${PREFIX_PORT_WORKDIR}/test_sets/setup_testsets.sh"

  COPTS="$(echo "$CFLAGS" | sed 's/-I[^ ]* //g')"

  # TODO: needed?
  export PATH="${TET_ROOT}/test_sets/BIN:${TET_EXECUTE}/BIN:$PATH"

  (cd "${PREFIX_PORT_WORKDIR}" && ./configure -t lite >/dev/null)

  sed -e "s|^CC =.*$|CC = ${CC}|" \
    -e "s|^LD_R =.*$|LD_R = ${LD} -r|" \
    -e "s|^LDFLAGS =.*$|LDFLAGS = ${CFLAGS} ${LDFLAGS}|" \
    -e "s|^AR =.*$|AR = ${AR}|" \
    -e "s|^CDEFS =\(.*\)$|CDEFS =\1 -I${PREFIX_BUILD}/sysroot/usr/include|" \
    -e "s|^COPTS =.*$|COPTS = ${COPTS} -std=gnu89|" \
    -e "s|^THR_COPTS =\(.*\)$|THR_COPTS =\1 -std=gnu89|" \
    -e "s|^SHLIB_COPTS =.*$|SHLIB_COPTS = SHLIB_NOT_SUPPORTED|" \
    -e "s|^C_PLUS = .*$|C_PLUS = CPLUSPLUS_NOT_SUPPORTED|" \
    "${PREFIX_PORT}/files/defines.mk" >"${PREFIX_PORT_WORKDIR}/src/defines.mk"

  (cd "${PREFIX_PORT_WORKDIR}/src" && "./tetconfig" -t lite)

  b_port_apply_patches "${PREFIX_PORT_WORKDIR}" "phoenix"
}

p_build() {
  # Disable parallel building as it is not supported and may cause build failures
  export MAKEFLAGS="${MAKEFLAGS}${MAKEFLAGS:+ }-j1"

  mkdir -p "${lsb_install_path}"

  make -C "${PREFIX_PORT_WORKDIR}/src" all
  make -C "${PREFIX_PORT_WORKDIR}/src" install

  chmod -R u+w "${lsb_install_path}"

  "$STRIP" -o "${PREFIX_PROG_STRIPPED}/tcc" "${PREFIX_PORT_WORKDIR}/bin/tcc"
  b_install "${PREFIX_PROG_TO_INSTALL}/tcc" "/usr/bin"

  cp -ap "${PREFIX_PORT_WORKDIR}"/. "${lsb_install_path}"
}
