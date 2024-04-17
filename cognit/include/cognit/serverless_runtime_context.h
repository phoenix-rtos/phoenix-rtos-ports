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
#ifndef SERVERLESS_RUNTIME_CONTEXT_H
#define SERVERLESS_RUNTIME_CONTEXT_H
/********************** INCLUDES **************************/
#include <stdio.h>
#include <stdbool.h>
#include <cognit/prov_engine_cli.h>
#include <cognit/serverless_runtime_client.h>
#include <cognit/faas_parser.h>
#include <cognit/cognit_config.h>
#include <cognit/serverless_runtime.h>
/***************** DEFINES AND MACROS *********************/
#define MODE_IN      "IN"
#define MODE_OUT     "OUT"
#define INTERVAL_1MS 1

#define MAX_ENERGY_SCHEDULING_POLICIES 1
#define POLICY_NAME_MAX_LEN            50

#define FAAS_MAX_SEND_PAYLOD_SIZE 16384 // 16KB
/**************** TYPEDEFS AND STRUCTS ********************/

typedef struct
{
    uint32_t ui32_energy_percentage;
} energy_scheduling_policy_t;

// Representación de la clase ServerlessRuntimeConfig
typedef struct
{
    energy_scheduling_policy_t m_t_energy_scheduling_policies;
    const char* name;
    const char* faas_flavour;
    const char* daas_flavour;
} serverless_runtime_conf_t;

typedef enum
{
    E_ST_CODE_SUCCESS = 0,
    E_ST_CODE_ERROR   = 1,
    E_ST_CODE_PENDING = 2
} e_status_code_t;

typedef struct
{
    cognit_config_t m_t_cognit_conf;
    serverless_runtime_t m_t_serverless_runtime;
    prov_engine_cli_t m_t_prov_engine_cli;
    serverless_runtime_cli_t m_t_serverless_runtime_cli;

    uint8_t ui8_a_faas_send_buffer[FAAS_MAX_SEND_PAYLOD_SIZE];

} serverless_runtime_context_t;

/******************* GLOBAL VARIABLES *********************/

/******************* PUBLIC METHODS ***********************/

/*******************************************************/ /**
 * @brief Initialize the serverless runtime context and shares pec_context with prov_engine_cli
 * 
 * @param pt_sr_ctx Serverless runtime context instance
 * @param pt_cfg Cognit library configuration
 * @return e_status_code_t Status returned by prov engine client
***********************************************************/
e_status_code_t serverless_runtime_ctx_init(serverless_runtime_context_t* pt_sr_ctx, const cognit_config_t* pt_cfg);

/*******************************************************/ /**
 * @brief Creates default serverless runtime configuration
 * 
 * @param pt_sr_ctx Serverless runtime context instance
 * @param t_sr_conf Serverless runtime configuration
 * @return e_status_code_t Status returned by prov engine client
***********************************************************/
e_status_code_t serverless_runtime_ctx_create(serverless_runtime_context_t* pt_sr_ctx, const serverless_runtime_conf_t* t_sr_conf);

/*******************************************************/ /**
 * @brief Gets current serverless runtime status
 * 
 * @param pt_sr_ctx Serverless runtime context instance
 * @return e_faas_state_t Serverless runtime status
***********************************************************/
e_faas_state_t serverless_runtime_ctx_status(serverless_runtime_context_t* pt_sr_ctx);

/*******************************************************/ /**
 * @brief Parses faas_params, generates the payload and calls the sync serverless runtime
 * 
 * @param pt_sr_ctx Serverless runtime context instance
 * @param exec_faas_params Execution parameters
 * @param pt_exec_response Execution response
 * @return e_status_code_t Execution status
***********************************************************/
e_status_code_t serverless_runtime_ctx_call_sync(serverless_runtime_context_t* pt_sr_ctx, exec_faas_params_t* exec_faas_params, exec_response_t* pt_exec_response);

/*******************************************************/ /**
 * @brief Parses faas_params, generates the payload and calls the async serverless runtime
 * 
 * @param pt_sr_ctx Serverless runtime context instance
 * @param exec_faas_params Execution parameters
 * @param pt_async_exec_response Async execution response
 * @return e_status_code_t Execution status
***********************************************************/
e_status_code_t serverless_runtime_ctx_call_async(serverless_runtime_context_t* pt_sr_ctx, exec_faas_params_t* exec_faas_params, async_exec_response_t* pt_async_exec_response);

/*******************************************************/ /**
 * @brief Ask periodically to the serverless runtime if the task has finished
 * 
 * @param pt_sr_ctx Serverless runtime context instance
 * @param c_async_task_id Task id to wait for
 * @param ui32_timeout_ms Timeout in milliseconds
 * @param pt_async_exec_response Async execution response
 * @return e_status_code_t Execution status
***********************************************************/
e_status_code_t serverless_runtime_ctx_wait_for_task(serverless_runtime_context_t* pt_sr_ctx, const char* c_async_task_id, uint32_t ui32_timeout_ms, async_exec_response_t* pt_async_exec_response);

/*******************************************************/ /**
 * @brief Ask pec to delete the serverless runtime
 * 
 * @param pt_sr_ctx Serverless runtime context instance
 * @return e_status_code_t Status returned by prov engine client
***********************************************************/
e_status_code_t serverless_runtime_delete(serverless_runtime_context_t* pt_sr_ctx);
/******************* PRIVATE METHODS ***********************/

#endif // SERVERLESS_RUNTIME_CONTEXT_H