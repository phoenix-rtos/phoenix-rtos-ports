# Makefile definitions for SPARC on Phoenix-RTOS

PLATFORM=sparc-phoenix
TOOLCHAIN=phoenix-gcc

#Flag: PLATFORM_DEFINES 
#	Use PLATFORM_DEFINES to set platform specific compiler flags. E.g. set the timer resolution to millisecs with TIMER_RES_DIVIDER=1000
#	Or add HAVE_PTHREAD_SETAFFINITY_NP=1 HAVE_PTHREAD_SELF=1 to enable affinity (must port the relevant functions in <mith/al/src/al_smp.c>.
PLATFORM_DEFINES = EE_BIG_ENDIAN=1
