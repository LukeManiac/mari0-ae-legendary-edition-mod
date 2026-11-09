/*
    Hotline
    Hotline Miami trip: the whole screen sways, zooms on a ~130bpm beat,
    splits its colours on every hit and floods with shifting pink and
    cyan neon over boosted saturation and contrast.
    Drop into shaders/ and pick "hotline" from the shader menu.
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

    // sharp pulse that decays after each beat
    float beat = pow(0.5 + 0.5 * cos(t * 13.614), 5.0);

    // zoom punch and woozy sway
    vec2 p = (uv - 0.5) * (1.0 - 0.015 * beat) + 0.5;
    p.x += sin(p.y * 22.0 + t * 3.0) * (0.0025 + 0.004 * beat);
    p.y += sin(p.x * 16.0 - t * 2.3) * (0.002 + 0.003 * beat);

    // colour split that spikes on the beat
    vec2 ca = vec2(0.002 + 0.007 * beat, 0.0);
    vec3 col = vec3(Texel(tex, p + ca).r, Texel(tex, p).g, Texel(tex, p - ca).b);

    // saturation and contrast
    float lum = dot(col, vec3(0.299, 0.587, 0.114));
    col = mix(vec3(lum), col, 1.6);
    col = (col - 0.5) * 1.25 + 0.5;

    // neon wash drifting between pink and cyan
    float sweep = 0.5 + 0.5 * sin(t * 0.8 + uv.y * 2.5 + uv.x * 1.5);
    vec3 tint = mix(vec3(1.0, 0.25, 0.75), vec3(0.2, 0.95, 1.0), sweep);
    col = mix(col, col * tint * 1.7, 0.6);

    col *= 0.94 + 0.06 * sin(gp.y * 3.14159);
    col += (hash(gp + floor(t * 24.0)) - 0.5) * 0.05;

    float aspect = inputSize.x / inputSize.y;
    float r = length((uv - 0.5) * vec2(aspect, 1.0));
    col *= 1.0 - smoothstep(0.5, 1.1, r) * 0.5;

    return vec4(clamp(col, 0.0, 1.0), 1.0);
}