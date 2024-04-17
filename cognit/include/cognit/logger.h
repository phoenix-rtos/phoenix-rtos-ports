#ifndef LOGGER_HEADER_
#define LOGGER_HEADER_

#define COGNIT_LOG_LEVEL_TRACE 0
#define COGNIT_LOG_LEVEL_DEBUG 1
#define COGNIT_LOG_LEVEL_INFO  2
#define COGNIT_LOG_LEVEL_ERROR 3

#define COGNIT_LOG_LEVEL COGNIT_LOG_LEVEL_DEBUG

#define COGNIT_LOG_TRACE(...)                       \
    if (COGNIT_LOG_LEVEL <= COGNIT_LOG_LEVEL_TRACE) \
        printf("[TRACE] ");                         \
    printf(__VA_ARGS__);                            \
    printf("\n");

#define COGNIT_LOG_DEBUG(...)                       \
    if (COGNIT_LOG_LEVEL <= COGNIT_LOG_LEVEL_DEBUG) \
        printf("[DEBUG] ");                         \
    printf(__VA_ARGS__);                            \
    printf("\n");

#define COGNIT_LOG_INFO(...)                       \
    if (COGNIT_LOG_LEVEL <= COGNIT_LOG_LEVEL_INFO) \
        printf("[INFO] ");                         \
    printf(__VA_ARGS__);                           \
    printf("\n");

#define COGNIT_LOG_ERROR(...)                       \
    if (COGNIT_LOG_LEVEL <= COGNIT_LOG_LEVEL_ERROR) \
        printf("[ERROR] ");                         \
    printf(__VA_ARGS__);                            \
    printf("\n");

#endif // LOGGER_HEADER_
