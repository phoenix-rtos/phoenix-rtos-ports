#!/usr/bin/env bash

set -e

BUSYBOX=busybox-1.27.2
PKG_URL="https://busybox.net/downloads/${BUSYBOX}.tar.bz2"
PKG_MIRROR_URL="https://files.phoesys.com/ports/${BUSYBOX}.tar.bz2"

PREFIX_BUSYBOX_SRC="$PREFIX_PORT_BUILD/${BUSYBOX}/"
PREFIX_BUSYBOX_MARKERS="$PREFIX_PORT_BUILD/markers/"
: "${BUSYBOX_CONFIG:="${PREFIX_PORT}/config"}"


#
# Download and unpack
#
mkdir -p "$PREFIX_PORT_BUILD" "$PREFIX_BUSYBOX_MARKERS"
if [ ! -f "$PREFIX_PORT/${BUSYBOX}.tar.bz2" ]; then
	if ! wget -T 10 "$PKG_URL" -P "${PREFIX_PORT}" --no-check-certificate; then
		wget "$PKG_MIRROR_URL" -P "${PREFIX_PORT}" --no-check-certificate
	fi
fi
[ -d "$PREFIX_BUSYBOX_SRC" ] || ( tar jxf "$PREFIX_PORT/${BUSYBOX}.tar.bz2" -C "$PREFIX_PORT_BUILD" && rm -rf "${PREFIX_BUSYBOX_MARKERS:?}/*")

#
# Apply patches
#
for patchfile in "$PREFIX_PORT"/*.patch; do
	if [ ! -f "$PREFIX_BUSYBOX_MARKERS/$(basename "$patchfile").applied" ]; then
		echo "applying patch: $patchfile"
		patch -d "$PREFIX_BUSYBOX_SRC" -p1 < "$patchfile"
		touch "$PREFIX_BUSYBOX_MARKERS/$(basename "$patchfile").applied"
	fi
done

#
# Configure
#
if [ ! -f "${PREFIX_PORT_BUILD}/.config" ] || [ "${BUSYBOX_CONFIG}" -nt "${PREFIX_PORT_BUILD}/.config" ]; then
	cp -a "${BUSYBOX_CONFIG}" "${PREFIX_PORT_BUILD}"/.config
	make -C "${PREFIX_PORT_BUILD}" KBUILD_SRC="$PREFIX_BUSYBOX_SRC" -f "${PREFIX_BUSYBOX_SRC}"/Makefile CROSS_COMPILE="$CROSS" CONFIG_PREFIX="$PREFIX_FS/root" clean
fi

# hackish: remove the final binary to re-link potential libc changes
rm -rf "$PREFIX_PORT_BUILD/busybox_unstripped" "$PREFIX_PORT_BUILD/busybox"

# For MacOS
export LC_CTYPE=C
if [ -n "$PORTS_INSTALL_STRIPPED" ] && [ "$PORTS_INSTALL_STRIPPED" = "n" ]; then
	UNSTRIPPED=y
else
	UNSTRIPPED=n
fi

make -C "${PREFIX_PORT_BUILD}" KBUILD_SRC="$PREFIX_BUSYBOX_SRC" -f "${PREFIX_BUSYBOX_SRC}"/Makefile CROSS_COMPILE="$CROSS" CONFIG_PREFIX="$PREFIX_FS/root" SKIP_STRIP="$UNSTRIPPED" all
make -C "${PREFIX_PORT_BUILD}" KBUILD_SRC="$PREFIX_BUSYBOX_SRC" -f "${PREFIX_BUSYBOX_SRC}"/Makefile CROSS_COMPILE="$CROSS" CONFIG_PREFIX="$PREFIX_FS/root" SKIP_STRIP="$UNSTRIPPED" install
cp -a "$PREFIX_PORT_BUILD/busybox_unstripped" "$PREFIX_PROG"

if [ "$LONG_TEST" = "y" ]; then
	mkdir -p "$PREFIX_ROOTFS/usr/test/busybox"
	cp -a "$PREFIX_BUSYBOX_SRC/testsuite" "$PREFIX_ROOTFS/usr/test/busybox"
	# busybox test suite requires .config file and busybox binary in the same bin directory
	cp "$PREFIX_PORT_BUILD/.config" "$PREFIX_ROOTFS/bin"
fi
