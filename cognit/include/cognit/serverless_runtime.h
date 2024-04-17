#ifndef SERVERLESS_RUNTIME_H
#define SERVERLESS_RUNTIME_H

#include <stdio.h>
#include <stdbool.h>

#define SR_NAME_MAX_LEN              50
#define SR_FLAVOUR_MAX_LEN           50
#define SR_ENDPOINT_MAX_LEN          256
#define SR_STATE_MAX_LEN             256
#define SR_VM_ID_MAX_LEN             256
#define SR_POLICY_MAX_LEN            256
#define SR_REQ_MAX_LEN               256
#define SR_GEOGRAPH_LOCATION_MAX_LEN 256

typedef struct
{
    uint8_t ui8_cpu;
    uint32_t ui32_memory;
    uint32_t ui32_disk_size;
    char c_flavour[SR_FLAVOUR_MAX_LEN];
    char c_endpoint[SR_ENDPOINT_MAX_LEN];
    char c_state[SR_STATE_MAX_LEN];
    uint32_t ui32_vm_id;
} faas_config_t;

typedef faas_config_t daas_config_t;

typedef struct
{
    char c_policy[SR_POLICY_MAX_LEN];
    char c_requirements[SR_REQ_MAX_LEN];
} scheduling_config_t;

typedef struct
{
    uint32_t ui32_latency_to_pe;
    char c_geograph_location[SR_GEOGRAPH_LOCATION_MAX_LEN];
} device_info_t;

typedef struct
{
    char c_name[SR_NAME_MAX_LEN];
    uint32_t ui32_id;
    faas_config_t faas_config;
    daas_config_t daas_config;
    scheduling_config_t scheduling_config;
    device_info_t device_info;
} serverless_runtime_t;

#endif // SERVERLESS_RUNTIME_H
