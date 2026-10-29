/*
    Bullet time
    Matrix-style slow-mo grade: cold desat, radial zoom smear
    and a dark vignette. Eight taps, so it stays cheap on the post pass.
*/

extern vec2 outputSize;
extern float time;

vec4 effect(vec4 vcolor, Image tex, vec2 uv, vec2 pixel_coords)
{
    float t = mod(time, 1000.0);
    vec2 center = vec2(0.5, 0.46);
    vec2 dir = uv - center;

    vec3 acc = vec3(0.0);
    float wsum = 0.0;
    for (int i = 0; i < 8; i++)
    {
        float fi = float(i) / 7.0;
        float w = 1.0 - fi * 0.65;
        vec2 s = uv - dir * fi * 0.045;
        acc += Texel(tex, s).rgb * w;
        wsum += w;
    }
    vec3 src = acc / wsum;

    float lum = dot(src, vec3(0.299, 0.587, 0.114));
    vec3 grade = mix(vec3(lum), src, 0.28);
    grade *= vec3(0.75, 0.86, 1.05);

    grade *= 0.92 + 0.08 * sin(t * 1.7);

    float aspect = outputSize.x / max(outputSize.y, 1.0);
    float r = length((uv - 0.5) * vec2(aspect, 1.0));
    grade *= 1.0 - smoothstep(0.35, 1.05, r) * 0.55;

    return vec4(clamp(grade, 0.0, 1.0), 1.0);
}