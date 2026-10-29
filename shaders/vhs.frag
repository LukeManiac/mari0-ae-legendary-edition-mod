/*
    VHS
    Worn tape look: colour bleed, line jitter, a rolling tracking-error band,
    tape noise and soft scanlines.
*/

extern vec2 inputSize;
extern vec2 outputSize;
extern float time;

float hash(vec2 p)
{
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

vec4 effect(vec4 vcolor, Image tex, vec2 uv, vec2 pixel_coords)
{
    float t = mod(time, 1000.0);
    float line = floor(uv.y * inputSize.y);
    float tick = floor(t * 30.0);

    // gentle wobble over the whole picture
    float wobble = sin(uv.y * inputSize.y * 0.25 + t * 4.0) * 0.0005;

    // rolling tracking band
    float bandPos = fract(t * 0.12);
    float bandDist = abs(uv.y - bandPos);
    float band = smoothstep(0.07, 0.0, bandDist);

    float jitter = (hash(vec2(line, tick)) - 0.5) * 0.02 * band;
    float bandShift = band * 0.012 * sin(uv.y * 60.0 + t * 20.0);

    vec2 p = vec2(uv.x + wobble + jitter + bandShift, uv.y);

    // colour bleed (red leads, blue lags)
    float o = 1.6 / inputSize.x + band * 0.004;
    float r = Texel(tex, p + vec2(o, 0.0)).r;
    float g = Texel(tex, p).g;
    float b = Texel(tex, p - vec2(o, 0.0)).b;
    vec3 col = vec3(r, g, b);

    // washed-out chroma, lifted blacks
    float lum = dot(col, vec3(0.299, 0.587, 0.114));
    col = mix(vec3(lum), col, 0.85) + 0.025;

    // scanlines
    col *= 0.93 + 0.07 * sin(uv.y * inputSize.y * 6.2832);

    // tape noise, stronger inside the band
    float n = hash(uv * outputSize + tick) - 0.5;
    col += n * (0.06 + 0.22 * band);

    // occasional white speckle dashes
    float speck = step(0.9993, hash(vec2(floor(uv.x * inputSize.x * 0.5), line + tick)));
    col += speck * 0.5;

    return vec4(clamp(col, 0.0, 1.0), 1.0);
}