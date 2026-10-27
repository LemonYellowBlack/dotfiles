// glass.glsl — drops of liquid glass for the Liquid shell, drifting over a faint dot grid and
// running together. Each bends the grid behind it like a lens, and its rim is a hairline of the
// window border's gradient (cyan, blue, violet, pink), turning slowly the way the border does.

#define INK0   vec3(0.086, 0.086, 0.114)   // #16161D sumiInk0, the shell's frame
#define INK3   vec3(0.212, 0.212, 0.275)   // #363646
#define INK4   vec3(0.329, 0.329, 0.427)   // #54546D
#define WAVE1  vec3(0.133, 0.196, 0.286)   // #223249
#define CYAN   vec3(0.498, 0.706, 0.792)   // #7FB4CA
#define BLUE   vec3(0.494, 0.612, 0.847)   // #7E9CD8
#define VIOLET vec3(0.584, 0.498, 0.722)   // #957FB8
#define PINK   vec3(0.824, 0.494, 0.600)   // #D27E99
#define FUJI   vec3(0.863, 0.843, 0.729)   // #DCD7BA

#define GS_TAU 6.2831853
#define GS_LAP 150.0                       // seconds for the rim's gradient to go once round
#define GS_GRID 38.0                       // dot spacing, in pixels at 2160p

// The border's four stops, s from 0 (cyan) to 1 (pink).
vec3 gsBorder(float s) {
    s = clamp(s, 0.0, 1.0) * 3.0;
    vec3 c = mix(CYAN, BLUE, clamp(s, 0.0, 1.0));
    c = mix(c, VIOLET, clamp(s - 1.0, 0.0, 1.0));
    return mix(c, PINK, clamp(s - 2.0, 0.0, 1.0));
}

// Where drop i is at time t, and how big: slow figures of eight, each its own speed.
vec3 gsDrop(int i, float t) {
    float f = float(i);
    vec2 home = vec2(-0.55 + 0.27 * f, 0.18 * sin(f * 2.4 + 0.5));
    vec2 swing = vec2(0.20 + 0.05 * f, 0.15);
    float w = 0.021 + 0.006 * f;
    vec2 at = home + swing * vec2(sin(t * w + f * 1.7), sin(t * w * 1.6 + f * 0.9));
    return vec3(at, 0.105 + 0.035 * sin(f * 3.1 + 1.0));
}

// The ground: a faint grid of dots over a glow along the border's diagonal.
vec3 gsGround(vec2 p, float k) {
    float across = dot(p, vec2(0.6, -0.8));
    vec3 col = mix(INK0, WAVE1, 0.5 * max(0.0, 1.0 - across * across * 5.0) * max(0.0, 1.0 - dot(p, p) * 0.6));
    vec2 cell = p * (2160.0 / GS_GRID);              // in grid cells
    vec2 f = fract(cell) - 0.5;
    float r = length(f) * GS_GRID * max(k, 0.5);     // distance to the dot, in pixels
    float spot = 1.0 - smoothstep(1.0 * max(k, 0.6), 1.0 * max(k, 0.6) + 1.0, r);
    return mix(col, INK4, spot * 0.55);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    float k = iResolution.y / 2160.0;                // physical pixels per 2160p pixel
    float px = 1.0 / iResolution.y;                   // one pixel, in screen heights
    float t = iTime;

    // Metaballs: each drop adds r²/d² to the field; the glass is wherever it passes 1.
    float F = 0.0;
    vec2 grad = vec2(0.0);
    for (int i = 0; i < 5; i++) {
        vec3 d = gsDrop(i, t);
        vec2 v = p - d.xy;
        float q = 1.0 / (dot(v, v) + 1e-4);
        float c = d.z * d.z * q;
        F += c;
        grad -= 2.0 * c * q * v;
    }

    vec3 col;
    if (F < 0.4) {
        // Well clear of every drop (most of the screen): just the ground, a little shaded.
        col = gsGround(p, k) * (1.0 - 0.25 * smoothstep(0.2, 1.0, F));
    } else {
        float g = max(length(grad), 1e-4);
        float edge = (F - 1.0) / g;                  // ≈ distance inside the edge, screen heights
        float inside = smoothstep(-0.75 * px, 0.75 * px, edge);

        // The glass as a lens, a low dome: flat in the middle, curving down to the rim. Its
        // slope bends the grid seen through it.
        vec2 slope = -grad / (F * F) * 0.06;
        vec3 n = normalize(vec3(slope, 1.0));
        float depth = 1.0 - 1.0 / max(F, 1.0);
        vec2 bent = p - n.xy * 0.03 * smoothstep(0.0, 0.4, depth);
        col = gsGround(mix(p, bent, inside), k);

        // Light from the top left, as the border's gradient starts there: a soft highlight up
        // that side of the dome, and the light it focuses gathering on the far side.
        const vec3 halfway = vec3(-0.28, 0.36, 0.89);   // between the light and the eye
        float tilt = 1.0 - n.z;
        float spin = t * GS_TAU / GS_LAP;
        vec3 hue = gsBorder(0.5 - 0.5 * dot(grad / g, vec2(cos(spin), sin(spin))));
        float spec = pow(max(dot(n, halfway), 0.0), 36.0);
        float caustic = smoothstep(0.0, 0.8, dot(n.xy, vec2(0.61, -0.79))) * smoothstep(0.05, 0.5, tilt);

        vec3 glass = col * 1.08 + WAVE1 * 0.10;
        glass += hue * tilt * 0.42 + hue * caustic * 0.14 + FUJI * spec * 0.26;
        // The rim: a hairline of the gradient, like a window's border.
        float rim = exp(-abs(edge) / max(1.3 * px, 0.0007));
        col = mix(col * (1.0 - 0.25 * smoothstep(0.2, 1.0, F)), glass, inside);
        col += hue * rim * 0.55;
    }

    // Darken towards the frame so its ink0 runs under it.
    vec2 vv = (uv - vec2(0.5, 0.49)) * vec2(1.1, 1.4);
    col = mix(INK0, col, 0.45 + 0.55 * smoothstep(1.05, 0.35, length(vv)));

    // Dither (interleaved gradient noise): dark gradients band without it.
    col += (fract(52.9829189 * fract(dot(fragCoord, vec2(0.06711056, 0.00583715)))) - 0.5) / 255.0;
    fragColor = vec4(col, 1.0);
}
