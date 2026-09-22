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

// This file has TWO mainImage functions. neowall splits them into passes by
// order: the first is Buffer A (hidden, keeps state between frames), the
// second is Image (what you see). practice2.neowall wires the channels.

// ===== Buffer A: smooth iMouseEnergy over time =====
// iMouseEnergy only updates ~4x per second, so using it directly makes things
// snap. This pass eases toward it a little each frame instead, and stores the
// eased value in the red channel. iChannel0 here is this buffer's own output
// from the previous frame (the "self" binding in the manifest) - that's the
// memory. Every pixel computes the same value, so the whole buffer is one
// flat colour; the Image pass can read it at any coordinate.
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    float target = iMouseEnergy;
    float prev = texture(iChannel0, vec2(0.5)).r;

    // Exponential smoothing. Smaller factor = slower, smoother easing.
    // 0.05 at 30fps settles in roughly two thirds of a second.
    float smoothed = mix(prev, target, 0.05);

    fragColor = vec4(smoothed, 0.0, 0.0, 1.0);
}

// ===== Image: the scene =====
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

    // iChannel0 here is Buffer A's output. Read the smoothed energy back out.
    float energy = texture(iChannel0, vec2(0.5)).r;

    // energy drives the orbit's size and the small circle's colour. Try
    // swapping `energy` for `iMouseEnergy` here to see the snapping come back.
    float radiusX = mix(0.275, 0.85, energy);
    float radiusY = mix(0.15, 0.5, energy);
    float orbitSpeed = 1.5;
    float angle = iTime * orbitSpeed;
    vec2 orbitPos = vec2(radiusX * cos(angle), radiusY * sin(angle));

    float d  = length(p) - 0.25;
    float d2 = length(p - orbitPos) - 0.025;

    float shape  = 1.0 - smoothstep(-0.005, 0.005, d);
    float shape2 = 1.0 - smoothstep(-0.005, 0.005, d2);

    vec3 dotColor = mix(fujiWhite, roninYellow, energy);

    // Depth from the orbit's own phase: sin(angle) is also what drives
    // orbitPos.y, so the upper half of the ellipse is the far side and the
    // lower half is the near side. step() is a 0/1 switch, so on any frame
    // exactly one of the two dot terms below is non-zero. The switch flips
    // at the far left/right of the orbit, where the big circle isn't, so
    // the handoff is never visible.
    float inFront = step(0.0, -sin(angle));

    vec3 col = mix(sumiInk0, dotColor, shape2 * (1.0 - inFront));   // far side: under the big circle
    col = mix(col, crystalBlue, shape);
    col = mix(col, dotColor, shape2 * inFront);                     // near side: over it

    fragColor = vec4(col, 1.0);
}
