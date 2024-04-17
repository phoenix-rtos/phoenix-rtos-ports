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
#ifndef PROV_ENGINE_CLI_H
#define PROV_ENGINE_CLI_H
/********************** INCLUDES **************************/
#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <cognit/cJSON.h>
#include <cognit/cognit_config.h>
#include <cognit/serverless_runtime.h>
/***************** DEFINES AND MACROS *********************/
#define SR_RESOURCE_ENDPOINT "serverless-runtimes"
#define REQ_TIMEOUT          60

#define PE_ERR_CODE_SUCCESS 0
#define PE_ERR_CODE_ERROR   1

// Definición de constantes de cadena para FaaSState
#define STR_FAAS_STATE_PENDING  "PENDING"
#define STR_FAAS_STATE_RUNNING  "RUNNING"
#define STR_FAAS_STATE_NO_STATE ""

/**************** TYPEDEFS AND STRUCTS ********************/

typedef enum EFaasState
{
    E_FAAS_STATE_ERROR    = -1,
    E_FAAS_STATE_PENDING  = 0,
    E_FAAS_STATE_RUNNING  = 1,
    E_FAAS_STATE_NO_STATE = 2,

} e_faas_state_t;

typedef struct SProvEngine
{
    const cognit_config_t* m_t_config;
} prov_engine_cli_t;

/******************* GLOBAL VARIABLES *********************/

/******************* PUBLIC METHODS ***********************/

/*******************************************************/ /**
 * @brief Initializes the prov_engine_cli_t structure with the given configuration.
 * 
 * This function loads the cognit configuration and validates it.
 * 
 * @param t_prov_engine_cli Pointer to the prov_engine_cli_t structure to initialize.
 * @param pt_cognit_config Pointer to the cognit_config_t structure containing the configuration.
 * @return int 0 if success, -1 otherwise.
***********************************************************/
int prov_engine_cli_init(prov_engine_cli_t* t_prov_engine_cli, const cognit_config_t* pt_cognit_config);

/*******************************************************/ /**
 * @brief Creates a runtime object in the provisioning engine and makes an HTTP request.
 * 
 * This function creates a serverless runtime object in the provisioning engine using the provided serverless_runtime_t structure.
 * 
 * @param t_prov_engine_cli Pointer to the prov_engine_cli_t structure.
 * @param t_serverless_runtime Pointer to the serverless_runtime_t structure to create.
 * @return int 0 if success, -1 otherwise.
***********************************************************/
int prov_engine_cli_create_runtime(prov_engine_cli_t* t_prov_engine_cli, serverless_runtime_t* t_serverless_runtime);

/*******************************************************/ /**
 * @brief Retrieves the status of a serverless runtime.
 * 
 * This function retrieves the status of a serverless runtime with the given ID from the provisioning engine.
 * 
 * @param t_prov_engine_cli Pointer to the prov_engine_cli_t structure.
 * @param ui32_id ID of the serverless runtime.
 * @param t_serverless_runtime Pointer to the serverless_runtime_t structure to store the retrieved runtime information.
 * @return int 0 if success, -1 otherwise.
***********************************************************/
int prov_engine_cli_retreive_runtime(prov_engine_cli_t* t_prov_engine_cli, uint32_t ui32_id, serverless_runtime_t* t_serverless_runtime);

/*******************************************************/ /**
 * @brief Deletes a serverless runtime.
 * 
 * This function deletes a serverless runtime with the given ID from the provisioning engine.
 * 
 * @param t_prov_engine_cli Pointer to the prov_engine_cli_t structure.
 * @param ui32_id ID of the serverless runtime to delete.
 * @param t_serverless_runtime Pointer to the serverless_runtime_t structure to be cleaned.
 * @return int 0 if success, -1 otherwise.
***********************************************************/
int prov_engine_delete_runtime(prov_engine_cli_t* t_prov_engine_cli, uint32_t ui32_id, serverless_runtime_t* t_serverless_runtime);

/******************* PRIVATE METHODS ***********************/
#endif // PROV_ENGINE_CLI_H