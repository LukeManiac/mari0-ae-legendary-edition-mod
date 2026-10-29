/*
    Hologram
    Star Wars holoprojector look: cyan cast, rolling scan bands,
    horizontal jitter and a little RGB split. Alpha stays at 1
    so the premultiplied post pass does not punch holes in the frame.
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

    float jitter = (hash(vec2(floor(uv.y * inputSize.y), floor(t * 12.0))) - 0.5) * 0.004;
    jitter *= step(0.82, hash(vec2(floor(t * 8.0), 1.7)));

    vec2 uvr = uv + vec2(jitter + 0.002, 0.0);
    vec2 uvb = uv + vec2(jitter - 0.002, 0.0);
    vec3 src = vec3(
        Texel(tex, uvr).r,
        Texel(tex, uv + vec2(jitter, 0.0)).g,
        Texel(tex, uvb).b
    );

    float lum = dot(src, vec3(0.299, 0.587, 0.114));
    vec3 holo = vec3(0.25, 0.85, 1.0) * lum;

    float band = 0.75 + 0.25 * sin(uv.y * inputSize.y * 1.4 - t * 18.0);
    float sweep = smoothstep(0.015, 0.0, abs(fract(uv.y * 2.0 - t * 0.35) - 0.5) - 0.47);
    holo *= band;
    holo += vec3(0.55, 0.9, 1.0) * sweep * 0.25;

    float flick = 0.88 + 0.12 * hash(vec2(floor(t * 24.0), 4.2));
    holo *= flick;

    float aspect = outputSize.x / max(outputSize.y, 1.0);
    float r = length((uv - 0.5) * vec2(aspect, 1.0));
    holo *= 1.0 - smoothstep(0.45, 0.95, r);

    vec3 col = mix(src, holo, 0.78);
    return vec4(clamp(col, 0.0, 1.0), 1.0);
}