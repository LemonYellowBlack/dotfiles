// halo.glsl — a planet eclipsing its star for the Liquid shell: a dark disc whose rim of air
// glows in the window border's gradient (cyan, blue, violet, pink) and turns once every two
// minutes, the way the border turns around a window, with the star's corona fanning out behind.

#define INK0   vec3(0.086, 0.086, 0.114)   // #16161D sumiInk0, the shell's frame
#define NIGHT  vec3(0.051, 0.051, 0.071)   // #0d0d12, the shell's darkest
#define WAVE1  vec3(0.133, 0.196, 0.286)   // #223249
#define CYAN   vec3(0.498, 0.706, 0.792)   // #7FB4CA
#define BLUE   vec3(0.494, 0.612, 0.847)   // #7E9CD8
#define VIOLET vec3(0.584, 0.498, 0.722)   // #957FB8
#define PINK   vec3(0.824, 0.494, 0.600)   // #D27E99
#define FUJI   vec3(0.863, 0.843, 0.729)   // #DCD7BA

#define HA_TAU 6.2831853
#define HA_LAP 120.0                       // seconds for the gradient to go once round

float haHash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

vec2 haHash2(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

// The border's four stops, s from 0 (cyan) to 1 (pink).
vec3 haBorder(float s) {
    s = clamp(s, 0.0, 1.0) * 3.0;
    vec3 c = mix(CYAN, BLUE, clamp(s, 0.0, 1.0));
    c = mix(c, VIOLET, clamp(s - 1.0, 0.0, 1.0));
    return mix(c, PINK, clamp(s - 2.0, 0.0, 1.0));
}

// The gradient laid round a circle, given a direction from its centre and the direction cyan
// sits in: cyan on that side, pink opposite, blue and violet between.
vec3 haRound(vec2 dir, vec2 cyanDir) {
    return haBorder(0.5 - 0.5 * dot(dir, cyanDir));
}

// Sparse stars, at most one per 70 px cell (at 2160p), never thinner than a pixel.
vec3 haStars(vec2 px, float k) {
    const float cell = 70.0;
    vec2 id = floor(px / cell);
    // One sine decides whether a cell has a star at all; most don't, and leave here.
    if (fract(sin(dot(id, vec2(12.9898, 78.233))) * 43758.5453) > 0.22) return vec3(0.0);
    vec2 h = haHash2(id + 5.0) * vec2(0.22, 1.0);
    vec2 at = (id + 0.2 + 0.6 * haHash2(id * 1.3 + 2.0)) * cell;
    float size = 0.8 + 1.0 * h.y * h.y;
    float r = length(px - at) * k / max(size * k, 0.85);
    float sub = min(1.0, size * k / 0.85);
    vec3 tint = h.y < 0.6 ? FUJI : (h.y < 0.85 ? CYAN : PINK);
    return mix(FUJI, tint, 0.5) * exp(-r * r * 2.0) * sub * sub * (0.2 + 0.8 * h.x / 0.22);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    float k = iResolution.y / 2160.0;                // physical pixels per 2160p pixel
    float px = 1.0 / iResolution.y;                   // one pixel, in screen heights

    const vec2 centre = vec2(0.0, -0.035);           // a little low: the bar takes the top
    const float R = 0.30;
    vec2 d = p - centre;
    float r = length(d);
    vec2 dir = d / r;
    float h = r - R;                                  // height above the planet's surface
    float spin = iTime * HA_TAU / HA_LAP;
    vec2 cyanDir = vec2(cos(spin), sin(spin));
    // The star is behind the planet, up and to the left, so the rim is brightest on that side:
    // the "diamond" of a diamond ring, travelling round with the gradient.
    vec2 sunDir = vec2(cos(2.25 + spin), sin(2.25 + spin));

    vec3 col = mix(NIGHT, INK0, smoothstep(0.0, 1.2, r));
    float above = smoothstep(-0.5 * px, 1.5 * px, h);       // 0 on the disc, 1 off it
    col += haStars(fragCoord / k, k) * above * (1.0 - 0.8 * exp(-max(h, 0.0) * 12.0));
    if (h > -0.03 && h < 0.34) {
        // The ring and the corona: only near the rim does anything here show, and what does
        // fades to nothing before the edge of this test.
        float facing = 0.5 + 0.5 * dot(dir, sunDir);
        vec3 hue = haRound(dir, cyanDir);
        float a = atan(d.y, d.x);
        float hh = max(h, 0.0);
        float fade = 1.0 - smoothstep(0.18, 0.34, hh);

        // Corona: soft streamers fanning out from behind the disc.
        float streak = 0.55 + 0.25 * sin(a * 7.0 + 1.3) * sin(a * 3.0 - 0.4) + 0.2 * sin(a * 17.0 + 2.1);
        float corona = exp(-hh * (11.0 - 5.0 * streak)) * (0.35 + 0.65 * streak) * above * fade;
        // Air: a thin bright line at the limb, a soft glow above it, and a little light
        // scattered round onto the night side.
        float limb = exp(-abs(h) / max(1.6 * px, 0.0008));
        float air = exp(-hh * 55.0) * above;
        float night = exp(min(h, 0.0) * 60.0) * (1.0 - above);

        col += WAVE1 * 0.30 * exp(-hh * 7.0) * above * fade;
        col += hue * corona * (0.10 + 0.22 * facing);
        col += hue * air * (0.22 + 0.55 * facing * facing);
        col += mix(hue, FUJI, 0.35 * facing) * limb * (0.30 + 0.70 * facing * facing * facing);
        col += hue * night * 0.12 * facing;
        // The diamond, where the star's light grazes the rim.
        float ds = length(p - (centre + sunDir * (R + 0.002)));
        col += mix(FUJI, CYAN, 0.25) * (0.000024 / (ds * ds + 0.0004) * fade + exp(-ds * 160.0) * 0.5);
    }

    // Darken towards the frame so its ink0 runs into space.
    vec2 v = (uv - vec2(0.5, 0.49)) * vec2(1.1, 1.4);
    col = mix(INK0, col, 0.45 + 0.55 * smoothstep(1.05, 0.35, length(v)));

    // Dither (interleaved gradient noise): dark gradients band without it.
    col += (fract(52.9829189 * fract(dot(fragCoord, vec2(0.06711056, 0.00583715)))) - 0.5) / 255.0;
    fragColor = vec4(col, 1.0);
}
