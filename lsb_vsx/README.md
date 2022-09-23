# LSB-VSX-2.0-1 (posix test suite) port for Phoenix-RTOS 

## Overview

LSB-VSX 2.0-1 is a beta release of this test suite for the POSIX.1 (including ISO C) coverage for the Linux Standard Base.
More information at: https://www.opengroup.org/testing/linux-test/lsb-vsx.html

In this port aspects requiring root privileges such as creating users and groups were deleted. We also run install and setup scripts twice.
Once for building tools needed to build tests (tests must be built on host and run on Phoenix-RTOS) and second for tools to execute tests.

## Before running

If you use Ubuntu 22.04 or newer you might need to install older byacc package. The package that worked fine with this test suite is
byacc_20140715-1build1_amd64.deb, which you can download from https://ubuntu.pkgs.org/20.04/ubuntu-universe-amd64/byacc_20140715-1build1_amd64.deb.html.
Next, just install the package using - sudo dpkg -i <package_name> command. It is worth mentioning that Ubuntu can automatically restore new version of
byacc so you will need to repeat installation.

## Running test suite

To build `lsb_vsx` tests please set `LONG_TEST=y` environment variable before calling `build.sh`.

In order to run the specific test please type in psh: `/bin/lsb_vsx_posix <test_name>`, for example:

/bin/lsb_vsx_posix T.isalnum

To run all test just type: `/bin/lsb_vsx_posix`.

All tests desirable should be run via test runner where output is conveniently parsed.

## Known issues

We omit installing loopdisc and pseudolanguages (it requires root privileges), which cause some test case to fail.

Many tests failed to compile due to libphoenix lacking some functions.

Header tests are disabled for now.

