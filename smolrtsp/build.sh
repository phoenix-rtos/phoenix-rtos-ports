#!/usr/bin/env bash

set -e

VERSION=0.1.3

PKG_URL="https://github.com/OpenIPC/smolrtsp/archive/refs/tags/v${VERSION}.tar.gz"
PREFIX_SMOLRTSP_SRC="${PREFIX_PORT_BUILD}/smolrtsp-${VERSION}"

#
# Download and unpack
#
mkdir -p "$PREFIX_PORT_BUILD"
b_port_download "https://github.com/OpenIPC/smolrtsp/archive/refs/tags/" "v${VERSION}.tar.gz"
[ -d "$PREFIX_SMOLRTSP_SRC" ] || tar zxf "${PREFIX_PORT}/v${VERSION}.tar.gz" -C "$PREFIX_PORT_BUILD"

#
# Apply patches
#
b_port_apply_patches "$PREFIX_SMOLRTSP_SRC"

#
# Make
#
pushd "$PREFIX_SMOLRTSP_SRC"
mkdir -p build
cd build
cmake -DCMAKE_INSTALL_PREFIX="$PREFIX_BUILD" -DCMAKE_BUILD_TYPE=Release ..
cmake --build .
cmake --install .
popd
