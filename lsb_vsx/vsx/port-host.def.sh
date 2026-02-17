#!/usr/bin/env bash
:
#shellcheck disable=2034
{
  name="vsx_host"
  version="2.0"

  lsb_version="${version}-1"

  source="http://www.opengroup.org/infosrv/lsb/ogdeliverables/LSB-VSX${lsb_version}"
  archive_filename="lts_vsx-pcts2.0beta.tgz"
  src_path="/"

  size="2208822"
  sha256="3231a264293b5c271ac28d96e85bbb2d0664e816e488505ad6b744645dd4692b"

  license="LicenseRef-VSX-PCTS" # Artistic-1.0 derivation
  license_file="Licence.VSX-PCTS"

  conflicts=""
  depends="tetware_host>=2.0"
  optional=""
}

p_common() {
  export lsb_install_path="${PREFIX_BUILD}/lsb_vsx_host"
  export test_sets_path="${lsb_install_path}/test_sets"
}

p_prepare() {
  # Fix permissions
  chmod -R u+w "${PREFIX_PORT_WORKDIR}"

  TET_EXECUTE="${test_sets_path}/TESTROOT"
  VSXDIR="${test_sets_path}/SRC"

  # TODO(adamgreloch): is there really no better way to achieve correct build
  # than sed patching?
  mkdir -p "${PREFIX_PORT_WORKDIR}/host_config"
  sed -e "s|^CC=.*$|CC=\"/bin/cc\"|" \
    -e "s|^COPTS=.*$|COPTS=\"-std=gnu89\"|" \
    -e "s|^INCDIRS=.*$|INCDIRS=\"/usr/include /usr/include/x86_64-linux-gnu\"|" \
    -e "s|^#PATH=\(.*\)$|PATH=\1|" \
    -e "s|^TET_EXECUTE=.*$|TET_EXECUTE=\"${TET_EXECUTE}\"|" \
    -e "s|^VSXDIR=.*$|VSXDIR=\"${VSXDIR}\"|" \
    -e "s|^VSX_ORG=.*$|VSX_ORG=\"Phoenix Systems\"|" \
    -e "s|^VSX_OPER=.*$|VSX_OPER=\"${USER:-Unknown}\"|" \
    -e "s|^SUBSETS=.*$|SUBSETS=\"base\"|" \
    -e "s|^RPCLIB=.*$|RPCLIB=\"\"|" \
    -e "s|^NOSPC_DEV=.*$|NOSPC_DEV=\"NOSPC_DEV\"|" \
    "${PREFIX_PORT}/files/vsxparams" >"${PREFIX_PORT_WORKDIR}/host_config/host_vsxparams"

  b_port_apply_patches "${PREFIX_PORT_WORKDIR}" "host"
}

p_build() {
  cp -ap "${PREFIX_PORT_WORKDIR}"/. "${test_sets_path}"
  (
    cd "${test_sets_path}" &&
      TET_ROOT="${lsb_install_path}" HOME="${test_sets_path}" ./setup_testsets.sh
  )

  b_install_host "${test_sets_path}/BIN/vbuild"
  b_install_host "${test_sets_path}/SRC/BIN/chmog"
}
