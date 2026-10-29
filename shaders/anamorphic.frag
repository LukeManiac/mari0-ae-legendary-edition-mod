/*
    Anamorphic
    Cinema lens look: 2.39 bars, teal-and-orange grade, horizontal
    streak from bright pixels, fine grain. Meant to sit on a whole frame.
    Grain updates every rendered frame (no 24fps hold).
*/

extern vec2 inputSize;
extern vec2 outputSize;
extern float time;

float hash(vec2 p)
{
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

vec4 effect(vec4 vcolor, Image tex, vec2 uv, vec2 pixel_coords)
{
    float t = mod(time, 1000.0);
    vec3 src = Texel(tex, uv).rgb;

    // horizontal anamorphic streak, only from bright pixels
    vec3 streak = vec3(0.0);
    for (int i = 1; i <= 6; i++)
    {
        float o = float(i) * 3.0 / max(outputSize.x, 1.0);
        float w = 1.0 / float(i);
        vec3 a = Texel(tex, uv + vec2(o, 0.0)).rgb;
        vec3 b = Texel(tex, uv - vec2(o, 0.0)).rgb;
        float la = max(dot(a, vec3(0.299, 0.587, 0.114)) - 0.65, 0.0);
        float lb = max(dot(b, vec3(0.299, 0.587, 0.114)) - 0.65, 0.0);
        streak += (a * la + b * lb) * w;
    }
    src += streak * 0.55;

    float lum = dot(src, vec3(0.299, 0.587, 0.114));
    vec3 shadows = vec3(0.05, 0.16, 0.22);
    vec3 highs = vec3(1.0, 0.78, 0.45);
    vec3 grade = mix(shadows, highs, smoothstep(0.05, 0.85, lum));
    grade = mix(grade, src, 0.45);

    // new grain sample every frame, not held at 24fps
    float grain = hash(floor(uv * inputSize) + t) - 0.5;
    grade += grain * 0.035;

    // Full-fade 2.39 bars. Alpha runs 0, 0.25, 0.5, 0.75, 1 across the
    // whole band, not a solid block with a short edge fade.
    float barH = 0.12;
    float top = clamp(uv.y / barH, 0.0, 1.0);
    float bottom = clamp((1.0 - uv.y) / barH, 0.0, 1.0);
    grade *= min(top, bottom);

    return vec4(clamp(grade, 0.0, 1.0), 1.0);
}