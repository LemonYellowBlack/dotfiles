/* minimal stand-in for neowall's shader_multipass.h: only what the parser needs */
#ifndef STUB_SHADER_MULTIPASS_H
#define STUB_SHADER_MULTIPASS_H
#include <stdbool.h>
#include <stddef.h>
#define MULTIPASS_MAX_PASSES 5
typedef enum {
    PASS_TYPE_NONE = 0, PASS_TYPE_BUFFER_A, PASS_TYPE_BUFFER_B, PASS_TYPE_BUFFER_C,
    PASS_TYPE_BUFFER_D, PASS_TYPE_IMAGE, PASS_TYPE_COMMON, PASS_TYPE_SOUND
} multipass_type_t;
typedef struct {
    bool is_multipass;
    int pass_count;
    char *pass_sources[MULTIPASS_MAX_PASSES];
    multipass_type_t pass_types[MULTIPASS_MAX_PASSES];
    char *common_source;
    char *error_message;
} multipass_parse_result_t;
const char *multipass_type_name(multipass_type_t type);
int multipass_count_main_functions(const char *source);
bool multipass_detect(const char *source);
char *multipass_extract_common(const char *source);
multipass_parse_result_t *multipass_parse_shader(const char *source);
void multipass_free_parse_result(multipass_parse_result_t *result);
bool shader_check_required_version(const char *source, const char *shader_path);
#endif
