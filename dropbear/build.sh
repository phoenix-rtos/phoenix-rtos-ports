#!/usr/bin/env bash

set -e

DROPBEAR=dropbear-2018.76
PKG_URL="https://matt.ucc.asn.au/dropbear/releases/${DROPBEAR}.tar.bz2"
PKG_MIRROR_URL="https://files.phoesys.com/ports/${DROPBEAR}.tar.bz2"

b_log "Building dropbear"
PREFIX_DROPBEAR="${PREFIX_PROJECT}/phoenix-rtos-ports/dropbear"
PREFIX_DROPBEAR_BUILD="${PREFIX_BUILD}/dropbear"
PREFIX_DROPBEAR_SRC="${PREFIX_DROPBEAR_BUILD}/${DROPBEAR}"
PREFIX_DROPBEAR_MARKERS="${PREFIX_DROPBEAR_BUILD}/markers"

#
# Download and unpack
#
mkdir -p "$PREFIX_DROPBEAR_BUILD" "$PREFIX_DROPBEAR_MARKERS"
if [ ! -f "$PREFIX_DROPBEAR/${DROPBEAR}.tar.bz2" ]; then
	if ! wget "$PKG_URL" -P "${PREFIX_DROPBEAR}" --no-check-certificate; then
		wget "$PKG_MIRROR_URL" -P "${PREFIX_DROPBEAR}" --no-check-certificate
	fi
fi
[ -d "$PREFIX_DROPBEAR_SRC" ] || ( tar jxf "$PREFIX_DROPBEAR/${DROPBEAR}.tar.bz2" -C "${PREFIX_DROPBEAR_BUILD}" && rm -rf "${PREFIX_DROPBEAR_MARKERS:?}/*" )

#
# Apply patches
#
for patchfile in "$PREFIX_DROPBEAR"/patch/*; do
	if [ ! -f "$PREFIX_DROPBEAR_MARKERS/$(basename "$patchfile").applied" ]; then
		echo "applying patch: $patchfile"
		patch -d "$PREFIX_DROPBEAR_SRC" -p1 < "$patchfile"
		touch "$PREFIX_DROPBEAR_MARKERS/$(basename "$patchfile").applied"
	fi
done

#
# Configure
#
if [ ! -f "$PREFIX_DROPBEAR_BUILD/config.h" ]; then
	cp -a "$PREFIX_DROPBEAR/localoptions.h" "$PREFIX_DROPBEAR_BUILD"

	DROPBEAR_CFLAGS="-DENDIAN_LITTLE -DUSE_DEV_PTMX ${DROPBEAR_CUSTOM_CFLAGS}"
	DROPBEAR_LDFLAGS=""
	ENABLE_ZLIB="no" && [ "$PORTS_ZLIB" = "y" ] && ENABLE_ZLIB="yes"

	( cd "${PREFIX_DROPBEAR_BUILD}" && "${PREFIX_DROPBEAR_SRC}/configure" CPPFLAGS="${CFLAGS} ${DROPBEAR_CFLAGS}" CFLAGS="${CFLAGS} ${DROPBEAR_CFLAGS}" \
		LDFLAGS="${CFLAGS} ${LDFLAGS} ${DROPBEAR_LDFLAGS}" ARFLAGS="-r" \
		--host="${HOST}" --includedir="${PREFIX_H}"  \
		--prefix="${PREFIX_PROG}" --program-prefix="${PREFIX_PROG}" --libdir="${PREFIX_A}" --bindir="${PREFIX_PROG}" --enable-zlib="$ENABLE_ZLIB" --enable-static \
		--disable-lastlog --disable-utmp --disable-utmpx --disable-wtmp --disable-wtmpx --disable-harden )
fi

#
# Make
#
# create multi-binary and hardlinks
make PROGRAMS="dropbear dbclient dropbearkey scp" -C "${PREFIX_DROPBEAR_BUILD}" CROSS_COMPILE="$CROSS" MULTI=1 NO_ADDTL_WARNINGS=1

"${CROSS}strip" -s "$PREFIX_DROPBEAR_BUILD/dropbearmulti" -o "$PREFIX_PROG_STRIPPED/dropbearmulti"
cp -a "$PREFIX_DROPBEAR_BUILD/dropbearmulti" "$PREFIX_PROG/dropbearmulti"

b_install "$PREFIX_PORTS_INSTALL/dropbearmulti" /usr/bin
mkdir -p "$PREFIX_ROOTFS/usr/sbin"
ln -f "$PREFIX_ROOTFS/usr/bin/dropbearmulti" "$PREFIX_ROOTFS/usr/sbin/dropbear"
ln -f "$PREFIX_ROOTFS/usr/bin/dropbearmulti" "$PREFIX_ROOTFS/usr/bin/dbclient"
ln -f "$PREFIX_ROOTFS/usr/bin/dropbearmulti" "$PREFIX_ROOTFS/usr/bin/scp"
