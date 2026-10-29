/*
    Snowfall
    Three layers of pixel-sized snowflakes drifting down at different speeds
    over a cold blue grade. Flakes carry a 1px coverage so they slide at
    the display rate instead of popping from pixel to pixel.
*/

extern vec2 inputSize;
extern float time;

float hash(vec2 p)
{
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float flakes(vec2 gp, float cellSize, float speed, float seed, float t)
{
    vec2 g = vec2(gp.x + sin(t * 0.7 + seed) * 3.0, gp.y - t * speed);

    vec2 cell = floor(g / cellSize);
    vec2 loc = g - cell * cellSize;

    vec2 target = vec2(hash(cell + seed), hash(cell + seed + 17.0)) * cellSize;
    float present = step(0.5, hash(cell + seed + 41.0));

    float d = abs(loc.x - target.x) + abs(loc.y - target.y);
    float hit = clamp(1.0 - d, 0.0, 1.0);
    return hit * present;
}

vec4 effect(vec4 vcolor, Image tex, vec2 uv, vec2 pixel_coords)
{
    float t = mod(time, 1000.0);

    vec3 col = Texel(tex, uv).rgb;

    // cold grade
    col = mix(col, col * vec3(0.85, 0.95, 1.12), 0.5);

    vec2 gp = uv * inputSize;

    float s = 0.0;
    s = max(s, flakes(gp, 14.0, 6.0,  1.0, t) * 0.55);
    s = max(s, flakes(gp,  9.0, 10.0, 2.0, t) * 0.8);
    s = max(s, flakes(gp,  6.0, 16.0, 3.0, t));

    col = mix(col, vec3(0.95, 0.98, 1.0), s);

    return vec4(clamp(col, 0.0, 1.0), 1.0);
}