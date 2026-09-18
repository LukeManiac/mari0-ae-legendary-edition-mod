/*
    Colourful edge shader
    Based on Themaister's edge shader.
    Keeps the original edge colours instead of converting to grayscale,
    and avoids the strong contrast boost (5.0 multiplier).

    Suitable for subtle coloured outlines.
*/

extern vec2 textureSize;

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

    vec3 first  = mix(c00, c20, fract(tex_coords.x * texsize.x + 0.5));
    vec3 second = mix(c02, c22, fract(tex_coords.x * texsize.x + 0.5));
    vec3 res    = mix(first, second, fract(tex_coords.y * texsize.y + 0.5));

    // Coloured edge difference with no forced high contrast.
    vec3 edge = abs(res - c11);

    return vec4(clamp(edge, 0.0, 1.0), 1.0);
}