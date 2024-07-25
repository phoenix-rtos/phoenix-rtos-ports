#!/usr/bin/env bash

set -e

LUA=lua-5.3.5
PKG_URL="https://www.lua.org/ftp/${LUA}.tar.gz"
PKG_MIRROR_URL="https://files.phoesys.com/ports/${LUA}.tar.gz"

PREFIX_LUA_SRC="${PREFIX_PORT_BUILD}/${LUA}"


mkdir -p "$PREFIX_PORT_BUILD"
if [ ! -f "$PREFIX_PORT/${LUA}.tar.gz" ]; then
	if ! wget "$PKG_URL" -P "${PREFIX_PORT}" --no-check-certificate; then
		wget "$PKG_MIRROR_URL" -P "${PREFIX_PORT}" --no-check-certificate
	fi
fi
if [ ! -d "$PREFIX_LUA_SRC" ]; then
	tar zxf "$PREFIX_PORT/${LUA}.tar.gz" -C "$PREFIX_PORT_BUILD"
	cp "$PREFIX_PORT/Makefile" "$PREFIX_LUA_SRC/src/"
fi

# FIXME: no out-of-tree building
make -C "$PREFIX_LUA_SRC" posix

$STRIP -o "$PREFIX_PROG_STRIPPED/lua" "$PREFIX_LUA_SRC/src/lua"
$STRIP -o "$PREFIX_PROG_STRIPPED/luac" "$PREFIX_LUA_SRC/src/luac"
cp -a "$PREFIX_LUA_SRC/src/lua" "$PREFIX_PROG/lua"
cp -a "$PREFIX_LUA_SRC/src/luac" "$PREFIX_PROG/luac"

b_install "$PREFIX_PORTS_INSTALL/lua" /bin
b_install "$PREFIX_PORTS_INSTALL/luac" /bin
