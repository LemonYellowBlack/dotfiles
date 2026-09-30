// kanagawa-wave.glsl — Hokusai's Great Wave as a living sumi-e ink wash,
// painted only in Kanagawa "wave" palette colours.
//
// Reacts to the machine it runs on (neowall reactive uniforms):
//   real local time    sun and moon arc across the sky, sky tint follows  (iTimeOfDay, iSun)
//   real moon phase    approximate, derived from iDate
//   system audio       swell height and foam pump with bass and beat      (iAudioBass, iAudioBeat)
//   CPU load           wind: the whole sea drifts faster under load       (iCpu)
//   typing / mouse     spray flies off the great wave's crest             (iKeyEnergy, iMouseEnergy)
//   battery            horizon burns autumnRed when low and unplugged     (iBattery, iCharging)
//
// Budgeted for a 4K panel on an Intel iGPU: wave heights use 1D noise, each
// sea layer is only evaluated below its highest possible crest, the nearest
// layer claims the pixel first, and small details are gated to their regions.

#define SUMI0    vec3(0.086, 0.086, 0.114)   // #16161D
#define SUMI3    vec3(0.122, 0.122, 0.157)   // #1F1F28
#define WAVE1    vec3(0.133, 0.196, 0.286)   // #223249
#define WAVE2    vec3(0.176, 0.310, 0.404)   // #2D4F67
#define DRAGON   vec3(0.396, 0.522, 0.580)   // #658594
#define CRYSTAL  vec3(0.494, 0.612, 0.847)   // #7E9CD8
#define SPRING   vec3(0.498, 0.706, 0.792)   // #7FB4CA
#define ONI      vec3(0.584, 0.498, 0.722)   // #957FB8
#define FUJI     vec3(0.863, 0.843, 0.729)   // #DCD7BA
#define OLDW     vec3(0.784, 0.753, 0.576)   // #C8C093
#define CARP     vec3(0.902, 0.765, 0.518)   // #E6C384
#define AUTUMNY  vec3(0.863, 0.647, 0.380)   // #DCA561
#define SURIMI   vec3(1.000, 0.627, 0.400)   // #FFA066
#define AUTUMNR  vec3(0.765, 0.251, 0.263)   // #C34043

#define TAU 6.2831853

float kwSq(float x) { return x * x; }

// smoothstep with reversed edges is undefined in GLSL; use this instead
float kwDown(float lo, float hi, float x) { return 1.0 - smoothstep(lo, hi, x); }

float kwHash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// lattice cells wrap at 1024 so the hash stays precise after hours of drift.
// f is derived from the same floor() rather than fract(): with FMA contraction
// the two can round differently at an exact integer and leave a seam line.
float kwNoise1(float x) {
    float i = floor(x);
    float f = x - i;
    f = f * f * (3.0 - 2.0 * f);
    float a = kwHash(vec2(mod(i, 1024.0), 1.7));
    float b = kwHash(vec2(mod(i + 1.0, 1024.0), 1.7));
    return mix(a, b, f);
}

float kwNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = p - i;
    vec2 u = f * f * (3.0 - 2.0 * f);
    vec2 i0 = mod(i, 1024.0);
    vec2 i1 = mod(i + 1.0, 1024.0);
    float a = kwHash(i0);
    float b = kwHash(vec2(i1.x, i0.y));
    float c = kwHash(vec2(i0.x, i1.y));
    float d = kwHash(i1);
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// big > 0 selects the great wave: the whole profile is sheared rightwards
// with height, so the crest overhangs like a breaking wave
float kwHeight(vec2 p, float t, float base, float amp, float freq, float speed, float big,
               float bass, out float xs, out float bw) {
    bw = 0.0;
    xs = p.x;
    if (big > 0.0) {
        xs -= 0.7 * max(p.y - base, 0.0) * exp(-kwSq((p.x + 0.10) / 0.45));
        bw = exp(-kwSq((xs + 0.32) / 0.26));
    }
    float h = kwNoise1(xs * freq - t * speed) - 0.5;
    h += 0.5 * (kwNoise1(xs * freq * 2.3 + t * speed * 0.6 + 7.0) - 0.5);
    h += 0.12 * sin(xs * freq * 4.1 + t * speed * 1.7);
    float crest = 0.30 * (0.9 + 0.1 * sin(t * 1.3) + 0.35 * bass);
    return base + h * amp * (1.0 + 1.2 * bass) + bw * crest;
}

// lip: thickness of the plain foam band along this layer's crest
vec3 kwShade(vec2 p, float t, float d, float xs, float bw, vec3 deep, vec3 lit, float lip, float kick, float sun) {
    float sh = smoothstep(0.0, 0.14, d);
    float stripes = kwNoise(vec2(xs * 6.0 + t * 0.2, d * 40.0));
    vec3 body = mix(lit, deep, sh);
    body += (stripes - 0.5) * 0.18 * (1.0 - sh * 0.5);
    body *= 1.0 + 0.35 * sun;

    // foam: a bright lip along every crest, plus Hokusai's claw fingers
    // hanging off the great wave, each with its own position, width and length
    float fxp = xs * 20.0;
    float hcell = kwHash(vec2(mod(floor(fxp), 1024.0), 3.0));
    float fw = abs(fract(fxp) - (0.35 + 0.3 * hcell));
    float fingerDepth = (0.06 + 0.09 * hcell) * bw * smoothstep(-0.62, -0.36, xs);   // none on the back slope
    float tipT = clamp(d / max(fingerDepth, 0.001), 0.0, 1.0);
    float wAt = (0.30 + 0.15 * hcell) * sqrt(1.0 - tipT);
    float finger = kwDown(0.0, wAt + 0.03, fw) * step(d, fingerDepth);
    float speck = 0.55 + 0.45 * kwNoise(vec2(xs * 70.0, p.y * 70.0 - t * 1.5));
    float foam = max(kwDown(0.0, lip + 0.045 * bw, d), finger) * speck * (0.85 + 0.5 * kick);
    return mix(body, mix(OLDW, FUJI, speck), clamp(foam, 0.0, 1.0));
}

vec3 kwSky(vec2 p, float hy, float sun, float twilight, float lowBat, float cl) {
    float h = clamp((p.y - hy) / (0.5 - hy), 0.0, 1.0);   // 0 at horizon, 1 at top
    vec3 top = mix(SUMI0, mix(WAVE2, CRYSTAL, 0.45), sun);
    vec3 hor = mix(WAVE1, mix(SPRING, FUJI, 0.55), sun);
    vec3 sky = mix(hor, top, pow(h, 0.6));
    sky += AUTUMNY * twilight * exp(-h * 5.0) * 0.55;
    sky += SURIMI * twilight * exp(-h * 14.0) * 0.35;
    sky += AUTUMNR * lowBat * exp(-h * 6.0) * 0.6;
    // ink-wash cloud band
    float band = exp(-kwSq((p.y - 0.17) / 0.16));
    float ca = smoothstep(0.42, 0.72, cl) * band;
    vec3 cloud = mix(sky, mix(ONI, FUJI, 0.5), 0.35 + 0.25 * sun);
    return mix(sky, cloud, ca);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

    float live  = iAudioActive;
    float bass  = iAudioBass * live;
    float kick  = iAudioBeat * live;
    float spray = clamp(iKeyEnergy + iMouseEnergy, 0.0, 1.0);
    float sun   = clamp(iSun, 0.0, 1.0);
    float twilight = smoothstep(0.0, 0.12, sun) * kwDown(0.12, 0.45, sun);
    float lowBat = (1.0 - iCharging) * kwDown(0.08, 0.25, iBattery);
    float t = iTime * (0.30 + 0.5 * iCpu);
    float hy = -0.04;

    // sun and moon on opposite sides of a daily arc
    float u = (iTimeOfDay - 0.25) * TAU;
    vec2 sunP  = vec2(-0.72 * cos(u), hy + 0.46 * sin(u));
    vec2 moonP = vec2( 0.72 * cos(u), hy - 0.46 * sin(u));
    float sunUp  = smoothstep(hy - 0.08, hy + 0.05, sunP.y);
    float moonUp = smoothstep(hy - 0.08, hy + 0.05, moonP.y);

    vec3 col = vec3(0.0);
    float lay = 0.0;
    // envelope of where the sheared great wave can reach; sky above it skips the sea entirely
    float env = exp(-kwSq((p.x + 0.12) / 0.5));
    float xs3 = 0.0, bw3 = 0.0, d3 = -1.0;

    // sea: each layer gated by its highest possible crest, nearest layer first
    if (p.y < 0.45 * env) {
        float xs, bw, H, d;
        if (p.y < -0.28) {
            H = kwHeight(p, t, -0.40, 0.060, 1.3, 0.45, 0.0, bass, xs, bw);
            d = H - p.y;
            if (d >= 0.0) {
                col = kwShade(p, t, d, xs, bw, mix(SUMI3, WAVE1, 0.6), mix(WAVE2, DRAGON, 0.3), 0.016, kick, sun);
                lay = 4.0;
            }
        }
        if (lay == 0.0) {
            // the great wave; its height is kept for the spray above it
            H = kwHeight(p, t, -0.25, 0.070, 1.7, 0.36, 1.0, bass, xs3, bw3);
            d3 = H - p.y;
            if (d3 >= 0.0) {
                col = kwShade(p, t, d3, xs3, bw3, WAVE1, mix(WAVE2, CRYSTAL, 0.55), 0.02, kick, sun);
                lay = 3.0;
            }
        }
        if (lay == 0.0 && p.y < -0.03) {
            H = kwHeight(p, t, -0.13, 0.050, 2.2, 0.30, 0.0, bass, xs, bw);
            d = H - p.y;
            if (d >= 0.0) {
                col = kwShade(p, t, d, xs, bw, WAVE2, mix(DRAGON, CRYSTAL, 0.4), 0.012, kick, sun);
                lay = 2.0;
            }
        }
        if (lay == 0.0 && p.y < -0.015) {
            H = kwHeight(p, t, hy, 0.012, 3.0, 0.25, 0.0, bass, xs, bw);
            d = H - p.y;
            if (d >= 0.0) {
                col = kwShade(p, t, d, xs, bw, mix(WAVE2, DRAGON, 0.3), DRAGON, 0.005, kick, sun);
                lay = 1.0;
            }
        }
    }

    if (lay < 2.5) {
        vec2 cc = vec2(p.x * 1.8 + t * 0.06, p.y * 3.2 + 3.0);
        float cl = 0.65 * kwNoise(cc) + 0.35 * kwNoise(cc * 2.1 + 5.0);
        vec3 skyCol = kwSky(p, hy, sun, twilight, lowBat, cl);

        if (lay == 0.0) {
            col = skyCol;

            // stars
            vec2 sc = floor(fragCoord / (iResolution.y * 0.0022));
            float star = step(0.996, kwHash(sc + 7.0)) * (0.5 + 0.5 * sin(iTime * 2.0 + kwHash(sc) * 40.0));
            col += FUJI * star * (1.0 - sun) * smoothstep(hy, hy + 0.08, p.y) * 0.85;

            // sun
            float ds = length(p - sunP);
            col += mix(SURIMI, CARP, sun) * (0.012 / (ds + 0.02)) * sunUp * 0.8;
            col = mix(col, mix(CARP, FUJI, 0.4), kwDown(0.040, 0.045, ds) * sunUp);

            // moon with (approximate) real phase; waxing moons are lit on the right
            float days = (iDate.x - 2000.0) * 365.25 + iDate.y * 30.6 + iDate.z - 6.0;
            float phase = fract(days / 29.530588);
            float kph = cos(phase * TAU);                        // 1 new, -1 full
            float side = phase < 0.5 ? -1.0 : 1.0;
            float dm = length(p - moonP);
            float moonDisc = kwDown(0.036, 0.040, dm);
            float shadow = kwDown(0.037, 0.041, length(p - (moonP + vec2(side * 0.04 * (1.0 - kph), 0.0))));
            col += CRYSTAL * (0.008 / (dm + 0.02)) * moonUp * (1.0 - sun) * 0.9;
            col = mix(col, WAVE1, moonDisc * shadow * 0.55 * moonUp);
            col = mix(col, mix(FUJI, OLDW, 0.3), moonDisc * (1.0 - 0.94 * shadow) * moonUp);

            // Mount Fuji, small and far, as Hokusai placed it
            float fx = p.x - 0.46;
            if (abs(fx) < 0.26 && p.y > hy && p.y < hy + 0.12) {
                float ft = abs(fx) / 0.26;
                float fh = 0.11 * pow(1.0 - ft, 1.6);
                float fujiTop = hy + fh;
                float fMask = kwDown(fujiTop - 0.0015, fujiTop + 0.0015, p.y);
                float snowLine = hy + 0.072 + 0.010 * (kwNoise(vec2(fx * 60.0, 2.0)) - 0.5);
                float snow = smoothstep(snowLine - 0.006, snowLine + 0.006, p.y);
                vec3 fujiCol = mix(WAVE2, WAVE1, kwDown(0.0, 0.08, p.y - hy));
                fujiCol = mix(fujiCol, FUJI, snow * 0.8);
                fujiCol = mix(fujiCol, col, 0.30 + 0.25 * (1.0 - sun));
                col = mix(col, fujiCol, fMask);
            }
        } else {
            // distance haze on the far water, plus moon and sun glitter
            float hz = mix(0.25, 0.55, step(lay, 1.5)) * smoothstep(-0.25, hy, p.y);
            col = mix(col, skyCol, hz);
            float gl = smoothstep(0.55, 0.9, kwNoise(vec2(p.x * 90.0 + t, p.y * 240.0 - t * 3.0)));
            col += SPRING * exp(-abs(p.x - moonP.x) * 4.0) * moonUp * (1.0 - sun) * gl * 0.20;
            col += CARP   * exp(-abs(p.x - sunP.x)  * 4.0) * sunUp  * sun         * gl * 0.14;
        }
        col *= 0.94 + 0.08 * cl;   // ink mottling on the wash
    }

    // spray flying off the great wave's crest, in front of everything behind it
    if (lay < 3.5 && d3 < 0.0 && d3 > -0.12) {
        vec2 sp = vec2(xs3, p.y) * 150.0 + vec2(0.0, -t * 1.2);
        float dotv = step(0.982 - 0.015 * (kick + spray) - 0.01 * bw3, kwHash(mod(floor(sp), 1024.0) + 11.0));
        float dotShape = kwDown(0.18, 0.38, length(fract(sp) - 0.5));
        float above = smoothstep(-0.12, -0.01, d3);
        col = mix(col, FUJI, clamp(dotv * dotShape * above * (bw3 * 0.9 + spray * 0.6), 0.0, 1.0));
    }

    // paper grain and vignette
    col *= 0.95 + 0.07 * kwHash(fragCoord * 0.37);
    float vig = smoothstep(0.5, 1.15, length(p * vec2(0.8, 1.3)));
    col = mix(col, SUMI0, vig * 0.5);

    // the artist's red seal
    vec2 q = p - vec2(0.80, -0.42);
    if (abs(q.x) < 0.03 && abs(q.y) < 0.038) {
        vec2 b = abs(q) - vec2(0.020, 0.028);
        float sd = length(max(b, 0.0)) + min(max(b.x, b.y), 0.0) - 0.004;
        sd += (kwNoise(q * 400.0) - 0.5) * 0.003;
        float seal = kwDown(-0.002, 0.002, sd);
        float carve = kwDown(-0.002, 0.002, sd + 0.006) * step(0.55, kwNoise(q * 180.0 + 5.0));
        col = mix(col, AUTUMNR, seal * (1.0 - carve));
    }

    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
