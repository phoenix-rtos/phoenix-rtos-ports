#!/usr/bin/env bash

set -e

version="${PORTS_LUA_VERSION:-5.3.6}"
archive_filename="lua-${version}.tar.gz"
tests_version="5.4.6"

PREFIX_PORT_SRC="${PREFIX_PORT_BUILD}/${version}"
PREFIX_PORT_TESTS="${PREFIX_PORT_BUILD}/${tests_version}-tests"

b_port_download "https://www.lua.org/ftp/" "${archive_filename}"

if [ ! -d "${PREFIX_PORT_SRC}" ]; then
	echo "Extracting sources from ${archive_filename}"
	mkdir -p "${PREFIX_PORT_SRC}"
	tar -axf "${PREFIX_PORT}/${archive_filename}" --strip-components 1 -C "${PREFIX_PORT_SRC}"
fi

b_port_apply_patches "${PREFIX_PORT_SRC}" "${version}"

if [ "${PORTS_LUA_RESTRAIN}" = "y" ]; then
	b_port_apply_patches "${PREFIX_PORT_SRC}" "${version}/restrain"
fi

mycflags=(
	${CFLAGS}
	-DLUAI_MAXSTACK=${PORTS_LUA_STACK_SIZE:-2000}
)

if [ "${PORTS_LUA_COMPAT_5_2}" = "y" ]; then mycflags+=("-DLUA_COMPAT_5_2"); fi
if [ "${PORTS_LUA_DEBUG}" = "y" ]; then mycflags+=("-DLUA_USE_APICHECK"); fi

myldflags=(
	${LDFLAGS}
	-Wl,-z,stack-size=${PORTS_LUA_CSTACK_SIZE:-4096}
)

# FIXME: no out-of-tree building
make -C "${PREFIX_PORT_SRC}/src" MYCFLAGS="${mycflags[*]}" MYLDFLAGS="${myldflags[*]}"
make -C "${PREFIX_PORT_SRC}" install INSTALL_TOP="${PREFIX_BUILD}"

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
