cmake_minimum_required(VERSION 3.16)
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

project(cognit)

set(CMAKE_C_FLAGS "$ENV{CFLAGS} -std=gnu99 -O2 -Wall -Wextra")

if(DEFINED SANITIZER)
  set(SANITIZER ${SANITIZER})
  set(CMAKE_CXX_FLAGS
      "${CMAKE_CXX_FLAGS} -fstack-protector-all  -fstack-check -fsanitize=address -fsanitize=leak  -fno-omit-frame-pointer -g"
  )
  set(CMAKE_C_FLAGS
      "${CMAKE_C_FLAGS} -fstack-check -fstack-protector-all -fsanitize=address  -fsanitize=leak -fno-omit-frame-pointer -g -Wno-comment"
  )
endif()

# Add a option to compile tests
option(COGNIT_BUILD_TESTS "Build the tests" OFF)
option(COGNIT_BUILD_EXAMPLES "Build the examples" ON)

set(PROJECT_ROOT ${CMAKE_CURRENT_SOURCE_DIR}/cognit)
set(TEST_FOLDER ${CMAKE_CURRENT_SOURCE_DIR}/cognit/test)
set(EXAMPLES_FOLDER ${CMAKE_CURRENT_SOURCE_DIR}/examples)

# Build the library
add_subdirectory(${PROJECT_ROOT})

# Build tests
if(COGNIT_BUILD_TESTS)
  add_subdirectory(${TEST_FOLDER})
endif()

# Build examples
if(COGNIT_BUILD_EXAMPLES)
  add_subdirectory(${EXAMPLES_FOLDER})
endif()

install(TARGETS ${PROJECT_NAME} DESTINATION "lib")
install(DIRECTORY ${PROJECT_ROOT}/include/ DESTINATION "include/cognit")
install(DIRECTORY ${PROJECT_ROOT}/nanopb/ DESTINATION "include" FILES_MATCHING PATTERN "*.h")
