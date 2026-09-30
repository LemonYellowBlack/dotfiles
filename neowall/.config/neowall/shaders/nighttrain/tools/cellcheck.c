/* cellcheck.c: feed a program's output through neowall 0.7.1's own terminal
 * emulator (screen.c + vtparse.c) and print what lands in the cells.
 *
 *   cellcheck FILE [t]
 *
 * FILE is a raw byte stream, or a recording from tests/drive_nt.py (it starts
 * "NTREC"); with t, only what was printed by t seconds is fed. Prints the
 * first six header cells as the bytes the shader reads (bg r,g,b and fg
 * r,g,b), the sign rows 1 and 2 (their first 24 columns, and which columns
 * the text spans), and the status rows 4..12. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include "neowall/terminal/terminal.h"
static void col(const char *what, term_color c) {
    if (c.kind == TERM_COLOR_RGB) printf("%s (%3d,%3d,%3d)", what, c.r, c.g, c.b);
    else printf("%s %-13s", what, c.kind == TERM_COLOR_DEFAULT ? "default" : "indexed");
}
static void text_row(term_screen *s, int y, int cols, int upto) {
    const term_cell *r = term_screen_row(s, y); char line[1025]; int k = 0, first = -1, last = -1;
    for (int x = 0; x < cols && x < upto; x++) {
        char ch = (r[x].cp >= 32 && r[x].cp < 127) ? (char)r[x].cp : ' ';
        if (ch != ' ') { if (first < 0) first = x; last = x; }
        line[k++] = ch;
    }
    while (k > 0 && line[k - 1] == ' ') k--; line[k] = 0;
    if (upto < 1024) printf("row %d: \"%s\"  (text in columns %d..%d)\n", y, line, first, last);
    else if (k) printf("row %d: %s\n", y, line);
}
int main(int argc, char **argv) {
    if (argc < 2) { fprintf(stderr, "usage: cellcheck FILE [t]\n"); return 1; }
    FILE *f = fopen(argv[1], "rb"); if (!f) { perror(argv[1]); return 1; }
    static unsigned char buf[1 << 24]; size_t n = fread(buf, 1, sizeof buf, f); fclose(f);
    double upto = argc > 2 ? atof(argv[2]) : 1e30;
    int cols = 160, rows = 45, ver = 0, hdr = 0;
    term_screen *s;
    if (n > 5 && memcmp(buf, "NTREC", 5) == 0) {
        if (sscanf((char *)buf, "NTREC %d %d %d\n%n", &ver, &cols, &rows, &hdr) != 3 || !hdr) { fprintf(stderr, "bad header\n"); return 1; }
        s = term_screen_create(cols, rows);
        double last_t = 0; int chunks = 0;
        for (size_t p = hdr; p + 12 <= n; ) {
            double t; uint32_t len; memcpy(&t, buf + p, 8); memcpy(&len, buf + p + 8, 4);
            if (t > upto || p + 12 + len > n) break;
            term_screen_feed(s, buf + p + 12, len); last_t = t; chunks++;
            p += 12 + len;
        }
        printf("fed %d chunks, up to %.2f s\n", chunks, last_t);
    } else {
        s = term_screen_create(cols, rows);
        term_screen_feed(s, buf, n);
    }
    const term_cell *r0 = term_screen_row(s, 0);
    const char *names[6] = {"H_BEAT", "H_SYNC", "H_STATION", "H_TUNNEL", "H_ENV", "H_WIPE"};
    for (int x = 0; x < 6; x++) {
        printf("cell %d %-9s ", x, names[x]); col("bg", r0[x].bg); printf("  "); col("fg", r0[x].fg); printf("\n");
    }
    for (int y = 1; y <= 2; y++) text_row(s, y, cols, 24);
    for (int y = 4; y <= 12 && y < rows; y++) text_row(s, y, cols, 1 << 20);
    int proto = 0; bool sgr = false; term_screen_mouse_mode(s, &proto, &sgr);
    int cx, cy; term_screen_cursor(s, &cx, &cy);
    printf("mouse mode %d, sgr %d, cursor visible %d at (%d,%d)\n", proto, sgr, term_screen_cursor_visible(s), cx, cy);
    char reply[128]; size_t rl = term_screen_take_reply(s, reply, sizeof reply);
    printf("replies to the program: %zu bytes\n", rl);
    return 0;
}
