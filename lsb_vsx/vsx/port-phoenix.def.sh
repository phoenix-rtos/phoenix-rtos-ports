#!/usr/bin/env bash
:
#shellcheck disable=2034
{
  ports_api=1

  name="vsx_phoenix"
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
  depends="vsx_host>=2.0 tetware_phoenix>=2.0 "
  optional=""

  supports="phoenix>=3.3"
}

p_common() {
  export lsb_install_path="${PREFIX_BUILD}/lsb_vsx_phoenix"
  export test_sets_path="${lsb_install_path}/test_sets"
  export TET_EXECUTE="${test_sets_path}/TESTROOT"
  export TET_ROOT="${lsb_install_path}"
  export VSXDIR="${test_sets_path}/SRC"
}

p_prepare() {
  # Fix permissions
  chmod -R u+w "${PREFIX_PORT_WORKDIR}"

  # TODO(adamgreloch): is there really no better way to achieve correct build
  # than sed patching?
  mkdir -p "${PREFIX_PORT_WORKDIR}/ps_config"
  sed -e "s|^CC=.*$|CC=\"${CC}\"|" \
    -e "s|^COPTS=.*$|COPTS=\"-std=gnu89\"|" \
    -e "s|^LDFLAGS=.*$|LDFLAGS=\"${CFLAGS} ${LDFLAGS}\"|" \
    -e "s|^AR=.*$|AR=\"${AR} cr\"|" \
    -e "s|^RANLIB=.*$|RANLIB=\"${CROSS}ranlib\"|" \
    -e "s|^INCDIRS=.*$|INCDIRS=\"${PREFIX_BUILD}/sysroot/usr/include\"|" \
    -e "s|^VSXDIR=.*$|VSXDIR=\"${VSXDIR}\"|" \
    -e "s|^TET_EXECUTE=.*$|TET_EXECUTE=\"${TET_EXECUTE}\"|" \
    -e "s|^VSX_ORG=.*$|VSX_ORG=\"Phoenix Systems\"|" \
    -e "s|^VSX_OPER=.*$|VSX_OPER=\"${USER:-Unknown}\"|" \
    -e "s|^VSX_SYS=.*$|VSX_SYS=\"Phoenix-RTOS\"|" \
    -e "s|^MLIB=.*$|MLIB=\"\"|" \
    -e "s|^SUBSETS=.*$|SUBSETS=\"base\"|" \
    -e "s|^RPCLIB=.*$|RPCLIB=\"\"|" \
    -e "s|^NOSPC_DEV=.*$|NOSPC_DEV=\"NOSPC_DEV\"|" \
    "${PREFIX_PORT}/files/vsxparams" >"${PREFIX_PORT_WORKDIR}/ps_config/ps_vsxparams"

  b_port_apply_patches "${PREFIX_PORT_WORKDIR}" "phoenix"
}

p_build() {
  cp -ap "${PREFIX_PORT_WORKDIR}"/. "${test_sets_path}"

  # FIXME: tetexec.cfg doesn't exist - is it intended?
  (
    cd "${test_sets_path}" && HOME="${test_sets_path}" ./setup_testsets.sh
  )
}

p_build_test() {
  PATH="${PREFIX_BUILD}/host-prog:$PATH"

  # FIXME(adamgreloch): ttc won't find make, tr, sed otherwise - potentially it
  # truncates PATH?
  PATH="/usr/bin:$PATH"

  sed -e "s|^PATH=.*$|PATH=${PATH}|" \
    -e "s|^VSXDIR=.*$|VSXDIR=${VSXDIR}|" \
    "${PREFIX_PORT}/config/tetbuild.cfg" >"${test_sets_path}/tetbuild.cfg"

  (
    cd "${test_sets_path}" &&
      HOME="${test_sets_path}" "${PREFIX_BUILD}/host-prog/tcc" -p -b -s "${PREFIX_PORT}/config/scen.bld"
  )

  find "${test_sets_path}" -type f -executable -name "T.*" -print0 | while IFS= read -r -d '' test_path; do
    PREFIX_TESTROOT="${PREFIX_ROOTFS}/root/lsb_vsx/test_sets/TESTROOT"
    testroot_path="tset${test_path#*tset}"
    dir="$(dirname "$test_path")"
    mkdir -p "$(dirname "${PREFIX_TESTROOT}/$testroot_path")"

    # TODO: use b_install?
    if ! file "$test_path" | grep -q "ASCII text"; then
      mkdir -p "$(dirname "${PREFIX_PROG_STRIPPED}/lsb_vsx/$testroot_path")"
      "$STRIP" "$test_path" -o "${PREFIX_PROG_STRIPPED}/lsb_vsx/$testroot_path"
      cp -vp "$_" "${PREFIX_TESTROOT}/$testroot_path"
    else
      cp -vp "$test_path" "${PREFIX_TESTROOT}/$testroot_path"
    fi

    # Some tests also use subprocesses
    export PREFIX_TESTROOT
    find "$dir" -type f -executable ! -name "T.*" -print0 | while IFS= read -r -d '' subproc_path; do
      if [ -n "$subproc_path" ]; then
        testroot_path="tset${subproc_path#*tset}"
        # TODO: use b_install?
        if ! file "$subproc_path" | grep -q "shell script"; then
          "$STRIP" "$subproc_path" -o "${PREFIX_PROG_STRIPPED}/lsb_vsx/$testroot_path"
          cp -vp "$_" "${PREFIX_TESTROOT}/$testroot_path"
        else
          cp -vp "$subproc_path" "${PREFIX_TESTROOT}/$testroot_path"
        fi
      fi
    done
  done

  mkdir -p "${PREFIX_ROOTFS}/root/lsb_vsx/test_sets/TESTROOT"
  cp -vp "${PREFIX_PORT}/config/tetexec.cfg" "${PREFIX_ROOTFS}/root/lsb_vsx/test_sets/TESTROOT/tetexec.cfg"
}
