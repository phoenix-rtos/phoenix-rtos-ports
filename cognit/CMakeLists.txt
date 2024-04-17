# Build the cognit device runtime library
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

project(cognit)
cmake_minimum_required(VERSION 3.5)

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -g")

if(DEFINED SANITIZER)
  set(SANITIZER ${SANITIZER})
  set(CMAKE_CXX_FLAGS
      "${CMAKE_CXX_FLAGS} -fstack-protector-all  -fstack-check -fsanitize=address -fsanitize=leak  -fno-omit-frame-pointer -g"
  )
  set(CMAKE_C_FLAGS
      "${CMAKE_C_FLAGS} -fstack-check -fstack-protector-all -fsanitize=address  -fsanitize=leak -fno-omit-frame-pointer -g -Wno-comment"
  )
endif()
set(PROJECT_ROOT ${CMAKE_CURRENT_SOURCE_DIR})
set(SRC_FILES
    "${PROJECT_ROOT}/src/cJSON_Utils.c"
    "${PROJECT_ROOT}/src/cJSON.c"
    "${PROJECT_ROOT}/src/cognit_http.c"
    "${PROJECT_ROOT}/src/prov_engine_cli.c"
    "${PROJECT_ROOT}/src/serverless_runtime_client.c"
    "${PROJECT_ROOT}/src/serverless_runtime_context.c"
    "${PROJECT_ROOT}/src/base64.c"
    "${PROJECT_ROOT}/src/ip_utils.c"
    "${PROJECT_ROOT}/src/faas_parser.c"
    "${PROJECT_ROOT}/src/offload_fc_c.c"
    "${PROJECT_ROOT}/src/sr_parser.c"
    )

set(INCLUDE_PATHS "${PROJECT_ROOT}/include" "${PROJECT_ROOT}/src")

add_library(${PROJECT_NAME} STATIC ${SRC_FILES})

target_include_directories(${PROJECT_NAME} PUBLIC ${INCLUDE_PATHS})
