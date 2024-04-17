#ifndef COGNIT_CONFIG_HEADER_
#define COGNIT_CONFIG_HEADER_

/********************** INCLUDES **************************/

#include <stdio.h>
#include <stdint.h>

/***************** DEFINES AND MACROS *********************/

#define COGNIT_ECODE_SUCCESS 0
#define COGNIT_ECODE_ERROR   -1

/**************** TYPEDEFS AND STRUCTS ********************/
/**
 * @brief Structure representing the configuration for the Cognit module.
 */
typedef struct
{
    const char* prov_engine_endpoint; /**< The endpoint of the provisioning engine. */
    const char* prov_engine_pe_usr;   /**< The username for the provisioning engine. */
    const char* prov_engine_pe_pwd;   /**< The password for the provisioning engine. */
    uint32_t prov_engine_port;        /**< The port number for the provisioning engine. */
    uint32_t ui32_serv_runtime_port;  /**< The port number for the service runtime. */
    // Add other fields as needed
} cognit_config_t;

#endif // COGNIT_CONFIG_HEADER_
