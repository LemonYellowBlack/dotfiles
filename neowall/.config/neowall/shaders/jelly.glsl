// jelly.glsl: a living drop of jelly. It sits on a dark, glossy floor,
// breathes, oozes and hops, and it reads the same three numbers as
// orbit3d:
//
//   cpu    its energy. Idle: it breathes slowly and now and then does a
//          small hop. Busy: it bounces about. A sudden spike startles it
//          into a jump, whatever the level was
//   ram    how much it has eaten: its size. A bigger jelly is heavier, so it
//          wobbles slower
//   heat   its colour: spring blue when cool, through violet and pink, to
//          orange when the CPU runs hot; its glow gets brighter as it warms
//
// What makes it feel alive, mostly borrowed from animators:
//   - it moves by itself and reacts to things: hops come from inside it,
//     at uneven times, and a CPU spike makes it flinch. More than any
//     texture, that is what makes a shape read as a creature
//   - squash and stretch: it pancakes when it lands and stretches when it
//     takes off, keeping its volume either way
//   - anticipation: it squats, and leans back, before every hop
//   - follow-through: nothing stops at once. The body is two weights on a
//     spring, so a landing squashes it, it springs back up, maybe bounces,
//     and wobbles to rest. Its core and three droplets hang off it on
//     springs of their own, each ringing at its own rate
//   - it's never quite still: it breathes, a heartbeat pulses its glow,
//     lumps crawl under its skin, bubbles drift up through it
//   - it oozes: a hard landing splashes droplets off it. They land, then
//     crawl home in little surges and melt back in
//
// Its texture is light doing things, not a pattern painted on: the colour
// deepens where it's thick, its core glows through it, bubbles catch the
// light, its skin is mottled, and it throws a pool of its own light onto
// the floor.
//
// Two passes, wired up by jelly.neowall, the same shape as orbit3d:
//   first    the simulation. It remembers everything between frames, and
//            works out everything that's the same for every pixel, once
//   second   draws the scene from that, once per pixel
//
// Like orbit3d, most of this file's shape comes from the second pass
// running 8.3 million times a frame at 4K, on a GPU that also has to show
// everything else. There's a section on what that costs near the bottom.
//
// Every number worth tweaking is in SETTINGS, just below, grouped by what
// it does. Change one, save, then `neowall reload` to see it. Distances are
// in world units: the jelly's radius is 0.9 with a little RAM in use, 1.1
// with lots.

// ============================================================================
// SETTINGS
// ============================================================================

// --- colours
// The Kanagawa Wave colours this uses (copied from colors.glsl, which has
// the full palette: neowall has no #include)...
const vec3 sumiInk0     = vec3(0.086, 0.086, 0.114);  // #16161D
const vec3 winterBlue   = vec3(0.145, 0.145, 0.208);  // #252535
const vec3 springBlue   = vec3(0.498, 0.706, 0.792);  // #7FB4CA
const vec3 oniViolet    = vec3(0.584, 0.498, 0.722);  // #957FB8
const vec3 sakuraPink   = vec3(0.824, 0.494, 0.600);  // #D27E99
const vec3 surimiOrange = vec3(1.000, 0.627, 0.400);  // #FFA066
const vec3 fujiWhite    = vec3(0.863, 0.843, 0.729);  // #DCD7BA

// ...and which one goes where. The jelly runs through the four heat
// colours as the CPU warms up: the first until HEAT_HOLD of the way, then
// evenly through the other three.
const vec3  JELLY_COOL = springBlue;
const vec3  JELLY_WARM = oniViolet;
const vec3  JELLY_HOT  = sakuraPink;
const vec3  JELLY_HOTTEST = surimiOrange;
const float HEAT_HOLD  = 0.25;
const vec3  BACKDROP   = sumiInk0;     // the dark everything sits in
const vec3  SKY_TINT   = winterBlue;   // what its skin reflects from above
const vec3  LIGHT_TINT = fujiWhite;    // the colour of the studio lights

// --- the three inputs
// The same readings and ranges as orbit3d (see its comments for how these
// were measured): smoothstep(lo, hi, x) turns lo..hi into 0..1.
//   iCpuMax   the busiest CPU thread. Idle, this wanders 0.1..0.3
//   iRam      used / total, around 0.3..0.6 with 16 GB
//   iThermal  (hottest CPU sensor - 30 C) / 65 C
const vec2 BUSY_RANGE = vec2(0.30, 0.95);     // iCpuMax
const vec2 RAM_RANGE  = vec2(0.25, 0.75);     // iRam
const vec2 HEAT_RANGE = vec2(0.68, 0.97);     // iThermal: 74 C .. 93 C
const vec3 INPUT_LAG  = vec3(3.0, 6.0, 4.0);  // seconds each takes to catch up: cpu, ram, heat

// --- the body
// Physically, the body is two weights, a "foot" at its bottom and a "head"
// at its top, joined by a spring. Its shape is drawn around them: the gap
// between them sets how squashed or stretched it is, and the head sitting
// off to one side of the foot makes it lean. Everything bouncy it does
// comes out of that spring.
const vec2  SIZE           = vec2(0.9, 1.1);  // its radius: little RAM in use .. lots
const float GRAVITY        = 16.0;            // units a second, per second (bigger = snappier hops)
const float SQUASH_HZ      = 1.4;             // how fast it springs up and down, sitting
const float SQUASH_DAMPING = 0.14;            // 0 wobbles forever, 1 doesn't wobble at all
const float SWAY_HZ        = 1.1;             // how fast its top sways side to side
const float SWAY_DAMPING   = 0.12;
const float FRICTION       = 10.0;            // how fast its foot stops sliding on the floor
const float SINK           = 0.10;            // how far (in radii) its foot presses into the floor,
                                              // which flattens its bottom against it
const float SQUASH_LIMIT   = 0.35;            // the flattest it can go, as a share of its round height
const float BOUNCE         = 0.1;             // how much of a landing its foot bounces back

// --- hopping
const vec2  HOP_EVERY       = vec2(14.0, 1.8);  // seconds between hops, on average: idle .. busy
const float HOP_RANDOM      = 0.6;              // each gap is up to this share longer or shorter
const vec2  HOP_HEIGHT      = vec2(0.25, 1.8);  // how high (in radii): idle .. busy
const vec2  HOP_REACH       = vec2(0.3, 1.1);   // how far sideways (in radii)
const float SQUAT_TIME      = 0.30;             // seconds it squats first (anticipation)
const float SQUAT_DEPTH     = 0.25;             // how low it squats before a full-power hop
const float LEAN_BACK       = 0.25;             // how far it leans away from where it's about to go
const float TAKEOFF_STRETCH = 0.25;             // how much faster its head leaves than its foot
const float WANDER          = 2.0;              // how far from the middle it likes to roam
const float SETTLE_TIME     = 0.35;             // seconds on the floor before it will hop again

// --- the startle
// A flinch is a jump in the CPU, not a level: the reading averaged over
// SPIKE_LAG against the one averaged over INPUT_LAG.x.
const float SPIKE_JUMP      = 0.35;  // how far the quick average must leap above the slow one
const float SPIKE_LAG       = 0.25;  // seconds, for the quick average
const float FLINCH_COOLDOWN = 8.0;   // seconds before it can be startled again
const float FLINCH_STRENGTH = 0.5;   // the jump's power (0 = an idle hop, 1 = a busy one)
const float FLINCH_SQUAT    = 0.08;  // seconds it squats first: hardly any, it's startled

// --- splashes: three droplets, which are part of it until a landing
// throws them off. While home they're lumps near its bottom, each on a
// spring of its own, so they jiggle after it.
const float SPLASH_SPEED    = 6.0;   // how hard a landing must be to throw droplets
const float SPLASH_CHANCE   = 0.75;  // the chance each one goes
const float SPLASH_OUT      = 2.2;   // how fast they fly outward...
const float SPLASH_UP       = 2.6;   // ...and upward
const float DROP_R          = 0.26;  // a droplet's radius, as a share of the body's
const float DROP_BOUNCE     = 0.35;  // how much of a bounce off the floor a droplet keeps
const float DROP_FRICTION   = 4.0;   // how fast a thrown droplet stops sliding
const float CRAWL_DELAY     = 0.7;   // seconds a droplet lies there before crawling home
const float CRAWL_SPEED     = 0.8;   // how fast it crawls (in surges, so the average is lower)
const float CRAWL_SURGE_HZ  = 1.3;   // surges a second
const float MERGE_TIME      = 0.6;   // seconds for a droplet back home to firm up its spring
const float DROP_HZ         = 2.2;   // how fast a droplet at home jiggles
const float DROP_DAMPING    = 0.25;
const float DROP_HOME_DEPTH = 0.78;  // how deep in the body a droplet sits when home (share of the radius)
const float GOO             = 0.25;  // how far apart (in radii) two blobs start melting together

// --- the core: a denser, glowing heart that floats inside on a spring,
// so it lags when the body moves and sloshes when it lands
const float CORE_R       = 0.30;  // its radius, as a share of the body's
const float CORE_HZ      = 1.5;
const float CORE_DAMPING = 0.35;
const float CORE_DRIFT   = 0.10;  // how far it wanders about, even at rest

// --- life while it sits still
const vec2  BREATH_HZ    = vec2(0.16, 0.40);   // breaths a second: idle .. busy
const float BREATH       = 0.025;              // how much it swells
const vec2  HEART_HZ     = vec2(0.75, 1.6);    // heartbeats a second: idle .. busy
const float HEART_PULSE  = 0.3;                // how much each beat brightens its glow
const vec2  LUMP_RATE    = vec2(0.005, 0.014); // how fast lumps crawl under its skin: idle .. busy
const float LUMP_SIZE    = 0.07;               // how tall they get (in radii)
const float LUMP_SHARP   = 5.0;                // how narrow (bigger = narrower)
const float BOTTOM_HEAVY = 0.10;               // how much fatter it is at the bottom, like a drop
const vec2  BUBBLE_RATE  = vec2(0.004, 0.010); // how fast bubbles drift up through it
const float BUBBLE_R     = 0.06;               // their size (in radii)

// --- ripples: rings that run up its skin after a landing
const float RIPPLE_PER_SPEED = 0.0035;  // how tall, per unit of landing speed
const float RIPPLE_MAX       = 0.022;
const float RIPPLE_FADE      = 0.8;     // seconds for them to die down
const float RIPPLE_WAVES     = 7.0;     // rings from bottom to top
const float RIPPLE_SPEED     = 14.0;    // how fast they run

// --- light through the jelly
const float IOR          = 1.35;   // how strongly it bends light (water is 1.33)
const float BODY_GLOW    = 0.22;   // the glow of the jelly itself...
const float SCATTER      = 2.2;    // ...and how quickly it builds with thickness
const float ABSORB       = 2.0;    // how fast thick jelly deepens its own colour
const float MOTTLE       = 0.5;    // how blotchy its glow is (0 = even)
const float MOTTLE_SCALE = 3.0;    // how small the blotches are
const float CORE_LIGHT   = 0.08;   // how brightly the core lights the jelly around it
const float CORE_SURFACE = 0.3;    // how brightly the core itself shows
const float CORE_BEND    = 0.35;   // how much the jelly bends the view of its core (1 = fully)
const float BUBBLE_GLINT = 0.9;    // how brightly bubbles catch its glow

// --- the lights: nothing lights the scene but the jelly's own glow. These
// two only exist as reflections in its wet skin, like a studio's softboxes
const vec3  KEY_DIR    = normalize(vec3(-0.45, 0.85, 0.40));  // high, to the left, in front
const float KEY_BRIGHT = 30.0;
const vec2  KEY_EDGE   = vec2(0.982, 0.995);  // how big and how soft its reflection is
const vec3  RIM_DIR    = normalize(vec3(0.75, 0.30, -0.60));  // behind, to the right
const float RIM_BRIGHT = 3.0;
const vec2  RIM_EDGE   = vec2(0.90, 0.97);

// --- the floor: black and glossy, so it only shows where the jelly's
// light lands on it, and in the jelly's reflection
const float POOL         = 0.9;   // how brightly the jelly lights the floor
const float POOL_CLIP    = 2.5;   // right under it, the light levels off at about this
const float POOL_REACH   = 2.0;   // how far the pool spreads
const float POOL_EXTENT  = 3.2;   // no pool at all past this distance from the jelly
const float FLOOR_ALBEDO = 0.35;  // how much of that light the floor sends back
const float REFLECT      = 0.25;  // how bright the jelly's reflection is
const float REFLECT_FADE = 1.3;   // how fast the reflection fades as it gets further from the floor
const float TONE_KNEE    = 0.6;   // brightness where highlights start rolling off instead of clipping

// --- the camera
// With these, the highest busy hops still fit on a 16:9 screen.
const float CAM_DIST   = 12.5;   // how far back it sits
const float CAM_HEIGHT = 2.6;    // how high above the floor
const float CAM_AIM_Y  = 1.3;    // the height it looks at, above the jelly's spot
const float FOCAL      = 2.0;    // zoom: bigger = narrower lens

// --- quality vs speed
const int   MARCH_STEPS = 24;    // most steps a ray takes looking for the jelly's skin
const float MARCH_STEP  = 0.9;   // how far each step goes, as a share of the safe distance

// ============================================================================
// Everything below is how it works: tuning shouldn't need anything past here.
// ============================================================================

const float TAU = 6.28318531;

// Lighting maths only works on "linear" colour values, so hex colours are
// decoded (squared) before lighting and re-encoded (square root) at the end.
// orbit3d.glsl has the longer version of this.
vec3 toLinear(vec3 c) { return c * c; }

// The camera never moves, so its whole setup is constants.
const vec3 CAM_POS = vec3(0.0, CAM_HEIGHT, CAM_DIST);
const vec3 CAM_FW  = normalize(vec3(0.0, CAM_AIM_Y, 0.0) - CAM_POS);
const vec3 CAM_RT  = normalize(cross(CAM_FW, vec3(0.0, 1.0, 0.0)));
const vec3 CAM_UP  = cross(CAM_RT, CAM_FW);

// A world point -> where it lands on screen (xy, in the same units as p in
// the drawing pass) and how far in front of the camera it is (z): the
// camera ray run backwards.
vec3 project(vec3 w) {
    vec3  cv = w - CAM_POS;
    float z  = dot(cv, CAM_FW);
    return vec3(FOCAL * vec2(dot(cv, CAM_RT), dot(cv, CAM_UP)) / z, z);
}
// ...and a safe (slightly big) guess at how big a sphere of radius r looks
// on screen at distance z
float screenRadius(float r, float z) { return FOCAL * r / max(z - r, 0.1); }

// The simulation's output: one row of texels, each holding one thing.
// S_ ones are its memory, read back next frame. D_ ones are worked out for
// the drawing pass; the simulation never reads them.
const int S_METRICS    = 0;   // smoothed busiest thread, ram, heat (+ the marker, see below)
const int S_METRICS_LO = 1;   // the fine part of those, + the quick cpu average
const int S_FOOT_HI    = 2;   // the foot: position, coarse part + time on the floor
const int S_FOOT_LO    = 3;   //           position, fine part + time since the last landing
const int S_FOOT_V     = 4;   //           velocity + how far into a squat it is
const int S_HEAD_HI    = 5;   // the head: position, coarse part + the next hop's power
const int S_HEAD_LO    = 6;   //           position, fine part + startle cooldown
const int S_HEAD_V     = 7;   //           velocity + hops so far
const int S_CORE       = 8;   // the core, from the body's middle + ripple height
const int S_CORE_V     = 9;   // its velocity, likewise + how long this squat lasts
const int S_HOP        = 10;  // readiness to hop (coarse, fine) + which way
const int S_PHASE      = 11;  // breathing, lumps: each a coarse and fine part
const int S_PHASE2     = 12;  // bubbles, heartbeat: likewise
const int S_DROP_HI    = 13;  // 13..15 droplets: position, coarse part + whether they're home
const int S_DROP_LO    = 16;  // 16..18            position, fine part
const int S_DROP_V     = 19;  // 19..21            velocity
const int D_NEAR       = 22;  // the body's middle, + the radius of a sphere holding it
                              // (negative when a droplet is out beyond that)
const int D_COLOR      = 23;  // glow colour, glow power
const int D_BODY0      = 24;  // the foot, + the radius
const int D_BODY1      = 25;  // the world -> rest matrix (see toRest, and restOf below)
const int D_BODY2      = 26;  // distance scale, bounding radius, ripple height, ripple time
const int D_DROP       = 27;  // 27..29 droplet positions
const int D_DROP_SCR   = 30;  // 30..31 droplets on screen: x0 y0 x1 y1 / x2 y2 radius -
const int D_LUMP       = 32;  // 32..34 lumps, packed ready for the drawing pass
const int D_CORE       = 35;  // the core's position, + its radius
const int D_BUBBLE     = 36;  // 36..40 bubbles: position + radius
const int D_NEAR2      = 41;  // copies of D_NEAR and D_COLOR, for the reason given
const int D_COLOR2     = 42;  // where the drawing pass reads them
const int S_COUNT      = 43;

vec4 state(int i) { return texelFetch(iChannel0, ivec2(i, 0), 0); }

// neowall buffers hold half floats: about 3 significant digits. orbit3d
// explains why that isn't enough for a position that must move smoothly;
// the fix is the same here. A position is kept as a coarse part in whole
// 1/128ths (which half floats hold exactly) plus the small leftover.
vec3 coarse(vec3 x) { return floor(x * 128.0 + 0.5) / 128.0; }

// The same trick for a number that grows a little every frame, counted in
// turns (so it wraps at 1). Straight from orbit3d.
vec2 accumulate(vec2 hilo, float step) {
    float lo    = hilo.y + step;
    float carry = floor(lo * 256.0) / 256.0;
    return vec2(fract(hilo.x + carry), lo - carry);
}
// ...and one that doesn't wrap
vec2 addUp(vec2 hilo, float step) {
    float lo    = hilo.y + step;
    float carry = floor(lo * 256.0) / 256.0;
    return vec2(hilo.x + carry, lo - carry);
}

// a repeatable "random" number 0..1 for any n
float hash(float n) { return fract(sin(n) * 43758.5453123); }

// ----------------------------------------------------------------------------
// The shape
// The body is a round blob in a space of its own, its "rest" space: a
// sphere of radius r around the origin (plus lumps). Squashing, stretching
// and leaning it are all one simple map from rest space into the world:
//   - up the middle it's scaled by `stretch` (under 1 squashed, over 1
//     stretched), and across by 1/sqrt(stretch), so its volume stays the
//     same, like the moon in orbit3d
//   - it leans by sliding each slice sideways in proportion to its height:
//     the bottom stays put and the top moves by `lean` (a shear)
//   - `breath` scales the whole thing a touch
// Because that map is simple, it runs backwards just as easily (toRest), so
// any world point can be asked "where is that on the round blob?".
struct Shape {
    vec3  foot;     // the bottom of the blob, in the world
    float r;        // its radius
    float breath;   // 1 + how far it has breathed in
    float stretch;  // its height as a share of its round height
    vec2  lean;     // how far its top sits off to the side of its foot (x, z)
};

Shape shapeOf(vec3 foot, vec3 head, float r, float breath) {
    Shape sh;
    sh.foot    = foot;
    sh.r       = r;
    sh.breath  = breath;
    sh.stretch = max(head.y - foot.y, 0.05) / (2.0 * r);
    sh.lean    = head.xz - foot.xz;
    return sh;
}
vec3 toWorld(Shape sh, vec3 q) {
    float up = (q.y / sh.r + 1.0) * 0.5;               // 0 at the bottom .. 1 at the top
    float across = sh.breath / sqrt(sh.stretch);
    return sh.foot + vec3(q.x * across + sh.lean.x * up,
                          sh.breath * (sh.r + q.y) * sh.stretch,
                          q.z * across + sh.lean.y * up);
}
vec3 toRest(Shape sh, vec3 w) {
    vec3  d  = w - sh.foot;
    float up = d.y / (2.0 * sh.r * sh.breath * sh.stretch);
    float across = sqrt(sh.stretch) / sh.breath;
    return vec3((d.x - sh.lean.x * up) * across,
                d.y / (sh.breath * sh.stretch) - sh.r,
                (d.z - sh.lean.y * up) * across);
}

// where the three droplets live when they're home: low on the body, spread
// round it (directions in rest space; one of them is round the back)
const vec3 DROP_HOME[3] = vec3[3](
    vec3( 0.80, -0.40,  0.45) / length(vec3( 0.80, -0.40,  0.45)),
    vec3(-0.85, -0.35,  0.30) / length(vec3(-0.85, -0.35,  0.30)),
    vec3( 0.10, -0.30, -0.95) / length(vec3( 0.10, -0.30, -0.95)));

vec3 heatColour(float w) {
    vec3 c0 = toLinear(JELLY_COOL), c1 = toLinear(JELLY_WARM), c2 = toLinear(JELLY_HOT), c3 = toLinear(JELLY_HOTTEST);
    float third = (1.0 - HEAT_HOLD) / 3.0;
    if (w < HEAT_HOLD)               return c0;
    if (w < HEAT_HOLD + third)       return mix(c0, c1, smoothstep(HEAT_HOLD, HEAT_HOLD + third, w));
    if (w < HEAT_HOLD + 2.0 * third) return mix(c1, c2, smoothstep(HEAT_HOLD + third, HEAT_HOLD + 2.0 * third, w));
    return mix(c2, c3, smoothstep(HEAT_HOLD + 2.0 * third, 1.0, w));
}

// Buffer A: the simulation
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // Only the first S_COUNT texels of the bottom row are used, so every
    // other pixel bails out straight away.
    ivec2 px = ivec2(fragCoord);
    if (px.y != 0 || px.x >= S_COUNT) discard;

    // A texel only counts as remembered if its alpha holds the marker 0.75
    // (a new buffer is cleared to 0, and the very first frame can be junk).
    vec4 prevM = state(S_METRICS);
    bool fresh = iFrame == 0 || prevM.a != 0.75;

    // after a pause iTimeDelta can be huge, and one giant step would fling
    // everything about
    float dt = min(iTimeDelta, 0.05);

    // --- inputs, smoothed the way orbit3d does it (hi/lo, lag in seconds)
    vec4  prevL   = state(S_METRICS_LO);
    vec3  live    = vec3(iCpuMax, iRam, iThermal);
    vec3  m       = fresh ? live : mix(prevM.rgb + prevL.rgb, live, 1.0 - exp(-dt / INPUT_LAG));
    // a second, much quicker average of the busiest thread, for startles
    float cpuFast = fresh ? iCpuMax : mix(prevL.a, iCpuMax, 1.0 - exp(-dt / SPIKE_LAG));
    float energy   = smoothstep(BUSY_RANGE.x, BUSY_RANGE.y, m.x);
    float fullness = smoothstep(RAM_RANGE.x, RAM_RANGE.y, m.y);
    float warmth   = smoothstep(HEAT_RANGE.x, HEAT_RANGE.y, m.z);

    float radius   = mix(SIZE.x, SIZE.y, fullness);
    float floorY   = -SINK * radius;     // where the foot rests: a little into the floor
    float roundLen = 2.0 * radius;       // foot to head when it's perfectly round
    // Each spring's stiffness comes from how fast it should wobble: a
    // weight on a spring of stiffness W^2 swings W radians a second
    const float WS = TAU * SQUASH_HZ, WH = TAU * SWAY_HZ, WC = TAU * CORE_HZ, WD = TAU * DROP_HZ;

    // --- last frame's state, or a fresh start: sitting still in the middle
    vec3  foot, vFoot, head, vHead, coreOff, coreVel;
    float groundTime, rippleTime, squatTime, hopPower, cooldown, hops, rippleAmp, squatLength;
    vec2  ready, hopDir, breathP, lumpP, bubbleP, heartP;
    vec3  dropPos[3], dropVel[3];
    float attach[3];   // a droplet's spring strength 0..1 while home, or -(seconds away) while out
    if (fresh) {
        foot  = vec3(0.0, floorY, 0.0);
        // the head starts where its own weight settles it
        head  = foot + vec3(0.0, roundLen - GRAVITY / (WS * WS), 0.0);
        vFoot = vec3(0.0); vHead = vec3(0.0); coreOff = vec3(0.0); coreVel = vec3(0.0);
        groundTime = 1.0; rippleTime = 10.0; squatTime = -1.0; hopPower = 0.0; cooldown = 3.0;
        hops = 0.0; rippleAmp = 0.0; squatLength = SQUAT_TIME;
        ready = vec2(0.5, 0.0); hopDir = vec2(1.0, 0.0);
        breathP = vec2(0.0); lumpP = vec2(0.0); bubbleP = vec2(0.0); heartP = vec2(0.0);
        Shape sh0 = shapeOf(foot, head, radius, 1.0);
        for (int i = 0; i < 3; i++) {
            dropPos[i] = toWorld(sh0, DROP_HOME[i] * DROP_HOME_DEPTH * radius);
            dropVel[i] = vec3(0.0);
            attach[i]  = 1.0;
        }
    } else {
        vec4 x;
        x = state(S_FOOT_HI); foot  = x.xyz;    groundTime  = x.w;
        x = state(S_FOOT_LO); foot += x.xyz;    rippleTime  = x.w;
        x = state(S_FOOT_V);  vFoot = x.xyz;    squatTime   = x.w;
        x = state(S_HEAD_HI); head  = x.xyz;    hopPower    = x.w;
        x = state(S_HEAD_LO); head += x.xyz;    cooldown    = x.w;
        x = state(S_HEAD_V);  vHead = x.xyz;    hops        = x.w;
        x = state(S_CORE);    coreOff = x.xyz;  rippleAmp   = x.w;
        x = state(S_CORE_V);  coreVel = x.xyz;  squatLength = x.w;
        x = state(S_HOP);     ready   = x.xy;   hopDir  = x.zw;
        x = state(S_PHASE);   breathP = x.xy;   lumpP   = x.zw;
        x = state(S_PHASE2);  bubbleP = x.xy;   heartP  = x.zw;
        for (int i = 0; i < 3; i++) {
            vec4 hi = state(S_DROP_HI + i);
            dropPos[i] = hi.xyz + state(S_DROP_LO + i).xyz;
            attach[i]  = hi.w;
            dropVel[i] = state(S_DROP_V + i).xyz;
        }
    }

    // --- the slow cycles, added up a frame at a time (see orbit3d for why
    // not from iTime). The busier it is, the faster each runs.
    breathP = accumulate(breathP, dt * mix(BREATH_HZ.x, BREATH_HZ.y, energy));
    lumpP   = accumulate(lumpP,   dt * mix(LUMP_RATE.x, LUMP_RATE.y, energy));
    bubbleP = accumulate(bubbleP, dt * mix(BUBBLE_RATE.x, BUBBLE_RATE.y, energy));
    heartP  = accumulate(heartP,  dt * mix(HEART_HZ.x, HEART_HZ.y, energy));
    float lp = lumpP.x + lumpP.y;

    // --- deciding to hop
    cooldown = max(cooldown - dt, 0.0);
    bool grounded = foot.y <= floorY + 0.003;
    groundTime = grounded ? min(groundTime + dt, 10.0) : 0.0;
    rippleTime = min(rippleTime + dt, 10.0);

    // Readiness fills up over one gap between hops. Each gap is a bit
    // longer or shorter than average, so its timing never settles into a
    // rhythm: a clock ticks evenly, a creature doesn't.
    float gap = mix(HOP_EVERY.x, HOP_EVERY.y, energy) * (1.0 + HOP_RANDOM * (2.0 * hash(hops * 1.37 + 0.2) - 1.0));
    if (squatTime < 0.0) ready = addUp(ready, dt / gap);

    bool spike   = !fresh && cpuFast - m.x > SPIKE_JUMP && cooldown <= 0.0;
    bool wantHop = ready.x + ready.y >= 1.0 && groundTime > SETTLE_TIME;
    bool flinch  = spike && groundTime > 0.1;
    if (squatTime < 0.0 && (wantHop || flinch)) {
        hops = mod(hops + 1.0, 256.0);
        squatTime = 0.0;
        if (flinch) {
            squatLength = FLINCH_SQUAT; hopPower = FLINCH_STRENGTH; cooldown = FLINCH_COOLDOWN;
        } else {
            squatLength = SQUAT_TIME;
            // mostly set by how busy it is, with a little chance either way
            hopPower = clamp(energy + 0.35 * (hash(hops * 2.71 + 0.5) - 0.35), 0.0, 1.0);
            ready = vec2(0.0);
        }
        // a random way to go, less so front to back, pulled back toward
        // the middle the further it has strayed
        float ang  = TAU * hash(hops * 3.17 + 0.9);
        vec2  dir  = vec2(cos(ang), 0.6 * sin(ang));
        vec2  home = -vec2(foot.x, 2.0 * foot.z) / WANDER;
        hopDir = normalize(dir + 1.5 * home + vec2(1e-4, 0.0));
    }

    // --- the squat, then the push off
    // Squatting just shortens the spring's resting length: the spring
    // itself pulls the head down, with a little overshoot, like a muscle.
    float restLen  = roundLen;
    vec2  leanRest = vec2(0.0);
    bool  takeoff  = false;
    if (squatTime >= 0.0) {
        squatTime += dt;
        float k = smoothstep(0.0, 1.0, min(squatTime / squatLength, 1.0));
        restLen  = roundLen * (1.0 - SQUAT_DEPTH * (0.35 + 0.65 * hopPower) * k);
        leanRest = -hopDir * LEAN_BACK * radius * hopPower * k;
        if (squatTime >= squatLength) { takeoff = true; squatTime = -1.0; }
    }
    if (takeoff) {
        // Launch speed for the height it wants: from h = v^2 / 2g. The head
        // leaves faster than the foot, which stretches it; the spring then
        // pulls the two back together, which is the wobble in the air.
        float hgt   = mix(HOP_HEIGHT.x, HOP_HEIGHT.y, hopPower) * radius;
        float vUp   = sqrt(2.0 * GRAVITY * hgt);
        float vSide = mix(HOP_REACH.x, HOP_REACH.y, hopPower) * radius * GRAVITY / (2.0 * vUp);
        vec3  side  = vec3(hopDir.x, 0.0, hopDir.y) * vSide;
        vFoot = side + vec3(0.0, vUp * (1.0 - TAKEOFF_STRETCH), 0.0);
        vHead = side * 1.2 + vec3(0.0, vUp * (1.0 + TAKEOFF_STRETCH), 0.0);
        restLen = roundLen; leanRest = vec2(0.0);
    }

    // --- the physics: a few small steps a frame, so stiff springs stay calm
    vec3  mid = 0.5 * (foot + head), vMid = 0.5 * (vFoot + vHead);
    // The core and the droplets are worked out in the world (so they lag
    // behind the body as it moves) and stored relative to it at the end.
    vec3  corePos = mid + coreOff, coreV = vMid + coreVel;
    vec3  drift = CORE_DRIFT * radius * vec3(sin(TAU * 11.0 * lp), 0.6 * sin(TAU * (7.0 * lp + 0.3)), cos(TAU * 13.0 * lp));
    float impact = 0.0;   // the hardest landing this frame, as a speed
    const int SUBSTEPS = 4;
    float h = dt / float(SUBSTEPS);
    for (int k = 0; k < SUBSTEPS; k++) {
        // The spring between foot and head: straight up and down it wants
        // the gap to be restLen, sideways it wants the head over the foot.
        // Hooke's law (a pull in proportion to the stretch) plus damping
        // (a drag in proportion to the speed). Semi-implicit Euler, as in
        // orbit3d: speeds first, then positions.
        vec3 d = head - foot, dv = vHead - vFoot;
        vec3 f = vec3(WH * WH * (leanRest.x - d.x) - 2.0 * SWAY_DAMPING   * WH * dv.x,
                      WS * WS * (restLen    - d.y) - 2.0 * SQUASH_DAMPING * WS * dv.y,
                      WH * WH * (leanRest.y - d.z) - 2.0 * SWAY_DAMPING   * WH * dv.z);
        vHead += (f - vec3(0.0, GRAVITY, 0.0)) * h;
        vFoot += (-f - vec3(0.0, GRAVITY, 0.0)) * h;
        foot += vFoot * h; head += vHead * h;
        // the floor: the foot can't go through it, and grips it
        if (foot.y < floorY) {
            if (vFoot.y < 0.0) { impact = max(impact, -vFoot.y); vFoot.y *= -BOUNCE; }
            foot.y = floorY;
        }
        if (foot.y <= floorY + 0.003) vFoot.xz *= exp(-FRICTION * h);
        // however hard the landing, it only flattens so far
        float minLen = SQUASH_LIMIT * roundLen;
        if (head.y - foot.y < minLen) { head.y = foot.y + minLen; vHead.y = max(vHead.y, vFoot.y); }

        // The core: a weight on a spring to the body's middle. It feels
        // gravity too, so its anchor sits a little high to hold it level at
        // rest; mid-hop, weightless, it floats up, and sinks on landing.
        mid = 0.5 * (foot + head); vMid = 0.5 * (vFoot + vHead);
        vec3 coreAnchor = mid + drift + vec3(0.0, GRAVITY / (WC * WC), 0.0);
        coreV += (WC * WC * (coreAnchor - corePos) - 2.0 * CORE_DAMPING * WC * (coreV - vMid) - vec3(0.0, GRAVITY, 0.0)) * h;
        corePos += coreV * h;

        // The droplets: at home, each is on a spring to its spot on the
        // body, so they jiggle; out, they fall, bounce, and crawl back.
        Shape shNow = shapeOf(foot, head, radius, 1.0);
        for (int i = 0; i < 3; i++) {
            vec3 acc = vec3(0.0, -GRAVITY, 0.0);
            if (attach[i] >= 0.0) {
                vec3 homePos = toWorld(shNow, DROP_HOME[i] * DROP_HOME_DEPTH * radius) + vec3(0.0, GRAVITY / (WD * WD), 0.0);
                acc += attach[i] * (WD * WD * (homePos - dropPos[i]) - 2.0 * DROP_DAMPING * WD * (dropVel[i] - vMid));
            }
            dropVel[i] += acc * h;
            dropPos[i] += dropVel[i] * h;
            float dropFloor = DROP_R * radius * 0.55;   // low enough that the floor flattens its bottom
            if (dropPos[i].y < dropFloor) {
                if (dropVel[i].y < 0.0) dropVel[i].y *= -DROP_BOUNCE;
                dropPos[i].y = dropFloor;
            }
            if (attach[i] < 0.0 && dropPos[i].y <= dropFloor + 0.003) {
                if (-attach[i] > CRAWL_DELAY) {
                    // crawl home in little surges, like an inchworm
                    vec2  toBody = foot.xz - dropPos[i].xz;
                    float surge  = 0.25 + 1.5 * max(sin(TAU * (CRAWL_SURGE_HZ * -attach[i] + 0.37 * float(i))), 0.0);
                    vec2  want   = CRAWL_SPEED * surge * toBody / max(length(toBody), 1e-3);
                    dropVel[i].xz = mix(dropVel[i].xz, want, 1.0 - exp(-6.0 * h));
                } else {
                    dropVel[i].xz *= exp(-DROP_FRICTION * h);
                }
            }
        }
    }
    Shape sh = shapeOf(foot, head, radius, 1.0);
    // keep the core inside, however the body has squashed around it
    {
        vec3  q    = toRest(sh, corePos);
        float maxR = radius * (1.0 - CORE_R) * 0.85;
        float len  = length(q);
        if (len > maxR) { corePos = toWorld(sh, q * (maxR / len)); coreV = mix(coreV, vMid, 0.5); }
    }
    coreOff = corePos - mid;
    coreVel = coreV - vMid;

    // --- landings: ripples, and hard ones splash droplets off
    if (impact > 0.8) { rippleAmp = min(rippleAmp + impact * RIPPLE_PER_SPEED, RIPPLE_MAX); rippleTime = 0.0; }
    rippleAmp *= exp(-dt / RIPPLE_FADE);
    if (impact > SPLASH_SPEED) {
        for (int i = 0; i < 3; i++) {
            if (attach[i] > 0.9 && hash(hops * 5.3 + float(i) * 1.7) < SPLASH_CHANCE) {
                vec3  homePos = toWorld(sh, DROP_HOME[i] * DROP_HOME_DEPTH * radius);
                vec2  outward = homePos.xz - mid.xz;
                outward /= max(length(outward), 1e-3);
                float f = min(impact / SPLASH_SPEED, 1.5);
                dropVel[i] = vec3(vMid.x + outward.x * SPLASH_OUT * f, SPLASH_UP * f, vMid.z + outward.y * SPLASH_OUT * f);
                attach[i]  = -0.001;
            }
        }
    }
    for (int i = 0; i < 3; i++) {
        if (attach[i] >= 0.0) {
            // back home: its spring firms up over MERGE_TIME, so it slides
            // into place instead of snapping there
            attach[i] = min(attach[i] + dt / MERGE_TIME, 1.0);
        } else {
            attach[i] = max(attach[i] - dt, -60.0);
            // it's home once it touches the body again
            vec3  q      = toRest(sh, dropPos[i]);
            float toSkin = (length(q) - radius) * min(sh.stretch, 1.0 / sqrt(sh.stretch));
            if (-attach[i] > CRAWL_DELAY && toSkin < DROP_R * radius * 0.6) attach[i] = 0.0;
        }
    }

    // ------------------------------------------------------------------
    // What the drawing pass needs, worked out once here instead of in
    // every one of its 8.3 million pixels.

    // the shape as drawn, breathing
    float breath = 1.0 + BREATH * sin(TAU * (breathP.x + breathP.y));
    Shape shD = shapeOf(foot, head, radius, breath);
    // toRest as a matrix: q = M * (w - foot) - (0, r, 0), with only these
    // four numbers not zero (the fifth, bottom right, repeats the first)
    float sq = sqrt(shD.stretch);
    vec4  mat = vec4(sq / breath,
                     -shD.lean.x * sq / (2.0 * radius * breath * breath * shD.stretch),
                     1.0 / (breath * shD.stretch),
                     -shD.lean.y * sq / (2.0 * radius * breath * breath * shD.stretch));
    // A distance measured in rest space is only a distance in the world
    // after scaling by how much the map shrinks things, and it shrinks some
    // directions more than others. Using its most-shrinking direction
    // keeps every step of the ray march safe, if a little short.
    float distScale = max(min(breath / sq, breath * shD.stretch) - length(shD.lean) / (2.0 * radius), 0.15);

    // Three lumps crawling under the skin: each a direction on the blob
    // and a height, moving on whole-number multiples of the lump phase so
    // they loop seamlessly when it wraps (orbit3d's wisps do the same).
    vec4 lump[3];
    lump[0] = vec4(normalize(vec3(sin(TAU * 7.0 * lp), 0.25 + 0.6 * sin(TAU * (5.0 * lp + 0.3)), cos(TAU * 7.0 * lp))),
                   LUMP_SIZE * (0.6 + 0.4 * sin(TAU * 3.0 * lp)));
    lump[1] = vec4(normalize(vec3(sin(TAU * (-9.0 * lp + 0.4)), 0.15 + 0.6 * sin(TAU * (4.0 * lp + 0.8)), cos(TAU * (-9.0 * lp + 0.4)))),
                   LUMP_SIZE * (0.6 + 0.4 * sin(TAU * (5.0 * lp + 0.5))));
    lump[2] = vec4(normalize(vec3(sin(TAU * (6.0 * lp + 0.7)), 0.35 + 0.5 * sin(TAU * (8.0 * lp + 0.1)), cos(TAU * (-5.0 * lp + 0.2)))),
                   LUMP_SIZE * (0.6 + 0.4 * sin(TAU * (4.0 * lp + 0.2))));
    // the biggest the blob gets anywhere, in rest space
    float boundR = radius * (1.0 + BOTTOM_HEAVY + lump[0].w + lump[1].w + lump[2].w) + 0.02;

    // Bubbles rise through the body in its own rest space, so they squash
    // and lean with it, and slosh a little along with the core.
    vec4  bub[5];
    float bp = bubbleP.x + bubbleP.y;
    vec3  slosh = toRest(sh, mid + coreOff) - toRest(sh, mid);
    for (int j = 0; j < 5; j++) {
        float fj   = float(j);
        float rise = fract(bp * (5.0 + 2.0 * fj) + hash(fj * 7.7 + 1.0));   // 0 at the bottom .. 1 at the top
        float ang  = TAU * hash(fj * 3.3 + 2.0) + 2.0 * rise;              // spirals a little as it rises
        float off  = 0.2 + 0.4 * hash(fj * 5.1 + 3.0);                     // how far from the middle
        vec3  q    = radius * vec3(off * cos(ang), mix(-0.55, 0.55, rise), off * sin(ang)) + 0.6 * slosh;
        q *= min(1.0, 0.72 * radius / max(length(q), 1e-4));               // never out through the skin
        // it grows in at the bottom and fades out at the top, so the wrap
        // back down never shows
        float size = BUBBLE_R * radius * (0.6 + 0.5 * hash(fj * 9.1)) * smoothstep(0.0, 0.12, rise) * smoothstep(1.0, 0.85, rise);
        bub[j] = vec4(toWorld(shD, q), size);
    }

    // A sphere that holds the whole body, for the drawing pass's shortcut,
    // and each droplet's circle on screen, in case one is out beyond it.
    vec3  centre = toWorld(shD, vec3(0.0));
    float reach  = boundR * max(breath / sq, breath * shD.stretch) + 0.5 * length(shD.lean);
    vec3  pc     = project(centre);
    float rs     = screenRadius(reach, pc.z);
    bool  anyOut = false;
    vec3  dropScr[3];
    for (int i = 0; i < 3; i++) {
        vec3 pd = project(dropPos[i]);
        dropScr[i] = vec3(pd.xy, screenRadius((DROP_R + GOO) * radius, pd.z));
        if (length(pd.xy - pc.xy) + dropScr[i].z > rs) anyOut = true;
    }

    // the glow: its colour from the heat, and its power, pulsed by a
    // heartbeat: lub-dub, a big beat and a smaller one just after
    vec3  glowCol = heatColour(warmth);
    float hp   = heartP.x + heartP.y;
    float beat = exp(-pow(min(hp, 1.0 - hp) / 0.05, 2.0)) + 0.55 * exp(-pow((hp - 0.2) / 0.055, 2.0));
    float glowPow = mix(0.85, 1.25, warmth) * (1.0 + HEART_PULSE * beat);

    // each texel keeps its own slice of all that
    vec4 o = vec4(0.0);
    if      (px.x == S_METRICS)    o = vec4(coarse(m), 0.75);
    else if (px.x == S_METRICS_LO) o = vec4(m - coarse(m), cpuFast);
    else if (px.x == S_FOOT_HI)    o = vec4(coarse(foot), groundTime);
    else if (px.x == S_FOOT_LO)    o = vec4(foot - coarse(foot), rippleTime);
    else if (px.x == S_FOOT_V)     o = vec4(vFoot, squatTime);
    else if (px.x == S_HEAD_HI)    o = vec4(coarse(head), hopPower);
    else if (px.x == S_HEAD_LO)    o = vec4(head - coarse(head), cooldown);
    else if (px.x == S_HEAD_V)     o = vec4(vHead, hops);
    else if (px.x == S_CORE)       o = vec4(coreOff, rippleAmp);
    else if (px.x == S_CORE_V)     o = vec4(coreVel, squatLength);
    else if (px.x == S_HOP)        o = vec4(ready, hopDir);
    else if (px.x == S_PHASE)      o = vec4(breathP, lumpP);
    else if (px.x == S_PHASE2)     o = vec4(bubbleP, heartP);
    else if (px.x >= S_DROP_HI && px.x < S_DROP_HI + 3) { int i = px.x - S_DROP_HI; o = vec4(coarse(dropPos[i]), attach[i]); }
    else if (px.x >= S_DROP_LO && px.x < S_DROP_LO + 3) { int i = px.x - S_DROP_LO; o = vec4(dropPos[i] - coarse(dropPos[i]), 0.0); }
    else if (px.x >= S_DROP_V  && px.x < S_DROP_V + 3)  { int i = px.x - S_DROP_V;  o = vec4(dropVel[i], 0.0); }
    else if (px.x == D_NEAR || px.x == D_NEAR2)   o = vec4(centre, anyOut ? -reach : reach);
    else if (px.x == D_COLOR || px.x == D_COLOR2) o = vec4(glowCol, glowPow);
    else if (px.x == D_BODY0)      o = vec4(foot, radius);
    else if (px.x == D_BODY1)      o = mat;
    else if (px.x == D_BODY2)      o = vec4(distScale, boundR, rippleAmp, rippleTime);
    else if (px.x >= D_DROP && px.x < D_DROP + 3) o = vec4(dropPos[px.x - D_DROP], 0.0);
    else if (px.x == D_DROP_SCR)     o = vec4(dropScr[0].xy, dropScr[1].xy);
    else if (px.x == D_DROP_SCR + 1) o = vec4(dropScr[2].xy, dropScr[0].z, 0.0);
    else if (px.x >= D_LUMP && px.x < D_LUMP + 3) {
        // packed so the drawing pass does less per step: a lump's height is
        // amp * exp(sharp * (cos - 1)), which is exp(dot(n, sharp * dir) + log(amp) - sharp)
        vec4 l = lump[px.x - D_LUMP];
        o = vec4(l.xyz * LUMP_SHARP, log(l.w) - LUMP_SHARP);
    }
    else if (px.x == D_CORE)       o = vec4(corePos, CORE_R * radius);
    else if (px.x >= D_BUBBLE && px.x < D_BUBBLE + 5) o = bub[px.x - D_BUBBLE];
    fragColor = o;
}

// ===== drawing helpers =====
// neowall gives code placed between the two mainImage functions to the
// second pass only.

// The body as the drawing pass sees it: where its foot is, its radius, the
// world -> rest matrix, and the two numbers the ray march needs.
struct Body { vec3 foot; float r; vec4 mat; float distScale, boundR; };

Body loadBody() {
    vec4 b0 = state(D_BODY0), b2 = state(D_BODY2);
    return Body(b0.xyz, b0.w, state(D_BODY1), b2.x, b2.y);
}
// toRest, with the matrix: for a point...
vec3 restOf(Body B, vec3 w) {
    vec3 d = w - B.foot;
    return vec3(B.mat.x * d.x + B.mat.y * d.y, B.mat.z * d.y - B.r, B.mat.w * d.y + B.mat.x * d.z);
}
// ...for a direction (no offset: directions don't move, they only turn)...
vec3 restDir(Body B, vec3 v) {
    return vec3(B.mat.x * v.x + B.mat.y * v.y, B.mat.z * v.y, B.mat.w * v.y + B.mat.x * v.z);
}
// ...and the other way round for a slope: how fast something measured in
// rest space changes as you move in the world (the matrix turned over,
// which is what the chain rule says)
vec3 worldGrad(Body B, vec3 g) {
    return vec3(B.mat.x * g.x, B.mat.y * g.x + B.mat.z * g.y + B.mat.w * g.z, B.mat.x * g.z);
}

// ray vs sphere: (near, far) hit distances, or -1. The Q version takes a
// direction that isn't unit length, like a ray carried into rest space; its
// answers are still distances along the world ray.
vec2 sphereHits(vec3 ro, vec3 rd, float r) {
    float b = dot(ro, rd);
    float h = b * b - dot(ro, ro) + r * r;
    if (h < 0.0) return vec2(-1.0);
    h = sqrt(h);
    return vec2(-b - h, -b + h);
}
vec2 sphereHitsQ(vec3 o, vec3 d, float r) {
    float a = dot(d, d), b = dot(o, d), c = dot(o, o) - r * r;
    float h = b * b - a * c;
    if (h < 0.0) return vec2(-1.0);
    h = sqrt(h);
    return vec2(-b - h, -b + h) / a;
}

// Distance to the jelly (raymarch3D.glsl's scene(), grown up):
//   - the body: a sphere in rest space whose radius depends on direction,
//     fatter toward the bottom and with the lumps added on. Measured in
//     rest space, then scaled to a safe world distance
//   - melted into one droplet with a "smooth minimum". Plain min() keeps
//     the nearer of two shapes, so two blobs just touch, with a crease.
//     smin() bends the two distances into each other when they're within
//     GOO of each other: a bridge grows between blobs as they near, and
//     stretches into a neck, then snaps, as they part. That's the ooze.
//   - cut flat by the floor, where it presses on it
// drop is the droplet as this ray meets it: (its distance from the camera
// squared, how far along the ray it lies, its radius), which makes its
// distance at any t a single square root.
float jellyDist(Body B, vec4 l0, vec4 l1, vec4 l2, vec3 drop, vec3 q, float t, float wy) {
    float len = length(q);
    vec3  n   = q / max(len, 1e-4);
    float r   = 1.0 + BOTTOM_HEAVY * (0.5 - 0.5 * n.y)
              + exp(dot(n, l0.xyz) + l0.w) + exp(dot(n, l1.xyz) + l1.w) + exp(dot(n, l2.xyz) + l2.w);
    float dBody = (len - B.r * r) * B.distScale;
    float dDrop = sqrt(max(drop.x + t * (t - 2.0 * drop.y), 0.0)) - drop.z;
    float k  = GOO * B.r;
    float hh = max(k - abs(dBody - dDrop), 0.0) / k;
    float d  = min(dBody, dDrop) - hh * hh * k * 0.25;
    return max(d, -wy);
}

// The same surface's normal, from calculus rather than the extra distance
// samples raymarch3D.glsl's normalAt takes (orbit3d does the same for its
// bulge). The body's slope comes from its rest-space shape, then turned
// into the world with worldGrad. The droplet's is straight out from its
// middle. smin() blends the two by how much each contributed.
vec3 jellyNormal(Body B, vec4 l0, vec4 l1, vec4 l2, vec4 drop, vec3 P, vec3 q) {
    float len = max(length(q), 1e-4);
    vec3  n   = q / len;
    float e0  = exp(dot(n, l0.xyz) + l0.w);
    float e1  = exp(dot(n, l1.xyz) + l1.w);
    float e2  = exp(dot(n, l2.xyz) + l2.w);
    float r   = 1.0 + BOTTOM_HEAVY * (0.5 - 0.5 * n.y) + e0 + e1 + e2;
    // how the radius changes with direction, then that turned into a slope
    vec3  g   = vec3(0.0, -0.5 * BOTTOM_HEAVY, 0.0) + e0 * l0.xyz + e1 * l1.xyz + e2 * l2.xyz;
    vec3  nBody = normalize(worldGrad(B, n - (B.r / len) * (g - n * dot(n, g))));
    float dBody = (len - B.r * r) * B.distScale;
    vec3  toD   = P - drop.xyz;
    float dDrop = length(toD) - drop.w;
    float k  = GOO * B.r;
    float hh = max(k - abs(dBody - dDrop), 0.0) / k;
    float wb = dBody < dDrop ? 1.0 - 0.5 * hh : 0.5 * hh;
    float d  = min(dBody, dDrop) - hh * hh * k * 0.25;
    return -P.y > d ? vec3(0.0, -1.0, 0.0) : normalize(wb * nBody + (1.0 - wb) * toD / max(length(toD), 1e-4));
}

// The jelly's light landing on the floor at X. From a glowing ball, a point
// on the floor gets light in proportion to the ball's size over the square
// of its distance, times how squarely it faces the ball: for centre c,
// that's c.y / distance^3. Then it's reined in: faded out by POOL_EXTENT
// (so everything further away can skip this), and levelled off right under
// the jelly, where the distance heads toward 0.
vec3 poolLight(vec3 X, vec3 c, vec4 cl) {
    vec3  d   = c - X;
    float d2  = dot(d, d) + 0.02;
    float rho = length(d.xz);
    float e   = POOL * cl.a * max(c.y, 0.05) / (d2 * sqrt(d2));
    e *= exp(-rho * rho / (POOL_REACH * POOL_REACH)) * (1.0 - smoothstep(0.6 * POOL_EXTENT, POOL_EXTENT, rho));
    e = e / (1.0 + e / POOL_CLIP);
    return cl.rgb * e;
}

// How much of a point light at c a ray (from o, along d, for length L)
// picks up on its way through a glowing haze. Every bit of the ray adds
// light fading with the square of its distance to c; added up along the
// ray, that has an exact answer, with atan in it. h is how close the ray
// passes c (never under hmin, so it can't blow up).
float inScatter(vec3 o, vec3 d, float L, vec3 c, float hmin) {
    vec3  oc = c - o;
    float t0 = dot(oc, d);
    float h  = sqrt(max(dot(oc, oc) - t0 * t0, hmin * hmin));
    return (atan((L - t0) / h) - atan(-t0 / h)) / h;
}

// Highlights roll off smoothly instead of clipping (as in orbit3d).
vec3 tonemap(vec3 c) {
    vec3 over = max(c - TONE_KNEE, 0.0);
    return min(c, vec3(TONE_KNEE)) + over / (1.0 + over / (1.0 - TONE_KNEE));
}

// What the jelly's wet skin reflects, looking along r from P: the dark
// room, a little sky, the two softboxes, and the lit floor below.
vec3 envLight(vec3 r, vec3 P, vec3 centre, vec4 cl) {
    vec3  e  = toLinear(BACKDROP) * 0.6 + toLinear(SKY_TINT) * 0.8 * max(r.y, 0.0);
    float kd = dot(r, KEY_DIR);
    e += toLinear(LIGHT_TINT) * KEY_BRIGHT * (smoothstep(KEY_EDGE.x, KEY_EDGE.y, kd) + 0.08 * pow(max(kd, 0.0), 12.0));
    e += mix(toLinear(LIGHT_TINT), cl.rgb, 0.5) * RIM_BRIGHT * smoothstep(RIM_EDGE.x, RIM_EDGE.y, dot(r, RIM_DIR));
    if (r.y < -0.01 && P.y > 0.01) e += poolLight(P + r * (-P.y / r.y), centre, cl) * FLOOR_ALBEDO * 0.8;
    return e;
}

// The light that comes out of the jelly along the refracted ray D, which
// runs through L of it from P:
//   - the jelly's own glow, building up with thickness, and deepened in
//     colour where it's thick: light from deep inside has further to come,
//     and the jelly soaks up the colours it isn't (Beer's law)
//   - the core's light, gathered along the way (inScatter), and the core
//     itself as a soft ball
//   - bubbles: darker where the ray goes through them, bright at their rims
vec3 innerLight(vec3 P, vec3 rd, vec3 D, float L, vec4 cl, float mott) {
    vec3 glowCol = cl.rgb;
    vec4 core = state(D_CORE);
    vec3 deep = exp(-0.5 * L * ABSORB * (1.0 - glowCol));
    // The core is looked up along a ray only partly bent (Dc): through a
    // squashed body the full bend works like a strong lens and smears it
    // into a streak.
    vec3 Dc = normalize(mix(rd, D, CORE_BEND));
    vec3 c  = glowCol * deep * cl.a * (BODY_GLOW * mott * (1.0 - exp(-L * SCATTER))
                                      + CORE_LIGHT * inScatter(P, Dc, L, core.xyz, core.w * 0.5));
    vec3  toCore  = core.xyz - P;
    float along   = clamp(dot(toCore, Dc), 0.0, L);
    float coreHit = smoothstep(core.w, core.w * 0.25, length(toCore - Dc * along));
    c += mix(glowCol, toLinear(LIGHT_TINT), 0.3) * cl.a * CORE_SURFACE * coreHit * coreHit;
    for (int j = 0; j < 5; j++) {
        vec4 bb = state(D_BUBBLE + j);
        vec2 bh = sphereHits(P - bb.xyz, D, bb.w);
        if (bb.w > 0.002 && bh.y > 0.0 && bh.x < L) {
            vec3  bn     = normalize(P + D * max(bh.x, 0.0) - bb.xyz);
            float facing = clamp(dot(bn, -D), 0.0, 1.0);
            float rim    = (1.0 - facing) * (1.0 - facing);
            c *= 0.55 + 0.45 * rim;
            c += glowCol * BUBBLE_GLINT * rim * (0.6 + 0.4 * dot(bn, KEY_DIR))
               + toLinear(LIGHT_TINT) * 2.0 * smoothstep(0.96, 0.995, dot(reflect(D, bn), KEY_DIR));
        }
    }
    return c;
}

// ----------------------------------------------------------------------------
// What it costs, and why the drawing pass below is shaped the way it is
//
// Two things turned out to matter on this laptop's graphics chip, both
// measured with the offscreen harness (at 4K, against orbit3d):
//
//   - Reading the simulation's texels isn't free. A texelFetch in every
//     pixel costs about 0.3 ms a frame, whatever it reads. So most of the
//     screen reads one texel (D_NEAR), learns it's nowhere near the jelly
//     or its pool of light, and stops.
//   - The chip runs each pixel program 8 or 16 pixels at a time, and 16 is
//     twice as fast. But 16 at once only fits if the program never needs
//     more than about 60 numbers alive at the same moment. Past that, the
//     driver quietly falls back to 8, and everything, the empty background
//     included, costs double. (Mesa says so if asked: INTEL_DEBUG=perf.)
//     So the passes below each keep their numbers to themselves: the
//     jelly is drawn first, and the floor, after it, works its ray out
//     again from scratch and reads its own copies of the colour and the
//     centre (D_NEAR2, D_COLOR2). Were it to reuse the jelly's, the
//     compiler would keep them alive right through the jelly's ray march,
//     and that is just enough to tip it over 60.
// ----------------------------------------------------------------------------

// Image: the scene, drawn from the simulation's texels
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2  p   = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    vec3  rd  = normalize(p.x * CAM_RT + p.y * CAM_UP + FOCAL * CAM_FW);
    float pix = 1.0 / (iResolution.y * FOCAL);   // one pixel's width at distance 1

    // The one texel every pixel reads: where the jelly is. Does this
    // pixel's ray pass within the sphere that holds it? (How close a ray
    // passes a point: the distance to it, less the part along the ray.)
    vec4  nr  = state(D_NEAR);
    vec3  toJ = nr.xyz - CAM_POS;
    float aJ  = dot(toJ, rd);
    bool  nearJelly = dot(toJ, toJ) - aJ * aJ < nr.w * nr.w;
    if (!nearJelly && nr.w < 0.0) {
        // a droplet is out on its own: check its circle on screen too
        vec4  d0 = state(D_DROP_SCR), d1 = state(D_DROP_SCR + 1);
        vec2  a = p - d0.xy, b = p - d0.zw, c = p - d1.xy;
        float rr = d1.z * d1.z;
        nearJelly = dot(a, a) < rr || dot(b, b) < rr || dot(c, c) < rr;
    }
    // does it land on the floor near enough to the jelly to be lit by it?
    float tF  = rd.y < 0.0 ? -CAM_POS.y / rd.y : 1e9;
    vec2  toC = CAM_POS.xz + rd.xz * tF - nr.xz;
    bool  inPool = tF < 1e8 && dot(toC, toC) < POOL_EXTENT * POOL_EXTENT;

    // ---- the jelly: its colour, and how much of this pixel it covers
    vec4 jel = vec4(0.0);
    if (nearJelly) {
        Body B = loadBody();
        // The ray carried into rest space: the map is simple enough that a
        // straight line stays a straight line, so this is a start and a
        // direction, and a point on it at distance t is oq + dq * t.
        vec3 oq = restOf(B, CAM_POS), dq = restDir(B, rd);
        // only march where the ray is inside the blob's bounding sphere...
        vec2  tb = sphereHitsQ(oq, dq, B.boundR);
        float tS = tb.y > 0.0 ? tb.x : 1e9, tE = tb.y > 0.0 ? tb.y : -1e9;
        // ...or a droplet's. Of the droplets, this ray only melts the first
        // it meets into the body: one instead of three keeps the march
        // cheap, and a ray is almost never close to two.
        int   di = -1;
        float dNear = 1e9;
        vec3  drop = vec3(1e6, 0.0, 0.0);   // a droplet nowhere near, until one is found
        for (int i = 0; i < 3; i++) {
            vec3  toD   = state(D_DROP + i).xyz - CAM_POS;
            float along = dot(toD, rd), dd2 = dot(toD, toD);
            float reach = (DROP_R + GOO) * B.r;
            float hh    = along * along - dd2 + reach * reach;
            if (hh > 0.0) {
                hh = sqrt(hh);
                tS = min(tS, along - hh); tE = max(tE, along + hh);
                if (along - hh < dNear) { dNear = along - hh; di = i; drop = vec3(dd2, along, DROP_R * B.r); }
            }
        }
        tS = max(tS, 0.0);
        tE = min(tE, tF);   // nothing to find under the floor
        if (tE > tS) {
            vec4 l0 = state(D_LUMP), l1 = state(D_LUMP + 1), l2 = state(D_LUMP + 2);
            // Sphere-trace, as in orbit3d: a near miss still covers however
            // many pixels it missed by (dMin at tMin), for a smooth edge.
            float t = tS, dMin = 1e9, tMin = tS;
            bool  hit = false;
            for (int i = 0; i < MARCH_STEPS; i++) {
                float d = jellyDist(B, l0, l1, l2, drop, oq + dq * t, t, CAM_POS.y + rd.y * t);
                if (d < dMin) { dMin = d; tMin = t; }
                if (d < 0.5 * pix * t) { hit = true; break; }
                t += MARCH_STEP * d;
                if (t > tE) break;
            }
            jel.a = hit ? 1.0 : clamp(1.0 - dMin / (pix * tMin), 0.0, 1.0);
            float tJ = hit ? t : tMin;
            if (jel.a > 0.0) {
                vec3 P  = CAM_POS + rd * tJ;
                vec3 qP = oq + dq * tJ;
                vec4 dropW = vec4(0.0, -100.0, 0.0, 0.0);
                if (di >= 0) dropW = vec4(state(D_DROP + di).xyz, DROP_R * B.r);
                vec3 N = jellyNormal(B, l0, l1, l2, dropW, P, qP);
                vec4 b2 = state(D_BODY2);
                if (b2.z > 0.002) {
                    // ripples: rings running up from its bottom after a
                    // landing, tilting the normal back and forth. They're
                    // too small to change its outline, so they only exist
                    // in the light.
                    vec3  nR    = normalize(qP);
                    float lat   = acos(clamp(-nR.y, -1.0, 1.0));   // 0 at the bottom .. pi at the top
                    float slope = b2.z * RIPPLE_WAVES * cos(RIPPLE_WAVES * lat - RIPPLE_SPEED * b2.w);
                    vec3  upSkin = normalize(vec3(0.0, 1.0, 0.0) + nR.y * nR + vec3(1e-4));
                    N = normalize(N - normalize(worldGrad(B, upSkin)) * slope);
                }
                // glancing angles reflect more (Schlick's approximation of
                // Fresnel, as in orbit3d); what isn't reflected goes in
                float F = 0.03 + 0.97 * pow(1.0 - clamp(dot(N, -rd), 0.0, 1.0), 5.0);

                // Into the body: the ray bends as it goes in (refract), and
                // how much jelly it passes through is roughly its path
                // through the plain round body (or the droplet, if longer).
                vec3  D  = refract(rd, N, 1.0 / IOR);
                vec3  dP = restDir(B, D);
                vec2  ch = sphereHitsQ(qP, dP, B.r * (1.0 + 0.5 * BOTTOM_HEAVY));
                float L  = max(max(ch.y, sphereHits(P - dropW.xyz, D, dropW.w).y), 0.05 * B.r);
                vec3  nOut = normalize(worldGrad(B, qP + dP * ch.y));   // the skin where it comes out

                vec4 cl     = state(D_COLOR2);
                vec3 centre = state(D_NEAR2).xyz;
                // What's behind, bent twice (in and out) and filtered by the
                // jelly on the way. Out the back is the dark, or the floor
                // under it, lit by its own pool.
                vec3 Xe   = P + D * L;
                vec3 Dout = refract(D, -nOut, IOR);
                if (dot(Dout, Dout) < 0.5) Dout = D;   // refract gives 0 when the light can't get out
                vec3 behind = toLinear(BACKDROP);
                if (Dout.y < -0.01) behind += poolLight(Xe + Dout * (max(Xe.y, 0.0) / -Dout.y), centre, cl) * FLOOR_ALBEDO;
                vec3 cJ = (1.0 - F) * behind * exp(-L * ABSORB * (1.15 - cl.rgb));
                // Its skin is mottled: three slow waves through its rest
                // space, so the blotches stretch and squash with it.
                vec3  qm   = qP * (MOTTLE_SCALE / B.r);
                float mott = 1.0 + MOTTLE * (sin(qm.x + 1.7 * qm.y) * sin(qm.z - 0.8 * qm.y + 1.3) + 0.5 * sin(2.1 * qm.x - 1.4 * qm.z + 0.4));
                cJ += (1.0 - F) * innerLight(P, rd, D, L, cl, mott);
                cJ += F * envLight(reflect(rd, N), P, centre, cl);
                jel.rgb = cJ;
            }
        }
    }

    // ---- the floor: the jelly's pool of light, and its reflection
    // (see "What it costs" for why this works its own ray out again)
    vec3 col = toLinear(BACKDROP);
    if (inPool && jel.a < 1.0) {
        vec2  p   = fragCoord / iResolution.y - vec2(0.5 * iResolution.x / iResolution.y, 0.5);
        vec3  rd  = normalize(FOCAL * CAM_FW + p.y * CAM_UP + p.x * CAM_RT);
        float tF  = CAM_POS.y / -rd.y;
        vec3  X   = CAM_POS + rd * tF;
        vec4  cl  = state(D_COLOR);
        vec4  nr2 = state(D_NEAR2);
        vec3  centre = nr2.xyz;
        col += poolLight(X, centre, cl) * FLOOR_ALBEDO;
        // The reflection: the floor is a mirror, so this pixel sees the
        // jelly's mirror image by carrying on from X with its ray flipped
        // upward. It's only the plain round body, and faint, so it can
        // skip the ray march: one exact ray-vs-blob test in rest space,
        // then the glow worked out the way innerLight does it. It fades as
        // it rises off the floor, and toward the pool's edge.
        vec3  toM = centre * vec3(1.0, -1.0, 1.0) - CAM_POS;
        float aM  = dot(toM, rd);
        if (dot(toM, toM) - aM * aM < nr2.w * nr2.w) {
            Body B = loadBody();
            vec3 rUp = vec3(rd.x, -rd.y, rd.z);
            vec2 th  = sphereHitsQ(restOf(B, X), restDir(B, rUp), B.r * (1.0 + 0.5 * BOTTOM_HEAVY));
            if (th.y > 0.0) {
                vec3  hitR = X + rUp * max(th.x, 0.0);
                float Lr   = th.y - max(th.x, 0.0);
                vec4  core = state(D_CORE);
                float g    = BODY_GLOW * (1.0 - exp(-Lr * SCATTER)) + CORE_LIGHT * inScatter(hitR, rUp, Lr, core.xyz, core.w * 0.5);
                float rho  = length(X.xz - centre.xz);
                col += cl.rgb * cl.a * g * REFLECT * exp(-hitR.y * REFLECT_FADE)
                     * (1.0 - smoothstep(0.35 * POOL_EXTENT, 0.8 * POOL_EXTENT, rho));
            }
        }
    }
    col = mix(col, jel.rgb, jel.a);

    // ---- out, as in orbit3d: roll off the highlights, re-encode the
    // colour, and dither so the dark floor doesn't band
    if (max(col.r, max(col.g, col.b)) > TONE_KNEE) col = tonemap(col);
    col = sqrt(col);
    col += (fract(52.9829189 * fract(dot(fragCoord, vec2(0.06711056, 0.00583715)))) - 0.5) / 255.0;
    fragColor = vec4(col, 1.0);
}
