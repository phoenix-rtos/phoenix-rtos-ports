#!/usr/bin/env bash
#
# Shell script for building Phoenix-RTOS ports
#
# Copyright 2019, 2024, 2026 Phoenix Systems
# Author: Pawel Pisarczyk, Daniel Sawka, Adam Greloch
#
# SPDX-License-Identifier: BSD-3-Clause
#

PORTS_RES="${PREFIX_BUILD}/ports.json"
PORT_MANAGER_FLAGS=(
  "--res=${PORTS_RES}"
)
PORT_MANAGER="${PREFIX_PROJECT}/phoenix-rtos-ports/port_mgmt/port_manager.py"

function port_manager() {
  "${PORT_MANAGER}" "${PORT_MANAGER_FLAGS[@]}" "$@"
}

if [ "$RAW_LOG" != 1 ]; then
  PORT_MANAGER_FLAGS+=("-r")
fi

if [ "$PORTS_VALIDATE_ONLY" == 1 ]; then
  b_log "Validating ports"
  port_manager validate
  exit 0
fi

b_log "Installing ports"

port_manager build "${PORTS_CONFIG}"
