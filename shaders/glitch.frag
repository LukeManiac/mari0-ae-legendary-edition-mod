/*
    Glitch
    Mild tearing and colour split, plus squares at fully random positions.
    A layout holds for 0.0625 seconds, then jumps to a new set.
    Square colour is a vivid hue, added onto the picture.
*/

extern vec2 inputSize;
extern float time;

float hash(vec2 p)
{
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

vec3 vivid(float h)
{
    vec3 rgb = clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
    return rgb;
}

vec4 effect(vec4 vcolor, Image tex, vec2 uv, vec2 pixel_coords)
{
    float t = mod(time, 1000.0);
    float seed = floor(t / 0.01);
    float jitter = seed;

    float strip = floor(uv.y * inputSize.y / 10.0);
    float torn = step(0.72, hash(vec2(strip, seed)));
    float shift = (hash(vec2(strip + 3.0, seed)) - 0.5) * 0.035 * torn;
    shift += (hash(vec2(strip, jitter)) - 0.5) * 0.004 * torn;
    vec2 p = vec2(fract(uv.x + shift), uv.y);

    float s = 0.8 / max(inputSize.x, 1.0) + 0.0025 * hash(vec2(jitter, 5.0));
    float r = Texel(tex, p + vec2(s, 0.0)).r;
    float g = Texel(tex, p).g;
    float b = Texel(tex, p - vec2(s, 0.0)).b;
    vec3 col = vec3(r, g, b);

    vec2 pix = uv * inputSize;
    for (int i = 0; i < 8; i++)
    {
        float fi = float(i);
        vec2 centre = vec2(
            hash(vec2(seed, fi + 1.3)),
            hash(vec2(fi + 4.7, seed + 2.0))) * inputSize;
        vec2 halfSize = vec2(
            3.0 + hash(vec2(fi, seed + 6.0)) * 11.0,
            3.0 + hash(vec2(seed + 1.0, fi + 8.0)) * 8.0);
        vec2 d = abs(pix - centre);
        float inside = step(d.x, halfSize.x) * step(d.y, halfSize.y);
        vec3 rc = vivid(hash(vec2(fi + 2.0, seed + 3.0)));
        col += rc * inside * 0.65;
    }

    return vec4(clamp(col, 0.0, 1.0), 1.0);
}