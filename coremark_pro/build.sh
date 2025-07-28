#!/usr/bin/env bash

set -e

commit="4832cc67b0926c7a80a4b7ce0ce00f4640ea6bec"
archive_filename="coremark-pro-${commit}"
b_port_download "https://codeload.github.com/eembc/coremark-pro/tar.gz/" "${archive_filename}.tar.gz" "${commit}"

PREFIX_PORT_SRC="${PREFIX_PORT_BUILD}/${commit}"

if ! [ -d "${PREFIX_PORT_SRC}" ]; then
	echo "Extracting sources from ${archive_filename}.tar.gz"
	mkdir -p "${PREFIX_PORT_SRC}"
	tar xzf "${PREFIX_PORT}/${archive_filename}.tar.gz" --strip-components 1 -C "${PREFIX_PORT_SRC}"
fi

patch_dir="${PREFIX_PORT}/patches/"
marker_dir="${PREFIX_PORT_BUILD}/markers/"
if [ -d "${patch_dir}" ]; then
	mkdir -p "${marker_dir}"
fi

# Restores the initial value of nullglob option upon function return
trap "$(shopt -p nullglob)" RETURN
shopt -s nullglob

if [ "$DISABLE_PARSER_BENCHMARK" == "y" ]; then
	patchfile="${patch_dir}"/01-small_stack_size.patch
else
	patchfile="${patch_dir}"/01-stack_size.patch
fi

if [ ! -f "${marker_dir}/$(basename "${patchfile}").applied" ]; then
	echo "applying patch: ${patchfile}"
	patch -d "${PREFIX_PORT_SRC}" -p1 < "${patchfile}"
	touch "${marker_dir}/$(basename "${patchfile}").applied"
fi

cp -a "${PREFIX_PORT}/make/"*.mak "${PREFIX_PORT_SRC}/util/make/"

cd "${PREFIX_PORT_SRC}"

# Build coremark
make TARGET="${HOST}" build
# Remove empty data directory (not needed)
rmdir "${PREFIX_PORT_SRC}/builds/${HOST}/phoenix-gcc/bin/data"
mkdir -p "${PREFIX_PROG}/coremark-pro"
cp -a "${PREFIX_PORT_SRC}/builds/${HOST}/phoenix-gcc/bin/"* "${PREFIX_PROG}/coremark-pro/"
mkdir -p "${PREFIX_PROG_STRIPPED}/coremark-pro"

# Strip the binaries
for bin in "${PREFIX_PROG}/coremark-pro/"*; do
	$STRIP -o "${PREFIX_PROG_STRIPPED}/coremark-pro/$(basename "$bin")" "$bin"
done

# Install the binaries
for bin in "${PREFIX_PROG_STRIPPED}/coremark-pro/"*; do
	b_install "$bin" /usr/bin/coremark-pro
done
