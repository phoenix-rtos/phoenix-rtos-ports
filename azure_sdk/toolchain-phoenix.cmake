# Set the location of the Phoenix-RTOS toolchain for a specific target architecture
SET(CMAKE_C_COMPILER $ENV{PHOENIX_SYSROOT}/../bin/$ENV{PHOENIX_COMPILER_CMD})
# Disable CXX compiler checks - cpp is not yet supported on Phoenix-RTOS
SET(CMAKE_CXX_COMPILER_WORKS 1)

SET(CURL_INCLUDE_DIR "${PREFIX_BUILD}/curl/include/")
SET(CURL_LIBRARY "$ENV{PREFIX_BUILD}/lib/libcurl.a")
SET(OPENSSL_INCLUDE_DIR "${PREFIX_BUILD}/openssl/include/")
SET(OPENSSL_SSL_LIBRARY "$ENV{PREFIX_BUILD}/lib/libssl.a")
SET(OPENSSL_CRYPTO_LIBRARY "$ENV{PREFIX_BUILD}/lib/libcrypto.a")

# Set the file system root for the specific target architecture
SET(CMAKE_FIND_ROOT_PATH $ENV{PHOENIX_SYSROOT})

# CMAKE_FIND_ROOT_PATH_MODE variable is set like it's recommended in cross compiling guide
# Search for programs in the build host directories
SET(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)

# For libraries and headers in the target directories
SET(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
SET(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

# Using PREFIX_H instead libphoenix/include does not work here
include_directories("$ENV{TOPDIR}/libphoenix/include")
