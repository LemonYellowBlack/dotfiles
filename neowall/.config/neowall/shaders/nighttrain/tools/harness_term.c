// harness.c - render a neowall multipass shader headlessly (EGL surfaceless,
// desktop GL 3.3 core) through neowall v0.7.1's own parser + wrapper, for
// previews (PNG) and GPU timing. Buffer passes are RGBA16F ping-pong exactly
// like neowall; the Image pass lands in an RGBA8 target like a real screen.
//
//   harness shader.glsl [-w W] [-h H] [-f fps] [-n frames]
//           [-s "sec,sec,..."] [-S start:end:step] [-o outdir] [-p prefix]
//           [-c cpu] [-r ram] [-t heat]   (each: "0.3" or "t:v,t:v,...")
//           [-T] (GPU timing)  [-d] (dump wrapped sources)
//   koi additions: [-N netdown] [-U netup] [-H hour-of-day 0..24] [-m mouse-energy]
//           [-X mouse-x-px] [-Y mouse-y-px (from the TOP, like neowall)]
//           [-P "sec,sec,..."] (a resume-from-pause at each: that frame's dt = 0.25)
//           [-C cpu-avg] (iCpu; defaults to -c)
//   terminal additions (harness_term):
//           [-x scenario] termtest's scripted session (0 normal, 1 heartbeat
//                         stops at 1 s, 2 no script)
//           [-R file.rec] replay a recording (tests/drive_nt.py) instead:
//                         its bytes go through neowall's own emulator and
//                         glyph atlas at the times they were printed, and the
//                         cells are packed exactly as term_render.c does
//           [-F font.ttf] [-z font-size]  the replay's font (default Noto Sans
//                         Mono Medium, 48, as nighttrain.vibe)
//           [-g]          the idle gate: draw only within 700 ms of a grid
//                         change, like neowall; a frame after a gap gets that
//                         gap as iTimeDelta, clamped to 0.25 s
//           [-b scale]    Buffer A's size as a share of the screen (0.7)
//           [-t "i,j"]    print these row-0 texels of Buffer A every frame
//           [-v n]        print the first n row-0 texels at the end (6)
//           [-D "y,m,d"]  iDate's date (month 1..12, as neowall sends it)
//           [-q "x:y,x:y"] print these Buffer A texels at the end (any row)
#define _GNU_SOURCE
#include <getopt.h>
#include <math.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <EGL/egl.h>
#include <EGL/eglext.h>
#define GL_GLEXT_PROTOTYPES
#include <GL/gl.h>
#include <GL/glext.h>
#include <png.h>

#include "neowall/shader/shader_multipass.h" /* stub: parser types only */
#include "neowall/shader/shader_stdlib.h"    /* real */
#include "neowall/shader/glsl_shadow.h"      /* real */
#include "neowall/shader/shadertoy_compat.h" /* real */
#include "nw_strings.h"                      /* real prefix/suffix, extracted */
#include "neowall/terminal/terminal.h"      /* real emulator: screen.c, vtparse.c */
#include "glyph_atlas.h"                    /* real glyph atlas */

const char *multipass_type_name(multipass_type_t t) {
    switch (t) {
    case PASS_TYPE_BUFFER_A: return "Buffer A";
    case PASS_TYPE_BUFFER_B: return "Buffer B";
    case PASS_TYPE_BUFFER_C: return "Buffer C";
    case PASS_TYPE_BUFFER_D: return "Buffer D";
    case PASS_TYPE_IMAGE: return "Image";
    default: return "?";
    }
}

#include "nw_wrap.inc" /* verbatim wrap_pass_source from neowall */

static char *read_file(const char *path) {
    FILE *f = fopen(path, "rb");
    if (!f) { perror(path); exit(1); }
    fseek(f, 0, SEEK_END);
    long n = ftell(f);
    fseek(f, 0, SEEK_SET);
    char *s = malloc(n + 1);
    if (fread(s, 1, n, f) != (size_t)n) { perror("read"); exit(1); }
    s[n] = 0;
    fclose(f);
    return s;
}

typedef struct { float t[64], v[64]; int n; } sched_t;

static void sched_parse(sched_t *s, const char *str) {
    s->n = 0;
    if (!strchr(str, ':')) { s->t[0] = 0; s->v[0] = strtof(str, NULL); s->n = 1; return; }
    char *dup = strdup(str), *save = NULL;
    for (char *tok = strtok_r(dup, ",", &save); tok && s->n < 64; tok = strtok_r(NULL, ",", &save)) {
        char *c = strchr(tok, ':');
        if (!c) continue;
        *c = 0;
        s->t[s->n] = strtof(tok, NULL);
        s->v[s->n] = strtof(c + 1, NULL);
        s->n++;
    }
    free(dup);
}

static float sched_eval(const sched_t *s, float t) {
    if (s->n == 1 || t <= s->t[0]) return s->v[0];
    for (int i = 1; i < s->n; i++)
        if (t <= s->t[i]) {
            float a = (t - s->t[i - 1]) / fmaxf(s->t[i] - s->t[i - 1], 1e-6f);
            return s->v[i - 1] + (s->v[i] - s->v[i - 1]) * a;
        }
    return s->v[s->n - 1];
}

static GLuint compile(GLenum type, const char *src, const char *label) {
    GLuint sh = glCreateShader(type);
    glShaderSource(sh, 1, &src, NULL);
    glCompileShader(sh);
    GLint ok = 0, len = 0;
    glGetShaderiv(sh, GL_COMPILE_STATUS, &ok);
    glGetShaderiv(sh, GL_INFO_LOG_LENGTH, &len);
    if (len > 1) {
        char *log = malloc(len);
        glGetShaderInfoLog(sh, len, NULL, log);
        fprintf(stderr, "--- %s shader log (%s) ---\n%s\n", label, ok ? "ok" : "FAILED", log);
        free(log);
    }
    if (!ok) exit(2);
    return sh;
}

static GLuint link_prog(const char *fs_src, const char *label) {
    static const char *vs =
        "#version 330 core\n"
        "void main() {\n"
        "    vec2 p = vec2(float((gl_VertexID << 1) & 2), float(gl_VertexID & 2));\n"
        "    gl_Position = vec4(p * 2.0 - 1.0, 0.0, 1.0);\n"
        "}\n";
    GLuint p = glCreateProgram();
    glAttachShader(p, compile(GL_VERTEX_SHADER, vs, "vertex"));
    glAttachShader(p, compile(GL_FRAGMENT_SHADER, fs_src, label));
    glLinkProgram(p);
    GLint ok = 0;
    glGetProgramiv(p, GL_LINK_STATUS, &ok);
    if (!ok) {
        char log[8192];
        glGetProgramInfoLog(p, sizeof log, NULL, log);
        fprintf(stderr, "link failed (%s): %s\n", label, log);
        exit(2);
    }
    return p;
}

static void save_png(const char *path, int w, int h, const unsigned char *rgba) {
    FILE *f = fopen(path, "wb");
    if (!f) { perror(path); return; }
    png_structp png = png_create_write_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
    png_infop info = png_create_info_struct(png);
    png_init_io(png, f);
    png_set_IHDR(png, info, w, h, 8, PNG_COLOR_TYPE_RGBA, PNG_INTERLACE_NONE,
                 PNG_COMPRESSION_TYPE_DEFAULT, PNG_FILTER_TYPE_DEFAULT);
    png_write_info(png, info);
    for (int y = h - 1; y >= 0; y--) png_write_row(png, (png_bytep)(rgba + (size_t)y * w * 4));
    png_write_end(png, NULL);
    png_destroy_write_struct(&png, &info);
    fclose(f);
}

typedef struct {
    GLint iTime, iTimeDelta, iFrame, iFrameRate, iResolution, iChannel0, iChannelRes,
          iCpu, iCpuMax, iRam, iThermal, iDate,
          iNetDown, iNetUp, iTimeOfDay, iSun, iMouse, iMouseEnergy, iBattery, iCharging;
} locs_t;

static locs_t get_locs(GLuint p) {
    locs_t l;
    l.iTime = glGetUniformLocation(p, "iTime");
    l.iTimeDelta = glGetUniformLocation(p, "iTimeDelta");
    l.iFrame = glGetUniformLocation(p, "iFrame");
    l.iFrameRate = glGetUniformLocation(p, "iFrameRate");
    l.iResolution = glGetUniformLocation(p, "iResolution");
    l.iChannel0 = glGetUniformLocation(p, "iChannel0");
    l.iChannelRes = glGetUniformLocation(p, "iChannelResolution");
    l.iCpu = glGetUniformLocation(p, "iCpu");
    l.iCpuMax = glGetUniformLocation(p, "iCpuMax");
    l.iRam = glGetUniformLocation(p, "iRam");
    l.iThermal = glGetUniformLocation(p, "iThermal");
    l.iDate = glGetUniformLocation(p, "iDate");
    l.iNetDown = glGetUniformLocation(p, "iNetDown");
    l.iNetUp = glGetUniformLocation(p, "iNetUp");
    l.iTimeOfDay = glGetUniformLocation(p, "iTimeOfDay");
    l.iSun = glGetUniformLocation(p, "iSun");
    l.iMouse = glGetUniformLocation(p, "iMouse");
    l.iMouseEnergy = glGetUniformLocation(p, "iMouseEnergy");
    l.iBattery = glGetUniformLocation(p, "iBattery");
    l.iCharging = glGetUniformLocation(p, "iCharging");
    return l;
}

typedef struct { float cpuavg, net_down, net_up, hour, mouse_e, mouse_x, mouse_y; int chw, chh; float year, month, day; } extra_t;

static void set_uniforms(const locs_t *l, float t, float dt, int frame, float fps, int w, int h,
                         float cpu, float ram, float heat, const extra_t *x) {
    if (l->iTime >= 0) glUniform1f(l->iTime, t);
    if (l->iTimeDelta >= 0) glUniform1f(l->iTimeDelta, dt);
    if (l->iFrame >= 0) glUniform1i(l->iFrame, frame);
    if (l->iFrameRate >= 0) glUniform1f(l->iFrameRate, fps);
    if (l->iResolution >= 0) glUniform3f(l->iResolution, (float)w, (float)h, (float)w / (float)h);
    if (l->iChannel0 >= 0) glUniform1i(l->iChannel0, 0);
    if (l->iChannelRes >= 0) { /* neowall sends a constant 256x256 for every channel */
        float r[12] = {256, 256, 1, 256, 256, 1, 256, 256, 1, 256, 256, 1};
        glUniform3fv(l->iChannelRes, 4, r);
    }
    if (l->iCpu >= 0) glUniform1f(l->iCpu, x->cpuavg >= 0 ? x->cpuavg : cpu);
    if (l->iNetDown >= 0) glUniform1f(l->iNetDown, x->net_down);
    if (l->iNetUp >= 0) glUniform1f(l->iNetUp, x->net_up);
    {
        /* the same maths as neowall's reactive.c sample_time() */
        float hr = fmodf(x->hour, 24.0f);
        if (l->iTimeOfDay >= 0) glUniform1f(l->iTimeOfDay, hr / 24.0f);
        float sun = cosf((hr - 13.0f) * 3.14159265f / 12.0f);
        sun = (sun + 0.15f) / 1.15f;
        if (sun < 0) sun = 0; if (sun > 1) sun = 1;
        if (l->iSun >= 0) glUniform1f(l->iSun, sun);
        if (l->iDate >= 0) glUniform4f(l->iDate, x->year, x->month, x->day, hr * 3600.0f);
    }
    if (l->iMouse >= 0) glUniform4f(l->iMouse, x->mouse_x, x->mouse_y, 0.0f, 0.0f);
    if (l->iMouseEnergy >= 0) glUniform1f(l->iMouseEnergy, x->mouse_e);
    if (l->iBattery >= 0) glUniform1f(l->iBattery, 0.8f);
    if (l->iCharging >= 0) glUniform1f(l->iCharging, 1.0f);
    if (l->iCpuMax >= 0) glUniform1f(l->iCpuMax, cpu);   /* -c drives both */
    if (l->iRam >= 0) glUniform1f(l->iRam, ram);
    if (l->iThermal >= 0) glUniform1f(l->iThermal, heat);
}

static int cmp_double(const void *a, const void *b) { double x = *(const double *)a, y = *(const double *)b; return (x > y) - (x < y); }
/* ---- a fake terminal, standing in for termtest.sh + neowall's term_render ----
 * Packs cells the way term_render.c does (fg/bg as rgb<<8, low bytes 0xFF /
 * attrs), stamps change times in ms, and plays a scripted session. */
#define MAXC 512
#define MAXR 256
static int TC = 160, TR = 45;                 /* the grid: termtest's, or the recording's */
static int CW = 24, CH = 48;                  /* on-screen cell px (font 48); the atlas is 4x */
static uint32_t cells[MAXR * MAXC * 4], prevc[MAXR * MAXC * 4], chg[MAXR * MAXC];
static int have_once = 0;
static uint32_t pack(int r, int g, int b, int low) { return ((uint32_t)r << 24) | ((uint32_t)g << 16) | ((uint32_t)b << 8) | (uint32_t)low; }
static void setcell(int x, int y, int br, int bg, int bb, int fr, int fg, int fb) {
    uint32_t *o = &cells[(y * TC + x) * 4];
    o[0] = 0; o[1] = 0; o[2] = pack(fr, fg, fb, 0xFF); o[3] = pack(br, bg, bb, 0);
}
typedef struct { int beat, clicks, cx, cy, button, scene, hue, clears; } sess_t;
/* scenario: 0 normal, 1 heartbeat stops at 1.0 s, 2 no script at all */
static void play(sess_t *s, float t, int scenario, float *mx, float *my, int W, int H) {
    static float next_beat = 0.1f; static int di = 0;
    if (scenario != 2 && t >= next_beat && !(scenario == 1 && t > 1.0f)) { s->beat = (s->beat + 1) % 256; next_beat += 0.4f; }
    struct { float t; int kind, x, y; } ev[] = {           /* kind: 0 left, 1 middle, 2 right, 64 wheel up */
        {0.5f, 0, 40, 11}, {1.4f, 0, 120, 30}, {3.0f, 64, 120, 30}, {3.05f, 64, 120, 30},
        {3.5f, 2, 80, 22}, {5.0f, 2, 80, 22}, {6.0f, 1, 80, 22}, {1e9f, 0, 0, 0}};
    while (t >= ev[di].t) {
        if (ev[di].kind == 0) { s->clicks = (s->clicks + 1) % 256; s->cx = ev[di].x; s->cy = ev[di].y; s->button = 0; }
        if (ev[di].kind == 1) s->clears = (s->clears + 1) % 256;
        if (ev[di].kind == 2) s->scene = 1 - s->scene;
        if (ev[di].kind == 64) s->hue = (s->hue + 16) % 256;
        di++;
    }
    /* a left drag along row 35, one report per 50 ms, 2.0 .. 2.6 s */
    if (t >= 2.0f && t <= 2.6f) {
        int x = 20 + (int)((t - 2.0f) / 0.6f * 40.0f);
        if (x != s->cx || s->cy != 35) { s->clicks = (s->clicks + 1) % 256; s->cx = x; s->cy = 35; }
    }
    for (int i = 0; i < TR * TC; i++) { uint32_t *o = &cells[i * 4]; o[0] = 0; o[1] = 0; o[2] = pack(208, 208, 208, 0xFF); o[3] = pack(16, 16, 24, 0); }
    if (scenario != 2) {
        setcell(0, 0, s->beat, 78, 87, 208, 208, 208);
        setcell(1, 0, 12, 200, 7, 208, 208, 208);
        setcell(2, 0, s->cx & 255, s->cy & 255, (s->cx >> 8) | ((s->cy >> 8) << 4), s->clicks, s->button, 0);
        setcell(3, 0, s->scene, 0, 0, 208, 208, 208);
        setcell(4, 0, s->hue, s->clears, 0, 208, 208, 208);
    }
    *mx = (s->cx + 0.5f) * W / TC; *my = (s->cy + 0.5f) * H / TR;   /* the pointer sits where it clicked */
}
/* stamp each cell whose record changed; returns whether any did */
static int stamp(uint32_t now_ms) {
    int any = 0;
    for (int i = 0; i < TR * TC; i++) {
        if (have_once && memcmp(&cells[i * 4], &prevc[i * 4], 16) != 0) { chg[i] = now_ms; any = 1; }
        memcpy(&prevc[i * 4], &cells[i * 4], 16);
    }
    if (!have_once) any = 1;
    have_once = 1;
    return any;
}

/* ---- replay: a recording through neowall's own emulator and glyph atlas ---- */
typedef struct { double t; size_t off; uint32_t n; } chunk_t;
static unsigned char *rec; static chunk_t *chunks; static int nchunks, next_chunk;
static term_screen *scr; static glyph_atlas *atlas;
static int atlas_w = 2, atlas_h = 2, cursor_x, cursor_y, cursor_vis;

static void load_rec(const char *path) {
    FILE *f = fopen(path, "rb"); if (!f) { perror(path); exit(1); }
    fseek(f, 0, SEEK_END); long n = ftell(f); fseek(f, 0, SEEK_SET);
    rec = malloc(n + 1); if (fread(rec, 1, n, f) != (size_t)n) { perror("read"); exit(1); } fclose(f);
    int ver = 0, hdr = 0;
    if (sscanf((char *)rec, "NTREC %d %d %d\n%n", &ver, &TC, &TR, &hdr) != 3 || ver != 1 || !hdr) { fprintf(stderr, "%s: not an NTREC 1 recording\n", path); exit(1); }
    if (TC > MAXC || TR > MAXR) { fprintf(stderr, "grid %dx%d too big\n", TC, TR); exit(1); }
    chunks = malloc(sizeof(chunk_t) * (n / 12 + 1));
    for (size_t p = hdr; p + 12 <= (size_t)n; ) {
        chunk_t c; memcpy(&c.t, rec + p, 8); memcpy(&c.n, rec + p + 8, 4); c.off = p + 12;
        if (c.off + c.n > (size_t)n) break;
        chunks[nchunks++] = c; p = c.off + c.n;
    }
    fprintf(stderr, "replay: %s, grid %dx%d, %d chunks over %.1f s\n", path, TC, TR, nchunks, nchunks ? chunks[nchunks - 1].t : 0.0);
}

static void open_atlas(const char *font, int size) {
    CH = size; CW = (size + 1) / 2;      /* neowall's cell for a font size (terminal-mode.md) */
    FILE *f = fopen(font, "rb"); if (!f) { perror(font); exit(1); }
    fseek(f, 0, SEEK_END); long n = ftell(f); fseek(f, 0, SEEK_SET);
    uint8_t *data = malloc(n); if (fread(data, 1, n, f) != (size_t)n) { perror("read"); exit(1); } fclose(f);
    atlas = glyph_atlas_create_ex(data, n, NULL, NULL, CW * 4, CH * 4);    /* term_render's 4x supersample */
    if (!atlas) { fprintf(stderr, "no atlas from %s\n", font); exit(1); }
    atlas_w = glyph_atlas_width(atlas); atlas_h = glyph_atlas_height(atlas);
}

/* term_render.c's palette and colour resolution, copied */
static void palette_rgb(uint8_t idx, uint8_t *r, uint8_t *g, uint8_t *b) {
    static const uint8_t base16[16][3] = {
        {  0,  0,  0}, {205,  0,  0}, {  0,205,  0}, {205,205,  0}, {  0,  0,238}, {205,  0,205}, {  0,205,205}, {229,229,229},
        {127,127,127}, {255,  0,  0}, {  0,255,  0}, {255,255,  0}, { 92, 92,255}, {255,  0,255}, {  0,255,255}, {255,255,255}};
    if (idx < 16) { *r = base16[idx][0]; *g = base16[idx][1]; *b = base16[idx][2]; return; }
    if (idx < 232) { static const uint8_t st[6] = {0, 95, 135, 175, 215, 255}; int c = idx - 16; *r = st[c / 36]; *g = st[(c / 6) % 6]; *b = st[c % 6]; return; }
    *r = *g = *b = (uint8_t)(8 + (idx - 232) * 10);
}
static void resolve(const term_color *c, const uint8_t def[3], uint8_t *r, uint8_t *g, uint8_t *b) {
    if (c->kind == TERM_COLOR_RGB) { *r = c->r; *g = c->g; *b = c->b; }
    else if (c->kind == TERM_COLOR_INDEXED) palette_rgb(c->idx, r, g, b);
    else { *r = def[0]; *g = def[1]; *b = def[2]; }
}
#define PACK_R(ax, ay, has) (((uint32_t)((ax) & 0xFFFu) << 20) | ((uint32_t)((ay) & 0xFFFu) << 8) | ((has) ? 1u : 0u))
#define PACK_G(w, h, ox, oy) (((uint32_t)((w) & 0xFFu) << 24) | ((uint32_t)((h) & 0xFFu) << 16) | ((uint32_t)(((ox) + 128) & 0xFFu) << 8) | ((uint32_t)(((oy) + 128) & 0xFFu)))

/* feed everything printed by time t, then pack the grid as term_render.c does */
static void replay_to(double t) {
    while (next_chunk < nchunks && chunks[next_chunk].t <= t) {
        term_screen_feed(scr, rec + chunks[next_chunk].off, chunks[next_chunk].n);
        char reply[256]; term_screen_take_reply(scr, reply, sizeof reply);   /* neowall answers DSR/DA; nobody listens here */
        next_chunk++;
    }
    static const uint8_t dfg[3] = {200, 200, 200}, dbg[3] = {0, 0, 0};
    int cw4 = CW * 4;
    for (int y = 0; y < TR; y++) {
        const term_cell *row = term_screen_row(scr, y);
        for (int x = 0; x < TC; x++) {
            const term_cell *c = &row[x]; uint32_t *o = &cells[(y * TC + x) * 4];
            bool tail = (c->attr & TERM_ATTR_WIDE_TAIL) != 0;
            uint8_t fr, fg, fb, br, bg, bb;
            resolve(&c->fg, dfg, &fr, &fg, &fb); resolve(&c->bg, dbg, &br, &bg, &bb);
            if (c->attr & TERM_ATTR_REVERSE) { uint8_t a = fr, b2 = fg, d = fb; fr = br; fg = bg; fb = bb; br = a; bg = b2; bb = d; }
            bool has = false, colr = false; uint16_t ax = 0, ay = 0, gw = 0, gh = 0; int16_t ox = 0, oy = 0;
            if (!tail && c->cp != 0 && c->cp != ' ' && !(c->attr & TERM_ATTR_INVISIBLE)) {
                const glyph_slot *s = glyph_atlas_get_styled(atlas, c->cp, (c->attr & TERM_ATTR_BOLD) != 0, (c->attr & TERM_ATTR_ITALIC) != 0);
                if (s && s->valid && s->w > 0 && s->h > 0) { has = true; colr = s->color; ax = s->x; ay = s->y; gw = s->w; gh = s->h; ox = s->off_x; oy = s->off_y; }
            } else if (tail && x > 0 && !(c->attr & TERM_ATTR_INVISIBLE)) {
                const term_cell *hd = &row[x - 1];
                if (hd->cp != 0 && !(hd->attr & TERM_ATTR_INVISIBLE)) {
                    const glyph_slot *s = glyph_atlas_get_styled(atlas, hd->cp, (hd->attr & TERM_ATTR_BOLD) != 0, (hd->attr & TERM_ATTR_ITALIC) != 0);
                    if (s && s->valid && (s->color || s->w > cw4)) { has = true; colr = s->color; ax = s->x; ay = s->y; gw = s->w; gh = s->h; ox = (int16_t)(s->off_x - cw4); oy = s->off_y; }
                }
            }
            o[0] = PACK_R(ax, ay, has) | (colr ? 2u : 0u);
            o[1] = PACK_G(gw, gh, ox, oy);
            o[2] = pack(fr, fg, fb, 0xFF);
            o[3] = pack(br, bg, bb, c->attr & 0xFF);
        }
    }
    term_screen_cursor(scr, &cursor_x, &cursor_y);
    cursor_vis = term_screen_cursor_visible(scr);
}

static void term_uniforms(GLuint p, float now_ms) {
    GLint l;
    if ((l = glGetUniformLocation(p, "iTermAtlas")) >= 0) glUniform1i(l, 5);
    if ((l = glGetUniformLocation(p, "iTermCells")) >= 0) glUniform1i(l, 6);
    if ((l = glGetUniformLocation(p, "iTermColorAtlas")) >= 0) glUniform1i(l, 7);
    if ((l = glGetUniformLocation(p, "iTermChange")) >= 0) glUniform1i(l, 8);
    /* .zw: the SUPERSAMPLED cell (term_render_cell_w/h), as neowall sends it */
    if ((l = glGetUniformLocation(p, "iTermInfo")) >= 0) glUniform4f(l, TC, TR, CW * 4, CH * 4);
    if ((l = glGetUniformLocation(p, "iTermAtlasSize")) >= 0) glUniform2f(l, atlas_w, atlas_h);
    if ((l = glGetUniformLocation(p, "iTermFade")) >= 0) glUniform2f(l, 0.5f, now_ms);
    if ((l = glGetUniformLocation(p, "iTermCursor")) >= 0) glUniform3f(l, cursor_x, cursor_y, cursor_vis ? 1.0f : 0.0f);
    if ((l = glGetUniformLocation(p, "iTermCursorPrev")) >= 0) glUniform4f(l, cursor_x, cursor_y, 0, 0);
}
static GLuint mktex(GLenum ifmt, int w, int h, GLenum fmt, GLenum type, GLenum filter) {
    GLuint t; glGenTextures(1, &t); glBindTexture(GL_TEXTURE_2D, t);
    glTexImage2D(GL_TEXTURE_2D, 0, ifmt, w, h, 0, fmt, type, NULL);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, filter);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, filter);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    return t;
}
static int parse_list(const char *s, float *out, int max) {
    int n = 0; char *d = strdup(s), *sv = NULL;
    for (char *k = strtok_r(d, ",", &sv); k && n < max; k = strtok_r(NULL, ",", &sv)) out[n++] = strtof(k, NULL);
    free(d); return n;
}

int main(int argc, char **argv) {
    int W = 1920, Hh = 1080, scenario = 0, frames = 0, nprint = 6, gate = 0, fontsize = 48; float fps = 60.0f, bufscale = 0.7f; bool timing = false;
    const char *saves = "", *outdir = ".", *prefix = "tt", *recpath = NULL, *font = "/usr/share/fonts/noto/NotoSansMono-Medium.ttf";
    float cpu = 0.1f, cpuavg = -1.0f, hour = 22.0f, trace[32]; int ntrace = 0;
    float seqa = 0, seqb = -1, seqs = 1; const char *probe = NULL;
    extra_t ex = {0}; ex.cpuavg = -1; ex.net_down = ex.net_up = 0.48f; ex.year = 2026; ex.month = 9; ex.day = 29;
    int opt;
    while ((opt = getopt(argc, argv, "w:h:n:s:S:o:p:x:TR:F:z:gb:t:v:D:H:c:C:f:X:Y:q:")) != -1) {
        if (opt == 'w') W = atoi(optarg); else if (opt == 'h') Hh = atoi(optarg);
        else if (opt == 'n') frames = atoi(optarg); else if (opt == 's') saves = optarg;
        else if (opt == 'S') sscanf(optarg, "%f:%f:%f", &seqa, &seqb, &seqs);
        else if (opt == 'o') outdir = optarg; else if (opt == 'p') prefix = optarg;
        else if (opt == 'x') scenario = atoi(optarg); else if (opt == 'T') timing = true;
        else if (opt == 'R') recpath = optarg; else if (opt == 'F') font = optarg; else if (opt == 'z') fontsize = atoi(optarg);
        else if (opt == 'g') gate = 1; else if (opt == 'b') bufscale = strtof(optarg, NULL);
        else if (opt == 't') ntrace = parse_list(optarg, trace, 32); else if (opt == 'v') nprint = atoi(optarg);
        else if (opt == 'D') { float d[3]; if (parse_list(optarg, d, 3) == 3) { ex.year = d[0]; ex.month = d[1]; ex.day = d[2]; } }
        else if (opt == 'H') hour = strtof(optarg, NULL); else if (opt == 'c') cpu = strtof(optarg, NULL);
        else if (opt == 'C') cpuavg = strtof(optarg, NULL); else if (opt == 'f') fps = strtof(optarg, NULL);
        else if (opt == 'q') probe = optarg;
        else if (opt == 'X') ex.mouse_x = strtof(optarg, NULL); else if (opt == 'Y') ex.mouse_y = strtof(optarg, NULL);
    }
    ex.hour = hour; ex.cpuavg = cpuavg;
    int save_f[4096], ns = 0; float last = 0;
    { float st[256]; int k = parse_list(saves, st, 256); for (int i = 0; i < k; i++) { save_f[ns++] = (int)lroundf(st[i] * fps); if (st[i] > last) last = st[i]; } }
    if (seqb >= seqa) for (float s = seqa; s <= seqb + 1e-4f && ns < 4096; s += seqs) { save_f[ns++] = (int)lroundf(s * fps); if (s > last) last = s; }
    if (frames <= 0) frames = (int)lroundf(last * fps) + 1;

    PFNEGLGETPLATFORMDISPLAYEXTPROC gpd = (PFNEGLGETPLATFORMDISPLAYEXTPROC)eglGetProcAddress("eglGetPlatformDisplayEXT");
    EGLDisplay dpy = gpd(EGL_PLATFORM_SURFACELESS_MESA, EGL_DEFAULT_DISPLAY, NULL);
    EGLint maj, min; if (!eglInitialize(dpy, &maj, &min)) return 1;
    eglBindAPI(EGL_OPENGL_API);
    EGLint ca[] = {EGL_CONTEXT_MAJOR_VERSION, 3, EGL_CONTEXT_MINOR_VERSION, 3, EGL_CONTEXT_OPENGL_PROFILE_MASK, EGL_CONTEXT_OPENGL_CORE_PROFILE_BIT, EGL_NONE};
    EGLContext ctx = eglCreateContext(dpy, EGL_NO_CONFIG_KHR, EGL_NO_CONTEXT, ca);
    if (!eglMakeCurrent(dpy, EGL_NO_SURFACE, EGL_NO_SURFACE, ctx)) return 1;

    char *src = read_file(argv[optind]);
    multipass_parse_result_t *pr = multipass_parse_shader(src);
    int ia = -1, ii = -1;
    for (int i = 0; i < pr->pass_count; i++) { if (pr->pass_types[i] == PASS_TYPE_BUFFER_A) ia = i; if (pr->pass_types[i] == PASS_TYPE_IMAGE) ii = i; }
    if (ia < 0 || ii < 0) { fprintf(stderr, "need a Buffer A and an Image pass (found %d passes)\n", pr->pass_count); return 2; }
    GLuint pa = link_prog(wrap_pass_source(pr->common_source, pr->pass_sources[ia], NULL), "Buffer A");
    GLuint pi = link_prog(wrap_pass_source(pr->common_source, pr->pass_sources[ii], NULL), "Image");
    locs_t la = get_locs(pa), li = get_locs(pi);

    if (recpath) { load_rec(recpath); open_atlas(font, fontsize); scr = term_screen_create(TC, TR); }

    GLuint vao; glGenVertexArrays(1, &vao); glBindVertexArray(vao);
    int BW = ((int)(W * bufscale)) & ~1, BH = ((int)(Hh * bufscale)) & ~1;       /* neowall's self-buffer size */
    GLuint btex[2], bfbo[2], itex, ifbo;
    glGenTextures(2, btex); glGenFramebuffers(2, bfbo);
    for (int i = 0; i < 2; i++) {
        glBindTexture(GL_TEXTURE_2D, btex[i]);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA16F, BW, BH, 0, GL_RGBA, GL_HALF_FLOAT, NULL);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glBindFramebuffer(GL_FRAMEBUFFER, bfbo[i]);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, btex[i], 0);
        glClearColor(0, 0, 0, 1); glClear(GL_COLOR_BUFFER_BIT);
    }
    glGenTextures(1, &itex); glBindTexture(GL_TEXTURE_2D, itex);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, W, Hh, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    glGenFramebuffers(1, &ifbo); glBindFramebuffer(GL_FRAMEBUFFER, ifbo);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, itex, 0);
    GLuint tcell = mktex(GL_RGBA32UI, TC, TR, GL_RGBA_INTEGER, GL_UNSIGNED_INT, GL_NEAREST);
    GLuint tchg  = mktex(GL_R32UI, TC, TR, GL_RED_INTEGER, GL_UNSIGNED_INT, GL_NEAREST);
    GLuint tat   = mktex(GL_R8, atlas_w, atlas_h, GL_RED, GL_UNSIGNED_BYTE, GL_LINEAR);   /* neowall: LINEAR */
    GLuint tcat  = mktex(GL_RGBA8, 2, 2, GL_RGBA, GL_UNSIGNED_BYTE, GL_LINEAR);
    glActiveTexture(GL_TEXTURE5); glBindTexture(GL_TEXTURE_2D, tat);
    glActiveTexture(GL_TEXTURE6); glBindTexture(GL_TEXTURE_2D, tcell);
    glActiveTexture(GL_TEXTURE7); glBindTexture(GL_TEXTURE_2D, tcat);
    glActiveTexture(GL_TEXTURE8); glBindTexture(GL_TEXTURE_2D, tchg);

    GLuint q[2]; glGenQueries(2, q);
    double ta = 0, tim = 0; int nt = 0, drawn = 0; static double ims[100000];
    unsigned char *pix = malloc((size_t)W * Hh * 4);
    sess_t ss = {0}; int wi = 0; float step = 1.0f / fps, last_change = -1e9f, last_drawn = -1e9f;
    for (int f = 0; f < frames; f++) {
        float t = f * step;
        float now_ms = 200.0f + t * 1000.0f;        /* the terminal's clock started a little earlier */
        if (recpath) replay_to(t); else play(&ss, t, scenario, &ex.mouse_x, &ex.mouse_y, W, Hh);
        if (stamp((uint32_t)now_ms)) last_change = t;
        bool want_save = false;
        for (int s = 0; s < ns; s++) if (save_f[s] == f) want_save = true;
        /* neowall's idle gate: nothing drawn (and no time passes for the shader's
         * iTimeDelta) unless the grid changed within the last 700 ms */
        if (gate && t - last_change >= 0.7f) {
            if (want_save) {   /* the screen still shows the last frame drawn */
                glBindFramebuffer(GL_FRAMEBUFFER, ifbo); glReadPixels(0, 0, W, Hh, GL_RGBA, GL_UNSIGNED_BYTE, pix);
                char path[4096]; snprintf(path, sizeof path, "%s/%s_%05.2f.png", outdir, prefix, t); save_png(path, W, Hh, pix);
            }
            continue;
        }
        float dt = gate ? fminf(t - last_drawn, 0.25f) : step;
        if (drawn == 0) dt = step;
        last_drawn = t;
        if (recpath && glyph_atlas_dirty(atlas)) {
            glActiveTexture(GL_TEXTURE5); glBindTexture(GL_TEXTURE_2D, tat); glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
            glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, atlas_w, atlas_h, GL_RED, GL_UNSIGNED_BYTE, glyph_atlas_bitmap(atlas));
            glyph_atlas_clear_dirty(atlas);
        }
        glActiveTexture(GL_TEXTURE6); glBindTexture(GL_TEXTURE_2D, tcell);
        glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, TC, TR, GL_RGBA_INTEGER, GL_UNSIGNED_INT, cells);
        glActiveTexture(GL_TEXTURE8); glBindTexture(GL_TEXTURE_2D, tchg);
        glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, TC, TR, GL_RED_INTEGER, GL_UNSIGNED_INT, chg);
        if (timing) glBeginQuery(GL_TIME_ELAPSED, q[0]);
        glBindFramebuffer(GL_FRAMEBUFFER, bfbo[wi]); glViewport(0, 0, BW, BH);
        glUseProgram(pa);
        glActiveTexture(GL_TEXTURE0); glBindTexture(GL_TEXTURE_2D, btex[1 - wi]);   /* self: last frame */
        set_uniforms(&la, t, dt, drawn, fps, BW, BH, cpu, 0.4f, 0.35f, &ex); term_uniforms(pa, now_ms);
        glDrawArrays(GL_TRIANGLES, 0, 3);
        if (timing) { glEndQuery(GL_TIME_ELAPSED); glBeginQuery(GL_TIME_ELAPSED, q[1]); }
        glBindFramebuffer(GL_FRAMEBUFFER, ifbo); glViewport(0, 0, W, Hh);
        glUseProgram(pi);
        glActiveTexture(GL_TEXTURE0); glBindTexture(GL_TEXTURE_2D, btex[wi]);       /* Buffer A, this frame */
        set_uniforms(&li, t, dt, drawn, fps, W, Hh, cpu, 0.4f, 0.35f, &ex); term_uniforms(pi, now_ms);
        glDrawArrays(GL_TRIANGLES, 0, 3);
        if (timing) {
            glEndQuery(GL_TIME_ELAPSED); GLuint64 na = 0, ni = 0;
            glGetQueryObjectui64v(q[0], GL_QUERY_RESULT, &na); glGetQueryObjectui64v(q[1], GL_QUERY_RESULT, &ni);
            if (drawn >= 10 && nt < 100000) { ta += na / 1e6; tim += ni / 1e6; ims[nt] = ni / 1e6; nt++; }
        }
        GLenum e = glGetError(); if (e) { fprintf(stderr, "GL error 0x%x at frame %d\n", e, f); return 3; }
        if (ntrace) {
            float st[4]; glBindFramebuffer(GL_FRAMEBUFFER, bfbo[wi]);
            printf("%7.3f", t);
            for (int k = 0; k < ntrace; k++) { glReadPixels((int)trace[k], 0, 1, 1, GL_RGBA, GL_FLOAT, st); printf("  [%d] %.4f %.4f %.4f %.4f", (int)trace[k], st[0], st[1], st[2], st[3]); }
            printf("\n");
        }
        if (want_save) {
            glBindFramebuffer(GL_FRAMEBUFFER, ifbo);
            glReadPixels(0, 0, W, Hh, GL_RGBA, GL_UNSIGNED_BYTE, pix);
            char path[4096]; snprintf(path, sizeof path, "%s/%s_%05.2f.png", outdir, prefix, t); save_png(path, W, Hh, pix);
        }
        wi = 1 - wi; drawn++;
        if ((drawn & 7) == 7) glFinish();
    }
    glFinish();
    if (nprint > 0) {
        float *st = malloc(sizeof(float) * 4 * nprint); glBindFramebuffer(GL_FRAMEBUFFER, bfbo[1 - wi]);
        glReadPixels(0, 0, nprint, 1, GL_RGBA, GL_FLOAT, st);
        for (int i = 0; i < nprint; i++) printf("texel %2d  %.4f %.4f %.4f %.4f\n", i, st[i*4], st[i*4+1], st[i*4+2], st[i*4+3]);
    }
    if (probe) {
        char *d = strdup(probe), *sv = NULL; float st[4]; glBindFramebuffer(GL_FRAMEBUFFER, bfbo[1 - wi]);
        for (char *k = strtok_r(d, ",", &sv); k; k = strtok_r(NULL, ",", &sv)) {
            int x = 0, y = 0; if (sscanf(k, "%d:%d", &x, &y) != 2) continue;
            glReadPixels(x, y, 1, 1, GL_RGBA, GL_FLOAT, st);
            printf("texel %d:%d  %.4f %.4f %.4f %.4f\n", x, y, st[0], st[1], st[2], st[3]);
        }
        free(d);
    }
    printf("frames drawn %d of %d\n", drawn, frames);
    if (timing && nt) { qsort(ims, nt, sizeof(double), cmp_double); printf("%dx%d: bufferA mean %.3f ms, image mean %.3f ms, p10 %.3f, p50 %.3f (%d frames)\n", W, Hh, ta / nt, tim / nt, ims[nt / 10], ims[nt / 2], nt); }
    return 0;
}
