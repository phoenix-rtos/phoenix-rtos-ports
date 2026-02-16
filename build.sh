#!/usr/bin/env bash
#
# Shell script for building Phoenix-RTOS ports
#
# Copyright 2019, 2024, 2026 Phoenix Systems
# Author: Pawel Pisarczyk, Daniel Sawka, Adam Greloch
#

PORTS_RES="${PREFIX_BUILD}/ports.json"
PORT_MANAGER_FLAGS=(
  "--res=${PORTS_DB}"
  # "-v"
  # "-r"
)
PORT_MANAGER="${PREFIX_PROJECT}/phoenix-rtos-ports/port_manager.py"

function port_manager() {
  "${PORT_MANAGER}" "${PORT_MANAGER_FLAGS[@]}" "$@"
}

if [ "$V" != 1 ]; then
  PORT_MANAGER_FLAGS+=("-r")
fi

port_manager build "${PORTS_CONFIG}"
