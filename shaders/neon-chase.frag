/*
    Blade Runner
    Wet neon night. Teal shadows, magenta highlights, pixel rain,
    and a few anamorphic bokeh specks.
    Rain slides in sub-pixel steps so it tracks the display rate
    instead of popping about once per game pixel.
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
    float lum = dot(src, vec3(0.299, 0.587, 0.114));

    vec3 shadows = vec3(0.02, 0.08, 0.14);
    vec3 highs = vec3(1.0, 0.45, 0.7);
    vec3 grade = mix(shadows, highs, smoothstep(0.02, 0.9, lum));
    grade = mix(grade, src, 0.4);
    grade *= vec3(0.85, 1.0, 1.15);

    vec2 gp = uv * inputSize;
    float rain = 0.0;
    for (int i = 0; i < 3; i++)
    {
        float fi = float(i);
        float cell = 5.0 + fi * 3.0;
        float speed = 22.0 + fi * 10.0;
        vec2 g = vec2(gp.x + sin(t * 0.4 + fi) * 2.0, gp.y - t * speed);
        vec2 cellId = floor(g / cell);
        vec2 loc = g - cellId * cell;
        float present = step(0.62, hash(cellId + fi * 9.0));
        // soft 1px streak so the edge moves every rendered frame
        float dropX = clamp(1.0 - abs(loc.x - 0.5) * 2.0, 0.0, 1.0);
        float dropY = smoothstep(0.4, 1.6, loc.y);
        rain = max(rain, present * dropX * dropY * (0.35 + fi * 0.2));
    }
    grade = mix(grade, vec3(0.75, 0.85, 0.95), rain);

    vec2 b = floor(uv * outputSize / 18.0);
    float twinkle = 0.5 + 0.5 * sin(t * 6.0 + hash(b) * 6.28318);
    float spec = step(0.97, hash(b)) * twinkle;
    grade += vec3(1.0, 0.55, 0.8) * spec * 0.35;

    float aspect = outputSize.x / max(outputSize.y, 1.0);
    float vig = length((uv - 0.5) * vec2(aspect, 1.0));
    grade *= 1.0 - smoothstep(0.4, 1.15, vig) * 0.45;

    return vec4(clamp(grade, 0.0, 1.0), 1.0);
}