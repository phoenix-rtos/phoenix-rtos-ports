#!/usr/bin/env bash
:
#shellcheck disable=2034
{
  ports_api=1

  name="azure_sdk"
  version="1.8.0"
  azure_version="lts_01_2022"

  src_path="${name}-${azure_version}"

  size="37747294"
  sha256="1654c9babeb51871efd33575132101c82f62e58856780cd7bb2369c2b154be89"

  license="MIT"
  license_file="LICENSE"

  conflicts=""
  depends="openssl>=1.1.1a curl>=7.64.1"
  optional=""

  supports="phoenix>=3.3"
}

install_binary() {
  local binary_name
  binary_name="$(basename "$1")"

  cp "$1" "${PREFIX_PROG}"
  $STRIP -o "$PREFIX_PROG_STRIPPED/${binary_name}" "${PREFIX_PROG}/${binary_name}"

  b_install "${PREFIX_PROG_TO_INSTALL}/${binary_name}" /bin
}

p_source() {
  if ! [ -d "${PREFIX_PORT_WORKDIR}" ]; then
    git clone -b "${azure_version}" --depth 1 https://github.com/Azure/azure-iot-sdk-c.git "${PREFIX_PORT_WORKDIR}"
    (cd "${PREFIX_PORT_WORKDIR}" && git submodule update --init)
  fi
}

p_prepare() {
  b_port_apply_patches "${PREFIX_PORT_WORKDIR}"

  # FIXME! This is a conditional patching and should be avoided

  if grep -q "armv7m7-imxrt106x" <<<"${TARGET}"; then
    b_port_apply_patches "${PREFIX_PORT_WORKDIR}" armv7m7-imxrt106x
  fi

  if [ "${LONG_TEST}" = "y" ]; then
    # WARN: submodules are outside of SHA256 checksum
    (cd "${PREFIX_PORT_WORKDIR}" && git submodule update --init --recursive)
    b_port_apply_patches "${PREFIX_PORT_WORKDIR}" long_test
  fi

  if [ -n "$AZURE_CONNECTION_STRING" ]; then
    sed -i "s/\"\[device connection string\]\"/\"${AZURE_CONNECTION_STRING}\"/g" \
      "${PREFIX_PORT_WORKDIR}/iothub_client/samples/iothub_ll_telemetry_sample/iothub_ll_telemetry_sample.c" &&
      echo "Connection string has been set properly."
  fi
}

p_build() {
  PHOENIX_SYSROOT="$("${CC}" "${CFLAGS}" --print-sysroot)"

  # FIXME: update azure to use newer cmake scripts
  export CMAKE_POLICY_VERSION_MINIMUM=3.5

  # Build (http and amqp protocols are currently not supported yet)
  # Treat Phoenix-RTOS as Linux and providing toolchain file was the most suitable solution
  (cd "${PREFIX_PORT_WORKDIR}/build_all/linux" && ./build.sh \
    --toolchain-file "${PREFIX_PORT}/toolchain-phoenix.cmake" -cl --sysroot="${PHOENIX_SYSROOT}" \
    --no-http --no-amqp)

  # Copy azure sdk libraries
  (cd "${PREFIX_PORT_WORKDIR}/cmake/" && cp "iothub_client/"*.a \
    "umqtt/libumqtt.a" "c-utility/libaziotsharedutil.a" "${PREFIX_A}")

  # Copy azure sdk headers
  (cd "${PREFIX_PORT_WORKDIR}/" && cp -r "iothub_client/inc/." \
    "deps/azure-macro-utils-c/inc/." "deps/umock-c/inc/." "c-utility/inc/." "${PREFIX_H}")

  install_binary "${PREFIX_PORT_WORKDIR}/cmake/iothub_client/samples/iothub_ll_telemetry_sample/iothub_ll_telemetry_sample"
}

p_build_test() {
  declare -A CUSTOM_DIRS=(
    [crtabstractions_ut]="crt_abstractions_ut_exe"
    [httpapicompact_ut]="httpapi_compact_ut_exe"
    [uniqueid_ut]="uniqueid_ut_linux_exe"
  )

  for dir in "${PREFIX_PORT_WORKDIR}/cmake/c-utility/tests"/*; do
    DIR_NAME="$(basename "$dir")"

    # There may be other files, which are not test directories - skip them
    grep -q "_ut" <<<"$dir" || continue

    if [ -n "${CUSTOM_DIRS[$DIR_NAME]}" ]; then
      test_executable="${CUSTOM_DIRS[$DIR_NAME]}"
    else
      test_executable="${DIR_NAME}_exe"
    fi

    install_binary "$dir/$test_executable"
  done
}
