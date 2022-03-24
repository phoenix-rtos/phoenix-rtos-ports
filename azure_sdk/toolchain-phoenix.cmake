INCLUDE(CMakeForceCompiler)

SET(CMAKE_SYSTEM_NAME Linux)
SET(CMAKE_SYSTEM_VERSION 1)

# this is the location of the Phoenix-RTOS toolchain for a specific target architecture
SET(CMAKE_C_COMPILER $ENV{PHOENIX_SYSROOT}/../bin/$ENV{PHOENIX_COMPILER_CMD})
# disable CXX compiler checks
SET(CMAKE_CXX_COMPILER_WORKS 1)

SET(CURL_INCLUDE_DIR "${PREFIX_BUILD}/curl/include/")
SET(CURL_LIBRARY "$ENV{PREFIX_BUILD}/lib/libcurl.a")
SET(OPENSSL_INCLUDE_DIR "${PREFIX_BUILD}/openssl/include/")
SET(OPENSSL_SSL_LIBRARY "$ENV{PREFIX_BUILD}/lib/libssl.a")
SET(OPENSSL_CRYPTO_LIBRARY "$ENV{PREFIX_BUILD}/lib/libcrypto.a")

# this is the file system root of the target
SET(CMAKE_FIND_ROOT_PATH $ENV{PHOENIX_SYSROOT})

# search for programs in the build host directories
SET(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)

# for libraries and headers in the target directories
SET(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
SET(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

include_directories("$ENV{TOPDIR}/libphoenix/include")
