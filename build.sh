#!/usr/bin/env bash
#
# Shell script for building Phoenix-RTOS ports
#
# Copyright 2019 Phoenix Systems
# Author: Pawel Pisarczyk
#

set -e

if [ "$TARGET_FAMILY" = "ia32" ]; then
	HOST_TARGET="i386"
	HOST="i386-pc-phoenix"
elif [ "$TARGET_FAMILY" = "armv7a7" ]; then
	HOST_TARGET="arm"
	HOST="arm-phoenix"
elif [ "$TARGET_FAMILY" = "riscv64" ]; then
	HOST_TARGET="riscv64"
	HOST="riscv64-phoenix"
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


if [ -n "$PORTS_INSTALL_STRIPPED" ] && [ "$PORTS_INSTALL_STRIPPED" = "n" ]; then
	export PREFIX_PORTS_INSTALL="$PREFIX_PROG"
else
	export PREFIX_PORTS_INSTALL="$PREFIX_PROG_STRIPPED"
fi

[ "${PORTS_MBEDTLS}" = "y" ] && ./phoenix-rtos-ports/mbedtls/build.sh

[ "${PORTS_BUSYBOX}" = "y" ] && ./phoenix-rtos-ports/busybox/build.sh

[ "${PORTS_PCRE}" = "y" ] && ./phoenix-rtos-ports/pcre/build.sh

[ "${PORTS_OPENSSL}" = "y" ] && ./phoenix-rtos-ports/openssl/build.sh

[ "${PORTS_ZLIB}" = "y" ] && ./phoenix-rtos-ports/zlib/build.sh

[ "${PORTS_LIGHTTPD}" = "y" ] && ./phoenix-rtos-ports/lighttpd/build.sh

[ "${PORTS_DROPBEAR}" = "y" ] && ./phoenix-rtos-ports/dropbear/build.sh

[ "${PORTS_LUA}" = "y" ] && ./phoenix-rtos-ports/lua/build.sh

[ "${PORTS_LZO}" = "y" ] && ./phoenix-rtos-ports/lzo/build.sh

[ "${PORTS_OPENVPN}" = "y" ] && ./phoenix-rtos-ports/openvpn/build.sh

[ "${PORTS_CURL}" = "y" ] && ./phoenix-rtos-ports/curl/build.sh

[ "${PORTS_JANSSON}" = "y" ] && ./phoenix-rtos-ports/jansson/build.sh

[ "${PORTS_MICROPYTHON}" = "y" ] && ./phoenix-rtos-ports/micropython/build.sh

[ "${PORTS_SSCEP}" = "y" ] && ./phoenix-rtos-ports/sscep/build.sh

[ "${PORTS_WPA_SUPPLICANT}" = "y" ] && ./phoenix-rtos-ports/wpa_supplicant/build.sh

[ "${PORTS_LIBEVENT}" = "y" ] && ./phoenix-rtos-ports/libevent/build.sh

[ "${PORTS_OPENIKED}" = "y" ] && ./phoenix-rtos-ports/openiked/build.sh

[ "${PORTS_AZURE_SDK}" = "y" ] && ./phoenix-rtos-ports/azure_sdk/build.sh

[ "${PORTS_PICOCOM}" = "y" ] && ./phoenix-rtos-ports/picocom/build.sh

[ "${PORTS_FS_MARK}" = "y" ] && ./phoenix-rtos-ports/fs_mark/build.sh

[ "${PORTS_COREMARK}" = "y" ] && ./phoenix-rtos-ports/coremark/build.sh

[ "${PORTS_X264}" = "y" ] && ./phoenix-rtos-ports/x264/build.sh

exit 0
