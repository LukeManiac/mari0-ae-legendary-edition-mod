/*
    Lightning
    Back to the Future / storm-scene flashes. Rare full-frame hits,
    a jagged bolt down the screen, and a small UV kick on each strike.
*/

extern vec2 inputSize;
extern vec2 outputSize;
extern float time;

float hash(float n)
{
    return fract(sin(n * 127.1) * 43758.5453);
}

float hash2(vec2 p)
{
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

vec4 effect(vec4 vcolor, Image tex, vec2 uv, vec2 pixel_coords)
{
    float t = mod(time, 1000.0);

    float slot = floor(t * 1.1);
    float local = fract(t * 1.1);
    float strike = step(0.72, hash(slot)) * exp(-local * 9.0);

    float kick = (hash(slot + 4.0) - 0.5) * strike * 0.012;
    vec3 src = Texel(tex, uv + vec2(kick, kick * 0.4)).rgb;

    float gy = floor(uv.y * inputSize.y);
    float wander = 0.0;
    wander += (hash2(vec2(floor(gy / 4.0), slot)) - 0.5) * 0.18;
    wander += (hash2(vec2(floor(gy / 12.0), slot + 1.0)) - 0.5) * 0.28;
    float bx = 0.5 + wander;
    float dx = abs(uv.x - bx) * outputSize.x;
    float bolt = exp(-dx * dx * 0.02) * strike;

    vec3 col = src * vec3(0.75, 0.82, 1.0);
    col += vec3(0.75, 0.85, 1.0) * strike * 0.55;
    col += vec3(0.9, 0.95, 1.0) * bolt;

    return vec4(clamp(col, 0.0, 1.0), 1.0);
}