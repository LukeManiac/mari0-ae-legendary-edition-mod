/*
    Sin City
    Crushed blacks, blown whites and one colour left alive: red.
    Everything else is pushed to hard black and white, with a faint halo
    around the brights, film grain and a heavy vignette.
    Drop into shaders/ and pick "sincity" from the shader menu.
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
    vec2 gp = uv * inputSize;
    vec3 src = Texel(tex, uv).rgb;
    float lum = luma(src);

    // two passes of contrast for a hard, graphic split
    float ink = smoothstep(0.25, 0.60, lum);
    ink = smoothstep(0.0, 1.0, ink);

    // soft halo around the whites
    vec2 o = 2.0 / inputSize;
    float bl = (lumaAt(tex, uv + vec2(o.x, 0.0)) + lumaAt(tex, uv - vec2(o.x, 0.0))
              + lumaAt(tex, uv + vec2(0.0, o.y)) + lumaAt(tex, uv - vec2(0.0, o.y))) * 0.25;
    ink += smoothstep(0.6, 1.0, bl) * 0.22 * (1.0 - ink);

    // keep anything strongly red, as a flat saturated red
    float redness = src.r - max(src.g, src.b);
    float keep = smoothstep(0.18, 0.40, redness);
    vec3 red = vec3(1.0, 0.04, 0.05) * clamp(src.r * 1.3, 0.0, 1.0);
    vec3 col = mix(vec3(ink), red, keep);

    // grain and vignette
    col += (hash(floor(gp) + floor(t * 24.0)) - 0.5) * 0.07;
    float aspect = inputSize.x / inputSize.y;
    float r = length((uv - 0.5) * vec2(aspect, 1.0));
    col *= 1.0 - smoothstep(0.55, 1.10, r) * 0.6;

    return vec4(clamp(col, 0.0, 1.0), 1.0);
}