const vec3 sumiInk0     = vec3(0.086, 0.086, 0.114);  // #16161D
const vec3 sumiInk4     = vec3(0.165, 0.165, 0.216);  // #2A2A37
const vec3 crystalBlue  = vec3(0.494, 0.612, 0.847);  // #7E9CD8
const vec3 oniViolet    = vec3(0.584, 0.498, 0.722);  // #957FB8
const vec3 springBlue   = vec3(0.498, 0.706, 0.792);  // #7FB4CA
const vec3 surimiOrange = vec3(1.000, 0.627, 0.400);  // #FFA066

const float TAU = 6.2831853;

// orbit.glsl: practice2, driven by CPU and RAM.
//
//   one dot per core   each core's load sets how wide its orbit is   (iCpuCores, iCpuCoreCount)
//   orbit speed        total CPU load spins the whole system         (iCpu)
//   planet size        memory used                                   (iRam)
//   planet heartbeat   gets faster under stress                      (iPulse)
//
// Same two-pass layout as practice2: Buffer A first, then Image.
// orbit.neowall does the channel wiring.

// Anti-aliased "1 inside, 0 outside" edge, same thresholds as practice2.
float fill(float d) { return 1.0 - smoothstep(-0.005, 0.005, d); }

// ===== Buffer A: smoothed state =====
// In practice2 every pixel of this buffer held the same value. Here each
// pixel *column* x holds the smoothed load of core x, so one buffer can smooth
// up to 64 cores at once:
//
//   r = smoothed load of core x (0 past the last core)
//   g = orbit phase, 0..1 of a turn           (same in every pixel)
//   b = smoothed RAM                          (same in every pixel)
//   a = smoothed total CPU                    (same in every pixel)
//
// The Image pass reads a single column with texelFetch() (exact pixel, no
// filtering) instead of texture() with a vec2 in 0..1.
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    ivec2 px = ivec2(fragCoord);
    vec4 prev = texelFetch(iChannel0, px, 0);
    // "glob" = the values that are the same in every pixel (phase/RAM/CPU).
    // Read them from column 0 so every pixel starts from the same value.
    vec4 glob = texelFetch(iChannel0, ivec2(0, 0), 0);

    int core = px.x;
    float coreTarget = (core < iCpuCoreCount) ? iCpuCores[core] : 0.0;

    // skip the fade-in from zero on the first frames
    bool warmup = iFrame < 2;

    float coreLoad = warmup ? coreTarget : mix(prev.r, coreTarget, 0.05);
    float ram      = warmup ? iRam       : mix(glob.b, iRam, 0.02);
    float cpu      = warmup ? iCpu       : mix(glob.a, iCpu, 0.03);

    // Why not angle = iTime * speed like practice2? When speed changes,
    // iTime * speed jumps and every dot teleports. Adding a small step each
    // frame keeps the motion continuous. fract() wraps it so it stays small:
    // this buffer is only half float (RGBA16F).
    float speed = mix(0.04, 0.5, cpu);   // turns per second
    float phase = fract(glob.g + speed * iTimeDelta);

    fragColor = vec4(coreLoad, phase, ram, cpu);
}

// ===== Image: the scene =====

// Draws every core's dot on one side of the planet: far side (front = 0) or
// near side (front = 1). Returns the colour in .rgb and coverage in .a.
vec4 coreDots(vec2 p, float angle, float front) {
    vec4 acc = vec4(0.0);
    // GLSL loops want a constant upper bound; break at the real core count
    // (neowall's docs: never hard-code 64).
    for (int i = 0; i < 64; i++) {
        if (i >= iCpuCoreCount) break;
        float load = texelFetch(iChannel0, ivec2(i, 0), 0).r;

        // spread the cores evenly around the orbit
        float a = angle + float(i) * TAU / float(iCpuCoreCount);

        // Same depth trick as practice2: the lower half of the ellipse is the
        // near side. Skip dots that belong to the other layer.
        float inFront = step(0.0, -sin(a));
        if (inFront != front) continue;

        // busier core = wider orbit. The smallest radiusX (0.36) stays
        // outside the largest planet, so the layer switch at the far
        // left/right is never visible, like in practice2.
        vec2 radius = vec2(mix(0.36, 0.85, load), mix(0.10, 0.42, load));
        vec2 pos = radius * vec2(cos(a), sin(a));
        float blob = fill(length(p - pos) - mix(0.012, 0.022, load));

        vec3 c = mix(springBlue, surimiOrange, smoothstep(0.3, 0.9, load));
        // keep whichever dot covers this pixel most
        if (blob > acc.a) acc = vec4(c, blob);
    }
    return acc;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

    vec4 glob = texelFetch(iChannel0, ivec2(0, 0), 0);
    float angle = glob.g * TAU;
    float ram   = glob.b;

    // --- RAM -> planet size, iPulse -> heartbeat ---
    float planetR = mix(0.18, 0.30, ram) + 0.01 * iPulse;
    float planet = fill(length(p) - planetR);
    // tints toward violet as memory fills
    vec3 planetColor = mix(crystalBlue, oniViolet, smoothstep(0.5, 0.9, ram));

    // faint rings marking the idle and fully loaded orbits
    float idleRing = fill(abs(length(p / vec2(0.36, 0.10)) - 1.0) * 0.10 - 0.001);
    float fullRing = fill(abs(length(p / vec2(0.85, 0.42)) - 1.0) * 0.42 - 0.001);

    vec4 far  = coreDots(p, angle, 0.0);
    vec4 near = coreDots(p, angle, 1.0);

    // back to front
    vec3 col = sumiInk0;
    col = mix(col, sumiInk4, max(idleRing, fullRing) * 0.6);
    col = mix(col, far.rgb, far.a);            // far side: under the planet
    col = mix(col, planetColor, planet);
    col = mix(col, near.rgb, near.a);          // near side: over it

    fragColor = vec4(col, 1.0);
}
