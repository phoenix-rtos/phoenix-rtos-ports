#include <cognit/serverless_runtime_context.h>
#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <errno.h>
#include <cognit/ip_utils.h>
#include <unistd.h>
#include <cognit/logger.h>

// Private functions
static int serialize_energy_requirements(energy_scheduling_policy_t t_energy_scheduling_policy, char* pch_serialized_energy_requirements, const size_t ui32_serialized_energy_requirements_len)
{
    cJSON* pt_json  = cJSON_CreateObject();
    int i_json_size = 0;

    cJSON_AddNumberToObject(pt_json, "energy", t_energy_scheduling_policy.ui32_energy_percentage);
    char* pch_json_string = cJSON_Print(pt_json);

    i_json_size = strlen(pch_json_string);

    if (i_json_size > ui32_serialized_energy_requirements_len)
    {
        COGNIT_LOG_ERROR("[sr_context] serialize_energy_requirements: serialized string is too big, %d bytes, max allowed %ld bytes", i_json_size, ui32_serialized_energy_requirements_len);
        return -1;
    }

    memcpy(pch_serialized_energy_requirements, pch_json_string, i_json_size);

    cJSON_Delete(pt_json);
    free(pch_json_string);

    return 0;
}

static void init_faas_config(faas_config_t* t_xaas_config)
{
    // Initialize the values in the structure
    t_xaas_config->ui8_cpu        = 1;
    t_xaas_config->ui32_memory    = 768;
    t_xaas_config->ui32_disk_size = 3072;
    strcpy(t_xaas_config->c_flavour, "Energy");
    strcpy(t_xaas_config->c_endpoint, "");
    strcpy(t_xaas_config->c_state, "");
    t_xaas_config->ui32_vm_id = 0;
}

// Public functions
e_status_code_t serverless_runtime_ctx_init(serverless_runtime_context_t* pt_sr_ctx, const cognit_config_t* pt_cfg)
{
    e_status_code_t e_ret = E_ST_CODE_ERROR;

    // Initial cleanup
    memset(pt_sr_ctx, 0, sizeof(serverless_runtime_context_t));

    // Copy the provided config into the sr instance
    memcpy(&pt_sr_ctx->m_t_cognit_conf, pt_cfg, sizeof(cognit_config_t));

    // Init the provisioning engine client using the config
    if (prov_engine_cli_init(&pt_sr_ctx->m_t_prov_engine_cli, &pt_sr_ctx->m_t_cognit_conf) == PE_ERR_CODE_SUCCESS)
    {
        e_ret = E_ST_CODE_SUCCESS;
    }

    return e_ret;
}

e_status_code_t serverless_runtime_ctx_create(serverless_runtime_context_t* pt_sr_ctx, const serverless_runtime_conf_t* pt_sr_conf)
{
    // Load default values to faas_config
    init_faas_config(&pt_sr_ctx->m_t_serverless_runtime.faas_config);

    // Copy name, flavour, policies and requirements
    strncpy(pt_sr_ctx->m_t_serverless_runtime.c_name, pt_sr_conf->name, sizeof(pt_sr_ctx->m_t_serverless_runtime.c_name));
    strncpy(pt_sr_ctx->m_t_serverless_runtime.faas_config.c_flavour, pt_sr_conf->faas_flavour, sizeof(pt_sr_ctx->m_t_serverless_runtime.faas_config.c_flavour));
    // By default "ENERGY" is the scheduling policy
    strncpy(pt_sr_ctx->m_t_serverless_runtime.scheduling_config.c_policy, "ENERGY", sizeof("ENERGY"));
    // TODO: Uncommet when ON avtivates requirements
    // snprintf(pt_sr_ctx->m_t_serverless_runtime.scheduling_config.c_requirements, sizeof(pt_sr_ctx->m_t_serverless_runtime.scheduling_config.c_requirements), "%d", pt_sr_conf->m_t_energy_scheduling_policies.ui32_energy_percentage);

    // TODO: add device info
    // TODO Add policies and requirements

    // Serialize energy requirements
    // for (int i = 0; i < MAX_ENERGY_SCHEDULING_POLICIES; i++)
    // {
    //     serialize_energy_requirements(pt_sr_conf.m_t_energy_scheduling_policies[i],pt_sr_ctx->m_t_prov_eng_context.m_serverless_runtime_conf.m_t_energy_scheduling_policies[i], sizeof(pt_sr_ctx->m_t_serverless_runtime.scheduling_config.
    // }

    // Create serverless runtime
    if (prov_engine_cli_create_runtime(&pt_sr_ctx->m_t_prov_engine_cli, &pt_sr_ctx->m_t_serverless_runtime) != COGNIT_ECODE_SUCCESS)
    {
        COGNIT_LOG_ERROR("[sr_context] Serverless Runtime creation request failed");
        return E_ST_CODE_ERROR;
    }
    // Check the state returned by the provisioning engine i
    if (strcmp(pt_sr_ctx->m_t_serverless_runtime.faas_config.c_state, STR_FAAS_STATE_PENDING) != 0)
    {
        COGNIT_LOG_ERROR("[sr_context] Serverless Runtime creation request failed: returned state is not PENDING, is %s", pt_sr_ctx->m_t_serverless_runtime.faas_config.c_state);
        return COGNIT_ECODE_ERROR;
    }
    COGNIT_LOG_INFO("[sr_context] Serverless Runtime create request completed successfully");
    return COGNIT_ECODE_SUCCESS;
}

e_faas_state_t serverless_runtime_ctx_status(serverless_runtime_context_t* pt_sr_ctx)
{
    int i_ret = COGNIT_ECODE_ERROR;

    // Check if the serverless runtime instance was created and already has an ID
    if (pt_sr_ctx == 0 || pt_sr_ctx->m_t_serverless_runtime.ui32_id == 0)
    {
        COGNIT_LOG_ERROR("[sr_context] Serverless Runtime not created yet");
        return E_FAAS_STATE_ERROR;
    }

    // Retrieve the serverless runtime from the provisioning engine using the ID
    i_ret = prov_engine_cli_retreive_runtime(&pt_sr_ctx->m_t_prov_engine_cli, pt_sr_ctx->m_t_serverless_runtime.ui32_id, &pt_sr_ctx->m_t_serverless_runtime);

    if (i_ret != COGNIT_ECODE_SUCCESS)
    {
        COGNIT_LOG_ERROR("[sr_context] Serverless Runtime retrieval request failed");
        return E_FAAS_STATE_ERROR;
    }

    // Check the state returned by the provisioning engine
    if (strcmp(pt_sr_ctx->m_t_serverless_runtime.faas_config.c_state, STR_FAAS_STATE_PENDING) == 0)
    {
        COGNIT_LOG_INFO("[sr_context] Serverless Runtime is PENDING");
        return E_FAAS_STATE_PENDING;
    }
    else if (strcmp(pt_sr_ctx->m_t_serverless_runtime.faas_config.c_state, STR_FAAS_STATE_NO_STATE) == 0)
    {
        COGNIT_LOG_INFO("[sr_context] Serverless Runtime is NO_STATE");
        return E_FAAS_STATE_NO_STATE;
    }
    else if (strcmp(pt_sr_ctx->m_t_serverless_runtime.faas_config.c_state, STR_FAAS_STATE_RUNNING) == 0)
    {
        COGNIT_LOG_INFO("[sr_context] Serverless Runtime is RUNNING");
        return E_FAAS_STATE_RUNNING;
    }

    COGNIT_LOG_ERROR("[sr_context] Serverless Runtime retrieval request failed: returned state is not PENDING, RUNNING or NO_STATE, is %s", pt_sr_ctx->m_t_serverless_runtime.faas_config.c_state);
    return E_FAAS_STATE_ERROR;
}

e_status_code_t serverless_runtime_ctx_call_sync(serverless_runtime_context_t* pt_sr_ctx, exec_faas_params_t* exec_faas_params, exec_response_t* pt_exec_response)
{
    size_t i_payload_len = 0;

    // Check if serverless runtime is created and running
    if (pt_sr_ctx == 0
        || pt_sr_ctx->m_t_serverless_runtime.ui32_id == 0
        || strcmp(pt_sr_ctx->m_t_serverless_runtime.faas_config.c_state, STR_FAAS_STATE_RUNNING) != 0
        || pt_sr_ctx->m_t_serverless_runtime.faas_config.c_endpoint == 0)
    {
        COGNIT_LOG_ERROR("[sr_context] Serverless Runtime is not ready");
        return E_ST_CODE_ERROR;
    }

    // Check if the serverless runtime client is initialized
    if (serverless_runtime_cli_is_initialized(&pt_sr_ctx->m_t_serverless_runtime_cli) == false)
    {
        serverless_runtime_cli_init(&pt_sr_ctx->m_t_serverless_runtime_cli, pt_sr_ctx->m_t_serverless_runtime.faas_config.c_endpoint);
    }

    // Serialize the function into a json string

    if (faasparser_parse_exec_faas_params_as_str_json(exec_faas_params, pt_sr_ctx->ui8_a_faas_send_buffer, &i_payload_len) == JSON_ERR_CODE_OK)
    {
        COGNIT_LOG_DEBUG("Params parsed successfully, generated JSON: %s", pt_sr_ctx->ui8_a_faas_send_buffer);
    }

    // Send the request to the serverless runtime
    serverless_runtime_cli_faas_exec_sync(&pt_sr_ctx->m_t_serverless_runtime_cli, pt_sr_ctx->ui8_a_faas_send_buffer, i_payload_len, pt_exec_response);

    return SUCCESS;
}

e_status_code_t serverless_runtime_ctx_call_async(serverless_runtime_context_t* pt_sr_ctx, exec_faas_params_t* exec_faas_params, async_exec_response_t* pt_async_exec_response)
{
    size_t i_payload_len = 0;
    // Check if serverless runtime is created and running
    if (pt_sr_ctx == 0
        || pt_sr_ctx->m_t_serverless_runtime.ui32_id == 0
        || strcmp(pt_sr_ctx->m_t_serverless_runtime.faas_config.c_state, STR_FAAS_STATE_RUNNING) != 0
        || pt_sr_ctx->m_t_serverless_runtime.faas_config.c_endpoint == 0)
    {
        COGNIT_LOG_ERROR("[sr_context] Serverless Runtime is not ready");
        return E_ST_CODE_ERROR;
    }

    // Check if the serverless runtime client is initialized
    if (serverless_runtime_cli_is_initialized(&pt_sr_ctx->m_t_serverless_runtime_cli) == false)
    {
        serverless_runtime_cli_init(&pt_sr_ctx->m_t_serverless_runtime_cli, pt_sr_ctx->m_t_serverless_runtime.faas_config.c_endpoint);
    }

    // Serialize the function into a json string
    if (faasparser_parse_exec_faas_params_as_str_json(exec_faas_params, pt_sr_ctx->ui8_a_faas_send_buffer, &i_payload_len) == JSON_ERR_CODE_OK)
    {
        COGNIT_LOG_DEBUG("Params parsed successfully, generated JSON: %s", pt_sr_ctx->ui8_a_faas_send_buffer);
    }

    // Send the request to the serverless runtime
    serverless_runtime_cli_faas_exec_async(&pt_sr_ctx->m_t_serverless_runtime_cli, pt_sr_ctx->ui8_a_faas_send_buffer, i_payload_len, pt_async_exec_response);

    return SUCCESS;
}

e_status_code_t serverless_runtime_ctx_wait_for_task(serverless_runtime_context_t* pt_sr_ctx, const char* c_async_task_id, uint32_t ui32_timeout_ms, async_exec_response_t* pt_async_exec_response)
{
    // Check if serverless runtime is created and running
    if (pt_sr_ctx == 0 || pt_sr_ctx->m_t_serverless_runtime.ui32_id == 0
        || strcmp(pt_sr_ctx->m_t_serverless_runtime.faas_config.c_state, STR_FAAS_STATE_RUNNING) != 0
        || pt_sr_ctx->m_t_serverless_runtime.faas_config.c_endpoint == 0)
    {
        COGNIT_LOG_ERROR("[sr_context] Serverless Runtime is not ready");
        return E_ST_CODE_ERROR;
    }

    // Check if the serverless runtime client is initialized
    if (serverless_runtime_cli_is_initialized(&pt_sr_ctx->m_t_serverless_runtime_cli) == false)
    {
        serverless_runtime_cli_init(&pt_sr_ctx->m_t_serverless_runtime_cli, pt_sr_ctx->m_t_serverless_runtime.faas_config.c_endpoint);
    }

    // Timeout management loop.
    while (ui32_timeout_ms > INTERVAL_1MS)
    {

        if (serverless_runtime_cli_wait_for_task(&pt_sr_ctx->m_t_serverless_runtime_cli, c_async_task_id, ui32_timeout_ms, pt_async_exec_response) != 0)
        {
            COGNIT_LOG_ERROR("[sr_context] Error sending HTTP request");
            return E_ST_CODE_ERROR;
        }

        if (strcmp(pt_async_exec_response->status, "READY") == 0
            && memcmp(&pt_async_exec_response->res, &(exec_response_t) { 0 }, sizeof(exec_response_t)) != 0)
        {
            COGNIT_LOG_DEBUG("[sr_context] Received task completed response from the serverless runtime");
            return SUCCESS;
        }

        usleep(INTERVAL_1MS * 1000);
        ui32_timeout_ms -= INTERVAL_1MS;
    }

    return E_ST_CODE_ERROR;
}

e_status_code_t serverless_runtime_delete(serverless_runtime_context_t* pt_sr_ctx)
{
    // Check if serverless runtime is created and running
    if (pt_sr_ctx == 0 || pt_sr_ctx->m_t_serverless_runtime.ui32_id == 0 || pt_sr_ctx->m_t_serverless_runtime.faas_config.c_state != STR_FAAS_STATE_RUNNING
        || pt_sr_ctx->m_t_serverless_runtime.faas_config.c_endpoint == 0)
    {
        COGNIT_LOG_ERROR("[sr_context] Serverless Runtime is not ready");
        return E_ST_CODE_ERROR;
    }

    if (prov_engine_delete_runtime(&pt_sr_ctx->m_t_prov_engine_cli, pt_sr_ctx->m_t_serverless_runtime.ui32_id, &pt_sr_ctx->m_t_serverless_runtime) == 0)
    {
        COGNIT_LOG_INFO("[sr_context] Serverless Runtime deleted successfully");
    }
    else
    {
        COGNIT_LOG_ERROR("[sr_context] Serverless Runtime deletion failed");
    }

    return E_ST_CODE_SUCCESS;
}