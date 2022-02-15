# MicroPython port for Phoenix-RTOS 

## Overview 

This is a Micropython port for Phoenix-RTOS operating system. Currently it is working on following targets:

 * `ia32-generic`
 * `armv7m7-imxrt106x`

Currently we are working to bring this port onto other targets so this list is going to be expanded.

For building micropython we are using `unix` port provided by Micropython that is patched to suite Phoenix-RTOS system. All configuration and patches are stored inside `micropython-1.15-config/` directory and are implemented by `build.sh` script

## File structure

 * `build.sh` - building script that prepares environment and executes `make` related commands
 * `micropython-1.15.tar.xz` - (may be missing before first build) archieve with MicroPython codebase 
 * `micropython-1.15-config/`
   * `files/`
     * `001_mpconfigport.mk` - file containing Micropython port configuration of used third party libraries. As selection of those libraries can heavily impact the size of MicroPython binary size this configuration is stored as a whole file for easy management. During build it is copied into MicroPython codebase.
   * `patches/`
     * `01_libm_absent_libm.patch` - arithmetic functions missing in `libphoenix` substitution
     * `02_libm_ifdefs.patch` - math related functions missing in `libphoenix` substitution in MicroPython libraries
     * `03_mpy-cross_configs.patch` - minor cross compilator patch
     * `04_mpy-cross_Makefile.patch` - minor patches for cross compilator Makefile 
     * `05_os_configs.patch` - patches for internal port configurations
     * `06_os_main.patch` - incorporating stack and heap size of MicroPython
     * `07_os_Makefile.patch`- disabling `Werror` compilation flag and addition of arithmetic functions absent in `libphoenix`
     * `08_os_varia.patch` - missing defines corrections 
     * `09_py_ifdefs.patch` - math related functions missing in `libphoenix` substitution in MicroPython code

