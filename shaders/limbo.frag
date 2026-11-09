/*
    Limbo
    Soft grey silhouettes in a cold fog: heavy shadows, light falling from
    above, ground mist, strong film grain and a dark vignette.
    Drop into shaders/ and pick "limbo" from the shader menu.
*/

extern vec2 inputSize;
extern float time;

float hash(vec2 p)
{
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

vec4 effect(vec4 vcolor, Image tex, vec2 uv, vec2 pixel_coords)
{
    float t = mod(time, 1000.0);
    vec2 gp = uv * inputSize;

    // soft focus
    vec2 o = 1.3 / inputSize;
    vec3 s = Texel(tex, uv).rgb * 0.4
           + (Texel(tex, uv + vec2(o.x, 0.0)).rgb + Texel(tex, uv - vec2(o.x, 0.0)).rgb
            + Texel(tex, uv + vec2(0.0, o.y)).rgb + Texel(tex, uv - vec2(0.0, o.y)).rgb) * 0.15;
    float lum = dot(s, vec3(0.299, 0.587, 0.114));

    // heavy shadows
    lum = pow(clamp(lum, 0.0, 1.0), 1.7);

    // glow from above and mist near the ground
    float aspect = inputSize.x / inputSize.y;
    vec2 d = (uv - vec2(0.5, -0.05)) * vec2(aspect, 1.0);
    float light = exp(-length(d) * 1.4);
    float mist = smoothstep(0.55, 1.0, uv.y);

    float tone = lum * (0.55 + 0.6 * light);
    tone += mist * 0.25 * (1.0 - lum);

    vec3 col = vec3(tone) * vec3(0.94, 0.97, 1.0);

    // flicker, grain, vignette
    col *= 0.97 + 0.03 * hash(vec2(floor(t * 18.0), 2.0));
    col += (hash(floor(gp * 0.75) + floor(t * 24.0)) - 0.5) * 0.12;
    float r = length((uv - 0.5) * vec2(aspect, 1.0));
    col *= 1.0 - smoothstep(0.30, 0.95, r) * 0.9;

    return vec4(clamp(col, 0.0, 1.0), 1.0);
}