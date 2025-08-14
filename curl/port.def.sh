#!/usr/bin/env bash
:
#shellcheck disable=2034
{
	name="curl"
	version="7.64.1"

	source="https://curl.haxx.se/download/"
	archive_filename="${name}-${version}.tar.gz"
	archive_src_path="${name}-${version}/"

	size="4008103"
	sha256="432d3f466644b9416bc5b649d344116a753aeaa520c8beaf024a90cba9d3d35d"

	license="curl"
	license_file="COPYING"

	conflicts=""
	depends=""
	optional=""
}

p_common() {
	export PREFIX_CURL_INSTALL="$PREFIX_PORT_BUILD/install"
	return
}

p_prepare() {
	b_port_apply_patches "${PREFIX_PORT_WORKDIR}"

	if [ ! -f "$PREFIX_PORT_WORKDIR/config.status" ]; then
		( cd "$PREFIX_PORT_WORKDIR" && PKG_CONFIG="" "$PREFIX_PORT_WORKDIR/configure" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
			--host="${HOST}" --sbindir="$PREFIX_PROG" --disable-pthreads --disable-threaded-resolver \
			--disable-ipv6 --prefix="$PREFIX_CURL_INSTALL" --disable-ntlm-wb --without-zlib )
	fi
}

p_build() {
	make -C "$PREFIX_PORT_WORKDIR"
	make -C "$PREFIX_PORT_WORKDIR" install

	cp -a "$PREFIX_CURL_INSTALL/include/curl" "$PREFIX_H"
	cp -a "$PREFIX_CURL_INSTALL/lib/"* "$PREFIX_A"
	cp -a "$PREFIX_CURL_INSTALL/bin/curl" "$PREFIX_PROG/curl"
	$STRIP -o "$PREFIX_PROG_STRIPPED/curl" "$PREFIX_PROG/curl"
	b_install "$PREFIX_PORTS_INSTALL/curl" /usr/bin/
}
