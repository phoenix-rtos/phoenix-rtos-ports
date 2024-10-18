#!/usr/bin/env bash

# TODO: Incremental build

set -e

LSB_VSX_VER="2.0-1"
LSB_VSX="lsb_vsx-$LSB_VSX_VER"

PREFIX_LSB_VSX="${PREFIX_PROJECT}/phoenix-rtos-ports/lsb_vsx"
PREFIX_LSB_VSX_BUILD="${PREFIX_BUILD}/lsb_vsx"
PREFIX_LSB_VSX_MARKERS="${PREFIX_LSB_VSX_BUILD}/markers"
PREFIX_LSB_VSX_FILES="${PREFIX_LSB_VSX_BUILD}/files"

apply_patches() {
	local patchfile
  
	for patchfile in "${PREFIX_LSB_VSX}/patches/${1}/"*.patch; do
		patch_basename="$(basename "$patchfile")"
		patch_dirname="$(basename $(dirname "$patchfile"))"
	if [ ! -f "${PREFIX_LSB_VSX_MARKERS}/${patch_dirname}/${patch_basename}.applied" ]; then
		echo "applying patch: $patchfile"
		patch -d "${PREFIX_LSB_VSX_BUILD}/files" -p1 < "$patchfile"
		touch "${PREFIX_LSB_VSX_MARKERS}/${patch_dirname}/${patch_basename}.applied"
	fi
	done
}

b_log "Building lsb-vsx testsuite"

mkdir -p "$PREFIX_LSB_VSX_BUILD"
mkdir -p "$PREFIX_LSB_VSX_MARKERS"
mkdir -p "${PREFIX_LSB_VSX_MARKERS}/host_TETware"
mkdir -p "${PREFIX_LSB_VSX_MARKERS}/host_VSX"
mkdir -p "${PREFIX_LSB_VSX_MARKERS}/ps_TETware"
mkdir -p "${PREFIX_LSB_VSX_MARKERS}/ps_VSX"
mkdir -p "$PREFIX_LSB_VSX_FILES"
mkdir -p "${PREFIX_LSB_VSX_BUILD}/host_bin"
mkdir -p "${PREFIX_PROG_STRIPPED}/lsb_vsx"

#
# # Download and extract packages
#

[ -f "${PREFIX_LSB_VSX}/packages/tet_vsxgen_3.02.tgz" ] || \
wget http://www.opengroup.org/infosrv/lsb/ogdeliverables/LSB-VSX2.0-1/tet_vsxgen_3.02.tgz -P "${PREFIX_LSB_VSX}/packages"

[ -f "${PREFIX_LSB_VSX}/packages/lts_vsx-pcts2.0beta.tgz" ] || \
wget http://www.opengroup.org/infosrv/lsb/ogdeliverables/LSB-VSX2.0-1/lts_vsx-pcts2.0beta.tgz -P "${PREFIX_LSB_VSX}/packages"

if [ ! -d "${PREFIX_LSB_VSX_FILES}/src" ]; then
	tar xzf "${PREFIX_LSB_VSX}/packages/tet_vsxgen_3.02.tgz" -C "$PREFIX_LSB_VSX_FILES"
	tar xzf "${PREFIX_LSB_VSX}/packages/lts_vsx-pcts2.0beta.tgz" -C "${PREFIX_LSB_VSX_FILES}/test_sets"
fi

#
# # Compile TETware-Lite for host
#

TET_ROOT="$PREFIX_LSB_VSX_FILES"
PATH="${TET_ROOT}/bin:$PATH"
export TET_ROOT PATH

apply_patches "host_TETware"
echo -e "\n--- Compiling TETware-Lite for host ---\n"
cd "$TET_ROOT" && sh configure -t lite > /dev/null
cd "${TET_ROOT}/src" && make && make install
cp -p "${TET_ROOT}/bin/tcc" "${PREFIX_LSB_VSX_BUILD}/host_bin/tcc"

#
# # Build VSX test framework for host (vbuild only needed)
#

HOME="${TET_ROOT}/test_sets"
export HOME PREFIX_LSB_VSX

apply_patches "host_VSX"
cd "${TET_ROOT}/test_sets"
sh setup_testsets.sh
cp -p "${HOME}/BIN/vbuild" "${PREFIX_LSB_VSX_BUILD}/host_bin/vbuild"

#
# # Clean host build
#

rm -rf "${PREFIX_LSB_VSX_FILES:?}/"*
tar xzf "${PREFIX_LSB_VSX}/packages/tet_vsxgen_3.02.tgz" -C "$PREFIX_LSB_VSX_FILES"
tar xzf "${PREFIX_LSB_VSX}/packages/lts_vsx-pcts2.0beta.tgz" -C "${PREFIX_LSB_VSX_FILES}/test_sets"

#
# # Configure src/defines.mk (used by TETware)
#

COPTS=$(echo "$CFLAGS" | sed 's/-I[^ ]* //g')

sed -e "s|^CC =|CC = ${CC}|" \
    -e "s|^LD_R =|LD_R = ${LD} -r|" \
    -e "s|^LDFLAGS =|LDFLAGS = ${LDFLAGS}|" \
    -e "s|^AR =|AR = ${AR}|" \
    -e "s|^CDEFS =|CDEFS = -I${PREFIX_PROJECT}/_build/${TARGET}/sysroot/usr/include|" \
    -e "s|^COPTS =|COPTS = ${COPTS}|" \
    "${PREFIX_LSB_VSX}/config/ps_defines.mk" > "${PREFIX_LSB_VSX_FILES}/src/defines.mk"

#
# # Compile TETware-Lite for Phoenix-RTOS
#

TET_EXECUTE="${TET_ROOT}/test_sets/TESTROOT"
PATH="${TET_ROOT}/test_sets/BIN:${TET_EXECUTE}/BIN:$PATH"
HOME="${TET_ROOT}/test_sets"
export TET_EXECUTE PATH HOME

apply_patches "ps_TETware"
echo -e "\n--- Compiling TETware-Lite for Phoenix-RTOS ---\n"
cd "${TET_ROOT}/src"
sh tetconfig -t lite
make; make install
"$STRIP" -o "${PREFIX_PROG_STRIPPED}/tcc" "${TET_ROOT}/bin/tcc"
b_install "${PREFIX_PROG_STRIPPED}/tcc" "/usr/bin"

#
# # Configure ps_vsxparams file
#

VSXDIR="${HOME}/SRC"
TET_EXECUTE="${HOME}/TESTROOT"

sed -e "s|^CC=|CC=\"${CC}\"|" \
    -e "s|^LDFLAGS=|LDFLAGS=\"${LDFLAGS}\"|" \
    -e "s|^AR=|AR=\"${AR} cr\"|" \
    -e "s|^RANLIB=|RANLIB=\"${CROSS}ranlib\"|" \
    -e "s|^INCDIRS=|INCDIRS=\"${PREFIX_PROJECT}/_build/${TARGET}/sysroot/usr/include\"|" \
    -e "s|^VSXDIR=|VSXDIR=\"${VSXDIR}\"|" \
    -e "s|^TET_EXECUTE=|TET_EXECUTE=\"${TET_EXECUTE}\"|" \
    "${PREFIX_LSB_VSX}/config/ps_vsxparams.skel" > "${PREFIX_LSB_VSX}/config/ps_vsxparams"

#
# # Build VSX test framework
#

apply_patches "ps_VSX"
cd "${TET_ROOT}/test_sets"
sh setup_testsets.sh

#
# # Build tests
#

PATH="${PREFIX_LSB_VSX_BUILD}/host_bin:$PATH"

echo -e "\n--- Building tests ---\n"
sed -e "s|^PATH=|PATH=\"${PATH}\"|" -i "${HOME}/tetbuild.cfg"
"${PREFIX_LSB_VSX_BUILD}/host_bin/tcc" -p -b -s "${PREFIX_LSB_VSX}/config/scen.bld"

#
# # Strip and copy to rootfs
#

find "$HOME" -type f -executable -name "T.*" -print0 | while IFS= read -r -d '' test_path; do
	testroot_path="${test_path##*test_sets/}"
	mkdir -p "$(dirname "${PREFIX_ROOTFS}/root/$testroot_path")"

	if ! file "$test_path" | grep -q "ASCII text"; then
		mkdir -p "$(dirname "${PREFIX_PROG_STRIPPED}lsb_vsx/$testroot_path")"
		"$STRIP" -o "${PREFIX_PROG_STRIPPED}lsb_vsx/$testroot_path" "$test_path"
		cp -p "${PREFIX_PROG_STRIPPED}lsb_vsx/$testroot_path" "${PREFIX_ROOTFS}/root/$testroot_path"
	else
		cp -p "$test_path" "${PREFIX_ROOTFS}/root/$testroot_path"
	fi
done
