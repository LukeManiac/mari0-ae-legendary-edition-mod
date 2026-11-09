/*
    Spider-Verse
    Into the Spider-Verse print look: colour plates that sit slightly off
    register, flat posterised tones, magenta Ben-Day dots in the shadows
    and loose ink outlines. Paper grain is refreshed at 12fps, "on twos".
    Drop into shaders/ and pick "spiderverse" from the shader menu.
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

float lumaAt(Image tex, vec2 p)
{
    return luma(Texel(tex, p).rgb);
}

vec4 effect(vec4 vcolor, Image tex, vec2 uv, vec2 pixel_coords)
{
    float t = mod(time, 1000.0);
    vec2 px = 1.0 / inputSize;
    vec2 gp = uv * inputSize;

    // red and blue plates slip in opposite directions
    vec2 slip = px * vec2(1.4, 0.7);
    vec3 src;
    src.r = Texel(tex, uv + slip).r;
    src.g = Texel(tex, uv).g;
    src.b = Texel(tex, uv - slip).b;

    // punchy colour, then flat tones
    float lum = luma(src);
    vec3 col = mix(vec3(lum), src, 1.5);
    col = floor(clamp(col, 0.0, 1.0) * 5.0 + 0.5) / 5.0;
    lum = luma(col);

    // Ben-Day dots on a 45 degree screen, only where it is dark
    float k = 0.70710678;
    vec2 q = vec2(gp.x * k - gp.y * k, gp.x * k + gp.y * k) / 3.0;
    float dist = length(fract(q) - 0.5);
    float dark = 1.0 - smoothstep(0.2, 0.6, lum);
    float radius = 0.12 + dark * 0.42;
    float dots = (1.0 - smoothstep(radius - 0.08, radius + 0.08, dist)) * step(0.04, dark);
    col = mix(col, col * vec3(0.55, 0.15, 0.75), dots * 0.9);

    // ink lines from the luminance gradient
    float e = abs(lumaAt(tex, uv + vec2(px.x, 0.0)) - lumaAt(tex, uv - vec2(px.x, 0.0)))
            + abs(lumaAt(tex, uv + vec2(0.0, px.y)) - lumaAt(tex, uv - vec2(0.0, px.y)));
    float ink = smoothstep(0.10, 0.28, e);
    col = mix(col, vec3(0.06, 0.03, 0.14), ink * 0.85);

    // paper grain
    col += (hash(floor(gp) + floor(t * 12.0)) - 0.5) * 0.04;

    return vec4(clamp(col, 0.0, 1.0), 1.0);
}