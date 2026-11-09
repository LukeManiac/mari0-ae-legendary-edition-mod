/*
    Upside Down
    Turns the whole picture upside down by mirroring it top to bottom.
    Left and right stay the same, so the controls still feel normal.
    Drop into shaders/ and pick "upside-down" from the shader menu.
*/

vec4 effect(vec4 vcolor, Image tex, vec2 uv, vec2 pixel_coords)
{
    vec4 src = Texel(tex, vec2(uv.x, 1.0 - uv.y));
    return vec4(src.rgb, 1.0);
}