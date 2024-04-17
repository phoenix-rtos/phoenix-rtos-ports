#!/usr/bin/env bash

set -e


b_log "Building cognit"
PREFIX_COGNIT="${PREFIX_PROJECT}/phoenix-rtos-ports/cognit"
PREFIX_COGNIT_BUILD="${PREFIX_BUILD}/cognit"
PREFIX_COGNIT_INSTALL="$PREFIX_COGNIT_BUILD/install"

#
# Download and unpack
#
mkdir -p "$PREFIX_COGNIT_BUILD" "$PREFIX_COGNIT_INSTALL"
# if [ ! -f "$PREFIX_COGNIT/${cognit}.tar.gz" ]; then
# 	if ! wget "$PKG_URL" -P "${PREFIX_COGNIT}" --no-check-certificate; then
# 		wget "$PKG_MIRROR_URL" -P "${PREFIX_COGNIT}" --no-check-certificate
# 	fi
# fi
# [ -d "$PREFIX_COGNIT_SRC" ] || tar zxf "$PREFIX_COGNIT/${cognit}.tar.gz" -C "$PREFIX_COGNIT_BUILD"


#
# Configure
#
# if [ ! -f "$PREFIX_COGNIT_BUILD/config.status" ]; then
# 	( cd "$PREFIX_COGNIT_BUILD" && PKG_CONFIG="" "$PREFIX_COGNIT_SRC/configure" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
# 		--host="${HOST}" --sbindir="$PREFIX_PROG" --disable-pthreads --disable-threaded-resolver \
# 		--prefix="$PREFIX_COGNIT_INSTALL" --disable-ntlm-wb --without-zlib )
# fi

cp -a "$PREFIX_COGNIT" "$PREFIX_BUILD"

#
# Make
#
cmake -S "$PREFIX_COGNIT_BUILD" -B "$PREFIX_COGNIT_INSTALL" 
make -C "$PREFIX_COGNIT_INSTALL"

cp -a "$PREFIX_COGNIT_BUILD/include/cognit" "$PREFIX_H"
cp -a "$PREFIX_COGNIT_INSTALL/libcognit.a" "$PREFIX_A"
# cp -a "$PREFIX_COGNIT_INSTALL/bin/cognit" "$PREFIX_PROG/cognit"
# "${CROSS}strip" -s "$PREFIX_PROG/cognit" -o "$PREFIX_PROG_STRIPPED/cognit"
# b_install "$PREFIX_PORTS_INSTALL/cognit" /usr/bin/
