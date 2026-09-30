/* binding_check.c: run neowall 0.7.1's own channel-binding guess (copied
 * verbatim from shader_multipass.c lines 785-939) on a shader, after its own
 * parser (multipass_parse.c) has split it into passes. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include "neowall/shader/shader_multipass.h"   /* harness stub: parser types */
#define MULTIPASS_MAX_CHANNELS 4
typedef enum {
    CHANNEL_SOURCE_NONE = 0, CHANNEL_SOURCE_BUFFER_A, CHANNEL_SOURCE_BUFFER_B,
    CHANNEL_SOURCE_BUFFER_C, CHANNEL_SOURCE_BUFFER_D, CHANNEL_SOURCE_TEXTURE,
    CHANNEL_SOURCE_KEYBOARD, CHANNEL_SOURCE_NOISE, CHANNEL_SOURCE_SELF
} channel_source_t;
typedef struct { channel_source_t source; } chan_t;
typedef struct { const char *name; const char *source; chan_t channels[MULTIPASS_MAX_CHANNELS]; } pass_t;
#undef log_info
#define log_info(...) (printf(__VA_ARGS__), putchar('\n'))
const char *multipass_type_name(multipass_type_t t) {
    switch (t) { case PASS_TYPE_BUFFER_A: return "Buffer A"; case PASS_TYPE_BUFFER_B: return "Buffer B";
    case PASS_TYPE_BUFFER_C: return "Buffer C"; case PASS_TYPE_BUFFER_D: return "Buffer D";
    case PASS_TYPE_IMAGE: return "Image"; default: return "?"; }
}
static void guess(pass_t *pass) {
#include "heuristic_body.inc"
}
int main(int argc, char **argv) {
    FILE *f = fopen(argv[1], "rb"); if (!f) { perror(argv[1]); return 1; }
    fseek(f, 0, SEEK_END); long n = ftell(f); fseek(f, 0, SEEK_SET);
    char *s = malloc(n + 1); if (fread(s, 1, n, f) != (size_t)n) return 1; s[n] = 0; fclose(f);
    multipass_parse_result_t *pr = multipass_parse_shader(s);
    const char *names[] = {"None", "BufA", "BufB", "BufC", "BufD", "Tex", "Kbd", "Noise", "Self"};
    for (int i = 0; i < pr->pass_count; i++) {
        pass_t p = { multipass_type_name(pr->pass_types[i]), pr->pass_sources[i], {{0}} };
        if (pr->pass_types[i] == PASS_TYPE_IMAGE) {
            p.channels[0].source = CHANNEL_SOURCE_BUFFER_A; p.channels[1].source = CHANNEL_SOURCE_BUFFER_B;
            p.channels[2].source = CHANNEL_SOURCE_BUFFER_C; p.channels[3].source = CHANNEL_SOURCE_BUFFER_D;
        } else guess(&p);
        printf("RESULT Pass %d (%s): ch0=%s, ch1=%s, ch2=%s, ch3=%s\n", i, p.name,
               names[p.channels[0].source], names[p.channels[1].source], names[p.channels[2].source], names[p.channels[3].source]);
    }
    return 0;
}
