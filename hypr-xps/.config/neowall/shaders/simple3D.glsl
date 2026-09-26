// [r,g,b,a] out, [x, y] in; [0,0] is bottom-left
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // center and aspect-correct
    vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

    // camera 1.5 in front of the screen, ray through this pixel into the screen
    vec3 ro = vec3(0.0, 0.0, 1.5);
    vec3 rd = normalize(vec3(p, -1.5));

    // march: step forward by the distance to the sphere until we're on it
    float t = 0.0;
    for (int i = 0; i < 64; i++) {
        t += length(ro + rd * t) - 0.3;
    }
    vec3 hitPos = ro + rd * t;

    // missed if we never got onto the surface
    if (length(hitPos) - 0.3 > 0.001) {
        fragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    // a sphere at [0,0,0]: the normal is just the hit point, scaled to length 1
    vec3 n = normalize(hitPos);
    float light = max(dot(n, normalize(vec3(-1.0, 1.0, 1.0))), 0.0);

    fragColor = vec4(vec3(light), 1.0);
}
