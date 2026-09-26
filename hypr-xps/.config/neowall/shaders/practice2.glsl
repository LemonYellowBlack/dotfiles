const vec3 sumiInk0   = vec3(0.086, 0.086, 0.114);  // #16161D
const vec3 fujiWhite  = vec3(0.863, 0.843, 0.729);  // #DCD7BA
const vec3 crystalBlue  = vec3(0.494, 0.612, 0.847);  // #7E9CD8
const vec3 roninYellow  = vec3(1.000, 0.620, 0.231);  // #FF9E3B

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
    float prev = texture(iChannel0, vec2(0.5)).r;
    
    float mouseTarget = iMouseEnergy;
    float heatTarget = iThermal;
    float cpuTarget = iCpu;

    // Exponential smoothing. Smaller factor = slower, smoother easing.
    // 0.05 at 30fps settles in roughly two thirds of a second.
    float mouseSmoothed = mix(prev, mouseTarget, 0.0125);
    float heatSmoothed = mix(prev, heatTarget,  0.01);
    float cpuSmoothed = mix(prev, cpuTarget, 0.01);


    //fragColor = vec4(mouseSmoothed, 0.0, 0.0, 1.0);
    //fragColor = vec4(heatSmoothed, 0.0, 0.0, 1.0);
    fragColor = vec4(cpuSmoothed, 0.0, 0.0, 1.0);
}

// ===== Image: the scene =====
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

    // iChannel0 here is Buffer A's output. Read the smoothed energy back out.
    float energy = texture(iChannel0, vec2(0.5)).r;

    // energy drives the orbit's size and the small circle's colour. Try
    // swapping `energy` for `iMouseEnergy` here to see the snapping come back.
    float radiusX = mix(0.275, 0.85, energy);
    float radiusY = mix(0.15, 0.45, energy);
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
