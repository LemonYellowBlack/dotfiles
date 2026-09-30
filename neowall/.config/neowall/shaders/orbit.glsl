const vec3 sumiInk0    = vec3(0.086, 0.086, 0.114);  // #16161D
const vec3 fujiWhite   = vec3(0.863, 0.843, 0.729);  // #DCD7BA
const vec3 crystalBlue = vec3(0.494, 0.612, 0.847);  // #7E9CD8
const vec3 roninYellow = vec3(1.000, 0.620, 0.231);  // #FF9E3B

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec4  prev = texture(iChannel0, vec2(0.5));
    
    float cpuTarget  = iCpu;
    float ramTarget  = iRam;
    float heatTarget = iThermal;
    
    bool  warmup = iFrame < 2;

    float cpu  = warmup ? cpuTarget  : mix(prev.r, cpuTarget, 0.01);
    float ram  = warmup ? ramTarget  : mix(prev.g, ramTarget, 0.01);
    float heat = warmup ? heatTarget : mix(prev.b, heatTarget, 0.01);

    fragColor = vec4(cpu, ram, heat, 1.0);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2  p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

    float cpu  = texture(iChannel0, vec2(0.5)).r;
    float ram  = texture(iChannel0, vec2(0.5)).g;
    float heat = texture(iChannel0, vec2(0.5)).b;

    float radiusX    = mix(0.3, 0.6, cpu);
    float radiusY    = mix(0.125, 0.4, cpu);
    float orbitSpeed = mix(1.2, 1.7, ram);
    float angle      = iTime * orbitSpeed;
    vec2  orbitPos   = vec2(radiusX * cos(angle), radiusY * sin(angle));

    float d  = length(p) - 0.25;
    float d2 = length(p - orbitPos) - 0.025;

    float shape  = 1.0 - smoothstep(-0.005, 0.005, d);
    float shape2 = 1.0 - smoothstep(-0.005, 0.005, d2);

    vec3  dotColor = mix(fujiWhite, roninYellow, heat * 0.3);

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
