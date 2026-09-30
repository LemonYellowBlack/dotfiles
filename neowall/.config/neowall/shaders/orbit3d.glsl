// orbit3d.glsl: orbit.glsl in 3D. Still two bodies, a big planet and a
// small moon, still reading the same three numbers:
//
//   cpu    the orbit's shape. Idle: a lazy, almost round orbit. Busy: a long
//          ellipse whose close pass skims the planet's surface
//   ram    how fast the moon goes around
//   heat   the moon's colour, fuji white -> old white, and so the colour
//          of the light it throws on the planet
//
// What makes it move like motion graphics instead of a clock hand:
//   - the moon obeys Kepler: it whips through the close pass and hangs at
//     the far end, so every orbit has its own ease-in and ease-out
//   - the planet reacts: its surface swells toward the moon as it passes,
//     trails behind it, and wobbles back like a liquid once it's gone
//   - the moon is the only light: the planet goes through phases as it
//     circles, it glints in the planet's coat, shines through its thin
//     edge from behind, and gets eclipsed by it
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
//
// Every number worth tweaking is in SETTINGS, just below, grouped by what it
// does. Change one, save, then `neowall reload` to see it. Distances are in
// planet radii: the planet's radius is 1.

// ============================================================================
// SETTINGS
// ============================================================================

// --- colours
// The Kanagawa Wave colours this uses (copied from colors.glsl, which has
// the full palette: neowall has no #include)...
const vec3 sumiInk0    = vec3(0.086, 0.086, 0.114);  // #16161D
const vec3 winterBlue  = vec3(0.145, 0.145, 0.208);  // #252535
const vec3 crystalBlue = vec3(0.494, 0.612, 0.847);  // #7E9CD8
const vec3 dragonBlue  = vec3(0.396, 0.522, 0.580);  // #658594
const vec3 fujiWhite   = vec3(0.863, 0.843, 0.729);  // #DCD7BA
const vec3 oldWhite    = vec3(0.784, 0.753, 0.576);  // #C8C093

// ...and which one goes where
const vec3 PLANET_COLOR  = crystalBlue;
const vec3 MOON_COOL     = fujiWhite;    // the moon when the CPU is cool...
const vec3 MOON_HOT      = oldWhite;     // ...and when it's hot
const vec3 AIR_COLOR     = dragonBlue;   // the thin air round the planet
const vec3 BACKDROP      = sumiInk0;     // the background
const vec3 BACKDROP_GLOW = winterBlue;   // the background's lift behind the planet

// --- the three inputs
// Each is stretched over the range it really covers on this laptop (XPS 15
// 7590, measured Sep 2026), not the whole 0..1: across ordinary use iCpu sat
// at 0.04..0.07, which would only ever have used the first 7% of the orbit's
// shapes. smoothstep(lo, hi, x) turns lo..hi into 0..1, flat at both ends,
// so everyday noise below lo doesn't wobble anything.
//   iCpuMax   the busiest CPU thread. iCpu averages all 12, so one thread
//             flat out reads as just 0.08. Idle, this wanders 0.1..0.3
//   iRam      used / total. With 16 GB it lives around 0.3..0.6
//   iThermal  (hottest CPU sensor - 30 C) / 65 C. The graphics chip sits in
//             the same package, so with this wallpaper on screen the CPU
//             idles around 70 C; flat out it heads for 95 C
const vec2 BUSY_RANGE = vec2(0.30, 0.95);     // iCpuMax
const vec2 RAM_RANGE  = vec2(0.25, 0.75);     // iRam
const vec2 HEAT_RANGE = vec2(0.68, 0.97);     // iThermal: 74 C .. 93 C
const vec3 INPUT_LAG  = vec3(1.5, 3.0, 4.0);  // seconds each takes to catch up: cpu, ram, heat

// --- the orbit
// Its close pass is at a distance of ORBIT_SIZE * (1 - eccentricity) from
// the planet's centre: past ~0.43 eccentricity the moon hits the planet.
const vec2  ORBIT_ECC   = vec2(0.24, 0.37);  // how stretched: idle .. busy (0 = a circle)
const float ORBIT_SIZE  = 1.95;              // half the ellipse's long diameter
const vec2  ORBIT_RATE  = vec2(0.11, 0.16);  // orbits a second: little RAM in use .. lots
const float ORBIT_TILT  = 0.30;              // radians the orbit tips toward the camera
const float ORBIT_ROLL  = -0.16;             // radians it rolls, so it runs on a diagonal
// The ellipse itself slowly turns (apsidal precession): the close pass
// starts off at the planet's right edge, where the bulge shows best, then
// drifts behind, round the left, and back.
const float ORBIT_START       = -0.35;       // radians: where the close pass starts (0 = right)
const float PRECESSION_PERIOD = 160.0;       // seconds for the ellipse to turn once

// --- the pull: how hard the moon tugs on the planet's surface
// Sets the height the bulge heads for, from the gap between the planet's
// surface and the moon's centre: nothing past PULL_REACH, full PULL at
// PULL_CLOSEST, and PULL_CURVE bending the ramp between them. 1 is a
// straight ramp; below 1 pulls hard from further out; above 1 saves it for
// the close pass.
// An idle orbit's far end is a gap of ~1.42: with PULL_REACH past that the
// pull never lets go, so the planet never settles back into a sphere and is
// raymarched every frame (a little more GPU).
const float PULL         = 0.33;  // strength: the height it heads for at the closest pass
const float PULL_REACH   = 1.6;   // no pull at all beyond this gap
const float PULL_CLOSEST = 0.2;   // full strength at this gap (about the closest the moon comes)
const float PULL_CURVE   = 0.4;   // the ramp's shape (see above)

// --- the bulge: its shape, and how it moves
const float BULGE_MAX    = 0.40;              // the tallest it may get
const float BULGE_DENT   = 0.35 * BULGE_MAX;  // the deepest a wobble may dent it
const float TIP_SHARE    = 0.55;              // how much of it is the narrow tip; the rest is a broad swell
const vec2  TIP_SHARP    = vec2(4.0, 9.0);    // tip narrowness: small bulge .. tall one (bigger = narrower)
const float TIP_SHARP_AT = 0.2;               // the height where the tip is at its narrowest
const float SWELL        = 2.5;               // the swell's narrowness (smaller = more of the side leans out)
// it's a damped spring: it lags on the way up, overshoots, and rings after
const float WOBBLE_HZ      = 0.95;            // how fast it springs: wobbles a second
const float WOBBLE_DAMPING = 0.18;            // 0 rings forever, under 1 overshoots and rings, 1 doesn't
// how quickly it turns to face the moon: slowly while the tug is weak, so
// the wobble after a pass stays put, and fast while it's strong
const vec2  FOLLOW      = vec2(1.5, 13.5);    // turning speed: weak tug .. strong (higher = tighter)
const float FOLLOW_FULL = 0.6;                // the tug, as a share of PULL, that gets the fast end

// --- the moon
const float MOON_R         = 0.1;             // its radius (the same 10:1 ratio as the 2D circles)
const float STRETCH_FROM   = 1.2;             // speed where it starts to stretch along its path
const float STRETCH_AMOUNT = 0.15;            // how much longer it gets per unit of speed past that
const float MOON_WARM_BASE = 0.3;             // how far toward MOON_HOT it already is when cool

// --- light
// The moon is the only light in the scene. Everything you see lit, the
// planet, its sheen, its edge, the air around it, is lit by the moon, so
// the whole picture changes as it goes round: the planet is "full" when the
// moon is in front of it, half-lit when it's to one side, and just a
// glowing rim when it's behind.
const float MOON_POWER     = 20.0;   // how brightly it lights the planet
const float LIGHT_FILL     = 0.08;   // the glow's soft light, reaching past the day/night line
const float RIM_GLOW       = 1.2;    // the planet's edge glowing with the moon behind it
const float RIM_SIDE       = 0.35;   // how gradually that fades round the edge (bigger = further round)
const float COAT_REFLECT   = 0.05;   // how glossy the coat is, head-on (it rises to 1 at the edge)
const float GLINT          = 4.0;    // how bright the moon's reflection in the coat is
const float GLINT_BLUR     = 0.3;    // how soft that reflection is, as a share of the moon's radius...
const float GLINT_BLUR_FAR = 0.03;   // ...plus this much more per unit of distance to the moon

// --- the moon's own look, apart from the light it throws
const float MOON_GLARE    = 0.6;             // brightness of its disc and glow (the planet's is MOON_POWER)
const vec2  MOON_SHADE    = vec2(0.8, 1.6);  // its disc's brightness: at the rim .. in the middle
const float GLOW_WIDTH    = 0.12;            // how far its glow spreads (half as bright this far out);
                                             // also the sheen round its reflection in the coat
const float GLOW_DISC_DIM = 0.6;             // how much glow the disc itself skips, so it keeps its colour

// --- the air round the planet, and the backdrop
const float AIR_GLOW      = 0.15;            // brightness of the thin air where the moon lights it
const float AIR_THICKNESS = 0.5;             // how far it can reach past the planet's edge (it fades to 0 by here)
const float AIR_FALLOFF   = 12.0;            // how fast it thins out (bigger = a tighter ring)
const float AIR_WISPS     = 0.5;             // how uneven its reach is round the ring (0 = a perfect circle, keep under ~0.8)
const vec2  AIR_BACKLIT   = vec2(0.2, 2.2);  // its brightness: moon in front .. moon behind
const float AIR_TINT      = 0.5;             // how much it takes the moon's colour (0 = all AIR_COLOR)
const float BACKDROP_LIFT   = 0.45;          // how much the background brightens behind the planet
const float BACKDROP_SPREAD = 3.0;           // how tight that is (bigger = smaller)
const float TONE_KNEE     = 0.6;             // brightness where highlights start rolling off instead of clipping

// --- the camera
// With these, the orbit's far ends were checked to fit a 16:9 screen; a
// closer camera or a longer lens can push the near side off the bottom.
const float CAM_DIST      = 8.0;             // how far back it sits
const float FOCAL         = 2.0;             // zoom: bigger = narrower lens
const float CAM_ELEVATION = 0.2;             // radians above the orbit's floor it looks down from
const float CAM_AIM_Y     = -0.12;           // aims this far below the planet's centre, which sits
                                             // the planet high and leaves room for the orbit's near side

// --- quality vs speed
const int   MARCH_STEPS = 48;                // most steps a ray takes looking for the bulged surface
const float MARCH_STEP  = 0.9;               // how far each step goes, as a share of the safe distance:
                                             // lower is safer on steep bulges, but slower

// ============================================================================
// Everything below is how it works: tuning shouldn't need anything past here.
// The numbers still written inline are maths, safety margins, tricks for the
// GPU's number format, and a few small shape details not worth a setting.
// ============================================================================

const float TAU = 6.28318531;

// Lighting maths only works on "linear" colour values. Hex colours are
// stored gamma-encoded (bent so dark shades get more of the 0..255 range),
// so decode them before lighting (square them) and re-encode once at the
// very end (square root). The exact curve is closer to a power of 2.2, but
// 2 is near enough, and sqrt is far cheaper than pow per pixel.
vec3 toLinear(vec3 c) { return c * c; }

// The unit everything is measured in: leave it at 1.
const float PLANET_R = 1.0;

// The camera never moves, so its whole setup is constants the compiler
// works out once, instead of maths every pixel repeats.
const vec3  CAM_POS  = CAM_DIST * vec3(0.0, sin(CAM_ELEVATION), cos(CAM_ELEVATION));
const vec3  CAM_FW   = normalize(vec3(0.0, CAM_AIM_Y, 0.0) - CAM_POS);
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
// the camera by ORBIT_TILT so we look down onto it, then rolls by
// ORBIT_ROLL so it runs on a slight diagonal. ORBIT_U and ORBIT_V are two
// perpendicular directions lying in that plane (U points right, V away from
// the camera); any spot on the orbit is some amount of each.
const vec3  ORBIT_U = vec3(cos(ORBIT_ROLL), sin(ORBIT_ROLL), 0.0);
const vec3  ORBIT_V = vec3(-sin(ORBIT_TILT) * sin(ORBIT_ROLL), sin(ORBIT_TILT) * cos(ORBIT_ROLL),
                           -cos(ORBIT_TILT));

struct Orbit {
    float e;      // eccentricity: 0 = circle, toward 1 = long and thin
    float a;      // semi-major axis: half the ellipse's long diameter
    float rate;   // orbits per second
    float turn;   // the angle the ellipse's long axis points at
};

// m = smoothed (busiest thread, ram, heat), turns = how far the ellipse has
// turned so far (whole turns don't matter)
Orbit orbitFor(vec3 m, float turns) {
    Orbit o;
    o.e    = mix(ORBIT_ECC.x, ORBIT_ECC.y, smoothstep(BUSY_RANGE.x, BUSY_RANGE.y, m.x));
    o.a    = ORBIT_SIZE;
    o.rate = mix(ORBIT_RATE.x, ORBIT_RATE.y, smoothstep(RAM_RANGE.x, RAM_RANGE.y, m.y));
    o.turn = ORBIT_START + TAU * turns;
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
// settle at if the moon held still: the pull settings, as a formula. Having
// no tug at all for part of the orbit gives the surface a chance to settle
// back into a sphere, which makes each pass an event, and lets the planet
// skip the raymarch meanwhile.
float pullTarget(vec3 moonPos) {
    float gap = length(moonPos) - PLANET_R;
    return PULL * pow(clamp((PULL_REACH - gap) / (PULL_REACH - PULL_CLOSEST), 0.0, 1.0), PULL_CURVE);
}

// The simulation's output: one row of texels, each holding one thing.
const int S_METRICS    = 0;   // smoothed busiest thread, ram, heat (+ the marker, see below)
const int S_PHASE      = 1;   // orbit phase, then the ellipse's turn: coarse and fine part each
const int S_SPRING     = 2;   // bulge height, and how fast it's moving
const int S_BULGE      = 3;   // bulge direction, and its height (capped)
const int S_MOON_HI    = 4;   // moon position, coarse part
const int S_MOON_LO    = 5;   // moon position, fine part
const int S_MOON_V     = 6;   // moon heading, and how stretched it is
const int S_SCREEN     = 7;   // the moon on screen: where, how big, how hot
const int S_METRICS_LO = 8;   // smoothed inputs, fine part (S_METRICS holds the coarse)
const int S_COUNT      = 9;

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
    // the same in seconds at any frame rate. INPUT_LAG is roughly the time
    // it takes to get 63% of the way to a new value.
    // Stored in two parts, like the positions: near 1 a half float moves in
    // steps of ~0.0005, and one frame's nudge toward a value that's close is
    // smaller than that, so a single number would stall short of it. For
    // heat at 60 fps that was up to 0.12 short: 8 C, reading too cool.
    vec3 live = vec3(iCpuMax, iRam, iThermal);
    vec3 prev = prevM.rgb + prevL.rgb;
    vec3 m    = fresh ? live : mix(prev, live, 1.0 - exp(-dt / INPUT_LAG));

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
    const float W = TAU * WOBBLE_HZ;   // natural frequency, in radians a second
    const float Z = WOBBLE_DAMPING;
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
    float follow = mix(FOLLOW.x, FOLLOW.y, clamp(pull / (FOLLOW_FULL * PULL), 0.0, 1.0));
    dir = normalize(mix(dir, toMoon, 1.0 - exp(-follow * dt)));

    // --- the moon's look: stretched when fast, warmer when hot
    float speed   = length(moonVel);
    float stretch = 1.0 + STRETCH_AMOUNT * max(speed - STRETCH_FROM, 0.0);
    float warmth  = smoothstep(HEAT_RANGE.x, HEAT_RANGE.y, m.z);

    // --- where the moon lands on screen, for the drawing pass's shortcut
    // (the same projection the camera ray does, run backwards: z is the
    // moon's depth in front of the camera, and x/z, y/z its screen spot)
    vec3  cv = moonPos - CAM_POS;
    float z  = dot(cv, CAM_FW);
    vec2  onScreen = FOCAL * vec2(dot(cv, CAM_RT), dot(cv, CAM_UP)) / z;

    // each texel keeps its own slice of all that
    vec4 outv;
    if      (px.x == S_METRICS)    outv = vec4(coarse(m), 0.75);
    else if (px.x == S_METRICS_LO) outv = vec4(m - coarse(m), 0.0);
    else if (px.x == S_PHASE)      outv = vec4(phase, turn);
    else if (px.x == S_SPRING)     outv = vec4(h, v, 0.0, 0.0);
    else if (px.x == S_BULGE)      outv = vec4(dir, clamp(h, -BULGE_DENT, BULGE_MAX));
    else if (px.x == S_MOON_HI)    outv = vec4(coarse(moonPos), 0.0);
    else if (px.x == S_MOON_LO)    outv = vec4(moonPos - coarse(moonPos), 0.0);
    else if (px.x == S_MOON_V)     outv = vec4(moonVel / max(speed, 1e-4), stretch);
    else                           outv = vec4(onScreen, z / FOCAL, warmth);
    fragColor = outv;
}

// ===== drawing helpers =====
// neowall gives code placed between the two mainImage functions to the
// second pass only.

// How brightly the moon lights a spot that sees it at apparent size sinS
// (its radius over its distance). Real light fades with the square of
// distance, sinS^2; this fades with distance itself, much gentler, so the
// moon floods the whole side facing it from anywhere on its orbit. With
// real falloff and the moon this close, it lights a small hot pool right
// under itself and leaves the rest dark. Mid-orbit this is 5x real, the
// close pass about the same, so the flare as it swoops in survives.
float moonBright(float sinS) { return MOON_POWER * sinS; }

// The glow around the moon: light scattered by haze, bright close in with
// a long soft tail. h2 is how close a ray passes the moon's centre
// (squared, in world units). w^2 / (w^2 + h^2) is 1 for a ray straight
// through the moon and halves by h = w, the same shape a street light makes
// in fog. It's both the glow you see and what the planet's coat reflects.
const float GLOW_W2 = GLOW_WIDTH * GLOW_WIDTH;
float haze(float h2) { return GLOW_W2 / (GLOW_W2 + h2); }

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

// The bulge's shape. c is the cosine of the angle between a spot and the
// peak (1 on top, 0 a quarter of the way round), and exp((c - 1) * s) turns
// that into a smooth bump: 1 at the peak, fading to nothing, narrower the
// bigger s is. Two of them: a narrow one for the tip, reaching for the
// moon, on top of a broad swell, so the planet's whole near side leans out
// toward it instead of one spike growing out of a ball.
float bulgeShape(float c, float sharp) {
    return TIP_SHARE * exp((c - 1.0) * sharp) + (1.0 - TIP_SHARE) * exp((c - 1.0) * SWELL);
}
// ...and how steeply that changes with c, for the normal below
float bulgeSlope(float c, float sharp) {
    return TIP_SHARE * sharp * exp((c - 1.0) * sharp)
         + (1.0 - TIP_SHARE) * SWELL * exp((c - 1.0) * SWELL);
}

// Distance to the planet: raymarch3D.glsl's sphere, with the radius pushed
// out by the bulge.
float planetDist(vec3 p, Bulge b) {
    float r = length(p);
    float c = dot(p, b.dir) / r;
    return r - PLANET_R - b.amp * bulgeShape(c, b.sharp);
}

// The normal, worked out with calculus instead of the six extra distance
// calls normalAt makes in raymarch3D.glsl: start from a plain sphere's
// normal (p / r), then tilt it away from the peak by the bulge's slope.
vec3 planetNormal(vec3 p, Bulge b) {
    float r = length(p);
    vec3  n = p / r;
    float c = dot(n, b.dir);
    float slope = b.amp * bulgeSlope(c, b.sharp) / r;
    return normalize(n - slope * (b.dir - c * n));
}

// Maps the stretched moon onto a unit sphere, so hitting it is plain
// ray-vs-sphere maths. Along its heading it's MOON_R * s long, across it
// MOON_R / sqrt(s), so its volume stays the same as it stretches.
vec3 squash(vec3 x, vec3 dir, float s) {
    float along = dot(x, dir);
    return ((x - along * dir) * sqrt(s) + along * dir / s) / MOON_R;
}

vec3 shadePlanet(vec3 p, vec3 n, vec3 rd, vec3 moonPos, vec3 moonCol) {
    vec3  v      = -rd;
    float ndv    = clamp(dot(n, v), 0.0, 1.0);
    float f      = 1.0 - ndv;
    // glancing angles reflect more (Schlick's approximation of Fresnel)
    float fres   = COAT_REFLECT + (1.0 - COAT_REFLECT) * f * f * f * f * f;
    vec3  albedo = toLinear(PLANET_COLOR);

    // The moon's light. sinS is its apparent size from here, and it fades
    // with distance (moonBright, above), so the planet flares as the moon
    // swoops in. A big light also reaches past the day/night line, by about
    // its apparent size, and smoothstep eases it out there: a plain clamp
    // stops with a corner, and under a light this bright the eye picks the
    // corner out as a line.
    vec3  toM  = moonPos - p;
    float dm   = length(toM);
    vec3  lm   = toM / dm;
    float sinS = MOON_R / dm;
    vec3  moonLight = moonCol * moonBright(sinS);
    float toward = dot(n, lm);          // 1 facing the moon, -1 facing away
    vec3  col = albedo * moonLight * smoothstep(0.0, 1.0, (toward + sinS) / (1.0 + sinS));

    // The haze around the moon lights the planet too: faintly, and from
    // all round the moon rather than one point, so it reaches further past
    // the day/night line. That keeps the edge of the dark side soft instead
    // of cut out with scissors.
    float wrap = 0.5 + 0.5 * toward;
    col += albedo * moonLight * LIGHT_FILL * wrap * wrap;

    // Translucency: when the moon is behind the planet, its light glows
    // through the thin edge we look through. `behind` is 1 when the moon's
    // light heads straight at the camera, and f^2 keeps the glow to the
    // edge, where there's least planet in the way. `near` keeps it to the
    // moon's side of the edge: the far side's light would have to cross the
    // whole planet. With the moon dead behind, every bit of the edge is
    // side-on to it (toward ~ 0), so the whole ring glows evenly, like the
    // ring round an eclipse.
    float behind = clamp(dot(v, -lm), 0.0, 1.0);
    float near   = smoothstep(-RIM_SIDE, RIM_SIDE, toward);
    col += moonLight * behind * behind * f * f * near * RIM_GLOW;

    // Reflections. With nothing else lit, the glossy coat has only the moon
    // to reflect: the disc itself, and a sheen of its glow around it. The
    // reflected ray "hits" the moon if it passes within MOON_R of its
    // centre; the edge is blurred a bit more the further the moon is, like a
    // real glossy coat. The glow is squared here so it fades fast: its long
    // tail would otherwise catch every ray skimming the planet's edge
    // (where the coat reflects nearly everything) and draw a glowing
    // outline all the way round whenever the moon is behind.
    vec3  r     = reflect(rd, n);
    float along = dot(toM, r);
    if (along > 0.0) {
        float miss2 = dm * dm - along * along;   // how close it passes, squared
        float miss  = sqrt(max(miss2, 0.0));
        float blur  = MOON_R * GLINT_BLUR + GLINT_BLUR_FAR * along;
        float disc  = smoothstep(MOON_R + blur, MOON_R - blur, miss);
        float sheen = haze(miss2);
        col += fres * moonCol * (GLINT * disc + sheen * sheen);
    }

    return col;
}

// Highlights roll off smoothly instead of clipping. Below the knee (the
// whole background, most of the planet) values pass through untouched, so
// the backdrop still comes out as exactly its hex colour.
vec3 tonemap(vec3 c) {
    vec3 over = max(c - TONE_KNEE, 0.0);
    return min(c, vec3(TONE_KNEE)) + over / (1.0 + over / (1.0 - TONE_KNEE));
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
    vec3  moonCol = toLinear(mix(MOON_COOL, MOON_HOT, MOON_WARM_BASE + (1.0 - MOON_WARM_BASE) * scr.w));
    vec2  dm      = (p - scr.xy) * scr.z;
    float h2      = dot(dm, dm);    // how close this pixel's ray passes the moon, squared

    // ...and how far it is from the planet's centre on screen (squared).
    // screenRadius() converts a distance from the planet's centre in the
    // world into one on screen, so these tests stay in screen units.
    vec2  q  = p - PLANET_ON_SCREEN;
    float q2 = dot(q, q);

    // background: the backdrop colour, lifted behind the planet
    vec3 col = mix(toLinear(BACKDROP), toLinear(BACKDROP_GLOW),
                   BACKDROP_LIFT * exp(-BACKDROP_SPREAD * dot(p, p)));

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
        Bulge bulge   = Bulge(bs.xyz, bs.w, mix(TIP_SHARP.x, TIP_SHARP.y, clamp(bs.w / TIP_SHARP_AT, 0.0, 1.0)));

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
            // planetDist measures straight out from the centre, which on a
            // steep bulge is a little more than the true distance, so each
            // step only goes MARCH_STEP of the way: a full step could jump
            // the tip.
            vec2 bound = sphereHits(ro, rd, PLANET_R + max(bulge.amp, 0.0) + 1e-4);
            if (bound.y > 0.0) {
                float t = bound.x, dMin = 1e9, tMin = t;
                bool hit = false;
                for (int i = 0; i < MARCH_STEPS; i++) {
                    float d = planetDist(ro + rd * t, bulge);
                    if (d < dMin) { dMin = d; tMin = t; }
                    if (d < 0.5 * pix * t) { hit = true; break; }
                    t += MARCH_STEP * d;
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
            cM = moonCol * mix(MOON_SHADE.x, MOON_SHADE.y, facing) * MOON_GLARE;
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
    // The haze around the moon, seen straight on (haze() is up with the
    // helpers). The moon's own disc gets less of it, so it keeps its colour
    // instead of washing out white.
    col += moonCol * MOON_GLARE * haze(h2) * (1.0 - GLOW_DISC_DIM * aM) * (1.0 - hidden);

    // ---- a faint atmosphere just outside the planet's edge, lit by the
    // moon: on the moon's side, brighter the closer the moon is, and
    // brightest when the moon is behind the planet, because thin air glows
    // most when you look through it toward the light. It lives in a thin
    // ring, so everything else skips it.
    float edge = screenRadius(PLANET_R), haloOut = screenRadius(PLANET_R + AIR_THICKNESS);
    if (q2 > edge * edge && q2 < haloOut * haloOut) {
        // the moon in the world, rebuilt from where it lands on screen and
        // how far away it is: Buffer A's projection, run backwards
        vec3  mPos = CAM_POS + scr.z * (scr.x * CAM_RT + scr.y * CAM_UP + FOCAL * CAM_FW);
        float qd   = sqrt(q2);
        vec2  md   = scr.xy - PLANET_ON_SCREEN;          // toward the moon, on screen
        float side = max(dot(q, md) / (qd * max(length(md), 1e-4)), 0.0);
        // with the moon right behind (or in front of) the middle, it lights
        // the whole ring evenly, like the ring round an eclipse
        float lit  = mix(1.0, side, smoothstep(0.0, edge, length(md)));
        // lit as brightly as the planet's edge: from outside a sphere, the
        // distance to its edge is sqrt(D^2 - 1)
        float near = moonBright(MOON_R / sqrt(max(dot(mPos, mPos) - 1.0, 0.05)));
        float back = smoothstep(0.0, 1.5, dot(mPos, CAM_FW));   // 1 well behind the planet
        // how far out: 0 at the planet's edge .. 1 at the ring's outer limit
        float x    = (qd - edge) / (haloOut - edge);
        // uneven reach round the ring: three slow waves of unrelated sizes.
        // Whole-number waves only: atan jumps from pi to -pi at the planet's
        // left, and only they match on both sides of the jump.
        float ang  = atan(q.y, q.x);
        float wisp = 0.5 * sin( 3.0 * ang + 0.11 * iTime)
                   + 0.3 * sin( 7.0 * ang - 0.07 * iTime + 2.0)
                   + 0.2 * sin(13.0 * ang + 0.05 * iTime + 4.0);
        float fall = AIR_FALLOFF * (1.0 - AIR_WISPS * wisp);
        // back from screen units to world units past the edge, near enough;
        // faded to exactly 0 by the ring's outer limit, so no hard edge
        float halo = exp(-fall * (qd - edge) * (CAM_DIST / FOCAL))
                   * (1.0 - smoothstep(0.4, 1.0, x)) * (1.0 - aP);
        col += mix(toLinear(AIR_COLOR), moonCol, AIR_TINT) * halo * near * lit
             * mix(AIR_BACKLIT.x, AIR_BACKLIT.y, back) * AIR_GLOW;
    }

    // ---- out
    if (max(col.r, max(col.g, col.b)) > TONE_KNEE) col = tonemap(col);
    col = sqrt(col);
    // Dither: nudge each pixel by up to one step of the 0..255 range, in a
    // fine noise pattern. Otherwise 8-bit colour draws visible bands across
    // slow, dark gradients like this background.
    col += (fract(52.9829189 * fract(dot(fragCoord, vec2(0.06711056, 0.00583715)))) - 0.5) / 255.0;
    fragColor = vec4(col, 1.0);
}
