#!/usr/bin/env bash
:
#shellcheck disable=2034
{
  ports_api=1

  name="heatshrink"
  version="0.4.1"

  source="https://github.com/atomicobject/heatshrink/archive/refs/tags/"
  archive_filename="${name}-${version}.tar.gz"
  src_path="${name}-${version}/"

  size="36945"
  sha256="7529a1c8ac501191ad470b166773364e66d9926aad632690c72c63a1dea7e9a6"

  license="ISC"
  license_file="LICENSE"

  conflicts=""
  depends=""
  optional=""

  supports="phoenix>=3.3"
}

p_prepare() {
  # Copy custom config.h
  if [ -n "$PORTS_HEATSHRINK_CONFIG_DIR" ] && [ -f "${PORTS_HEATSHRINK_CONFIG_DIR}/config.h" ]; then
    if ! cmp -s "${PORTS_HEATSHRINK_CONFIG_DIR}/config.h" "${PREFIX_PORT_WORKDIR}/heatshrink_config.h"; then
      echo "copying config.h"
      cp -a "${PORTS_HEATSHRINK_CONFIG_DIR}/config.h" "${PREFIX_PORT_WORKDIR}/heatshrink_config.h"
    fi
  fi
}

p_build() {
  make -C "${PREFIX_PORT_WORKDIR}" install PREFIX="$PREFIX_PORT_INSTALL" OPTIMIZE="-Os"

  cp -a "${PREFIX_PORT_INSTALL}/bin/"* "$PREFIX_PROG"
  $STRIP -o "$PREFIX_PROG_STRIPPED/heatshrink" "${PREFIX_PROG}/heatshrink"
  b_install "${PREFIX_PROG_TO_INSTALL}/heatshrink" /usr/bin
}
