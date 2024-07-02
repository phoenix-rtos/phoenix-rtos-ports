set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

project(coreMQTT)
cmake_minimum_required(VERSION 3.5)

set(PROJECT_ROOT ${CMAKE_CURRENT_SOURCE_DIR})
set(COREMQTT "coreMQTT-2.3.0")
set(CMAKE_C_FLAGS $ENV{EXPORT_CFLAGS})

add_compile_definitions(MQTT_DO_NOT_USE_CUSTOM_CONFIG)

set(SRC_FILES
    "${PROJECT_ROOT}/${COREMQTT}/source/core_mqtt.c"
    "${PROJECT_ROOT}/${COREMQTT}/source/core_mqtt_state.c"
    "${PROJECT_ROOT}/${COREMQTT}/source/core_mqtt_serializer.c"
    )

set(INCLUDE_PATHS "${PROJECT_ROOT}/${COREMQTT}/source/include" "${PROJECT_ROOT}/${COREMQTT}/source/interface")

add_library(${PROJECT_NAME} STATIC ${SRC_FILES})

target_include_directories(${PROJECT_NAME} PUBLIC ${INCLUDE_PATHS})
