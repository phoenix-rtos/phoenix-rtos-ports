#!/usr/bin/env bash

set -e

b_log "Building picocom"

PCOM_VER="3.1"
PCOM="picocom-${PCOM_VER}"
PKG_URL="https://github.com/npat-efault/picocom/archive/refs/tags/${PCOM_VER}.tar.gz"
PKG_MIRROR_URL="https://files.phoesys.com/ports/${PCOM}.tar.gz"

PREFIX_PCOM="${PREFIX_PROJECT}/phoenix-rtos-ports/picocom"
PREFIX_PCOM_BUILD="${PREFIX_BUILD}/picocom"
PREFIX_PCOM_SRC=${PREFIX_PCOM_BUILD}/${PCOM}
PREFIX_PCOM_MARKERS="$PREFIX_PCOM_BUILD/markers"


#
# Download and unpack
#
mkdir -p "$PREFIX_PCOM_BUILD" "$PREFIX_PCOM_MARKERS"
if [ ! -f "$PREFIX_PCOM/${PCOM}.tar.gz" ]; then
	if ! wget "$PKG_URL" -P "${PREFIX_PCOM}" -O "$PREFIX_PCOM/${PCOM}.tar.gz" --no-check-certificate; then
		wget "$PKG_MIRROR_URL" -P "${PREFIX_PCOM}" -O "$PREFIX_PCOM/${PCOM}.tar.gz" --no-check-certificate
	fi
fi
[ -d "${PREFIX_PCOM_SRC}" ] || tar xf "$PREFIX_PCOM/${PCOM}.tar.gz" -C "$PREFIX_PCOM_BUILD"


#
# Apply patches and copy files
#
for patchfile in "$PREFIX_PCOM"/*.patch; do
	if [ ! -f "$PREFIX_PCOM_MARKERS/$(basename "$patchfile").applied" ]; then
		echo "applying patch: $patchfile"
		patch -d "$PREFIX_PCOM_SRC" -p1 < "$patchfile"
		touch "$PREFIX_PCOM_MARKERS/$(basename "$patchfile").applied"
	fi
done


# Changing LDFLAGS from "ld" params format to "gcc" params - prefixing with -Wl, and changing spaces to colons
LDFLAGS_VAR=$(echo " ${LDFLAGS}" | sed "s/\s/,/g" | sed "s/,-/ -Wl,-/g")
export LDFLAGS="${CFLAGS} $LDFLAGS_VAR"


#
# Make and strip
#
(cd "${PREFIX_PCOM_SRC}" && make clean && make)
cp -a "${PREFIX_PCOM_SRC}/picocom" "$PREFIX_PROG"
"${CROSS}strip" -s "${PREFIX_PROG}/picocom" -o "$PREFIX_PROG_STRIPPED/picocom"


b_install "${PREFIX_PROG_STRIPPED}/picocom" /bin
