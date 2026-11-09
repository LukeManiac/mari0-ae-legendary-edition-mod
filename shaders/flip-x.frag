/*
    FlipX
    Flips the whole picture mirroring it left to right.
    Up and down stay the same, so the controls still feel normal.
    Drop into shaders/ and pick "flip-x" from the shader menu.
*/

vec4 effect(vec4 vcolor, Image tex, vec2 uv, vec2 pixel_coords)
{
    vec4 src = Texel(tex, vec2(1.0 - uv.x, uv.y));
    return vec4(src.rgb, 1.0);
}