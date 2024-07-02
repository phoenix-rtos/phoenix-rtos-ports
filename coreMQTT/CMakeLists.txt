cmake_minimum_required(VERSION 3.16)
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

project(coreMQTT)

set(PROJECT_ROOT ${CMAKE_CURRENT_SOURCE_DIR})
set(COREMQTT "coreMQTT-2.3.0")
set(CMAKE_C_FLAGS "$ENV{CFLAGS} -std=gnu99 -O2 -Wall -Wextra")

include("${COREMQTT}/mqttFilePaths.cmake")

add_library(${PROJECT_NAME} STATIC ${MQTT_SOURCES} ${MQTT_SERIALIZER_SOURCES})

if (DEFINED ENV{COREMQTT_CONFIG_DIR})
    target_include_directories(${PROJECT_NAME} PRIVATE $ENV{COREMQTT_CONFIG_DIR})
else()
    target_compile_definitions(${PROJECT_NAME} PRIVATE MQTT_DO_NOT_USE_CUSTOM_CONFIG)
endif()

target_include_directories(${PROJECT_NAME} PUBLIC ${MQTT_INCLUDE_PUBLIC_DIRS})

install(TARGETS ${PROJECT_NAME} DESTINATION "lib")
foreach(dir IN LISTS MQTT_INCLUDE_PUBLIC_DIRS)
    install(DIRECTORY "${dir}/" DESTINATION "include" FILES_MATCHING PATTERN "*.h")
endforeach()
