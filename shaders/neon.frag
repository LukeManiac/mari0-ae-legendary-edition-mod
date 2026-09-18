/*
    Neon Overlay Shader

    Full-screen rainbow tint with selectable blend modes.

    Hue cycle:
    - t = 0              -> hue = 0°
    - t = cycleTime / 4  -> hue = 90°
    - t = cycleTime / 2  -> hue = 180°
    - t = 3/4 cycleTime  -> hue = 270°
    - t = cycleTime      -> hue = 360° (= 0°)

    Blend modes:
    0  = Multiply
    1  = Additive
    2  = Color Burn
    3  = Color Dodge
    4  = Reflect
    5  = Overlay
    6  = Difference
    7  = Negation
    8  = Lighten
    9  = Darken
    10 = Screen
    11 = XOR
*/

extern float time;
extern float cycleTime = 5.0;
extern int blendMode = 0;

vec3 grayscale(vec3 color)
{
    return vec3(dot(color, vec3(0.3, 0.59, 0.11)));
}

vec3 hsv2rgb(vec3 c)
{
    vec3 rgb = clamp(
        abs(mod(c.x * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0,
        0.0,
        1.0
    );

    rgb = rgb * rgb * (3.0 - 2.0 * rgb);

    return c.z * mix(vec3(1.0), rgb, c.y);
}

vec3 blendMultiply(vec3 base, vec3 blend)
{
    return base * blend;
}

vec3 blendAdditive(vec3 base, vec3 blend)
{
    return min(base + blend, 1.0);
}

vec3 blendColorBurn(vec3 base, vec3 blend)
{
    return clamp(
        1.0 - (1.0 - base) / max(blend, vec3(0.001)),
        0.0,
        1.0
    );
}

vec3 blendColorDodge(vec3 base, vec3 blend)
{
    return clamp(
        base / max(vec3(1.0) - blend, vec3(0.001)),
        0.0,
        1.0
    );
}

vec3 blendReflect(vec3 base, vec3 blend)
{
    return clamp(
        base * base / max(vec3(1.0) - blend, vec3(0.001)),
        0.0,
        1.0
    );
}

vec3 blendOverlay(vec3 base, vec3 blend)
{
    return mix(
        2.0 * base * blend,
        1.0 - 2.0 * (1.0 - base) * (1.0 - blend),
        step(vec3(0.5), base)
    );
}

vec3 blendDifference(vec3 base, vec3 blend)
{
    return abs(base - blend);
}

vec3 blendNegation(vec3 base, vec3 blend)
{
    return 1.0 - abs(1.0 - base - blend);
}

vec3 blendLighten(vec3 base, vec3 blend)
{
    return max(base, blend);
}

vec3 blendDarken(vec3 base, vec3 blend)
{
    return min(base, blend);
}

vec3 blendScreen(vec3 base, vec3 blend)
{
    return 1.0 - (1.0 - base) * (1.0 - blend);
}

vec3 blendXor(vec3 base, vec3 blend)
{
    return abs(base + blend - 2.0 * base * blend);
}

vec3 applyBlendMode(vec3 base, vec3 blend)
{
    if (blendMode == 0)
        return blendMultiply(base, blend);

    if (blendMode == 1)
        return blendAdditive(base, blend);

    if (blendMode == 2)
        return blendColorBurn(base, blend);

    if (blendMode == 3)
        return blendColorDodge(base, blend);

    if (blendMode == 4)
        return blendReflect(base, blend);

    if (blendMode == 5)
        return blendOverlay(base, blend);

    if (blendMode == 6)
        return blendDifference(base, blend);

    if (blendMode == 7)
        return blendNegation(base, blend);

    if (blendMode == 8)
        return blendLighten(base, blend);

    if (blendMode == 9)
        return blendDarken(base, blend);

    if (blendMode == 10)
        return blendScreen(base, blend);

    if (blendMode == 11)
        return blendXor(base, blend);

    return blendMultiply(base, blend);
}

vec4 effect(vec4 vcolor, Image tex, vec2 tex_coords, vec2 pixel_coords)
{
    vec4 texcolor = Texel(tex, tex_coords);

    float hue = mod(time / cycleTime, 1.0);

    vec3 rainbow = hsv2rgb(vec3(hue, 1.0, 1.0));

    vec3 grey = grayscale(texcolor.rgb);

    vec3 result = applyBlendMode(grey, rainbow);

    return vec4(clamp(result, 0.0, 1.0), texcolor.a) * vcolor;
}