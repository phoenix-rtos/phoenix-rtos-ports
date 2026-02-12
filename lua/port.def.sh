#!/usr/bin/env bash
:
#shellcheck disable=2034
{
  name="lua"
  version="5.3.6"

  source="https://www.lua.org/ftp/"
  archive_filename="${name}-${version}.tar.gz"
  src_path="${name}-${version}/"

  size="303770"
  sha256="fc5fd69bb8736323f026672b1b7235da613d7177e72558893a0bdcd320466d60"

  license="MIT"
  license_file="src/lua.h"

  conflicts=""
  depends=""
  optional=""
}

p_prepare() {
  b_port_apply_patches "${PREFIX_PORT_WORKDIR}" "${version}"

  if [ "${USE_LUA_SAFE}" = "y" ]; then
    b_port_apply_patches "${PREFIX_PORT_WORKDIR}" "${version}/safe"
  fi
}

p_build() {
  : "${PORTS_LUA_CONFIG_DIR:=${PREFIX_PORT}}"

  # shellcheck disable=SC2206
  mycflags=(
    ${CFLAGS} # Split intended
    "-I${PORTS_LUA_CONFIG_DIR}"
  )

  if [ -n "${PORTS_LUA_BIN_CSTACK_SIZE}" ]; then
    LDFLAGS+=" -Wl,-z,stack-size=${PORTS_LUA_BIN_CSTACK_SIZE}"
  fi

  # FIXME: no out-of-tree building
  make -C "${PREFIX_PORT_WORKDIR}/src" MYCFLAGS="${mycflags[*]}" MYLDFLAGS="${LDFLAGS}"
  make -C "${PREFIX_PORT_WORKDIR}" install INSTALL_TOP="${PREFIX_BUILD}"

  cp -a "${PORTS_LUA_CONFIG_DIR}/luaconf_local.h" "${PREFIX_H}/"

  $STRIP -o "${PREFIX_PROG_STRIPPED}/lua" "${PREFIX_PROG}/lua"
  $STRIP -o "${PREFIX_PROG_STRIPPED}/luac" "${PREFIX_PROG}/luac"

  b_install "${PREFIX_PROG_TO_INSTALL}/lua" /usr/bin
  b_install "${PREFIX_PROG_TO_INSTALL}/luac" /usr/bin
}

p_build_test() {
  tests_version="${PORTS_LUA_TESTS_VERSION:-5.3.4}" # There is no 5.3.6 tag for tests
  tests_filename="lua-${tests_version}-tests.tar.gz"

  b_port_download "https://www.lua.org/tests/" "${tests_filename}"

  lua_test_dir="${PREFIX_PORT_WORKDIR}/${tests_version}-tests"
  if [ ! -d "${lua_test_dir}" ]; then
    echo "Extracting tests from ${tests_filename}"
    mkdir -p "${lua_test_dir}"
    tar -axf "${PREFIX_PORT}/${tests_filename}" --strip-components 1 -C "${lua_test_dir}"
  fi

  b_install "${lua_test_dir}"/*.lua /usr/share/lua/tests
}
