/*
    Dreamy Glow
    Soft bloom: bright areas are blurred outward in two rings and added back
    on top, with a light pastel lift for a hazy, storybook feel.

    Tweak with shaders:setParameter("dreamy-glow", "threshold", 0.55)
    and shaders:setParameter("dreamy-glow", "intensity", 1.0)
*/

extern vec2 inputSize;
extern float threshold = 0.55;
extern float intensity = 1.0;

vec4 effect(vec4 vcolor, Image tex, vec2 uv, vec2 pixel_coords)
{
    vec3 base = Texel(tex, uv).rgb;
    vec3 glow = vec3(0.0);

    // two rings of 8 taps, radius in game pixels
    for (int ring = 0; ring < 2; ring++)
    {
        float radius = 2.5 + float(ring) * 3.5;
        for (int i = 0; i < 8; i++)
        {
            float a = float(i) * 0.785398;
            vec2 o = vec2(cos(a), sin(a)) * radius / inputSize;
            vec3 s = Texel(tex, uv + o).rgb;
            glow += max(s - vec3(threshold), vec3(0.0));
        }
    }
    glow /= 16.0;

    vec3 col = base + glow * 2.2 * intensity;

    // pastel lift and a touch of warmth
    col = mix(col, vec3(1.0), 0.06);
    col *= vec3(1.03, 1.0, 1.04);

    return vec4(clamp(col, 0.0, 1.0), 1.0);
}