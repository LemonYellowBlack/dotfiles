// nighttrain.glsl: the view from a train window at night. The land goes by
// in layers, the far mountains barely moving and the poles beside the track
// flicking past; the train pulls in at stations whose signs say what just
// happened on this computer; tunnels, bridges, towns and lakes come and go;
// rain runs across the glass, which mists over, and you can wipe it clear.
//
// It's a terminal wallpaper: neowall runs nighttrain.py and hands this shader
// what that program prints (neowall's terminal mode; PLAN.md has the design).
// The program decides what happens and when; this decides how it all looks,
// and does the fine motion itself, since only it knows where the train is
// every frame. What it reads:
//
//   the program   the heartbeat that keeps it moving, stations and their
//                 signs, tunnels (and a change of line inside one), the
//                 weather, and where you wiped the glass       (iTermCells)
//   time of day   night is the point, but dusk, dawn and an overcast day
//                 come round with the real clock    (iSun, iTimeOfDay)
//   the date      the moon's phase                               (iDate)
//   cpu           how fast the train runs: 18 m/s idling, 34 flat out
//                 (iCpuMax)
//
// What makes it feel real, mostly borrowed from sitting on a train:
//   - parallax: the land is five layers, each four times as far away as the
//     one in front, so each slides by at a quarter of the speed. The poles 16
//     m away flick past; the mountains 4 km off hardly move at all
//   - the wires between the poles sag, so they seem to rise and fall as you
//     watch them, the way they do from a real train
//   - stations: the train brakes smoothly to the metre it's told to (the sign
//     ends up dead in the middle of the window) and waits there
//   - the land changes as you go: forest, lakes, plains, hills and coast
//     drift by every few km, with towns, bridges, crossings and tunnels in
//     among them; a line is its own mix of them. None of it repeats: it's all
//     worked out from where the train is, on a grid of whole numbers exact to
//     four million km (see "Distance")
//   - the glass: rain streaks back along it while moving and beads when
//     still; it mists over slowly, and a wipe (left-drag) clears a stripe
//     that mists back over minutes. The carriage's reading lamp shows in the
//     glass, strongest in a tunnel
//
// Two passes, like koi's:
//   first    the simulation, and everything that can be worked out once
//            rather than per pixel: where the train is, the land's shapes
//            across the screen, the misted glass
//   second   draws the screen from that
//
// Every number worth tweaking is in SETTINGS, just below. neowall doesn't
// reload a terminal wallpaper's shader: restart it (nighttrain.vibe says how).

// ============================================================================
// SETTINGS
// ============================================================================

// --- colours
// The Kanagawa Wave colours this uses (copied from colors.glsl, which has the
// full palette: neowall has no #include).
const vec3 sumiInk0     = vec3(0.086, 0.086, 0.114);  // #16161D
const vec3 sumiInk1     = vec3(0.094, 0.094, 0.125);  // #181820
const vec3 sumiInk2     = vec3(0.102, 0.102, 0.133);  // #1a1a22
const vec3 sumiInk3     = vec3(0.122, 0.122, 0.157);  // #1F1F28
const vec3 sumiInk4     = vec3(0.165, 0.165, 0.216);  // #2A2A37
const vec3 winterBlue   = vec3(0.145, 0.145, 0.208);  // #252535
const vec3 fujiGray     = vec3(0.447, 0.443, 0.412);  // #727169
const vec3 katanaGray   = vec3(0.443, 0.486, 0.486);  // #717C7C
const vec3 oldWhite     = vec3(0.784, 0.753, 0.576);  // #C8C093
const vec3 fujiWhite    = vec3(0.863, 0.843, 0.729);  // #DCD7BA
const vec3 waveBlue1    = vec3(0.133, 0.196, 0.286);  // #223249
const vec3 waveBlue2    = vec3(0.176, 0.310, 0.404);  // #2D4F67
const vec3 dragonBlue   = vec3(0.396, 0.522, 0.580);  // #658594
const vec3 springBlue   = vec3(0.498, 0.706, 0.792);  // #7FB4CA
const vec3 lightBlue    = vec3(0.639, 0.831, 0.835);  // #A3D4D5
const vec3 springViolet1= vec3(0.576, 0.541, 0.663);  // #938AA9
const vec3 oniViolet    = vec3(0.584, 0.498, 0.722);  // #957FB8
const vec3 springViolet2= vec3(0.612, 0.671, 0.792);  // #9CABCA
const vec3 autumnRed    = vec3(0.765, 0.251, 0.263);  // #C34043
const vec3 samuraiRed   = vec3(0.910, 0.141, 0.141);  // #E82424
const vec3 boatYellow2  = vec3(0.753, 0.639, 0.431);  // #C0A36E
const vec3 autumnYellow = vec3(0.863, 0.647, 0.380);  // #DCA561
const vec3 carpYellow   = vec3(0.902, 0.765, 0.518);  // #E6C384
const vec3 roninYellow  = vec3(1.000, 0.620, 0.231);  // #FF9E3B
const vec3 surimiOrange = vec3(1.000, 0.627, 0.400);  // #FFA066
const vec3 winterGreen  = vec3(0.169, 0.200, 0.157);  // #2B3328
const vec3 autumnGreen  = vec3(0.463, 0.580, 0.416);  // #76946A
const vec3 waveAqua2    = vec3(0.478, 0.659, 0.624);  // #7AA89F

// --- the train
// smoothstep(lo, hi, x) turns lo..hi into 0..1, flat at both ends.
const vec2  CRUISE      = vec2(18.0, 34.0);   // m/s it cruises at: the computer idle .. flat out
const vec2  BUSY_RANGE  = vec2(0.20, 0.85);   // iCpuMax (the busiest thread) over which it speeds up
const float CPU_LAG     = 10.0;               // seconds the cpu reading takes to catch up, so the speed never twitches
const float A_MAX       = 0.4;                // m/s², the most it speeds up or slows down while cruising
const float A_BRAKE     = 0.7;                // m/s², braking for a station (826 m to stop from 34 m/s)
const float EASE        = 0.3;                // how fast the speed settles on the cruising speed (share a second)
const float MIN_DWELL   = 8.0;                // seconds stopped at a station before it may leave
const float TUNNEL_AHEAD= 150.0;              // metres ahead a tunnel you ask for (right-click) begins
const float CLEAR_OF    = 200.0;              // metres a station keeps clear of tunnels and bridges

// --- the view
const float HORIZON     = 0.40;   // how far up the screen the horizon is
const float EYE         = 3.0;    // metres your eye is above the ground outside (the nearer the land, the further below the horizon it lies)
// The land is five layers, 16, 64, 256, 1024 and 4096 m from the track. One
// screen height takes in as many metres of a layer as it is far away (a view
// of about 53 degrees), so the poles, 16 m off, show 16 m of line at a time.
// (The distances must stay 16 times powers of four: see "Distance".)
const float MOUNT_COL   = 0.30;   // how much the far mountains fade into the sky (more = hazier)
const float HILL_COL    = 0.16;   // the same for the hills

// --- the lineside, 16 m away
const float POLE_EVERY  = 64.0;   // metres between the poles (it must divide 1024)
const float POLE_H      = 8.5;    // how tall they are, in metres
const float POLE_W      = 0.32;   // and how thick
const vec3  WIRE_H      = vec3(8.1, 7.5, 6.9);   // the three wires' heights at the poles
const float WIRE_SAG    = 1.3;    // how far they sag between poles
const float BLUR        = 1.0;    // motion blur: how many frames' worth of movement it smears (1 = like a camera)

// --- stations
const float PLAT_BACK   = 180.0;  // metres of platform behind the stopping point
const float PLAT_FRONT  = 30.0;   // and in front of it
const float PLAT_TOP    = 0.18;   // how far up the screen the platform comes
const float LAMP_EVERY  = 25.0;   // metres between the platform lamps
const vec3  SIGN_BOX    = vec3(0.55, 0.42, 0.58);    // the sign: width, bottom, top (screen heights)

// --- the glass
const float FOG_TIME    = 180.0;  // seconds for clear glass to mist over, at the fastest (heavy rain)
const float FOG_LOOK    = 0.85;   // how milky fully misted glass looks
const float WIPE_R      = 0.03;   // how wide a wipe is, in screen heights (the radius)
const float REFLECT     = 1.0;    // how strongly the carriage's reading lamp shows in the glass
const bool  FRAME       = true;   // a thin dark window frame round the edges

// ============================================================================
// Everything below is how it works: tuning shouldn't need anything past here.
// ============================================================================

const float TAU = 6.28318531;

// Lighting maths only works on linear colour values, so hex colours are
// decoded (squared) before lighting and re-encoded (square root) at the end.
vec3 toLinear(vec3 c) { return c * c; }

// ----------------------------------------------------------------------------
// The program's header: row 0 of the terminal. Each cell's background and
// foreground colours carry three bytes apiece (PLAN.md section 4 has the
// table). Counts run 1..255; the shader acts when one changes.
const int H_BEAT = 0, H_SYNC = 1, H_STATION = 2, H_TUNNEL = 3, H_ENV = 4, H_WIPE = 5;
uvec3 cellBg(int i) { uint a = texelFetch(iTermCells, ivec2(i, 0), 0).a; return uvec3(a >> 24, (a >> 16) & 255u, (a >> 8) & 255u); }
uvec3 cellFg(int i) { uint b = texelFetch(iTermCells, ivec2(i, 0), 0).b; return uvec3(b >> 24, (b >> 16) & 255u, (b >> 8) & 255u); }
// Is nighttrain.py the one running? Its heartbeat cell carries "NT" (78, 84)
// and the protocol's version.
bool programRunning() {
    uvec3 bg = cellBg(H_BEAT), fg = cellFg(H_BEAT);
    return bg.g == 78u && bg.b == 84u && fg.r == 1u;
}

// ----------------------------------------------------------------------------
// Buffer A's layout
//
// Buffer A is a picture about 70% of the screen's size (neowall's choice),
// and this uses a few patches of it, all kept below 1000 texels each way:
//
//   row 0            the state (S_), and a few things worked out each frame
//                    for the drawing pass (D_): everything that's the same
//                    for every pixel is worked out once here, not 8 million
//                    times a frame
//   rows 2..4        the land across the screen, one texel per 4 px column
//   row 5            the sky's colour from the horizon up (256 texels: .a the
//                    stars' brightness, plus 2 if night is forced), then the
//                    land's colours (7, which Buffer A's own texels use)
//   rows 8..187      the misted glass, 320 x 180
//   rows 190..369    what that glass does to the view, 320 x 180
const int S_MARK   = 0;   // .a: 0.75 remembered and the program's running, 0.5 remembered but it isn't, 0 nothing yet
const int S_POS    = 1;   // where the train is (see "Distance")
const int S_VEL    = 2;   // speed (whole m/s, the rest), and what it's doing: 0 cruising, 1 pulling in, 2 stopped
const int S_STOP   = 3;   // where it's to stop (or stopped), like S_POS; .x -1 if nowhere
const int S_LAST   = 4;   // the station before that, still drawn while it's in view
const int S_SEEN   = 5;   // the counts last acted on: arrive, depart, tunnel, wipe
const int S_TUN0   = 6;   // the tunnel asked for: its start (.x -1 if none)...
const int S_TUN1   = 7;   // ...and its end
const int S_LINE   = 8;   // the line, the line to change to, and how long it's been stopped (whole s, the rest)
const int S_FLAGS  = 9;   // a departure waiting (1), how far into sleep (0..1), sync count seen, the kind of stop
const int S_WIPE   = 10;  // the last wipe: where (screen heights from the middle, from the bottom), seconds since
const int S_CLOCK  = 11;  // two steady clocks (coarse, fine each): blinking lights, the rain running down the glass
const int S_CPU    = 12;  // the cpu reading, smoothed (coarse, fine)
const int S_ENV    = 13;  // the weather, smoothed: rain, how fast the glass mists, wind, cloud (coarse parts)...
const int S_ENVLO  = 14;  // ...and the fine parts
const int D_MOTION = 16;  // speed m/s, motion blur (screen heights at the poles), the station's distance (whole m, the rest)
const int D_POLE   = 17;  // where the train is between poles (m), a level crossing (m, relative), a bridge's start and end (m, relative)
const int D_TUNNEL = 18;  // the nearest tunnel's start and end (m, relative), how far into it the window is (0..1)
const int D_SKY    = 19;  // how much it's day, dusk, how clearly the moon's seen, its phase (0 new, 0.5 full)
const int D_SKY2   = 20;  // the moon on the screen (x, y), and the train's metres past a pole (whole, the rest)
const int D_ENV    = 21;  // rain, how much it's running (1) rather than beading (0), misting rate, reflection strength
const int D_POS    = 22;  // (spare: things fixed to the land read S_POS, whose parts are all exact)
const int D_SIGN   = 23;  // which columns the sign's two lines of text span: main first, last, sub first, last (-1: none)
const int D_FEAT   = 24;  // the clocks as 0..1 turns: blinking, rain; how far into sleep; the moon's glow on water
const int D_PAL    = 25;  // 25..31: the colours of the mountains, hills, land 256 m off, its trees, land 64 m off, the lineside, the mist
const int S_COUNT  = 32;
const int COL_Y0   = 2;
const int NCOL     = 960;   // at most: fewer if Buffer A is narrower (a small screen)
const int SKY_Y    = 5;
const int SKY_W    = 256;
const int FOG_Y0   = 8;     // the misted glass: rows 8..187
const int GLASS_Y0 = 190;   // what the glass does to the view: rows 190..369
const int FOG_W    = 320;
const int FOG_H    = 180;
const int M_CRUISE = 0, M_APPROACH = 1, M_STOPPED = 2;

vec4 state(int i) { return texelFetch(iChannel0, ivec2(i, 0), 0); }
// how many land columns there are: 960, or as many as Buffer A is wide
int landColumns(float bufferWidth) { return min(NCOL, int(bufferWidth)); }

// neowall buffers hold half floats: about 3 significant digits. A number
// that has to change by tiny steps is kept as a coarse part in whole 1/128ths
// (which half floats hold exactly) plus the small leftover.
float coarse(float x) { return floor(x * 128.0 + 0.5) / 128.0; }
// ...and a number that grows a little every frame, counted in turns (so it
// wraps at 1). Straight from orbit3d.
vec2 accumulate(vec2 hl, float step) {
    float lo = hl.y + step;
    float carry = floor(lo * 256.0) / 256.0;
    return vec2(fract(hl.x + carry), lo - carry);
}
// a soft glow, 1 at its middle, falling off as 1/(1 + (d/r)^2)
float glowAt(vec2 d, float r) { return 1.0 / (1.0 + dot(d, d) / (r * r)); }
// Highlights roll off smoothly instead of clipping (as in orbit3d and koi).
vec3 tonemap(vec3 c) {
    const float K = 0.6;
    vec3 over = max(c - K, 0.0);
    return min(c, vec3(K)) + over / (1.0 + over / (1.0 - K));
}
// a soft wave 0..1..0 once a unit, made without sine (which this chip is slow at)
float tri(float x) { float t = abs(fract(x) - 0.5) * 2.0; return t * t * (3.0 - 2.0 * t); }
// sin and cos too, without sine: a parabola, refined. Good to ~0.1%.
vec2 sinCos(float x) {
    vec2 a = vec2(x, x + 1.5707963);
    a -= TAU * floor(a / TAU + 0.5);
    vec2 y = 1.2732395 * a - 0.4052847 * a * abs(a);
    return 0.225 * (y * abs(y) - y) + y;
}

// ----------------------------------------------------------------------------
// Distance
//
// A journey runs for days, so the train can be millions of metres down the
// line, and a float can't hold that finely: at 3.5 million m it counts in
// quarter metres, and the poles would jitter. So the big part is kept as a
// whole number, and only small numbers are ever floats: the line is cut into
// 1024 m tiles, and a position is a tile plus metres into it.
//
// In Buffer A even that is stored in half floats, which hold whole numbers
// exactly only up to 2048: so S_POS is (tile / 2048, tile % 2048, whole
// metres, the rest). All four fit exactly, up to 4 million km.
struct Pos { uint tile; float off; };
Pos  posFrom(vec4 s) { return Pos(uint(s.x) * 2048u + uint(s.y), s.z + s.w); }
vec4 posTexel(Pos p) { float m = floor(p.off); return vec4(float(p.tile >> 11u), float(p.tile & 2047u), m, p.off - m); }
Pos moved(Pos p, float d) {
    float o = p.off + d, t = floor(o / 1024.0);
    return Pos(uint(int(p.tile) + int(t)), o - t * 1024.0);
}
// how far a is past b, in metres (for nearby points)
float metresFrom(Pos a, Pos b) { return float(int(a.tile) - int(b.tile)) * 1024.0 + (a.off - b.off); }

// The land's shapes come from noise on a grid of whole numbers, which never
// runs out of precision. A layer d metres from the track is measured in
// "layer metres" of d/16 metres each, so on every layer a screen height is
// 16 layer metres wide. d/16 is a power of four (1, 4, 16, 64, 256), so a
// spot's layer position is a whole number (A) plus a small fraction (a),
// exactly, and grid cells can be any power of two of layer metres.
uint pcg(uint x) {
    uint h = x * 747796405u + 2891336453u;
    h = ((h >> ((h >> 28u) + 4u)) ^ h) * 277803737u;
    return (h >> 22u) ^ h;
}
float h01(uint x) { return float(pcg(x) >> 8u) * (1.0 / 16777216.0); }   // 0..1
struct LPos { uint A; float a; };
// a spot on the layer 16 * 2^shift metres from the track (shift 0, 2, 4, 6 or 8)
LPos layerPos(Pos w, int shift) {
    float f = w.off / exp2(float(shift));
    float fl = floor(f);
    return LPos(w.tile * (1024u >> uint(shift)) + uint(fl), f - fl);
}
// smooth value noise 0..1 at a layer position, cells 2^s layer metres wide
float lnoise(LPos p, int s, uint seed) {
    uint idx; float w;
    if (s >= 0) {
        uint m = (1u << uint(s)) - 1u;
        idx = p.A >> uint(s);
        w = (float(p.A & m) + p.a) / float(m + 1u);
    } else {
        float q = p.a * exp2(float(-s));
        idx = (p.A << uint(-s)) + uint(q);
        w = fract(q);
    }
    float a = h01(idx ^ seed), b = h01((idx + 1u) ^ seed);
    return mix(a, b, w * w * (3.0 - 2.0 * w));
}
// a few octaves of it, the first with cells 2^s wide, each after half as wide and half as strong
float lfbm(LPos p, int s, int octaves, uint seed) {
    float sum = 0.0, amp = 0.5, norm = 0.0;
    for (int o = 0; o < octaves; o++) {
        sum += amp * lnoise(p, s - o, seed + uint(o) * 0x9E3779B9u);
        norm += amp;
        amp *= 0.5;
    }
    return sum / norm;
}

// ----------------------------------------------------------------------------
// The country
//
// The line runs through regions of 8 tiles (about 8 km) of one biome each:
// forest, lakes, open plains, hills or coast. Which, is a throw of the dice
// weighted by the line (a line is its own mix). Each tile then gets a kind,
// weighted by its biome: plain country, forest, a lake, a town, the sea, a
// bridge, a tunnel or a level crossing. Tunnels and bridges take the middle
// half of their tile; a crossing sits somewhere in its tile.
const int B_FOREST = 0, B_LAKES = 1, B_PLAINS = 2, B_HILLS = 3, B_COAST = 4;
const int K_PLAIN = 0, K_FOREST = 1, K_LAKE = 2, K_TOWN = 3, K_SEA = 4, K_BRIDGE = 5, K_TUNNEL = 6, K_CROSSING = 7;
// how often each biome comes up on each line: forest, lakes, plains, hills, coast
const float BIOME_W[20] = float[20](
    2.0, 1.5, 2.0, 1.5, 1.0,     // 0 mixed country
    1.0, 0.5, 1.0, 0.7, 4.0,     // 1 the coast
    2.0, 1.5, 0.5, 4.0, 0.0,     // 2 the hills
    1.0, 1.0, 5.0, 0.3, 0.3);    // 3 the plains
// how often each kind of tile comes up in each biome:
//   plain, forest, lake, town, sea, bridge, tunnel, crossing
const float KIND_W[40] = float[40](
    1.0, 5.0, 0.5, 0.7, 0.0, 0.6, 0.4, 0.8,    // forest
    1.0, 2.0, 3.0, 0.6, 0.0, 1.0, 0.0, 0.5,    // lakes
    5.0, 0.7, 0.3, 1.2, 0.0, 0.5, 0.0, 1.5,    // plains
    1.5, 2.5, 0.7, 0.5, 0.0, 1.2, 1.5, 0.4,    // hills
    1.0, 0.3, 0.0, 1.0, 4.0, 0.6, 0.4, 0.5);   // coast
// what each biome's land is like: mountains on the skyline (m), hills (m),
// the nearer ground's rise and fall (m), how wooded, how many wind turbines
const float B_MOUNT[5]   = float[5](300.0, 250.0, 70.0, 750.0, 140.0);
const float B_HILL[5]    = float[5](55.0, 45.0, 12.0, 140.0, 30.0);
const float B_GROUND[5]  = float[5](10.0, 8.0, 4.0, 22.0, 6.0);
const float B_WOODS[5]   = float[5](0.85, 0.5, 0.15, 0.55, 0.2);
const float B_TURBINE[5] = float[5](0.0, 0.0, 0.6, 0.25, 0.5);

int biomeOf(uint region, int line) {
    float r = h01(region * 2654435761u ^ uint(line + 1) * 40503u);
    float total = 0.0;
    for (int b = 0; b < 5; b++) total += BIOME_W[line * 5 + b];
    r *= total;
    for (int b = 0; b < 5; b++) { r -= BIOME_W[line * 5 + b]; if (r < 0.0) return b; }
    return 0;
}
int tileKind(uint tile, int line) {
    int b = biomeOf(tile >> 3u, line);
    float r = h01(tile * 3266489917u ^ uint(line + 7) * 668265263u);
    float total = 0.0;
    for (int k = 0; k < 8; k++) total += KIND_W[b * 8 + k];
    r *= total;
    for (int k = 0; k < 8; k++) { r -= KIND_W[b * 8 + k]; if (r < 0.0) return k; }
    return 0;
}
// A biome's numbers at a spot, blended into the next region's over the last
// tile of each region, so the land never changes at a stroke.
struct Biome { float mount, hill, ground, woods, turbine, sea; };
Biome biomeNumbers(int b) {
    return Biome(B_MOUNT[b], B_HILL[b], B_GROUND[b], B_WOODS[b], B_TURBINE[b], b == B_COAST ? 1.0 : 0.0);
}
Biome biomeAt(Pos w, int line) {
    uint region = w.tile >> 3u;
    Biome a = biomeNumbers(biomeOf(region, line));
    float t = float(w.tile & 7u) * 1024.0 + w.off;
    float k = smoothstep(7168.0, 8192.0, t);
    if (k > 0.0) {
        Biome b = biomeNumbers(biomeOf(region + 1u, line));
        a = Biome(mix(a.mount, b.mount, k), mix(a.hill, b.hill, k), mix(a.ground, b.ground, k),
                  mix(a.woods, b.woods, k), mix(a.turbine, b.turbine, k), mix(a.sea, b.sea, k));
    }
    return a;
}
// where in a crossing tile its road is (metres into the tile)
float crossingAt(uint tile) { return 300.0 + 424.0 * h01(tile ^ 0x51ED270Bu); }

// ----------------------------------------------------------------------------
// The sky: by night ink-dark overhead down to a deep blue at the horizon; at
// dusk and dawn violet over a thin band of the sun's last (or first) light;
// by day an overcast grey-blue. Cloud flattens it all toward grey.
vec3 skyAt(float v, vec4 DS, float cloud) {
    float t = clamp((v - HORIZON) / (1.0 - HORIZON), 0.0, 1.0), st = sqrt(t);
    vec3 night = mix(toLinear(waveBlue1) * 0.95, toLinear(sumiInk0) * 0.9, st);
    vec3 dusk  = mix(toLinear(surimiOrange) * 0.50, toLinear(oniViolet) * 0.40, smoothstep(0.0, 0.12, t));
    dusk = mix(dusk, toLinear(winterBlue) * 0.9, smoothstep(0.12, 0.8, t));
    dusk = mix(toLinear(autumnYellow) * 0.55, dusk, smoothstep(0.0, 0.03, t));
    vec3 day   = mix(toLinear(springViolet2) * 0.85, toLinear(dragonBlue) * 0.8, st);
    vec3 c = mix(mix(night, dusk, DS.y), day, DS.x);
    vec3 grey = mix(toLinear(sumiInk3) * 1.1, toLinear(katanaGray) * 0.9, DS.x);
    return mix(c, grey, cloud * 0.55 * (1.0 - 0.5 * t));
}

// ----------------------------------------------------------------------------
// The layers' colours: each nearer layer darker and less hazed into the sky.
// By night they're silhouettes in the Kanagawa inks and blues; by day a
// dull green-grey under the overcast.
struct Palette { vec3 far, hills, mid, trees, near, fore, horizon, mist; };
Palette paletteFor(vec4 DS, vec4 DS2, float cloud) {
    Palette c;
    float day = DS.x, dusk = DS.y, moon = DS.z * (0.25 + 0.75 * tri(DS.w));
    c.horizon = skyAt(HORIZON + 0.01, DS, cloud);
    c.far   = mix(mix(toLinear(waveBlue1) * 0.28, toLinear(dragonBlue) * 0.55, day), c.horizon, MOUNT_COL);
    c.far   = mix(c.far, toLinear(oniViolet) * 0.2, dusk * 0.35);
    c.hills = mix(mix(toLinear(sumiInk2) * 0.95, toLinear(winterGreen) * 1.3, day), c.horizon, HILL_COL);
    c.mid   = mix(toLinear(sumiInk2) * 0.95, toLinear(autumnGreen) * 0.30, day);
    c.trees = mix(toLinear(sumiInk1) * 0.9, toLinear(winterGreen) * 0.95, day);
    c.near  = mix(toLinear(sumiInk3) * 0.95, toLinear(winterGreen) * 0.75, day);
    c.fore  = mix(toLinear(sumiInk0) * 0.45, toLinear(sumiInk2) * 0.8, day);
    // moonlight lifts the far layers a little
    c.far += toLinear(dragonBlue) * 0.025 * moon;
    c.hills += toLinear(dragonBlue) * 0.012 * moon;
    c.near += toLinear(waveBlue2) * 0.03 * moon;
    c.mist = toLinear(springViolet1) * mix(0.09, 0.2, day);
    return c;
}

// ----------------------------------------------------------------------------
// The train
//
// Everything the state texels need, worked out from last frame's state and
// the program's header. Each state texel runs all of it and keeps its part:
// there are only a dozen of them, so that's cheaper than being clever.
struct Sim {
    Pos pos; float v; int mode;
    Pos stop; bool hasStop;
    Pos last; bool hasLast;
    vec4 seen;
    Pos tun0, tun1; bool hasTun;
    float line, pending, stopped;
    float departing, sleep, syncSeen, kind;
};

float smoothedCpu() { vec4 c = state(S_CPU); return c.x + c.y; }
float cruiseSpeed() { return mix(CRUISE.x, CRUISE.y, smoothstep(BUSY_RANGE.x, BUSY_RANGE.y, smoothedCpu())); }

// A stop that would fall in a tunnel or on a bridge, or too near one, moves
// on to the first clear stretch past it.
Pos clearStop(Pos p, Sim s) {
    for (int i = 0; i < 3; i++) {
        if (s.hasTun && metresFrom(p, s.tun0) > -CLEAR_OF && metresFrom(p, s.tun1) < CLEAR_OF)
            p = moved(s.tun1, CLEAR_OF);
        int k = tileKind(p.tile, int(s.line));
        if ((k == K_BRIDGE || k == K_TUNNEL) && p.off > 256.0 - CLEAR_OF && p.off < 768.0 + CLEAR_OF)
            p = Pos(p.tile, 768.0 + CLEAR_OF);
    }
    return p;
}

Sim simulate(bool fresh) {
    Sim s;
    uvec3 st = cellBg(H_STATION), sf = cellFg(H_SYNC), sb = cellBg(H_SYNC), tb = cellBg(H_TUNNEL);
    uint departs = cellFg(H_STATION).r, wipes = cellFg(H_WIPE).r;
    if (fresh) {
        // A new start (neowall has just started, so Buffer A is empty): the
        // journey carries on from where the program last saved it. Every
        // command already in the header counts as done, so none replays.
        s.pos = Pos((sb.r << 16u) | (sb.g << 8u) | sb.b, float((sf.r << 8u) | sf.g));
        s.v = cruiseSpeed(); s.mode = M_CRUISE;
        s.hasStop = s.hasLast = s.hasTun = false;
        s.stop = s.last = s.tun0 = s.tun1 = s.pos;
        s.seen = vec4(float(st.r), float(departs), float(tb.r), float(wipes));
        s.line = s.pending = float(cellFg(H_ENV).g & 3u);
        s.stopped = 0.0; s.departing = 0.0; s.sleep = 0.0; s.syncSeen = float(sf.b); s.kind = 0.0;
        return s;
    }
    vec4 V = state(S_VEL), L = state(S_LINE), F = state(S_FLAGS), P;
    s.pos = posFrom(state(S_POS)); s.v = V.x + V.y; s.mode = int(V.z + 0.5);
    P = state(S_STOP); s.hasStop = P.x >= 0.0; s.stop = posFrom(max(P, 0.0));
    P = state(S_LAST); s.hasLast = P.x >= 0.0; s.last = posFrom(max(P, 0.0));
    P = state(S_TUN0); s.hasTun = P.x >= 0.0; s.tun0 = posFrom(max(P, 0.0)); s.tun1 = posFrom(max(state(S_TUN1), 0.0));
    s.seen = state(S_SEEN);
    s.line = L.x; s.pending = L.y; s.stopped = L.z + L.w;
    s.departing = F.x; s.sleep = F.y; s.syncSeen = F.z; s.kind = F.w;
    float dt = min(iTimeDelta, 0.05);    // after a pause neowall says 0.25 s; the train doesn't leap

    // ---- the program's commands
    // A resync (a debugging key): jump to where the program thinks we are.
    if (float(sf.b) != s.syncSeen) {
        s.syncSeen = float(sf.b);
        s.pos = Pos((sb.r << 16u) | (sb.g << 8u) | sb.b, float((sf.r << 8u) | sf.g));
        s.mode = M_CRUISE; s.hasStop = false;
    }
    // ARRIVE: stop so many metres ahead. At a station it waits until it's
    // left; it also means "time to go" (if the program restarted, it won't
    // send the departure it owes).
    if (float(st.r) != s.seen.x) {
        if (st.r == 0u) {
            s.seen.x = 0.0;                                    // the program restarted
            if (s.mode == M_STOPPED) s.departing = 1.0;
        } else if (s.mode == M_STOPPED) {
            s.departing = 1.0;
        } else {
            s.seen.x = float(st.r);
            if (s.hasStop) { s.last = s.stop; s.hasLast = true; }
            s.stop = clearStop(moved(s.pos, float(st.g) * 8.0), s);
            s.hasStop = true; s.mode = M_APPROACH; s.kind = float(st.b);
        }
    }
    // DEPART: leave, once it's been stopped long enough (an early one waits)
    if (float(departs) != s.seen.y) {
        s.seen.y = float(departs);
        if (departs != 0u) s.departing = 1.0;
    }
    // TUNNEL: one starts a little ahead (after the station, if it's pulling
    // in to one), and the line changes in its middle, where nobody can see.
    if (float(tb.r) != s.seen.z) {
        s.seen.z = float(tb.r);
        if (tb.r != 0u) {
            float len = float(tb.g) * 16.0;
            Pos a = moved(s.pos, TUNNEL_AHEAD);
            if (s.hasStop && s.mode != M_CRUISE) {
                float d = metresFrom(a, s.stop);
                if (d > -PLAT_BACK - len - CLEAR_OF && d < CLEAR_OF) a = moved(s.stop, CLEAR_OF + PLAT_FRONT);
            }
            s.tun0 = a; s.tun1 = moved(a, len); s.hasTun = true;
            s.pending = float(tb.b & 3u);
        }
    }
    if (s.hasTun && s.line != s.pending && metresFrom(s.pos, s.tun0) > 0.5 * metresFrom(s.tun1, s.tun0))
        s.line = s.pending;
    s.seen.w = float(wipes);
    // sleeping soon: ease the rain and the lights to rest, so the last frame
    // (which stays on the screen) looks meant
    s.sleep = clamp(s.sleep + ((cellFg(H_BEAT).g & 1u) != 0u ? dt : -dt) / 3.0, 0.0, 1.0);

    // ---- moving
    float vc = cruiseSpeed();
    if (s.mode == M_CRUISE) {
        s.v += clamp((vc - s.v) * EASE, -A_MAX, A_MAX) * dt;
    } else if (s.mode == M_APPROACH) {
        // the fastest it can go and still stop in time, braking at A_BRAKE
        float left = metresFrom(s.stop, s.pos);
        float target = min(vc, sqrt(2.0 * A_BRAKE * max(left, 0.0)));
        s.v = s.v > target ? max(target, s.v - 1.2 * A_BRAKE * dt) : min(target, s.v + A_MAX * dt);
    }
    s.v = max(s.v, 0.0);
    float ahead = s.v * dt;
    if (s.mode == M_APPROACH) {
        float left = metresFrom(s.stop, s.pos);
        if (ahead >= left || (left < 0.5 && s.v < 0.3)) {
            s.pos = s.stop; s.v = 0.0; s.mode = M_STOPPED; s.stopped = 0.0; ahead = 0.0;   // exactly there
        }
    }
    if (ahead > 0.0) s.pos = moved(s.pos, ahead);
    if (s.mode == M_STOPPED) {
        s.stopped = min(s.stopped + dt, 1000.0);
        if (s.departing > 0.5 && s.stopped >= MIN_DWELL) { s.mode = M_CRUISE; s.departing = 0.0; }
    }
    // a station long passed isn't drawn any more
    if (s.hasLast && metresFrom(s.pos, s.last) > 1000.0) s.hasLast = false;
    return s;
}

vec4 posOrNone(Pos p, bool has) { return has ? posTexel(p) : vec4(-1.0); }

// ----------------------------------------------------------------------------
// What the drawing pass needs about the line near the train, from last
// frame's state (so everything drawn agrees with everything else).

// the tunnel nearest the train: its start and end, in metres from it
vec2 nearestTunnel(Pos pos, int line) {
    vec2 best = vec2(1e4);
    vec4 t0 = state(S_TUN0);
    if (t0.x >= 0.0) best = vec2(metresFrom(posFrom(t0), pos), metresFrom(posFrom(state(S_TUN1)), pos));
    for (int i = -1; i <= 1; i++) {
        uint t = uint(int(pos.tile) + i);
        if (tileKind(t, line) != K_TUNNEL) continue;
        float s = float(i) * 1024.0 - pos.off + 256.0;
        vec2 c = vec2(s, s + 512.0);
        if (max(c.x, -c.y) < max(best.x, -best.y)) best = c;
    }
    return best;
}
// the bridge nearest the train (start, end in m), or far away
vec2 nearestBridge(Pos pos, int line) {
    vec2 best = vec2(1e4);
    for (int i = -1; i <= 1; i++) {
        if (tileKind(uint(int(pos.tile) + i), line) != K_BRIDGE) continue;
        float s = float(i) * 1024.0 - pos.off + 256.0;
        if (max(s, -s - 512.0) < max(best.x, -best.y)) best = vec2(s, s + 512.0);
    }
    return best;
}
float nearestCrossing(Pos pos, int line) {
    float best = 1e4;
    for (int i = -1; i <= 1; i++) {
        uint t = uint(int(pos.tile) + i);
        if (tileKind(t, line) != K_CROSSING) continue;
        float c = float(i) * 1024.0 - pos.off + crossingAt(t);
        if (abs(c) < abs(best)) best = c;
    }
    return best;
}

// Days since 1970 for a date (Howard Hinnant's algorithm), for the moon.
int daysFromCivil(int y, int m, int d) {
    y -= m <= 2 ? 1 : 0;
    int era = (y >= 0 ? y : y - 399) / 400;
    int yoe = y - era * 400;
    int doy = (153 * (m + (m > 2 ? -3 : 9)) + 2) / 5 + d - 1;
    int doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    return era * 146097 + doe - 719468;
}

// How much it's day and dusk, how many stars, where the moon is and its
// phase (D_SKY, D_SKY2); returns how much light the moon gives.
float skyNumbers(out vec4 DS, out vec4 DS2) {
    bool night = (cellFg(H_BEAT).g & 2u) != 0u;
    float day  = night ? 0.0 : smoothstep(0.06, 0.40, iSun);
    float dusk = night ? 0.0 : smoothstep(0.0, 0.08, iSun) * (1.0 - smoothstep(0.10, 0.36, iSun));
    float stars = night ? 1.0 : 1.0 - smoothstep(0.0, 0.14, iSun);
    // The moon: its phase from the date (days since a known new moon, in
    // lunar months), and where it is from the time: it's highest when it's
    // opposite the sun, so at midnight when it's full.
    float days = float(daysFromCivil(int(iDate.x), int(iDate.y), int(iDate.z))) + iDate.w / 86400.0;
    float phase = fract((days - 10962.7597) / 29.530589);
    float hourAngle = fract(iTimeOfDay - 0.5 - phase + 1.5) * 24.0 - 12.0;   // hours from its highest
    float up = 1.0 - abs(hourAngle) / 6.5;
    vec2 at = vec2(hourAngle / 6.5 * 0.75, HORIZON + 0.03 + 0.45 * max(up, 0.0) * (2.0 - max(up, 0.0)));
    float cloud = (state(S_ENV) + state(S_ENVLO)).w;
    float vis = (1.0 - day) * smoothstep(0.0, 0.1, up) * (1.0 - 0.8 * cloud);   // how clearly it's seen
    float lit = vis * (0.25 + 0.75 * tri(phase));                              // the light it gives
    DS = vec4(day, dusk, vis, phase);
    DS2 = vec4(at, stars * (1.0 - 0.8 * cloud), 0.0);     // .z: how bright the stars are (the sky row carries it on)
    return lit;
}

// the station in view (or the last one, while it's still near): metres from the train
float stationRel(Pos pos) {
    float st = 1e4;
    vec4 P = state(S_STOP);
    if (P.x >= 0.0) st = metresFrom(posFrom(P), pos);
    P = state(S_LAST);
    if (P.x >= 0.0) { float l = metresFrom(posFrom(P), pos); if (abs(l) < abs(st)) st = l; }
    return st;
}

vec4 drawTexel(int i) {
    Pos pos = posFrom(state(S_POS));
    vec4 V = state(S_VEL);
    float v = V.x + V.y;
    int line = int(state(S_LINE).x + 0.5);
    if (i == D_MOTION || i == D_TUNNEL) {
        vec2 tun = nearestTunnel(pos, line);
        if (i == D_TUNNEL) return vec4(tun, smoothstep(-6.0, 6.0, -tun.x) * smoothstep(-6.0, 6.0, tun.y), 0.0);
        // the station's distance, as whole metres and the fraction: its far
        // end shows when it's ~180 m off, where a half float steps 12 cm
        float st = clamp(stationRel(pos), -1e4, 1e4), sw = floor(st);
        float shutter = BLUR * clamp(iTimeDelta, 1.0 / 60.0, 1.0 / 20.0);
        return vec4(v, v * shutter / 16.0, sw, st - sw);
    }
    if (i == D_POLE) {
        vec2 br = nearestBridge(pos, line);
        return vec4(mod(pos.off, POLE_EVERY), nearestCrossing(pos, line), br);
    }
    if (i == D_SKY || i == D_SKY2 || i == D_FEAT || (i >= D_PAL && i < D_PAL + 7)) {
        vec4 DS, DS2;
        float lit = skyNumbers(DS, DS2);
        if (i == D_SKY) return DS;
        if (i == D_SKY2) { float m = mod(pos.off, POLE_EVERY); return vec4(DS2.xy, floor(m), m - floor(m)); }
        if (i == D_FEAT) { vec4 C = state(S_CLOCK); return vec4(C.x + C.y, C.z + C.w, state(S_FLAGS).y, lit); }
        Palette pal = paletteFor(DS, DS2, (state(S_ENV) + state(S_ENVLO)).w);
        int k = i - D_PAL;
        return vec4(k == 0 ? pal.far : k == 1 ? pal.hills : k == 2 ? pal.mid : k == 3 ? pal.trees :
                    k == 4 ? pal.near : k == 5 ? pal.fore : pal.mist, 0.0);
    }
    if (i == D_ENV) {
        vec4 E = state(S_ENV) + state(S_ENVLO);
        float sleep = state(S_FLAGS).y;
        float running = smoothstep(0.5, 6.0, v) * (1.0 - sleep);
        float day = smoothstep(0.06, 0.40, iSun) * ((cellFg(H_BEAT).g & 2u) != 0u ? 0.0 : 1.0);
        vec2 t = nearestTunnel(pos, line);
        float tun = smoothstep(-6.0, 6.0, -t.x) * smoothstep(-6.0, 6.0, t.y);
        return vec4(E.x, running, E.y, REFLECT * mix(1.0, 0.12, day * (1.0 - tun)));
    }
    if (i == D_SIGN) {
        // which columns of the sign rows have letters in them
        vec4 span = vec4(-1.0);
        for (int c = 0; c < 24; c++) {
            if ((texelFetch(iTermCells, ivec2(c, 1), 0).r & 1u) != 0u) { if (span.x < 0.0) span.x = float(c); span.y = float(c); }
            if ((texelFetch(iTermCells, ivec2(c, 2), 0).r & 1u) != 0u) { if (span.z < 0.0) span.z = float(c); span.w = float(c); }
        }
        return span;
    }
    return vec4(0.0);
}

// A wipe's cell, as a spot on the glass (screen heights from the middle,
// from the bottom). Buffer A has the screen's shape, so its own size will do.
vec2 wipePoint(uvec3 wb) {
    float x = float(wb.r | ((wb.b & 15u) << 8u)), y = float(wb.g | ((wb.b >> 4u) << 8u));
    float hw = 0.5 * iResolution.x / iResolution.y;
    return vec2(((x + 0.5) / iTermInfo.x - 0.5) * 2.0 * hw, 1.0 - (y + 0.5) / iTermInfo.y);
}

vec4 stateTexel(int i, vec4 prev, bool fresh, bool running) {
    // .x counts the frames since it started (to 8): the drawing pass waits
    // for the second, when the land has been worked out from a real position
    if (i == S_MARK) return vec4(running ? min(fresh ? 0.0 : prev.x + 1.0, 8.0) : prev.x, 0.0, 0.0, running ? 0.75 : (fresh ? 0.0 : 0.5));
    if (i >= D_MOTION) return drawTexel(i);
    if (!running) return fresh ? vec4(0.0) : prev;      // the program isn't there: hold everything as it is
    float dt = min(iTimeDelta, 0.05);
    if (i == S_CPU) {
        float c = fresh ? iCpuMax : prev.x + prev.y;
        c += (iCpuMax - c) * min(dt / CPU_LAG, 1.0);
        return vec4(coarse(c), c - coarse(c), 0.0, 0.0);
    }
    if (i == S_ENV || i == S_ENVLO) {
        // the weather the program asks for, eased into over half a minute
        uvec3 eb = cellBg(H_ENV);
        vec4 target = vec4(vec3(eb) / 255.0, float(cellFg(H_ENV).r) / 255.0);
        vec4 e = fresh ? target : state(S_ENV) + state(S_ENVLO);
        e += clamp(target - e, -dt / 30.0, dt / 30.0);
        vec4 c = floor(e * 128.0 + 0.5) / 128.0;
        return i == S_ENV ? c : e - c;
    }
    if (i == S_CLOCK) {
        // blinking lights: a turn every 2 s. The rain on the glass: a turn is
        // 256 of its grid cells, and it runs faster the faster the train goes
        vec4 V = state(S_VEL);
        float v = V.x + V.y, sleep = state(S_FLAGS).y;
        vec2 blink = accumulate(prev.xy, dt * 0.5 * (1.0 - sleep));
        vec2 rain = accumulate(prev.zw, dt * (0.4 + 0.12 * v) / 256.0 * (1.0 - sleep));
        return fresh ? vec4(0.0) : vec4(blink, rain);
    }
    if (i == S_WIPE) {
        // where the last wipe was, and how long ago: the glass texels draw a
        // stripe from there to the next one if it comes quickly (a drag)
        uvec3 wb = cellBg(H_WIPE);
        vec2 at = wipePoint(wb);
        if (!fresh && float(cellFg(H_WIPE).r) != state(S_SEEN).w) return vec4(at, 0.0, 0.0);
        return fresh ? vec4(at, 99.0, 0.0) : vec4(prev.xy, min(prev.z + dt, 99.0), 0.0);
    }
    Sim s = simulate(fresh);
    if (i == S_POS)   return posTexel(s.pos);
    if (i == S_VEL)   { float vi = floor(s.v); return vec4(vi, s.v - vi, float(s.mode), 0.0); }
    if (i == S_STOP)  return posOrNone(s.stop, s.hasStop);
    if (i == S_LAST)  return posOrNone(s.last, s.hasLast);
    if (i == S_SEEN)  return s.seen;
    if (i == S_TUN0)  return posOrNone(s.tun0, s.hasTun);
    if (i == S_TUN1)  return posOrNone(s.tun1, s.hasTun);
    if (i == S_LINE)  { float w = floor(s.stopped); return vec4(s.line, s.pending, w, s.stopped - w); }
    if (i == S_FLAGS) return vec4(s.departing, s.sleep, s.syncSeen, s.kind);
    return prev;
}

// ----------------------------------------------------------------------------
// The land across the screen
//
// Rows 2..4 hold, for 960 columns across the screen (4 px each on a 4K
// screen), everything about the land that doesn't need a pixel's precision:
// the skyline of each layer, trees, water, roofs, wind turbines. The drawing
// pass reads it smoothly between columns. Worked out from last frame's
// position, like the D_ texels, so it all agrees.
//
//   row 2   skylines: mountains 4 km off, hills 1 km, the land 256 m off
//           (the highest of its ground, trees and roofs), the land 64 m off
//           (screen heights from the bottom); read smoothly between columns
//   row 3   the land 256 m off: water (the level it mirrors; or -1 none,
//           -2 none and the fence 64 m off runs here), roofs (-1: none);
//           flags for what else is in the column, and the train's metres
//           past a pole (see columnTexel). Read a column at a time
//   row 4   the nearest wind turbine: how far across (screen heights), its
//           hub's height, which way its blades are turned, how long they are
//           (0: none)

// the ground's height on the screen, d metres off: the further, the nearer the horizon
float groundV(float d) { return HORIZON - EYE / d; }

// the kinds of the tiles either side of a spot, and how far into its own it is
struct Kinds { int before, here, after; float off; };
Kinds kindsAt(Pos w, int line) { return Kinds(tileKind(w.tile - 1u, line), tileKind(w.tile, line), tileKind(w.tile + 1u, line), w.off); }
// how much a spot belongs to tiles of a kind: 0 or 1, blended over `edge`
// metres either side of a tile's ends
float share(Kinds k, int kind, float edge) {
    float a = k.here == kind ? 1.0 : 0.0;
    if (k.off < edge) a = mix(k.before == kind ? 1.0 : 0.0, a, smoothstep(-edge, edge, k.off));
    else if (k.off > 1024.0 - edge) a = mix(a, k.after == kind ? 1.0 : 0.0, smoothstep(1024.0 - edge, 1024.0 + edge, k.off));
    return a;
}
// A tunnel goes into a hill: the land rises over the last 350 m before it
// and falls over 350 m after. `s`, `e`: the tunnel's ends, metres from the spot.
float hillOver(float s, float e) { return smoothstep(350.0, 20.0, s) * smoothstep(-350.0, -20.0, e); }
float tunnelHill(Kinds k, float rel, vec2 asked) {
    float h = hillOver(asked.x - rel, asked.y - rel);
    if (k.here == K_TUNNEL) h = max(h, hillOver(256.0 - k.off, 768.0 - k.off));
    if (k.before == K_TUNNEL) h = max(h, hillOver(-768.0 - k.off, -256.0 - k.off));
    if (k.after == K_TUNNEL) h = max(h, hillOver(1280.0 - k.off, 1792.0 - k.off));
    return h;
}
// a bridge crosses a valley: the ground drops away under its middle
float valley(Kinds k) {
    float v = k.here == K_BRIDGE ? smoothstep(200.0, 340.0, k.off) * smoothstep(200.0, 340.0, 1024.0 - k.off) : 0.0;
    return v * v * (3.0 - 2.0 * v);
}

// The land 256 m off at a column: its ground, the tops of its trees, water
// (the level it mirrors, or -1), roofs (-1: none).
vec4 midLand(Pos pos, float xs, int line, uint seed, vec2 asked) {
    Pos w = moved(pos, xs * 256.0);
    Biome b = biomeAt(w, line);
    Kinds k = kindsAt(w, line);
    float g = groundV(256.0);
    float n = lfbm(layerPos(w, 4), 2, 3, seed ^ 33u);
    // (in a bridge's valley the far side stays at the land's height: only
    // the river, below, lies low)
    float ground = g + (b.ground * n * (1.0 - share(k, K_SEA, 150.0)) + 70.0 * tunnelHill(k, xs * 256.0, asked)) / 256.0;
    // water: a lake (to its far shore, 1 km off), the sea (to the
    // horizon), or the river under a bridge
    float lake = k.here == K_LAKE ? smoothstep(80.0, 170.0, k.off) * smoothstep(80.0, 170.0, 1024.0 - k.off) : 0.0;
    float sea = share(k, K_SEA, 150.0);
    float river = k.here == K_BRIDGE ? 1.0 - smoothstep(30.0, 70.0, abs(k.off - 512.0)) : 0.0;
    float water = -1.0;
    if (sea > 0.5) water = groundV(4096.0);
    else if (lake > 0.5) water = groundV(1024.0);
    else if (river > 0.5) water = g - 22.0 * valley(k) / 256.0 + 0.001;
    // trees: one to each 8 m, if the dice say so, a round crown or a
    // pointed one, 9..22 m tall
    float woods = b.woods * mix(1.0, 1.5, share(k, K_FOREST, 120.0)) * mix(1.0, 0.25, share(k, K_PLAIN, 120.0))
            * (1.0 - share(k, K_TOWN, 80.0)) * (1.0 - sea) * (1.0 - lake) * (1.0 - river);
    float canopy = ground;
    float cell = w.off / 8.0, ci = floor(cell);
    for (int j = -1; j <= 1; j++) {
        uint id = w.tile * 128u + uint(int(ci) + j);
        uint h = pcg(id ^ seed ^ 0x2545F491u);
        if (float(h & 1023u) / 1024.0 >= woods) continue;
        float at = (ci + float(j) + 0.2 + 0.6 * float((h >> 10) & 255u) / 255.0 - cell) * 8.0;   // metres from this column
        float tall = 9.0 + 13.0 * float((h >> 18) & 255u) / 255.0;
        float r = tall * (0.22 + 0.12 * float((h >> 26) & 3u) / 3.0);
        float x = abs(at) / r;
        if (x >= 1.0) continue;
        float top = (h & 0x80000000u) != 0u ? tall * (1.0 - x) : tall * (1.0 - 0.45 * x * x) * sqrt(1.0 - x * x);
        canopy = max(canopy, ground + top / 256.0);
    }
    // a town: houses and blocks, 16 m to a plot, gabled or flat roofs,
    // the odd water tower
    float roof = -1.0;
    float town = share(k, K_TOWN, 40.0);
    if (town > 0.5 && k.off > 60.0 && k.off < 964.0) {
        float plot = w.off / 16.0, pi = floor(plot), u = plot - pi;
        uint h = pcg(w.tile * 64u + uint(pi) ^ seed ^ 0x68E31DA4u);
        float fill = 0.62 + 0.38 * float(h & 255u) / 255.0;
        float lo = 0.5 - 0.5 * fill, hi = 0.5 + 0.5 * fill;
        if ((h >> 8 & 15u) == 0u) {           // a water tower: a tank on a stalk
        float tank = 1.0 - smoothstep(0.16, 0.19, abs(u - 0.5));
        float stalk = 1.0 - smoothstep(0.04, 0.06, abs(u - 0.5));
        roof = tank > 0.0 ? g + (24.0 + 3.0 * tank) / 256.0 : (stalk > 0.0 ? g + 21.0 / 256.0 : -1.0);
        } else if (u > lo && u < hi) {
        float tall = 6.0 + 20.0 * pow(float((h >> 12) & 255u) / 255.0, 2.0);
        float gable = (h >> 20 & 3u) != 0u && tall < 14.0 ? 3.5 * (1.0 - abs(u - 0.5) / (0.5 * fill)) : 0.0;
        roof = g + (tall + gable) / 256.0;
        }
    }
    // over water there's no land at this distance: let it sink out of the way
    if (water > 0.0) { ground = groundV(64.0) - 0.05; canopy = ground; }
    return vec4(ground, canopy, water, roof);
}

vec4 columnTexel(int c, int row) {
    Pos pos = posFrom(state(S_POS));
    int line = int(state(S_LINE).x + 0.5);
    float hw = 0.5 * iResolution.x / iResolution.y;
    float xs = ((float(c) + 0.5) / float(landColumns(iResolution.x)) * 2.0 - 1.0) * hw;
    uint seed = uint(line + 1) * 0x85EBCA6Bu;
    vec2 asked = vec2(-1e5);
    if (state(S_TUN0).x >= 0.0) asked = vec2(metresFrom(posFrom(state(S_TUN0)), pos), metresFrom(posFrom(state(S_TUN1)), pos));
    if (row == 0) {
        // the mountains, 4 km off: low along the coast
        Pos w = moved(pos, xs * 4096.0);
        Biome b = biomeAt(w, line);
        float n = lfbm(layerPos(w, 8), 4, 5, seed ^ 11u);
        float far = groundV(4096.0) + b.mount * (0.1 + smoothstep(0.25, 0.85, n)) * mix(1.0, 0.4, b.sea) / 4096.0;
        // the hills, 1 km off: none where it's sea
        w = moved(pos, xs * 1024.0); b = biomeAt(w, line);
        Kinds k = kindsAt(w, line);
        n = lfbm(layerPos(w, 6), 3, 4, seed ^ 22u);
        float hills = groundV(1024.0) + b.hill * n * (1.0 - share(k, K_SEA, 300.0)) / 1024.0;
        // the land 256 m off: the highest of its ground, trees and roofs
        vec4 m = midLand(pos, xs, line, seed, asked);
        float mid = max(m.x, max(m.y, m.w));
        // the land 64 m off: the embankment, bushes, the odd tree
        w = moved(pos, xs * 64.0); b = biomeAt(w, line); k = kindsAt(w, line);
        LPos lp = layerPos(w, 2);
        n = lfbm(lp, 2, 4, seed ^ 44u);
        float bush = lfbm(lp, -1, 2, seed ^ 55u);
        float trees = b.woods * (1.0 - share(k, K_TOWN, 60.0)) * (1.0 - valley(k));
        float near = 1.6 * (n - 0.5) + 0.8 * smoothstep(0.45, 0.8, bush) + 4.0 * trees * smoothstep(0.6, 0.9, bush)
                   + 30.0 * tunnelHill(k, xs * 64.0, asked) - 24.0 * valley(k);
        near = groundV(64.0) + near / 64.0;
        return vec4(far, hills, mid, near);
    }
    if (row == 1) {
        vec4 m = midLand(pos, xs, line, seed, asked);
        // the fence, 64 m off: everywhere but towns, bridges, tunnels and the crossing's road
        Pos wn = moved(pos, xs * 64.0);
        Kinds kn = kindsAt(wn, line);
        float fence = (1.0 - share(kn, K_TOWN, 20.0)) * (1.0 - valley(kn)) * (1.0 - tunnelHill(kn, xs * 64.0, asked));
        if (kn.here == K_CROSSING && abs(kn.off - crossingAt(wn.tile)) < 5.0) fence = 0.0;
        // Flags: what's in this column, so the drawing pass only looks for
        // (and reads the numbers for) what's there: 1 the moon; 2 a bridge,
        // 4 a tunnel, 8 a station, all at the lineside; 16 a level crossing;
        // 32 wind turbines on the hills. The bridge, tunnel, station and
        // crossing come from last frame's D_ texels: a frame out, which the
        // margins here allow for.
        int flags = 0;
        float r = xs * 16.0;
        vec4 DP = state(D_POLE), DT = state(D_TUNNEL), DM = state(D_MOTION), M = state(D_SKY2);
        float st = DM.z + DM.w;
        if (state(D_SKY).z > 0.0 && abs(xs - M.x) < 0.21) flags |= 1;
        if (r > DP.z - 2.0 && r < DP.w + 2.0) flags |= 2;
        if (r > DT.x - 4.0 && r < DT.y + 4.0) flags |= 4;
        if (abs(st) < 400.0 && r > st - PLAT_BACK - 25.0 && r < st + PLAT_FRONT + 25.0) flags |= 8;
        if (abs(xs - DP.y / 64.0) < 0.13) flags |= 16;
        if (biomeAt(moved(pos, xs * 1024.0), line).turbine > 0.0) flags |= 32;
        // Where the poles are: the train's metres past one, as whole metres
        // (packed with the flags: a half float holds whole numbers to 2048
        // either side of 0) and the fraction, since a half float can't hold
        // 0..64 finely enough on its own (it would step 3 cm, 4 px at 4K).
        float m64 = mod(pos.off, POLE_EVERY), mi = floor(m64);
        float water = m.z > 0.0 ? m.z : (fence > 0.5 ? -2.0 : -1.0);
        return vec4(water, m.w, float(flags + 64 * int(mi)) - 2048.0, m64 - mi);
    }
    // the nearest wind turbine on the hills, if this biome has them: one to
    // each 256 m, if the dice say so
    Pos w = moved(pos, xs * 1024.0);
    Biome b = biomeAt(w, line);
    LPos lp = layerPos(w, 6);
    float here = (float(lp.A & 3u) + lp.a) / 4.0;
    uint slot = lp.A >> 2u;
    vec4 best = vec4(9.0, 0.0, 0.0, 0.0);
    for (int j = -1; j <= 1; j++) {
        uint id = uint(int(slot) + j);
        uint h = pcg(id ^ seed ^ 0x7F4A7C15u);
        if (float(h & 1023u) / 1024.0 >= b.turbine) continue;
        float at = (float(j) + 0.25 + 0.5 * float((h >> 10) & 255u) / 255.0 - here) * 4.0;   // layer metres from this column
        if (abs(at) / 16.0 >= abs(best.x)) continue;
        Pos wt = moved(w, at * 64.0);
        Kinds kt = kindsAt(wt, line);
        if (share(kt, K_SEA, 300.0) > 0.1) continue;
        float n = lfbm(layerPos(wt, 6), 3, 4, seed ^ 22u);
        float base = groundV(1024.0) + biomeAt(wt, line).hill * n / 1024.0;
        best = vec4(at / 16.0, base + 88.0 / 1024.0, float((h >> 18) & 255u) / 255.0, 44.0 / 1024.0);
    }
    return best;
}

// ----------------------------------------------------------------------------
// The misted glass: .r how misted (0 clear .. 1 milky, coarse), .g the fine
// part, .b the carriage reflected in it, .a how hard it's raining (the same
// everywhere: here because every pixel reads this texture anyway). It mists over at the rate the weather gives (fastest in heavy rain),
// quicker near the window's edges, and a wipe clears a stripe from the last
// wipe point to the new one, so a drag leaves a clean band.
vec4 fogTexel(ivec2 f, vec4 prev, bool fresh, bool running) {
    if (fresh) return vec4(0.25, 0.0, 0.0, 0.0);
    if (!running) return prev;
    float hw = 0.5 * iResolution.x / iResolution.y;
    vec2 p = vec2(((float(f.x) + 0.5) / float(FOG_W) - 0.5) * 2.0 * hw, (float(f.y) + 0.5) / float(FOG_H));
    vec2 e = vec2(abs(p.x) / hw, abs(p.y - 0.5) * 2.0);
    float edge = max(e.x, e.y);
    vec4 E = state(S_ENV) + state(S_ENVLO);
    float lo = prev.g + E.y * min(iTimeDelta, 0.05) / FOG_TIME * (0.7 + 0.6 * edge * edge);
    float carry = floor(lo * 256.0) / 256.0;
    float fog = min(prev.r + carry, 1.0);
    lo -= carry;
    uint wc = cellFg(H_WIPE).r;
    if (wc != 0u && float(wc) != state(S_SEEN).w) {
        vec2 b = wipePoint(cellBg(H_WIPE));
        vec4 W = state(S_WIPE);
        vec2 a = W.z < 0.15 ? W.xy : b;
        vec2 ab = b - a, ap = p - a;
        float t = clamp(dot(ap, ab) / max(dot(ab, ab), 1e-8), 0.0, 1.0);
        float keep = smoothstep(WIPE_R * 0.55, WIPE_R, length(ap - ab * t));
        fog *= keep;
        lo *= keep;
    }
    return vec4(fog, lo, 0.0, 0.0);
}
// What the glass does to the view, worked out on its own grid so a pixel
// only has to read it: the view comes through as col * k + light, where k
// and light hold the mist (it dims and lifts toward a pale violet), the
// carriage reflected in it (the reading lamp behind you, up to the left,
// and the window's lower edge), the moon's glare and the window frame. .a is
// k, made negative
// while it rains (rain is the same everywhere, so no texel's sign differs
// from its neighbours' and reading it smoothly can't blur the flag).
vec4 glassTexel(ivec2 f, vec4 fogNow) {
    float hw = 0.5 * iResolution.x / iResolution.y;
    vec2 p = vec2(((float(f.x) + 0.5) / float(FOG_W) - 0.5) * 2.0 * hw, (float(f.y) + 0.5) / float(FOG_H));
    float fog = clamp(fogNow.r + fogNow.g, 0.0, 1.0) * FOG_LOOK;
    vec2 lamp = vec2(-0.78 * hw, 0.80);
    float refl = 0.25 * glowAt(p - lamp, 0.006) + 0.03 * glowAt(p - lamp, 0.06) + 0.008 * glowAt(p - lamp, 0.25)
               + 0.012 * (1.0 - smoothstep(0.0, 0.02, abs(p.y - 0.06)));
    vec2 dm = p - state(D_SKY2).xy;
    vec3 light = state(D_PAL + 6).rgb * fog + toLinear(boatYellow2) * refl * state(D_ENV).w
               + toLinear(dragonBlue) * 0.025 * state(D_SKY).z * glowAt(dm, 0.3);
    float k = 1.0 - 0.6 * fog;
    // the window frame: a dark rounded border, a little soft (it's close, and
    // your eyes are on the view)
    if (FRAME) {
        vec2 e = abs(p - vec2(0.0, 0.5)) - vec2(hw, 0.5) + 0.07;
        float d = length(max(e, 0.0)) + min(max(e.x, e.y), 0.0) - 0.07;
        float frame = smoothstep(-0.016, -0.011, d);
        k *= 1.0 - frame;
        light = mix(light, toLinear(sumiInk0) * 0.25, frame);
    }
    return vec4(light, state(D_ENV).x > 0.01 ? -k : k);
}

// Buffer A: the simulation
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // Most of this buffer is unused, and every texel of it runs this: those
    // outside every patch leave first, before reading anything.
    ivec2 px      = ivec2(fragCoord);
    if (px.y >= GLASS_Y0 + FOG_H || px.x >= NCOL) discard;
    // This texel's last frame, read right here and not only in a helper:
    // it's how neowall learns that this pass reads itself (terminal mode
    // has no sidecar file to say so; termtest.glsl explains).
    vec4  prev    = texelFetch(iChannel0, ivec2(fragCoord), 0);
    // Nothing remembered yet (neowall just started, or resized the buffer,
    // which clears it) unless one of our two markers is there. Whatever an
    // empty buffer holds, it won't be exactly those.
    float mark    = state(S_MARK).a;
    bool  fresh   = iFrame == 0 || (abs(mark - 0.75) > 0.01 && abs(mark - 0.5) > 0.01);
    bool  running = programRunning();
    if (px.y == 0) {
        if (px.x >= S_COUNT) discard;
        fragColor = stateTexel(px.x, prev, fresh, running);
        return;
    }
    if (px.y >= COL_Y0 && px.y < COL_Y0 + 3) {
        if (px.x >= landColumns(iResolution.x)) discard;
        fragColor = columnTexel(px.x, px.y - COL_Y0);
        return;
    }
    if (px.y == SKY_Y) {
        if (px.x >= SKY_W + 7) discard;
        vec4 DS, DS2;
        skyNumbers(DS, DS2);
        float cloud = (state(S_ENV) + state(S_ENVLO)).w;
        if (px.x >= SKY_W) {
            fragColor = vec4(drawTexel(D_PAL + px.x - SKY_W).rgb, 1.0 - DS.x);
            return;
        }
        float v = HORIZON + (float(px.x) + 0.5) / float(SKY_W) * (1.0 - HORIZON);
        bool forced = (cellFg(H_BEAT).g & 2u) != 0u;
        fragColor = vec4(skyAt(v, DS, cloud), DS2.z * smoothstep(HORIZON + 0.03, HORIZON + 0.2, v) * 0.99 + (forced ? 2.0 : 0.0));
        return;
    }
    ivec2 f = px - ivec2(0, FOG_Y0);
    if (f.y >= 0 && f.y < FOG_H && f.x < FOG_W) { fragColor = fogTexel(f, prev, fresh, running); return; }
    f = px - ivec2(0, GLASS_Y0);
    if (f.y < 0 || f.y >= FOG_H || f.x >= FOG_W) discard;
    fragColor = glassTexel(f, texelFetch(iChannel0, f + ivec2(0, FOG_Y0), 0));
}

// ============================================================================
// Drawing (neowall gives code placed between the two mainImage functions to
// the second pass only)
// ============================================================================

// A bar of width w centred at c, smeared sideways over b by the motion: a box
// blur, worked out exactly as the share of the smear the bar covers. b is at
// least a pixel, which also smooths its edges when it's still.
float smeared(float x, float c, float w, float b) {
    float lo = max(x - 0.5 * b, c - 0.5 * w), hi = min(x + 0.5 * b, c + 0.5 * w);
    return max(hi - lo, 0.0) / b;
}
// how much a layer whose top edge is at `top` covers a pixel at height v
float cover(float top, float v, float px) { return clamp((top - v) / px + 0.5, 0.0, 1.0); }

// ----------------------------------------------------------------------------
// Stars: a few in each patch of sky, on a grid fixed to the screen (they're
// too far away to move), twinkling a little, fading toward the horizon.
float starsAt(vec2 fragCoord, float v, float twinkle) {
    float cell = iResolution.y / 180.0;
    vec2 g = fragCoord / cell, id = floor(g);
    uint h = (uint(id.x) * 73856093u) ^ (uint(id.y) * 19349663u);
    h *= 0x27D4EB2Du; h ^= h >> 15;
    if ((h & 31u) != 0u) return 0.0;                         // one cell in 32 has a star
    vec2 at = 0.15 + 0.7 * vec2(float((h >> 3) & 255u), float((h >> 11) & 255u)) / 255.0;
    float b = float((h >> 19) & 255u) / 255.0;
    b = b * b * b;                                           // mostly faint, a few bright
    float d = length((g - id - at) * cell);                  // pixels from its middle
    float r = 0.7 + 1.6 * b;
    return (0.08 + 0.9 * b) * max(0.0, 1.0 - d / r) * (0.7 + 0.3 * tri(twinkle * 3.0 + float(h >> 27) / 32.0))
         * smoothstep(HORIZON + 0.03, HORIZON + 0.2, v);
}

// The moon: a disc lit to its phase (waxing from the right, as seen from the
// north), a dim ghost of the unlit part, and a halo.
vec3 moonAt(vec2 p, vec2 at, float phase, float px) {
    float r = 0.028;
    vec2 d = (p - at) / r;
    float dd = dot(d, d);
    float g = glowAt(d, 1.8);
    vec3 c = toLinear(oldWhite) * 0.06 * g * g;                                 // the halo
    if (dd < 1.3) {
        float edge = clamp((1.0 - sqrt(dd)) * r / px + 0.5, 0.0, 1.0);
        float term = sqrt(max(1.0 - d.y * d.y, 0.0)) * sinCos(TAU * phase).y;   // where light turns to shadow
        float lit = phase < 0.5 ? smoothstep(term - 0.06, term + 0.06, d.x) : smoothstep(term - 0.06, term + 0.06, -d.x);
        c += edge * mix(toLinear(sumiInk4) * 0.25, toLinear(fujiWhite) * 1.1, lit);
    }
    return c;
}

// ----------------------------------------------------------------------------
// Reading what Buffer A worked out. On this chip every texture read costs
// about 0.7 ms a frame at 4K, even when every pixel reads the same texel
// (measured: four more cost 2.6 ms), so a pixel reads only what it needs.
// Reads are textureLod(.., 0.0): neowall's buffers have no smaller copies
// to choose between, and plain texture() would work out which anyway.

// one of the land's colours (0 mountains, 1 hills, 2 the land 256 m off, 4
// the land 64 m off, 5 the lineside, 6 the mist; .a: how much it's night)
vec4 paletteAt(int k) { return texelFetch(iChannel0, ivec2(SKY_W + k, SKY_Y), 0); }
// The sky's colour at a height, read from the gradient Buffer A works out
// each frame (row 5), rather than worked out again for every pixel.
vec3 skyRow(float v, vec2 bs) {
    float i = clamp((v - HORIZON) / (1.0 - HORIZON), 0.0, 1.0) * float(SKY_W - 1) + 0.5;
    return textureLod(iChannel0, vec2(i, float(SKY_Y) + 0.5) / bs, 0.0).rgb;
}

// The land's colours for how much it's day: the same as Buffer A's palette
// less its finer touches, worked out here since that's cheaper than reading
// them. haze: the sky's colour just above, which the far layers fade into.
vec3 farColour(float day, vec3 haze) {
    float dusk = day > 0.0 ? smoothstep(0.0, 0.08, iSun) * (1.0 - smoothstep(0.10, 0.36, iSun)) : 0.0;
    vec3 c = mix(mix(toLinear(waveBlue1) * 0.28, toLinear(dragonBlue) * 0.55, day), haze, MOUNT_COL);
    return mix(c, toLinear(oniViolet) * 0.2, dusk * 0.35);
}
vec3 hillsColour(float day, vec3 haze) { return mix(mix(toLinear(sumiInk2) * 0.95, toLinear(winterGreen) * 1.3, day), haze, HILL_COL); }
vec3 midColour(float day)  { return mix(toLinear(sumiInk2) * 0.95, toLinear(autumnGreen) * 0.30, day); }
vec3 nearColour(float day) { return mix(toLinear(sumiInk3) * 0.95, toLinear(winterGreen) * 0.75, day); }
vec3 foreColour(float day) { return mix(toLinear(sumiInk0) * 0.45, toLinear(sumiInk2) * 0.8, day); }

// Water mirrors what's above it about its level: the sky, the hills and
// mountains (from the same columns), and a glittering path under the moon.
vec3 waterAt(float v, float level, vec2 p, vec4 C2, float day, float glitterPhase, vec2 bs) {
    float m = 2.0 * level - v + (tri(v * 900.0 + glitterPhase * 7.0) - 0.5) * 0.0015;   // the spot it mirrors, rippled
    vec3 sky = skyRow(m, bs);
    vec3 c = 0.5 * (m < C2.y ? hillsColour(day, sky) : (m < C2.x ? farColour(day, sky) : sky));
    // the moon's path: bright specks across the water beneath it
    vec4 M = state(D_SKY2), DS = state(D_SKY);
    float below = level - v;
    if (DS.z > 0.02 && below > 0.0) {
        float across = abs(p.x - M.x) / (0.012 + 0.9 * below);
        if (across < 1.0) {
            vec2 g = vec2(p.x / 0.004, v / 0.0018);
            uint h = pcg(uint(int(floor(g.x)) + 100000) * 7919u ^ uint(int(floor(g.y)) + 100000) * 104729u);
            float spark = step(0.86, fract(float(h & 1023u) / 1024.0 + glitterPhase * 0.7));
            c += toLinear(fujiWhite) * 0.35 * spark * (1.0 - across) * DS.z * (0.25 + 0.75 * tri(DS.w));
        }
    }
    return c;
}

// ----------------------------------------------------------------------------
// A wind turbine on the hills: a tower and three turning blades, a red light
// on its hub blinking with all the others (1 s on, 1 s off).
vec3 turbine(vec2 p, vec4 T, vec3 col, vec3 ink, float spin, float blink, float px, float sleep) {
    vec2 d = vec2(-T.x, p.y - T.y);          // this pixel from the hub (T.x: the turbine, across from this pixel)
    float R = T.w;
    // the tower: tapering from the hub down to the hills
    float tw = mix(0.0022, 0.0012, clamp((p.y - (T.y - 0.09)) / 0.09, 0.0, 1.0));
    float tower = (1.0 - smoothstep(tw - px, tw + px, abs(d.x))) * step(p.y, T.y) * step(T.y - 88.0 / 1024.0, p.y);
    // the blades: three thin tapering bars, turning
    float blades = 0.0;
    float r = length(d);
    if (r < R) {
        float ang = spin * TAU / 3.0 + T.z * TAU;
        for (int k = 0; k < 3; k++) {
            vec2 dir = sinCos(ang + float(k) * TAU / 3.0);
            float along = dot(d, dir), across = abs(d.x * dir.y - d.y * dir.x);
            float w = mix(0.0016, 0.0005, clamp(along / R, 0.0, 1.0));
            blades = max(blades, step(0.0, along) * (1.0 - smoothstep(w - px, w + px, across)));
        }
    }
    col = mix(col, ink, max(tower, blades));
    float on = step(0.5, fract(blink)) * (1.0 - sleep);
    col += toLinear(autumnRed) * (0.9 * on) * glowAt(d / 0.002, 1.0) + toLinear(autumnRed) * 0.08 * on * glowAt(d, 0.01);
    return col;
}

// ----------------------------------------------------------------------------
// The lineside, 16 m away: poles every 64 m carrying three wires, which sag
// between them, so they seem to rise to each pole and fall away after it.
// Returns how much they cover the pixel.
float lineside(float xs, float v, float px, float m64, float blur, bool nearPole) {
    float x = xs * 16.0 + m64;                          // metres past the pole behind the window's middle
    float base = groundV(16.0), top = base + POLE_H / 16.0;
    float c = 0.0;
    if (nearPole) {
        float pc = (floor(x / POLE_EVERY + 0.5) * POLE_EVERY - m64) / 16.0;   // the nearest pole, from the middle
        float b = max(blur, px);
        c = smeared(xs, pc, POLE_W / 16.0, b) * step(v, top) * step(base - 0.05, v);
        float arm = 1.0 - smoothstep(0.0, 1.2 * px, abs(v - (top - 0.4 / 16.0)) - 0.07 / 16.0);
        c = max(c, arm * smeared(xs, pc, 2.2 / 16.0, b));
    }
    float u = fract(x / POLE_EVERY + 0.5);              // 0..1 from one pole to the next
    float h = (v - base) * 16.0 + WIRE_SAG * 4.0 * u * (1.0 - u);   // metres, as if the wires didn't sag
    float d = min(abs(h - WIRE_H.x), min(abs(h - WIRE_H.y), abs(h - WIRE_H.z))) / 16.0;
    return max(c, 0.85 * (1.0 - smoothstep(0.3 * px, 1.4 * px, d)));
}

// A truss bridge's girders, right by the window: top and bottom chords and
// diagonals every 8 m, smeared to a haze at speed.
float truss(float xs, float v, float px, float m64, float blur) {
    float x = xs * 16.0 + m64;
    float base = groundV(16.0) - 0.02, top = base + 5.5 / 16.0;
    float b = max(blur, px), thin = min(1.0, 0.14 / 16.0 / b);
    float chord = max(1.0 - smoothstep(0.0, px, abs(v - top) - 0.1 / 16.0), 1.0 - smoothstep(0.0, px, abs(v - base) - 0.16 / 16.0));
    float u = fract(x / 8.0);
    float hd = base + (1.0 - abs(2.0 * u - 1.0)) * 5.5 / 16.0;
    float diag = (1.0 - smoothstep(0.0, px + b * 1.6, abs(v - hd) - 0.006)) * thin * step(base, v) * step(v, top);
    return max(chord, diag);
}

// ----------------------------------------------------------------------------
// A level crossing, 64 m off: the signal's two red lamps flashing in turn,
// and a car waiting at the barrier with its headlights on.
vec3 crossing(vec2 p, float at, vec3 col, vec3 ink, float blink, float blur, float px, float sleep) {
    float x = at / 64.0;                               // on the screen
    float g = groundV(64.0);
    vec2 d = p - vec2(x - 0.07, g);
    float b = max(blur * 0.25, px);
    // the signal's post and crossbuck
    float post = smeared(p.x, x - 0.07, 0.12 / 64.0 * 2.0, b) * step(p.y, g + 3.2 / 64.0) * step(g - 0.01, p.y);
    col = mix(col, ink, post);
    float on = step(0.5, fract(blink * 2.0)) * (1.0 - sleep);
    vec2 l1 = p - vec2(x - 0.07 - 0.5 / 64.0, g + 2.5 / 64.0), l2 = p - vec2(x - 0.07 + 0.5 / 64.0, g + 2.5 / 64.0);
    vec3 red = toLinear(samuraiRed);
    col += red * (on * (glowAt(l1, 0.0025) + 0.2 * glowAt(l1, 0.012)) + (1.0 - on) * (glowAt(l2, 0.0025) + 0.2 * glowAt(l2, 0.012))) * (1.0 - 0.8 * sleep);
    // the car: two warm headlights, low down, and their light on the road
    vec2 h1 = p - vec2(x + 0.035, g + 0.7 / 64.0), h2 = p - vec2(x + 0.035 + 1.4 / 64.0, g + 0.7 / 64.0);
    col += toLinear(fujiWhite) * (glowAt(h1, 0.002) + glowAt(h2, 0.002) + 0.12 * glowAt(h1, 0.015) + 0.12 * glowAt(h2, 0.015));
    return col;
}

// ----------------------------------------------------------------------------
// A tunnel: dark walls rushing by, lamps every 32 m smeared into streaks,
// and a stone face at each mouth. rel: metres along the line from the
// window's middle; ends: the tunnel's start and end.
vec3 tunnelAt(float xs, float v, float rel, vec2 ends, float m64, float blur, float px) {
    vec3 col = toLinear(sumiInk0) * 0.18;
    float b = max(blur, px);
    float m32 = mod(m64, 32.0);                         // lamps every 32 m, which divides the poles' 64
    float x = rel + m32;
    float j = floor(x / 32.0 + 0.5);
    float lc = (j * 32.0 - m32) / 16.0;
    float dv = abs(v - 0.56);
    float lamp = smeared(xs, lc, 0.35 / 16.0, b) * (1.0 - smoothstep(0.002, 0.008, dv));
    float halo = smeared(xs, lc, 2.0 / 16.0, b + 0.04) * glowAt(vec2(dv, 0.0), 0.02);
    vec3 lampCol = mod(j, 2.0) < 0.5 ? toLinear(waveAqua2) : toLinear(oldWhite);
    col += lampCol * (0.9 * lamp + 0.05 * halo);
    // the walls: a faint sheen, and the cable trays along them
    col += toLinear(sumiInk4) * 0.25 * smoothstep(0.5, 0.0, abs(v - 0.3));
    col = mix(col, toLinear(sumiInk0) * 0.08, 1.0 - smoothstep(0.0, px, abs(v - 0.24) - 0.003));
    // the mouths: a band of stone
    float face = max(smoothstep(-2.5, -2.0, rel - ends.x) * smoothstep(0.3, 0.0, rel - ends.x),
                     smoothstep(-0.3, 0.0, rel - ends.y) * smoothstep(2.5, 2.0, rel - ends.y));
    float course = step(0.5, fract(v * 40.0 + 0.3 * step(0.5, fract(rel * 0.8))));   // courses of stone
    col = mix(col, toLinear(katanaGray) * mix(0.035, 0.05, course), face);
    return col;
}

// ----------------------------------------------------------------------------
// The station, at the lineside's distance: a platform along the bottom, its
// lamps, and the sign, dead in the middle of the window when stopped.

// How much of a terminal cell's letter covers a spot in it (frac: 0..1
// across, 0..1 down). A small copy of the stdlib's nwTermCell lookup:
// neowall packs where each letter is in its glyph atlas into the cell.
float glyphCover(ivec2 cell, vec2 frac) {
    uvec4 rec = texelFetch(iTermCells, cell, 0);
    if ((rec.r & 1u) == 0u) return 0.0;
    vec2 a = vec2(float((rec.r >> 20) & 0xFFFu), float((rec.r >> 8) & 0xFFFu));
    vec2 g = vec2(float((rec.g >> 24) & 0xFFu), float((rec.g >> 16) & 0xFFu));
    vec2 o = vec2(float((rec.g >> 8) & 0xFFu), float(rec.g & 0xFFu)) - 128.0;
    vec2 gp = frac * iTermInfo.zw - o;
    if (gp.x < 0.0 || gp.y < 0.0 || gp.x >= g.x || gp.y >= g.y) return 0.0;
    gp = clamp(gp, vec2(0.5), g - 0.5);
    // four taps half a texel apart: the atlas is drawn larger than the sign's
    // letters, and this averages it down without shimmer
    vec2 t = 0.5 / iTermAtlasSize, uv = (a + gp) / iTermAtlasSize;
    float c = textureLod(iTermAtlas, uv + t, 0.0).r + textureLod(iTermAtlas, uv - t, 0.0).r
            + textureLod(iTermAtlas, uv + vec2(t.x, -t.y), 0.0).r + textureLod(iTermAtlas, uv + vec2(-t.x, t.y), 0.0).r;
    return clamp(c * 0.25, 0.0, 1.0);
}
// One line of the sign: the program centres it in the first 24 columns of
// row `row`; span says which columns hold letters, so the letters can be as
// big as fits. q: the spot, from the line's middle (screen heights); box:
// the line's width and height.
float signLine(vec2 q, int row, vec2 span, vec2 box) {
    if (span.x < 0.0) return 0.0;
    float n = span.y - span.x + 1.0;
    float h = min(box.y, box.x / n * 2.0);           // a letter cell is twice as tall as wide
    float w = 0.5 * h;
    float x = q.x / w + 0.5 * n;
    if (x < 0.0 || x >= n || abs(q.y) > 0.5 * h) return 0.0;
    float cx = floor(x);
    return glyphCover(ivec2(int(span.x + cx), row), vec2(x - cx, 0.5 - q.y / h));
}

vec3 station(vec2 p, float at, vec3 col, float px, float night, float fog, vec4 span) {
    float rel = p.x * 16.0;                           // metres from the window's middle
    float sx = at / 16.0;                             // the sign's middle, on the screen
    float plat = step(at - PLAT_BACK, rel) * step(rel, at + PLAT_FRONT);
    vec3 lampCol = toLinear(roninYellow);
    // the lamps along the platform: their posts and heads, and the pools of
    // light they cast (their glow spreads wider through misted glass)
    float first = at - PLAT_BACK + 0.5 * LAMP_EVERY;
    float li = clamp(floor((rel - first) / LAMP_EVERY + 0.5), 0.0, floor((PLAT_BACK + PLAT_FRONT) / LAMP_EVERY) - 1.0);
    float lx = (first + li * LAMP_EVERY) / 16.0;
    float spread = 1.0 + 2.0 * fog;
    float pool = 0.0;
    if (plat > 0.0 && p.y < PLAT_TOP) {
        // the platform: its edge line near the bottom, lit by the lamps
        float d = (p.x - lx) * 16.0;
        pool = 1.0 / (1.0 + d * d / 30.0) + 0.6 / (1.0 + (d - LAMP_EVERY) * (d - LAMP_EVERY) / 30.0)
             + 0.6 / (1.0 + (d + LAMP_EVERY) * (d + LAMP_EVERY) / 30.0);
        vec3 slab = mix(toLinear(fujiGray) * 0.10, toLinear(katanaGray) * 0.16, smoothstep(0.0, PLAT_TOP, p.y));
        col = slab * (0.4 + 1.6 * pool * night) + toLinear(katanaGray) * 0.1 * (1.0 - night);
        float line = 1.0 - smoothstep(0.0, px, abs(p.y - 0.035) - 0.004);
        col = mix(col, toLinear(carpYellow) * (0.25 + 0.6 * pool * night), line);
        col = mix(col, toLinear(sumiInk0) * 0.3, 1.0 - smoothstep(0.0, px, PLAT_TOP - p.y - 0.006));
    }
    if (plat > 0.0) {
        float post = (1.0 - smoothstep(0.0, px, abs(p.x - lx) - 0.07 / 16.0)) * step(p.y, 0.62) * step(0.1, p.y);
        col = mix(col, toLinear(sumiInk0) * 0.4, post);
        vec2 hd = p - vec2(lx, 0.625);
        col += lampCol * (1.5 * glowAt(hd / 0.006, 1.0) + 0.09 * glowAt(hd, 0.04 * spread)) * night;
    }
    // the sign on its two posts
    float hwid = 0.5 * SIGN_BOX.x;
    vec2 q = p - vec2(sx, 0.5 * (SIGN_BOX.y + SIGN_BOX.z));
    float posts = (1.0 - smoothstep(0.0, px, abs(abs(q.x) - 0.36 * hwid) - 0.004)) * step(PLAT_TOP, p.y) * step(p.y, SIGN_BOX.y);
    col = mix(col, toLinear(sumiInk0) * 0.35, posts);
    float hh = 0.5 * (SIGN_BOX.z - SIGN_BOX.y);
    vec2 e = abs(q) - vec2(hwid, hh);
    if (max(e.x, e.y) < px) {
        float inside = clamp(-max(e.x, e.y) / px + 0.5, 0.0, 1.0);
        float border = 1.0 - smoothstep(0.0, px, -max(e.x, e.y) - 0.004);
        vec3 panel = toLinear(waveBlue1) * mix(0.6, 1.2, night);
        vec3 ink = toLinear(fujiWhite) * mix(0.55, 0.95, night);
        vec2 box = vec2(2.0 * hwid * 0.9, 2.0 * hh);
        float letters = signLine(q - vec2(0.0, hh * 0.4), 1, span.xy, box * vec2(1.0, 0.5))
                      + signLine(q - vec2(0.0, -hh * 0.55), 2, span.zw, box * vec2(0.8, 0.26));
        vec3 face = mix(mix(panel, ink, clamp(letters, 0.0, 1.0)), ink, border);
        col = mix(col, face, inside);
    }
    return col;
}

// ----------------------------------------------------------------------------
// The glass
//
// Rain: while the train moves, drops run back along the glass in slanting
// streaks (the faster it goes, the flatter); stopped, they sit as beads and
// slowly slip down. Both are grids of cells, each with a drop in it or not.
float streaks(vec2 p, float amount, float phase, float slant, float px) {
    vec2 sc = sinCos(slant);                               // slant from the vertical
    vec2 q = vec2(p.x * sc.y + p.y * sc.x, p.y * sc.y - p.x * sc.x);   // across, along
    vec2 cell = vec2(0.02, 0.26);
    float colId = floor(q.x / cell.x);
    q.y += phase * 256.0 * cell.y + float(pcg(uint(int(colId) + 65536)) & 1023u) / 1024.0 * cell.y;
    vec2 g = q / cell, id = floor(g), f = g - id;
    uint h = pcg(uint(int(id.x) + 65536) * 7919u ^ (uint(int(id.y) + 65536) & 255u) * 104729u ^ 0x9E3779B9u);
    if (float(h & 1023u) / 1024.0 > amount * 0.28) return 0.0;
    float x0 = 0.2 + 0.6 * float((h >> 10) & 255u) / 255.0;
    float len = 0.25 + 0.6 * float((h >> 18) & 255u) / 255.0;
    float d = abs(f.x - x0) * cell.x / px;
    float along = (f.y - (1.0 - len)) / len;               // 0 at its tail, 1 at its head
    if (along < 0.0) return 0.0;
    return (1.0 - smoothstep(0.5, 1.4, d)) * (0.25 + 0.75 * along * along) * (0.4 + 0.6 * float((h >> 26) & 63u) / 63.0);
}
float beads(vec2 p, float amount, float slip, float px, out vec2 bend) {
    vec2 cell = vec2(0.045);
    vec2 g = p / cell, id = floor(g);
    uint h = pcg(uint(int(id.x) + 65536) * 7919u ^ uint(int(id.y) + 65536) * 104729u ^ 0x85EBCA6Bu);
    bend = vec2(0.0);
    if (float(h & 1023u) / 1024.0 > amount * 0.45) return 0.0;
    vec2 at = 0.25 + 0.5 * vec2(float((h >> 10) & 255u), float((h >> 18) & 255u)) / 255.0;
    at.y -= fract(slip * (0.3 + float(h >> 26) / 64.0)) * 0.25 * step(0.8, float((h >> 4) & 63u) / 63.0);   // a few slip down
    float r = 0.06 + 0.2 * pow(float((h >> 26) & 63u) / 63.0, 2.0);
    vec2 d = (g - id - at) / r;
    float dd = dot(d, d);
    if (dd > 1.0) return 0.0;
    bend = d;
    return 1.0 - smoothstep(0.75, 1.0, dd);
}

// The sky at a height: its colour, and how bright its stars are there.
vec4 skyTexel(float v, vec2 bs) {
    float i = clamp((v - HORIZON) / (1.0 - HORIZON), 0.0, 1.0) * float(SKY_W - 1) + 0.5;
    return textureLod(iChannel0, vec2(i, float(SKY_Y) + 0.5) / bs, 0.0);
}
// The sky's pixels: the sky, its stars, and the moon's disc where it is.
vec3 skyWith(vec4 S, vec2 p, vec2 fragCoord, float px, bool moonHere) {
    vec3 col = S.rgb;
    float stars = fract(S.a * 0.5) * 2.0;
    if (stars > 0.01) col += toLinear(fujiWhite) * 0.9 * stars * starsAt(fragCoord, p.y, iTime * 0.13);
    if (moonHere) {
        vec4 M = state(D_SKY2), DS = state(D_SKY);
        if (DS.z > 0.0 && abs(p.x - M.x) < 0.2 && abs(p.y - M.y) < 0.2) col += moonAt(p, M.xy, DS.w, px) * DS.z;
    }
    return col;
}

// ----------------------------------------------------------------------------
// What it costs
//
// On the XPS's UHD 630 at 4K (Sep 2026, tools/bin/harness_term, a night
// scene, no rain): about 9.4 ms a frame, Buffer A 1.3 and this pass 8.1:
// level with orbit3d (9.2), a little above koi (8.5). At 60 Hz that's about
// half the chip's time, as with the others; on a 30 Hz screen, half that.
// When the wallpaper sleeps (covered by windows, or halted at a quiet
// station) it costs nothing at all: neowall stops drawing.
//
// What made it that cheap, all measured:
//   - reads. Each texture read costs about 0.7 ms at 4K here, even when
//     every pixel reads the same texel (four more cost 2.6 ms). So anything
//     that's the same for every pixel and cheap to work out (the land's
//     colours) is worked out, not read; what's costly (the sky's gradient,
//     the glass's whole effect, the land's shapes) is worked out once in
//     Buffer A and read in as few texels as possible: three for every pixel
//     (skylines, the column's details, the sky) and one for the glass.
//   - reading them all at once, up front: a read inside a branch waits its
//     own round trip (reading two only where needed was 0.5 ms slower than
//     always), but holding all four from the start left too few registers
//     for the chip to run 16 pixels at a time (13 ms). Three up front and
//     the glass at the end came out best.
//   - the sky's own path: above the land, a pixel reads its sky and draws
//     the poles, wires and stars, and none of the land's layers.
//   - drawing the land from the nearest layer that hides the rest: most of
//     the screen is only one layer deep.
//   - Buffer A throws away the texels it doesn't use before reading
//     anything (that took it from 3.0 ms to 1.3).
//   - half floats hold ~3 digits: every position is kept as whole metres
//     plus the rest (a pole's place in one half float would step 4 px).
// This pass must compile for 16 pixels at a time: check with
// MESA_SHADER_CACHE_DISABLE=true INTEL_DEBUG=fs, which lists a "SIMD16
// shader:" for it. (The simulation pass is SIMD8, which is fine: its big
// state code runs on only a few hundred texels.)
// ----------------------------------------------------------------------------

// Image: the screen, drawn from the simulation (neowall finds each pass by a
// comment like this just above it, so keep other pass names out of it)
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec4 mark = state(S_MARK);
    if (mark.a != 0.75 || mark.x < 2.0) {
        // the program isn't running (or not yet): show its terminal as it is,
        // so an error message can be seen
        fragColor = vec4(nwTerm(fragCoord / iResolution.xy), 1.0);
        return;
    }
    float px = 1.0 / iResolution.y;                     // a pixel, in screen heights
    float hw = 0.5 * iResolution.x * px;
    vec2  p  = vec2(fragCoord.x * px - hw, fragCoord.y * px);   // across from the middle, up from the bottom
    vec2  bs = vec2(textureSize(iChannel0, 0));
    float ncol = float(landColumns(bs.x));
    float colf = clamp((p.x / hw * 0.5 + 0.5) * ncol, 0.5, ncol - 0.5);
    // Every pixel makes the same three reads, all at once, up front, and the
    // glass's at the end: on this chip each costs ~0.7 ms at 4K, and one made
    // inside a branch costs a round trip more (measured: reading two of
    // these only where needed came out 0.5 ms slower than always). But all
    // four held from the start leave too little room for the chip to run 16
    // pixels at a time, which costs far more (13 ms): so the glass waits.
    vec4 C2 = textureLod(iChannel0, vec2(colf, float(COL_Y0) + 0.5) / bs, 0.0);    // the skylines, smoothly
    vec4 C3 = texelFetch(iChannel0, ivec2(int(colf), COL_Y0 + 1), 0);             // water, roofs, flags, poles
    vec4 S = skyTexel(p.y, bs);                                                     // the sky at this height
    int bits = int(C3.z + 2048.5), flags = bits & 63;
    float m64 = float(bits >> 6) + C3.w;                // metres past the last pole
    float day  = S.a >= 2.0 ? 0.0 : smoothstep(0.06, 0.40, iSun);   // (.a >= 2: night is forced)
    float base = groundV(16.0);
    float rel = p.x * 16.0, fx = rel + m64;             // metres along the line at the lineside
    vec3 col;
    if (p.y > max(max(C2.x, C2.y), max(C2.z, C2.w)) + 0.03 && (flags & 14) == 0) {
        // above the land, with no tunnel, station or bridge here: the sky,
        // and the turbines against it
        col = skyWith(S, p, fragCoord, px, (flags & 1) != 0);
        if ((flags & 32) != 0 && p.y < HORIZON + 0.2) {
            int ci = int(colf);
            vec4 T = texelFetch(iChannel0, ivec2(ci, COL_Y0 + 2), 0);
            if (T.w > 0.0) {
                T.x -= p.x - ((float(ci) + 0.5) / ncol * 2.0 - 1.0) * hw;
                if (abs(T.x) < T.w + 0.004 && p.y < T.y + T.w + 0.004) {
                    vec4 F = state(D_FEAT);
                    col = turbine(p, T, col, hillsColour(day, S.rgb) * 0.8, F.x, F.x * 2.0, px, F.z);
                }
            }
        }
    } else {
        vec4 DP = vec4(1e4);
        if ((flags & 18) != 0) DP = state(D_POLE);
        bool onBridge = (flags & 2) != 0 && rel > DP.z && rel < DP.w;
        float foreTop = -1.0;
        if (!onBridge && p.y < base + 1.4 / 16.0)
            foreTop = base + (0.8 + 0.25 * tri(fx / 16.0) + 0.12 * tri(fx / 4.0 + 0.3) + 0.06 * tri(fx + 0.7)) / 16.0;

        // ---- the land, drawn from the nearest layer that hides everything
        // behind it: most of the screen is only one layer deep
        if (p.y < foreTop - px) {
            col = foreColour(day);                      // the embankment by the track
        } else if (p.y < C2.w - px) {
            col = nearColour(day);                      // the land 64 m off
        } else {
            int from = p.y < C2.z - px ? 3 : (p.y < C2.y - px ? 2 : (p.y < C2.x - px ? 1 : 0));
            col = from == 0 ? skyWith(S, p, fragCoord, px, (flags & 1) != 0) : vec3(0.0);
            float a;
            if (from <= 1 && (a = cover(C2.x, p.y, px)) > 0.0) col = mix(col, farColour(day, S.rgb), a);
            if (from <= 2) {
                if ((a = cover(C2.y, p.y, px)) > 0.0) col = mix(col, hillsColour(day, S.rgb), a);
                if ((flags & 32) != 0 && p.y > HORIZON - 0.01 && p.y < HORIZON + 0.2) {
                    int ci = int(colf);
                    vec4 T = texelFetch(iChannel0, ivec2(ci, COL_Y0 + 2), 0);
                    if (T.w > 0.0) {
                        T.x -= p.x - ((float(ci) + 0.5) / ncol * 2.0 - 1.0) * hw;   // from this pixel, not the column's middle
                        if (abs(T.x) < T.w + 0.004 && p.y < T.y + T.w + 0.004) {
                            vec4 F = state(D_FEAT);
                            col = turbine(p, T, col, hillsColour(day, S.rgb) * 0.8, F.x, F.x * 2.0, px, F.z);
                        }
                    }
                }
                if (C3.x > 0.0 && p.y < C3.x + px)
                    col = mix(col, waterAt(p.y, C3.x, p, C2, day, state(D_FEAT).y * 64.0, bs), cover(C3.x, p.y, px));
            }
            // the land 256 m off: its ground and trees, and towns
            if ((a = cover(C2.z, p.y, px)) > 0.0) col = mix(col, midColour(day), a);
            if (C3.y > 0.0 && p.y < C3.y + px) {
                vec4 SP = state(S_POS);
                float night = 1.0 - day;
                vec3 wall = mix(toLinear(sumiInk3) * 0.8, toLinear(katanaGray) * 0.25, day);
                // windows, on a grid fixed to the land: 4 m apart, 3.2 m a floor
                float wx = (SP.z + (SP.w + p.x * 256.0)) / 4.0, fy = (p.y - groundV(256.0)) * 256.0 / 3.2;
                float wi = floor(wx), fi = floor(fy);
                uint h = pcg((uint(SP.x) * 2048u + uint(SP.y)) * 256u + uint(int(wi)) ^ uint(int(fi)) * 0x632BE5ABu);
                float hour = iTimeOfDay * 24.0;
                float litShare = mix(0.35, 0.12, smoothstep(22.5, 26.0, hour < 12.0 ? hour + 24.0 : hour)) * night;
                vec2 wf = vec2(wx - wi, fy - fi);
                float win = step(0.3, wf.x) * step(wf.x, 0.72) * step(0.3, wf.y) * step(wf.y, 0.78) * step(1.0, fi);
                if (win > 0.0 && float(h & 1023u) / 1024.0 < litShare) {
                    float k = float((h >> 10) & 15u);
                    vec3 lit = k < 1.0 ? toLinear(springBlue) * 0.25 : (k < 8.0 ? toLinear(carpYellow) : toLinear(autumnYellow)) * 0.45;
                    wall = mix(wall, lit, win);
                }
                col = mix(col, wall, cover(C3.y, p.y, px));
                // street lamps along the town's foot
                float lampY = groundV(256.0) + 5.0 / 256.0;
                if (abs(p.y - lampY) < 0.05) {
                    float lx = (SP.z + (SP.w + p.x * 256.0)) / 32.0, li = floor(lx + 0.5);
                    vec2 d = vec2((lx - li) * 32.0 / 256.0, p.y - lampY);
                    vec3 lc = mod(li, 3.0) < 1.0 ? toLinear(surimiOrange) : toLinear(roninYellow);
                    col += lc * (0.8 * glowAt(d / 0.0012, 1.0) + 0.05 * glowAt(d, 0.02)) * night;
                }
            }
            // the land 64 m off, its fence, a level crossing, and the top of
            // the embankment
            if ((a = cover(C2.w, p.y, px)) > 0.0) col = mix(col, nearColour(day), a);
            if (C3.x < -1.5 && p.y < C2.w + 1.4 / 64.0) {
                // fence posts every 2 m (2 divides 64, so they stay put as a pole passes)
                float g = C2.w, fp = mod(m64, 2.0);
                float pc = (floor((p.x * 64.0 + fp) / 2.0 + 0.5) * 2.0 - fp) / 64.0;
                float post = step(g, p.y + px) * step(p.y, g + 1.3 / 64.0);
                if (post > 0.0 && abs(p.x - pc) < 0.01) post *= smeared(p.x, pc, 0.14 / 64.0, max(state(D_MOTION).y * 0.25, px));
                else post = 0.0;
                float rails = max(1.0 - smoothstep(0.0, px, abs(p.y - g - 1.1 / 64.0) - 0.3 * px),
                                  1.0 - smoothstep(0.0, px, abs(p.y - g - 0.55 / 64.0) - 0.3 * px)) * 0.7;
                if (max(post, rails) > 0.0) col = mix(col, foreColour(day), max(post, rails));
            }
            if ((flags & 16) != 0 && abs(p.x - DP.y / 64.0) < 0.12) {
                vec4 F = state(D_FEAT);
                col = crossing(p, DP.y, col, foreColour(day), F.x, state(D_MOTION).y, px, F.z);
            }
            if ((a = cover(foreTop, p.y, px)) > 0.0) col = mix(col, foreColour(day), a);
        }
        // ---- a bridge's girders, a station, a tunnel
        if (onBridge) col = mix(col, foreColour(day) * 0.9, truss(p.x, p.y, px, m64, state(D_MOTION).y));
        if ((flags & 8) != 0) {
            vec4 DM = state(D_MOTION);
            float st = DM.z + DM.w;
            if (rel > st - PLAT_BACK - 20.0 && rel < st + PLAT_FRONT + 20.0)
                col = station(p, st, col, px, 1.0 - day, 0.5, state(D_SIGN));
        }
        if ((flags & 4) != 0) {
            vec4 DT = state(D_TUNNEL);
            if (rel > DT.x - 3.0 && rel < DT.y + 3.0)
                col = mix(col, tunnelAt(p.x, p.y, rel, DT.xy, m64, state(D_MOTION).y, px),
                          smoothstep(-2.6, -2.5, rel - DT.x) * smoothstep(2.6, 2.5, rel - DT.y));
        }
    }
    // ---- the poles and wires, in front of it all (behind a tunnel's walls:
    // a pole in a tunnel is only in the way of nothing)
    float pole = (floor(fx / POLE_EVERY + 0.5) * POLE_EVERY - m64) / 16.0;
    bool nearPole = abs(p.x - pole) < 0.08;
    if (nearPole || p.y > base + (WIRE_H.z - WIRE_SAG) / 16.0 - 3.0 * px && p.y < base + WIRE_H.x / 16.0 + 3.0 * px) {
        float blur = 0.0;
        if (nearPole) blur = state(D_MOTION).y;
        float c = lineside(p.x, p.y, px, m64, blur, nearPole);
        if (c > 0.0) col = mix(col, foreColour(day) * 0.8, c);
    }

    // ---- the glass: rain on it...
    vec2 guv = vec2(clamp(fragCoord.x / iResolution.x * float(FOG_W), 0.5, float(FOG_W) - 0.5),
                    clamp(p.y * float(FOG_H), 0.5, float(FOG_H) - 0.5) + float(GLASS_Y0));
    vec4 G = textureLod(iChannel0, guv / bs, 0.0);
    if (G.a < 0.0) {
        vec4 DE = state(D_ENV), DF = state(D_FEAT);
        float rain = DE.x, running = DE.y, night = 1.0 - smoothstep(0.06, 0.40, iSun);
        vec3 hl = mix(toLinear(lightBlue), toLinear(fujiWhite), 0.4) * mix(0.06, 0.14, night);
        if (running > 0.01) {
            float slant = atan(state(D_MOTION).x / 5.0);
            float s = streaks(p, rain, DF.y, slant, px) + 0.6 * streaks(p * 1.7 + 3.1, rain, DF.y * 1.3, slant, px);
            col += hl * s * running * 0.8;
        }
        if (running < 0.99) {
            // a drop: darker at its rim, with a highlight up and to the left
            vec2 bend;
            float b = beads(p, rain, DF.y * 20.0, px, bend);
            float spec = smoothstep(0.55, 0.0, length(bend - vec2(-0.35, 0.35)));
            col = mix(col, col * (0.55 + 0.35 * dot(bend, bend)) + hl * 1.6 * spec, b * (1.0 - running));
        }
    }
    // ...then the mist on it, what it reflects and the window frame, worked
    // out on the glass's own grid (see glassTexel)
    col = col * abs(G.a) + G.rgb;
    if (max(col.r, max(col.g, col.b)) > 0.6) col = tonemap(col);
    col = sqrt(max(col, 0.0));
    // Dither: nudge each pixel by up to one step of the 0..255 range, in a
    // fine noise pattern, or 8-bit colour draws bands across the dark sky.
    col += (fract(52.9829189 * fract(dot(fragCoord, vec2(0.06711056, 0.00583715)))) - 0.5) / 255.0;
    fragColor = vec4(col, 1.0);
}
