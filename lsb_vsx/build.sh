#!/bin/bash

LSB_VSX_VER="2.0-1"
LSB_VSX="lsb_vsx-${LSB_VSX_VER}"

PREFIX_LSB_VSX="${PREFIX_PROJECT}/phoenix-rtos-ports/lsb_vsx"
PREFIX_LSB_VSX_BUILD="${PREFIX_BUILD}/lsb_vsx"
PREFIX_LSB_VSX_CONFIG="${PREFIX_LSB_VSX}/${LSB_VSX}-config"
PREFIX_LSB_VSX_MARKERS="$PREFIX_LSB_VSX_BUILD/markers"
PREFIX_LSB_VSX_FILES="${PREFIX_LSB_VSX_BUILD}/files"
PREFIX_LSB_VSX_TMP="$PREFIX_LSB_VSX_BUILD/tmp"

b_log "Building lsb-vsx (posix test suite)"

#
# Download and unpack
#
mkdir -p "$PREFIX_LSB_VSX_MARKERS"
mkdir -p "$PREFIX_LSB_VSX_FILES"
mkdir -p "$PREFIX_LSB_VSX_TMP"
mkdir -p "$PREFIX_LSB_VSX_TMP"/tetbin_host
mkdir -p "$PREFIX_LSB_VSX_TMP"/tetbin_phoenix
mkdir -p "$PREFIX_LSB_VSX_TMP"/BIN_host
mkdir -p "$PREFIX_LSB_VSX_TMP"/BIN_phoenix

[ -f "$PREFIX_LSB_VSX/tet_vsxgen_3.02.tgz" ] || wget http://www.opengroup.org/infosrv/lsb/ogdeliverables/LSB-VSX2.0-1/tet_vsxgen_3.02.tgz -P "$PREFIX_LSB_VSX"
[ -f "$PREFIX_LSB_VSX/lts_vsx-pcts2.0beta2.tgz" ] || wget http://www.opengroup.org/infosrv/lsb/ogdeliverables/LSB-VSX2.0-1/lts_vsx-pcts2.0beta2.tgz -P "$PREFIX_LSB_VSX"
[ -f "$PREFIX_LSB_VSX/lts_vsx-pcts2.0beta.tgz" ] || wget http://www.opengroup.org/infosrv/lsb/ogdeliverables/LSB-VSX2.0-1/lts_vsx-pcts2.0beta.tgz -P "$PREFIX_LSB_VSX"

#
# # Store compiler name for later use
#
CC_BUF=$CC
export CC_BUF
export PREFIX_LSB_VSX

TET_ROOT=${PREFIX_LSB_VSX_BUILD}/files
export TET_ROOT

#
# # Install files
#
if [ ! -d "$PREFIX_LSB_VSX_FILES"/src ]; then
	# Find out where to install the test suite
	if [ ! -d "${TET_ROOT}" ]; then
	mkdir "${TET_ROOT}"
	if [ ! -d "$TET_ROOT" ]; then
		echo "Unable to create installation directory: ${TET_ROOT}"
		exit 1
	fi
	fi

	tet_package=${PREFIX_LSB_VSX}/tet_vsxgen_3.02.tgz
	echo "Installing the TET and VSXgen test harness"
	if [ ! -f "$tet_package" ]; then
	echo "Could not find file \"$tet_package\""
	echo Aborting
	exit 1
	fi

	(cd "$TET_ROOT" && tar xfz "$tet_package")
	if [ $? -ne 0 ]; then
	echo "Unable to unpack TET/VSXgen"
	exit 1
	fi

	# Install the test suites
	cd "${PREFIX_LSB_VSX}" || exit
	test_suites=$(echo lts_*.tgz | sed -e s/\ +//)
	echo installing test_suites: "$test_suites"

	current_dir=$PWD;
	for test_suite in $test_suites; do
	echo "Installing $test_suite"
	(cd "$TET_ROOT"/test_sets && tar xfz "$current_dir"/"$test_suite")
	if [ $? -ne 0 ]; then
		echo "Unable to install test suite: $test_suite"
	fi
	done;

	# Configure setup script and profiles
	sed -e "s@^echo Unconfigured@TET_ROOT=$TET_ROOT@" "$TET_ROOT"/setup.sh.skeleton \
	> "$TET_ROOT"/setup.sh && rm "$TET_ROOT"/setup.sh.skeleton
	sed -e "s@^echo Unconfigured@TET_ROOT=$TET_ROOT@" "$TET_ROOT"/profile.skeleton \
	> "$TET_ROOT"/profile && rm "$TET_ROOT"/profile.skeleton
	sed -e "s@^echo Unconfigured@TET_ROOT=$TET_ROOT@" "$TET_ROOT"/test_sets/profile.skeleton  > "$TET_ROOT"/test_sets/profile && rm "$TET_ROOT"/test_sets/profile.skeleton
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
	export INCDIRS
	export CC
	chmod 755 "$PREFIX_LSB_VSX_FILES"/setup.sh
	(cd "$PREFIX_LSB_VSX_BUILD"/files && PLATFORM=HOST ./setup.sh)
	#
	# # Copy needed executables for later use
	#
	(cd "$PREFIX_LSB_VSX_FILES" && cp bin/* "$PREFIX_LSB_VSX_TMP"/tetbin_host)
	(cd "$PREFIX_LSB_VSX_FILES" && cp test_sets/BIN/* "$PREFIX_LSB_VSX_TMP"/BIN_host)

	touch "$PREFIX_LSB_VSX_MARKERS/host_step.stamp-files-prepared"

	(cd "$PREFIX_LSB_VSX_FILES/src" && make clean)
fi

#
# # Build all under phoenix
#
rm -f "$PREFIX_LSB_VSX_FILES"/test_sets/SRC/SYSINC/*
rm "$PREFIX_LSB_VSX_FILES"/test_sets/SRC/SYSINC/sys/*
rm "$PREFIX_LSB_VSX_FILES"/test_sets/SRC/SYSINC/rpc/*
INCDIRS="$PREFIX_PROJECT/libphoenix/include"
CC=$CC_BUF
export LD
export INCDIRS
export CC
(cd "$PREFIX_LSB_VSX_BUILD"/files && PLATFORM=PHOENIX-RTOS ./setup.sh)

#
# # Copy all to phoenix file system
#
mkdir -p "$PREFIX_ROOTFS/usr/test/lsb_vsx_posix"
cp -a "$PREFIX_LSB_VSX_FILES" "$PREFIX_ROOTFS/usr/test/lsb_vsx_posix"

