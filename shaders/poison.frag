/*
    Poison
    Sickly grade, a slow pulse, and pixel bubbles rising through the frame.
    Bubbles move in sub-pixel steps so the rise is not capped to the
    game-pixel clock.
    Drop into shaders/ and pick "poison" from the shader menu.
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

    // queasy wobble, kept small so jumps still read
    vec2 wobble = vec2(sin(uv.y * 18.0 + t * 2.4), cos(uv.x * 14.0 + t * 1.7)) * 0.003;
    vec3 src = Texel(tex, uv + wobble).rgb;

    float lum = dot(src, vec3(0.299, 0.587, 0.114));
    vec3 sick = vec3(0.18, 0.55, 0.08) * lum;
    sick += vec3(0.15, 0.35, 0.02) * (1.0 - lum);
    // bruise the reds so mushrooms and lava go livid
    sick.r += src.r * 0.25;
    sick.b *= 0.55;

    float pulse = 0.85 + 0.15 * sin(t * 3.2);
    sick *= pulse;

    // rising bubbles, three sizes, coverage so they glide
    vec2 gp = uv * inputSize;
    float bubbles = 0.0;
    for (int i = 0; i < 3; i++)
    {
        float fi = float(i);
        float cell = 10.0 + fi * 6.0;
        float speed = 7.0 + fi * 4.0;
        vec2 g = vec2(gp.x + sin(t * 0.8 + fi) * 2.0, gp.y + t * speed);
        vec2 cellId = floor(g / cell);
        vec2 loc = g - cellId * cell;
        vec2 centre = vec2(
            hash(cellId + fi) * (cell - 3.0) + 1.0,
            hash(cellId + fi + 5.0) * (cell - 3.0) + 1.0
        );
        float rad = 1.0 + hash(cellId + fi + 11.0) * (1.0 + fi);
        float present = step(0.55, hash(cellId + fi + 19.0));
        float d = abs(loc.x - centre.x) + abs(loc.y - centre.y);
        float ring = clamp(1.0 - abs(d - rad) / 0.85, 0.0, 1.0);
        bubbles = max(bubbles, present * ring * (0.45 + fi * 0.15));
    }
    sick = mix(sick, vec3(0.55, 0.95, 0.25), bubbles);

    // toxic vignette
    float aspect = outputSize.x / max(outputSize.y, 1.0);
    float r = length((uv - 0.5) * vec2(aspect, 1.0));
    sick *= 1.0 - smoothstep(0.4, 1.1, r) * 0.4;
    sick += vec3(0.05, 0.18, 0.0) * smoothstep(0.55, 1.15, r);

    vec3 col = mix(src, sick, 0.72);
    return vec4(clamp(col, 0.0, 1.0), 1.0);
}