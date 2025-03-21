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

b_port_apply_patches "${PREFIX_PORT_SRC}"

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
