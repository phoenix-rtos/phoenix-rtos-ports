#include <cognit/prov_engine_cli.h>
#include <cognit/serverless_runtime_client.h>
#include <cognit/cognit_http.h>
#include <stdlib.h>
#include <string.h>
#include <cognit/sr_parser.h>
#include <cognit/logger.h>

int prov_engine_cli_init(prov_engine_cli_t* t_prov_engine_cli, const cognit_config_t* pt_cognit_config)
{
    // Setup the instance to point to the configuration
    t_prov_engine_cli->m_t_config = pt_cognit_config;

    return 0;
}

int prov_engine_cli_create_runtime(prov_engine_cli_t* t_prov_engine_cli, serverless_runtime_t* t_serverless_runtime)
{
    int8_t i8_ret = 0;
    uint8_t ui8_payload[1024 * 16];
    size_t payload_len;
    http_config_t t_http_config = { 0 };
    char url[MAX_URL_LENGTH];

    memset(url, 0, sizeof(url));
    snprintf(url, MAX_URL_LENGTH, "%s://%s:%d/%s", STR_PROTOCOL, t_prov_engine_cli->m_t_config->prov_engine_endpoint, t_prov_engine_cli->m_t_config->prov_engine_port, SR_RESOURCE_ENDPOINT);

    t_http_config.c_url           = url;
    t_http_config.c_method        = HTTP_METHOD_POST;
    t_http_config.ui32_timeout_ms = REQ_TIMEOUT * 1000;
    t_http_config.c_username      = t_prov_engine_cli->m_t_config->prov_engine_pe_usr;
    t_http_config.c_password      = t_prov_engine_cli->m_t_config->prov_engine_pe_pwd;

    i8_ret = srparser_parse_serverless_runtime_as_str_json(t_serverless_runtime, &ui8_payload, &payload_len);
    COGNIT_LOG_DEBUG("%s", ui8_payload);

    COGNIT_LOG_DEBUG("Create [POST] URL: %s", t_http_config.c_url);
    i8_ret = cognit_http_send(ui8_payload, payload_len, &t_http_config);

    if (i8_ret != 0
        || t_http_config.t_http_response.l_http_code != 201)
    {
        COGNIT_LOG_ERROR("Provisioning engine returned %ld on create", t_http_config.t_http_response.l_http_code);
        COGNIT_LOG_ERROR("i8_ret: %d", i8_ret);

        return COGNIT_ECODE_ERROR;
    }
    else
    {
        COGNIT_LOG_DEBUG("Response JSON: %s", t_http_config.t_http_response.ui8_response_data_buffer);
        // Copy the response json to the response struct
        i8_ret = srparser_parse_json_str_as_serverless_runtime(t_http_config.t_http_response.ui8_response_data_buffer, t_serverless_runtime);

        if (i8_ret != 0)
        {
            COGNIT_LOG_ERROR("Error parsing JSON");
            return COGNIT_ECODE_ERROR;
        }
    }

    // TODO IMPOORTANT handle the free of the response buffer???

    return 0;
}

int prov_engine_cli_retreive_runtime(prov_engine_cli_t* t_prov_engine_cli, uint32_t ui32_id, serverless_runtime_t* t_serverless_runtime)
{
    int8_t i8_ret               = 0;
    http_config_t t_http_config = { 0 };
    char url[MAX_URL_LENGTH];

    memset(url, 0, sizeof(url));
    snprintf(url, MAX_URL_LENGTH, "%s://%s:%d/%s/%d", STR_PROTOCOL, t_prov_engine_cli->m_t_config->prov_engine_endpoint, t_prov_engine_cli->m_t_config->prov_engine_port, SR_RESOURCE_ENDPOINT, ui32_id);

    t_http_config.c_url           = url;
    t_http_config.c_method        = HTTP_METHOD_GET;
    t_http_config.ui32_timeout_ms = REQ_TIMEOUT * 1000;
    t_http_config.c_username      = t_prov_engine_cli->m_t_config->prov_engine_pe_usr;
    t_http_config.c_password      = t_prov_engine_cli->m_t_config->prov_engine_pe_pwd;

    //auth?

    COGNIT_LOG_DEBUG("Create [GET] URL: %s", t_http_config.c_url);
    i8_ret = cognit_http_send(NULL, NULL, &t_http_config);

    if (i8_ret != 0
        || t_http_config.t_http_response.l_http_code != 200)
    {
        COGNIT_LOG_ERROR("Provisioning engine returned %ld on retrieve", t_http_config.t_http_response.l_http_code);
        return COGNIT_ECODE_ERROR;
    }
    else
    {
        // Copy the response json to the response struct
        i8_ret = srparser_parse_json_str_as_serverless_runtime(t_http_config.t_http_response.ui8_response_data_buffer, t_serverless_runtime);

        if (i8_ret != 0)
        {
            COGNIT_LOG_ERROR("Error parsing JSON");
            return COGNIT_ECODE_ERROR;
        }
    }

    return 0;
}

int prov_engine_delete_runtime(prov_engine_cli_t* t_prov_engine_cli, uint32_t ui32_id, serverless_runtime_t* t_serverless_runtime)
{
    int8_t i8_ret               = 0;
    http_config_t t_http_config = { 0 };
    char url[MAX_URL_LENGTH];

    memset(url, 0, sizeof(url));

    snprintf(url, MAX_URL_LENGTH, "%s://%s:%d/%s/%d", STR_PROTOCOL, t_prov_engine_cli->m_t_config->prov_engine_endpoint, t_prov_engine_cli->m_t_config->prov_engine_port, SR_RESOURCE_ENDPOINT, ui32_id);

    t_http_config.c_url           = url;
    t_http_config.c_method        = HTTP_METHOD_DELETE;
    t_http_config.ui32_timeout_ms = REQ_TIMEOUT * 1000;
    t_http_config.c_username      = t_prov_engine_cli->m_t_config->prov_engine_pe_usr;
    t_http_config.c_password      = t_prov_engine_cli->m_t_config->prov_engine_pe_pwd;

    COGNIT_LOG_DEBUG("Create [DELETE] URL: %s", t_http_config.c_url);
    i8_ret = cognit_http_send(NULL, NULL, &t_http_config);

    if (i8_ret != 0
        || t_http_config.t_http_response.l_http_code != 204)
    {
        COGNIT_LOG_ERROR("Provisioning engine returned %ld on delete", t_http_config.t_http_response.l_http_code);
        return COGNIT_ECODE_ERROR;
    }

    return 0;
}