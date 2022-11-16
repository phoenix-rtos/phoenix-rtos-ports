#!/bin/bash

set -e

LSB_VSX_VER="2.0-1"
LSB_VSX="lsb_vsx-${LSB_VSX_VER}"

PREFIX_LSB_VSX="${PREFIX_PROJECT}/phoenix-rtos-ports/lsb_vsx"
PREFIX_TET_PACKAGE="${PREFIX_LSB_VSX}/tet_vsxgen_3.02.tgz"
PREFIX_LSB_VSX_BUILD="${PREFIX_BUILD}/lsb_vsx"
PREFIX_LSB_VSX_CONFIG="${PREFIX_LSB_VSX}/${LSB_VSX}-config"
PREFIX_LSB_VSX_MARKERS="${PREFIX_LSB_VSX_BUILD}/markers"
PREFIX_LSB_VSX_FILES="${PREFIX_LSB_VSX_BUILD}/files"
PREFIX_LSB_VSX_TMP="${PREFIX_LSB_VSX_BUILD}/tmp"
PREFIX_ROOTFS_LSB_VSX="${PREFIX_ROOTFS}/usr/test/lsb_vsx_posix/"

b_log "Building lsb-vsx (posix test suite)"

#
# Download and unpack
#
mkdir -p "${PREFIX_LSB_VSX_MARKERS}"
mkdir -p "${PREFIX_LSB_VSX_FILES}"
mkdir -p "${PREFIX_LSB_VSX_TMP}"/tetbin_host
mkdir -p "${PREFIX_LSB_VSX_TMP}"/tetbin_phoenix
mkdir -p "${PREFIX_LSB_VSX_TMP}"/BIN_host
mkdir -p "${PREFIX_LSB_VSX_TMP}"/BIN_phoenix

[ -f "${PREFIX_TET_PACKAGE}" ] || wget http://www.opengroup.org/infosrv/lsb/ogdeliverables/LSB-VSX2.0-1/tet_vsxgen_3.02.tgz -P "${PREFIX_LSB_VSX}"
[ -f "${PREFIX_LSB_VSX}/lts_vsx-pcts2.0beta2.tgz" ] || wget http://www.opengroup.org/infosrv/lsb/ogdeliverables/LSB-VSX2.0-1/lts_vsx-pcts2.0beta2.tgz -P "${PREFIX_LSB_VSX}"
[ -f "${PREFIX_LSB_VSX}/lts_vsx-pcts2.0beta.tgz" ] || wget http://www.opengroup.org/infosrv/lsb/ogdeliverables/LSB-VSX2.0-1/lts_vsx-pcts2.0beta.tgz -P "${PREFIX_LSB_VSX}"

#
# # Store compiler/linker name for later use
#
CC_BUF="${CC}"
LD_BUF="${LD}"
export CC_BUF
export PREFIX_LSB_VSX

TET_ROOT="${PREFIX_LSB_VSX_BUILD}/files"
export TET_ROOT

#
# # Unpack files
#
if [ ! -d "${PREFIX_LSB_VSX_FILES}"/src ]; then
	mkdir -p "${TET_ROOT}"

	echo "---Unpacking the TET and VSXgen test harness---"
	tar xfz "${PREFIX_TET_PACKAGE}" -C "${TET_ROOT}"

	for test_suite_path in "${PREFIX_LSB_VSX}/"lts_*.tgz; do
		test_suite=$(basename "$test_suite_path")
		echo Unpacking "$test_suite"
		tar xfz "${PREFIX_LSB_VSX}/${test_suite}" -C "${TET_ROOT}/test_sets"
	done;

	# Configure setup script and profiles
	sed "s|echo Unconfigured|TET_ROOT=$TET_ROOT|" "$TET_ROOT"/setup.sh.skeleton \
	> "$TET_ROOT"/setup.sh && rm "$TET_ROOT"/setup.sh.skeleton
	sed "s|echo Unconfigured|TET_ROOT=$TET_ROOT|" "$TET_ROOT"/profile.skeleton \
	> "$TET_ROOT"/profile && rm "$TET_ROOT"/profile.skeleton
	sed "s|echo Unconfigured|TET_ROOT=$TET_ROOT|" "$TET_ROOT"/test_sets/profile.skeleton  > "$TET_ROOT"/test_sets/profile && rm "$TET_ROOT"/test_sets/profile.skeleton
fi

#
# # Apply patches
#
for patchfile in "$PREFIX_LSB_VSX_CONFIG"/patches/*.patch; do
 	if [ ! -f "$PREFIX_LSB_VSX_MARKERS/$(basename "$patchfile").applied" ]; then
 		echo "applying patch: $patchfile"
 		patch -d "$PREFIX_LSB_VSX_BUILD"/files -p1 < "$patchfile"
 		touch "$PREFIX_LSB_VSX_MARKERS/$(basename "$patchfile").applied"
 	fi
done

#
# # Build host executables needed to build tests
#
if [ ! -f "$PREFIX_LSB_VSX_MARKERS/host_step.stamp-files-prepared" ]; then
	INCDIRS="/usr/include /usr/include/x86_64-linux-gnu"
	CC=gcc
	LD=ld

	export INCDIRS
	export CC
	export LD

	echo "---Preparing host tcc exectutables to build tests in the next step---"
	chmod 755 "$PREFIX_LSB_VSX_FILES"/setup.sh
	(cd "$PREFIX_LSB_VSX_BUILD"/files && PLATFORM=HOST ./setup.sh)

	#
	# # Copy needed executables for later use
	#
	(cd "$PREFIX_LSB_VSX_FILES" && cp bin/* "$PREFIX_LSB_VSX_TMP"/tetbin_host)
	(cd "$PREFIX_LSB_VSX_FILES" && cp test_sets/BIN/* "$PREFIX_LSB_VSX_TMP"/BIN_host)

	(cd "$PREFIX_LSB_VSX_FILES/src" && make clean)
	# we want to avoid using host files when compiling under phoenix, so the SYSINC is cleared
	rm -rf "$PREFIX_LSB_VSX_FILES"/test_sets/SRC/SYSINC/*
	(cd "$PREFIX_LSB_VSX_FILES/test_sets/SRC/SYSINC/" && mkdir sys rpc)

	touch "$PREFIX_LSB_VSX_MARKERS/host_step.stamp-files-prepared"
fi

#
# # Build all under phoenix
#
INCDIRS="$PREFIX_PROJECT/libphoenix/include"
CC="${CC_BUF}"
LD="${LD_BUF}"
# we are using scenario file (scen.bld), where is the list containing all tests for build
export PREFIX_LSB_VSX_CONFIG
export CC
export LD
export INCDIRS

echo "---Preparing Phoenix-RTOS tcc and tests to run after starting the system---"
(cd "${PREFIX_LSB_VSX_BUILD}"/files && PLATFORM=PHOENIX-RTOS ./setup.sh)

#
# # Copy files required for running tests to Phoenix-RTOS rootfs
#
mkdir -p "${PREFIX_ROOTFS_LSB_VSX}/test_sets"

# we use --force, because, when building recursively in _fs may be write protected files
cp -af "${PREFIX_LSB_VSX_FILES}/bin" "${PREFIX_ROOTFS_LSB_VSX}"
(cd "${PREFIX_LSB_VSX_FILES}/test_sets" && cp -af "TESTROOT" "scen.exec" "tetclean.cfg" "${PREFIX_ROOTFS_LSB_VSX}/test_sets")
