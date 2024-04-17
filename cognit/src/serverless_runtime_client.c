#include <cognit/serverless_runtime_client.h>
#include <cognit/cognit_http.h>
#include <cognit/cJSON.h>
#include <stdlib.h>
#include <string.h>
#include <cognit/faas_parser.h>
#include <cognit/logger.h>

void serverless_runtime_cli_init(serverless_runtime_cli_t* pt_serverless_runtime_cli, const char* c_endpoint)
{
    memset(pt_serverless_runtime_cli, 0, sizeof(serverless_runtime_cli_t));
    snprintf(pt_serverless_runtime_cli->t_serverless_runtime_endpoint, MAX_URL_LENGTH, c_endpoint);
    snprintf(pt_serverless_runtime_cli->c_a_exec_sync_url, MAX_URL_LENGTH, "http://[%s]:8000/%s/%s", c_endpoint, FAAS_VERSION, FAAS_EXECUTE_SYNC_ENDPOINT);
    snprintf(pt_serverless_runtime_cli->c_a_exec_async_url, MAX_URL_LENGTH, "http://[%s]:8000/%s/%s", c_endpoint, FAAS_VERSION, FAAS_EXECUTE_ASYNC_ENDPOINT);
}

bool serverless_runtime_cli_is_initialized(serverless_runtime_cli_t* pt_serverless_runtime_cli)
{
    // Assume that the endpoint is not initialized if it is empty
    if (pt_serverless_runtime_cli->t_serverless_runtime_endpoint[0] == '\0')
    {
        return false;
    }
    else
    {
        return true;
    }
}

int serverless_runtime_cli_faas_exec_sync(serverless_runtime_cli_t* pt_serverless_runtime_cli, uint8_t* ui8_payload, size_t payload_len, exec_response_t* pt_exec_response)
{
    int8_t i8_ret               = 0;
    http_config_t t_http_config = { 0 };

    //Clear the response
    memset(pt_exec_response, 0, sizeof(exec_response_t));

    t_http_config.c_url           = pt_serverless_runtime_cli->c_a_exec_sync_url;
    t_http_config.c_method        = HTTP_METHOD_POST;
    t_http_config.ui32_timeout_ms = 10000;

    i8_ret = cognit_http_send(ui8_payload, payload_len, &t_http_config);
    COGNIT_LOG_DEBUG("FaaS execute sync [POST-URL]: %s", t_http_config.c_url);

    if (i8_ret != 0
        || t_http_config.t_http_response.ui8_response_data_buffer == NULL
        || t_http_config.t_http_response.size == 0
        || t_http_config.t_http_response.l_http_code != 200)
    {
        COGNIT_LOG_ERROR("Error sending HTTP request, HTTP code: %d", i8_ret);
        pt_exec_response->ret_code = ERROR;
    }
    else
    {
        // Print json response
        COGNIT_LOG_DEBUG("JSON received from serverless runtime: %s", t_http_config.t_http_response.ui8_response_data_buffer);
        COGNIT_LOG_TRACE("JSON received size: %ld", t_http_config.t_http_response.size);

        // Copy the response json to the response struct
        i8_ret = faasparser_parse_json_str_as_exec_response(t_http_config.t_http_response.ui8_response_data_buffer, pt_exec_response);

        if (i8_ret != 0)
        {
            COGNIT_LOG_ERROR("Error parsing JSON");
            pt_exec_response->ret_code = ERROR;
        }
    }

    pt_exec_response->http_err_code = t_http_config.t_http_response.l_http_code;

    // TODO IMPOORTANT handle the free of the response buffer???

    return 0;
}

int serverless_runtime_cli_faas_exec_async(serverless_runtime_cli_t* pt_serverless_runtime_cli, uint8_t* ui8_payload, size_t payload_len, async_exec_response_t* pt_async_exec_response)
{
    int8_t i8_ret = 0;
    http_config_t t_http_config;

    t_http_config.c_url           = pt_serverless_runtime_cli->c_a_exec_async_url;
    t_http_config.c_method        = HTTP_METHOD_POST;
    t_http_config.ui32_timeout_ms = 10000;

    i8_ret = cognit_http_send(ui8_payload, payload_len, &t_http_config);
    COGNIT_LOG_DEBUG("FaaS execute async [POST-URL]: %s", pt_serverless_runtime_cli->c_a_exec_async_url);

    if (i8_ret != 0
        || t_http_config.t_http_response.ui8_response_data_buffer == NULL
        || t_http_config.t_http_response.size == 0)
    {
        COGNIT_LOG_ERROR("Error sending HTTP request, HTTP code: %d", i8_ret);
        pt_async_exec_response->res.ret_code = ERROR;
    }
    else
    {
        // Print json response
        COGNIT_LOG_DEBUG("JSON received from serverless runtime: %s", t_http_config.t_http_response.ui8_response_data_buffer);
        COGNIT_LOG_TRACE("JSON received size: %ld", t_http_config.t_http_response.size);

        if (t_http_config.t_http_response.l_http_code == 200)
        {
            // Copy the response json to the response struct
            i8_ret = faasparser_parse_json_str_as_async_exec_response(t_http_config.t_http_response.ui8_response_data_buffer, pt_async_exec_response);

            if (i8_ret != 0)
            {
                COGNIT_LOG_ERROR("Error parsing JSON");
                pt_async_exec_response->res.ret_code = ERROR;
            }
        }
        else if (t_http_config.t_http_response.l_http_code == 400)
        {
            strcpy(pt_async_exec_response->status, "FAILED");
            pt_async_exec_response->res.ret_code = ERROR;
            strncpy(pt_async_exec_response->exec_id.faas_task_uuid, "000-000-000", strlen("000-000-000"));
        }
        else
        {
            strcpy(pt_async_exec_response->status, "READY");
            pt_async_exec_response->res.ret_code = ERROR;
            strncpy(pt_async_exec_response->exec_id.faas_task_uuid, "000-000-000", strlen("000-000-000"));
        }
    }

    pt_async_exec_response->res.http_err_code = t_http_config.t_http_response.l_http_code;

    return 0;
}

int serverless_runtime_cli_wait_for_task(serverless_runtime_cli_t* pt_serverless_runtime_cli, const char* c_async_task_id, uint32_t ui32_timeout_ms, async_exec_response_t* pt_async_exec_response)
{
    int8_t i8_ret = 0;
    http_config_t t_http_config;
    uint8_t ui8_payload[1] = { 0 };
    size_t payload_len     = 0;
    char c_faas_task__status_url[MAX_URL_LENGTH];
    // Fill firstly the task status URL
    snprintf(c_faas_task__status_url, MAX_URL_LENGTH, FAAS_WAIT_ENDPOINT, c_async_task_id);
    // Fill the URL
    snprintf(pt_serverless_runtime_cli->c_a_wait_task_url, MAX_URL_LENGTH, "http://[%s]:8000/%s/%s", pt_serverless_runtime_cli->t_serverless_runtime_endpoint, FAAS_VERSION, c_faas_task__status_url);
    memset(pt_async_exec_response, 0, sizeof(async_exec_response_t));

    t_http_config.c_url           = pt_serverless_runtime_cli->c_a_wait_task_url;
    t_http_config.c_method        = HTTP_METHOD_GET;
    t_http_config.ui32_timeout_ms = ui32_timeout_ms;

    COGNIT_LOG_DEBUG("FaaS wait [GET-URL]: %s", pt_serverless_runtime_cli->c_a_wait_task_url);
    i8_ret = cognit_http_send(ui8_payload, payload_len, &t_http_config);

    if (i8_ret != 0
        || t_http_config.t_http_response.ui8_response_data_buffer == NULL
        || t_http_config.t_http_response.size == 0)
    {
        COGNIT_LOG_ERROR("Error sending HTTP request, HTTP code: %d", i8_ret);
        pt_async_exec_response->res.ret_code = ERROR;
    }
    else
    {
        // Print json response
        COGNIT_LOG_DEBUG("JSON received from serverless runtime: %s", t_http_config.t_http_response.ui8_response_data_buffer);
        COGNIT_LOG_TRACE("JSON received size: %ld", t_http_config.t_http_response.size);

        if (t_http_config.t_http_response.l_http_code == 200
            || t_http_config.t_http_response.l_http_code == 400)
        {
            i8_ret = faasparser_parse_json_str_as_async_exec_response(t_http_config.t_http_response.ui8_response_data_buffer, pt_async_exec_response);

            if (i8_ret != 0)
            {
                COGNIT_LOG_ERROR("Error parsing JSON");
                pt_async_exec_response->res.ret_code = ERROR;
            }
        }
        else
        {
            strcpy(pt_async_exec_response->status, "READY");
            pt_async_exec_response->res.ret_code = ERROR;
            strcpy(pt_async_exec_response->exec_id.faas_task_uuid, "000-000-000");
        }
    }

    pt_async_exec_response->res.http_err_code = t_http_config.t_http_response.l_http_code;

    return 0;
}