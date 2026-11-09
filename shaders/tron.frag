/*
    Tron
    Tron: Legacy look. The picture drops to near black, edges light up as
    glowing neon lines (cyan, or orange on warm colours) and a faint
    circuit grid pulses across the dark areas.
    Drop into shaders/ and pick "tron" from the shader menu.
*/

extern vec2 inputSize;
extern float time;

float luma(vec3 c)
{
    return dot(c, vec3(0.299, 0.587, 0.114));
}

float lumaAt(Image tex, vec2 p)
{
    return luma(Texel(tex, p).rgb);
}

float edgeAt(Image tex, vec2 p, vec2 d)
{
    return abs(lumaAt(tex, p + vec2(d.x, 0.0)) - lumaAt(tex, p - vec2(d.x, 0.0)))
         + abs(lumaAt(tex, p + vec2(0.0, d.y)) - lumaAt(tex, p - vec2(0.0, d.y)));
}

vec4 effect(vec4 vcolor, Image tex, vec2 uv, vec2 pixel_coords)
{
    float t = mod(time, 1000.0);
    vec2 px = 1.0 / inputSize;
    vec2 gp = uv * inputSize;

    vec3 src = Texel(tex, uv).rgb;
    float lum = luma(src);

    // thin bright core plus a wider soft glow
    float core = smoothstep(0.08, 0.25, edgeAt(tex, uv, px));
    float glow = smoothstep(0.04, 0.35, edgeAt(tex, uv, px * 3.0));

    float warm = smoothstep(0.0, 0.35, src.r - src.b);
    vec3 neon = mix(vec3(0.10, 0.85, 1.00), vec3(1.00, 0.50, 0.05), warm);

    // light that travels along the circuits
    float pulse = 0.5 + 0.5 * sin(gp.x * 0.04 + gp.y * 0.04 - t * 2.5);

    // 16px circuit grid, mostly visible in the dark
    vec2 g = abs(fract(gp / 16.0) - 0.5);
    float lines = 1.0 - smoothstep(0.0, 0.05, min(0.5 - g.x, 0.5 - g.y));

    vec3 col = vec3(0.01, 0.025, 0.04) + lum * vec3(0.02, 0.09, 0.13);
    col += neon * (core * 1.1 + glow * 0.45) * (0.85 + 0.25 * pulse);
    col += vec3(0.05, 0.60, 0.80) * lines * (1.0 - lum) * 0.22 * (0.5 + pulse);

    return vec4(clamp(col, 0.0, 1.0), 1.0);
}