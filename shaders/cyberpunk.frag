/*
    Cyberpunk
    Night City grade: teal shadows, hot pink and yellow highlights, neon
    bloom, lens colour fringing and a rare glitch where a few bands of
    the picture tear sideways for a third of a second.
    Drop into shaders/ and pick "cyberpunk" from the shader menu.
*/

extern vec2 inputSize;
extern float time;

float hash(vec2 p)
{
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float luma(vec3 c)
{
    return dot(c, vec3(0.299, 0.587, 0.114));
}

vec4 effect(vec4 vcolor, Image tex, vec2 uv, vec2 pixel_coords)
{
    float t = mod(time, 1000.0);
    vec2 gp = uv * inputSize;

    // rare glitch window
    float slot = floor(t * 3.0);
    float gate = step(0.96, hash(vec2(slot, 11.0)));
    float band = floor(gp.y / 12.0);
    float tear = step(0.7, hash(vec2(band, slot))) * gate;
    vec2 p = uv + vec2((hash(vec2(band, slot + 5.0)) - 0.5) * 0.06 * tear, 0.0);

    // fringing grows toward the corners, and while glitching
    vec2 ca = (p - 0.5) * (0.004 + 0.01 * gate);
    vec3 src = vec3(Texel(tex, p + ca).r, Texel(tex, p).g, Texel(tex, p - ca).b);
    float lum = luma(src);

    // split toning
    float shadows = 1.0 - smoothstep(0.0, 0.6, lum);
    float highs = smoothstep(0.4, 1.0, lum);
    float mids = 1.0 - abs(lum - 0.5) * 2.0;
    vec3 col = src;
    col = mix(col, vec3(lum) * vec3(0.55, 1.0, 1.15) + vec3(0.0, 0.05, 0.10), shadows * 0.8);
    col = mix(col, col * vec3(1.25, 0.75, 1.15), mids * 0.55);
    col = mix(col, col * vec3(1.35, 0.80, 0.95), highs * 0.6);
    col = mix(vec3(lum), col, 1.25) * 0.92;

    // neon bloom, pink with a little yellow on the hottest spots
    vec2 o = 2.0 / inputSize;
    float bl = (luma(Texel(tex, p + vec2(o.x, 0.0)).rgb) + luma(Texel(tex, p - vec2(o.x, 0.0)).rgb)
              + luma(Texel(tex, p + vec2(0.0, o.y)).rgb) + luma(Texel(tex, p - vec2(0.0, o.y)).rgb)) * 0.25;
    float glow = max(bl - 0.5, 0.0) * 1.5;
    vec3 hot = mix(vec3(1.0, 0.35, 0.70), vec3(1.0, 0.92, 0.20), smoothstep(0.7, 1.0, bl));
    col += hot * glow * 0.6;

    col += vec3(0.15, 0.0, 0.05) * tear;
    col = (col - 0.5) * 1.12 + 0.5;
    col *= 0.94 + 0.06 * sin(gp.y * 1.5708);

    float aspect = inputSize.x / inputSize.y;
    float r = length((uv - 0.5) * vec2(aspect, 1.0));
    col *= 1.0 - smoothstep(0.6, 1.2, r) * 0.35;

    return vec4(clamp(col, 0.0, 1.0), 1.0);
}