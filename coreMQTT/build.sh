#!/usr/bin/env bash

set -e

COREMQTT_VERSION="2.3.0"
COREMQTT="coreMQTT-${COREMQTT_VERSION}"
PKG_URL="https://github.com/FreeRTOS/coreMQTT/archive/refs/tags/"


PREFIX_PORT_SRC="${PREFIX_PORT_BUILD}/${COREMQTT}/source"
PREFIX_PORT_STAGING="${PREFIX_PORT_BUILD}/staging"


b_port_download "${PKG_URL}" "${COREMQTT}.tar.gz" "v${COREMQTT_VERSION}.tar.gz"
[ -d "${PREFIX_PORT_SRC}" ] || tar zxf "${PREFIX_PORT}/${COREMQTT}.tar.gz" -C "$PREFIX_PORT_BUILD"

cp -a "${PREFIX_PORT}/CMakeLists.txt" "${PREFIX_PORT_BUILD}/CMakeLists.txt"

cmake -S "${PREFIX_PORT_BUILD}" -B "${PREFIX_PORT_STAGING}"
make -C "${PREFIX_PORT_STAGING}" -j 9
cmake --install "${PREFIX_PORT_STAGING}" --prefix "${PREFIX_BUILD}"
