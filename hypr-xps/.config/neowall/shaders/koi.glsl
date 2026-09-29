// koi.glsl: a koi pond seen from straight above. Seven koi cruise about under
// a few lily pads, all over the screen, and the water answers everything that
// touches it.
//
// It's made to look alive with nothing going on: most of the time this laptop
// is only showing an ssh session, so the koi keep themselves busy, and the
// things it reads only change their mood:
//
//   time of day   the light: the sun by day (low and golden at either end of
//                 it), the moon by night, and a stone lantern just off the
//                 top-left corner, lit from dusk to dawn      (iSun, iTimeOfDay)
//   network       rain: a drip every few seconds when it's quiet, a shower
//                 while something is coming or going over the wire, like an
//                 ssh session printing or a download          (iNetDown, iNetUp)
//   cpu           how lively the koi are: they beat their tails harder and
//                 glide less                                    (iCpuMax)
//   heat          warm water holds less air, so the koi come up to gulp at
//                 the surface more often                        (iThermal)
//   the pointer   move it over the pond and nearby koi come to see, and it
//                 trails rings like a fingertip             (iMouse, iMouseEnergy)
//   coming back   show the pond again (switch to an empty workspace) and the
//                 koi notice you: they rise and gulp at the surface for a few
//                 seconds. That needs neowall to pause the wallpaper while
//                 it's covered; see "Coming back" in stateTexel  (iTimeDelta)
//
// What makes it feel alive, mostly borrowed from how real koi move:
//   - beat and glide: a koi gives a few tail beats, then coasts, slowing, and
//     beats again, so its speed swells and eases instead of holding steady
//   - the body follows the head: it's a chain of joints, each pulled along
//     after the one in front, so a turn runs back down it like a real spine.
//     A swimming wave rides on top, swinging the tail far more than the head
//   - the fins move with it: the pectorals fold in when it swims hard, spread
//     to brake and turn, and scull gently while it hovers
//   - each has a mind of its own: it picks somewhere to go, mostly ahead of
//     it and wherever the others aren't; sometimes it trails another koi for
//     a while, sometimes it comes up to gulp at the surface. A drop landing
//     right beside one near the surface makes it start and dive
//   - the water is a real wave simulation: rain, gulps, the wakes of koi
//     swimming just under the surface, the pointer and gusts of wind all start
//     ripples, which spread, cross and fade as they would
//   - light does the rest: the ripples bend your view of everything under
//     them, focus light into caustics on the floor, and catch glints of the
//     sun, the moon or the lantern; koi and pads throw shadows on the floor
//
// Two passes, wired up by koi.neowall, the same shape as orbit3d and jelly:
//   first    the simulation, plus everything that can be worked out once
//            rather than per pixel: the koi, the pads, the ripples, and a
//            coarse picture of the water's light
//   second   draws the screen from that
//
// Unlike orbit3d and jelly, almost every pixel here shows something: there's
// no empty background to skip. "What it costs", near the bottom, says how it
// still comes out about as cheap as jelly.
//
// Every number worth tweaking is in SETTINGS, just below, grouped by what it
// does. Change one, save, then `neowall reload` to see it. Distances are in
// pond units: the screen is 1 tall, and about 1.78 wide.

// ============================================================================
// SETTINGS
// ============================================================================

// --- colours
// The Kanagawa Wave colours this uses (copied from colors.glsl, which has the
// full palette: neowall has no #include). Kanagawa even has a carp yellow.
const vec3 sumiInk0     = vec3(0.086, 0.086, 0.114);  // #16161D
const vec3 winterBlue   = vec3(0.145, 0.145, 0.208);  // #252535
const vec3 winterGreen  = vec3(0.169, 0.200, 0.157);  // #2B3328
const vec3 waveBlue2    = vec3(0.176, 0.310, 0.404);  // #2D4F67
const vec3 dragonBlue   = vec3(0.396, 0.522, 0.580);  // #658594
const vec3 springViolet2= vec3(0.612, 0.671, 0.792);  // #9CABCA
const vec3 fujiWhite    = vec3(0.863, 0.843, 0.729);  // #DCD7BA
const vec3 autumnRed    = vec3(0.765, 0.251, 0.263);  // #C34043
const vec3 surimiOrange = vec3(1.000, 0.627, 0.400);  // #FFA066
const vec3 carpYellow   = vec3(0.902, 0.765, 0.518);  // #E6C384
const vec3 autumnYellow = vec3(0.863, 0.647, 0.380);  // #DCA561
const vec3 boatYellow1  = vec3(0.576, 0.502, 0.337);  // #938056
const vec3 boatYellow2  = vec3(0.753, 0.639, 0.431);  // #C0A36E
const vec3 autumnGreen  = vec3(0.463, 0.580, 0.416);  // #76946A

// --- the inputs
// smoothstep(lo, hi, x) turns lo..hi into 0..1, flat at both ends.
//   iCpuMax    the busiest CPU thread; idle, it wanders 0.1..0.3
//   iNetDown   neowall's log scale: 0.5 is ~5 KB/s, 0.6 ~30 KB/s, 0.8 ~1 MB/s.
//   iNetUp     With an ssh session open and nothing happening this laptop
//              idles around 0.44..0.52 (measured Sep 2026); a burst of
//              terminal output reaches 0.6..0.7
//   iThermal   (hottest CPU sensor - 30 C) / 65 C, as in orbit3d
const vec2 BUSY_RANGE = vec2(0.30, 0.95);     // iCpuMax
const vec2 NET_RANGE  = vec2(0.53, 0.80);     // the busier of iNetDown and iNetUp
const vec2 HEAT_RANGE = vec2(0.68, 0.97);     // iThermal: 74 C .. 93 C
const vec3 INPUT_LAG  = vec3(2.0, 1.0, 4.0);  // seconds each takes to catch up: cpu, network, heat

// --- the pond
const float FLOOR_DEPTH = 0.30;   // how deep the water is
const float REFRACT     = 0.03;   // how far the ripples shift what's under them (bigger = wobblier)

// --- ripples
// The surface is a grid of heights, and each frame every point is pulled
// toward the average of its neighbours: the wave equation, which is all it
// takes for a poke to spread as rings, and for rings to cross.
const int   GRID_ROWS   = 360;    // grid points top to bottom (more = finer ripples, spreading slower, and more work)
const float WAVE_C2     = 0.55;   // how fast ripples spread: grid points a frame, squared (under 0.75, or it blows up)
const float WAVE_DAMP   = 0.018;  // how fast they die away (share lost a frame)
const float WAVE_VISC   = 0.05;   // how much faster small ripples die than big ones
const float SLOPE       = 22.0;   // how steep the ripples look to the light
const float CAUSTICS    = 5.0;    // how strongly ripples focus light onto the floor
const int   WATER_ROWS  = 432;    // the water's light is worked out on a grid this tall

// --- rain
const float DRIP_EVERY  = 3.0;    // seconds between drips when the network is quiet
const float RAIN_MAX    = 8.0;    // drops a second, flat out
const float DROP_DEPTH  = 1.2;    // how hard a drop hits
const float DROP_RADIUS = 1.1;    // how wide (in grid points)

// --- wind: now and then a gust drifts across, roughening a patch of the water
const vec2  GUST_EVERY  = vec2(18.0, 40.0);   // seconds between gusts: shortest .. longest
const float GUST        = 0.000;              // how hard it ruffles the water
const vec2  GUST_SIZE   = vec2(0.18, 0.32);   // its radius: smallest .. largest
const float GUST_SPEED  = 0.12;               // how fast it drifts across

// --- the lantern: a stone lantern just off the top-left corner, lit at night
const vec3  LANTERN_POS   = vec3(-1.02, 0.60, 0.28);  // x, y in pond units (on a 16:9 screen), and how high it stands
const float LANTERN       = 1.6;                      // how bright
const float LANTERN_REACH = 0.9;                      // how far its light spreads (a fifth as bright this far away)

// --- the koi
// Seven, each a different variety, so they read apart at a glance:
//   0 kohaku   white, with big red patches
//   1 tancho   white, with one red circle on its head, like the flag
//   2 showa    black, with red and white
//   3 ogon     solid metallic gold
//   4 asagi    blue-grey back netted with scales, orange flanks and cheeks
//   5 sanke    kohaku, with small black spots
//   6 chagoi   tea brown, the friendly one
const int   N_KOI       = 7;
const float KOI_LEN[7]  = float[7](0.26, 0.22, 0.24, 0.25, 0.21, 0.18, 0.23);   // nose to tail root
const int   KOI_KIND[7] = int[7](0, 1, 2, 3, 4, 5, 6);
// how deep each likes to swim: shallowest .. deepest (the surface is 0)
const vec2  KOI_DEPTH[7] = vec2[7](vec2(0.03, 0.16), vec2(0.02, 0.12), vec2(0.06, 0.20), vec2(0.03, 0.14),
                                   vec2(0.05, 0.20), vec2(0.02, 0.12), vec2(0.03, 0.15));
// their colours: the body, and the two kinds of patch on it (linear, so
// squared: see toLinear)
const vec3  KOI_BASE[7] = vec3[7](fujiWhite * fujiWhite * 1.1, fujiWhite * fujiWhite * 1.1, sumiInk0 * sumiInk0 * 0.7,
                                  carpYellow * carpYellow * 1.15, springViolet2 * dragonBlue,
                                  fujiWhite * fujiWhite * 1.1, boatYellow1 * boatYellow2 * 0.8);
const vec3  KOI_HI[7]   = vec3[7](autumnRed * surimiOrange * 1.2, autumnRed * surimiOrange * 1.2, autumnRed * surimiOrange * 1.2,
                                  autumnYellow * autumnYellow, surimiOrange * autumnRed * 1.1,
                                  autumnRed * surimiOrange * 1.2, boatYellow2 * boatYellow2 * 0.8);
const vec3  KOI_SUMI[7] = vec3[7](sumiInk0 * sumiInk0, sumiInk0 * sumiInk0, fujiWhite * fujiWhite * 1.05,
                                  sumiInk0 * sumiInk0, sumiInk0 * sumiInk0, sumiInk0 * sumiInk0 * 0.7, sumiInk0 * sumiInk0);
const float WIDTH       = 0.115;  // half its width at the shoulders, as a share of its length
// swimming
const vec2  CRUISE      = vec2(0.07, 0.15);   // the speed a burst of tail beats heads for: calm .. lively
const float GLIDE_DRAG  = 0.45;   // how fast it slows while gliding (share lost a second)
const float MIN_SPEED   = 0.010;  // it never quite stops
const float BEAT_HZ     = 2.0;    // tail beats a second, flat out
const float SWING       = 0.085;  // how far the tail swings, as a share of its length
const float WAVE_LEN    = 0.9;    // the swimming wave's length, in body lengths
// turning: a damped spring toward the way it wants to go, so a turn eases
// in and overshoots a touch
const float TURN_K      = 5.0;    // stiffness
const float TURN_D      = 3.5;    // damping
const float TURN_MAX    = 1.3;    // fastest turn, radians a second
const float MAX_BEND    = 0.34;   // the most one of its eight joints can bend, in radians
// the water
const float WAKE        = 1.5;    // how much a koi just under the surface pushes it about
const float WAKE_DEPTH  = 0.05;   // how near the surface it must be to leave a wake
// what it notices
const float STARTLE_RANGE = 0.09; // how close a drop must land to startle a koi near the surface
const float CURIOUS_RANGE = 0.4;  // how far away a koi notices the pointer moving

// --- lily pads
const int   N_PADS      = 5;
const float PAD_R[5]    = float[5](0.075, 0.058, 0.085, 0.052, 0.066);   // their radii

// ============================================================================
// Everything below is how it works: tuning shouldn't need anything past here.
// ============================================================================

const float TAU = 6.28318531;

// Lighting maths only works on linear colour values, so hex colours are
// decoded (squared) before lighting and re-encoded (square root) at the end.
// orbit3d.glsl has the longer version of this.
vec3 toLinear(vec3 c) { return c * c; }

// ----------------------------------------------------------------------------
// Buffer A's layout
//
// Buffer A is a picture the size of 70% of the screen (neowall's size for a
// buffer that reads itself), and this uses a few patches of it:
//
//   row 0                   the state: koi, pads, lights, wind, rain...
//   rows 2..109, left       tiles: which koi and pads reach each patch of the
//                           screen (20 px squares on a 4K screen)
//   rows 2..33, from x 300  each koi's skin, laid out flat
//   rows 36..99, from 300   each lily pad, painted flat
//   rows 120..479           the ripple grid
//   rows 488..919           the water's light, ready to draw
//
// Everything else is left alone. It all fits in the buffer of a 1080p
// screen (the water's light gets fewer rows there) up to about 21:9.
const int TILE_Y0   = 2;
const int TILE_ROWS = 108;
const int GRID_Y0   = 120;
const int W_Y0      = GRID_Y0 + GRID_ROWS + 8;
const float GRID_MARGIN = 0.06;   // the ripple grid reaches this far past the screen's edges...
const float SPONGE      = 0.05;   // ...where the last of this soaks ripples up, so nothing bounces off the edges
const int SKIN_X0   = 300;
const int SKIN_Y0   = TILE_Y0;
const int SKIN_W    = 96;         // along the koi
const int SKIN_H    = 32;         // across it
const float SKIN_U  = 1.25;       // how far along the koi the skin reaches (1 = the root of the tail)
const int PADS_X0   = SKIN_X0;
const int PADS_Y0   = SKIN_Y0 + SKIN_H + 2;
const int PAD_SPR   = 64;
const float PAD_SPR_R = 1.08;     // how far out a pad's picture reaches, in radii

// the state row, texel by texel
const int S_METRICS    = 0;    // smoothed cpu, network, heat (+ the marker, see stateTexel)
const int S_METRICS_LO = 1;    // their fine parts
const int S_CLOCK      = 2;    // rain: how near the next drop is (coarse, fine), drops so far
const int S_UNDER      = 3;    // the colour of the water between things, and how much it's day
const int S_SRC        = 4;    // 4..13, things poking the water: 2 drops, 7 koi, the pointer
const int N_SRC        = 10;
const int S_LIGHT      = 14;   // where the light comes from, and how much it's day
const int S_LIGHT2     = 15;   // the light's colour, and how golden
const int S_GUST       = 16;   // the gust: where it is, and its velocity
const int S_GUST2      = 17;   // its age (below 0 while waiting for the next), lifetime, radius, strength
const int S_LANTERN    = 18;   // the lantern's light just now, and how much it's night
const int S_PHASE      = 19;   // two steady clocks, for flicker and dabbling (coarse, fine each)
// the koi: F_STRIDE texels each. The mind is worked out first each frame; the
// body follows where the mind put the head, a frame later.
const int F_BASE       = 20;
const int F_STRIDE     = 23;
const int F_HEAD = 0, F_MOVE = 1, F_SWIM = 2, F_MIND = 3, F_EXTRA = 4;
const int F_CHEAD = 5, F_CHAIN = 6, F_DRAW = 10, F_SHADOW = 14, F_LOOK = 15, F_TINT = 16, F_FIN = 17,
          F_BOUND = 21, F_SHADOW2 = 22;
// the pads
const int P_BASE   = F_BASE + N_KOI * F_STRIDE;
const int P_STRIDE = 3;
const int S_COUNT  = P_BASE + N_PADS * P_STRIDE;

vec4 state(int i) { return texelFetch(iChannel0, ivec2(i, 0), 0); }
int  koiTexel(int k, int slot) { return F_BASE + k * F_STRIDE + slot; }
int  padTexel(int k, int slot) { return P_BASE + k * P_STRIDE + slot; }

// neowall buffers hold half floats: about 3 significant digits. orbit3d
// explains why that isn't enough for something that must move smoothly; the
// fix is the same here. A position is kept as a coarse part in whole 1/128ths
// (which half floats hold exactly) plus the small leftover.
vec2 coarse(vec2 x) { return floor(x * 128.0 + 0.5) / 128.0; }
vec4 hilo(vec2 x) { vec2 c = coarse(x); return vec4(c, x - c); }
// ...and a number that grows a little every frame, counted in turns (so it
// wraps at 1). Straight from orbit3d.
vec2 accumulate(vec2 hl, float step) {
    float lo = hl.y + step;
    float carry = floor(lo * 256.0) / 256.0;
    return vec2(fract(hl.x + carry), lo - carry);
}

float hash(float n) { return fract(sin(n) * 43758.5453123); }   // a repeatable "random" 0..1 for any n
float wrapAngle(float a) { return a - TAU * floor(a / TAU + 0.5); }
vec2  rot90(vec2 v) { return vec2(-v.y, v.x); }
float cross2(vec2 a, vec2 b) { return a.x * b.y - a.y * b.x; }
// a soft wave 0..1..0 once a unit, made without sine (which this chip is slow at)
float tri(float x) { float t = abs(fract(x) - 0.5) * 2.0; return t * t * (3.0 - 2.0 * t); }
// sin and cos too, without sine: a parabola, refined. Good to ~0.1%.
vec2 sinCos(float x) {
    vec2 a = vec2(x, x + 1.5707963);
    a -= TAU * floor(a / TAU + 0.5);
    vec2 y = 1.2732395 * a - 0.4052847 * a * abs(a);
    return 0.225 * (y * abs(y) - y) + y;
}
// smooth value noise, 0..1 (Buffer A only: its sine-based hash is slow per pixel)
float vnoise(vec2 p) {
    vec2 i = floor(p), f = p - i;
    vec2 u = f * f * (3.0 - 2.0 * f);
    float a = hash(dot(i, vec2(1.0, 57.0))), b = hash(dot(i + vec2(1, 0), vec2(1.0, 57.0)));
    float c = hash(dot(i + vec2(0, 1), vec2(1.0, 57.0))), d = hash(dot(i + vec2(1, 1), vec2(1.0, 57.0)));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}
// how far p is from the line a..b, squared
float segDist2(vec2 p, vec2 a, vec2 b) {
    vec2 ab = b - a, ap = p - a;
    float t = clamp(dot(ap, ab) / max(dot(ab, ab), 1e-8), 0.0, 1.0);
    vec2 d = ap - ab * t;
    return dot(d, d);
}

// The ripple grid: a little past the screen all round (hw is half the
// screen's width), so ripples leave the screen before they're soaked up.
struct Grid { int cols, rows; float cell; vec2 origin; };
Grid gridFor(float hw) {
    Grid g;
    g.rows = GRID_ROWS;
    g.cell = (1.0 + 2.0 * GRID_MARGIN) / float(GRID_ROWS);
    g.cols = int(ceil((2.0 * hw + 2.0 * GRID_MARGIN) / g.cell));
    g.origin = vec2(-hw - GRID_MARGIN, -0.5 - GRID_MARGIN);
    return g;
}
int tileCols(float hw) { return int(ceil(2.0 * hw * float(TILE_ROWS))); }
// the water-light grid: as tall as asked for, or as fits in the buffer
int waterRows(float bufH) { return min(WATER_ROWS, int(bufH) - W_Y0 - 8); }

// The pointer, in pond units. iMouse is in the screen's pixels, counting down
// from the top, and a buffer pass isn't told the screen's size: neowall makes
// buffers like this one 70% of it, so work it back from that.
vec2 pointerPos(float hw) {
    float H = iResolution.y / 0.7;
    return vec2(iMouse.x / H - hw, 0.5 - iMouse.y / H);
}

// ----------------------------------------------------------------------------
// The light: the sun by day, the moon by night. The sun comes up in the east
// (the screen's right), passes south (the bottom) and sets west (the left),
// higher at midday; the moon stands high to the upper left. .w says how
// much it's day; the colour texel's .w how golden the sun is (low in the
// sky, at either end of the day).
vec4 lightTexel(bool colour) {
    float day = smoothstep(0.03, 0.35, iSun);
    vec2  az = sinCos(3.14159265 * (iTimeOfDay - 0.25) * 2.0);
    vec2  el = sinCos(mix(0.35, 1.1, iSun));
    vec3  sun = vec3(vec2(az.y, -az.x) * el.y, el.x);
    vec3  moon = vec3(-0.40, 0.48, 0.78);
    vec3  dir = normalize(mix(moon, sun, day));
    float golden = day * (1.0 - smoothstep(0.15, 0.55, iSun));
    if (!colour) return vec4(dir, day);
    vec3  sunCol = mix(toLinear(fujiWhite) * 1.2, toLinear(surimiOrange) * 1.1, golden);
    return vec4(mix(toLinear(springViolet2) * 0.30, sunCol, day), golden);
}
// the light from the sky all round, which even the shadows get
vec3 ambientFor(float day) { return mix(toLinear(winterBlue) * 0.30, toLinear(dragonBlue) * 0.22, day); }

// The lantern's light at a spot (z above the water; below it is negative):
// which way it comes from (.xyz), and how much of it gets there (.w).
vec4 lanternAt(vec2 pos, float hw, float z) {
    vec3  lp = vec3(LANTERN_POS.x / 0.8889 * hw, LANTERN_POS.yz);   // it stays by the corner on any shape of screen
    vec3  d  = lp - vec3(pos, z);
    float d2 = dot(d, d);
    return vec4(d * inversesqrt(d2), LANTERN_REACH * LANTERN_REACH / (LANTERN_REACH * LANTERN_REACH + d2 * 4.0));
}

// ----------------------------------------------------------------------------
// Ripples
//
// Each grid point keeps its height now (.r) and a frame ago (.g). The
// difference is how fast it's moving, and it keeps moving (with a little
// lost to damping), pushed toward the average of its neighbours: the wave
// equation. The "average of its neighbours" uses all eight around it, which
// keeps rings round; with just four they come out squarish. The viscosity
// does the same to how fast they move, so the small, fussy ripples die
// first, as on real water. .ba is the slope, for the light.
vec4 rippleCell(ivec2 px, Grid g, float hw, bool fresh) {
    ivec2 lo = ivec2(0, GRID_Y0), hi = ivec2(g.cols - 1, GRID_Y0 + g.rows - 1);
    vec4  c  = texelFetch(iChannel0, px, 0);
    vec2  e  = texelFetch(iChannel0, min(px + ivec2(1, 0), hi), 0).rg;
    vec2  w  = texelFetch(iChannel0, max(px - ivec2(1, 0), lo), 0).rg;
    vec2  n  = texelFetch(iChannel0, min(px + ivec2(0, 1), hi), 0).rg;
    vec2  s  = texelFetch(iChannel0, max(px - ivec2(0, 1), lo), 0).rg;
    vec2  ne = texelFetch(iChannel0, min(px + ivec2(1, 1), hi), 0).rg;
    vec2  nw = texelFetch(iChannel0, clamp(px + ivec2(-1, 1), lo, hi), 0).rg;
    vec2  se = texelFetch(iChannel0, clamp(px + ivec2(1, -1), lo, hi), 0).rg;
    vec2  sw = texelFetch(iChannel0, max(px - ivec2(1, 1), lo), 0).rg;
    if (fresh) return vec4(0.0);
    vec2  lap2 = (4.0 * (e + w + n + s) + (ne + nw + se + sw) - 20.0 * c.rg) / 6.0;
    vec2  pos = g.origin + (vec2(px - lo) + 0.5) * g.cell;
    vec2  over = max(abs(pos) - vec2(hw, 0.5), 0.0);
    float edge = smoothstep(0.0, SPONGE, max(over.x, over.y));
    // A frame is one step: if frames come slower than 60 a second the ripples
    // slow down too, since stepping further at once would make them blow up.
    float step60 = clamp(iTimeDelta * 60.0, 0.25, 1.0);
    float h = c.r + (c.r - c.g) * (1.0 - WAVE_DAMP) + WAVE_C2 * step60 * step60 * lap2.x
            + WAVE_VISC * (lap2.x - lap2.y);
    // soaked up past the edge; and the whole pond levels off, very slowly
    h *= 1.0 - 0.12 * edge - 0.002;
    // a gust: wind pushing the surface about under it, which the waves turn
    // into a patch of fine chop drifting across the pond
    vec4 G2 = state(S_GUST2);
    if (G2.w > 0.0) {
        vec4  G = state(S_GUST);
        vec2  dg = (pos - G.xy) / G2.z;
        float fall = 1.0 - dot(dg, dg);
        if (fall > 0.0) {
            vec2 np = pos / (3.5 * g.cell) - G.zw * G2.x * 90.0;
            h += G2.w * fall * fall * (vnoise(np) + vnoise(np * 1.7 + 4.1) - 1.0);
        }
    }
    // Things poking the water. Each poke is a dip with a raised rim, shaped
    // so it adds no water overall: pokes that only pushed down would slowly
    // hollow the pond out.
    for (int k = 0; k < N_SRC; k++) {
        vec4 src = state(S_SRC + k);
        if (src.z != 0.0) {
            vec2  d  = (pos - src.xy) / (src.w * g.cell);
            float d2 = dot(d, d);
            if (d2 < 16.0) h += src.z * (exp(-d2) - 0.5 * exp(-0.5 * d2));
        }
    }
    return vec4(h, c.r, 0.5 * (e.x - w.x), 0.5 * (n.x - s.x));
}

// the ripple grid at any spot, smoothly
vec4 rippleAt(vec2 pos, Grid g, vec2 bufSize) {
    vec2 tc = clamp((pos - g.origin) / g.cell, vec2(0.5), vec2(g.cols, g.rows) - 0.5) + vec2(0.0, float(GRID_Y0));
    return texture(iChannel0, tc / bufSize);
}

// Highlights roll off smoothly instead of clipping (as in orbit3d).
vec3 tonemap(vec3 c) {
    const float K = 0.6;
    vec3 over = max(c - K, 0.0);
    return min(c, vec3(K)) + over / (1.0 + over / (1.0 - K));
}

// ----------------------------------------------------------------------------
// The water's light
//
// Most of the screen is only water, and on this chip every little bit of
// maths done per pixel adds up (see "What it costs"). So the water's light is
// worked out here instead, on a grid a twenty-fifth of the screen's pixels
// (5 px squares on a 4K screen), and the drawing pass just reads it:
// everything in it is soft, apart from the sharpest glints.

// How much light the koi and pads above keep off the floor here. The tiles
// say which might, so most spots check none.
float floorShadow(vec2 pos, float hw) {
    ivec2 ti = ivec2(clamp((pos + vec2(hw, 0.5)) * float(TILE_ROWS), vec2(0.0), vec2(float(tileCols(hw) - 1), float(TILE_ROWS - 1))));
    vec4  tile = texelFetch(iChannel0, ti + ivec2(0, TILE_Y0), 0);
    int   todo = int(tile.g + 0.5);
    float shadow = 0.0;
    while (todo != 0) {
        int bit = todo & -todo;
        todo ^= bit;
        int k = int(log2(float(bit)) + 0.5);
        vec4  s0 = state(koiTexel(k, F_SHADOW)), s1 = state(koiTexel(k, F_SHADOW2));
        float d = sqrt(min(segDist2(pos, s0.xy, s0.zw), segDist2(pos, s0.zw, s1.xy)));
        shadow = max(shadow, smoothstep(s1.z + s1.w, s1.z - s1.w, d) * 0.6);
    }
    int ptodo = (int(tile.b + 0.5) >> 5) & 31;
    if (ptodo != 0) {
        vec4 L = state(S_LIGHT);
        vec2 off = -L.xy / max(L.z, 0.25) * FLOOR_DEPTH;
        while (ptodo != 0) {
            int bit = ptodo & -ptodo;
            ptodo ^= bit;
            int k = int(log2(float(bit)) + 0.5);
            vec4 a = state(padTexel(k, 0));
            float ds = length(pos - (a.xy + a.zw + off));
            shadow = max(shadow, smoothstep(PAD_R[k] + 0.03, PAD_R[k] - 0.02, ds) * 0.7);
        }
    }
    return shadow;
}

// The light coming up out of the water at one spot: the floor, seen through
// it, lit through the ripples, which focus the light into caustics; and on
// top, the sky, the sun or moon and the lantern, reflected off the surface.
// .rgb is ready for the screen; .a is how much of it the surface itself adds
// (the part that lies over the koi too).
vec4 waterCell(vec2 pos, Grid g, vec2 bufSize, float hw) {
    vec4  w = rippleAt(pos, g, bufSize);
    vec2  slope = w.ba * SLOPE;
    vec4  L = state(S_LIGHT), L2 = state(S_LIGHT2), U = state(S_UNDER);
    float day = L.w;
    vec3  amb = ambientFor(day);
    vec3  sky = mix(toLinear(winterBlue) * 0.5, mix(toLinear(waveBlue2), toLinear(surimiOrange) * 0.5, L2.a * 0.5), day);
    // the floor: dark, mottled, and bent about by the ripples above it. The
    // crest of a ripple is a little lens, so caustics are brightest under
    // the crests; they only show in sunlight.
    vec2  fp = pos + slope * (FLOOR_DEPTH * REFRACT);
    float mott = 0.6 * tri(fp.x * 2.3 + fp.y * 1.1) + 0.4 * tri(fp.y * 3.7 - fp.x * 0.7 + 0.3);
    vec3  floorCol = toLinear(mix(sumiInk0, winterGreen, 0.2 + 0.6 * mott)) * 0.8;
    float caustic = max(1.0 + CAUSTICS * w.r, 0.0);
    vec3  floorLit = floorCol * (amb + L2.rgb * L.z * mix(1.0, caustic, day) * (1.0 - floorShadow(pos, hw)));
    // seen through the water, which soaks up red first
    // (exp(-FLOOR_DEPTH * (9, 5, 4)) * 0.7 + 0.3)
    vec3  col = mix(U.rgb, floorLit, vec3(0.349, 0.453, 0.511));
    // The surface, looked at straight down: the direction the view bounces
    // off to, and what's there. Flat water only shows the sky overhead;
    // ripples tip it toward the sun and the brighter sky around it.
    float s2 = dot(slope, slope);
    vec3  n = vec3(-slope, 1.0) * inversesqrt(1.0 + s2);
    vec3  r = vec3(2.0 * n.z * n.xy, 2.0 * n.z * n.z - 1.0);      // reflect(down, n)
    float toward = max(dot(r, L.xyz), 0.0);
    float lobe = toward * toward; lobe *= lobe; lobe *= lobe;
    // the sun or moon itself, glinting off a ripple: kept soft, since this
    // grid is a few pixels a square and a sharp glint would show them
    float glint = smoothstep(0.975, 0.999, toward);
    glint *= glint;
    // water reflects more of the sky the steeper it tips (Fresnel, roughly)
    float F = 0.02 + 0.3 * s2 / (1.0 + s2);
    vec3  surf = (sky + L2.rgb * 0.6 * lobe) * F * 2.0 + L2.rgb * 0.9 * glint;
    vec3  lc = state(S_LANTERN).rgb;
    if (lc.r > 0.0) {
        // The lantern stands low, off to the side, so flat water can't show
        // it; but every ripple face tipped toward it catches its glow, and
        // the steepest a glint. A faint warm wash lies over its corner.
        vec4  la = lanternAt(pos, hw, 0.0);
        float tw = max(dot(r, la.xyz), 0.0);
        float lg = smoothstep(0.97, 0.998, tw);
        col  += floorCol * lc * la.w * 0.35 * vec3(0.349, 0.453, 0.511) + lc * la.w * 0.012;
        surf += lc * la.w * (0.22 * smoothstep(la.z + 0.02, la.z + 0.35, tw) + 1.2 * lg * lg);
    }
    // stored ready for the screen (tone-mapped and gamma-encoded), since
    // most pixels show nothing but water; .a stays linear
    return vec4(sqrt(tonemap(col + surf)), dot(surf, vec3(0.333)) / max(dot(L2.rgb + lc, vec3(0.333)), 1e-3));
}

// ----------------------------------------------------------------------------
// Koi skins
//
// Each koi's pattern, laid out flat: along it (u: 0 the nose, 1 the root of
// its tail) and across it (vn: -1 one flank, 0 its spine, 1 the other). .x is
// above 0 where its first kind of patch is (red, mostly), .y where its second
// is, .z a shade for its scales. They're smooth fields, cut sharp by the
// drawing pass, so a small texture still gives crisp edges: bilinear
// filtering blurs a colour, but not where a smooth field crosses 0.

// a blob, in body coordinates (u centre, vn centre, u radius, vn radius): > 0 inside
float blob(float u, float vn, vec4 b) { return 1.0 - length(vec2((u - b.x) / b.z, (vn - b.y) / b.w)); }

vec4 skinTexel(int k, float u, float vn) {
    int   kind = KOI_KIND[k];
    vec2  sd = vec2(float(k) * 13.7, float(k) * 5.3);
    float n1 = 0.65 * vnoise(vec2(u * 7.0, vn * 1.6) + sd) + 0.35 * vnoise(vec2(u * 17.0, vn * 4.0) + sd.yx);
    float n2 = vnoise(vec2(u * 22.0, vn * 5.0) + sd * 1.7);
    float rag = 0.36 * (n1 - 0.5);                                         // ragged edges
    float flank = smoothstep(0.6, 1.0, abs(vn) + 0.35 * (n2 - 0.5));   // seen from above, the flanks stay pale
    float f1 = -1.0, f2 = -1.0;
    if (kind == 0) {         // kohaku: white, with big red patches
        f1 = max(max(blob(u, vn, vec4(0.13, 0.05, 0.11, 1.1)), blob(u, vn, vec4(0.42, -0.1, 0.17, 1.0))),
                 blob(u, vn, vec4(0.70, 0.15, 0.09, 0.8))) + rag - 0.8 * flank;
    } else if (kind == 1) {  // tancho: white, with one red circle on its head
        f1 = blob(u, vn, vec4(0.12, 0.0, 0.075, 0.62)) + 0.1 * (n1 - 0.5);
    } else if (kind == 2) {  // showa: black, with red and white
        f1 = max(max(blob(u, vn, vec4(0.15, -0.1, 0.12, 1.0)), blob(u, vn, vec4(0.48, 0.25, 0.13, 0.8))),
                 blob(u, vn, vec4(0.66, -0.3, 0.07, 0.7))) + rag - 0.4 * flank;
        f2 = min(max(blob(u, vn, vec4(0.34, -0.4, 0.09, 0.8)), blob(u, vn, vec4(0.58, 0.6, 0.1, 0.6))) + rag, -f1);
    } else if (kind == 5) {  // sanke: kohaku, with small black spots
        f1 = max(blob(u, vn, vec4(0.2, 0.1, 0.12, 1.0)), blob(u, vn, vec4(0.52, -0.1, 0.14, 0.9))) + rag - 0.8 * flank;
        f2 = (n2 - 0.68) * 4.0 * step(0.2, u) - flank;
    } else if (kind == 4) {  // asagi: blue-grey back, orange flanks and cheeks
        f1 = (abs(vn) + 0.25 * (n2 - 0.5) - 0.72) * 2.0 + smoothstep(0.1, 0.02, u) * 1.5;
    }
    // scales: a net of darker edges, strong on the metallic and netted kinds
    vec2  sc = vec2(u * 34.0, vn * 5.0);
    sc.y += 0.5 * mod(floor(sc.x), 2.0);
    float net = smoothstep(0.30, 0.48, length((fract(sc) - 0.5) * vec2(1.0, 1.3)));
    float netStrength = (kind == 3 || kind == 4 || kind == 6) ? 0.22 : 0.06;
    return vec4(f1, f2, (1.0 - netStrength * net) * (0.94 + 0.12 * n1), 0.0);
}

// ----------------------------------------------------------------------------
// A koi's mind: where it's going, how fast, and how deep
struct Mind {
    vec2  head;                   // where its nose is
    float heading, speed, turn, depth;
    vec2  phase;                  // how far through a tail beat (coarse, fine)
    float swing;                  // how hard it's swimming: 1 beating, toward 0 gliding
    float beat;                   // time left beating (> 0) or gliding (< 0)
    vec2  target;                 // where it's going
    float mindT, mode;            // how long until it thinks again, and what it's up to
    float depthGoal, depthVel, gulp, decisions;
};

const float MODE_WANDER = 0.0, MODE_FOLLOW = 1.0, MODE_SURFACE = 2.0, MODE_GREET = 3.0, MODE_CURIOUS = 4.0;

Mind loadMind(int k) {
    Mind f;
    vec4 a = state(koiTexel(k, F_HEAD));  f.head = a.xy + a.zw;
    a = state(koiTexel(k, F_MOVE));       f.heading = a.x; f.speed = a.y; f.turn = a.z; f.depth = a.w;
    a = state(koiTexel(k, F_SWIM));       f.phase = a.xy; f.swing = a.z; f.beat = a.w;
    a = state(koiTexel(k, F_MIND));       f.target = a.xy; f.mindT = a.z; f.mode = a.w;
    a = state(koiTexel(k, F_EXTRA));      f.depthGoal = a.x; f.depthVel = a.y; f.gulp = a.z; f.decisions = a.w;
    return f;
}

// a fresh start: spread over the screen, facing every which way
Mind freshMind(int k, float hw) {
    Mind f;
    float fk = float(k);
    vec2 cell = vec2(mod(fk, 4.0), floor(fk / 4.0));
    f.head = vec2((cell.x + 0.5) / 4.0 * 2.0 * hw - hw, (cell.y + 0.5) / 2.0 - 0.5)
           + 0.12 * vec2(hash(fk * 3.1) - 0.5, hash(fk * 5.7) - 0.5);
    f.heading = TAU * hash(fk * 7.3 + 1.0);
    f.speed = 0.05; f.turn = 0.0;
    f.depth = mix(KOI_DEPTH[k].x, KOI_DEPTH[k].y, hash(fk * 1.9));
    f.phase = vec2(hash(fk * 2.3), 0.0); f.swing = 0.5; f.beat = 0.5 + hash(fk);
    f.target = f.head + 0.3 * vec2(cos(f.heading), sin(f.heading));
    f.mindT = 2.0 + 4.0 * hash(fk * 4.4); f.mode = MODE_WANDER;
    f.depthGoal = f.depth; f.depthVel = 0.0; f.gulp = 0.0; f.decisions = fk * 17.0;
    return f;
}

// close enough to where it was going: near it, or passing it by, so it
// doesn't circle round trying to hit it
bool reached(Mind f) {
    vec2  to = f.target - f.head;
    float d  = length(to);
    return d < 0.15 || (d < 0.3 && dot(to, vec2(cos(f.heading), sin(f.heading))) < 0.0);
}

// how much room there is at a spot: how far it is from the nearest other koi
float roomAt(vec2 at, int k) {
    float m = 1e9;
    for (int j = 0; j < N_KOI; j++) {
        if (j == k) continue;
        vec4 h = state(koiTexel(j, F_HEAD));
        m = min(m, length(at - h.xy - h.zw));
    }
    return m;
}

// One frame of a koi's life. src comes back as how it pokes the water.
Mind stepMind(int k, Mind f, float dt, float hw, float energy, float warmth, bool revealed, out vec4 src) {
    float len = KOI_LEN[k];
    float fk  = float(k);

    // --- what it's up to
    f.mindT -= dt;
    vec2 mouse = pointerPos(hw);
    bool curious = iMouseEnergy > 0.05 && length(mouse - f.head) < CURIOUS_RANGE;
    if (revealed) {
        // It notices you: up to the surface, where it is, drifting in a little.
        f.mode = MODE_GREET; f.mindT = 6.0 + 3.0 * hash(fk + f.decisions);
        f.target = f.head * 0.8 + 0.08 * vec2(hash(fk * 3.7 + f.decisions) - 0.5, hash(fk * 1.1 + f.decisions) - 0.5);
        f.depthGoal = 0.0;
    } else if (curious) {
        f.mode = MODE_CURIOUS; f.mindT = max(f.mindT, 1.5);
        f.target = mouse; f.depthGoal = 0.01;
    } else if (f.mindT <= 0.0 || (f.mode == MODE_WANDER && reached(f))) {
        f.decisions = mod(f.decisions + 1.0, 256.0);
        float r  = hash(fk * 13.1 + f.decisions * 1.7);
        float r3 = hash(fk * 9.7 + f.decisions * 0.37);
        // Somewhere new: mostly ahead of it, so it flows from one place to
        // the next instead of turning back on itself, and preferably where
        // the others aren't. The best of four spots.
        float bestScore = -1e9;
        vec2  lim = vec2(hw - 0.05, 0.42);
        for (int c = 0; c < 4; c++) {
            float h1 = hash(fk * 5.3 + f.decisions * 3.1 + float(c) * 11.0);
            float h2 = hash(fk * 2.9 + f.decisions * 1.3 + float(c) * 7.0);
            vec2  cand = c < 3 ? f.head + mix(0.3, 0.8, h2) * vec2(cos(f.heading + (h1 - 0.5) * 2.4), sin(f.heading + (h1 - 0.5) * 2.4))
                               : vec2((h1 * 2.0 - 1.0) * lim.x, (h2 * 2.0 - 1.0) * lim.y);
            vec2  inside = clamp(cand, -lim, lim);
            float score = roomAt(inside, k) - 2.0 * length(cand - inside);
            if (score > bestScore) { bestScore = score; f.target = inside; }
        }
        // Now and then it tags along behind another for a while, or comes up
        // to gulp at the surface: more so when it's lively, and when the
        // water's warm (warm water holds less air).
        f.mode = r < 0.12 ? MODE_FOLLOW : (r < 0.24 + 0.1 * energy + 0.3 * warmth ? MODE_SURFACE : MODE_WANDER);
        f.mindT = f.mode == MODE_FOLLOW ? mix(4.0, 8.0, r3) : mix(7.0, 16.0, hash(fk + f.decisions * 7.1));
        f.depthGoal = f.mode == MODE_SURFACE ? 0.0 : mix(KOI_DEPTH[k].x, KOI_DEPTH[k].y, r3);
    }
    if (f.mode == MODE_FOLLOW) {
        int j = int(mod(fk + 1.0 + floor(f.decisions * 0.5), float(N_KOI)));
        if (j == k) j = int(mod(fk + 1.0, float(N_KOI)));
        vec4 hj = state(koiTexel(j, F_HEAD));
        vec4 mj = state(koiTexel(j, F_MOVE));
        // only ever behind a leader, never a follower: no conga lines
        if (state(koiTexel(j, F_MIND)).w == MODE_FOLLOW) f.mode = MODE_WANDER;
        else {
            f.target = hj.xy + hj.zw - vec2(cos(mj.x), sin(mj.x)) * KOI_LEN[j] * 1.2;
            f.depthGoal = mj.w + 0.02;
        }
    }

    // A drop landing right beside it, while it's up near the surface,
    // startles it: it snaps its body round (a fish's "C-start") and shoots off
    // away from the splash, down into deeper water.
    for (int n = 0; n < 2; n++) {
        vec4 d = state(S_SRC + n);
        if (d.z < 0.0 && f.depth < 0.07 && length(d.xy - f.head) < STARTLE_RANGE) {
            vec2  away = normalize(f.head - d.xy + vec2(1e-4, 0.0));
            f.heading = wrapAngle(f.heading + clamp(wrapAngle(atan(away.y, away.x) - f.heading), -0.8, 0.8));
            f.turn = 0.0;
            f.speed = max(f.speed, 0.30); f.beat = 0.7; f.swing = 1.0;
            f.target = f.head + away * 0.45; f.mode = MODE_WANDER; f.mindT = 5.0;
            f.depthGoal = KOI_DEPTH[k].y; f.depthVel = 0.25;
        }
    }

    // --- steering: toward where it's going, away from koi at its own depth
    // (koi at other depths just pass over or under), a gentle wish for room
    // whatever the depth, and soft walls just inside the screen's edges
    vec2  toT   = f.target - f.head;
    float distT = length(toT);
    vec2  want  = toT / max(distT, 1e-4);
    for (int j = 0; j < N_KOI; j++) {
        if (j == k) continue;
        vec4  hj = state(koiTexel(j, F_HEAD));
        float zj = state(koiTexel(j, F_MOVE)).w;
        vec2  d  = f.head - (hj.xy + hj.zw);
        float dl = length(d);
        float range = 0.45 * (len + KOI_LEN[j]);
        vec2  away = d / max(dl, 1e-4);
        if (dl < range && abs(f.depth - zj) < 0.06) want += 1.5 * away * (1.0 - dl / range);
        if (f.mode != MODE_FOLLOW && dl < 0.5) want += 0.25 * away * (1.0 - dl / 0.5);
    }
    vec2 lim = vec2(hw - 0.02, 0.47);
    want += 2.5 * max(abs(f.head) - lim, 0.0) * -sign(f.head) / 0.1;
    want = normalize(want + 1e-5);
    // turning: a damped spring toward that way, never faster than TURN_MAX
    // (slower still when it's barely moving)
    float err = wrapAngle(atan(want.y, want.x) - f.heading);
    f.turn += (TURN_K * err - TURN_D * f.turn) * dt;
    float turnMax = TURN_MAX * (0.4 + 0.6 * smoothstep(0.0, 0.08, f.speed));
    f.turn = clamp(f.turn, -turnMax, turnMax);
    f.heading = wrapAngle(f.heading + f.turn * dt);
    vec2 dir = vec2(cos(f.heading), sin(f.heading));

    // --- beat and glide: a burst of tail beats eases it up to cruising
    // speed, then it coasts, slowing, until the next. Each burst and each
    // glide lasts a little longer or shorter than the last, so it never
    // falls into a rhythm; lively koi beat harder and glide less.
    bool  excited = f.mode == MODE_GREET || f.mode == MODE_CURIOUS;
    float vigor = max(energy, excited ? 0.7 : 0.0);
    bool  arriving = excited && distT < 0.15;
    if (f.beat > 0.0) {
        f.beat -= dt;
        if (f.beat <= 0.0) f.beat = -mix(mix(1.5, 4.0, hash(fk + f.phase.x * 91.0)), 0.5, vigor);
    } else {
        f.beat += dt;
        if (f.beat >= 0.0) f.beat = mix(0.8, 1.6, hash(fk * 1.3 + f.phase.x * 57.0));
    }
    float cruise = mix(CRUISE.x, CRUISE.y, vigor) * (0.85 + 0.3 * hash(fk * 3.3)) * (arriving ? 0.25 : 1.0);
    if (f.beat > 0.0) f.speed += (cruise - f.speed) * (1.0 - exp(-2.5 * dt));
    else              f.speed *= exp(-GLIDE_DRAG * dt);
    f.speed = max(f.speed, MIN_SPEED);
    f.swing += ((f.beat > 0.0 ? 1.0 : 0.12) - f.swing) * (1.0 - exp(-4.0 * dt));
    f.phase = accumulate(f.phase, dt * BEAT_HZ * mix(0.35, 1.0, f.swing) * mix(0.8, 1.3, vigor));

    // --- depth: a slow spring toward where it wants to be; a quick one when
    // it's come to see you
    vec2 dk = excited ? vec2(4.0, 3.5) : vec2(1.2, 1.8);
    f.depthVel += (dk.x * (f.depthGoal - f.depth) - dk.y * f.depthVel) * dt;
    f.depth = clamp(f.depth + f.depthVel * dt, 0.0, FLOOR_DEPTH - 0.06);

    f.head += dir * f.speed * dt;

    // --- the water: up at the surface it gulps, a little crater at its
    // mouth every so often; just under it, its nose pushes up a wake
    float gulpBefore = f.gulp;
    bool  atSurface = f.depth < 0.012 && (f.mode == MODE_SURFACE || excited);
    f.gulp = atSurface ? fract(f.gulp + dt * 1.6) : max(f.gulp - dt, 0.0);
    bool  gulped = atSurface && f.gulp < gulpBefore;
    float shallow = 1.0 - smoothstep(0.0, WAKE_DEPTH, f.depth);
    src = vec4(f.head + dir * len * 0.02, WAKE * f.speed * shallow * dt - (gulped ? 0.9 : 0.0), gulped ? 1.2 : 2.2);
    return f;
}

vec4 mindOut(int slot, Mind f) {
    if (slot == F_HEAD) return hilo(f.head);
    if (slot == F_MOVE) return vec4(f.heading, f.speed, f.turn, f.depth);
    if (slot == F_SWIM) return vec4(f.phase, f.swing, f.beat);
    if (slot == F_MIND) return vec4(f.target, f.mindT, f.mode);
    return vec4(f.depthGoal, f.depthVel, f.gulp, f.decisions);
}

// ----------------------------------------------------------------------------
// A koi's body: dragged along behind where its head was last frame
//
// The body is a chain of eight points. Each frame the head moves and every
// point is pulled after the one in front of it, keeping its distance, so the
// body follows the path the head took; no joint bends more than MAX_BEND.
// A swimming wave then sways the drawn points side to side, more toward the
// tail. Every texel of the body only keeps the points it's asked for, walking
// the chain just as far as it needs: holding all of it at once made the
// whole of Buffer A run at half speed (see "What it costs").
vec2 chainPoint(int k, int j) {
    vec4 c = state(koiTexel(k, F_CHAIN + j / 2));
    return (j & 1) == 0 ? c.xy : c.zw;
}

vec4 bodyTexel(int k, int slot, bool fresh, float hw) {
    float len = KOI_LEN[k];
    vec2  head; float heading, turn, depth, speed, swing, ph;
    if (fresh) {
        Mind f = freshMind(k, hw);
        head = f.head; heading = f.heading; turn = 0.0; depth = f.depth; speed = f.speed;
        swing = f.swing; ph = f.phase.x;
    } else {
        vec4 a = state(koiTexel(k, F_HEAD));  head = a.xy + a.zw;
        a = state(koiTexel(k, F_MOVE));       heading = a.x; speed = a.y; turn = a.z; depth = a.w;
        a = state(koiTexel(k, F_SWIM));       ph = a.x + a.y; swing = a.z;
    }
    if (slot == F_CHEAD) return hilo(head);
    // how much of each colour the water above it lets through: red goes first
    if (slot == F_TINT)  return vec4(exp(-depth * vec3(3.5, 2.2, 1.8)), 0.0);
    // the pectoral fins: folded in when it's swimming hard, spread when it's
    // gliding, braking or hovering (sculling gently), and wider on the inside
    // of a turn
    float spread = mix(1.1, 0.35, swing * smoothstep(0.02, 0.12, speed));
    float scull  = 0.25 * (1.0 - swing) * sin(TAU * ph * 0.5);
    if (slot == F_LOOK)
        return vec4(depth, spread + 0.6 * max(turn, 0.0) + scull, spread + 0.6 * max(-turn, 0.0) - scull, 0.0);

    // which points this texel wants (up to three), and whether as drawn
    // (with the swimming wave) or raw
    int  ia = 3, ib = 7, ic = -1;
    bool drawn = true;
    if (slot < F_DRAW)        { ia = 2 * (slot - F_CHAIN); ib = ia + 1; drawn = false; }
    else if (slot < F_SHADOW) { ia = 2 * (slot - F_DRAW); ib = ia + 1; }
    else if (slot == F_BOUND) { ib = 6; ic = 7; }
    else if (slot >= F_FIN && slot < F_FIN + 4) { ia = slot - F_FIN < 2 ? 0 : 3; ib = ia + 1; }
    int  last = max(max(ia, ib), ic);

    vec2  dir = vec2(cos(heading), sin(heading));
    vec4  ch = state(koiTexel(k, F_CHEAD));
    vec2  oldHead = ch.xy + ch.zw;
    vec2  prevP = head, prevD = -dir;
    vec2  A = vec2(0.0), B = vec2(0.0), C = vec2(0.0);
    float seg = len / 8.0;
    float cb = cos(MAX_BEND), sb = sin(MAX_BEND);
    for (int j = 0; j <= last; j++) {
        vec2  P = fresh ? head - dir * seg * float(j + 1) : oldHead + chainPoint(k, j);
        vec2  d = P - prevP;
        float dl = length(d);
        d = dl > 1e-5 ? d / dl : prevD;
        if (dot(d, prevD) < cb) {
            float sgn = cross2(prevD, d) >= 0.0 ? 1.0 : -1.0;
            d = prevD * cb + rot90(prevD) * sb * sgn;
        }
        P = prevP + d * seg;
        vec2  o = P - head;
        if (drawn) {
            float u = float(j + 1) / 8.0;
            o += rot90(d) * (SWING * len * swing * (0.05 + 0.95 * u * u) * sin(TAU * (ph - WAVE_LEN * u)));
        }
        if (j == ia) A = o;
        if (j == ib) B = o;
        if (j == ic) C = o;
        prevP = P; prevD = d;
    }
    if (slot < F_SHADOW) return vec4(A, B);             // F_CHAIN, F_DRAW
    // two capsules that hold all of it, for the tiles: head to middle, and
    // middle to the tip of the tail
    if (slot == F_BOUND) return vec4(A, C + (C - B) * 2.6);
    if (slot == F_SHADOW || slot == F_SHADOW2) {
        // its shadow on the floor: three points along it, where the light
        // casts them (a half float's rounding doesn't matter on something
        // this soft), and how wide and soft it is
        vec4 Ls = state(S_LIGHT);
        vec2 off = -Ls.xy / max(Ls.z, 0.25) * (FLOOR_DEPTH - depth);
        if (slot == F_SHADOW) return vec4(head + off, head + A + off);
        return vec4(head + B + off, 0.8 * WIDTH * len, 0.012 + 0.06 * (FLOOR_DEPTH - depth));
    }
    // the fins: where each one joins the body, and which way it points.
    // Pectorals behind the head, pelvics halfway back.
    int   fin = slot - F_FIN;
    float sg  = (fin & 1) == 0 ? 1.0 : -1.0;
    bool  pec = fin < 2;
    vec2  t = normalize(B - A), n = rot90(t);
    float ang = pec ? spread + 0.6 * max(sg * turn, 0.0) + sg * scull : 0.9;
    vec2  base = pec ? mix(A, B, 0.4) + n * sg * 0.086 * len : A + n * sg * 0.045 * len;
    return vec4(base, -t * cos(ang) + n * sg * sin(ang));
}

// ----------------------------------------------------------------------------
// Lily pads: they drift on a slow current, nudge each other apart, keep to
// the screen, turn slowly, and bob on the ripples under them.
vec4 stepPad(int k, int slot, float dt, float hw, bool fresh, Grid g) {
    float fk = float(k);
    vec4 a = state(padTexel(k, 0)), b = state(padTexel(k, 1));
    vec2 pos = a.xy + a.zw;
    float ang = b.x;
    if (fresh) {
        vec2 spots[5] = vec2[5](vec2(0.55, 0.22), vec2(-0.62, -0.28), vec2(0.18, -0.34), vec2(-0.2, 0.33), vec2(0.72, -0.2));
        pos = spots[k] * vec2(hw / 0.889, 1.0);
        ang = TAU * hash(fk * 2.9);
    }
    float r = PAD_R[k];
    vec2 flow = 0.004 * vec2(sin(iTime * 0.013 + fk), cos(iTime * 0.011 + 2.0 * fk));
    vec2 push = vec2(0.0);
    for (int j = 0; j < N_PADS; j++) {
        if (j == k) continue;
        vec4 o = state(padTexel(j, 0));
        vec2 d = pos - (o.xy + o.zw);
        float dl = length(d), gap = r + PAD_R[j] + 0.03;
        if (dl < gap) push += 0.05 * d / max(dl, 1e-4) * (1.0 - dl / gap);
    }
    vec2 lim = vec2(hw - 0.04, 0.46);
    push -= 0.05 * max(abs(pos) - lim, 0.0) * sign(pos) / 0.05;
    pos += (flow + push) * dt;
    ang = wrapAngle(ang + 0.02 * sin(fk * 1.7 + 1.0) * dt);
    if (slot == 0) return hilo(pos);
    if (slot == 1) return vec4(ang, cos(ang), sin(ang), 0.0);
    // how it tips: the slope of the water under it
    ivec2 cellIx = ivec2(clamp((pos - g.origin) / g.cell, vec2(0.0), vec2(g.cols - 1, g.rows - 1))) + ivec2(0, GRID_Y0);
    return vec4(texelFetch(iChannel0, cellIx, 0).ba * SLOPE, 0.0, 0.0);
}

// A pad painted flat in its own frame, its notch along +x, lit: .rgb its
// colour, .a how far inside its edge (in radii), so the drawing pass can cut
// a crisp edge from a small picture, as with the skins.
vec4 padSprite(int k, vec2 d) {
    float dl  = length(d);
    float ang = atan(d.y, d.x);
    float wob = 1.0 + 0.025 * (tri(ang * 1.6) - 0.5) + 0.015 * (tri(ang * 4.3 + 0.3) - 0.5);
    float field = min(wob - dl, (abs(ang) - 0.13) * dl);         // the edge, and the notch
    vec3  g = toLinear(mix(winterGreen, autumnGreen, 0.35 + 0.3 * (1.0 - dl) + 0.15 * fract(float(k) * 0.618)));
    float veins = smoothstep(0.93, 1.0, tri(ang * 9.0 / 3.14159 + dl * 0.3)) * smoothstep(0.15, 0.4, dl) * 0.18;
    g *= 1.0 - veins;
    float rim = smoothstep(0.86, 1.0, dl);                         // a rim that curls up, reddish underneath
    g = mix(g, toLinear(mix(winterGreen, autumnRed, 0.25)), rim * 0.5);
    // the light, turned into the pad's own frame
    vec4  L = state(S_LIGHT), b = state(padTexel(k, 1)), t = state(padTexel(k, 2));
    vec2  lxy = vec2(L.x * b.y + L.y * b.z, L.y * b.y - L.x * b.z);
    vec2  txy = vec2(t.x * b.y + t.y * b.z, t.y * b.y - t.x * b.z);
    vec3  N = normalize(vec3(d / max(dl, 1e-4) * rim * 0.6 - txy * 0.15, 1.0));
    float ndl = max(dot(N, vec3(lxy, L.z)), 0.0);
    float sp = max(2.0 * ndl * N.z - L.z, 0.0);                    // reflect(-L, N).z: its waxy sheen
    sp *= sp; sp *= sp; sp *= sp; sp *= sp;
    vec3  lc = state(S_LIGHT2).rgb;
    vec3  col = g * (ambientFor(L.w) * 1.6 + lc * ndl) + lc * 0.10 * sp;
    vec3  ln = state(S_LANTERN).rgb;
    if (ln.r > 0.0) {
        vec4 pa = state(padTexel(k, 0));
        vec4 la = lanternAt(pa.xy + pa.zw, 0.5 * iResolution.x / iResolution.y, 0.0);
        col += g * ln * la.w * max(dot(N, vec3(la.x * b.y + la.y * b.z, la.y * b.y - la.x * b.z, la.z)), 0.0);
    }
    return vec4(col, field);
}

// ----------------------------------------------------------------------------
// Tiles
//
// The drawing pass would have to try every koi and pad at every pixel, so
// instead the screen is cut into tiles (20 px squares on a 4K screen), and
// each tile lists, as bits, the koi (.r) and pads (.b) that can reach it,
// and the koi (.g) and pads (.b's upper bits) whose shadows can. .a keeps the
// buffer's height, for the drawing pass (see its mainImage). A tile works
// this out from last frame's koi, so it allows a little room for them to
// have moved.
vec4 tileCell(ivec2 t, float hw) {
    float T = 1.0 / float(TILE_ROWS);
    vec2  c = vec2(-hw, -0.5) + (vec2(t) + 0.5) * T;
    float rt = 0.7072 * T;              // from its middle to a corner
    float slack = rt + 0.012;           // ...plus a frame of movement and some refraction
    vec4  L = state(S_LIGHT);
    vec2  sh = L.xy / max(L.z, 0.25);
    float bodies = 0.0, shadows = 0.0, pads = 0.0;
    // (the loops' ends are hidden from the compiler, `+ min(iFrame, 0)`, so it
    // doesn't unroll them into one enormous stretch of code)
    for (int k = 0; k < N_KOI + min(iFrame, 0); k++) {
        vec4  h = state(koiTexel(k, F_CHEAD));
        float len = KOI_LEN[k];
        vec2  cb = c - (h.xy + h.zw);
        // first, cheaply: is it anywhere near? then segment by segment,
        // allowing for the fins on the front half
        vec4  bb = state(koiTexel(k, F_BOUND));
        float rf = slack + len * 0.30, rb = slack + len * 0.16;
        bool  near = segDist2(cb, vec2(0.0), bb.xy) < rf * rf || segDist2(cb, bb.xy, bb.zw) < rb * rb;
        vec2  a = vec2(0.0);
        bool  hb = false;
        for (int j = 0; j < (near ? 4 : 0); j++) {
            vec4  d = state(koiTexel(k, F_DRAW + j));
            float r0 = slack + len * (j == 0 ? 0.20 : (j == 1 ? 0.25 : (j == 2 ? 0.15 : 0.12)));
            float r1 = slack + len * (j == 0 ? 0.27 : (j == 1 ? 0.17 : 0.12));
            hb = hb || segDist2(cb, a, d.xy) < r0 * r0 || segDist2(cb, d.xy, d.zw) < r1 * r1;
            if (j == 3) hb = hb || segDist2(cb, d.zw, d.zw + (d.zw - d.xy) * 2.6) < (slack + len * 0.13) * (slack + len * 0.13);
            a = d.zw;
        }
        vec4  s0 = state(koiTexel(k, F_SHADOW)), s1 = state(koiTexel(k, F_SHADOW2));
        float shd = rt + s1.z + s1.w + 0.01;
        bool  hs = min(segDist2(c, s0.xy, s0.zw), segDist2(c, s0.zw, s1.xy)) < shd * shd;
        if (hb) bodies += exp2(float(k));
        if (hs) shadows += exp2(float(k));
    }
    for (int k = 0; k < N_PADS + min(iFrame, 0); k++) {
        vec4 a = state(padTexel(k, 0));
        vec2 pos = a.xy + a.zw;
        float reach = rt + PAD_R[k] + 0.012;
        if (length(c - pos) < reach) pads += exp2(float(k));
        if (length(c + sh * FLOOR_DEPTH - pos) < reach + 0.03) pads += exp2(float(k + 5));
    }
    return vec4(bodies, shadows, pads, iResolution.y);
}

// ----------------------------------------------------------------------------
// The state row
vec4 stateTexel(int i, float hw, Grid g) {
    // A texel only counts as remembered if its alpha holds the marker 0.75 (a
    // new buffer is cleared, and the very first frame can be junk).
    vec4 prevM = state(S_METRICS);
    bool fresh = iFrame == 0 || prevM.a != 0.75;
    // after a pause iTimeDelta can be huge, and one giant step would fling
    // everything about
    float dt = min(iTimeDelta, 0.05);
    // Coming back: neowall stops drawing the wallpaper while windows cover
    // it (if it can tell: on this laptop that needs pause_coverage_threshold
    // in config.vibe, because its check forgets the screen's scaling), and
    // the first frame after, iTimeDelta is its biggest, 0.25 s. So a long
    // gap between frames means someone just came to look: the koi notice.
    // A fresh start counts too.
    bool revealed = fresh || iTimeDelta > 0.2;

    // the body texels only need what the mind worked out last frame
    if (i >= F_BASE && i < P_BASE) {
        int k = (i - F_BASE) / F_STRIDE, slot = (i - F_BASE) - k * F_STRIDE;
        if (slot >= F_CHEAD) return bodyTexel(k, slot, fresh, hw);
    }

    // --- the inputs, smoothed the way orbit3d does it (in two parts, with
    // the lag in seconds whatever the frame rate)
    vec4 prevL = state(S_METRICS_LO);
    vec3 live = vec3(iCpuMax, max(iNetDown, iNetUp), iThermal);
    vec3 m = fresh ? live : mix(prevM.rgb + prevL.rgb, live, 1.0 - exp(-dt / INPUT_LAG));
    float energy  = smoothstep(BUSY_RANGE.x, BUSY_RANGE.y, m.x);
    float traffic = smoothstep(NET_RANGE.x, NET_RANGE.y, m.y);
    float warmth  = smoothstep(HEAT_RANGE.x, HEAT_RANGE.y, m.z);

    if (i == S_METRICS)    return vec4(floor(m * 128.0 + 0.5) / 128.0, 0.75);
    if (i == S_METRICS_LO) return vec4(m - floor(m * 128.0 + 0.5) / 128.0, 0.0);
    if (i == S_LIGHT || i == S_LIGHT2) return lightTexel(i == S_LIGHT2);
    if (i == S_UNDER) {
        float day = smoothstep(0.03, 0.35, iSun);
        return vec4(toLinear(winterGreen) * 0.3 * (ambientFor(day) * 3.0 + 0.3), day);
    }
    // two steady clocks, counted up a frame at a time (see orbit3d for why
    // not from iTime, which neowall only resets while the wallpaper's
    // hidden: after days on screen it's too big for a smooth flicker)
    vec4 ph = fresh ? vec4(0.0) : state(S_PHASE);
    ph = vec4(accumulate(ph.xy, dt * 1.16), accumulate(ph.zw, dt * 0.43));
    if (i == S_PHASE) return ph;
    if (i == S_LANTERN) {
        // lit from dusk to dawn, and flickering a little, like a candle
        float night = 1.0 - smoothstep(0.02, 0.3, iSun);
        float p1 = ph.x + ph.y, p2 = ph.z + ph.w;
        float fl = 0.88 + 0.07 * sin(TAU * p1) + 0.03 * sin(TAU * (2.0 * p2 + 0.2)) + 0.02 * sin(TAU * (3.0 * p1 + p2));
        return vec4(toLinear(mix(surimiOrange, carpYellow, 0.35)) * LANTERN * night * fl, night);
    }
    if (i == S_GUST || i == S_GUST2) {
        vec4 G = state(S_GUST), G2 = state(S_GUST2);
        if (fresh) { G = vec4(0.0); G2 = vec4(-6.0, 1.0, 0.2, 0.0); }
        G2.x += dt;
        if (G2.x >= G2.y) {
            // that one's gone: wait a while for the next
            float n = floor(iTime * 0.37) + 13.0 * floor(G.x * 17.0);
            G2 = vec4(-mix(GUST_EVERY.x, GUST_EVERY.y, hash(n * 1.3)), 1.0, 0.2, 0.0);
            G = vec4(1e3, 0.0, 0.0, 0.0);
        }
        if (G2.x < 0.0 && G2.x + dt >= 0.0) {
            // a new one: from just off the screen, upwind, on a line passing
            // near the middle, all the way across. Half the way across is
            // however far it must go to leave the screen along its heading.
            float n = floor(iTime * 0.53) + 7.0;
            float a = TAU * hash(n * 2.1);
            vec2  dirG = vec2(cos(a), sin(a));
            float radius = mix(GUST_SIZE.x, GUST_SIZE.y, hash(n * 3.7));
            vec2  half_ = (vec2(hw, 0.5) + radius) / max(abs(dirG), vec2(1e-3));
            float across = min(half_.x, half_.y);
            G  = vec4(rot90(dirG) * (hash(n * 5.1) - 0.5) * 0.4 - dirG * across, dirG * GUST_SPEED);
            G2 = vec4(0.0, 2.0 * across / GUST_SPEED, radius, 0.0);
        }
        if (G2.x >= 0.0) {
            // it drifts, rising and falling over its life
            G.xy += G.zw * dt;
            G2.w = GUST * sin(3.14159 * clamp(G2.x / G2.y, 0.0, 1.0));
        }
        return i == S_GUST ? G : G2;
    }
    // --- rain: drips when the network's quiet, a shower when it's busy.
    // Each drop pokes the water once (in the frame after the one it's
    // written in), somewhere random, at a random size.
    if (i == S_CLOCK || i == S_SRC || i == S_SRC + 1) {
        vec4 c = fresh ? vec4(0.0) : state(S_CLOCK);
        float rate = 1.0 / DRIP_EVERY + RAIN_MAX * traffic * traffic;
        float acc = c.x + c.y + rate * dt;
        float counter = c.z;
        vec4 d0 = vec4(0.0), d1 = vec4(0.0);
        for (int n = 0; n < 2; n++) {
            if (acc >= 1.0) {
                acc -= 1.0; counter = mod(counter + 1.0, 2048.0);
                float a = hash(counter * 1.37 + 0.1), b = hash(counter * 2.71 + 0.3), s = hash(counter * 0.91 + 0.7);
                vec4 d = vec4((a * 2.0 - 1.0) * hw, b - 0.5, -DROP_DEPTH * (0.5 + s), DROP_RADIUS * (0.7 + 0.6 * s));
                if (n == 0) d0 = d; else d1 = d;
            }
        }
        acc = min(acc, 1.0);
        float accHi = floor(acc * 256.0) / 256.0;
        if (i == S_CLOCK) return vec4(accHi, acc - accHi, counter, 0.0);
        return i == S_SRC ? d0 : d1;
    }
    if (i == S_SRC + 2 + N_KOI) {
        // the pointer, while it moves: a fingertip dabbling in the water,
        // dipping in and out a few times a second, so it trails rings
        float e = smoothstep(0.02, 0.3, iMouseEnergy);
        float dab = max(sin(TAU * 2.0 * (ph.x + ph.y)), 0.0);
        return vec4(pointerPos(hw), -0.5 * e * dab * dab * dt * 60.0, 1.6);
    }
    // --- the koi's minds, and the pokes they give the water
    int k = -1, slot = -1;
    if (i >= S_SRC + 2 && i < S_SRC + 2 + N_KOI) k = i - S_SRC - 2;
    if (i >= F_BASE && i < P_BASE) { k = (i - F_BASE) / F_STRIDE; slot = (i - F_BASE) - k * F_STRIDE; }
    if (k >= 0) {
        Mind f = fresh ? freshMind(k, hw) : loadMind(k);
        vec4 src;
        f = stepMind(k, f, fresh ? 0.0 : dt, hw, energy, warmth, revealed, src);
        return slot < 0 ? src : mindOut(slot, f);
    }
    if (i >= P_BASE && i < S_COUNT) {
        int p = (i - P_BASE) / P_STRIDE, ps = (i - P_BASE) - p * P_STRIDE;
        return stepPad(p, ps, dt, hw, fresh, g);
    }
    return vec4(0.0);
}

// Buffer A: the simulation, and everything worked out once for the drawing pass
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    ivec2 px = ivec2(fragCoord);
    float hw = 0.5 * iResolution.x / iResolution.y;
    int   wRows = waterRows(iResolution.y);
    Grid  g = gridFor(hw);
    // Most of the buffer is unused, and every texel of it runs this, so
    // throw those away before anything else. `discard` writes nothing.
    if (px.y >= W_Y0 + wRows || px.x >= max(max(int(float(wRows) * 2.0 * hw) + 1, g.cols), SKIN_X0 + N_KOI * SKIN_W)) discard;
    if (px.y >= W_Y0) {
        vec2 pos = vec2(-hw, -0.5) + (vec2(px.x, px.y - W_Y0) + 0.5) / float(wRows);
        fragColor = waterCell(pos, g, iResolution.xy, hw);
        return;
    }
    if (px.y >= GRID_Y0) {
        if (px.y < GRID_Y0 + g.rows && px.x < g.cols) {
            bool fresh = iFrame == 0 || state(S_METRICS).a != 0.75;
            fragColor = rippleCell(px, g, hw, fresh);
            return;
        }
        discard;
    }
    if (px.y >= TILE_Y0 && px.y < TILE_Y0 + TILE_ROWS) {
        if (px.x < tileCols(hw)) { fragColor = tileCell(px - ivec2(0, TILE_Y0), hw); return; }
        int qx = px.x - PADS_X0, qy = px.y - PADS_Y0;
        if (qx >= 0 && qx < N_PADS * PAD_SPR && qy >= 0 && qy < PAD_SPR) {
            int k = qx / PAD_SPR;
            vec2 d = ((vec2(qx - k * PAD_SPR, qy) + 0.5) / float(PAD_SPR) * 2.0 - 1.0) * PAD_SPR_R;
            fragColor = padSprite(k, d);
            return;
        }
        int sx = px.x - SKIN_X0, sy = px.y - SKIN_Y0;
        if (sx >= 0 && sx < N_KOI * SKIN_W && sy < SKIN_H) {
            int k = sx / SKIN_W;
            fragColor = skinTexel(k, (float(sx - k * SKIN_W) + 0.5) / float(SKIN_W) * SKIN_U,
                                     (float(sy) + 0.5) / float(SKIN_H) * 2.0 - 1.0);
            return;
        }
        discard;
    }
    if (px.y == 0 && px.x < S_COUNT) { fragColor = stateTexel(px.x, hw, g); return; }
    discard;
}

// ===== drawing helpers =====
// neowall gives code placed between the two mainImage functions to the
// second pass only.

// how wide a koi is along it (u: 0 the nose .. 1 the root of the tail), as a share of its length
float bodyWidth(float u) {
    float grow = mix(0.55, 1.0, smoothstep(-0.02, 0.30, u));
    float taper = mix(1.0, 0.20, smoothstep(0.32, 0.92, u));
    return WIDTH * grow * taper;
}

// A fin: a flat, see-through paddle from its base along fdir, narrow where
// it joins and round at the tip, with rays fanning out from the root.
// How much of this spot it covers.
float finShape(vec2 q, vec2 base, vec2 fdir, float fl, float fw, float blur) {
    vec2  d = q - base;
    float x = dot(d, fdir) / fl;
    float y = dot(d, rot90(fdir));
    if (x <= 0.0 || x >= 1.0) return 0.0;
    float half_ = fw * smoothstep(0.0, 0.4, x) * sqrt(1.0 - x * x);
    float cov = clamp((half_ - abs(y)) / (2.0 * blur) + 0.5, 0.0, 1.0);
    return cov * (0.7 + 0.3 * tri(y / (x * fl + 0.3 * fl) * 7.0));
}

// spine point i (0 the nose .. 8 the root of the tail), from its head
vec2 spine(int k, int i) {
    if (i <= 0) return vec2(0.0);
    vec4 d = state(koiTexel(k, F_DRAW + (i - 1) / 2));
    return ((i - 1) & 1) == 0 ? d.xy : d.zw;
}

// What a koi leaves at a pixel, for shading afterwards: which koi, where on
// it (u along, vn across), how much of it is body rather than fin, how much
// of the pixel it covers, how its flank faces the light, and how deep it is.
struct Hit { int k; float u, vn, share, a, latL, z; };

// Does koi k cover this pixel, and where? Keeps the two nearest the surface.
void koiShape(int k, vec2 p, vec2 slope, float pix, inout Hit front, inout Hit back) {
    vec4  hd = state(koiTexel(k, F_CHEAD));
    vec2  head = hd.xy + hd.zw;
    float len = KOI_LEN[k];
    // what you see at depth z is shifted a little by the slope of the water above it
    float z = state(koiTexel(k, F_LOOK)).x;
    vec2  q = p + slope * (z * REFRACT) - head;

    // the nearest of its nine spine points...
    float bd = dot(q, q);
    int   bi = 0;
    for (int j = 0; j < 4; j++) {
        vec4  d = state(koiTexel(k, F_DRAW + j));
        vec2  a = q - d.xy, b = q - d.zw;
        float da = dot(a, a), db = dot(b, b);
        if (da < bd) { bd = da; bi = 2 * j + 1; }
        if (db < bd) { bd = db; bi = 2 * j + 2; }
    }
    // ...and if nothing of the koi reaches this far from it, stop
    float reach = len * (bi <= 3 ? 0.30 : (bi == 8 ? 0.42 : 0.17)) + 3.0 * pix;
    if (bd > reach * reach) return;

    // the exact nearest point, on a segment either side of that one
    // (the last segment runs on past the root, through the tail fin)
    vec2  A = spine(k, bi - 1), B = spine(k, bi), C = spine(k, min(bi + 1, 8));
    float best = 1e9, bestT = 0.0, bestSide = 1.0;
    int   bestI = 0;
    vec2  bestDD = vec2(0.0);
    for (int m = 0; m < 2; m++) {
        int   si = bi - 1 + m;
        if (si < 0 || si > 7) continue;
        vec2  a = m == 0 ? A : B, b = m == 0 ? B : C;
        vec2  ab = b - a, aq = q - a;
        float t  = clamp(dot(aq, ab) / dot(ab, ab), 0.0, si == 7 ? 3.6 : 1.0);
        vec2  dd = aq - ab * t;
        float d2 = dot(dd, dd);
        if (d2 < best) { best = d2; bestI = si; bestT = t; bestSide = cross2(ab, aq); bestDD = dd; }
    }
    float dist = sqrt(best);
    float u = (float(bestI) + bestT) / 8.0;
    // deeper koi are a little blurred by the water
    float blur = pix * 1.2 + z * 0.012;
    float w = bodyWidth(min(u, 1.0)) * len;
    // the body melts into the tail fin at its root, rather than stopping at a line
    float body = clamp((w - dist) / (2.0 * blur) + 0.5, 0.0, 1.0) * smoothstep(1.03, 0.93, u);
    // the tail fin: a forked fan past the root of the tail, with rays
    float s = (u - 0.9) / 0.3;
    float fins = 0.0;
    if (s > 0.0) {
        float tw = mix(0.2, 1.1, smoothstep(0.0, 0.8, s)) * WIDTH * len;
        float tv = clamp(dist / tw, 0.0, 1.0);
        float tailEnd = 0.72 + 0.28 * tv * tv;
        fins = clamp((tw - dist) / (2.0 * blur) + 0.5, 0.0, 1.0) * clamp((tailEnd - s) * 20.0, 0.0, 1.0)
             * (0.55 + 0.25 * tri(dist / ((u - 0.86) * len) * 5.0));
    }
    // the other fins: pectorals (the big pair) and pelvics, wherever the
    // body doesn't already cover the pixel
    if (body < 1.0 && u < 0.8) {
        int f0 = u < 0.45 ? 0 : 2;
        float fl = f0 == 0 ? 0.19 * len : 0.09 * len, fw = f0 == 0 ? 0.07 * len : 0.035 * len;
        for (int sd = 0; sd < 2; sd++) {
            vec4 fn = state(koiTexel(k, F_FIN + f0 + sd));
            fins = max(fins, finShape(q, fn.xy, fn.zw, fl, fw, blur) * 0.6 * (1.0 - body));
        }
    }
    float a0 = max(body, fins);
    if (a0 <= 0.001) return;
    // which way is out from its spine here, against the light: for its flanks
    float latL = dot(bestDD, state(S_LIGHT).xy) / max(dist, 1e-5);
    Hit h = Hit(k, u, clamp(dist / max(w, 1e-4), 0.0, 1.0) * (bestSide >= 0.0 ? 1.0 : -1.0), body / a0, a0, latL, z);
    if (z < front.z) { back = front; front = h; }
    else if (z < back.z) back = h;
}

// the colour of a koi where a Hit says: its skin, lit, seen through the water
vec3 koiColour(Hit h, vec2 bs, float pix, vec2 p, float hw) {
    int   k = h.k;
    float len = KOI_LEN[k];
    // its skin, from the texture Buffer A painted, cut sharp
    vec2  st = vec2(clamp(h.u / SKIN_U * float(SKIN_W), 0.5, float(SKIN_W) - 0.5) + float(SKIN_X0 + k * SKIN_W),
                    clamp((h.vn * 0.5 + 0.5) * float(SKIN_H), 0.5, float(SKIN_H) - 0.5) + float(SKIN_Y0));
    vec4  sk = texture(iChannel0, st / bs);
    vec3  c = mix(KOI_BASE[k], KOI_HI[k], clamp(sk.x * 30.0 + 0.5, 0.0, 1.0));
    c = mix(c, KOI_SUMI[k], clamp(sk.y * 30.0 + 0.5, 0.0, 1.0)) * sk.z;
    // fins and tail are thin and pale, tinted by the body
    c = mix(mix(toLinear(fujiWhite) * 0.9, c, 0.35), c, h.share);
    // Light on a rounded back: straight up along its spine, leaning out
    // toward its flanks. A wet sheen along the top (strong on the metallic
    // ogon), from the reflection of the light straight up to you.
    vec4  L = state(S_LIGHT);
    float nz = mix(1.0, sqrt(max(1.0 - h.vn * h.vn, 0.0)), h.share);
    float ndl = max(nz * L.z + h.latL * abs(h.vn) * h.share, 0.0);
    float spec = max(2.0 * ndl * nz - L.z, 0.0);
    spec *= spec; spec *= spec; spec *= spec; spec *= spec;
    vec3  lc = state(S_LIGHT2).rgb;
    vec3  c0 = c;
    c = c * (ambientFor(L.w) + lc * ndl) + lc * spec * h.share * (KOI_KIND[k] == 3 ? 0.6 : 0.2);
    // the lantern, at night: warm light, most on the side that faces it
    vec3  ln = state(S_LANTERN).rgb;
    if (ln.r > 0.0) {
        vec4  la = lanternAt(p, hw, -h.z);
        c += c0 * ln * la.w * (0.25 + max(nz * la.z + h.latL * abs(h.vn) * h.share * 0.5, 0.0));
    }
    // its eyes, just behind the nose
    float w = bodyWidth(min(h.u, 1.0)) * len;
    float eye = length(vec2((h.u - 0.075) * len, (abs(h.vn) - 0.62) * w));
    c *= 1.0 - 0.8 * clamp((0.011 * len - eye) / (2.4 * pix) + 0.5, 0.0, 1.0) * h.share;
    // seen through the water above it, which takes the red first
    return mix(state(S_UNDER).rgb, c, state(koiTexel(k, F_TINT)).rgb);
}

// a lily pad, from its picture: turned into its own frame, looked up, cut sharp
void padPixel(int k, vec2 p, float pix, vec2 bs, inout vec3 padRGB, inout float padA) {
    vec4  a = state(padTexel(k, 0));
    float r = PAD_R[k];
    vec2  d = p - (a.xy + a.zw);
    float reach = r * PAD_SPR_R;
    if (dot(d, d) > reach * reach) return;
    vec4  b = state(padTexel(k, 1));
    vec2  l = vec2(d.x * b.y + d.y * b.z, d.y * b.y - d.x * b.z) / reach;
    vec2  st = clamp((l * 0.5 + 0.5) * float(PAD_SPR), vec2(0.5), vec2(float(PAD_SPR) - 0.5))
             + vec2(float(PADS_X0 + k * PAD_SPR), float(PADS_Y0));
    vec4  sp = texture(iChannel0, st / bs);
    float cov = clamp(sp.a * r / (2.0 * pix) + 0.5, 0.0, 1.0);
    padRGB = mix(padRGB, sp.rgb, cov);
    padA = max(padA, cov);
}

// the buffer's size: its height (kept in every tile), its width from the screen's shape
vec2 bufSize(float hw, float bh) { return vec2(floor(bh * 2.0 * hw + 0.5), bh); }

// the water's light, from the grid Buffer A worked it out on
vec4 waterAt(vec2 p, float hw, vec2 bs) {
    float wr = float(waterRows(bs.y));
    vec2  wt = clamp((p + vec2(hw, 0.5)) * wr, vec2(0.5), vec2(2.0 * hw, 1.0) * wr - 0.5);
    return texture(iChannel0, (wt + vec2(0.0, float(W_Y0))) / bs);
}

// ----------------------------------------------------------------------------
// What it costs, and why the drawing pass is shaped the way it is
//
// At 3840x2160 this pass runs 8.3 million times a frame, and unlike orbit3d
// and jelly there's no empty background: every pixel is water at least. On
// this laptop's graphics chip (UHD 630), measured with the offscreen harness:
//
//   - A pixel's maths is dear. Roughly 10 more instructions a pixel cost
//     0.5 ms a frame, so the water's light, the part every pixel needs, is
//     worked out in Buffer A on a coarse grid and read here ready to show.
//   - A texture read costs most in the waiting, and a read that has to wait
//     for another before it can start costs twice. The water needs the
//     buffer's size, and the tile knows it, but the water is read at the
//     same time as the tile, using a guess of neowall's own sum.
//   - Each pixel reads one tile to learn which koi and pads can reach it.
//     About 17% of the screen is in a koi's tile; 5% is on one.
//   - The chip runs 8 or 16 pixels at once, and 16 is nearly twice as fast.
//     Mesa (26.2) decides before it starts: it estimates the most numbers
//     alive at any one moment, and if twice that is over 134 it quietly
//     makes only the 8-wide version (brw_nir_quick_pressure_estimate). So
//     the koi loop only finds which two koi are here and where on them
//     (a Hit each), and they're coloured once it's done; and Buffer A walks
//     each koi's spine a point at a time, keeping only what each texel needs.
//     To check: MESA_SHADER_CACHE_DISABLE=true INTEL_DEBUG=fs lists a
//     "SIMD16 shader:" for both passes.
//   - Buffer A is 70% of the screen, and every texel of it runs its shader,
//     even the unused ones; so it throws those away first.
//
// All of that together, at 4K (Sep 2026, harness, same conditions): about
// 8.5 ms a frame, Buffer A 2.0 and this pass 6.5 (a rainy night, 8.7). jelly
// came out at 8.1 and orbit3d at 9.2 in the same run.
// ----------------------------------------------------------------------------

// Image: the screen, drawn from the simulation (neowall finds each pass by
// a comment like this just above it, so keep other pass names out of it)
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2  p   = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    float hw  = 0.5 * iResolution.x / iResolution.y;

    ivec2 ti = ivec2(clamp((p + vec2(hw, 0.5)) * float(TILE_ROWS), vec2(0.0), vec2(float(tileCols(hw) - 1), float(TILE_ROWS - 1))));
    vec4  tile = texelFetch(iChannel0, ti + ivec2(0, TILE_Y0), 0);
    // The buffer's size, as neowall works it out: buffers like this one are
    // 70% of the screen, rounded down to an even number. The tile says the
    // real height, to check (it could differ if neowall ever scales down).
    vec2  bs = vec2(ivec2(iResolution.xy * 0.7) & ivec2(~1));
    vec4  W  = waterAt(p, hw, bs);
    if (tile.a != bs.y) { bs = bufSize(hw, tile.a); W = waterAt(p, hw, bs); }
    vec3  col;
    int   bodies = int(tile.r + 0.5), pads = int(tile.b + 0.5) & 31;
    if ((bodies | pads) == 0) {
        // nothing but water: the grid has it ready for the screen
        col = W.rgb;
    } else {
        float pix = 1.0 / iResolution.y;
        float fishA = 0.0, padA = 0.0;
        vec3  fishRGB = vec3(0.0), padRGB = vec3(0.0);
        vec2  slope = bodies != 0 ? rippleAt(p, gridFor(hw), bs).ba * SLOPE : vec2(0.0);
        // ---- the koi: find the (at most) two here, then shade them, the
        // deeper one under the other
        Hit   front = Hit(0, 0.0, 0.0, 0.0, 0.0, 0.0, 1e9), back = front;
        int todo = bodies;
        while (todo != 0) {
            int bit = todo & -todo;       // the lowest koi left in the list...
            todo ^= bit;                  // ...crossed off
            koiShape(int(log2(float(bit)) + 0.5), p, slope, pix, front, back);
        }
        if (back.a > 0.0)  { fishRGB = koiColour(back, bs, pix, p, hw) * back.a; fishA = back.a; }
        if (front.a > 0.0) { fishRGB = mix(fishRGB, koiColour(front, bs, pix, p, hw), front.a); fishA = front.a + fishA * (1.0 - front.a); }
        // ---- the pads, on the surface
        int ptodo = pads;
        while (ptodo != 0) {
            int bit = ptodo & -ptodo;
            ptodo ^= bit;
            padPixel(int(log2(float(bit)) + 0.5), p, pix, bs, padRGB, padA);
        }
        // ---- put it together: the water's light is ready for the screen, so
        // back to linear to mix; the koi go under the surface's reflections,
        // the pads over them
        vec3 surf = W.a * (state(S_LIGHT2).rgb + state(S_LANTERN).rgb);
        col = (W.rgb * W.rgb - surf) * (1.0 - fishA) + fishRGB + surf;
        col = mix(col, padRGB, padA);
        if (max(col.r, max(col.g, col.b)) > 0.6) col = tonemap(col);
        col = sqrt(max(col, 0.0));
    }
    // Dither: nudge each pixel by up to one step of the 0..255 range, in a fine
    // noise pattern, or 8-bit colour draws bands across the dark water.
    col += (fract(52.9829189 * fract(dot(fragCoord, vec2(0.06711056, 0.00583715)))) - 0.5) / 255.0;
    fragColor = vec4(col, 1.0);
}
