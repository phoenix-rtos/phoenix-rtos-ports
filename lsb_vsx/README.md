# LSB-VSX-2.0-1 (posix test suite) port for Phoenix-RTOS 

## Overview

LSB-VSX 2.0-1 is a beta release of this test suite for the POSIX.1 (including ISO C) coverage for the Linux Standard Base. In our case we prefer to test rather POSIX than LSB, which has been set during configuration (test mode POSIX). More information at: https://www.opengroup.org/testing/linux-test/lsb-vsx.html .

All changes to original test suite resides in `lsb_vsx-2.0-1-config/files/patches` and are described below. Prompting user for configuration has been deleted and replaced with vsxparams.mk file which is used to edit the configuration of test suite before building.

Currently it is working on following targets:

 * `ia32-generic`

## File structure

 * `build.sh` - building script that prepares environment and executes subsequent building scripts
 * `lts_vsx-pcts2.0beta.tgz lts_vsx-pcts2.0beta2.tgz` - (may be missing before first build) archieve with LSB-VSX codebase
 * `lab_vsx-2.0-1-config/`
    * `files/`
     * `vsxparams.mk` - file containing LSB-VSX port configuration
     * `scen.bld` - list of tests to be built
     * `scenAll.bld` - list of all tests (not used during build)
   * `patches/`
     * `01_vmake.patch` :
        * move test executable to coresponding test macro folder (executing tool uses this location to find test binary)
     * `02_defines.patch` :
        * file with configuration included by makefiles
     * `03_getline.patch` :
        * getline previously declared in toolchains/i386-pc-phoenix/i386-pc-phoenix/i386-pc-phoenix/include/stdio.h
     * `04_userintf.patch` :
        * Phoenix-RTOS defines mount in the same manner as linux
     * `05_ngroups_max.patch` :
        * Phoenix-RTOS doesn't support groups - there is no NGROUPS_MAX constant value
     * `06_missing.patch` :
        * minor patches to compile without errors
     * `07_nonposix.patch` :
        * the suite cannot use any non-POSIX interfaces as they may not be available on the system. Therefore portable versions of those interfaces which are used are provided in this file. Features which this file contains are defined on linux are defined on PHEONIX-RTOS as well.
     * `08_vtools_Makefile_org.patch` :
        * y.tab.c is already created. no need to use yacc
     * `09_run_testsets.patch` :
        * Firstly binary files needed to execute tests are moved to temporary directory. Next host binaries are copied into appropriate place then building takes place. After that host binaries become redundant so we delte them. Lastly phoenix binaries are brought back in order to later execute tests on PHOENIX-RTOS.
     * `10_setup.patch` :
        * don't source profiles (unneeded namespace littering)
     * `11_setup_testsets.patch` :
        * delete invoking config scripts (this scripts install things that PHOENIX-RTOS doesn't support e.g. loopback device, pax, pseudo-languages)
        * don not change NSIG to _NSIG (on host change)
        * Run determining missing #defines and #includes script, create userintf.c and install_info (taken from config.sh)
        * Run install.sh script without root privileges
        * Parametrization of tetexec.cfg is only needed for PHOENIX-RTOS since tests are being run there
        * Run run_testsets without prompting user
     * `12_Makefile.patch` :
        * getting rid of building unnecessary features, only need tet3
     * `13_install.patch` :
        * I_PUSH stub to compile without errors
        * delete directory search routines and  variable argument lists tests because it is compiled using phoenix toolchains and run on host
        * rpcincs.h is created in config.sh, which is skipped so we cannot copy it (it is not used in POSIX mode of test suite)
     * `14_editcfg.patch` :
        * evaluate all shell variables in vsxparams.mk


## Running test suite

To build `lsb_vsx` tests please set `LONG_TEST=y` environment variable before calling `build.sh`.

In order to run the specific test please type in psh: `/bin/lsb_vsx_posix <test_name>`, for example:

/bin/lsb_vsx_posix T.isalnum

To run all test just type: `/bin/lsb_vsx_posix`.

All tests desirable should be run via test runner where output is conveniently parsed.

## Known issues

Some tests fails due to lack of pseudo-languages, because PHOENIX-RTOS doesn't support localedef utility.

Many tests failed to compile due to absence of some functions in libphoenix.

Header tests are disabled for now.

