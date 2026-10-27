// contour.glsl — a topographic map for the Liquid shell: hairline contours over dark ground,
// coloured by height along the window border's gradient (cyan in the valleys, through blue and
// violet, to pink on the peaks), every fifth line heavier, as survey maps draw them. The land
// holds still while the water rises through it: each line creeps slowly uphill and closes up at
// the top, and the next one comes up behind it.
//
// Two passes (contour.neowall). The terrain is costly, so Buffer A paints it once, a strip a
// frame, into each of its two textures, and from then on discards every pixel (neowall never
// clears a buffer after its first frame, so a discarded pixel keeps what it had). The Image pass
// draws the lines from it, which is cheap.

#define INK0   vec3(0.086, 0.086, 0.114)   // #16161D sumiInk0, the shell's frame
#define INK1   vec3(0.122, 0.122, 0.157)   // #1F1F28
#define WAVE1  vec3(0.133, 0.196, 0.286)   // #223249
#define CYAN   vec3(0.498, 0.706, 0.792)   // #7FB4CA
#define BLUE   vec3(0.494, 0.612, 0.847)   // #7E9CD8
#define VIOLET vec3(0.584, 0.498, 0.722)   // #957FB8
#define PINK   vec3(0.824, 0.494, 0.600)   // #D27E99

#define CO_STRIPS 8.0     // Buffer A paints one strip in this many a frame, each into both textures
#define CO_FADE 24.0      // then the map fades in over this many frames
#define CO_LINES 26.0     // contour lines from the lowest ground to the highest
#define CO_RISE 75.0      // seconds for the water to rise one line

float coHash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// Value noise with a quintic fade, so contours drawn through it don't kink at the lattice.
float coNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = p - i;
    vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    return mix(mix(coHash(i), coHash(i + vec2(1.0, 0.0)), u.x),
               mix(coHash(i + vec2(0.0, 1.0)), coHash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Rotating each octave hides the value-noise grid.
float coFbm(vec2 p, int octaves) {
    const mat2 R = mat2(1.60, 1.20, -1.20, 1.60);
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 8; i++) {
        if (i >= octaves) break;
        v += a * coNoise(p);
        p = R * p;
        a *= 0.5;
    }
    return v;
}

// The border's four stops, s from 0 (cyan) to 1 (pink).
vec3 coBorder(float s) {
    s = clamp(s, 0.0, 1.0) * 3.0;
    vec3 c = mix(CYAN, BLUE, clamp(s, 0.0, 1.0));
    c = mix(c, VIOLET, clamp(s - 1.0, 0.0, 1.0));
    return mix(c, PINK, clamp(s - 2.0, 0.0, 1.0));
}

// The land, 0 to 1, in screen heights from the centre: rolling hills worn into ridges, with a
// range of higher ground running the border's diagonal.
float coLand(vec2 p) {
    vec2 q = p * 1.7 + vec2(4.7, 1.9);
    vec2 w = vec2(coFbm(q + vec2(1.3, 7.1), 3), coFbm(q + vec2(6.2, 2.4), 3));
    float h = coFbm(q + 0.9 * w, 5);
    vec2 d = mat2(0.7071, 0.7071, -0.7071, 0.7071) * (p - vec2(0.05, 0.0));
    h += 0.22 * exp(-d.y * d.y * 9.0) - 0.08;
    return clamp(h * 1.25 - 0.18, 0.0, 1.0);
}

float coVignette(vec2 uv) {
    vec2 v = (uv - vec2(0.5, 0.49)) * vec2(1.1, 1.4);
    return 0.45 + 0.55 * smoothstep(1.05, 0.35, length(v));
}

// Buffer A: the land, painted a strip a frame until both textures hold all of it
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // Texel (0, 0), under the shell's frame, counts the frames painted so far, marked so neither
    // a fresh buffer, cleared to (0, 0, 0, 1), nor junk reads as a count. Frames 2n and 2n + 1
    // paint strip n, one into each texture; once every strip is in, every pixel is discarded.
    vec4 state = texelFetch(iChannel0, ivec2(0), 0);
    float done = state.g == 0.625 ? state.r : 0.0;
    if (ivec2(gl_FragCoord.xy) == ivec2(0)) {
        fragColor = vec4(min(done + 1.0, 2.0 * CO_STRIPS + CO_FADE), 0.625, 0.0, 0.0);
        return;
    }
    // Strips break on even rows: the slope below comes from each 2x2 quad of pixels, so a quad
    // split between a strip being painted and one discarded would get a garbage slope (a seam).
    float strip = floor(floor(gl_FragCoord.y * 0.5) * 2.0 / iResolution.y * CO_STRIPS);
    if (strip != floor(done / 2.0)) discard;

    vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    float h = coLand(p);
    // Half floats keep 11 bits, far too few to place a hairline, so the height is split in two.
    // The slope, in height per pixel, sets how far apart the lines run; it and the light on the
    // land come from the neighbouring pixels, for free.
    vec2 g = vec2(dFdx(h), dFdy(h));
    float hi = floor(h * 512.0) / 512.0;
    float light = clamp(0.5 + dot(normalize(vec3(-g * iResolution.y * 0.35, 1.0)), vec3(-0.5, 0.6, 0.62)) * 0.5, 0.0, 1.0);
    fragColor = vec4(hi + 0.001, (h - hi) * 512.0, length(g), light);
}

// Image: the lines, from the kept land, where the water has risen to now
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec4 land = texelFetch(iChannel0, ivec2(gl_FragCoord.xy), 0);
    vec4 state = texelFetch(iChannel0, ivec2(0), 0);
    float ready = state.g == 0.625 ? smoothstep(2.0 * CO_STRIPS, 2.0 * CO_STRIPS + CO_FADE, state.r) : 0.0;
    vec2 uv = fragCoord / iResolution.xy;
    float k = iResolution.y / 2160.0;                 // physical pixels per 2160p pixel

    float h = land.r - 0.001 + land.g / 512.0;
    float level = h * CO_LINES - iTime / CO_RISE;
    float n = floor(level + 0.5);
    // Distance to the nearest line, in pixels: how far off a whole level, over the slope.
    float px = abs(level - n) / max(land.b * CO_LINES, 1e-5);
    // Line n is the same line for as long as it lives (rising, it keeps its n), so every fifth
    // stays every fifth all the way up.
    bool major = mod(n, 5.0) == 0.0;
    float width = (major ? 1.3 : 0.65) * max(k, 0.5);
    float line = 1.0 - smoothstep(width - 0.5, width + 0.5, px);
    // Lines bunch up on steep ground; thin the minor ones out there so slopes don't turn to
    // solid colour. The heavy ones carry on through.
    float crowd = land.b * CO_LINES / max(k, 0.5);
    line *= major ? 1.0 - smoothstep(0.6, 1.2, crowd) : 1.0 - smoothstep(0.25, 0.5, crowd);

    vec3 ground = mix(INK0, mix(WAVE1, INK1, smoothstep(0.2, 0.7, h)), 0.55);
    ground *= 0.93 + 0.14 * land.a;
    vec3 col = mix(ground, coBorder(h * 1.15 - 0.05), line * (major ? 0.78 : 0.32));
    col = mix(INK0, col, coVignette(uv) * ready);

    // Dither (interleaved gradient noise): dark gradients band without it.
    col += (fract(52.9829189 * fract(dot(fragCoord, vec2(0.06711056, 0.00583715)))) - 0.5) / 255.0;
    fragColor = vec4(col, 1.0);
}
