/*
    Neon Edge Shader
    Based on edges.frag by Themaister (Public Domain)
    Modified for LOVE2D/Mari0.

    Rainbow neon effect:
    - Entire screen shares the same animated hue.
    - Hue cycles through the full colour wheel in cycleTime seconds.
    - t = 0              -> hue = 0°
    - t = cycleTime / 4  -> hue = 90°
    - t = cycleTime / 2  -> hue = 180°
    - t = 3/4 cycleTime  -> hue = 270°
*/

extern vec2 textureSize;
extern float time;
extern float cycleTime = 5.0;

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

vec4 effect(vec4 vcolor, Image tex, vec2 tex_coords, vec2 pixel_coords)
{
    vec4 texcolor = Texel(tex, tex_coords);

    float x = 0.5 / textureSize.x;
    float y = 0.5 / textureSize.y;
    vec2 dg1 = vec2( x, y);
    vec2 dg2 = vec2(-x, y);

    vec3 c00 = Texel(tex, tex_coords - dg1).xyz;
    vec3 c02 = Texel(tex, tex_coords + dg2).xyz;
    vec3 c11 = texcolor.xyz;
    vec3 c20 = Texel(tex, tex_coords - dg2).xyz;
    vec3 c22 = Texel(tex, tex_coords + dg1).xyz;

    vec2 texsize = textureSize;

    vec3 first = mix(c00, c20, fract(tex_coords.x * texsize.x + 0.5));
    vec3 second = mix(c02, c22, fract(tex_coords.x * texsize.x + 0.5));

    vec3 res = mix(first, second, fract(tex_coords.y * texsize.y + 0.5));

    // Original edge intensity
    float edge = clamp(
        5.0 * grayscale(abs(res - c11)).r,
        0.0,
        1.0
    );

    // Global rainbow hue cycle
    float hue = mod(time / cycleTime, 1.0);

    // Full-saturation neon colour
    vec3 neon = hsv2rgb(vec3(hue, 1.0, 1.0));

    return vec4(neon * edge, edge);
}