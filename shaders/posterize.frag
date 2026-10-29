/*
    Posterize
    Photoshop Posterize, per channel, on the 8-bit values the frame is stored as.

    Levels is the number of output tones per channel (2 to 255). Photoshop's
    default is 4, which is 4 reds x 4 greens x 4 blues = 64 colours.
    Drop into shaders/ and pick "posterize" from the shader menu.

    The split is equal-width ranges of 0..255, not a round to the nearest
    reconstructed tone. Range i maps to floor(i * 255 / (levels - 1)):
        levels 2: 0..127 -> 0,   128..255 -> 255
        levels 4: 0..63 -> 0,    64..127 -> 85,  128..191 -> 170,  192..255 -> 255
    Alpha is left alone. Channels are not converted to linear light; Posterize
    runs on the stored channel values.

    Change the fallback below, or send the uniform from Lua:
        shaders:setParameter("posterize", "levels", 6)
    An unset uniform arrives as 0, which falls back to 4.
*/

extern float levels;

float quantize(float channel, float n)
{
    float v = clamp(floor(channel * 255.0 + 0.5), 0.0, 255.0);

    // 256 source codes split into n equal ranges. 255 must stay in the last one.
    float area = floor(v * n / 256.0);
    area = min(area, n - 1.0);

    // floor, with a tiny bias so 85.0 cannot collapse to 84 from float error
    float outv = floor(area * 255.0 / (n - 1.0) + 1e-4);
    return outv / 255.0;
}

vec4 effect(vec4 vcolor, Image tex, vec2 uv, vec2 pixel_coords)
{
    float n = floor(levels + 0.5);
    if (n < 2.0) n = 4.0;
    if (n > 255.0) n = 255.0;

    vec4 src = Texel(tex, uv);
    vec3 outc = vec3(
        quantize(src.r, n),
        quantize(src.g, n),
        quantize(src.b, n)
    );

    return vec4(outc, src.a) * vcolor;
}