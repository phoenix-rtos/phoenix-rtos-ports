#!/bin/bash


#
#	FSMARK
#

b_log "Building fsmark"

PREFIX_FSBENCH="${TOPDIR}/phoenix-rtos-ports/fsbench"
PREFIX_FSBENCH_FSMARK_SRC="${PREFIX_FSBENCH}/fs_mark/"

# Convert ldflags to format recognizable by gcc, for example -q -> -Wl,-q
LDFLAGS=$(echo " ${LDFLAGS}" | sed "s/\s/,/g" | sed "s/,-/ -Wl,-/g")
export LDFLAGS
# export CFLAGS

#
# fs_mark compile & install
#
# git clone https://github.com/josefbacik/fs_mark.git $PREFIX_FSBENCH/fs_mark
(cd $PREFIX_FSBENCH_FSMARK_SRC && make clean && make all)
cp -a "${PREFIX_FSBENCH_FSMARK_SRC}/fs_mark" "$PREFIX_PROG_STRIPPED"
b_install "$PREFIX_FSBENCH_FSMARK_SRC/fs_mark" /bin/
