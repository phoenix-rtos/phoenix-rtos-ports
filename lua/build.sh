#!/usr/bin/env bash

set -e

LUA=lua-5.3.5
PKG_URL="https://www.lua.org/ftp/${LUA}.tar.gz"
PKG_MIRROR_URL="https://files.phoesys.com/ports/${LUA}.tar.gz"

b_log "Building lua"
PREFIX_LUA="${PREFIX_PROJECT}/phoenix-rtos-ports/lua"
PREFIX_LUA_BUILD="${PREFIX_BUILD}/lua"
PREFIX_LUA_SRC="${PREFIX_LUA_BUILD}/${LUA}"


mkdir -p "$PREFIX_LUA_BUILD"
if [ ! -f "$PREFIX_LUA/${LUA}.tar.gz" ]; then
	if ! wget "$PKG_URL" -P "${PREFIX_LUA}" --no-check-certificate; then
		wget "$PKG_MIRROR_URL" -P "${PREFIX_LUA}" --no-check-certificate
	fi
fi
if [ ! -d "$PREFIX_LUA_SRC" ]; then
	tar zxf "$PREFIX_LUA/${LUA}.tar.gz" -C "$PREFIX_LUA_BUILD"
	cp "$PREFIX_LUA/Makefile" "$PREFIX_LUA_SRC/src/"
fi

# FIXME: no out-of-tree building
make -C "$PREFIX_LUA_SRC" posix

$STRIP -s "$PREFIX_LUA_SRC/src/lua" -o "$PREFIX_PROG_STRIPPED/lua"
$STRIP -s "$PREFIX_LUA_SRC/src/luac" -o "$PREFIX_PROG_STRIPPED/luac"
cp -a "$PREFIX_LUA_SRC/src/lua" "$PREFIX_PROG/lua"
cp -a "$PREFIX_LUA_SRC/src/luac" "$PREFIX_PROG/luac"

b_install "$PREFIX_PORTS_INSTALL/lua" /bin
b_install "$PREFIX_PORTS_INSTALL/luac" /bin
