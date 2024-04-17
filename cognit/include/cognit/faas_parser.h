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
#ifndef FAAS_PARSER_H
#define FAAS_PARSER_H
/********************** INCLUDES **************************/
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <cognit/serverless_runtime_client.h>
/***************** DEFINES AND MACROS *********************/
#define JSON_ERR_CODE_OK           0
#define JSON_ERR_CODE_INVALID_JSON -1
// Macro to include headers
#define INCLUDE_HEADERS(...) \
    (#__VA_ARGS__)

// Macro to create a string from a function
#define FUNC_TO_STR(name, fn) \
    fn const char name##_str[] = #fn;
#define MAX_PARAMS 5
/**************** TYPEDEFS AND STRUCTS ********************/
typedef struct
{
    char* type; // Float, int, char, bool
    char* var_name;
    char* value;  // Coded b64
    char mode[4]; // "IN" or "OUT"
} param_t;

typedef struct
{
    char lang[2]; // "PY", "C"
    char* fc;
    param_t params[MAX_PARAMS];
    size_t params_count;
} exec_faas_params_t;

/******************* GLOBAL VARIABLES *********************/

/******************* PUBLIC METHODS ***********************/

/*******************************************************/ /**
 * @brief Parse the exec_faas_params_t struct to a JSON string
 * 
 * @param exec_faas_params Struct with the FaaS parameters
 * @param ui8_payload_buff Buffer to store the JSON string
 * @param payload_len Length of the JSON string
 * @return int8_t 0 if OK, -1 if error
***********************************************************/
int8_t faasparser_parse_exec_faas_params_as_str_json(exec_faas_params_t* exec_faas_params, uint8_t* ui8_payload_buff, size_t* payload_len);

/*******************************************************/ /**
 * @brief Parse JSON string to exec_response_t struct
 * 
 * @param json_str JSON string
 * @param t_exec_response Struct to store the response
 * @return int8_t 0 if OK, -1 if error
***********************************************************/
int8_t faasparser_parse_json_str_as_exec_response(const char* json_str, exec_response_t* t_exec_response);

/*******************************************************/ /**
 * @brief Parse JSON string to async_exec_response_t struct
 * 
 * @param json_str JSON string
 * @param t_async_exec_response Struct to store the response 
 * @return int8_t 0 if OK, -1 if error
***********************************************************/
int8_t faasparser_parse_json_str_as_async_exec_response(const char* json_str, async_exec_response_t* t_async_exec_response);

/*******************************************************/ /**
 * @brief Frees the memory allocated for exec_faas_params_t struct
 * 
 * @param t_exec_response Struct to free
***********************************************************/
void faasparser_destroy_exec_response(exec_response_t* t_exec_response);

/******************* PRIVATE METHODS ***********************/

#endif // FAAS_PARSER_H