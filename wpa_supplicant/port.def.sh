#!/usr/bin/env bash
:
#shellcheck disable=2034
{
  ports_api=1

  name="wpa_supplicant"
  version="2.9"

  source="https://w1.fi/releases/"
  archive_filename="${name}-${version}.tar.gz"
  src_path="${name}-${version}/"

  size="3231785"
  sha256="fcbdee7b4a64bea8177973299c8c824419c413ec2e3a95db63dd6a5dc3541f17"

  license="BSD-3-Clause"
  license_file="COPYING"

  conflicts=""
  depends="openssl>=1.1.1a"
  optional=""

  supports="phoenix>=3.3"
}

p_prepare() {
  b_port_apply_patches "${PREFIX_PORT_WORKDIR}"
}

p_build() {
  PREFIX_WPA_SUPPLICANT_INSTALL="${PREFIX_PORT_BUILD}/install"

  mkdir -p "$PREFIX_WPA_SUPPLICANT_INSTALL"

  # TODO: set up pkgconfig for versioned ports?
  openssl_dir=$(b_dependency_dir "openssl")
  CFLAGS+=" -I${openssl_dir}/include"
  LDFLAGS+=" -L${openssl_dir}/lib"

  (
    cd "${PREFIX_PORT_WORKDIR}/wpa_supplicant" &&
      cp -a "$PREFIX_PORT/config" .config &&
      make install DESTDIR="$PREFIX_WPA_SUPPLICANT_INSTALL" LIBDIR="/lib" INCDIR="/include" BINDIR="/bin"
  )

  cp -a "${PREFIX_WPA_SUPPLICANT_INSTALL}/bin/wpa_cli" "${PREFIX_PROG}/wpa_cli"
  cp -a "${PREFIX_WPA_SUPPLICANT_INSTALL}/bin/wpa_supplicant" "${PREFIX_PROG}/wpa_supplicant"

  $STRIP -o "${PREFIX_PROG_STRIPPED}/wpa_cli" "${PREFIX_PROG}/wpa_cli"
  $STRIP -o "${PREFIX_PROG_STRIPPED}/wpa_supplicant" "${PREFIX_PROG}/wpa_supplicant"

  b_install "${PREFIX_PROG_TO_INSTALL}/wpa_cli" /usr/bin
  b_install "${PREFIX_PROG_TO_INSTALL}/wpa_supplicant" /usr/bin
}
