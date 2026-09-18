#ifdef GL_ES
precision mediump float;
#endif

vec4 effect(vec4 colour, Image texture, vec2 textureCoords, vec2 screenCoords)
{
    vec4 pixel = Texel(texture, textureCoords) * colour;

    // Calculate perceived luminance
    float luminance = dot(pixel.rgb, vec3(0.299, 0.587, 0.114));

    // Invert the luminance while preserving colour ratios
    float invertedLuminance = 1.0 - luminance;

    if (luminance > 0.0001)
    {
        pixel.rgb *= invertedLuminance / luminance;
    }
    else
    {
        pixel.rgb = vec3(invertedLuminance);
    }

    pixel.rgb = clamp(pixel.rgb, 0.0, 1.0);

    return pixel;
}