// termtest.glsl: a test of neowall's terminal mode, not a wallpaper. It
// answers three questions before anything real gets built on it:
//
//   1. Does Buffer A remember? In terminal mode neowall reads no sidecar
//      file, so it guesses what each pass reads from its source text (see
//      "Channel binding", below). The clock in the top-left corner only
//      turns if Buffer A gets its own last frame back.
//   2. Does the heartbeat keep frames coming? neowall stops drawing a
//      terminal wallpaper 0.7 s after the terminal last changed, whatever
//      the shader is doing. termtest.sh changes one cell every 0.4 s. If
//      that works, the soft light drifting across the water never stops.
//   3. Do clicks land where you click? Click anywhere: the script is told
//      which cell you clicked, and the shader starts a ripple there and
//      draws a box round that cell. The box should sit right under the
//      pointer, whose own cell has a fainter box.
//
// The corner has three lamps, left to right:
//   heartbeat    green: beating. red: whatever's running isn't termtest.sh.
//                (amber, beat late, is rare: without a beat neowall stops
//                drawing, so the screen just freezes, which is the sign)
//   exact bytes  green if cell 1 reads exactly (12, 200, 7)
//   memory       a clock: its hand turns steadily if Buffer A remembers
//
// If the drifting light moves but the clock doesn't, Buffer A isn't
// remembering. If both freeze, frames have stopped: the heartbeat isn't
// getting through.
//
// Right click (or key 2) switches to the second scene: the raw terminal,
// shown over the water, so you can see what the script printed. Its top
// row of data cells shows up there as small coloured blocks.
//
// termtest.sh is the other half; termtest.vibe says how to run it.

// ============================================================================
// SETTINGS
// ============================================================================

// --- colours: the Kanagawa Wave ones this uses (from colors.glsl)
const vec3 sumiInk0     = vec3(0.086, 0.086, 0.114);  // #16161D
const vec3 waveBlue1    = vec3(0.133, 0.196, 0.286);  // #223249
const vec3 fujiWhite    = vec3(0.863, 0.843, 0.729);  // #DCD7BA
const vec3 springBlue   = vec3(0.498, 0.706, 0.792);  // #7FB4CA
const vec3 sakuraPink   = vec3(0.824, 0.494, 0.600);  // #D27E99
const vec3 carpYellow   = vec3(0.902, 0.765, 0.518);  // #E6C384
const vec3 springGreen  = vec3(0.596, 0.733, 0.424);  // #98BB6C
const vec3 oniViolet    = vec3(0.584, 0.498, 0.722);  // #957FB8
const vec3 autumnYellow = vec3(0.863, 0.647, 0.380);  // #DCA561
const vec3 autumnRed    = vec3(0.765, 0.251, 0.263);  // #C34043

// --- the ripples
const int   GRID_ROWS   = 270;    // ripple grid points, top to bottom
const int   GRID_COLS   = 480;    // ...and across
const float WAVE_C2     = 0.40;   // how fast ripples spread (keep under 0.5, or it blows up)
const float WAVE_DAMP   = 0.015;  // how fast they die away (share lost a frame)
const float POKE_DEPTH  = 2.5;    // how hard a click hits the water
const float POKE_RADIUS = 2.5;    // how wide, in grid points
const float SLOPE       = 6.0;    // how steep the ripples look to the light

// --- timings (the terminal's clock counts milliseconds)
const float BEAT_LATE_MS  = 1500.0;  // no heartbeat for this long: the lamp goes amber
const float SCENE_FADE_MS = 600.0;   // how long a scene change takes
const float CLICK_BOX_MS  = 1500.0;  // how long the clicked cell keeps its box

// --- the lamps in the corner, in screen heights from the top-left corner
const float LAMP_R   = 0.014;              // their radius
const float LAMP_GAP = 0.045;              // from one's middle to the next's
const vec2  LAMP_AT  = vec2(0.035, 0.035); // the first one's middle

// ============================================================================
// Everything below is how it works.
// ============================================================================

const float TAU = 6.28318531;

// Hex colours are gamma-encoded: square them before lighting, square-root
// once at the end (orbit3d.glsl has the longer version).
vec3 toLinear(vec3 c) { return c * c; }

// ----------------------------------------------------------------------------
// The terminal's top row: the data cells termtest.sh prints. Each carries
// three bytes as its background colour (and H_CLICK three more as its
// foreground). Cells count from 0, left to right, and rows from 0 at the top.
const ivec2 H_BEAT  = ivec2(0, 0);   // (beat, 78, 87): 78, 87 is "NW", the script's marker
const ivec2 H_TEST  = ivec2(1, 0);   // always (12, 200, 7)
const ivec2 H_CLICK = ivec2(2, 0);   // the last click: see clickCell()
const ivec2 H_SCENE = ivec2(3, 0);   // (scene, 0, 0): 0 the water, 1 the raw terminal
const ivec2 H_MODE  = ivec2(4, 0);   // (hue, clears, 0): ripple colour, and "calm the water" count

// ----------------------------------------------------------------------------
// Buffer A's layout: row 0 holds what it remembers and what it works out for
// the drawing pass; the ripple grid starts at row GRID_Y0.
const int S_MARK  = 0;   // the "this was remembered" marker, 0.75 in .a (as in koi)
const int S_CLOCK = 1;   // the clock's phase in turns: coarse and fine part
const int S_CLICK = 2;   // the last click seen: count, cell x, cell y, and 1 on the frame it's new
const int S_CLEAR = 3;   // clears seen: count, and 1 on the frame one's new
// Two texels for the drawing pass: everything that's the same for every
// pixel is worked out here once, not 8 million times a frame (at 4K, ~10
// instructions a pixel cost ~0.5 ms). Picking the ripple colour per pixel
// cost 1.4 ms on its own.
const int D_VIEW  = 4;   // the ripple colour (linear rgb), how far into scene 2
const int D_VIEW2 = 5;   // the clicked cell (x, y), how bright its box is, and the lamps (see lampCode)
const int S_COUNT = 6;
const int GRID_Y0 = 2;

vec4 state(int i) { return texelFetch(iChannel0, ivec2(i, 0), 0); }

// A number that grows a little every frame, kept in two parts so a half
// float can hold it smoothly (orbit3d explains why).
vec2 accumulate(vec2 hilo, float step) {
    float lo    = hilo.y + step;
    float carry = floor(lo * 256.0) / 256.0;
    return vec2(fract(hilo.x + carry), lo - carry);
}

// ----------------------------------------------------------------------------
// Reading the terminal
//
// iTermCells holds one record per cell, four whole numbers (neowall's
// term_render.c packs them): .b is the foreground colour and .a the
// background, each red << 24 | green << 16 | blue << 8, with 8 bits of style
// in the background's lowest byte. It's an integer texture, so the colours
// arrive exactly as printed: no half-float rounding, no filtering.
uvec3 cellBg(ivec2 c) {
    uint a = texelFetch(iTermCells, c, 0).a;
    return uvec3(a >> 24, (a >> 16) & 255u, (a >> 8) & 255u);
}
uvec3 cellFg(ivec2 c) {
    uint b = texelFetch(iTermCells, c, 0).b;
    return uvec3(b >> 24, (b >> 16) & 255u, (b >> 8) & 255u);
}

// How long ago a cell last changed, in ms. iTermChange stamps each cell with
// the terminal's clock whenever its record changes, and iTermFade.y is that
// clock now. (A cell unchanged since the first frame reads 0, which comes out
// as "a long time ago".)
float cellAgeMs(ivec2 c) {
    return iTermFade.y - float(texelFetch(iTermChange, c, 0).r);
}

// Is termtest.sh the one running? Its heartbeat cell carries the marker.
bool scriptRunning() {
    uvec3 b = cellBg(H_BEAT);
    return iTermInfo.x >= 1.0 && b.g == 78u && b.b == 87u;
}

// the terminal's grid, columns x rows (never 0, so it's safe to divide by)
vec2 termGrid() { return max(iTermInfo.xy, vec2(1.0)); }

// The last click, from H_CLICK: its background is (column & 255, row & 255,
// the two's high bits), so grids past 256 cells work too.
vec2 clickCell() {
    uvec3 b = cellBg(H_CLICK);
    return vec2(float(b.r | ((b.b & 15u) << 8)), float(b.g | ((b.b >> 4) << 8)));
}

// A terminal cell's middle -> ripple grid points. Cells count rows down from
// the top, the grid up from the bottom, like everything else in GL.
vec2 cellToGrid(vec2 cell) {
    vec2 uv = (cell + 0.5) / termGrid();
    return vec2(uv.x, 1.0 - uv.y) * vec2(GRID_COLS, GRID_ROWS);
}

// The ripple colour the scroll wheel picks: five Kanagawa colours, round and round.
vec3 hueColour(float h) {
    vec3  c[5] = vec3[5](springBlue, sakuraPink, carpYellow, springGreen, oniViolet);
    float x = fract(h) * 5.0;
    int   i = int(x);
    return toLinear(mix(c[i], c[(i + 1) % 5], smoothstep(0.0, 1.0, fract(x))));
}

// The lamps, as one whole number (half floats hold those exactly): the
// heartbeat's state, 0 red, 1 amber, 2 green, plus 3 if the test bytes came
// through exact.
float lampCode(bool ok) {
    float heart = !ok ? 0.0 : (cellAgeMs(H_BEAT) < BEAT_LATE_MS ? 2.0 : 1.0);
    bool  exact = ok && cellBg(H_TEST) == uvec3(12u, 200u, 7u);
    return heart + (exact ? 3.0 : 0.0);
}

// ----------------------------------------------------------------------------
// Channel binding
//
// With a normal shader, koi.neowall says "Buffer A reads itself". In
// terminal mode neowall reads no sidecar file: it guesses each pass's inputs
// from the source text instead, and for Buffer A it only looks at the text
// of Buffer A's own mainImage, not at the helpers above it. It decides
// channel 0 is Buffer A's own last frame if that mainImage reads channel 0
// itself, and nothing after the read looks to it like a noise-texture
// lookup: a division by 256, 512 or 1024, or a multiplication by a number
// starting 0.00. If it never sees channel 0 read there at all, it binds a
// noise texture instead, and nothing is remembered: koi.glsl as it stands
// would get that, because its reads are all inside state().
//
// So Buffer A's mainImage below reads its own texel on its first line, and
// keeps those patterns out of the rest of it. With `neowall -f -v` the log
// says what it decided: "Pass 0 (Buffer A): ch0=Self" is the line to see.

// The state row, texel by texel
vec4 stateTexel(int i, vec4 prev, bool fresh) {
    float dt = min(iTimeDelta, 0.05);
    bool  ok = scriptRunning();
    if (i == S_MARK) return vec4(0.0, 0.0, 0.0, 0.75);
    // the clock: half a turn a second, added up a frame at a time
    if (i == S_CLOCK) return vec4(accumulate(fresh ? vec2(0.0) : prev.xy, 0.5 * dt), 0.0, 0.0);
    if (i == S_CLICK) {
        // a new click is a new count; the frame after, the ripple cells see
        // the 1 in .w and poke the water
        float n = float(cellFg(H_CLICK).r);
        return vec4(n, clickCell(), (!fresh && ok && n != prev.x) ? 1.0 : 0.0);
    }
    if (i == S_CLEAR) {
        float n = float(cellBg(H_MODE).g);
        return vec4(n, (!fresh && ok && n != prev.x) ? 1.0 : 0.0, 0.0, 0.0);
    }
    if (i == D_VIEW) {
        // Scene changes fade in from the moment the scene cell changed. The
        // raw terminal is also what shows when termtest.sh isn't running, so
        // you can see what is (a shell error, say).
        float t      = smoothstep(0.0, SCENE_FADE_MS, cellAgeMs(H_SCENE));
        float scene2 = !ok ? 1.0 : (cellBg(H_SCENE).r == 1u ? t : 1.0 - t);
        return vec4(hueColour(ok ? float(cellBg(H_MODE).r) / 255.0 : 0.0), scene2);
    }
    if (i == D_VIEW2) {
        // The clicked cell's box fades over CLICK_BOX_MS. The click count
        // runs 1..255, so 0 means no click yet: no box.
        float box = (ok && cellFg(H_CLICK).r != 0u)
                  ? 1.0 - smoothstep(0.0, CLICK_BOX_MS, cellAgeMs(H_CLICK)) : 0.0;
        return vec4(clickCell(), box, lampCode(ok));
    }
    return vec4(0.0);
}

// One ripple grid point: the wave equation, as in koi (with four neighbours
// rather than eight: this is only a test). .r is the height now, .g a frame
// ago, .ba the slope, for the light.
vec4 rippleCell(ivec2 g, vec4 c, bool fresh) {
    if (fresh || state(S_CLEAR).y > 0.5) return vec4(0.0);
    ivec2 p  = g + ivec2(0, GRID_Y0);
    ivec2 lo = ivec2(0, GRID_Y0), hi = ivec2(GRID_COLS - 1, GRID_Y0 + GRID_ROWS - 1);
    float e = texelFetch(iChannel0, min(p + ivec2(1, 0), hi), 0).r;
    float w = texelFetch(iChannel0, max(p - ivec2(1, 0), lo), 0).r;
    float n = texelFetch(iChannel0, min(p + ivec2(0, 1), hi), 0).r;
    float s = texelFetch(iChannel0, max(p - ivec2(0, 1), lo), 0).r;
    // keep moving, less a little, and get pulled toward the neighbours
    float h = c.r + (c.r - c.g) * (1.0 - WAVE_DAMP) + WAVE_C2 * (e + w + n + s - 4.0 * c.r);
    vec4 ck = state(S_CLICK);
    if (ck.w > 0.5) {
        // a dip with a raised rim, which adds no water overall (as in koi)
        vec2  d  = (vec2(g) + 0.5 - cellToGrid(ck.yz)) / POKE_RADIUS;
        float d2 = dot(d, d);
        if (d2 < 16.0) h -= POKE_DEPTH * (exp(-d2) - 0.5 * exp(-0.5 * d2));
    }
    return vec4(h, c.r, 0.5 * (e - w), 0.5 * (n - s));
}

// Buffer A: the simulation
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // This texel's last frame, read right here and not only in a helper:
    // it's how neowall learns this pass reads itself ("Channel binding").
    vec4  prev  = texelFetch(iChannel0, ivec2(fragCoord), 0);
    ivec2 px    = ivec2(fragCoord);
    bool  fresh = iFrame == 0 || state(S_MARK).a != 0.75;
    if (px.y == 0) {
        if (px.x >= S_COUNT) discard;
        fragColor = stateTexel(px.x, prev, fresh);
        return;
    }
    ivec2 g = px - ivec2(0, GRID_Y0);
    if (g.y < 0 || g.x >= GRID_COLS || g.y >= GRID_ROWS) discard;
    fragColor = rippleCell(g, prev, fresh);
}

// ===== drawing helpers =====
// neowall gives code placed between the two mainImage functions to the
// second pass only.

// the ripple grid at a spot on the screen (uv 0..1, y up), smoothly
vec4 rippleAt(vec2 uv, vec2 bufSize) {
    vec2 g = clamp(uv * vec2(GRID_COLS, GRID_ROWS), vec2(0.5), vec2(GRID_COLS, GRID_ROWS) - 0.5);
    return texture(iChannel0, (g + vec2(0.0, float(GRID_Y0))) / bufSize);
}

// A box just inside a cell's edge: 1 on the edge, fading to 0 `width` pixels
// in. f is where this pixel sits in its cell, 0..1 each way.
float cellEdge(vec2 f, vec2 cellPx, float width) {
    vec2 d = min(f, 1.0 - f) * cellPx;        // pixels to the nearest side, each way
    return 1.0 - smoothstep(0.0, width, min(d.x, d.y));
}

// a disc with a soft edge a pixel wide
float disc(vec2 p, vec2 at, float r, float px) { return 1.0 - smoothstep(r - px, r + px, length(p - at)); }

// Image: the screen, drawn from the simulation (neowall finds each pass by a
// comment like this just above it, so keep other pass names out of it)
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 bs = vec2(textureSize(iChannel0, 0));
    vec4 V  = state(D_VIEW);      // the ripple colour, how far into scene 2
    vec4 V2 = state(D_VIEW2);     // the clicked cell, its box, the lamps

    // ---- the water: dark, lit by one soft light drifting round. It runs
    // on iTime, so it moves whenever frames are drawn, memory or not.
    vec4  w       = rippleAt(uv, bs);
    vec3  n       = normalize(vec3(-w.ba * SLOPE, 1.0));
    vec2  lightAt = vec2(0.5) + vec2(0.28, 0.22) * vec2(cos(0.25 * iTime), sin(0.25 * iTime));
    float pool    = exp(-8.0 * dot(uv - lightAt, uv - lightAt));
    vec3  L       = normalize(vec3(lightAt - uv, 0.6));
    float lit     = max(dot(n, L), 0.0);
    float spec    = max(dot(reflect(vec3(0.0, 0.0, -1.0), n), L), 0.0);
    spec *= spec; spec *= spec; spec *= spec; spec *= spec;     // ^16, without pow
    vec3  col     = toLinear(sumiInk0) + toLinear(waveBlue1) * (0.35 + 0.9 * pool * lit)
                  + V.rgb * (0.8 * spec * (0.3 + pool) + 0.5 * abs(w.r));

    // ---- boxes: the cell under the pointer (faint), and the cell the script
    // says was clicked (bright, fading). Only pixels inside those two cells
    // do any of this: with boxes worked out everywhere, they cost 1.8 ms.
    // iMouse counts pixels down from the top, like the terminal's rows.
    vec2 grid   = termGrid();
    vec2 cellPx = iResolution.xy / grid;
    vec2 q      = vec2(uv.x, 1.0 - uv.y) * grid;            // this pixel, in cells
    vec2 cell   = floor(q);
    if (cell == floor(iMouse.xy / cellPx)) col += toLinear(fujiWhite) * 0.25 * cellEdge(q - cell, cellPx, 1.5);
    if (cell == V2.xy && V2.z > 0.0)      col += V.rgb * 1.2 * V2.z * cellEdge(q - cell, cellPx, 3.0);

    // ---- scene 2: the raw terminal, over the water
    if (V.a > 0.001) col = mix(col, toLinear(nwTerm(uv)), 0.9 * V.a);

    // ---- the lamps, top left
    float H = iResolution.y;
    vec2  p = vec2(fragCoord.x, H - fragCoord.y) / H;      // from the top-left, in screen heights
    if (p.x < LAMP_AT.x + 2.0 * LAMP_GAP + 2.0 * LAMP_R && p.y < LAMP_AT.y + 2.0 * LAMP_R) {
        float px1 = 1.0 / H;
        vec2  a0 = LAMP_AT, a1 = LAMP_AT + vec2(LAMP_GAP, 0.0), a2 = LAMP_AT + vec2(2.0 * LAMP_GAP, 0.0);
        bool  exact   = V2.w > 2.5;                           // see lampCode
        float heart   = V2.w - (exact ? 3.0 : 0.0);           // 0 red, 1 amber, 2 green
        vec3  heartCol = heart > 1.5 ? springGreen : (heart > 0.5 ? autumnYellow : autumnRed);
        col = mix(col, toLinear(heartCol), disc(p, a0, LAMP_R, px1));
        col = mix(col, toLinear(exact ? springGreen : autumnRed), disc(p, a1, LAMP_R, px1));
        // the clock: a ring, and a hand at the phase Buffer A remembers
        vec4  ck    = state(S_CLOCK);
        float ang   = TAU * (ck.x + ck.y);
        vec2  dir   = vec2(sin(ang), -cos(ang));           // clockwise from 12 (y runs down here)
        vec2  rel   = p - a2;
        float ring  = abs(length(rel) - 0.9 * LAMP_R);
        float hand  = length(rel - dir * clamp(dot(rel, dir), 0.0, 0.8 * LAMP_R));
        float ink   = max(1.0 - smoothstep(px1, 2.5 * px1, ring), 1.0 - smoothstep(px1, 3.0 * px1, hand));
        col = mix(col, toLinear(fujiWhite), ink);
    }

    // ---- out: re-encode, and dither so the dark water doesn't band
    col = sqrt(max(col, 0.0));
    col += (fract(52.9829189 * fract(dot(fragCoord, vec2(0.06711056, 0.00583715)))) - 0.5) / 255.0;
    fragColor = vec4(col, 1.0);
}
