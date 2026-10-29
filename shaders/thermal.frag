/*
    Thermal
    Thermal-camera palette: brightness is mapped from cold black-blue through
    purple, red and orange to hot yellow-white, with a little sensor noise.
*/

extern vec2 outputSize;
extern float time;

float hash(vec2 p)
{
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

vec3 heat(float x)
{
    vec3 c0 = vec3(0.00, 0.00, 0.10);
    vec3 c1 = vec3(0.25, 0.00, 0.55);
    vec3 c2 = vec3(0.85, 0.10, 0.20);
    vec3 c3 = vec3(1.00, 0.60, 0.05);
    vec3 c4 = vec3(1.00, 1.00, 0.85);

    x = clamp(x, 0.0, 1.0) * 4.0;
    if (x < 1.0) return mix(c0, c1, x);
    if (x < 2.0) return mix(c1, c2, x - 1.0);
    if (x < 3.0) return mix(c2, c3, x - 2.0);
    return mix(c3, c4, x - 3.0);
}

vec4 effect(vec4 vcolor, Image tex, vec2 uv, vec2 pixel_coords)
{
    float t = mod(time, 1000.0);

    vec3 col = Texel(tex, uv).rgb;
    float lum = dot(col, vec3(0.299, 0.587, 0.114));

    // sensor noise
    lum += (hash(floor(uv * outputSize * 0.5) + floor(t * 20.0)) - 0.5) * 0.06;

    return vec4(heat(lum), 1.0);
}