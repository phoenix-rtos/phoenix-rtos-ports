#!/bin/bash

set -e

UPYTH_VER="1.15"
UPYTH="micropython-${UPYTH_VER}"

PREFIX_UPYTH="${TOPDIR}/phoenix-rtos-ports/micropython"
PREFIX_UPYTH_BUILD="${PREFIX_BUILD}/micropython"
PREFIX_UPYTH_SRC=${PREFIX_UPYTH_BUILD}/${UPYTH}
PREFIX_UPYTH_CONFIG="${PREFIX_UPYTH}/${UPYTH}-config/"
PREFIX_UPYTH_MARKERS="$PREFIX_UPYTH_BUILD/markers/"

b_log "Building micropython"

#
# Download and unpack
#
mkdir -p "$PREFIX_UPYTH_BUILD" "$PREFIX_UPYTH_MARKERS"
[ -f "$PREFIX_UPYTH/${UPYTH}.tar.xz" ] || wget https://github.com/micropython/micropython/releases/download/v${UPYTH_VER}/${UPYTH}.tar.xz -P "$PREFIX_UPYTH"
[ -d "${PREFIX_UPYTH_SRC}" ] || tar xf "$PREFIX_UPYTH/${UPYTH}.tar.xz" -C "$PREFIX_UPYTH_BUILD"


#
# Apply patches and copy files
#
for patchfile in "$PREFIX_UPYTH_CONFIG"/patches/*.patch; do
	if [ ! -f "$PREFIX_UPYTH_MARKERS/$(basename "$patchfile").applied" ]; then
		echo "applying patch: $patchfile"
		patch -d "$PREFIX_UPYTH_SRC" -p1 < "$patchfile"
		touch "$PREFIX_UPYTH_MARKERS/$(basename "$patchfile").applied"
	fi
done
cp -a "${PREFIX_UPYTH_CONFIG}/files/001_mpconfigport.mk" "${PREFIX_UPYTH_SRC}/ports/unix/mpconfigport.mk" && echo "Copied mpconfigport.mk!"


#
# Micropython internal use stack/heap size (not actual application stack/heap)
# Values are to be overwritten in _targets/build.project.*
#
: "${UPYTH_STACKSZ=4096}"
: "${UPYTH_HEAPSZ=16384}"


#
# Architecture specific flags/values set
#
if [ "${TARGET_FAMILY}" = "armv7m7" ]; then
	STRIPEXP="--strip-unneeded"
elif [ "${TARGET_FAMILY}" = "ia32" ]; then
	STRIPEXP="--strip-all"
else
	b_log "Warning! Phoenix-RTOS for ${TARGET_FAMILY} does not support MicroPython compilation (yet!)"
	b_log "The compilation attempt will start in 5 seconds..."
	sleep 5
fi
# changing LDFLAGS from "ld" params format to "gcc" params - prefixing with -Wl, and changing spaces to colons
LDFLAGS_VAR=$(echo " ${LDFLAGS}" | sed "s/\s/,/g" | sed "s/,-/ -Wl,-/g")

export STRIPFLAGS_EXTRA="${STRIPEXP}"
export PHOENIX_MATH_ABSENT="expm1 log1p asinh acosh atanh erf tgamma lgamma copysign __sin __cos __tan __signbit"
export LDFLAGS_EXTRA="${CFLAGS} $LDFLAGS_VAR"
export CFLAGS_EXTRA="${CFLAGS} -DUPYTH_STACKSZ=${UPYTH_STACKSZ} -DUPYTH_HEAPSZ=${UPYTH_HEAPSZ} "
# clear original ld-format ldflags/cflags
export LDFLAGS=""
export CFLAGS=""


#
# Build and install micropython binary
#
(cd "${PREFIX_UPYTH_SRC}/mpy-cross" && make all BUILD="${PREFIX_UPYTH_BUILD}" CROSS_COMPILE="${CROSS}")
(cd "${PREFIX_UPYTH_SRC}/ports/unix" && make all CROSS_COMPILE="${CROSS}")

cp -a "${PREFIX_UPYTH_SRC}/ports/unix/micropython" "$PREFIX_PROG_STRIPPED"
b_install "$PREFIX_PORTS_INSTALL/micropython" /bin/
