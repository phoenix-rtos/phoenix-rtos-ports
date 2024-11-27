#!/usr/bin/env bash

set -e

LSB_VSX_VER="2.0-1"
LSB_VSX="lsb_vsx-$LSB_VSX_VER"
PKG_URL1="http://www.opengroup.org/infosrv/lsb/ogdeliverables/LSB-VSX${LSB_VSX_VER}/tet_vsxgen_3.02.tgz"
PKG_URL2="http://www.opengroup.org/infosrv/lsb/ogdeliverables/LSB-VSX${LSB_VSX_VER}/lts_vsx-pcts2.0beta.tgz"
PKG_MIRROR_URL1="https://files.phoesys.com/ports/${LSB_VSX}/tet_vsxgen_3.02.tgz"
PKG_MIRROR_URL2="https://files.phoesys.com/ports/${LSB_VSX}/lts_vsx-pcts2.0beta.tgz"

PREFIX_LSB_VSX_MARKERS="${PREFIX_PORT_BUILD}/markers"
PREFIX_LSB_VSX_FILES="${PREFIX_PORT_BUILD}/files"

apply_patches() {
	local patchfile
  
	for patchfile in "${PREFIX_PORT}/patches/${1}/"*.patch; do
		patch_basename="$(basename "$patchfile")"
		patch_dirname="$(basename "$(dirname "$patchfile")")"

		if [ ! -f "${PREFIX_LSB_VSX_MARKERS}/${patch_dirname}/${patch_basename}.applied" ]; then
			echo "applying patch: $patchfile"
			patch -d "${PREFIX_PORT_BUILD}/files" -p1 < "$patchfile"
			touch "${PREFIX_LSB_VSX_MARKERS}/${patch_dirname}/${patch_basename}.applied"
		fi
	done
}

check_patches() {
	local patchfile
	local VAR_NAME

	for patchfile in "${PREFIX_PORT}/patches/${1}/"*.patch; do
		patch_basename="$(basename "$patchfile")"
		patch_dirname="$(basename "$(dirname "$patchfile")")"

		if [ ! -f "${PREFIX_LSB_VSX_MARKERS}/${patch_dirname}/${patch_dirname}.built" ]; then
			break
		fi

		if [ "$1" = "host_TETware" ] || [ "$1" = "host_VSX" ]; then
			VAR_NAME="HOST_NEW_PATCH"
		elif [ "$1" = "ps_TETware" ] || [ "$1" = "ps_VSX" ]; then
			VAR_NAME="PS_NEW_PATCH"
		fi

		if [ ! -f "${PREFIX_LSB_VSX_MARKERS}/${patch_dirname}/${patch_basename}.applied" ] || \
		   [ "$patchfile" -nt "${PREFIX_LSB_VSX_MARKERS}/${patch_dirname}/${patch_dirname}.built" ];
		then
			declare "${VAR_NAME}=y"
			break
		fi
	done
}

check_tests() {
	while IFS= read -r -d '' stamp; do
		if [ "$stamp" -nt "${PREFIX_LSB_VSX_MARKERS}/tests.built" ]; then
			return 0
		fi
	done < <(find "$PREFIX_LSB_VSX_MARKERS" -type f -name "*.built" -print0)
	return 1
}

check_build_script() {
	while IFS= read -r -d '' stamp; do
		if [ "$0" -nt "$stamp" ]; then
			return 0
		fi
	done < <(find "$PREFIX_LSB_VSX_MARKERS" -type f -name "*.built" -print0)
	return 1
}

prepare_new_build() {
	rm -rf "${PREFIX_LSB_VSX_FILES:?}/"*
	tar xzf "${PREFIX_PORT}/packages/tet_vsxgen_3.02.tgz" -C "$PREFIX_LSB_VSX_FILES"
	tar xzf "${PREFIX_PORT}/packages/lts_vsx-pcts2.0beta.tgz" -C "${PREFIX_LSB_VSX_FILES}/test_sets"
}

mkdir -p "$PREFIX_LSB_VSX_MARKERS"
mkdir -p "${PREFIX_LSB_VSX_MARKERS}/host_TETware"
mkdir -p "${PREFIX_LSB_VSX_MARKERS}/host_VSX"
mkdir -p "${PREFIX_LSB_VSX_MARKERS}/ps_TETware"
mkdir -p "${PREFIX_LSB_VSX_MARKERS}/ps_VSX"
mkdir -p "$PREFIX_LSB_VSX_FILES"
mkdir -p "${PREFIX_PORT_BUILD}/host_bin"
mkdir -p "${PREFIX_PORT_BUILD}/host_config"
mkdir -p "${PREFIX_PORT_BUILD}/ps_config"
mkdir -p "${PREFIX_PROG_STRIPPED}/lsb_vsx"

#
# # Download and extract packages
#

[ -f "${PREFIX_PORT}/packages/tet_vsxgen_3.02.tgz" ] || \
wget "$PKG_URL1" -P "${PREFIX_PORT}/packages" || wget "$PKG_MIRROR_URL1" -P "${PREFIX_PORT}/packages"

[ -f "${PREFIX_PORT}/packages/lts_vsx-pcts2.0beta.tgz" ] || \
wget "$PKG_URL2" -P "${PREFIX_PORT}/packages" || wget "$PKG_MIRROR_URL2" -P "${PREFIX_PORT}/packages"

if [ ! -d "${PREFIX_LSB_VSX_FILES}/src" ]; then
	tar xzf "${PREFIX_PORT}/packages/tet_vsxgen_3.02.tgz" -C "$PREFIX_LSB_VSX_FILES"
	tar xzf "${PREFIX_PORT}/packages/lts_vsx-pcts2.0beta.tgz" -C "${PREFIX_LSB_VSX_FILES}/test_sets"
fi

TET_ROOT="$PREFIX_LSB_VSX_FILES"
HOME="${TET_ROOT}/test_sets"
TET_EXECUTE="${HOME}/TESTROOT"
HOST_NEW_PATCH="n"
PS_NEW_PATCH="n"

#
# # Check if there are new patches or build.sh has changed since last build
#

if check_build_script; then
	find "$PREFIX_LSB_VSX_MARKERS" -type f -delete
	prepare_new_build
else
	check_patches "host_TETware"
	check_patches "host_VSX"
	check_patches "ps_TETware"
	check_patches "ps_VSX"
fi

#
# # New host patches - prepare new build
#

if [ "$HOST_NEW_PATCH" = "y" ]; then
	find "$PREFIX_LSB_VSX_MARKERS" -type f -delete
	prepare_new_build
fi

#
# # Compile TETware-Lite for host
#

if [ ! -f "${PREFIX_LSB_VSX_MARKERS}/host_TETware/host_TETware.built" ]; then
	PATH="${TET_ROOT}/bin:$PATH"
	export TET_ROOT PATH

	apply_patches "host_TETware"
	echo -e "\n--- Compiling TETware-Lite for host ---\n"
	cd "$TET_ROOT" && sh configure -t lite > /dev/null
	cd "${TET_ROOT}/src" && make && make install
	cp -p "${TET_ROOT}/bin/tcc" "${PREFIX_PORT_BUILD}/host_bin/tcc"
	touch "${PREFIX_LSB_VSX_MARKERS}/host_TETware/host_TETware.built"
fi

#
# # Build VSX test framework for host (vbuild only needed)
#

if [ ! -f "${PREFIX_LSB_VSX_MARKERS}/host_VSX/host_VSX.built" ]; then
	export HOME

	apply_patches "host_VSX"
	cd "${TET_ROOT}/test_sets"
	sh setup_testsets.sh
	cp -p "${HOME}/BIN/vbuild" "${PREFIX_PORT_BUILD}/host_bin/vbuild"
	cp -p "${HOME}/tetbuild.cfg" "${PREFIX_PORT_BUILD}/host_config/tetbuild.cfg"

#
# # Clean whole host build
#

	prepare_new_build
	touch "${PREFIX_LSB_VSX_MARKERS}/host_VSX/host_VSX.built"
fi

#
# # New phoenix patches - prepare new build
#

if [ "$PS_NEW_PATCH" = "y" ]; then
	rm -f "${PREFIX_LSB_VSX_MARKERS}/tests.built"
	rm -f "${PREFIX_LSB_VSX_MARKERS}/ps_TETware/"*
	rm -f "${PREFIX_LSB_VSX_MARKERS}/ps_VSX/"*
	prepare_new_build
fi

#
# # Configure src/defines.mk (used by TETware)
#

COPTS="$(echo "$CFLAGS" | sed 's/-I[^ ]* //g')"

sed -e "s|^CC =.*$|CC = ${CC}|" \
    -e "s|^LD_R =.*$|LD_R = ${LD} -r|" \
    -e "s|^LDFLAGS =.*$|LDFLAGS = ${CFLAGS} ${LDFLAGS}|" \
    -e "s|^AR =.*$|AR = ${AR}|" \
    -e "s|^CDEFS =\(.*\)$|CDEFS =\1 -I${PREFIX_PROJECT}/_build/${TARGET}/sysroot/usr/include|" \
    -e "s|^COPTS =.*$|COPTS = ${COPTS}|" \
    "${PREFIX_PORT}/config/ps_defines.mk" > "${PREFIX_LSB_VSX_FILES}/src/defines.mk"

#
# # Compile TETware-Lite for Phoenix-RTOS
#

if [ ! -f "${PREFIX_LSB_VSX_MARKERS}/ps_TETware/ps_TETware.built" ]; then
	PATH="${TET_ROOT}/test_sets/BIN:${TET_EXECUTE}/BIN:$PATH"
	export TET_ROOT TET_EXECUTE PATH HOME

	apply_patches "ps_TETware"
	echo -e "\n--- Compiling TETware-Lite for Phoenix-RTOS ---\n"
	cd "${TET_ROOT}/src"
	sh tetconfig -t lite
	make; make install
	"$STRIP" -o "${PREFIX_PROG_STRIPPED}/tcc" "${TET_ROOT}/bin/tcc"
	b_install "${PREFIX_PROG_STRIPPED}/tcc" "/usr/bin"
	touch "${PREFIX_LSB_VSX_MARKERS}/ps_TETware/ps_TETware.built"
fi

#
# # Configure ps_vsxparams file
#

VSXDIR="${HOME}/SRC"

sed -e "s|^CC=.*$|CC=\"${CC}\"|" \
    -e "s|^LDFLAGS=.*$|LDFLAGS=\"${CFLAGS} ${LDFLAGS}\"|" \
    -e "s|^AR=.*$|AR=\"${AR} cr\"|" \
    -e "s|^RANLIB=.*$|RANLIB=\"${CROSS}ranlib\"|" \
    -e "s|^INCDIRS=.*$|INCDIRS=\"${PREFIX_PROJECT}/_build/${TARGET}/sysroot/usr/include\"|" \
    -e "s|^VSXDIR=.*$|VSXDIR=\"${VSXDIR}\"|" \
    -e "s|^TET_EXECUTE=.*$|TET_EXECUTE=\"${TET_EXECUTE}\"|" \
    "${PREFIX_PORT}/config/ps_vsxparams.skel" > "${PREFIX_PORT_BUILD}/ps_config/ps_vsxparams"

#
# # Build VSX test framework
#

if [ ! -f "${PREFIX_LSB_VSX_MARKERS}/ps_VSX/ps_VSX.built" ]; then
	apply_patches "ps_VSX"
	cd "${TET_ROOT}/test_sets"
	sh setup_testsets.sh
	touch "${PREFIX_LSB_VSX_MARKERS}/ps_VSX/ps_VSX.built"
fi

#
# # Build tests
#

if [ "$LONG_TEST" = "y" ] && { [ "$HOST_NEW_PATCH" = "y" ] || [ "$PS_NEW_PATCH" = "y" ] || \
   [ ! -f "${PREFIX_LSB_VSX_MARKERS}/tests.built" ] || check_tests; };
then
	PATH="${PREFIX_PORT_BUILD}/host_bin:$PATH"
	export TET_ROOT TET_EXECUTE

	echo -e "\n--- Building tests ---\n"
	sed -e "s|^PATH=.*$|PATH=${PATH}|" \
	    -e "s|^VSXDIR=.*$|VSXDIR=${TET_ROOT}/test_sets/SRC|" \
	    "${PREFIX_PORT_BUILD}/host_config/tetbuild.cfg" > "${HOME}/tetbuild.cfg"
	cd "$HOME" && "${PREFIX_PORT_BUILD}/host_bin/tcc" -p -b -s "${PREFIX_PORT}/config/scen.bld"

#
# # Strip and copy to rootfs
#

	find "$HOME" -type f -executable -name "T.*" -print0 | while IFS= read -r -d '' test_path; do
		PREFIX_TESTROOT="${PREFIX_ROOTFS}/root/lsb_vsx/test_sets/TESTROOT"
		testroot_path="tset${test_path#*tset}"
		dir="$(dirname "$test_path")"
		mkdir -p "$(dirname "${PREFIX_TESTROOT}/$testroot_path")"

		if ! file "$test_path" | grep -q "ASCII text"; then
			mkdir -p "$(dirname "${PREFIX_PROG_STRIPPED}/lsb_vsx/$testroot_path")"
			"$STRIP" "$test_path" -o "${PREFIX_PROG_STRIPPED}/lsb_vsx/$testroot_path"
			cp -p "$_" "${PREFIX_TESTROOT}/$testroot_path"
		else
			cp -p "$test_path" "${PREFIX_TESTROOT}/$testroot_path"
		fi

		# Some tests also use subprocesses
		export PREFIX_TESTROOT
		find "$dir" -type f -executable ! -name "T.*" -print0 | while IFS= read -r -d '' subproc_path; do
			if [ -n "$subproc_path" ]; then
				testroot_path="tset${subproc_path#*tset}"
				if ! file "$subproc_path" | grep -q "shell script"; then
					"$STRIP" "$subproc_path" -o "${PREFIX_PROG_STRIPPED}/lsb_vsx/$testroot_path"
					cp -p "$_" "${PREFIX_TESTROOT}/$testroot_path"
				else
					cp -p "$subproc_path" "${PREFIX_TESTROOT}/$testroot_path"
				fi
			fi
		done
	done

#
# # Copy exec parameter file
#

	cp -p "${PREFIX_PORT}/config/ps_tetexec.cfg" "${PREFIX_ROOTFS}/root/lsb_vsx/test_sets/tetexec.cfg"
	touch "${PREFIX_LSB_VSX_MARKERS}/tests.built"
fi
