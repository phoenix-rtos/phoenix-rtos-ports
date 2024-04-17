/*******************************************************/ /***
*	\file  ${file_name}
*	\brief HTTP client
*
*	Compiler  :  \n
*	Copyright : Samuel Pérez \n
*	Target    :  \n
*
*	\version $(date) ${user} $(remarks)
***********************************************************/
#ifndef IP_UTILS_H
#define IP_UTILS_H
/********************** INCLUDES **************************/
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>

/***************** DEFINES AND MACROS *********************/
#define IN6ADDRSZ 16
#define INADDRSZ  4
#define INT16SZ   2

#define IP_V4 4
#define IP_V6 6
/**************** TYPEDEFS AND STRUCTS ********************/

/******************* GLOBAL VARIABLES *********************/

/******************* PUBLIC METHODS ***********************/

/*******************************************************/ /**
 * @brief Get the ip version object
 * 
 * @param ip String with the ip address
 * @return int 4 if the ip is v4, 6 if the ip is v6, 0 if the ip is invalid
***********************************************************/
int get_ip_version(const char* ip);

/******************* PRIVATE METHODS ***********************/

#endif // IP_UTILS_H