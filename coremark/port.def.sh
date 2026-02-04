#!/usr/bin/env bash
:
#shellcheck disable=2034
{
  name="coremark"
  version="1.0"

  commit="d5fad6bd094899101a4e5fd53af7298160ced6ab"

  source="https://github.com/eembc/coremark/archive/"
  archive_filename="${commit}.tar.gz"
  src_path="${name}-${commit}/"

  size="402348"
  sha256="76f3b98fc940d277521023dc6e106551ef4a2180fa4c3da8cd5bf933aa494ef2"

  license="Apache-2.0"
  license_file="LICENSE.md"

  conflicts=""
  depends=""
  optional=""
}

p_prepare() {
  b_port_apply_patches "${PREFIX_PORT_WORKDIR}"
}

p_build() {
  export PORT_DIR="${PREFIX_PORT_WORKDIR}/phoenix"
  mkdir -p "${PORT_DIR}"

  cp -a "$PREFIX_PORT/core-portme.mak" "${PORT_DIR}/core_portme.mak"

  if [ -z ${PORTS_COREMARK_THREADS+x} ]; then
    PORTS_COREMARK_THREADS="1"
  fi

  export XCFLAGS="${CFLAGS} -DUSE_PTHREAD -DMULTITHREAD=${PORTS_COREMARK_THREADS} ${LDFLAGS}"

  # uses PORT_DIR, XCFLAGS
  make -C "${PREFIX_PORT_WORKDIR}" compile

  cp -a "$PREFIX_PORT_WORKDIR/coremark" "$PREFIX_PROG/coremark"
  $STRIP -o "${PREFIX_PROG_STRIPPED}/coremark" "${PREFIX_PROG}/coremark"
  b_install "$PREFIX_PROG_TO_INSTALL/coremark" /bin
}
