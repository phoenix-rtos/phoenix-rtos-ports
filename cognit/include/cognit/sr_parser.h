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
#ifndef SR_PARSER_H
#define SR_PARSER_H
/********************** INCLUDES **************************/
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <cognit/serverless_runtime_client.h>
#include <cognit/serverless_runtime.h>
/***************** DEFINES AND MACROS *********************/
#define JSON_ERR_CODE_OK           0
#define JSON_ERR_CODE_INVALID_JSON -1

/**************** TYPEDEFS AND STRUCTS ********************/
/******************* GLOBAL VARIABLES *********************/

/******************* PUBLIC METHODS ***********************/

/*******************************************************/ /**
 * @brief Parse the serverless_runtime_t struct to a JSON string
 * 
 * @param t_serverless_runtime Struct with the serverless runtime configuration
 * @param ui8_payload_buff Buffer to store the JSON string
 * @param payload_len Length of the JSON string
 * @return int8_t 0 if OK, -1 if error
***********************************************************/
int8_t srparser_parse_serverless_runtime_as_str_json(serverless_runtime_t* t_serverless_runtime, uint8_t* ui8_payload_buff, size_t* payload_len);

/*******************************************************/ /**
 * @brief Parse JSON string to serverless_runtime_t struct
 * 
 * @param json_str JSON string
 * @param t_serverless_runtime Struct to store the response
 * @return int8_t 0 if OK, -1 if error
***********************************************************/
int8_t srparser_parse_json_str_as_serverless_runtime(const char* json_str, serverless_runtime_t* t_serverless_runtime);

/******************* PRIVATE METHODS ***********************/

#endif // SR_PARSER_H