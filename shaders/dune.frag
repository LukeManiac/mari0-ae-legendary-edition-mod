/*
    Dune
    Arrakis grade: the picture becomes a single burnt-orange gradient from
    deep brown shadows to pale sand highlights, with a hazy lifted black,
    soft bloom, a slow heat ripple and windblown sand streaks.
    Drop into shaders/ and pick "dune" from the shader menu.
*/

extern vec2 inputSize;
extern float time;

float hash(vec2 p)
{
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float luma(vec3 c)
{
    return dot(c, vec3(0.299, 0.587, 0.114));
}

vec4 effect(vec4 vcolor, Image tex, vec2 uv, vec2 pixel_coords)
{
    float t = mod(time, 1000.0);
    vec2 gp = uv * inputSize;

    // heat ripple, a little stronger toward the ground
    vec2 p = uv;
    p.x += sin(p.y * 90.0 + t * 2.0) * 0.0012 * (0.4 + uv.y);

    float lum = luma(Texel(tex, p).rgb);

    // cheap bloom from four wide taps
    vec2 o = 3.0 / inputSize;
    float bl = (luma(Texel(tex, p + vec2(o.x, 0.0)).rgb) + luma(Texel(tex, p - vec2(o.x, 0.0)).rgb)
              + luma(Texel(tex, p + vec2(0.0, o.y)).rgb) + luma(Texel(tex, p - vec2(0.0, o.y)).rgb)) * 0.25;
    lum = mix(lum, bl, 0.35) + max(bl - 0.60, 0.0) * 0.6;
    lum = pow(clamp(lum, 0.0, 1.0), 0.85);
    lum = clamp((lum - 0.5) * 1.3 + 0.5, 0.0, 1.0);

    // gradient map
    vec3 shadow = vec3(0.16, 0.06, 0.03);
    vec3 mid = vec3(0.86, 0.45, 0.14);
    vec3 high = vec3(1.00, 0.84, 0.58);
    vec3 col = lum < 0.5 ? mix(shadow, mid, lum * 2.0) : mix(mid, high, (lum - 0.5) * 2.0);

    // haze, then drifting sand
    col = mix(col, vec3(0.95, 0.55, 0.25), 0.12);
    float streak = hash(vec2(floor(gp.y * 0.7), floor((gp.x - t * 70.0) * 0.12)));
    col += vec3(1.0, 0.75, 0.45) * step(0.985, streak) * 0.12;

    // soft vignette and fine grain
    float aspect = inputSize.x / inputSize.y;
    float r = length((uv - 0.5) * vec2(aspect, 1.0));
    col *= 1.0 - smoothstep(0.5, 1.2, r) * 0.45;
    col += (hash(gp + floor(t * 24.0)) - 0.5) * 0.05;

    return vec4(clamp(col, 0.0, 1.0), 1.0);
}