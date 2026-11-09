/*
    Pip-Boy
    Fallout terminal: bulging green phosphor tube with rounded black
    corners, banded tones, heavy scanlines, a slow rolling refresh band,
    glow and flicker.
    Drop into shaders/ and pick "pipboy" from the shader menu.
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

    // bulging glass: the edges and corners fall off the tube
    vec2 c = uv * 2.0 - 1.0;
    c *= 1.0 + 0.06 * dot(c, c);
    vec2 p = c * 0.5 + 0.5;
    float inside = step(0.0, p.x) * step(p.x, 1.0) * step(0.0, p.y) * step(p.y, 1.0);
    vec2 gp = p * inputSize;

    float lum = luma(Texel(tex, p).rgb);

    // phosphor glow
    vec2 o = 1.5 / inputSize;
    float bl = (luma(Texel(tex, p + vec2(o.x, 0.0)).rgb) + luma(Texel(tex, p - vec2(o.x, 0.0)).rgb)
              + luma(Texel(tex, p + vec2(0.0, o.y)).rgb) + luma(Texel(tex, p - vec2(0.0, o.y)).rgb)) * 0.25;
    lum = mix(lum, bl, 0.4) + max(bl - 0.7, 0.0) * 0.5;

    // banded tones
    lum = clamp(lum, 0.0, 1.0);
    lum = mix(lum, floor(lum * 7.0 + 0.5) / 7.0, 0.6);

    vec3 col = mix(vec3(0.0, 0.03, 0.01), vec3(0.20, 1.0, 0.35), lum);
    col += vec3(0.25, 0.30, 0.25) * pow(lum, 6.0) * 0.4;

    // scanlines, rolling band and flicker
    col *= 0.8 + 0.2 * sin(p.y * inputSize.y * 3.14159);
    float d = uv.y - fract(t * 0.1);
    col *= 1.0 + 0.25 * exp(-d * d * 200.0);
    col *= 0.97 + 0.03 * hash(vec2(floor(t * 30.0), 1.0));
    col += (hash(gp + floor(t * 30.0)) - 0.5) * 0.04;

    col *= 1.0 - dot(c, c) * 0.25;

    return vec4(clamp(col * inside, 0.0, 1.0), 1.0);
}