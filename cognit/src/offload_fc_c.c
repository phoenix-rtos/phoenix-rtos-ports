#include <cognit/offload_fc_c.h>
#include <cognit/faas_parser.h>
#include <cognit/logger.h>

void offload_fc_c_create(exec_faas_params_t* t_exec_faas_params, const char* c_includes, const char* c_func)
{
    strncpy(t_exec_faas_params->lang, "C", sizeof("C"));
    size_t total_fc_len = strlen(c_includes) + strlen(c_func) + 1;
    char* c_raw_fc      = (char*)malloc(total_fc_len);

    COGNIT_LOG_TRACE("Includes length: %zu, function length: %zu, Total length of function: %zu", strlen(c_includes), strlen(c_func), total_fc_len);
    strncpy(c_raw_fc, c_includes, strlen(c_includes));
    c_raw_fc[strlen(c_includes)] = '\0';

    size_t available_space = total_fc_len - strlen(c_raw_fc) - 1;
    COGNIT_LOG_TRACE("Available space: %zu", available_space);
    if (available_space >= strlen(c_func))
    {
        strncat(c_raw_fc, c_func, strlen(c_func));
    }
    else
    {
        COGNIT_LOG_ERROR("Not enough space to add function");
    }

    t_exec_faas_params->fc = malloc(total_fc_len + 1);
    if (t_exec_faas_params->fc == NULL)
    {
        COGNIT_LOG_ERROR("Failed to allocate memory for function");
    }

    strncpy(t_exec_faas_params->fc, c_raw_fc, total_fc_len);
    t_exec_faas_params->fc[total_fc_len] = '\0';
    free(c_raw_fc);
    printf("t_exec_faas_params->fc: %s\n", t_exec_faas_params->fc);

    return;
}

void offload_fc_c_add_param(exec_faas_params_t* t_exec_faas_params, const char* c_param_name, const char* c_param_mode)
{
    t_exec_faas_params->params[t_exec_faas_params->params_count].var_name = malloc(strlen(c_param_name) + 1);

    if (t_exec_faas_params->params[t_exec_faas_params->params_count].var_name == NULL)
    {
        COGNIT_LOG_ERROR("Failed to allocate memory for parameter name");
    }

    strncpy(t_exec_faas_params->params[t_exec_faas_params->params_count].var_name, c_param_name, strlen(c_param_name) + 1);
    strncpy(t_exec_faas_params->params[t_exec_faas_params->params_count].mode, c_param_mode, strlen(c_param_mode) + 1);
}

void offload_fc_c_set_param(exec_faas_params_t* t_exec_faas_params, const char* c_param_type, const char* c_value)
{
    COGNIT_LOG_INFO("Handling parameter %s", t_exec_faas_params->params[t_exec_faas_params->params_count].var_name);
    t_exec_faas_params->params[t_exec_faas_params->params_count].type = malloc(strlen(c_param_type) + 1);

    if (t_exec_faas_params->params[t_exec_faas_params->params_count].type == NULL)
    {
        COGNIT_LOG_ERROR("Failed to allocate memory for parameter type");
    }
    else
    {
        strncpy(t_exec_faas_params->params[t_exec_faas_params->params_count].type, c_param_type, strlen(c_param_type) + 1);
    }

    if (c_value != NULL)
    {
        t_exec_faas_params->params[t_exec_faas_params->params_count].value = malloc(strlen(c_value) + 1);

        if (t_exec_faas_params->params[t_exec_faas_params->params_count].value == NULL)
        {
            COGNIT_LOG_ERROR("Failed to allocate memory for parameter value");
        }
    }

    if (strcmp(t_exec_faas_params->params[t_exec_faas_params->params_count].mode, "OUT") == 0)
    {
        t_exec_faas_params->params[t_exec_faas_params->params_count].value = NULL;
    }
    else
    {
        strncpy(t_exec_faas_params->params[t_exec_faas_params->params_count].value, c_value, strlen(c_value) + 1);
    }

    t_exec_faas_params->params_count++;
}

void offload_fc_c_destroy(exec_faas_params_t* t_exec_faas_params)
{
    free(t_exec_faas_params->fc);
    for (int i = 0; i < t_exec_faas_params->params_count; i++)
    {
        free((char*)t_exec_faas_params->params[i].var_name);
        free((char*)t_exec_faas_params->params[i].type);
        free((char*)t_exec_faas_params->params[i].value);
    }
}