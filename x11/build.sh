#!/usr/bin/env bash

set -e

# FIXME: libxcb fails to find pkgconfig without this export, why?
export PKG_CONFIG_PATH="${PREFIX_A}/pkgconfig"


inner_log() {
	echo -e "$1"
}


# extract_sources(dest_dir_path)
extract_sources() {
	local destdir="${1:?destdir missing}"

	if [ ! -d "${destdir}" ]; then
		echo "Extracting sources from ${archive_filename}"
		mkdir -p "${destdir}"
		tar -axf "${PREFIX_PORT}/${archive_filename}" --strip-components 1 -C "${destdir}"
	fi
}


exec_configure_no_reconf() {
	# set LIBBSD_LIBS/LIBBSD_CFLAGS to whitespace so that '-lbsd' is not included in build dependencies
	# penultimate line is a shotgun (some builds support these, some don't)
	(cd "${PREFIX_PORT_SRC}" &&
		"${PREFIX_PORT_SRC}/configure" CFLAGS="-DMALLOC_0_RETURNS_NULL ${CFLAGS}" LDFLAGS="${LDFLAGS}" \
		LIBBSD_LIBS=" " LIBBSD_CFLAGS=" " \
		--host="${HOST%phoenix}linux" --target="${HOST%phoenix}linux" \
		--bindir="${PREFIX_PROG}" --sbindir="${PREFIX_PROG}" \
		--libdir="${PREFIX_A}" --includedir="${PREFIX_H}" --datarootdir="${PREFIX_A}" \
		--disable-shared --enable-static --disable-specs --enable-silent-rules --disable-devel-docs --disable-docs \
		"${@}"
	)
}


# exec_configure([configure_opts])
exec_configure() {
	(cd "${PREFIX_PORT_SRC}" &&
		autoreconf -vfi && # reconf, as there may be patches to configure.ac
		exec_configure_no_reconf "${@}"
	)
}


# md5_checksum(dir)
#  Returns md5 checksum of a given directory
md5_checksum() {
	local dir="${1:?dir missing}"
	tar cfP - "${dir}" | md5sum
}


# port_cleanup(appname)
port_cleanup() {
	local appname="${1:?appname missing}"
	rm -rf "${PREFIX_PORT_SRC}"
	rm -rf "${PREFIX_PORT_BUILD}/markers/${appname}"
}


# should_reconfigure(appname)
#  Reconfigures appname build project if patches changed
should_reconfigure() {
	local appname="${1:?appname missing}"

	local marker_dir="${PREFIX_PORT_BUILD}/markers/${appname}"
	local patch_dir="${PREFIX_PORT}/patches/${appname}"
	local built_md5_path="${marker_dir}/built.md5"

	if [ ! -f "${built_md5_path}" ]; then
		inner_log "Patch and configure ${appname} from scratch"
		port_cleanup "${appname}"

		true
	else
		patch_md5=$(md5_checksum "${patch_dir}")
		if [ "${patch_md5}" = "$(cat "${built_md5_path}")" ]; then
			inner_log "${appname} up-to-date, not reconfiguring"
			false
		else
			inner_log "Cleaning ${appname} up after previous patch set"
			port_cleanup "${appname}"

			inner_log "Patch and reconfigure ${appname} from scratch"
			true
		fi
	fi
}


# mark_as_configured(appname)
#  Marks autotools in given appname project as configured
mark_as_configured() {
	local appname="${1:?appname missing}"
	local marker_dir="${PREFIX_PORT_BUILD}/markers/${appname}"
	local patch_dir="${PREFIX_PORT}/patches/${appname}"
	local built_md5_path="${marker_dir}/built.md5"

	mkdir -p "${marker_dir}"
	md5_checksum "${patch_dir}" > "${built_md5_path}"
}


build_xorg_pkg() {
	local type="${1:?type missing}"
	local pkgname="${2:?pkgname missing}"
	local version="${3:?version missing}"
	local configure_opts=${*:4}

	b_log "x11: building ${pkgname}"

	local archive_filename="${pkgname}-${version}.tar.gz"

	PREFIX_PORT_SRC="${PREFIX_PORT_BUILD}/${pkgname}"

	b_port_download "https://www.x.org/archive/individual/${type}/" "${archive_filename}"

	if should_reconfigure "${pkgname}"; then
		extract_sources "${PREFIX_PORT_SRC}"

		b_port_apply_patches "${PREFIX_PORT_SRC}" "${pkgname}"

		if [ ! -f "${PREFIX_PORT_SRC}/config.status" ]; then
			# shellcheck disable=SC2086
			exec_configure ${configure_opts}
		fi

		mark_as_configured "${pkgname}"
	fi

	make -C "${PREFIX_PORT_SRC}"
	make -C "${PREFIX_PORT_SRC}" install
}


build_a_lib() {
	local pkgname="$1"
	local version="$2"
	local configure_opts=${*:3}

	build_xorg_pkg "lib" "${pkgname}" "${version}" "${configure_opts}"

	if [ "${pkgname}" = "libX11" ]; then
		b_install "${PREFIX_A}/X11/locale/compose.dir" /usr/lib/X11/locale
		b_install "${PREFIX_A}/X11/locale/locale.dir" /usr/lib/X11/locale
		b_install "${PREFIX_A}/X11/locale/locale.alias" /usr/lib/X11/locale
		b_install "${PREFIX_A}/X11/locale/C/"* /usr/lib/X11/locale/C
	fi
}


build_tinyx() {
	b_log "x11: building tinyx (xserver)"

	local pkgname="tinyx"
	local ref="eed4902840732f170a7020cedb381017de99f2e6"
	local archive_filename="${ref}.tar.gz"

	PREFIX_PORT_SRC="${PREFIX_PORT_BUILD}/${pkgname}"
	b_port_download "https://github.com/tinycorelinux/tinyx/archive/" "${archive_filename}"

	if should_reconfigure "${pkgname}"; then
		extract_sources "${PREFIX_PORT_SRC}"

		if [ ! -d "${PREFIX_PORT_SRC}/kdrive/phoenix/" ]; then
			mkdir -p "${PREFIX_PORT_SRC}/kdrive/phoenix/"
			cp "${PREFIX_PORT_SRC}/kdrive/linux/mouse.c" "${PREFIX_PORT_SRC}/kdrive/phoenix/mouse.c"
		fi

		b_port_apply_patches "${PREFIX_PORT_SRC}" "${pkgname}"

		if [ ! -f "${PREFIX_PORT_SRC}/config.status" ]; then
			exec_configure --disable-xres --disable-screensaver --disable-xdmcp \
				--disable-dpms --disable-xf86bigfont --disable-xdm-auth-1 \
				--disable-dbe --host="${HOST}" \
				--with-default-font-path="built-ins" # otherwise won't find 'fixed'. libxfont/src/fontfile.c:FontFileNameCheck()

			# (brutally) force static compilation in generated Makefiles
			# FIXME do it properly by patching configure.ac instead?
			find . -name 'Makefile' -print0 | xargs -0 sed -i 's/ -lz/ -l:libz.a/g;s/ -lXfont/ -l:libXfont.a/g;s/ -lfontenc/ -l:libfontenc.a/g;s/-lm//g'
		fi
		mark_as_configured "${pkgname}"
	fi

	make -C "${PREFIX_PORT_SRC}"

	${STRIP} -o "${PREFIX_PROG_STRIPPED}/Xfbdev" "${PREFIX_PORT_SRC}/kdrive/fbdev/Xfbdev"
	cp -a "${PREFIX_PORT_SRC}/kdrive/fbdev/Xfbdev" "${PREFIX_PROG}/Xfbdev"

	b_install "${PREFIX_PORTS_INSTALL}/Xfbdev" /usr/bin
}


build_x11_app() {
	local appname="$1"
	local version="$2"
	local configure_opts=${*:3}

	b_log "x11: building ${appname}"

	local archive_filename="${appname}-${version}.tar.gz"

	PREFIX_PORT_SRC="${PREFIX_PORT_BUILD}/${appname}"

	b_port_download "https://www.x.org/archive/individual/app/" "${archive_filename}"

	if should_reconfigure "${appname}"; then
		extract_sources "${PREFIX_PORT_SRC}"

		b_port_apply_patches "${PREFIX_PORT_SRC}" "${appname}"

		if [ ! -f "${PREFIX_PORT_SRC}/config.status" ]; then
			# shellcheck disable=SC2086
			exec_configure ${configure_opts}
		fi

		# FIXME: this is brutal, see build_tinyx note
		sedexpr='s/ -lXaw7/ -l:libXaw7.a/g;s/ -lXt/ -l:libXt.a -l:libXpm.a/g;'
		sedexpr+='s/ -lX11/ -l:libXcursor.a -l:libXfixes.a -l:libXrender.a -l:libXmu.a -l:libXext.a -l:libSM.a -l:libICE.a -l:libX11.a -l:libxcb.a -l:libXau.a/g;'
		sedexpr+='s/ -lXmuu/ -l:libXmuu.a/g;s/ -lXcursor//g;'
		sedexpr+='s/ -lXft/ -l:libXft.a -l:libfontconfig.a -l:libexpat.a/g;'

		find . -name 'Makefile' -print0 | xargs -0 sed -i "${sedexpr}"

		mark_as_configured "${appname}"
	fi

	make -C "${PREFIX_PORT_SRC}"

	binpath="${PREFIX_PORT_SRC}/${appname}"
	if [ ! -f "${binpath}" ]; then
		binpath="${PREFIX_PORT_SRC}/src/${appname}"
	fi
	${STRIP} -o "${PREFIX_PROG_STRIPPED}/${appname}" "${binpath}"

	b_install "${PREFIX_PORTS_INSTALL}/${appname}" /usr/bin
}


build_suckless() {
	local appname="$1"
	local version="$2"

	b_log "x11: building ${appname}"

	local archive_filename="${appname}-${version}.tar.gz"
	PREFIX_PORT_SRC="${PREFIX_PORT_BUILD}/${appname}"

	b_port_download "https://dl.suckless.org/${appname}/" "${archive_filename}"

	extract_sources "${PREFIX_PORT_SRC}"

	b_port_apply_patches "${PREFIX_PORT_SRC}" "${appname}"

	make -C "${PREFIX_PORT_SRC}" PREFIX="${PREFIX_PORT_BUILD}"

	# TODO: termcap/terminfo
	# if [ ${appname} == "st" ]; then
	#		cp -a "${PREFIX_PORT_SRC}/st.info" "${PREFIX_PORT_SRC}/termcap"
	#		b_install "${PREFIX_PORT_SRC}/st.info" /etc/termcap
	# fi

	${STRIP} -o "${PREFIX_PROG_STRIPPED}/${appname}" "${PREFIX_PORT_SRC}/${appname}"

	b_install "${PREFIX_PORTS_INSTALL}/${appname}" /usr/bin
}


build_xbill() {
	local appname="xbill"
	local version="2.1"

	b_log "x11: building ${appname}"

	local archive_filename="${appname}-${version}.tar.gz"
	PREFIX_PORT_SRC="${PREFIX_PORT_BUILD}/${appname}/${version}"

	b_port_download "http://www.xbill.org/download/" "${archive_filename}"

	if should_reconfigure "${appname}/${version}"; then
		extract_sources "${PREFIX_PORT_SRC}"

		b_port_apply_patches "${PREFIX_PORT_SRC}" "${appname}/${version}"

		if [ ! -f "${PREFIX_PORT_SRC}/config.status" ]; then
			exec_configure --datadir="/usr/share/"
		fi

		# FIXME: this is brutal, see build_tinyx note
		sedexpr='s/ -lXaw/ -l:libXaw7.a/g;s/ -lXt/ -l:libXt.a -l:libXpm.a/g;'
		sedexpr+='s/ -lX11/ -l:libXcursor.a -l:libXfixes.a -l:libXrender.a -l:libXmu.a -l:libXext.a -l:libSM.a -l:libICE.a -l:libX11.a -l:libxcb.a -l:libXau.a/g;'
		sedexpr+='s/ -lXmuu/ -l:libXmuu.a/g;s/ -lXcursor//g;'
		sedexpr+='s/ -lXft/ -l:libXft.a -l:libfontconfig.a -l:libexpat.a/g;'

		find . -name 'Makefile' -print0 | xargs -0 sed -i "${sedexpr}"

		mark_as_configured "${appname}/${version}"
	fi

	make -C "${PREFIX_PORT_SRC}" PREFIX="${PREFIX_PORT_BUILD}"

	${STRIP} -o "${PREFIX_PROG_STRIPPED}/${appname}" "${PREFIX_PORT_SRC}/${appname}"

	b_install "${PREFIX_PORT_SRC}/pixmaps"/* /usr/share/xbill/pixmaps/
	b_install "${PREFIX_PORT_SRC}/bitmaps"/* /usr/share/xbill/bitmaps/
	b_install "${PREFIX_PORTS_INSTALL}/${appname}" /usr/bin
}


build_freetype() {
	local appname="freetype"
	local version="2.13.3"

	b_log "x11: building ${appname}"

	local archive_filename="${appname}-${version}.tar.gz"
	PREFIX_PORT_SRC="${PREFIX_PORT_BUILD}/${appname}/${version}"

	b_port_download "https://download.savannah.gnu.org/releases/${appname}/" "${archive_filename}"

	extract_sources "${PREFIX_PORT_SRC}"

	b_port_apply_patches "${PREFIX_PORT_SRC}" "${appname}/${version}"

	make -C "${PREFIX_PORT_SRC}" PREFIX="${PREFIX_PORT_BUILD}" PLATFORM="unix" \
		CFG="--host=\"${HOST%phoenix}linux\" --bindir=\"${PREFIX_PROG}\" --sbindir=\"${PREFIX_PROG}\" \
		 --libdir=\"${PREFIX_A}\" --includedir=\"${PREFIX_H}\" \
		 --prefix=\"${PREFIX_PORT_INSTALL}\" --datarootdir=\"${PREFIX_A}\" \
		 --disable-shared --enable-static --enable-silent-rules --without-brotli --without-harfbuzz" \
		CFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS}"
	make -C "${PREFIX_PORT_SRC}" PREFIX="${PREFIX_PORT_BUILD}" install
}


build_imlib2() {
	local appname="imlib2"
	local version="1.12.3"

	b_log "x11: building ${appname}"

	local archive_filename="${version}.tar.gz"
	PREFIX_PORT_SRC="${PREFIX_PORT_BUILD}/${appname}"

	# TODO find a better source/mirror - wanted to use git.enlightement.org, but their
	# tar.gz downloading seems to be dead :(
	b_port_download "https://github.com/gijsbers/imlib2/archive/refs/tags/" "${archive_filename}"

	if should_reconfigure "${appname}"; then
		extract_sources "${PREFIX_PORT_SRC}"

		# This is a workaround that adds the contents of png loader module to the
		# loaders.c that is then patched with 02-loaders-no-dl.patch. It is here
		# until dynamic library support gets merged
		cat "${PREFIX_PORT_SRC}/src/modules/loaders/loader_png.c" >> "${PREFIX_PORT_SRC}/src/lib/loaders.c"

		b_port_apply_patches "${PREFIX_PORT_SRC}" "${appname}"

		if [ ! -f "${PREFIX_PORT_SRC}/config.status" ]; then
			exec_configure --x-includes="${PREFIX_H}/X11" --x-libraries="${PREFIX_A}"
		fi

		mark_as_configured "${appname}"
	fi

	make -C "${PREFIX_PORT_SRC}" PREFIX="${PREFIX_PORT_BUILD}" LDFLAGS="${LDFLAGS} -l:libpng.a"
	make -C "${PREFIX_PORT_SRC}" PREFIX="${PREFIX_PORT_BUILD}" install
}


build_feh() {
	local appname="feh"
	local version="3.10.3"

	b_log "png: building ${appname}"

	local archive_filename="${version}.tar.gz"
	PREFIX_PORT_SRC="${PREFIX_PORT_BUILD}/${appname}"

	b_port_download "https://github.com/derf/feh/archive/refs/tags/" "${archive_filename}"

	extract_sources "${PREFIX_PORT_SRC}"

	b_port_apply_patches "${PREFIX_PORT_SRC}" "${appname}"

	mkdir -p "${PREFIX_PORT_SRC}/out"

	make -C "${PREFIX_PORT_SRC}" PREFIX="${PREFIX_PORT_SRC}/out" xinerama=0 curl=0
	make -C "${PREFIX_PORT_SRC}" PREFIX="${PREFIX_PORT_SRC}/out" install

	${STRIP} -o "${PREFIX_PROG_STRIPPED}/${appname}" "${PREFIX_PORT_SRC}/out/bin/${appname}"
	b_install "${PREFIX_PORTS_INSTALL}/${appname}" /usr/bin
}


build_expat() {
	local libname="expat"
	local version="2.6.4"

	b_log "x11: building ${libname}"

	local archive_filename="${libname}-${version}.tar.gz"

	PREFIX_PORT_SRC="${PREFIX_PORT_BUILD}/${libname}"

	# NOTE: URL depends on ${version} (FIXME)
	b_port_download "https://github.com/libexpat/libexpat/releases/download/R_2_6_4/" "${archive_filename}"

	if should_reconfigure "${libname}"; then
		extract_sources "${PREFIX_PORT_SRC}"

		b_port_apply_patches "${PREFIX_PORT_SRC}" "${libname}"

		if [ ! -f "${PREFIX_PORT_SRC}/config.status" ]; then
			exec_configure_no_reconf
		fi

		mark_as_configured "${libname}"
	fi

	make -C "${PREFIX_PORT_SRC}"
	make -C "${PREFIX_PORT_SRC}" install
}


build_fontconfig() {
	local libname="fontconfig"
	local version="2.15.0"

	b_log "x11: building ${libname}"

	local archive_filename="${libname}-${version}.tar.gz"

	PREFIX_PORT_SRC="${PREFIX_PORT_BUILD}/${libname}"

	b_port_download "https://www.freedesktop.org/software/fontconfig/release/" "${archive_filename}"

	if should_reconfigure "${libname}"; then
		extract_sources "${PREFIX_PORT_SRC}"

		b_port_apply_patches "${PREFIX_PORT_SRC}" "${libname}"

		if [ ! -f "${PREFIX_PORT_SRC}/config.status" ]; then
			exec_configure_no_reconf --prefix="${PREFIX_PORT_SRC}" --localstatedir="/var"
		fi

		mark_as_configured "${libname}"
	fi

	make -C "${PREFIX_PORT_SRC}"
	make -C "${PREFIX_PORT_SRC}" install

	b_install "${PREFIX_PORT_SRC}/fc-list/fc-list" /usr/bin
}


install_dejavu() {
	b_log "x11: installing dejavu fonts"

	local pkgname="dejavu-fonts-ttf"
	local version="2.37"

	local archive_filename="${pkgname}-${version}.tar.bz2"

	PREFIX_PORT_SRC="${PREFIX_PORT_BUILD}/${pkgname}"

	b_port_download "https://github.com/dejavu-fonts/dejavu-fonts/releases/download/version_2_37/" ${archive_filename}

	extract_sources "${PREFIX_PORT_SRC}"

	b_install "${PREFIX_PORT_SRC}/ttf/DejaVuSansMono.ttf" /usr/share/fonts
	b_install "${PREFIX_PORT_SRC}/ttf/DejaVuSansMono-Bold.ttf" /usr/share/fonts
}


#
# Build xlib (call ordering is important here)
#

build_xorg_pkg    proto       xorgproto   2023.1  --disable-specs
build_xorg_pkg    proto       xextproto   7.3.0   --disable-specs
build_xorg_pkg    data        xbitmaps    1.1.2
build_a_lib       libXau      1.0.12

# FIXME: set pyexecdir instead of shotgunning prefix
build_xorg_pkg    xcb         xcb-proto   1.17.0  --prefix="${PREFIX_PORT_BUILD}/xcb-proto/1.17.0" --libdir="${PREFIX_A}" --includedir="${PREFIX_H}" --datadir="${PREFIX_H}"

build_xorg_pkg    xcb         libxcb      1.17.0

build_a_lib       xtrans      1.5.2

build_a_lib       libX11      1.8

build_a_lib       libXext     1.3.6

build_a_lib       libfontenc  1.1.8
build_freetype
build_a_lib       libXfont    1.5.4   # used by tinyx (sigh)
build_a_lib       libXfont2   2.0.7   # requires libpng

build_a_lib       libICE      1.1.2
build_a_lib       libSM       1.0.0
build_a_lib       libXt       1.3.1

build_a_lib       libXmu      1.2.1
build_a_lib       libXrender  0.9.12
build_a_lib       libXfixes   6.0.1
build_a_lib       libXcursor  1.2.3

build_a_lib       libXpm      3.5.17
build_a_lib       libXaw      1.0.16

build_expat
build_fontconfig  # requires gperf on host
build_a_lib       libXft      2.3.8

install_dejavu

#
# Finally build xserver
#
build_tinyx

#
# Build client apps
#

# Window managers
build_suckless    dwm         5.1
build_x11_app     twm         1.0.12 # requires yacc

build_suckless    st          0.7

build_x11_app     ico         1.0.4 # requires gettext
build_x11_app     xmessage    1.0.7

build_x11_app     xclock      1.1.1   --without-xft --without-xkb

build_x11_app     xeyes       1.1.1
build_x11_app     xsetroot    1.1.1
build_x11_app     xinit       1.3.3
build_x11_app     xrdb        1.2.2
build_x11_app     xgc         1.0.6

# Fun stuff
build_xbill

# Image viewer
build_imlib2      # requires freetype
build_feh
