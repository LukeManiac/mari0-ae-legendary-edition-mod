/*
    Underwater
    Pixel-friendly wave distortion, deep blue-green tint, depth fade and
    drifting caustic light.
*/

extern vec2 inputSize;
extern float time;

vec4 effect(vec4 vcolor, Image tex, vec2 uv, vec2 pixel_coords)
{
    float t = mod(time, 1000.0);
    vec2 p = uv * inputSize;

    // wobble measured in game pixels
    vec2 d;
    d.x = sin(p.y * 0.35 + t * 2.0) * 0.8;
    d.y = cos(p.x * 0.25 + t * 1.6) * 0.4;

    vec3 col = Texel(tex, uv + d / inputSize).rgb;

    // water tint, darker with depth
    col *= vec3(0.55, 0.85, 1.10);
    vec3 deep = vec3(0.03, 0.18, 0.40);
    col = mix(col, deep, 0.12 + 0.28 * uv.y);

    // caustics
    float c = sin(p.x * 0.09 + sin(p.y * 0.11 + t) * 2.0)
            * sin(p.y * 0.08 + sin(p.x * 0.07 - t * 0.7) * 2.0);
    c = smoothstep(0.55, 1.0, c);
    col += vec3(0.35, 0.75, 0.9) * c * 0.2 * (1.0 - 0.6 * uv.y);

    return vec4(clamp(col, 0.0, 1.0), 1.0);
}