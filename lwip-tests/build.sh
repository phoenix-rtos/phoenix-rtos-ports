#!/usr/bin/env bash

set -e

b_log "Building lwip-test"

LWIP_CONTRIB_TAG="STABLE-2_1_0_RELEASE"
LWIP_CONTRIB_PKG_URL="https://git.savannah.nongnu.org/cgit/lwip/lwip-contrib.git/snapshot/lwip-contrib-${LWIP_CONTRIB_TAG}.tar.gz"
LWIP_CONTRIB_PKG_MIRROR_URL="https://files.phoesys.com/ports/lwip-contrib.tar.gz"

PREFIX_LWIP_TEST="${PREFIX_PROJECT}/phoenix-rtos-ports/lwip-tests"
PREFIX_LWIP_TEST_BUILD="${PREFIX_BUILD}/lwip-test"
PREFIX_LWIP_CONTRIB="${PREFIX_LWIP_TEST_BUILD}/contrib-lwip"
PREFIX_LWIP_CHECK="${PREFIX_LWIP_CONTRIB}/ports/unix/check"
PREFIX_LWIP_TEST_MARKERS="${PREFIX_LWIP_TEST_BUILD}/markers"

# Set variables used by Makefile
CHECK_H_PATH="${PREFIX_BUILD}/check/include"
CONTRIBDIR="${PREFIX_BUILD}/lwip-test/contrib-lwip"
MBEDTLSDIR="${PREFIX_BUILD}/mbedtls/mbedtls-2.28.0"
LWIPDIR="${PREFIX_PROJECT}/phoenix-rtos-lwip/lib-lwip/src"

export CHECK_H_PATH CONTRIBDIR MBEDTLSDIR LWIPDIR

#
# Download and unpack lwip-contrib
#
if [ ! -f "${PREFIX_LWIP_TEST}/lwip-contrib.tar.gz" ]; then
	if ! wget "$LWIP_CONTRIB_PKG_URL" -O "${PREFIX_LWIP_TEST}/lwip-contrib.tar.gz" --no-check-certificate; then
		wget "$LWIP_CONTRIB_PKG_MIRROR_URL" -P "$PREFIX_LWIP_TEST" --no-check-certificate
	fi
fi

mkdir -p "$PREFIX_LWIP_TEST_BUILD"
if [ ! -d "$PREFIX_LWIP_CONTRIB" ]; then
	tar xzf "${PREFIX_LWIP_TEST}/lwip-contrib.tar.gz" -C "$PREFIX_LWIP_TEST_BUILD" && \
	mv "${PREFIX_LWIP_TEST_BUILD}/lwip-contrib-$LWIP_CONTRIB_TAG" "${PREFIX_LWIP_TEST_BUILD}/contrib-lwip"
fi

#
# Apply patches
#
mkdir -p "$PREFIX_LWIP_TEST_MARKERS"
for patchfile in "$PREFIX_LWIP_TEST"/patch/*; do
	if [ ! -f "${PREFIX_LWIP_TEST_MARKERS}/$(basename "$patchfile").applied" ]; then
		echo "applying patch: $patchfile"
		patch -d "${PREFIX_LWIP_CONTRIB}/" -p1 < "$patchfile"
		touch "${PREFIX_LWIP_TEST_MARKERS}/$(basename "$patchfile").applied"
	fi
done

make check -C "$PREFIX_LWIP_CHECK"
"${CROSS}strip" -s "${PREFIX_LWIP_CHECK}/lwip_unittests" -o "${PREFIX_PROG_STRIPPED}/lwip_unittests"
cp -a "${PREFIX_LWIP_CHECK}/lwip_unittests" "${PREFIX_PROG}/lwip_unittests"

b_install "${PREFIX_PROG_STRIPPED}/lwip_unittests" /bin
