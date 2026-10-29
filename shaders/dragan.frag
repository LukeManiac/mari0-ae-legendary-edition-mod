/*
    Dragan
    Paint.NET Dragan Effect, ReMake's method 2.

    Sharpen, then a high-pass layer blended with Paint.NET's Overlay
    (the base decides multiply or screen). A short contrast curve stands in
    for the levels step from method 1, which is what gives the crushed look.

    Neighbours are game pixels, so the sharpen actually crosses sprite
    edges instead of the scaled-up copies of one texel.

    Sharpness is 1..100. The plugin default is 5.
    Hue is -20..20 degrees. The plugin default is 0.
*/

extern vec2 inputSize;

const float sharpness = 5.0;
const float hue = 0.0;

vec3 canvas(Image tex, vec2 cell)
{
    return Texel(tex, (floor(cell) + 0.5) / inputSize).rgb;
}

float overlay(float base, float blend)
{
    return base < 0.5
        ? 2.0 * base * blend
        : 1.0 - 2.0 * (1.0 - base) * (1.0 - blend);
}

vec3 rgb2hsv(vec3 c)
{
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c)
{
    vec3 rgb = clamp(abs(mod(c.x * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
    return c.z * mix(vec3(1.0), rgb, c.y);
}

vec4 effect(vec4 vcolor, Image tex, vec2 uv, vec2 pixel_coords)
{
    float amount = clamp(sharpness, 1.0, 100.0) / 10.0;

    vec2 cell = floor(uv * inputSize);
    vec3 centre = canvas(tex, cell);

    vec3 blur = vec3(0.0);
    blur += canvas(tex, cell + vec2(-1.0, -1.0));
    blur += canvas(tex, cell + vec2( 0.0, -1.0));
    blur += canvas(tex, cell + vec2( 1.0, -1.0));
    blur += canvas(tex, cell + vec2(-1.0,  0.0));
    blur += canvas(tex, cell + vec2( 1.0,  0.0));
    blur += canvas(tex, cell + vec2(-1.0,  1.0));
    blur += canvas(tex, cell + vec2( 0.0,  1.0));
    blur += canvas(tex, cell + vec2( 1.0,  1.0));
    blur /= 8.0;

    vec3 sharpened = clamp(centre + (centre - blur) * amount, 0.0, 1.0);

    // high pass is the detail layer: centre minus a wider blur, biased to grey
    vec3 wide = blur * 0.65 + centre * 0.35;
    vec3 highpass = clamp((centre - wide) + 0.5, 0.0, 1.0);

    vec3 graded = vec3(
        overlay(sharpened.r, highpass.r),
        overlay(sharpened.g, highpass.g),
        overlay(sharpened.b, highpass.b)
    );

    graded = clamp((graded - 0.5) * 1.28 + 0.5, 0.0, 1.0);

    float hueShift = clamp(hue, -20.0, 20.0);
    if (abs(hueShift) > 0.01)
    {
        vec3 hsv = rgb2hsv(graded);
        hsv.x = fract(hsv.x + hueShift / 360.0);
        graded = hsv2rgb(hsv);
    }

    return vec4(graded, 1.0) * vcolor;
}