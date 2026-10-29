/*
    Retro Dither
    Posterises each colour channel to a few levels and hides the banding with
    an ordered Bayer dither, like an old 12-bit display.

    Tweak with shaders:setParameter("retro-dither", "levels", 4)
    (2 = harsh, 4 = default, 8 = subtle)
*/

extern vec2 inputSize;
extern float levels = 4.0;

float bayer2(vec2 a)
{
    a = floor(a);
    return fract(a.x / 2.0 + a.y * a.y * 0.75);
}

float bayer4(vec2 a)
{
    return bayer2(0.5 * a) * 0.25 + bayer2(a);
}

vec4 effect(vec4 vcolor, Image tex, vec2 uv, vec2 pixel_coords)
{
    vec2 cell = floor(uv * inputSize);
    vec2 snapped = (cell + 0.5) / inputSize;

    vec3 col = Texel(tex, snapped).rgb;

    // small saturation push so the reduced palette still pops
    float lum = dot(col, vec3(0.299, 0.587, 0.114));
    col = clamp(mix(vec3(lum), col, 1.2), 0.0, 1.0);

    float steps = max(levels, 2.0) - 1.0;
    float d = bayer4(cell) - 0.47;
    col = floor(col * steps + 0.5 + d) / steps;

    return vec4(clamp(col, 0.0, 1.0), 1.0);
}