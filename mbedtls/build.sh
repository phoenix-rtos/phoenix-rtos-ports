#!/bin/bash

set -e

MBEDTLS_DIR="${TOPDIR}/phoenix-rtos-ports/mbedtls/mbedtls"
MBEDTLS_LIBDIR="${MBEDTLS_DIR}/library"

if ! [ -f "${PREFIX_BUILD}/lib/libmbedtls.a" ]; then
	(cd ${MBEDTLS_LIBDIR} && make all)
	cp "${MBEDTLS_LIBDIR}/libmbedcrypto.a" "${PREFIX_BUILD}/lib"
	cp "${MBEDTLS_LIBDIR}/libmbedtls.a" "${PREFIX_BUILD}/lib"
	cp "${MBEDTLS_LIBDIR}/libmbedx509.a" "${PREFIX_BUILD}/lib"
	cp -r "${MBEDTLS_DIR}/include/." "${PREFIX_BUILD}/include"
fi