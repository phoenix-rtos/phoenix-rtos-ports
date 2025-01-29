#!/usr/bin/env bash

set -e

appname="joe"
version="4.6"
archive_filename="${appname}-${version}.tar.gz"

PREFIX_PORT_SRC="${PREFIX_PORT_BUILD}/${appname}-${version}/"

b_port_download "https://sourceforge.net/projects/joe-editor/files/JOE%20sources/joe-4.6/" "${archive_filename}"

if [ ! -d "${PREFIX_PORT_SRC}" ]; then
	echo "Extracting sources from ${archive_filename}"
	mkdir -p "${PREFIX_PORT_SRC}"
	tar -axf "${PREFIX_PORT}/${archive_filename}" --strip-components 1 -C "${PREFIX_PORT_SRC}"
fi

b_port_apply_patches "${PREFIX_PORT_SRC}"

if [ ! -f "${PREFIX_PORT_SRC}/config.status" ]; then
	(cd "${PREFIX_PORT_SRC}" && autoreconf -vfi &&
		"${PREFIX_PORT_SRC}/configure" CFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS}" \
		--prefix="/usr" --host="${HOST}" --enable-silent-rules --datadir="/usr/share" \
		--disable-curses --disable-termcap
	)
fi

make -C "${PREFIX_PORT_SRC}"

b_install "${PREFIX_PORT_SRC}/rc/joerc" /usr/etc/joe
b_install "${PREFIX_PORT_SRC}/syntax"/*.jsf /usr/share/joe/syntax
b_install "${PREFIX_PORT_SRC}/colors"/*.jcf /usr/share/joe/colors

${STRIP} -o "${PREFIX_PROG_STRIPPED}/joe" "${PREFIX_PORT_SRC}/joe/joe"
b_install "${PREFIX_PROG_STRIPPED}/joe" /usr/bin
