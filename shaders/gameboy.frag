/*
    Game Boy
    4-shade green LCD look: luminance is quantised to 4 tones with ordered
    (Bayer) dithering, snapped to the game's pixel grid, plus a faint LCD grid.
*/

extern vec2 inputSize;
extern vec2 outputSize;

const vec3 shade0 = vec3(0.059, 0.220, 0.059);
const vec3 shade1 = vec3(0.188, 0.384, 0.188);
const vec3 shade2 = vec3(0.545, 0.675, 0.059);
const vec3 shade3 = vec3(0.608, 0.737, 0.059);

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
    float lum = dot(col, vec3(0.299, 0.587, 0.114));

    lum = clamp(lum * 1.15, 0.0, 1.0);
    lum += (bayer4(cell) - 0.47) * 0.22;

    float level = floor(clamp(lum, 0.0, 0.999) * 4.0);

    vec3 result = shade0;
    if (level > 2.5)      result = shade3;
    else if (level > 1.5) result = shade2;
    else if (level > 0.5) result = shade1;

    // faint LCD grid between game pixels (only when scaled up enough to see it)
    float s = outputSize.x / inputSize.x;
    vec2 f = fract(uv * inputSize);
    float lw = 1.0 / s;
    if (s > 1.5 && (f.x < lw || f.y < lw))
    {
        result *= 0.92;
    }

    return vec4(result, 1.0);
}