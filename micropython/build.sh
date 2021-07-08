#!/bin/bash

set -e

UPYTH_VER="1.15"
UPYTH="micropython-${UPYTH_VER}"
DESTINATIONS_CFG="destinations.cfg"

PREFIX_UPYTH="${TOPDIR}/phoenix-rtos-ports/micropython"
PREFIX_UPYTH_BUILD="${PREFIX_BUILD}/micropython"
PREFIX_UPYTH_SRC=${PREFIX_UPYTH_BUILD}/${UPYTH}
PREFIX_UPYTH_CONFIG="${PREFIX_UPYTH}/${UPYTH}-config/"
PREFIX_UPYTH_MARKERS="$PREFIX_UPYTH_BUILD/markers/"
COPYPATH=""

b_log "Building micropython"

#
# Download and unpack
#
mkdir -p "$PREFIX_UPYTH_BUILD" "$PREFIX_UPYTH_MARKERS"
[ -f "$PREFIX_UPYTH/${UPYTH}.tar.xz" ] || wget https://github.com/micropython/micropython/releases/download/v${UPYTH_VER}/${UPYTH}.tar.xz -P "$PREFIX_UPYTH"
[ -d "${PREFIX_UPYTH_SRC}" ] || tar xf "$PREFIX_UPYTH/${UPYTH}.tar.xz" -C "$PREFIX_UPYTH_BUILD"


#
# Apply patches
#
for patchfile in "$PREFIX_UPYTH_CONFIG"/patches/*.patch; do
	if [ ! -f "$PREFIX_UPYTH_MARKERS/$(basename "$patchfile").applied" ]; then
		echo "applying patch: $patchfile"
		patch -d "$PREFIX_UPYTH_SRC" -p1 < "$patchfile"   # FIXME: should be -p1
		touch "$PREFIX_UPYTH_MARKERS/$(basename "$patchfile").applied"
	fi
done


#
# Copy config file/s
#
while read -r line; do 
	arr=($line)
	cp "$PREFIX_UPYTH_CONFIG"/files/"${arr[0]}" "$PREFIX_UPYTH_SRC"/"${arr[1]}" && echo "Copied config: ${arr[0]} -> ${arr[1]}"
	echo "$PREFIX_UPYTH_SRC"/"${arr[1]}"
done < "$PREFIX_UPYTH_CONFIG"/"$DESTINATIONS_CFG"


#
# Architecture specific flags/values
#
export PHOENIX_MATH_ABSENT="expm1 log1p asinh acosh atanh erf tgamma lgamma copysign __sin __cos __tan __signbit"
if [[ ${CROSS} == "arm-phoenix-" ]]
then
	UPYTH_STACKSZ="4096"
	UPYTH_HEAPSZ="32768"
	export CFLAGS_EXTRA="-DUPYTH_STACKSZ=${UPYTH_STACKSZ} -DUPYTH_HEAPSZ=${UPYTH_HEAPSZ} -nostdlib"
	export STRIPFLAGS_EXTRA="--strip-unneeded"
	export PHOENIX_PORT_FLAGS=${CFLAGS}
	export PHOENIX_PORT_LDFLAGS="-z stack-size=8192 --emit-relocs --gc-sections --pic-executable -nostdlib -L ${PREFIX_BUILD}/lib/"
elif [[ ${CROSS} == "i386-pc-phoenix-" ]]
then
	UPYTH_STACKSZ="32768"
	UPYTH_HEAPSZ="32768"
	export CFLAGS_EXTRA=" -DUPYTH_STACKSZ=${UPYTH_STACKSZ} -DUPYTH_HEAPSZ=${UPYTH_HEAPSZ} "
	export STRIPFLAGS_EXTRA="--strip-all"
else
	echo "Error: there is no micropython port for chosen architecture"
	exit 1
fi


#
# Build and install micropython binary
#
(cd "${PREFIX_UPYTH_SRC}/mpy-cross" && make all BUILD="${PREFIX_UPYTH_BUILD}" CROSS_COMPILE="${CROSS}")
(cd "${PREFIX_UPYTH_SRC}/ports/unix" && make all CROSS_COMPILE="${CROSS}")

cp -a "${PREFIX_UPYTH_SRC}/ports/unix/micropython" "$PREFIX_PROG"
"${CROSS}strip" "${STRIPFLAGS_EXTRA}" "$PREFIX_PROG/micropython" -o "$PREFIX_PROG_STRIPPED/micropython"
b_install "$PREFIX_PORTS_INSTALL/micropython" /bin/
