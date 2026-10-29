/*
    Drunk
    The whole screen sways and breathes, with layered double vision and a
    slow wave that rolls up the picture.
*/

extern vec2 inputSize;
extern float time;

vec4 effect(vec4 vcolor, Image tex, vec2 uv, vec2 pixel_coords)
{
    float t = mod(time, 1000.0);

    // slow sway and breathing zoom around the centre
    vec2 sway = vec2(sin(t * 1.3) * 0.012, sin(t * 1.7 + 1.0) * 0.008);
    float zoom = 1.0 - 0.03 - 0.02 * sin(t * 0.9);
    vec2 p = (uv - 0.5) * zoom + 0.5 + sway;

    // wave rolling up the screen
    p.x += sin(uv.y * 9.0 - t * 2.2) * 0.004;
    p.y += sin(uv.x * 7.0 + t * 1.6) * 0.003;

    p = clamp(p, 0.0, 1.0);

    // double vision: two ghosts drifting in opposite directions
    vec2 drift = vec2(sin(t * 0.8), cos(t * 1.1)) * (6.0 / inputSize);
    vec3 a = Texel(tex, p).rgb;
    vec3 b = Texel(tex, clamp(p + drift, 0.0, 1.0)).rgb;
    vec3 c = Texel(tex, clamp(p - drift, 0.0, 1.0)).rgb;

    vec3 col = a * 0.5 + b * 0.25 + c * 0.25;

    // slightly warm and washed out
    float lum = dot(col, vec3(0.299, 0.587, 0.114));
    col = mix(vec3(lum), col, 0.9) * vec3(1.05, 1.0, 0.95);

    return vec4(clamp(col, 0.0, 1.0), 1.0);
}