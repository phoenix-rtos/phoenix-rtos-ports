#!/usr/bin/env bash

set -e

VER="3.3"
FS_MARK="fs_mark-$VER"
FS_MARK_COMMIT="2628be58146de63a13260ff64550f84275556c0e"
PKG_URL="https://github.com/josefbacik/fs_mark/archive/${FS_MARK_COMMIT}.tar.gz"
PKG_MIRROR_URL="https://files.phoesys.com/ports/${FS_MARK}.tar.gz"

PREFIX_FS_MARK_SRC="${PREFIX_PORT_BUILD}/src"
PREFIX_FS_MARK_MARKERS="${PREFIX_PORT_BUILD}/markers"

mkdir -p "$PREFIX_FS_MARK_MARKERS"

#
# # Download and unpack
#
if ! [ -f "${PREFIX_PORT}/${FS_MARK}.tar.gz" ]; then
	if ! wget "$PKG_URL" -O "${PREFIX_PORT}/${FS_MARK}.tar.gz" --no-check-certificate; then
		wget "$PKG_MIRROR_URL" -P "$PREFIX_PORT" --no-check-certificate
	fi
fi

if [ ! -d "$PREFIX_FS_MARK_SRC" ]; then
	tar xzf "${PREFIX_PORT}/${FS_MARK}.tar.gz" -C "$PREFIX_PORT_BUILD"
	mv "${PREFIX_PORT_BUILD}/fs_mark-$FS_MARK_COMMIT" "$PREFIX_FS_MARK_SRC"
fi

#
# # Apply patches
#
for patchfile in "${PREFIX_PORT}/patches/"*.patch; do
	if [ ! -f "${PREFIX_FS_MARK_MARKERS}/$(basename "$patchfile").applied" ]; then
		echo "applying patch: $patchfile"
		patch -d "$PREFIX_FS_MARK_SRC" -p1 < "$patchfile"
		touch "${PREFIX_FS_MARK_MARKERS}/$(basename "$patchfile").applied"
	fi
done

#
# # Build fs_mark
#
cd "$PREFIX_FS_MARK_SRC" && make

#
# # Strip and install
#
cp -a "${PREFIX_FS_MARK_SRC}/fs_mark" "${PREFIX_PROG}/fs_mark"
eval "$STRIP" -o "${PREFIX_PROG_STRIPPED}/fs_mark" "${PREFIX_PROG}/fs_mark"
b_install "${PREFIX_PROG_STRIPPED}/fs_mark" /bin
