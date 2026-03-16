#!/usr/bin/env bash
#
# Shell script for building Phoenix-RTOS ports
#
# Copyright 2019, 2024 Phoenix Systems
# Author: Pawel Pisarczyk, Daniel Sawka
#

set -e

# unset phoenix-rtos DEBUG variable as it changes how ports are compiled
unset DEBUG

if [ "$TARGET_FAMILY" = "ia32" ]; then
	HOST_TARGET="i386"
	HOST="i386-pc-phoenix"
elif [[ "$TARGET_FAMILY" == "arm"* ]]; then
	HOST_TARGET="arm"
	HOST="arm-phoenix"
elif [ "$TARGET_FAMILY" = "sparcv8leon" ]; then
	HOST_TARGET="sparc"
	HOST="sparc-phoenix"
else
	HOST_TARGET="$TARGET_FAMILY"
	HOST="${TARGET_FAMILY}-phoenix"
fi
export HOST_TARGET HOST

# use CFLAGS/LDFLAGS/STRIP taken from make
CFLAGS="$EXPORT_CFLAGS"
LDFLAGS="$EXPORT_LDFLAGS"
STRIP="$EXPORT_STRIP"
export CFLAGS LDFLAGS STRIP

export PORTS_MIRROR_BASEURL="https://files.phoesys.com/ports/"

if [ -n "$PORTS_INSTALL_STRIPPED" ] && [ "$PORTS_INSTALL_STRIPPED" = "n" ]; then
	export PREFIX_PORTS_INSTALL="$PREFIX_PROG"
else
	export PREFIX_PORTS_INSTALL="$PREFIX_PROG_STRIPPED"
fi

# List of directories with ports. Built in this order
ports=(
	"mbedtls"
	"busybox"
	"pcre"
	"openssl"
	"zlib"
	"lighttpd"
	"dropbear"
	"lua"
	"lzo"
	"openvpn"
	"curl"
	"jansson"
	"micropython"
	"sscep"
	"wpa_supplicant"
	"libevent"
	"openiked"
	"azure_sdk"
	"picocom"
	"fs_mark"
	"coremark"
	"coremark_pro"
	"coreMQTT"
	"lsb_vsx"
	"heatshrink"
	"smolrtsp"
)


for port in "${ports[@]}"; do
(
	port_env_name="PORTS_${port^^}"
	if [ "${!port_env_name}" = "y" ]; then
		export PREFIX_PORT="${PREFIX_PROJECT}/phoenix-rtos-ports/${port}"
		# TODO: Maybe "${PREFIX_BUILD}/ports/${port}" to avoid any potential name clashes?
		export PREFIX_PORT_BUILD="${PREFIX_BUILD}/${port}"

		source "${PREFIX_PROJECT}/phoenix-rtos-ports/build.subr"

		b_log "Building ${port}"
		mkdir -p "${PREFIX_PORT_BUILD}"
		./phoenix-rtos-ports/"${port}"/build.sh
	fi
)
done

[ "${PORTS_X264}" = "y" ] && ./phoenix-rtos-ports/x264/build.sh

exit 0
