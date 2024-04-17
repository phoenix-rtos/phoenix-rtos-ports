#include <cognit/sr_parser.h>
#include <cognit/base64.h>
#include <cognit/cJSON.h>
#include <cognit/logger.h>

int8_t srparser_parse_serverless_runtime_as_str_json(serverless_runtime_t* t_serverless_runtime, uint8_t* ui8_payload_buff, size_t* payload_len)
{
    cJSON* root        = NULL;
    cJSON* sr          = NULL;
    cJSON* faas        = NULL;
    cJSON* daas        = NULL;
    cJSON* scheduling  = NULL;
    cJSON* device_info = NULL;

    char* str_sr_json = NULL;

    sr = cJSON_CreateObject();

    if (sr == NULL)
    {
        COGNIT_LOG_ERROR("Error creating cJSON object");
        return JSON_ERR_CODE_INVALID_JSON;
    }

    root = cJSON_CreateObject();
    if (root == NULL)
    {
        COGNIT_LOG_ERROR("Error creating cJSON object");
        cJSON_Delete(sr);
        return JSON_ERR_CODE_INVALID_JSON;
    }

    cJSON_AddItemToObject(sr, "SERVERLESS_RUNTIME", root);

    if (t_serverless_runtime->c_name != NULL)
    {
        cJSON_AddStringToObject(root, "NAME", t_serverless_runtime->c_name);
    }

    if (t_serverless_runtime->ui32_id != 0)
    {
        char c_id[32];
        sprintf(c_id, "%u", t_serverless_runtime->ui32_id);
        cJSON_AddStringToObject(root, "ID", c_id);
    }

    //faas
    faas = cJSON_CreateObject();
    if (faas == NULL)
    {
        COGNIT_LOG_ERROR("Error creating cJSON object");
        cJSON_Delete(root);
        return JSON_ERR_CODE_INVALID_JSON;
    }

    if (t_serverless_runtime->faas_config.ui8_cpu != 0)
    {
        cJSON_AddNumberToObject(faas, "CPU", t_serverless_runtime->faas_config.ui8_cpu);
    }

    if (t_serverless_runtime->faas_config.ui32_memory != 0)
    {
        cJSON_AddNumberToObject(faas, "MEMORY", t_serverless_runtime->faas_config.ui32_memory);
    }

    if (t_serverless_runtime->faas_config.ui32_disk_size != 0)
    {
        cJSON_AddNumberToObject(faas, "DISK_SIZE", t_serverless_runtime->faas_config.ui32_disk_size);
    }

    if (t_serverless_runtime->faas_config.c_flavour[0] != '\0')
    {
        cJSON_AddStringToObject(faas, "FLAVOUR", t_serverless_runtime->faas_config.c_flavour);
    }

    if (t_serverless_runtime->faas_config.c_endpoint[0] != '\0')
    {
        cJSON_AddStringToObject(faas, "ENDPOINT", t_serverless_runtime->faas_config.c_endpoint);
    }

    if (t_serverless_runtime->faas_config.c_state[0] != '\0')
    {
        cJSON_AddStringToObject(faas, "STATE", t_serverless_runtime->faas_config.c_state);
    }

    if (t_serverless_runtime->faas_config.ui32_vm_id != 0)
    {
        cJSON_AddNumberToObject(faas, "VM_ID", t_serverless_runtime->faas_config.ui32_vm_id);
    }

    cJSON_AddItemToObject(root, "FAAS", faas);

    daas = cJSON_CreateObject();
    if (daas == NULL)
    {
        COGNIT_LOG_ERROR("Error creating cJSON object");
        cJSON_Delete(root);
        return JSON_ERR_CODE_INVALID_JSON;
    }

    if (t_serverless_runtime->daas_config.c_flavour[0] != '\0')
    {
        cJSON_AddStringToObject(daas, "FLAVOUR", t_serverless_runtime->daas_config.c_flavour);
        cJSON_AddItemToObject(root, "DAAS", daas);
    }

    if (t_serverless_runtime->daas_config.ui8_cpu != 0)
    {
        cJSON_AddNumberToObject(daas, "CPU", t_serverless_runtime->daas_config.ui8_cpu);
    }

    if (t_serverless_runtime->daas_config.ui32_memory != 0)
    {
        cJSON_AddNumberToObject(daas, "MEMORY", t_serverless_runtime->daas_config.ui32_memory);
    }

    if (t_serverless_runtime->daas_config.ui32_disk_size != 0)
    {
        cJSON_AddNumberToObject(daas, "DISK_SIZE", t_serverless_runtime->daas_config.ui32_disk_size);
    }

    if (t_serverless_runtime->daas_config.c_endpoint[0] != '\0')
    {
        cJSON_AddStringToObject(daas, "ENDPOINT", t_serverless_runtime->daas_config.c_endpoint);
    }

    if (t_serverless_runtime->daas_config.c_state[0] != '\0')
    {
        cJSON_AddStringToObject(daas, "STATE", t_serverless_runtime->daas_config.c_state);
    }

    if (t_serverless_runtime->daas_config.ui32_vm_id != 0)
    {
        cJSON_AddNumberToObject(daas, "VM_ID", t_serverless_runtime->daas_config.ui32_vm_id);
    }

    scheduling = cJSON_CreateObject();
    if (scheduling == NULL)
    {
        COGNIT_LOG_ERROR("Error creating cJSON object");
        cJSON_Delete(root);
        return JSON_ERR_CODE_INVALID_JSON;
    }

    cJSON_AddStringToObject(scheduling, "POLICY", t_serverless_runtime->scheduling_config.c_policy);
    cJSON_AddItemToObject(root, "SCHEDULING", scheduling);

    if (t_serverless_runtime->scheduling_config.c_requirements[0] != '\0')
    {
        cJSON_AddStringToObject(scheduling, "REQUIREMENTS", t_serverless_runtime->scheduling_config.c_requirements);
    }

    device_info = cJSON_CreateObject();
    if (device_info == NULL)
    {
        COGNIT_LOG_ERROR("Error creating cJSON object");
        cJSON_Delete(root);
        return JSON_ERR_CODE_INVALID_JSON;
    }

    cJSON_AddStringToObject(device_info, "GEOGRAPHIC_LOCATION", t_serverless_runtime->device_info.c_geograph_location);
    cJSON_AddItemToObject(root, "DEVICE_INFO", device_info);

    if (t_serverless_runtime->device_info.ui32_latency_to_pe != 0)
    {
        cJSON_AddNumberToObject(device_info, "LATENCY_TO_PE", t_serverless_runtime->device_info.ui32_latency_to_pe);
    }

    str_sr_json = cJSON_Print(sr);

    // Copy the json string to the payload buffer
    strcpy((char*)ui8_payload_buff, str_sr_json);
    *payload_len = strlen(str_sr_json);

    free(str_sr_json);
    cJSON_Delete(sr);

    return JSON_ERR_CODE_OK;
}

int8_t srparser_parse_json_str_as_serverless_runtime(const char* json_str, serverless_runtime_t* t_serverless_runtime)
{
    cJSON* sr   = cJSON_Parse(json_str);
    cJSON* root = cJSON_GetObjectItem(sr, "SERVERLESS_RUNTIME");

    if (root == NULL)
    {
        COGNIT_LOG_ERROR("Error parsing JSON");
        cJSON_Delete(root);
        return JSON_ERR_CODE_INVALID_JSON;
    }

    cJSON* cname_item             = cJSON_GetObjectItem(root, "NAME");
    cJSON* ui32_id_item           = cJSON_GetObjectItem(root, "ID");
    cJSON* faas_config_item       = cJSON_GetObjectItem(root, "FAAS");
    cJSON* daas_config_item       = cJSON_GetObjectItem(root, "DAAS");
    cJSON* scheduling_config_item = cJSON_GetObjectItem(root, "SCHEDUULING");
    cJSON* device_info_item       = cJSON_GetObjectItem(root, "DEVICE_INFO");

    if (!cJSON_IsNumber(ui32_id_item) || !cJSON_IsString(cname_item))
    {
        COGNIT_LOG_ERROR("JSON content types are wrong");
        cJSON_Delete(root);
        return JSON_ERR_CODE_INVALID_JSON;
    }

    //Name
    //  strcpy(t_serverless_runtime->c_name, cname_item->valuestring);

    //id
    COGNIT_LOG_DEBUG("%d%d", t_serverless_runtime->ui32_id, ui32_id_item->valueint);
    t_serverless_runtime->ui32_id = ui32_id_item->valueint;

    //faas_config
    if (faas_config_item != NULL)
    {
        cJSON* faas_cpu_item = cJSON_GetObjectItem(faas_config_item, "CPU");
        if (faas_cpu_item != NULL)
        {
            t_serverless_runtime->faas_config.ui8_cpu = faas_cpu_item->valueint;
        }

        cJSON* faas_memory_item = cJSON_GetObjectItem(faas_config_item, "MEMORY");
        if (faas_memory_item != NULL)
        {
            t_serverless_runtime->faas_config.ui32_memory = faas_memory_item->valueint;
        }

        cJSON* faas_disk_size_item = cJSON_GetObjectItem(faas_config_item, "DISK_SIZE");
        if (faas_disk_size_item != NULL)
        {
            t_serverless_runtime->faas_config.ui32_disk_size = faas_disk_size_item->valueint;
        }

        cJSON* faas_flavour_item = cJSON_GetObjectItem(faas_config_item, "FLAVOUR");
        strcpy(t_serverless_runtime->faas_config.c_flavour, faas_flavour_item->valuestring);

        cJSON* faas_endpoint_item = cJSON_GetObjectItem(faas_config_item, "ENDPOINT");
        if (faas_endpoint_item != NULL)
        {
            strcpy(t_serverless_runtime->faas_config.c_endpoint, faas_endpoint_item->valuestring);
            COGNIT_LOG_DEBUG("t_serverless_runtime->faas_config.c_endpoint: %s", t_serverless_runtime->faas_config.c_endpoint);
        }

        cJSON* faas_state_item = cJSON_GetObjectItem(faas_config_item, "STATE");
        strcpy(t_serverless_runtime->faas_config.c_state, faas_state_item->valuestring);

        cJSON* faas_vm_id_item = cJSON_GetObjectItem(faas_config_item, "VM_ID");
        if (faas_vm_id_item != NULL)
        {
            t_serverless_runtime->faas_config.ui32_vm_id = faas_vm_id_item->valueint;
        }
    }
    else
    {
        COGNIT_LOG_ERROR("JSON message is wrong");
        cJSON_Delete(root);
        return JSON_ERR_CODE_INVALID_JSON;
    }

    //daas_config
    if (daas_config_item != NULL)
    {
        cJSON* daas_cpu_item = cJSON_GetObjectItem(daas_config_item, "CPU");
        if (daas_cpu_item != NULL)
        {
            t_serverless_runtime->daas_config.ui8_cpu = daas_cpu_item->valueint;
        }
        cJSON* daas_memory_item = cJSON_GetObjectItem(daas_config_item, "MEMORY");
        if (daas_memory_item != NULL)
        {
            t_serverless_runtime->daas_config.ui32_memory = daas_memory_item->valueint;
        }

        cJSON* daas_disk_size_item = cJSON_GetObjectItem(daas_config_item, "DISK_SIZE");
        if (daas_disk_size_item != NULL)
        {
            char* end;
            t_serverless_runtime->daas_config.ui32_disk_size = (uint32_t)strtoul(daas_disk_size_item->valuestring, &end, 10);
            // t_serverless_runtime->daas_config.ui32_disk_size = daas_disk_size_item->valuestring;
        }

        cJSON* daas_flavour_item = cJSON_GetObjectItem(daas_config_item, "FLAVOUR");
        strcpy(t_serverless_runtime->daas_config.c_flavour, daas_flavour_item->valuestring);

        cJSON* daas_endpoint_item = cJSON_GetObjectItem(daas_config_item, "ENDPOINT");
        if (daas_endpoint_item != NULL)
        {
            strcpy(t_serverless_runtime->daas_config.c_endpoint, daas_endpoint_item->valuestring);
        }

        cJSON* daas_state_item = cJSON_GetObjectItem(daas_config_item, "STATE");
        strcpy(t_serverless_runtime->daas_config.c_state, daas_state_item->valuestring);

        cJSON* daas_vm_id_item = cJSON_GetObjectItem(daas_config_item, "VM_ID");
        if (daas_vm_id_item != NULL)
        {
            t_serverless_runtime->daas_config.ui32_vm_id = daas_vm_id_item->valueint;
        }
    }

    //scheduling_config;
    if (scheduling_config_item != NULL)
    {
        cJSON* scheduling_policy_item = cJSON_GetObjectItem(scheduling_config_item, "POLICY");
        strcpy(t_serverless_runtime->scheduling_config.c_policy, scheduling_policy_item->valuestring);

        cJSON* scheduling_req_item = cJSON_GetObjectItem(daas_config_item, "REQUIREMENTS");
        if (scheduling_req_item != NULL)
            strcpy(t_serverless_runtime->scheduling_config.c_requirements, scheduling_policy_item->valuestring);
    }

    //device_info;
    if (device_info_item != NULL)
    {
        cJSON* device_latency_item = cJSON_GetObjectItem(device_info_item, "LATENCY_TO_PE");
        if (device_latency_item != NULL)
            t_serverless_runtime->device_info.ui32_latency_to_pe = device_latency_item->valueint;

        cJSON* device_loc_item = cJSON_GetObjectItem(device_info_item, "GEOGRAPHIC_LOCATION");
        strcpy(t_serverless_runtime->device_info.c_geograph_location, device_loc_item->valuestring);
    }

    cJSON_Delete(sr);

    return JSON_ERR_CODE_OK;
}
