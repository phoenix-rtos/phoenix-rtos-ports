#!/bin/bash


#
#	FSTEST
#

PREFIX_FSBENCH="${TOPDIR}/phoenix-rtos-ports/fsbench"
PREFIX_FSBENCH_FSTEST_SRC="${PREFIX_FSBENCH}/fstest/"
PREFIX_FSBENCH_FSMARK_SRC="${PREFIX_FSBENCH}/fs_mark/"

#
# fstest compile & install
#
# #git clone https://github.com/zfsonlinux/fstest.git $PREFIX_FSBENCH/fstest
(cd $PREFIX_FSBENCH_FSTEST_SRC && make clean && make all)
cp -a "${PREFIX_FSBENCH_FSTEST_SRC}/fstest" "$PREFIX_PROG_STRIPPED"
b_install "$PREFIX_PORTS_INSTALL/fstest" /bin/

#
# fs_mark compile & install
#
# #git clone https://github.com/josefbacik/fs_mark.git $PREFIX_FSBENCH/fs_mark
(cd $PREFIX_FSBENCH_FSMARK_SRC && make clean && make all)
cp -a "${PREFIX_FSBENCH_FSMARK_SRC}/fs_mark" "$PREFIX_PROG_STRIPPED"
b_install "$PREFIX_FSBENCH_FSMARK_SRC/fs_mark" /bin/
