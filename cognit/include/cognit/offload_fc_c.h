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
#ifndef OFFLOAD_FC_C_H
#define OFFLOAD_FC_C_H
/********************** INCLUDES **************************/
#include <stdio.h>
#include <stdint.h>
#include <cognit/faas_parser.h>

/***************** DEFINES AND MACROS *********************/

/**************** TYPEDEFS AND STRUCTS ********************/

/******************* GLOBAL VARIABLES *********************/

/******************* PUBLIC METHODS ***********************/

/*******************************************************/ /**
 * @brief Create a exec faas params object with function to offload in C
 * 
 * @param t_exec_faas_params Struct to store the FaaS parameters
 * @param c_includes String with the includes of the function
 * @param c_func String with the function to offload
***********************************************************/
void offload_fc_c_create(exec_faas_params_t* t_exec_faas_params, const char* c_includes, const char* c_func);

/*******************************************************/ /**
 * @brief Add a parameter to the exec faas params object
 * 
 * @param t_exec_faas_params Struct to store the FaaS parameters
 * @param c_param_name Parameter name
 * @param c_param_mode Parameter mode (IN or OUT)
***********************************************************/
void offload_fc_c_add_param(exec_faas_params_t* t_exec_faas_params, const char* c_param_name, const char* c_param_mode);

/*******************************************************/ /**
 * @brief Set the parameter type and value
 * 
 * @param t_exec_faas_params Struct to store the FaaS parameters
 * @param c_param_type Parameter type
 * @param c_value Parameter value
***********************************************************/
void offload_fc_c_set_param(exec_faas_params_t* t_exec_faas_params, const char* c_param_type, const char* c_value);

/*******************************************************/ /**
 * @brief Destroy the dynamic memory of the exec faas params object
 * 
 * @param t_exec_faas_params Struct to store the FaaS parameters
***********************************************************/
void offload_fc_c_destroy(exec_faas_params_t* t_exec_faas_params);

/******************* PRIVATE METHODS ***********************/

#endif // OFFLOAD_FC_C_H