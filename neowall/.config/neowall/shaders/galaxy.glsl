// galaxy.glsl — a band of the Milky Way across the Liquid shell's desktop, corner to corner, its
// light running the window border's gradient (cyan, blue, violet, pink) along its length. Dust
// rifts and pink emission knots in the band, stars thickening towards it, the brightest of them
// breathing, and now and then a meteor.
//
// Two passes (galaxy.neowall). The sky costs about 90 ms to paint at 4K on a laptop's graphics
// chip, so Buffer A paints it twice, once into each of its two textures, and from then on
// discards every pixel: neowall never clears a buffer after its first frame, so a discarded pixel
// keeps what it had. The Image pass reads the sky and adds what moves, for about the price of a
// plain gradient.

#define INK0   vec3(0.086, 0.086, 0.114)   // #16161D sumiInk0, the shell's frame
#define WAVE1  vec3(0.133, 0.196, 0.286)   // #223249
#define CYAN   vec3(0.498, 0.706, 0.792)   // #7FB4CA
#define BLUE   vec3(0.494, 0.612, 0.847)   // #7E9CD8
#define VIOLET vec3(0.584, 0.498, 0.722)   // #957FB8
#define PINK   vec3(0.824, 0.494, 0.600)   // #D27E99
#define FUJI   vec3(0.863, 0.843, 0.729)   // #DCD7BA
#define CARP   vec3(0.902, 0.765, 0.518)   // #E6C384

float gxHash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

vec2 gxHash2(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

// Value noise with a quintic fade, so ridges built from it don't crease.
float gxNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = p - i;
    vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    return mix(mix(gxHash(i), gxHash(i + vec2(1.0, 0.0)), u.x),
               mix(gxHash(i + vec2(0.0, 1.0)), gxHash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Rotating each octave hides the value-noise grid.
float gxFbm(vec2 p, int octaves) {
    const mat2 R = mat2(1.60, 1.20, -1.20, 1.60);
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 7; i++) {
        if (i >= octaves) break;
        v += a * gxNoise(p);
        p = R * p;
        a *= 0.5;
    }
    return v;
}

// The border's four stops, s from 0 (cyan) to 1 (pink).
vec3 gxBorder(float s) {
    s = clamp(s, 0.0, 1.0) * 3.0;
    vec3 c = mix(CYAN, BLUE, clamp(s, 0.0, 1.0));
    c = mix(c, VIOLET, clamp(s - 1.0, 0.0, 1.0));
    return mix(c, PINK, clamp(s - 2.0, 0.0, 1.0));
}

vec3 gxSaturate(vec3 c, float k) {
    return mix(vec3(dot(c, vec3(0.299, 0.587, 0.114))), c, k);
}

// Where the band runs: u along it (bottom left to top right), v across it, its centre wandering.
vec2 gxBand(vec2 p) {
    const vec2 dir = vec2(0.8716, 0.4903);          // corner to corner of a 16:9 screen
    float u = dot(p, dir);
    float v = dot(p, vec2(-dir.y, dir.x));
    v += 0.05 * sin(u * 2.1 + 0.8) + 0.035 * sin(u * 4.7 - 1.3);
    return vec2(u, v);
}

// The band's light, in screen heights from the centre; `clear` is how much of a star behind it
// the dust lets through.
vec3 gxSky(vec2 p, out float clear) {
    vec2 b = gxBand(p);
    vec2 q = b * 2.0;
    vec2 w = vec2(gxFbm(q * 1.3 + vec2(3.1, 7.7), 4), gxFbm(q * 1.3 + vec2(9.4, 1.2), 4));

    float width = 0.17 + 0.07 * (gxFbm(vec2(q.x * 1.4, 5.0), 3) - 0.5);
    float vv = b.y + (w.y - 0.5) * 0.08;
    float band = exp(-vv * vv / (width * width));
    float core = exp(-vv * vv / (width * width * 0.18));

    // Unresolved stars: the band's light is grainy, not smooth.
    float clouds = gxFbm(q * 2.6 + 2.2 * w, 6);
    float grain = gxFbm(q * 14.0 + 3.0 * w, 3);
    float light = band * (0.35 + 0.9 * smoothstep(0.3, 0.8, clouds)) * (0.75 + 0.5 * grain);

    // The great rift: a dark lane along the band, a little off its centre, ragged at the edges.
    float lane = exp(-pow((b.y + 0.015 - 0.02 * sin(b.x * 3.3)) / (width * 0.42), 2.0));
    float dustN = gxFbm(q * 3.4 + 2.6 * w + vec2(5.0, 1.0), 6);
    float dust = smoothstep(0.30, 0.68, dustN * (0.45 + 0.75 * lane)) * band;

    // Pink knots of glowing hydrogen, strung along the band.
    float knots = smoothstep(0.60, 0.82, gxFbm(q * 1.8 + 1.5 * w + vec2(13.0, 2.0), 5)) * band;

    float s = 0.5 + b.x * 0.52 + (w.x - 0.5) * 0.25;
    vec3 hue = gxSaturate(gxBorder(s), 1.25) * (1.15 - 0.15 * s);
    vec3 col = INK0 + WAVE1 * 0.30 * exp(-vv * vv / (width * width * 6.0));
    col += hue * light * 0.42;
    col += mix(hue, FUJI, 0.55) * core * light * 0.30;
    col += gxSaturate(mix(PINK, VIOLET, 0.25), 1.3) * knots * 0.42;
    col *= 1.0 - 0.86 * dust;
    clear = 1.0 - 0.8 * dust;
    return col;
}

// One layer of stars, at most one per cell of `cell` px (at 2160p). `crowd` raises the odds
// near the band, judged at the cell's centre so a star is never cut in half.
vec3 gxStars(vec2 px, vec2 res, float k, float cell, float sparse, float crowd, float size) {
    vec2 id = floor(px / cell);
    vec2 h = gxHash2(id + cell);
    vec2 centre = ((id + 0.5) * cell * k - 0.5 * res) / res.y;
    float v = gxBand(centre).y;
    float odds = sparse + crowd * exp(-v * v / 0.03);
    if (h.x > odds) return vec3(0.0);
    vec2 at = (id + 0.2 + 0.6 * gxHash2(id * 1.7 + 3.1)) * cell;
    float rank = h.x / odds;
    // Never thinner than a pixel; one that should be gives up brightness instead, so a small
    // render looks like a big one shrunk rather than a snowstorm.
    float r = length(px - at) * k / max(size * k, 0.85);
    float sub = min(1.0, size * k / 0.85);
    float glow = (exp(-r * r * 2.0) + exp(-r * 0.8) * 0.05 * rank) * sub * sub;
    vec3 tint = h.y < 0.55 ? FUJI : (h.y < 0.8 ? CYAN : (h.y < 0.93 ? CARP : PINK));
    return mix(FUJI, tint, 0.6) * glow * (0.25 + 0.75 * rank * rank);
}

// The few bright stars, breathing, with the four-point spikes a telescope's struts put on them.
// Most pixels are nowhere near one and leave after the first test.
vec3 gxBright(vec2 px, float k, float t) {
    const float cell = 560.0;
    vec2 id = floor(px / cell);
    vec2 h = gxHash2(id * 3.7 + 1.3);
    if (h.x > 0.28) return vec3(0.0);
    vec2 at = (id + 0.25 + 0.5 * gxHash2(id + 9.1)) * cell;
    vec2 d = abs(px - at);
    if (min(d.x, d.y) > 5.0 && d.x + d.y > 40.0) return vec3(0.0);
    d *= k / max(k, 0.5);
    float r = length(d) / 2.8;
    float core = 1.0 / (1.0 + r * r * r * r) + 0.10 / (1.0 + r * 0.35);
    float spikes = (1.0 / (1.0 + d.y * d.y)) / (1.0 + d.x * 0.05) + (1.0 / (1.0 + d.x * d.x)) / (1.0 + d.y * 0.05);
    float breathe = 0.80 + 0.20 * sin(t * (0.45 + 0.3 * h.y) + h.y * 30.0);
    vec3 tint = mix(FUJI, h.y < 0.5 ? CYAN : CARP, 0.4);
    return tint * (core + spikes * 0.3) * (0.5 + 0.5 * h.x / 0.28) * breathe;
}

// A meteor every four minutes or so, somewhere different each time, gone in under a second.
vec3 gxMeteor(vec2 p, float t) {
    const float every = 240.0;
    float n = floor(t / every);
    float age = t - n * every - every * (0.2 + 0.6 * gxHash(vec2(n, 7.0)));
    if (age < 0.0 || age > 0.9) return vec3(0.0);
    vec2 h = gxHash2(vec2(n, 3.0));
    vec2 from = vec2(-0.6 + 1.2 * h.x, 0.15 + 0.3 * h.y);
    vec2 dir = normalize(vec2(h.y > 0.5 ? 1.0 : -1.0, -0.55 - 0.5 * h.x));
    float run = 0.5 * smoothstep(0.0, 0.7, age);               // how far the head has gone
    vec2 rel = p - from;
    float along = clamp(dot(rel, dir), run - 0.18, run);        // the tail trails the head
    float dist = length(rel - dir * along);
    float tail = smoothstep(run - 0.18, run, along);
    float fade = smoothstep(0.0, 0.08, age) * (1.0 - smoothstep(0.55, 0.9, age));
    return mix(CYAN, FUJI, tail) * exp(-dist * dist * 4.0e5) * tail * fade * 0.9;
}

// Fades towards the frame, so its ink0 runs into space.
float gxVignette(vec2 uv) {
    vec2 v = (uv - vec2(0.5, 0.49)) * vec2(1.1, 1.4);
    return 0.4 + 0.6 * smoothstep(1.05, 0.35, length(v));
}

// Buffer A: the sky and its fainter stars, painted until both textures hold them
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // Texel (0, 0), under the shell's frame, keeps count: how many frames in a row have painted
    // (1, then 2), marked so neither a fresh buffer, cleared to (0, 0, 0, 1), nor junk reads as
    // one. At 2 both textures have been painted and every other pixel is discarded.
    vec4 state = texelFetch(iChannel0, ivec2(0), 0);
    float painted = state.g == 0.625 ? state.r : 0.0;
    if (ivec2(gl_FragCoord.xy) == ivec2(0)) {
        fragColor = vec4(min(painted + 1.0, 2.0), 0.625, 0.0, 0.0);
        return;
    }
    if (painted >= 2.0) discard;

    vec2 uv = fragCoord / iResolution.xy;
    vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    float k = iResolution.y / 2160.0;                // physical pixels per 2160p pixel
    vec2 px = fragCoord / k;

    float clear;
    vec3 col = gxSky(p, clear);
    col += (gxStars(px, iResolution.xy, k, 14.0, 0.00, 0.55, 0.75)
          + gxStars(px + 300.0, iResolution.xy, k, 26.0, 0.10, 0.70, 1.0)
          + gxStars(px + 700.0, iResolution.xy, k, 90.0, 0.18, 0.30, 1.7)) * clear;
    // Alpha keeps the dust's transmission for the stars the Image pass adds.
    fragColor = vec4(mix(INK0, col, gxVignette(uv)), clear);
}

// Image: the kept sky, the bright stars breathing, and the odd meteor
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec4 sky = texelFetch(iChannel0, ivec2(gl_FragCoord.xy), 0);
    vec2 uv = fragCoord / iResolution.xy;
    vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    float k = iResolution.y / 2160.0;

    vec3 moving = gxBright(fragCoord / k, k, iTime) + gxMeteor(p, iTime);
    vec3 col = sky.rgb + moving * sky.a * gxVignette(uv);

    // Triangular dither: dark gradients band without it.
    col += (gxHash(fragCoord) + gxHash(fragCoord + 17.3) - 1.0) / 255.0;
    fragColor = vec4(col, 1.0);
}
