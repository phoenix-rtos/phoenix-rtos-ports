#!/usr/bin/env bash

set -e

version="${PORTS_LUA_VERSION:-5.3.6}"
archive_filename="lua-${version}.tar.gz"
tests_version="${PORTS_LUA_TESTS_VERSION:-5.3.4}" # There is no 5.3.6 tag for tests

PREFIX_PORT_SRC="${PREFIX_PORT_BUILD}/${version}"
PREFIX_PORT_TESTS="${PREFIX_PORT_BUILD}/${tests_version}-tests"
: "${PORTS_LUA_CONFIG_DIR:=${PREFIX_PORT}}"

b_port_download "https://www.lua.org/ftp/" "${archive_filename}"

if [ ! -d "${PREFIX_PORT_SRC}" ]; then
	echo "Extracting sources from ${archive_filename}"
	mkdir -p "${PREFIX_PORT_SRC}"
	tar -axf "${PREFIX_PORT}/${archive_filename}" --strip-components 1 -C "${PREFIX_PORT_SRC}"
fi

b_port_apply_patches "${PREFIX_PORT_SRC}" "${version}"

if [ "${PORTS_LUA_SAFE}" = "y" ]; then
	b_port_apply_patches "${PREFIX_PORT_SRC}" "${version}/safe"
fi

# shellcheck disable=SC2206
mycflags=(
	${CFLAGS} # Split intended
	"-I${PORTS_LUA_CONFIG_DIR}"
)

if [ -n "${PORTS_LUA_BIN_CSTACK_SIZE}" ]; then
	LDFLAGS+=" -Wl,-z,stack-size=${PORTS_LUA_BIN_CSTACK_SIZE}"
fi

# FIXME: no out-of-tree building
make -C "${PREFIX_PORT_SRC}/src" MYCFLAGS="${mycflags[*]}" MYLDFLAGS="${LDFLAGS}"
make -C "${PREFIX_PORT_SRC}" install INSTALL_TOP="${PREFIX_BUILD}"

cp -a "${PORTS_LUA_CONFIG_DIR}/luaconf_local.h" "${PREFIX_H}/"

$STRIP -o "${PREFIX_PROG_STRIPPED}/lua" "${PREFIX_PROG}/lua"
$STRIP -o "${PREFIX_PROG_STRIPPED}/luac" "${PREFIX_PROG}/luac"

b_install "${PREFIX_PORTS_INSTALL}/lua" /usr/bin
b_install "${PREFIX_PORTS_INSTALL}/luac" /usr/bin

if [ "${PORTS_LUA_INSTALL_TESTS}" = "y" ]; then
	tests_filename="lua-${tests_version}-tests.tar.gz"
	b_port_download "https://www.lua.org/tests/" "${tests_filename}"

	if [ ! -d "${PREFIX_PORT_TESTS}" ]; then
		echo "Extracting tests from ${tests_filename}"
		mkdir -p "${PREFIX_PORT_TESTS}"
		tar -axf "${PREFIX_PORT}/${tests_filename}" --strip-components 1 -C "${PREFIX_PORT_TESTS}"
	fi

	b_install "${PREFIX_PORT_TESTS}"/*.lua /usr/share/lua/tests
fi
