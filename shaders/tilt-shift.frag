/*
    Tilt Shift
    Diorama / toy-world look: the middle band of the screen stays sharp and
    the top and bottom blur out, with a little extra saturation and contrast.

    Tweak with shaders:setParameter("tilt-shift", "focus", 0.22)
    and shaders:setParameter("tilt-shift", "strength", 3.0)
*/

extern vec2 inputSize;
extern float focus = 0.22;
extern float strength = 3.0;

vec4 effect(vec4 vcolor, Image tex, vec2 uv, vec2 pixel_coords)
{
    // how far outside the sharp band we are (0 inside, 1 at the screen edge)
    float off = clamp((abs(uv.y - 0.5) - focus) / (0.5 - focus), 0.0, 1.0);
    float radius = off * off * strength;          // blur radius in game pixels
    vec2 step = radius * 0.5 / inputSize;

    vec3 sum = vec3(0.0);
    float wsum = 0.0;

    for (int y = -2; y <= 2; y++)
    {
        for (int x = -2; x <= 2; x++)
        {
            vec2 o = vec2(float(x), float(y));
            float w = exp(-dot(o, o) / 3.0);
            sum += Texel(tex, uv + o * step).rgb * w;
            wsum += w;
        }
    }

    vec3 col = sum / wsum;

    // toy-like grading
    float lum = dot(col, vec3(0.299, 0.587, 0.114));
    col = mix(vec3(lum), col, 1.25);
    col = (col - 0.5) * 1.08 + 0.5;

    return vec4(clamp(col, 0.0, 1.0), 1.0);
}