/*
    Vaporwave
    Maps brightness onto a navy > magenta > cyan > pink-white gradient, blends
    it with the original colours, then adds chromatic offset and scanlines.
    The gradient slowly breathes over time.
*/

extern vec2 inputSize;
extern vec2 outputSize;
extern float time;

vec3 gradient(float x)
{
    vec3 c0 = vec3(0.08, 0.02, 0.20);
    vec3 c1 = vec3(0.85, 0.15, 0.65);
    vec3 c2 = vec3(0.20, 0.90, 0.95);
    vec3 c3 = vec3(1.00, 0.90, 0.95);

    x = clamp(x, 0.0, 1.0) * 3.0;
    if (x < 1.0) return mix(c0, c1, x);
    if (x < 2.0) return mix(c1, c2, x - 1.0);
    return mix(c2, c3, x - 2.0);
}

vec4 effect(vec4 vcolor, Image tex, vec2 uv, vec2 pixel_coords)
{
    float t = mod(time, 1000.0);

    float o = 1.5 / inputSize.x;
    vec3 col;
    col.r = Texel(tex, uv + vec2(o, 0.0)).r;
    col.g = Texel(tex, uv).g;
    col.b = Texel(tex, uv - vec2(o, 0.0)).b;

    float lum = dot(col, vec3(0.299, 0.587, 0.114));
    lum += sin(t * 0.5) * 0.04;

    vec3 mapped = gradient(lum);
    col = mix(col, mapped, 0.75);

    // soft pink-to-cyan wash from top to bottom
    col += mix(vec3(0.10, 0.0, 0.08), vec3(0.0, 0.06, 0.10), uv.y) * 0.5;

    // scanlines
    col *= 0.94 + 0.06 * sin(uv.y * outputSize.y * 3.14159);

    return vec4(clamp(col, 0.0, 1.0), 1.0);
}