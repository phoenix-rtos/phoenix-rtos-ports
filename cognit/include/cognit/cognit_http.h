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
#ifndef COGNIT_HTTP_H
#define COGNIT_HTTP_H
/********************** INCLUDES **************************/
#include <stdint.h>
#include <stddef.h>
/***************** DEFINES AND MACROS *********************/
#define STR_PROTOCOL "http"

#define HTTP_METHOD_GET    "GET"
#define HTTP_METHOD_POST   "POST"
#define HTTP_METHOD_DELETE "DELETE"

#define MAX_HTTP_RESPONSE_SIZE     30000
#define MAX_HTTP_TRANSMISSION_SIZE 20000

/**************** TYPEDEFS AND STRUCTS ********************/

typedef struct
{
    uint8_t ui8_response_data_buffer[MAX_HTTP_RESPONSE_SIZE];
    size_t size;
    long l_http_code;
} http_response_t;

typedef struct
{
    http_response_t t_http_response;
    const char* c_url;
    const char* c_method;
    uint32_t ui32_timeout_ms;
    const char* c_username;
    const char* c_password;
} http_config_t;

typedef int (*send_http_req_cb_t)(const char* c_buffer, size_t size, http_config_t* config);
/******************* GLOBAL VARIABLES *********************/

/******************* PUBLIC METHODS ***********************/

/*******************************************************/ /**
 * @brief Send HTTP request
 * 
 * @param buffer Buffer with the JSON payload
 * @param size Size of the buffer
 * @param config HTTP client configuration
 * @return int 0 if success, -1 otherwise
***********************************************************/
int cognit_http_send(const char* c_buffer, size_t size, http_config_t* config);

/******************* PRIVATE METHODS ***********************/

#endif // COGNIT_HTTP_H