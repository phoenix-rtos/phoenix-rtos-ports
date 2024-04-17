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
#ifndef SERVERLESS_RUNTIME_CLIENT_H
#define SERVERLESS_RUNTIME_CLIENT_H
/********************** INCLUDES **************************/
#include <stdio.h>
#include <stdbool.h>
#include <stdint.h>
/***************** DEFINES AND MACROS *********************/
#define FAAS_VERSION                "v1"
#define FAAS_EXECUTE_SYNC_ENDPOINT  "faas/execute-sync"
#define FAAS_EXECUTE_ASYNC_ENDPOINT "faas/execute-async"
#define FAAS_WAIT_ENDPOINT          "faas/%s/status"

#define MODE_IN        "IN"
#define MODE_OUT       "OUT"
#define MAX_URL_LENGTH 512

/**************** TYPEDEFS AND STRUCTS ********************/
typedef enum
{
    OK      = 0,
    WORKING = 1,
    NOT_OK  = -1
} e_status_exec_t;

typedef struct
{
    char* state;
    char* result; // NULL if not present
} FaasUuidStatus;

typedef enum
{
    SUCCESS = 0,
    ERROR   = -1
} exec_return_code_t;

typedef struct
{
    exec_return_code_t ret_code;
    char* res_payload; // NULL if not present
    size_t res_payload_len;
    long http_err_code;
} exec_response_t;

typedef struct
{
    char faas_task_uuid[256];
} AsyncExecId;

typedef struct
{
    char status[10]; // "WORKING", "READY", "FAILED"
    exec_response_t res;
    AsyncExecId exec_id;
} async_exec_response_t;

typedef struct SServerlessRuntimeCli
{
    const char t_serverless_runtime_endpoint[MAX_URL_LENGTH];
    char c_a_exec_sync_url[MAX_URL_LENGTH];
    char c_a_exec_async_url[MAX_URL_LENGTH];
    char c_a_wait_task_url[MAX_URL_LENGTH];

} serverless_runtime_cli_t;
/******************* GLOBAL VARIABLES *********************/

/******************* PUBLIC METHODS ***********************/

/*******************************************************/ /**
 * @brief Initializes the serverless runtime client with the server endpoint
 * 
 * This function initializes the serverless runtime client with the provided server endpoint.
 * 
 * @param pt_serverless_runtime_cli Pointer to the serverless runtime client structure
 * @param c_endpoint Server endpoint URL
***********************************************************/
void serverless_runtime_cli_init(serverless_runtime_cli_t* pt_serverless_runtime_cli, const char* c_endpoint);

/*******************************************************/ /**
 * @brief Checks if the serverless runtime client is initialized
 * 
 * This function checks if the serverless runtime client is initialized.
 * 
 * @param pt_serverless_runtime_cli Pointer to the serverless runtime client structure
 * @return true if the serverless runtime client is initialized, false otherwise
***********************************************************/
bool serverless_runtime_cli_is_initialized(serverless_runtime_cli_t* pt_serverless_runtime_cli);

/*******************************************************/ /**
 * @brief Executes a synchronous task on the serverless runtime
 * 
 * This function makes a POST request to the serverless runtime for synchronous task execution.
 * 
 * @param pt_serverless_runtime_cli Pointer to the serverless runtime client structure
 * @param ui8_payload JSON payload with the task parameters
 * @param payload_len Length of the payload
 * @param pt_exec_response Pointer to the execution response structure
 * @return 0 on success, an error code otherwise
***********************************************************/
int serverless_runtime_cli_faas_exec_sync(serverless_runtime_cli_t* pt_serverless_runtime_cli, uint8_t* ui8_payload, size_t payload_len, exec_response_t* pt_exec_response);

/*******************************************************/ /**
 * @brief Executes an asynchronous task on the serverless runtime
 * 
 * This function makes a POST request to the serverless runtime for asynchronous task execution.
 * 
 * @param pt_serverless_runtime_cli Pointer to the serverless runtime client structure
 * @param ui8_payload JSON payload with the task parameters
 * @param payload_len Length of the payload
 * @param pt_async_exec_response Pointer to the asynchronous execution response structure
 * @return 0 on success, an error code otherwise
***********************************************************/
int serverless_runtime_cli_faas_exec_async(serverless_runtime_cli_t* pt_serverless_runtime_cli, uint8_t* ui8_payload, size_t payload_len, async_exec_response_t* pt_async_exec_response);

/*******************************************************/ /**
 * @brief Waits for the completion of an asynchronous task on the serverless runtime
 * 
 * This function makes a GET request to the serverless runtime to check the status of an asynchronous task.
 * 
 * @param pt_serverless_runtime_cli Pointer to the serverless runtime client structure
 * @param c_async_task_id String with the ID of the asynchronous task
 * @param ui32_timeout_ms Timeout in milliseconds
 * @param pt_async_exec_response Pointer to the asynchronous execution response structure
 * @return 0 on success, an error code otherwise
***********************************************************/
int serverless_runtime_cli_wait_for_task(serverless_runtime_cli_t* pt_serverless_runtime_cli, const char* c_async_task_id, uint32_t ui32_timeout_ms, async_exec_response_t* pt_async_exec_response);

/******************* PRIVATE METHODS ***********************/

#endif // SERVERLESS_RUNTIME_CLIENT_H