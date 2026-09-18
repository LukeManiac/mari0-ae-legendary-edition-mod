// invert.frag

vec4 effect(vec4 colour, Image texture, vec2 textureCoords, vec2 screenCoords)
{
    vec4 pixel = Texel(texture, textureCoords);

    // Invert RGB while preserving alpha
    pixel.rgb = 1.0 - pixel.rgb;

    return pixel * colour;
}