// orbit3d.glsl: orbit.glsl in 3D. Still two bodies, a big planet and a
// small moon, still reading the same three numbers:
//
//   cpu    the orbit's shape. Idle: a lazy, almost round orbit. Busy: a long
//          ellipse whose close pass skims the planet's surface
//   ram    how fast the moon goes around
//   heat   the moon's colour, fuji white -> old white, and so the colour
//          of the light it throws on the planet
//   (each one stretched over the range it really covers on this laptop:
//   see BUSY_RANGE below)
//
// What makes it move like motion graphics instead of a clock hand:
//   - the moon obeys Kepler: it whips through the close pass and hangs at
//     the far end, so every orbit has its own ease-in and ease-out
//   - the planet reacts: its surface swells toward the moon as it passes,
//     trails behind it, and wobbles back like a liquid once it's gone
//   - the moon is a light: it lights the planet, glints in it, shines
//     through its thin edge from behind, and gets eclipsed by it
//   - the moon stretches along its path when it's fast (squash and stretch)
//   - the ellipse slowly turns, so the close pass keeps landing somewhere new
//
// Two passes, wired up by orbit3d.neowall:
//   first    a tiny simulation. It remembers things between frames, and
//            works out everything that's the same for every pixel, once
//   second   draws the scene from that, once per pixel
//
// Most of this file's shape comes from one number: at 3840x2160 the second
// pass runs 8.3 million times a frame. A line of maths that's the same for
// every pixel costs 8.3 million times what it would in the first pass, and
// every pixel that can skip the 3D work entirely should.

// --- Kanagawa Wave (copied from colors.glsl: neowall has no #include)
const vec3 sumiInk0    = vec3(0.086, 0.086, 0.114);  // #16161D
const vec3 winterBlue  = vec3(0.145, 0.145, 0.208);  // #252535
const vec3 waveBlue1   = vec3(0.133, 0.196, 0.286);  // #223249
const vec3 crystalBlue = vec3(0.494, 0.612, 0.847);  // #7E9CD8
const vec3 dragonBlue  = vec3(0.396, 0.522, 0.580);  // #658594
const vec3 fujiWhite   = vec3(0.863, 0.843, 0.729);  // #DCD7BA
const vec3 oldWhite   = vec3(0.784, 0.753, 0.576);  // #C8C093

const float TAU = 6.28318531;

// Lighting maths only works on "linear" colour values. Hex colours are
// stored gamma-encoded (bent so dark shades get more of the 0..255 range),
// so decode them before lighting (square them) and re-encode once at the
// very end (square root). The exact curve is closer to a power of 2.2, but
// 2 is near enough, and sqrt is far cheaper than pow per pixel.
vec3 toLinear(vec3 c) { return c * c; }

// ===== the world, in units where the planet's radius is 1 =====
const float PLANET_R  = 1.0;
const float MOON_R    = 0.1;    // the same 10:1 ratio as the 2D circles
const float BULGE_MAX = 0.11;   // the tallest the surface may reach

// The camera never moves, so its whole setup is constants the compiler
// works out once, instead of maths every pixel repeats. It looks down at
// the planet from a little above, aimed a bit below its centre: that sits
// the planet slightly high in the frame and leaves room for the near side
// of the orbit, which perspective makes bigger.
const float CAM_DIST = 8.0;
const float FOCAL    = 2.0;     // zoom: bigger = narrower lens
const vec3  CAM_POS  = CAM_DIST * vec3(0.0, sin(0.2), cos(0.2));
const vec3  CAM_FW   = normalize(vec3(0.0, -0.12, 0.0) - CAM_POS);
const vec3  CAM_RT   = normalize(cross(CAM_FW, vec3(0.0, 1.0, 0.0)));
const vec3  CAM_UP   = cross(CAM_RT, CAM_FW);

// where the planet's centre lands on screen (same units as p in mainImage)
const vec2  PLANET_ON_SCREEN = FOCAL * vec2(dot(-CAM_POS, CAM_RT), dot(-CAM_POS, CAM_UP))
                             / dot(-CAM_POS, CAM_FW);

// How big a sphere of radius r around the planet's centre looks on screen:
// its edge is seen at angle asin(r / CAM_DIST) off the centre, and the lens
// turns an angle into a screen distance of FOCAL * tan(angle).
float screenRadius(float r) {
    return FOCAL * r / sqrt(CAM_DIST * CAM_DIST - r * r);
}

// The orbit lies in a plane that starts flat (the x/z floor), tips toward
// the camera by INCL so we look down onto it, then rolls by ROLL so it runs
// on a slight diagonal. ORBIT_U and ORBIT_V are two perpendicular directions
// lying in that plane (U points right, V away from the camera); any spot on
// the orbit is some amount of each.
const float INCL = 0.30;
const float ROLL = -0.16;
const vec3  ORBIT_U = vec3(cos(ROLL), sin(ROLL), 0.0);
const vec3  ORBIT_V = vec3(-sin(INCL) * sin(ROLL), sin(INCL) * cos(ROLL), -cos(INCL));

struct Orbit {
    float e;      // eccentricity: 0 = circle, toward 1 = long and thin
    float a;      // semi-major axis: half the ellipse's long diameter
    float rate;   // orbits per second
    float turn;   // the angle the ellipse's long axis points at
};

// The range each input really covers on this laptop (XPS 15 7590, measured
// Sep 2026). Mapping the whole 0..1 wastes most of it: across a stretch of
// ordinary use iCpu sat at 0.04..0.07, so the orbit only ever used the
// first 7% of its range of shapes. smoothstep(lo, hi, x) turns lo..hi into
// 0..1, flat at both ends, so everyday noise below lo doesn't wobble anything.
//   iCpuMax   the busiest CPU thread. iCpu averages all 12, so one thread
//             flat out reads as just 0.08. Idle, this wanders 0.1..0.3
//   iRam      used / total. With 16 GB it lives around 0.3..0.6
//   iThermal  (hottest CPU sensor - 30 C) / 65 C. The graphics chip sits in
//             the same package, so with this wallpaper on screen the CPU
//             idles around 70 C; flat out it heads for 95 C
const vec2 BUSY_RANGE = vec2(0.30, 0.95);
const vec2 RAM_RANGE  = vec2(0.25, 0.75);
const vec2 HEAT_RANGE = vec2(0.68, 0.97);   // 74 C .. 93 C

// The ellipse itself slowly turns (apsidal precession), once every ~2.7
// minutes: the close pass starts off at the planet's right edge, where the
// bulge shows best, then drifts behind, round the left, and back.
const float PRECESSION_PERIOD = 160.0;      // seconds per full turn

// m = smoothed (busiest thread, ram, heat), turns = how far the ellipse has
// turned so far (whole turns don't matter)
Orbit orbitFor(vec3 m, float turns) {
    Orbit o;
    o.e    = mix(0.24, 0.37, smoothstep(BUSY_RANGE.x, BUSY_RANGE.y, m.x));
    o.a    = 1.95;
    o.rate = mix(0.11, 0.16, smoothstep(RAM_RANGE.x, RAM_RANGE.y, m.y));
    o.turn = -0.35 + TAU * turns;
    return o;
}

// Kepler: an orbiting body sweeps out equal areas in equal times, so it
// speeds up close in and slows down far out. The maths: the "mean anomaly"
// M grows steadily (that's the phase), and the moon's actual place on the
// ellipse is set by the "eccentric anomaly" E, where M = E - e*sin(E).
// There's no formula that solves that for E, so start from a close guess
// and refine it with Newton's method. Two steps are plenty here.
float eccentricAnomaly(float M, float e) {
    float E = M + e * sin(M) * (1.0 + e * cos(M));
    for (int i = 0; i < 2; i++) {
        E -= (E - e * sin(E) - M) / (1.0 - e * cos(E));
    }
    return E;
}

// phase 0..1 once around (0 = the close pass) -> position and velocity
void moonState(float phase, Orbit o, out vec3 pos, out vec3 vel) {
    float E  = eccentricAnomaly(TAU * phase, o.e);
    float cE = cos(E), sE = sin(E);
    float b  = o.a * sqrt(1.0 - o.e * o.e);          // semi-minor axis

    // flat 2D ellipse first, with the planet at one focus...
    vec2  q  = vec2(o.a * (cE - o.e), b * sE);
    float dE = TAU * o.rate / (1.0 - o.e * cE);      // how fast E changes
    vec2  dq = vec2(-o.a * sE, b * cE) * dE;

    // ...then stood up in 3D: P points at the close pass, Q a quarter turn on
    vec3 P = cos(o.turn) * ORBIT_U + sin(o.turn) * ORBIT_V;
    vec3 Q = cos(o.turn) * ORBIT_V - sin(o.turn) * ORBIT_U;
    pos = q.x * P + q.y * Q;
    vel = dq.x * P + dq.y * Q;
}

// How hard the moon tugs on the surface, as the height the bulge would
// settle at if the moon held still. Nothing past a gap of 1.25, then it
// climbs steeply as the gap closes. Having no tug at all for part of the
// orbit means the surface gets to settle back into a perfect sphere, which
// makes each pass an event, and lets the planet skip the raymarch meanwhile.
float pullTarget(vec3 moonPos) {
    float gap = length(moonPos) - PLANET_R;
    return 0.09 * pow(clamp((1.25 - gap) / 1.05, 0.0, 1.0), 2.2);
}

// The simulation's output: one row of texels, each holding one thing.
const int S_METRICS = 0;   // smoothed busiest thread, ram, heat (+ the marker, see below)
const int S_PHASE   = 1;   // orbit phase, then the ellipse's turn: coarse and fine part each
const int S_SPRING  = 2;   // bulge height, and how fast it's moving
const int S_BULGE   = 3;   // bulge direction, and its height (capped)
const int S_MOON_HI = 4;   // moon position, coarse part
const int S_MOON_LO = 5;   // moon position, fine part
const int S_MOON_V  = 6;   // moon heading, and how stretched it is
const int S_SCREEN  = 7;   // the moon on screen: where, how big, how hot
const int S_METRICS_LO = 8;   // smoothed inputs, fine part (S_METRICS holds the coarse)
const int S_COUNT   = 9;

vec4 state(int i) { return texelFetch(iChannel0, ivec2(i, 0), 0); }

// neowall buffers hold half floats: about 3 significant digits. That's fine
// for a colour, not for a position: at the moon's distance a half float's
// step is 0.002, a whole pixel at 4K, and the rounding changes frame to
// frame, so the moon would jitter. So its position is stored in two parts:
// a coarse one in whole 1/128ths (which half floats hold exactly) and the
// small leftover (where half floats are very precise). Add them to read.
vec3 coarse(vec3 x) { return floor(x * 128.0 + 0.5) / 128.0; }

// The same trick for a number that grows a little every frame, counted in
// turns (so it wraps at 1): hi holds whole 1/256ths, lo the leftover, and
// whenever lo passes 1/256 it carries over into hi. Add the two to read it.
vec2 accumulate(vec2 hilo, float step) {
    float lo    = hilo.y + step;
    float carry = floor(lo * 256.0) / 256.0;
    return vec2(fract(hilo.x + carry), lo - carry);
}

// Buffer A: the simulation
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // Only the first S_COUNT texels of the bottom row are used, so every
    // other pixel bails out straight away (`discard`: write nothing at all).
    ivec2 px = ivec2(fragCoord);
    if (px.y != 0 || px.x >= S_COUNT) discard;

    // Last frame's state. neowall clears a new buffer to (0, 0, 0, 1) and
    // can hand over garbage on the very first frame, so the metrics texel
    // only counts as remembered if its alpha holds the marker 0.75.
    vec4 prevM = state(S_METRICS);
    vec4 prevL = state(S_METRICS_LO);
    vec4 prevP = state(S_PHASE);
    vec4 prevS = state(S_SPRING);
    vec4 prevB = state(S_BULGE);
    bool fresh = iFrame == 0 || prevM.a != 0.75;

    // after a pause iTimeDelta can be huge, and one giant step would fling
    // the spring off on an orbit of its own
    float dt = min(iTimeDelta, 0.05);

    // --- smoothing
    // Moves a fraction of the way to the live value each frame, like
    // orbit.glsl's mix(prev, target, 0.01). But a fixed 0.01 is a 1.7 s lag
    // at 60 fps and 3.3 s at 30; deriving the fraction from dt keeps the lag
    // the same in seconds at any frame rate. tau is roughly the time it
    // takes to get 63% of the way to a new value.
    // Stored in two parts, like the positions: near 1 a half float moves in
    // steps of ~0.0005, and one frame's nudge toward a value that's close is
    // smaller than that, so a single number would stall short of it. For
    // heat at 60 fps that was up to 0.12 short: 8 C, reading too cool.
    vec3 live = vec3(iCpuMax, iRam, iThermal);
    vec3 prev = prevM.rgb + prevL.rgb;
    vec3 m    = fresh ? live : mix(prev, live, 1.0 - exp(-dt / vec3(1.5, 3.0, 4.0)));

    // --- the ellipse's slow turn, and the orbit phase
    // Both are added up a frame at a time (turn += dt / period, phase +=
    // rate * dt) instead of worked out from iTime. orbit.glsl's iTime * speed
    // has a catch: iTime reaches the thousands, so the tiniest change in
    // speed jumps the moon to another spot on its orbit. And neowall resets
    // iTime to 0 about once an hour, while the wallpaper is hidden: a turn
    // worked out from iTime would swing the orbit to a new angle behind the
    // simulation's back, and the bulge would be left reaching for a moon
    // that isn't there. (It also means neowall's shader_speed setting does
    // nothing here: it speeds up iTime, not iTimeDelta.)
    // Each is split in two for the same half-float reason as the positions:
    // near 1.0 a half float's smallest step is ~0.0005. The phase moves ~4x
    // that a frame, so a single number would round every step and make the
    // speed stutter; the turn moves ~0.0001 a frame, so it wouldn't move at
    // all. accumulate() does the carrying.
    vec2  turn  = accumulate(fresh ? vec2(0.0) : prevP.ba, dt / PRECESSION_PERIOD);
    Orbit o     = orbitFor(m, turn.x + turn.y);
    vec2  phase = accumulate(fresh ? vec2(0.0) : prevP.rg, o.rate * dt);

    vec3 moonPos, moonVel;
    moonState(phase.x + phase.y, o, moonPos, moonVel);

    // --- bulge height, as a damped spring
    // The spring is pulled toward the moon's tug. It lags on the way up,
    // overshoots, and rings on the way back down: that follow-through is
    // what makes the surface read as liquid instead of a shape tracking a
    // number. Semi-implicit Euler: update the velocity first, then the height.
    const float W = TAU * 0.9;   // natural frequency: 0.9 wobbles a second
    const float Z = 0.22;        // damping: below 1 rings, 1 doesn't overshoot
    float h = fresh ? 0.0 : prevS.r;
    float v = fresh ? 0.0 : prevS.g;
    float pull = pullTarget(moonPos);
    v += (W * W * (pull - h) - 2.0 * Z * W * v) * dt;
    h += v * dt;

    // --- bulge direction
    // Eases toward the moon: quickly while the tug is strong, slowly while
    // it's weak. So the bulge trails the moon through a fast close pass, and
    // the wobble afterwards stays put instead of chasing the moon off.
    vec3  toMoon = normalize(moonPos);
    vec3  dir    = (fresh || dot(prevB.xyz, prevB.xyz) < 0.5) ? toMoon : prevB.xyz;
    float follow = 1.5 + 12.0 * clamp(pull / 0.06, 0.0, 1.0);
    dir = normalize(mix(dir, toMoon, 1.0 - exp(-follow * dt)));

    // --- the moon's look: stretched when fast, warmer when hot
    float speed   = length(moonVel);
    float stretch = 1.0 + 0.15 * max(speed - 1.2, 0.0);
    float warmth  = smoothstep(HEAT_RANGE.x, HEAT_RANGE.y, m.z);

    // --- where the moon lands on screen, for the drawing pass's shortcut
    // (the same projection the camera ray does, run backwards: z is the
    // moon's depth in front of the camera, and x/z, y/z its screen spot)
    vec3  cv = moonPos - CAM_POS;
    float z  = dot(cv, CAM_FW);
    vec2  onScreen = FOCAL * vec2(dot(cv, CAM_RT), dot(cv, CAM_UP)) / z;

    // each texel keeps its own slice of all that
    vec4 outv;
    if      (px.x == S_METRICS) outv = vec4(coarse(m), 0.75);
    else if (px.x == S_METRICS_LO) outv = vec4(m - coarse(m), 0.0);
    else if (px.x == S_PHASE)   outv = vec4(phase, turn);
    else if (px.x == S_SPRING)  outv = vec4(h, v, 0.0, 0.0);
    else if (px.x == S_BULGE)   outv = vec4(dir, clamp(h, -BULGE_MAX, BULGE_MAX));
    else if (px.x == S_MOON_HI) outv = vec4(coarse(moonPos), 0.0);
    else if (px.x == S_MOON_LO) outv = vec4(moonPos - coarse(moonPos), 0.0);
    else if (px.x == S_MOON_V)  outv = vec4(moonVel / max(speed, 1e-4), stretch);
    else                        outv = vec4(onScreen, z / FOCAL, warmth);
    fragColor = outv;
}

// ===== drawing helpers =====
// neowall gives code placed between the two mainImage functions to the
// second pass only.

const float MOON_POWER = 40.0;   // how much light the moon throws

// Lights: a big soft key up and to the left, a cool rim from behind right.
// The key is a softbox with a diffuser over its face; BOX_U and BOX_V lie
// in that face.
const vec3 KEY_DIR = normalize(vec3(-0.7, 0.6, 0.3));
const vec3 RIM_DIR = normalize(vec3(0.8, 0.25, -0.55));
const vec3 BOX_U   = normalize(cross(KEY_DIR, vec3(0.0, 1.0, 0.0)));
const vec3 BOX_V   = cross(BOX_U, KEY_DIR);

struct Bulge {
    vec3  dir;     // where the hill peaks
    float amp;     // how tall it is (negative mid-wobble: a dent)
    float sharp;   // how narrow it is
};

// ray vs sphere centred on the origin: (near, far) hit distances, or -1
vec2 sphereHits(vec3 ro, vec3 rd, float r) {
    float b = dot(ro, rd);
    float h = b * b - dot(ro, ro) + r * r;
    if (h < 0.0) return vec2(-1.0);
    h = sqrt(h);
    return vec2(-b - h, -b + h);
}

// Distance to the planet: raymarch3D.glsl's sphere, with the radius pushed
// out by a hill. c is the cosine of the angle between p and the peak
// (1 on top, 0 a quarter of the way round), and exp((c - 1) * sharp) turns
// that into a smooth bump: 1 at the peak, fading to nothing.
float planetDist(vec3 p, Bulge b) {
    float r = length(p);
    float c = dot(p, b.dir) / r;
    return r - PLANET_R - b.amp * exp((c - 1.0) * b.sharp);
}

// The normal, worked out with calculus instead of the six extra distance
// calls normalAt makes in raymarch3D.glsl: start from a plain sphere's
// normal (p / r), then tilt it away from the peak by the hill's slope.
vec3 planetNormal(vec3 p, Bulge b) {
    float r = length(p);
    vec3  n = p / r;
    float c = dot(n, b.dir);
    float slope = b.amp * b.sharp * exp((c - 1.0) * b.sharp) / r;
    return normalize(n - slope * (b.dir - c * n));
}

// Maps the stretched moon onto a unit sphere, so hitting it is plain
// ray-vs-sphere maths. Along its heading it's MOON_R * s long, across it
// MOON_R / sqrt(s), so its volume stays the same as it stretches.
vec3 squash(vec3 x, vec3 dir, float s) {
    float along = dot(x, dir);
    return ((x - along * dir) * sqrt(s) + along * dir / s) / MOON_R;
}

// How much key light gets past the moon to reach p: 1 lit, 0 in shadow.
// Spheres have a closed form: find how far the ray toward the light misses
// the moon (d) and how far along it does (t). d / t is the angle it misses
// by, and a small angle lands in the soft edge of the shadow.
// (after Inigo Quilez, "sphere soft shadow")
float moonShadow(vec3 p, vec3 l, vec3 c) {
    if (dot(c, l) < 0.0) return 1.0;     // moon on the far side from the light
    vec3  oc = p - c;
    float b  = dot(oc, l);
    float h  = b * b - dot(oc, oc) + MOON_R * MOON_R;
    float d  = sqrt(max(MOON_R * MOON_R - h, 0.0)) - MOON_R;
    float t  = -b - sqrt(max(h, 0.0));
    return t < 0.0 ? 1.0 : smoothstep(0.0, 1.0, d / (0.12 * t));
}

// What the planet's glossy coat reflects: a dim studio, brighter overhead,
// with the key's softbox and a strip light behind for the rim.
vec3 studio(vec3 d) {
    vec3 col = mix(toLinear(sumiInk0), toLinear(winterBlue) * 2.5, smoothstep(-0.3, 0.9, d.y));

    // The softbox: find where d crosses the box's face (q), then light that
    // spot with smooth falloffs and no edge anywhere, so its reflection
    // reads as a glow on the coat rather than a shape stuck on top of it.
    // Two parts, like a real diffuser:
    //   body  wide and soft. pow(r, 2.2) keeps its middle broad before it
    //         fades, the k.x line makes it a little egg-shaped (wider toward
    //         its top), and it's brighter toward the top, like a window
    //         with sky above it
    //   core  a small hot spot near the top, where the diffuser glows most
    float facing = dot(d, KEY_DIR);
    if (facing > 0.0) {
        vec2  q    = vec2(dot(d, BOX_U), dot(d, BOX_V)) / facing;
        vec2  k    = q / vec2(0.46, 0.34);
        k.x       /= 1.0 + 0.18 * k.y;
        float body = exp(-1.4 * pow(length(k), 2.2)) * (0.75 + 0.4 * smoothstep(-1.0, 1.0, k.y));
        vec2  c    = (q - vec2(0.0, 0.08)) / vec2(0.22, 0.16);
        float core = exp(-2.0 * dot(c, c));
        col += vec3(3.2) * body + vec3(2.4) * core;
    }

    col += toLinear(dragonBlue) * 1.5 * smoothstep(0.70, 0.90, dot(d, RIM_DIR));
    return col;
}

vec3 shadePlanet(vec3 p, vec3 n, vec3 rd, vec3 moonPos, vec3 moonCol) {
    vec3  v      = -rd;
    float ndv    = clamp(dot(n, v), 0.0, 1.0);
    float f      = 1.0 - ndv;
    float fres   = 0.05 + 0.95 * f * f * f * f * f;   // glancing angles reflect more
    vec3  albedo = toLinear(crystalBlue);

    // key light, wrapped a touch past the day/night line so it's soft,
    // minus the moon's shadow
    float shadow = moonShadow(p, KEY_DIR, moonPos);
    float key    = clamp((dot(n, KEY_DIR) + 0.1) / 1.1, 0.0, 1.0);
    vec3  col    = albedo * 1.1 * key * shadow;

    // ambient: the surroundings, a little brighter from above
    col += albedo * mix(toLinear(sumiInk0), toLinear(waveBlue1), 0.5 + 0.5 * n.y) * 0.8;

    // The moon as a light. sinS is its apparent size from here, and sinS^2
    // is how much of the sky it fills: that makes its light fade with the
    // square of distance, so it flares as the moon swoops in. A big light
    // also reaches past the day/night line, by about its apparent size, and
    // smoothstep eases it out there: a plain clamp stops with a corner, and
    // under a light this bright the eye picks the corner out as a line.
    vec3  toM  = moonPos - p;
    float dm   = length(toM);
    vec3  lm   = toM / dm;
    float sinS = MOON_R / dm;
    vec3  moonLight = moonCol * MOON_POWER * sinS * sinS;
    // (A blue surface under yellow light really does look grey. Art beats
    // physics here: the planet answers the moon with a paler version of its
    // colour, so warm light reads as warm.)
    vec3  answer = mix(albedo, vec3(0.5), 0.7);
    col += answer * moonLight * smoothstep(0.0, 1.0, (dot(n, lm) + sinS) / (1.0 + sinS));

    // Translucency: when the moon is behind the planet, its light glows
    // through the thin edge we look through. `behind` is 1 when the moon's
    // light heads straight at the camera, and f^2 keeps the glow to the
    // edge, where there's least planet in the way.
    float behind = clamp(dot(v, -lm), 0.0, 1.0);
    col += moonLight * behind * behind * f * f * 1.2;

    // cool rim light, hugging the edge
    col += toLinear(dragonBlue) * f * f * f * max(dot(n, RIM_DIR) + 0.2, 0.0) * 0.8;

    // Reflections: the studio, plus the moon itself. The reflected ray
    // "hits" the moon if it passes within MOON_R of its centre; the edge is
    // blurred a bit more the further the moon is, like a real glossy coat.
    vec3  r     = reflect(rd, n);
    vec3  env   = studio(r);
    float along = dot(toM, r);
    if (along > 0.0) {
        float miss = length(toM - r * along);
        float blur = MOON_R * 0.3 + 0.03 * along;
        env += moonCol * 4.0 * smoothstep(MOON_R + blur, MOON_R - blur, miss);
    }
    col += fres * env;

    return col;
}

// Highlights roll off smoothly instead of clipping. Below the knee (the
// whole background, most of the planet) values pass through untouched, so
// sumiInk0 still comes out as exactly #16161D.
vec3 tonemap(vec3 c) {
    const float knee = 0.6;
    vec3 over = max(c - knee, 0.0);
    return min(c, vec3(knee)) + over / (1.0 + over / (1.0 - knee));
}

// Image: the scene, drawn from the simulation's texels
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

    // Most of the screen is background with a little glow on it, and those
    // pixels take a shortcut: everything they need can be worked out flat,
    // from where the moon and the planet land on the screen. Only pixels
    // near one or the other fire a real ray into the scene.

    // the moon on screen: where it lands (xy), how many world units one
    // screen unit spans at its distance (z), and how hot it is (w)
    vec4  scr     = state(S_SCREEN);
    vec3  moonCol = toLinear(mix(fujiWhite, oldWhite, 0.3 + 0.7 * scr.w));
    vec2  dm      = (p - scr.xy) * scr.z;
    float h2      = dot(dm, dm);    // how close this pixel's ray passes the moon, squared

    // ...and how far it is from the planet's centre on screen (squared).
    // screenRadius() converts a distance from the planet's centre in the
    // world into one on screen, so these tests stay in screen units.
    vec2  q  = p - PLANET_ON_SCREEN;
    float q2 = dot(q, q);

    // background: sumiInk0, lifted toward winterBlue behind the planet
    vec3 col = mix(toLinear(sumiInk0), toLinear(winterBlue), 0.45 * exp(-3.0 * dot(p, p)));

    float aP = 0.0, aM = 0.0, hidden = 0.0;
    float nearPlanet = screenRadius(PLANET_R + BULGE_MAX + 0.01);   // all constants: the compiler
    if (q2 < nearPlanet * nearPlanet || h2 < 0.025) {                // turns these into plain numbers
        // ---- the real work: a ray into the scene
        vec3  ro  = CAM_POS;
        vec3  rd  = normalize(p.x * CAM_RT + p.y * CAM_UP + FOCAL * CAM_FW);
        float pix = 1.0 / (iResolution.y * FOCAL);   // one pixel's width at distance 1

        vec3  moonPos = state(S_MOON_HI).xyz + state(S_MOON_LO).xyz;
        vec4  heading = state(S_MOON_V);             // xyz: direction, w: stretch
        vec4  bs      = state(S_BULGE);              // xyz: direction, w: height
        // the taller the bulge, the narrower: a gentle swell becomes a reach
        Bulge bulge   = Bulge(bs.xyz, bs.w, mix(4.0, 10.0, clamp(bs.w / 0.08, 0.0, 1.0)));

        // ---- the planet
        // aP is how much of this pixel it covers (0..1), tP how far away.
        float tP = 1e9;
        float bC = -dot(ro, rd);                           // along the ray to its closest approach
        float hC = sqrt(max(dot(ro, ro) - bC * bC, 0.0));  // and how close that is
        if (abs(bulge.amp) < 5e-4) {
            // No bulge to speak of (under a quarter pixel): a plain sphere,
            // so exact ray-vs-sphere maths, no loop. How far the ray passes
            // outside the edge, in pixels, gives the smooth edge
            // raymarch3D.glsl's last comment asks about: half covered right
            // on the edge, fading out over a pixel.
            aP = clamp(0.5 - (hC - PLANET_R) / (pix * bC), 0.0, 1.0);
            tP = bC - sqrt(max(PLANET_R * PLANET_R - hC * hC, 0.0));
        } else {
            // Sphere-trace (raymarch3D.glsl's loop), but only inside a sphere
            // just big enough to hold the bulge: rays that miss it never
            // march, and the rest start right at the surface. A near miss is
            // covered by however many pixels it missed by (dMin at tMin).
            vec2 bound = sphereHits(ro, rd, PLANET_R + max(bulge.amp, 0.0) + 1e-4);
            if (bound.y > 0.0) {
                float t = bound.x, dMin = 1e9, tMin = t;
                bool hit = false;
                for (int i = 0; i < 40; i++) {
                    float d = planetDist(ro + rd * t, bulge);
                    if (d < dMin) { dMin = d; tMin = t; }
                    if (d < 0.5 * pix * t) { hit = true; break; }
                    t += d;
                    if (t > bound.y) break;
                }
                aP = hit ? 1.0 : clamp(1.0 - dMin / (pix * tMin), 0.0, 1.0);
                tP = hit ? t : tMin;
            }
        }

        // ---- the moon
        // An ellipsoid stretched along its heading: squash() turns it into
        // a unit sphere. dMin is how close the ray passes its centre, in moon
        // radii: under 1 is a hit, and the same number gives the smooth edge.
        vec3  oc = moonPos - ro;
        float b  = dot(oc, rd);                            // along the ray to the moon
        float tM = 1e9;
        vec3  cM = vec3(0.0);
        float reach = MOON_R * heading.w + 2.0 * pix * b;  // its longest radius, plus a pixel or two
        if (dot(oc, oc) - b * b < reach * reach) {
            vec3  mo   = squash(-oc, heading.xyz, heading.w);
            vec3  md   = squash(rd, heading.xyz, heading.w);
            float qa   = dot(md, md), qb = dot(mo, md);
            float tMid = -qb / qa;
            float dMin = sqrt(max(dot(mo, mo) + qb * tMid, 0.0));
            tM = tMid - sqrt(max(1.0 - dMin * dMin, 0.0) / qa);
            aM = clamp(0.5 - (dMin - 1.0) * MOON_R / (pix * tM), 0.0, 1.0);
            float facing = sqrt(max(1.0 - dMin * dMin, 0.0));   // 1 mid-disc, 0 at its rim
            cM = moonCol * (0.8 + 0.8 * facing);
        }

        // ---- put it together, back to front
        vec3 cP = vec3(0.0);
        if (aP > 0.0) {
            vec3 hitP = ro + rd * tP;
            vec3 n = abs(bulge.amp) < 5e-4 ? hitP / PLANET_R : planetNormal(hitP, bulge);
            cP = shadePlanet(hitP, n, rd, moonPos, moonCol);
        }
        if (tM < tP) { col = mix(col, cP, aP); col = mix(col, cM, aM); }
        else         { col = mix(col, cM, aM); col = mix(col, cP, aP); }

        // where the planet stands in front of the moon, it hides the glow
        hidden = aP * smoothstep(-0.3, 0.3, b - tP);
    }

    // ---- glow
    // Light scattered toward the camera by haze around the moon: bright
    // close in, with a long soft tail. w^2 / (w^2 + h^2) is 1 for a ray
    // straight through the moon and halves by h = w, the same shape a street
    // light makes in fog. The moon's own disc gets less of it, so it keeps
    // its colour instead of washing out white.
    const float GLOW_W2 = 0.12 * 0.12;
    float glow = GLOW_W2 / (GLOW_W2 + h2);
    col += moonCol * glow * (1.0 - 0.6 * aM) * (1.0 - hidden);

    // ---- a faint cool atmosphere just outside the planet's edge, brighter
    // on the key light's side. It lives in a thin ring, so everything else
    // skips it. keyOnScreen says which way the key light points, on screen.
    float edge = screenRadius(PLANET_R), haloOut = screenRadius(PLANET_R + 0.3);
    if (q2 > edge * edge && q2 < haloOut * haloOut) {
        const vec2 keyOnScreen = vec2(dot(KEY_DIR, CAM_RT), dot(KEY_DIR, CAM_UP));
        float qd   = sqrt(q2);
        float lit  = max(dot(q, keyOnScreen) / qd, 0.0);
        // back from screen units to world units past the edge, near enough
        float halo = exp(-12.0 * (qd - edge) * (CAM_DIST / FOCAL)) * (1.0 - aP);
        col += toLinear(dragonBlue) * halo * 0.05 * (0.3 + lit);
    }

    // ---- out
    if (max(col.r, max(col.g, col.b)) > 0.6) col = tonemap(col);
    col = sqrt(col);
    // Dither: nudge each pixel by up to one step of the 0..255 range, in a
    // fine noise pattern. Otherwise 8-bit colour draws visible bands across
    // slow, dark gradients like this background.
    col += (fract(52.9829189 * fract(dot(fragCoord, vec2(0.06711056, 0.00583715)))) - 0.5) / 255.0;
    fragColor = vec4(col, 1.0);
}
