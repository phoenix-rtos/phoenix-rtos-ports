#!/bin/bash

LSB_VSX_VER="2.0-1"
LSB_VSX="lsb_vsx-${LSB_VSX_VER}"

PREFIX_LSB_VSX="${PREFIX_PROJECT}/phoenix-rtos-ports/lsb_vsx"
PREFIX_LSB_VSX_BUILD="${PREFIX_BUILD}/lsb_vsx"
PREFIX_LSB_VSX_CONFIG="${PREFIX_LSB_VSX}/${LSB_VSX}-config/"
PREFIX_LSB_VSX_MARKERS="$PREFIX_LSB_VSX_BUILD/markers/"
PREFIX_LSB_VSX_FILES="$PREFIX_LSB_VSX_BUILD/files"
PREFIX_LSB_VSX_TMP="$PREFIX_LSB_VSX_BUILD/tmp"

b_log "Building lsb-vsx (posix tests suite)"

if [ -d "$PREFIX_LSB_VSX_FILES" ]; then
	b_log "Lsb-vsx (posix tests suite) has been built already"
	exit 0
fi

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
[ -f "$PREFIX_LSB_VSX_BUILD/install.sh" ] || wget http://www.opengroup.org/infosrv/lsb/ogdeliverables/LSB-VSX2.0-1/install.sh -P "$PREFIX_LSB_VSX_BUILD"

#
# # Store compiler name for later use
#
CC_BUF=$CC
export CC_BUF
#
# # Apply patches to install script
#
patchfile="$PREFIX_LSB_VSX_CONFIG"patches/01_install.patch
if [ ! -f "$PREFIX_LSB_VSX_MARKERS/01_install.patch.applied" ]; then
		echo "applying patch: $patchfile"
        patch "$PREFIX_LSB_VSX_BUILD/install.sh" < "$patchfile" 
		touch "$PREFIX_LSB_VSX_MARKERS/01_install.patch.applied"
fi

# shellcheck search install.sh in current
# directory not in PREFIX_LSB_VSX_BUILD therefore
# emits warnning which we disable
# shellcheck disable=SC1000-SC9999
(cd "$PREFIX_LSB_VSX_BUILD" && . ./install.sh)

#
# # Apply host patches
#
for patchfile in "$PREFIX_LSB_VSX_CONFIG"patches/*host*.patch; do
 	if [ ! -f "$PREFIX_LSB_VSX_MARKERS/$(basename "$patchfile").applied" ]; then
 		echo "applying patch: $patchfile"
 		patch -d "$PREFIX_LSB_VSX_BUILD"/files -p1 < "$patchfile" 
 		touch "$PREFIX_LSB_VSX_MARKERS/$(basename "$patchfile").applied"
 	fi
done

#
# # Build host executables needed to build tests
#
# shellcheck disable=SC1000-SC9999
(cd "$PREFIX_LSB_VSX_BUILD"/files && . ./setup.sh)
#
# # Copy needed executables for later use
#
(cd "$PREFIX_LSB_VSX_FILES" && cp bin/* "$PREFIX_LSB_VSX_TMP"/tetbin_host)
(cd "$PREFIX_LSB_VSX_FILES" && cp test_sets/BIN/* "$PREFIX_LSB_VSX_TMP"/BIN_host)
#
# #Clear all files
#
rm -rf "${PREFIX_LSB_VSX_FILES:?}"/*
#
# # Install all once again for build under phoenix
#
# shellcheck disable=SC1000-SC9999
(cd "$PREFIX_LSB_VSX_BUILD" && . ./install.sh)

#
# # Apply patches to build everything under phoenix
#
for patchfile in "$PREFIX_LSB_VSX_CONFIG"patches/*.patch; do
 	if [ ! -f "$PREFIX_LSB_VSX_MARKERS/$(basename "$patchfile").applied" ]; then
 		echo "applying patch: $patchfile"
 		patch -d "$PREFIX_LSB_VSX_BUILD"/files -p1 < "$patchfile" 
 		touch "$PREFIX_LSB_VSX_MARKERS/$(basename "$patchfile").applied"
 	fi
done

#
# # Build all under phoenix
#

# shellcheck disable=SC1000-SC9999
(cd "$PREFIX_LSB_VSX_BUILD"/files && . ./setup.sh)

#
# # Copy all to phoenix file system
#
mkdir -p "$PREFIX_ROOTFS/usr/test/lsb_vsx_posix"
cp -a "$PREFIX_LSB_VSX_FILES" "$PREFIX_ROOTFS/usr/test/lsb_vsx_posix"

