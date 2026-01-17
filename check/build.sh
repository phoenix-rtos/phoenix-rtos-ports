#!/usr/bin/env bash

set -e

CHECK_VER="0.10.0"
CHECK="check-$CHECK_VER"
CHECK_PKG_URL="https://github.com/libcheck/check/archive/refs/tags/${CHECK_VER}.tar.gz"
CHECK_PKG_MIRROR_URL="https://files.phoesys.com/ports/${CHECK}.tar.gz"

PREFIX_CHECK="${PREFIX_PROJECT}/phoenix-rtos-ports/check"
PREFIX_CHECK_SRC="${PREFIX_BUILD}/check"

b_log "Building check test framework"

#
# Download and unpack
#
if [ ! -f "${PREFIX_CHECK}/${CHECK}.tar.gz" ]; then
	if ! wget "$CHECK_PKG_URL" -O "${PREFIX_CHECK}/${CHECK}.tar.gz" --no-check-certificate; then
		wget "$CHECK_PKG_MIRROR_URL" -P "$PREFIX_CHECK" --no-check-certificate
	fi
fi

if [ ! -d "$PREFIX_CHECK_SRC" ]; then
	tar xzf "${PREFIX_CHECK}/${CHECK}.tar.gz" -C "$PREFIX_BUILD" && \
    mv "${PREFIX_BUILD}/${CHECK}" "$PREFIX_CHECK_SRC"
fi

#
# Configure
#
mkdir -p "${PREFIX_CHECK_SRC}/include"
if [ ! -f "${PREFIX_CHECK_SRC}/config.h" ]; then
	CHECK_CFLAGS="-std=gnu99 -I${PREFIX_CHECK_SRC}/include"
	(cd "$PREFIX_CHECK_SRC" && autoreconf -i -v -f && \
	PKG_CONFIG="" ./configure CC="$CC" LD="$LD" AR="$AR" STRIP="${CROSS}strip" CFLAGS="$CFLAGS $CHECK_CFLAGS" \
							  LDFLAGS="$LDFLAGS" --host="${HOST}" --build="x86_64-linux-gnu" --disable-subunit \
							  --disable-shared --disable-doc --enable-static --libdir="$PREFIX_A" \
							  --includedir="${PREFIX_CHECK_SRC}/include")
fi

#
# Make
#
SUBDIRS="lib src . tests" # Run makefiles from this directories
make -C "$PREFIX_CHECK_SRC"
make SUBDIRS="$SUBDIRS" doc_DATA="" m4data_DATA="" -C "$PREFIX_CHECK_SRC" install
