#!/usr/bin/env bash
:
#shellcheck disable=2034
{
  name="mbedtls"
  version="2.28.0"

  source="https://github.com/Mbed-TLS/mbedtls/archive/"
  archive_filename="v${version}.tar.gz"
  src_path="${name}-${version}/"

  size="3711231"
  sha256="6519579b836ed78cc549375c7c18b111df5717e86ca0eeff4cb64b2674f424cc"

  license="Apache-2.0 OR GPL-2.0-or-later"
  license_file="LICENSE"

  conflicts=""
  depends=""
  optional=""
}

p_common() {
  export PREFIX_MBEDTLS_DESTDIR="${PREFIX_PORT_BUILD}/root/"
}

p_prepare() {
  b_port_apply_patches "${PREFIX_PORT_WORKDIR}"

  # Copy custom config.h
  if [ -n "$PORTS_MBEDTLS_CONFIG_DIR" ] && [ -f "${PORTS_MBEDTLS_CONFIG_DIR}/config.h" ]; then
    if ! cmp -s "${PORTS_MBEDTLS_CONFIG_DIR}/config.h" "${PREFIX_PORT_WORKDIR}/include/mbedtls/config.h"; then
      echo "copying config.h"
      cp -a "${PORTS_MBEDTLS_CONFIG_DIR}/config.h" "${PREFIX_PORT_WORKDIR}/include/mbedtls/config.h"
    fi
  fi
}

p_build() {
  # Flag that can be checked in makefiles
  export phoenix=1

  # Build mbedtls without tests
  (cd "${PREFIX_PORT_WORKDIR}" && make install no_test DESTDIR="$PREFIX_MBEDTLS_DESTDIR")

  # Copy built libraries and mbedtls header files to `lib` and `include` dirs
  cp -a "${PREFIX_MBEDTLS_DESTDIR}/lib"/* "${PREFIX_A}"
  cp -a "${PREFIX_MBEDTLS_DESTDIR}/include"/* "${PREFIX_H}"
}

p_build_test() {
  PREFIX_MBEDTLS_TESTS="${PREFIX_PORT_WORKDIR}/tests"

  (cd "${PREFIX_PORT_WORKDIR}" && make tests)

  mkdir -p "${PREFIX_ROOTFS}/mbedtls_test_configs/"

  for file in "${PREFIX_MBEDTLS_TESTS}"/*; do
    # Each .datax file is related to a test with the same name
    if [[ $file == *\.datax ]]; then
      config_filename="$(basename "${file}")"
      test_executable=${config_filename::-6}
      # test_suite_asn1parse have cases that assume `long` type is 64bit long, which isn't True for some Phoenix-RTOS targets
      if ! [ "${test_executable}" = "test_suite_asn1parse" ]; then
        cp -a "${file}" "${PREFIX_ROOTFS}/mbedtls_test_configs/"
        # use intermediate dir for stripped binaries to use b_install
        $STRIP -o "${PREFIX_MBEDTLS_DESTDIR}/bin/${test_executable}" "$PREFIX_MBEDTLS_TESTS/${test_executable}"
        b_install "${PREFIX_MBEDTLS_DESTDIR}/bin/${test_executable}" /bin/
      fi
    fi
  done
  # Files required for some tests
  cp -ar "${PREFIX_PORT_WORKDIR}/tests/data_files" "${PREFIX_ROOTFS}"
}
