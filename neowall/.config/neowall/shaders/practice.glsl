// Kanagawa "Wave" palette, as normalized 0..1 floats for GLSL.
const vec3 sumiInk0   = vec3(0.086, 0.086, 0.114);  // #16161D
const vec3 crystalBlue  = vec3(0.494, 0.612, 0.847);  // #7E9CD8

// [r,g,b,a] out, [x, y] in; [0,0] is bottom-left
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // center and aspect-correct 
    // p is pixel position relative to the center of the screen
    // dividing by y makes units of distance relative to screen height [-0.5, 0.5]
    vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

    // p is a 2vec point in space relative to the centerpoint
    // length(p) is the euclidean distance of a pixel to that centerpoint
    // subtract 0.3 to get the signed distance of that pixel...
    // to a centered circle with radius 0.3's edge
    // if d is negative, the pixel is inside that circle
    float d = length(p) - 0.3;

    // smoothstep maps d to a 0..1 value based on where it falls between thresholds
    // smoothstep eases along an s-curve
    // between -0.005 and 0.005 is 0, the circle's edge
    // `1.0 -` flips the signage 
    // this results in a soft edge on the rim of the circle
    float shape = 1.0 - smoothstep(-0.005, 0.0025, d);

    vec3 background = sumiInk0;
    vec3 fillColor   = crystalBlue;

    // col is the [r,g,b] value of the pixel
    // mix(a, b, t) linearly blends a -> b as t goes 0 -> 1. (linear interpolation)
    // shape's value is 0 or 1 for all but the pixels between the thresholds 
    vec3 col = mix(background, fillColor, shape);

    fragColor = vec4(col, 1.0);   // alpha 1.0 = fully opaque; 0.0 renders black
}
