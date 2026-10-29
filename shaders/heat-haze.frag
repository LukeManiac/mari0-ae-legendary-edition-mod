/*
    Heat Haze
    Rising shimmer that gets stronger toward the bottom of the screen, a warm
    colour grade and a pulsing ember glow. Good for castles and lava.
*/

extern vec2 inputSize;
extern float time;

vec4 effect(vec4 vcolor, Image tex, vec2 uv, vec2 pixel_coords)
{
    float t = mod(time, 1000.0);
    vec2 p = uv * inputSize;

    float k = 0.4 + 0.9 * uv.y;
    float dx = sin(p.y * 0.5 - t * 3.0 + sin(p.x * 0.2 + t)) * 0.7 * k;
    float dy = sin(p.x * 0.3 + t * 2.0) * 0.25 * k;

    vec2 q = uv + vec2(dx, dy) / inputSize;

    float split = 0.4 * k / inputSize.x;
    float r = Texel(tex, q + vec2(split, 0.0)).r;
    float g = Texel(tex, q).g;
    float b = Texel(tex, q - vec2(split, 0.0)).b;
    vec3 col = vec3(r, g, b);

    // warm grade
    col *= vec3(1.08, 1.0, 0.88);

    // ember glow rising from below
    float pulse = 0.7 + 0.3 * sin(t * 2.0 + p.x * 0.1);
    col += vec3(0.25, 0.08, 0.0) * pow(uv.y, 3.0) * pulse * 0.6;

    return vec4(clamp(col, 0.0, 1.0), 1.0);
}