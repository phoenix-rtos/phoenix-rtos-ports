#!/usr/bin/env bash

set -e

appname="libpng"
version="1.6.44"
archive_filename="${appname}-${version}.tar.gz"

PREFIX_PORT_SRC="${PREFIX_PORT_BUILD}/${appname}-${version}/"

b_port_download "http://prdownloads.sourceforge.net/libpng/" "${archive_filename}"

if [ ! -d "${PREFIX_PORT_SRC}" ]; then
	echo "Extracting sources from ${archive_filename}"
	mkdir -p "${PREFIX_PORT_SRC}"
	tar -axf "${PREFIX_PORT}/${archive_filename}" --strip-components 1 -C "${PREFIX_PORT_SRC}"
fi

b_port_apply_patches "${PREFIX_PORT_SRC}"

if [ ! -f "${PREFIX_PORT_SRC}/config.status" ]; then
	(cd "${PREFIX_PORT_SRC}" && autoreconf -vfi &&
		"${PREFIX_PORT_SRC}/configure" CFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS}" \
		--host="${HOST}" --bindir="${PREFIX_PROG}" --sbindir="${PREFIX_PROG}" \
		--libdir="${PREFIX_A}" --includedir="${PREFIX_H}" --datarootdir="${PREFIX_A}" \
		--disable-shared --enable-static --enable-silent-rules \
		--disable-tests --disable-tools
	)
fi

make -C "${PREFIX_PORT_SRC}"
make -C "${PREFIX_PORT_SRC}" install
