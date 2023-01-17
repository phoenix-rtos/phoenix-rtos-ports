#!/usr/bin/env bash

set -e

LIBEVENT=libevent-2.1.12-stable
PKG_URL="https://github.com/libevent/libevent/releases/download/release-2.1.12-stable/${LIBEVENT}.tar.gz"
PKG_MIRROR_URL="https://files.phoesys.com/ports/${LIBEVENT}.tar.gz"

b_log "Building libevent"
PREFIX_LIBEVENT="${PREFIX_PROJECT}/phoenix-rtos-ports/libevent"
PREFIX_LIBEVENT_BUILD="${PREFIX_BUILD}/libevent"
PREFIX_LIBEVENT_SRC="${PREFIX_LIBEVENT_BUILD}/${LIBEVENT}"
PREFIX_LIBEVENT_MARKERS="${PREFIX_LIBEVENT_BUILD}/markers"
PREFIX_LIBEVENT_INSTALL="${PREFIX_LIBEVENT_BUILD}/install"

#
# Download and unpack
#
mkdir -p "$PREFIX_LIBEVENT_BUILD"

if [ ! -f "${PREFIX_LIBEVENT}/${LIBEVENT}.tar.gz" ]; then
	if ! wget "$PKG_URL" -P "${PREFIX_LIBEVENT}" --no-check-certificate; then
		wget "$PKG_MIRROR_URL" -P "${PREFIX_LIBEVENT}" --no-check-certificate
	fi
fi
[ -d "$PREFIX_LIBEVENT_SRC" ] || tar zxf "${PREFIX_LIBEVENT}/${LIBEVENT}.tar.gz" -C "$PREFIX_LIBEVENT_BUILD"

#
# Apply patches
#
mkdir -p "$PREFIX_LIBEVENT_MARKERS"

for patchfile in "${PREFIX_LIBEVENT}"/patches/*.patch; do
	if [ ! -f "${PREFIX_LIBEVENT_MARKERS}/$(basename "$patchfile").applied" ]; then
		echo "applying patch: $patchfile"
		patch -d "$PREFIX_LIBEVENT_SRC" -p1 < "$patchfile"
		touch "${PREFIX_LIBEVENT_MARKERS}/$(basename "$patchfile").applied"
	fi
done

#
# Make
#
mkdir -p "$PREFIX_LIBEVENT_INSTALL"

pushd "$PREFIX_LIBEVENT_SRC"
[ -f Makefile ] || ./configure INSTALL="/usr/bin/install -p" CPPFLAGS="$CFLAGS" --host="$HOST" --disable-thread-support --disable-openssl --disable-debug-mode --disable-libevent-regress --disable-samples --enable-function-sections \
	--disable-clock-gettime --disable-shared --prefix="$PREFIX_LIBEVENT_INSTALL" --includedir="${PREFIX_BUILD}/include" --libdir="${PREFIX_BUILD}/lib"
make install
popd
