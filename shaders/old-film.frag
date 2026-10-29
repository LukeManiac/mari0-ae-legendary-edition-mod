/*
    Old Film
    Sepia silent-movie look: gate weave, lamp flicker, grain, vignette,
    vertical scratches and dust.
    Motion is interpolated between film frames so it is not held at 12fps.
    Grain is a fresh sample every rendered frame.
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
    float f = t * 12.0;
    float f0 = floor(f);
    float f1 = f0 + 1.0;
    float a = fract(f);

    // projector gate weave, slid between keys instead of stepped
    vec2 weave = mix(
        vec2(hash(vec2(f0, 1.0)), hash(vec2(f0, 2.0))),
        vec2(hash(vec2(f1, 1.0)), hash(vec2(f1, 2.0))),
        a);
    weave = (weave - 0.5) * 0.8 / inputSize;
    vec3 col = Texel(tex, uv + weave).rgb;

    // sepia
    vec3 sepia = vec3(
        dot(col, vec3(0.393, 0.769, 0.189)),
        dot(col, vec3(0.349, 0.686, 0.168)),
        dot(col, vec3(0.272, 0.534, 0.131)));
    col = mix(col, sepia, 0.9);

    // flicker, blended across the old 24fps keys
    float flick = mix(hash(vec2(f0, 7.0)), hash(vec2(f1, 7.0)), a);
    col *= 0.9 + 0.1 * flick;

    // vignette
    vec2 q = (uv - 0.5) * vec2(1.0, 0.9) * 1.5;
    col *= clamp(1.0 - dot(q, q) * 0.55, 0.0, 1.0);

    // grain, new every frame
    float grain = hash(floor(uv * outputSize * 0.5) + t) - 0.5;
    col += grain * 0.12;

    // vertical scratches, position slid so the line is not frozen
    float sx = mix(hash(vec2(f0, 11.0)), hash(vec2(f1, 11.0)), a);
    float scratchOn = step(0.65, hash(vec2(floor(t * 8.0), 13.0)));
    float scratch = step(abs(uv.x - sx), 0.5 / outputSize.x) * scratchOn;
    col += scratch * 0.3;

    // dust specks, reshuffled every frame
    vec2 cell = floor(uv * inputSize / 3.0);
    float dust = step(0.9985, hash(cell + t * 1.7));
    col *= 1.0 - dust * 0.6;

    return vec4(clamp(col, 0.0, 1.0), 1.0);
}