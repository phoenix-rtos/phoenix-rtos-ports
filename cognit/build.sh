#!/usr/bin/env bash

set -e

COGNIT="device-runtime-c"
GIT_PKG_URL="https://github.com/SovereignEdgeEU-COGNIT/device-runtime-c"


PREFIX_PORT_SRC="${PREFIX_PORT_BUILD}/${COGNIT}"


if [ ! -d "${PREFIX_PORT_SRC}" ]; then
    git clone ${GIT_PKG_URL} ${PREFIX_PORT_SRC}
    cd ${PREFIX_PORT_SRC}
    git checkout 02f067e
    git apply ${PREFIX_PORT}/01_include_headers.patch
    git apply ${PREFIX_PORT}/02_adjust_loglevel.patch
fi

cp -a "${PREFIX_PORT}/CMakeLists.txt" "${PREFIX_PORT_SRC}/CMakeLists.txt"

cmake -DCOGNIT_BUILD_EXAMPLES=OFF -S "${PREFIX_PORT_SRC}" -B "${PREFIX_PORT_BUILD}"
make -C "${PREFIX_PORT_BUILD}" -j 9
cmake --install "${PREFIX_PORT_BUILD}" --prefix "${PREFIX_BUILD}"
