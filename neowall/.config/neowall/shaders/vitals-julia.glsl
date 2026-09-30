// --- Kanagawa Wave (copied from colors.glsl: neowall has no #include)

// neutrals
const vec3 sumiInk0   = vec3(0.086, 0.086, 0.114);  // #16161D
const vec3 sumiInk1   = vec3(0.094, 0.094, 0.125);  // #181820
const vec3 sumiInk2   = vec3(0.102, 0.102, 0.133);  // #1a1a22
const vec3 sumiInk3   = vec3(0.122, 0.122, 0.157);  // #1F1F28
const vec3 sumiInk4   = vec3(0.165, 0.165, 0.216);  // #2A2A37
const vec3 sumiInk5   = vec3(0.212, 0.212, 0.275);  // #363646
const vec3 sumiInk6   = vec3(0.329, 0.329, 0.427);  // #54546D
const vec3 winterBlue = vec3(0.145, 0.145, 0.208);  // #252535
const vec3 fujiGray   = vec3(0.447, 0.443, 0.412);  // #727169
const vec3 katanaGray = vec3(0.443, 0.486, 0.486);  // #717C7C
const vec3 oldWhite   = vec3(0.784, 0.753, 0.576);  // #C8C093
const vec3 fujiWhite  = vec3(0.863, 0.843, 0.729);  // #DCD7BA

// blues
const vec3 waveBlue1    = vec3(0.133, 0.196, 0.286);  // #223249
const vec3 waveBlue2    = vec3(0.176, 0.310, 0.404);  // #2D4F67
const vec3 dragonBlue   = vec3(0.396, 0.522, 0.580);  // #658594
const vec3 springBlue   = vec3(0.498, 0.706, 0.792);  // #7FB4CA
const vec3 crystalBlue  = vec3(0.494, 0.612, 0.847);  // #7E9CD8
const vec3 lightBlue    = vec3(0.639, 0.831, 0.835);  // #A3D4D5

// violets
const vec3 oniViolet2    = vec3(0.722, 0.706, 0.816);  // #b8b4d0
const vec3 springViolet1 = vec3(0.576, 0.541, 0.663);  // #938AA9
const vec3 oniViolet     = vec3(0.584, 0.498, 0.722);  // #957FB8
const vec3 springViolet2 = vec3(0.612, 0.671, 0.792);  // #9CABCA

// reds / pinks
const vec3 winterRed = vec3(0.263, 0.141, 0.169);  // #43242B
const vec3 autumnRed = vec3(0.765, 0.251, 0.263);  // #C34043
const vec3 samuraiRed = vec3(0.910, 0.141, 0.141);  // #E82424
const vec3 waveRed   = vec3(0.894, 0.408, 0.463);  // #E46876
const vec3 peachRed  = vec3(1.000, 0.365, 0.384);  // #FF5D62
const vec3 sakuraPink = vec3(0.824, 0.494, 0.600);  // #D27E99

// oranges / yellows
const vec3 winterYellow = vec3(0.286, 0.267, 0.235);  // #49443C
const vec3 boatYellow1  = vec3(0.576, 0.502, 0.337);  // #938056
const vec3 boatYellow2  = vec3(0.753, 0.639, 0.431);  // #C0A36E
const vec3 autumnYellow = vec3(0.863, 0.647, 0.380);  // #DCA561
const vec3 carpYellow   = vec3(0.902, 0.765, 0.518);  // #E6C384
const vec3 roninYellow  = vec3(1.000, 0.620, 0.231);  // #FF9E3B
const vec3 surimiOrange = vec3(1.000, 0.627, 0.400);  // #FFA066

// greens / aquas
const vec3 winterGreen = vec3(0.169, 0.200, 0.157);  // #2B3328
const vec3 autumnGreen = vec3(0.463, 0.580, 0.416);  // #76946A
const vec3 springGreen = vec3(0.596, 0.733, 0.424);  // #98BB6C
const vec3 waveAqua1   = vec3(0.416, 0.584, 0.537);  // #6A9589
const vec3 waveAqua2   = vec3(0.478, 0.659, 0.624);  // #7AA89F

const float TAU = 6.2831853;
const float PI  = 3.1415927;

// vitals.glsl: one Julia set, where each thing measured controls a
// different parameter of it.
//
//   temperature   the shape (c)          cool = calm and joined, hot = scattered dust  (iThermal)
//                 the edge colours       blue when cool, red-orange when hot
//   time of day   rotation               one half turn per day, midnight = level       (iTimeOfDay)
//                 background             night ink -> dusk red -> day blue             (iSun)
//   battery       detail (iterations)    full = fine filaments, empty = a soft blob    (iBattery)
//                 glow                   breathes while charging                       (iCharging)
//   network       colour flow            bands stream outward faster with traffic      (iNetDown, iNetUp)
//
// neowall has no wifi/bluetooth uniform, so network *activity* stands in.
// An idle link and a dead one look the same.
//
// Same two-pass layout as practice2: Buffer A first, then Image.
// vitals.neowall does the channel wiring.

// ===== Buffer A: smoothed state =====
//   r = smoothed temperature
//   g = smoothed network activity
//   b = colour-flow phase, 0..1
//
// The colour bands repeat every 1.0 of phase, so the phase can wrap with
// fract() without a visible jump. That keeps the value small, which matters
// because this buffer is only half float (RGBA16F). Adding speed * dt each
// frame, instead of computing iTime * speed, keeps the flow smooth when
// traffic changes the speed.
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec4 prev = texture(iChannel0, vec2(0.5));

    float heatTarget = iThermal;
    float netTarget  = max(iNetDown, iNetUp);

    // skip the fade-in from zero on the first frames
    bool warmup = iFrame < 2;

    float heat = warmup ? heatTarget : mix(prev.r, heatTarget, 0.01);   // temp drifts slowly
    float net  = warmup ? netTarget  : mix(prev.g, netTarget,  0.03);   // traffic is burstier

    // band cycles per second: a slow drift when idle, streaming under traffic
    float speed = mix(0.03, 0.5, net);
    float phase = fract(prev.b + speed * iTimeDelta);

    fragColor = vec4(heat, net, phase, 1.0);
}

// ===== Image: the scene =====
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

    vec4 state  = texture(iChannel0, vec2(0.5));
    float heat  = state.r;
    float net   = state.g;
    float phase = state.b;

    // --- temperature -> shape ---
    // Heat moves c along an arc: at the cool end the set is one joined blob,
    // in the middle it grows spirals (the "seahorse valley"), and at the hot
    // end it breaks apart into dust. iThermal 0..1 covers 30..95C, and the
    // XPS usually sits low in that range, so 0.2..0.85 is stretched to 0..1.
    float t = smoothstep(0.2, 0.85, heat);
    float cA = mix(3.0, 4.2, t) + 0.02 * sin(iTime * 0.15);   // tiny wobble keeps it alive
    vec2 c = 0.7885 * vec2(cos(cA), sin(cA));

    // --- time of day -> rotation ---
    // A Julia set looks the same after a half turn, so a full day maps to
    // PI (half a turn) rather than TAU. That way every hour gets a different
    // angle. Midnight and noon both come out level; the background colour
    // tells them apart.
    float rot = iTimeOfDay * PI;
    vec2 z = mat2(cos(rot), -sin(rot), sin(rot), cos(rot)) * p * 2.8;

    // --- battery -> detail ---
    // More iterations resolve finer filaments. As the battery drains, the
    // loop gets cut short and the set softens into a blob. The loop keeps a
    // constant upper bound (80) and breaks early, because some GPUs don't
    // like loop limits that change at runtime.
    float maxIt = mix(12.0, 80.0, iBattery);

    float n = 0.0;
    bool escaped = false;
    for (int i = 0; i < 80; i++) {
        if (n >= maxIt) break;
        // complex square: (x + iy)^2 = x^2 - y^2 + 2xyi
        z = vec2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y) + c;
        if (dot(z, z) > 64.0) { escaped = true; break; }
        n += 1.0;
    }

    // --- time of day -> background ---
    float day  = smoothstep(0.1, 0.5, iSun);
    float dusk = smoothstep(0.0, 0.2, iSun) * (1.0 - smoothstep(0.2, 0.45, iSun));
    vec3 bg = mix(mix(sumiInk0, winterBlue, day), winterRed, dusk * 0.6);
    vec3 core = mix(sumiInk0, bg, 0.5);    // inside the set: a slightly darker ink

    vec3 col = core;
    if (escaped) {
        // Smooth iteration count. The integer n alone gives visible stair-step
        // bands; this term measures how far past the escape radius z got and
        // turns n into a continuous value.
        float sn = n - log2(log2(dot(z, z))) + 4.0;

        // --- network -> colour flow ---
        // Repeating bands along sn. Adding phase slides them outward, away from
        // the set's edge, faster when there's more traffic.
        float bands = 0.5 + 0.5 * cos(TAU * (sn * 0.07 + phase));

        // --- temperature -> colours ---
        vec3 dim    = mix(waveBlue2, winterRed, t);
        vec3 bright = mix(lightBlue, surimiOrange, t);
        vec3 edge = mix(dim, bright, bands);

        // Glow is based on sn relative to maxIt, so a low battery still gives
        // a bright edge, just a simpler one. Far-away pixels escape almost
        // immediately and fade into the background.
        float glow = smoothstep(0.08, 0.6, sn / maxIt);

        // --- charging -> breathing ---
        glow *= 1.0 + iCharging * 0.2 * sin(iTime * 1.5);

        col = mix(bg, edge, clamp(glow, 0.0, 1.0));
    }

    fragColor = vec4(col, 1.0);
}
