const vec3 sumiInk0   = vec3(0.086, 0.086, 0.114);  // #16161D
const vec3 crystalBlue  = vec3(0.494, 0.612, 0.847);  // #7E9CD8

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
   vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
   fragColor = vec4(sumiInk0, 1.0);
} 
