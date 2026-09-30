#ifndef STUB_SHADER_LOG_H
#define STUB_SHADER_LOG_H
#include <stdio.h>
#define log_info(...)  do { if (getenv("HARNESS_VERBOSE")) { fprintf(stderr, "[info] " __VA_ARGS__); fputc('\n', stderr); } } while (0)
#define log_debug(...) do {} while (0)
#define log_warn(...)  do { fprintf(stderr, "[warn] " __VA_ARGS__); fputc('\n', stderr); } while (0)
#define log_error(...) do { fprintf(stderr, "[error] " __VA_ARGS__); fputc('\n', stderr); } while (0)
#endif
