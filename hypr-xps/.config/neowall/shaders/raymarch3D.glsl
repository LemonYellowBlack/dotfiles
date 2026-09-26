// Kanagawa "Wave" palette, as normalized 0..1 floats for GLSL.
const vec3 sumiInk0    = vec3(0.086, 0.086, 0.114);  // #16161D
const vec3 crystalBlue = vec3(0.494, 0.612, 0.847);  // #7E9CD8
const vec3 fujiWhite   = vec3(0.863, 0.843, 0.729);  // #DCD7BA

// the 3D version of the line `d = length(p) - 0.3` from practice.glsl
// q is a 3vec point in space instead of a 2vec pixel position
// length(q) is the distance from q to the centerpoint [0,0,0]
// subtract 0.3 to get the signed distance to the surface of a sphere with radius 0.3
// if the result is negative, q is inside the sphere
float scene(vec3 q) {
    return length(q) - 0.3;
}

// the normal is the direction a surface faces at a point
// scene() grows fastest when moving straight away from the surface
// so nudge q a tiny bit along x, y and z and see how much scene() changes on each axis
// e.xyy = [0.001, 0, 0], e.yxy = [0, 0.001, 0], e.yyx = [0, 0, 0.001]
// normalize() scales the result to length 1, since only the direction matters
vec3 normalAt(vec3 q) {
    vec2 e = vec2(0.001, 0.0);
    return normalize(vec3(
        scene(q + e.xyy) - scene(q - e.xyy),
        scene(q + e.yxy) - scene(q - e.yxy),
        scene(q + e.yyx) - scene(q - e.yyx)));
}

// [r,g,b,a] out, [x, y] in; [0,0] is bottom-left
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // center and aspect-correct, same as practice.glsl
    // p is pixel position relative to the center of the screen [-0.5, 0.5] on y
    vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

    // ro (ray origin) is the camera, 1.5 units in front of the screen (+z is toward you)
    // rd (ray direction) points from the camera through this pixel, into the screen (-z)
    // the 1.5 in rd is the zoom: bigger = narrower view, smaller = wider view
    // 1.5 makes the sphere about as big on screen as the 0.3 circle in practice.glsl
    vec3 ro = vec3(0.0, 0.0, 1.5);
    vec3 rd = normalize(vec3(p, -1.5));

    // raymarching: walk along the ray until we hit something
    // t is how far along the ray we've gone; the current point is ro + rd * t
    // scene() says how far the nearest surface is, so stepping exactly that far
    // can never jump through it
    // loops need a constant bound in GLSL; break early on a hit or a miss
    float t = 0.0;
    bool hit = false;
    for (int i = 0; i < 64; i++) {
        float d = scene(ro + rd * t);
        if (d < 0.001) { hit = true; break; }   // close enough: we're on the surface
        t += d;
        if (t > 5.0) break;                     // gone past everything: background
    }

    vec3 background = sumiInk0;
    vec3 fillColor  = crystalBlue;

    vec3 col = background;
    if (hit) {
        vec3 n = normalAt(ro + rd * t);

        // light comes from the upper left, in front of the screen
        // sin/cos of iTime slowly swings it left and right so the shading moves
        vec3 lightDir = normalize(vec3(-0.6 + 0.4 * sin(iTime * 0.3), 0.6, 0.8));
        //vec3 lightDir = [0.6, 0.6, 0.6];

        // dot of two length-1 vectors = cosine of the angle between them
        // 1 facing the light, 0 at a right angle, negative facing away
        // max() clamps the far side to 0 instead of going negative (lambert / diffuse shading)
        float diffuse = max(dot(n, lightDir), 0.0);

        // 0.15 is ambient light, so the dark side isn't pure black
        col = fillColor * (0.15 + 0.85 * diffuse);
    }

    // note: a ray either hits or misses, so the edge is hard/jagged
    // the smoothstep trick from practice.glsl doesn't apply here - fixing that is a next step

    fragColor = vec4(col, 1.0);   // alpha 1.0 = fully opaque; 0.0 renders black
}
