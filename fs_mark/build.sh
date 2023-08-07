#!/usr/bin/env bash

set -e

FS_MARK_VER="3.3"
FS_MARK=fs_mark-${FS_MARK_VER}
FS_MARK_COMMIT="2628be58146de63a13260ff64550f84275556c0e"
PKG_URL="https://github.com/josefbacik/fs_mark/archive/${FS_MARK_COMMIT}.tar.gz"
PKG_MIRROR_URL="https://files.phoesys.com/ports/${FS_MARK}.tar.gz"

b_log "Building fs_mark"
PREFIX_FS_MARK=${PREFIX_PROJECT}/phoenix-rtos-ports/fs_mark
PREFIX_FS_MARK_BUILD="${PREFIX_BUILD}/fs_mark"
PREFIX_FS_MARK_SRC="${PREFIX_FS_MARK_BUILD}/${FS_MARK}"
PREFIX_FS_MARK_MARKERS="${PREFIX_FS_MARK_BUILD}/markers"

#
# Download and unpack
#
mkdir -p "$PREFIX_FS_MARK_BUILD" "$PREFIX_FS_MARK_MARKERS"
if ! [ -f "${PREFIX_FS_MARK}/${FS_MARK}.tar.gz" ]; then
	if ! wget "$PKG_URL" -O "${PREFIX_FS_MARK}/${FS_MARK}.tar.gz" --no-check-certificate; then
		wget "$PKG_MIRROR_URL" -P "${PREFIX_FS_MARK}" --no-check-certificate
	fi
fi

if ! [ -d "${PREFIX_FS_MARK_SRC}" ]; then
	tar xzf "${PREFIX_FS_MARK}/${FS_MARK}.tar.gz" -C "${PREFIX_FS_MARK_BUILD}" && mv "${PREFIX_FS_MARK_BUILD}"/fs_mark-"${FS_MARK_COMMIT}" "${PREFIX_FS_MARK_BUILD}"/${FS_MARK}
fi

#
# Apply patches
#
for patchfile in "$PREFIX_FS_MARK"/patch/*; do
	if [ ! -f "$PREFIX_FS_MARK_MARKERS/$(basename "$patchfile").applied" ]; then
		echo "applying patch: $patchfile"
		patch -d "$PREFIX_FS_MARK_SRC" -p1 < "$patchfile"
		touch "$PREFIX_FS_MARK_MARKERS/$(basename "$patchfile").applied"
	fi
done

# Build fs_mark
cd "${PREFIX_FS_MARK_BUILD}/${FS_MARK}" && make

cp -a "$PREFIX_FS_MARK_BUILD/${FS_MARK}/fs_mark" "$PREFIX_PROG/fs_mark"
"${CROSS}strip" -s "${PREFIX_PROG}/fs_mark" -o "${PREFIX_PROG_STRIPPED}/fs_mark"
b_install "$PREFIX_PORTS_INSTALL/fs_mark" /bin
