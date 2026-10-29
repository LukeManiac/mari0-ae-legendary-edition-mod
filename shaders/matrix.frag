/*
    Matrix
    Digital rain over a green grade. The head and trail slide continuously
    with the display rate. Glyphs scroll with the rain instead of being
    held on a stepped clock.
    Drop into shaders/ and pick "matrix" from the shader menu.
*/

extern vec2 inputSize;
extern float time;

float hash(float n)
{
    return fract(sin(n * 127.1) * 43758.5453);
}

float hash2(vec2 p)
{
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

vec4 effect(vec4 vcolor, Image tex, vec2 uv, vec2 pixel_coords)
{
    float t = mod(time, 1000.0);
    vec3 src = Texel(tex, uv).rgb;

    vec2 gp = uv * inputSize;
    float colId = floor(gp.x / 2.0);
    float speed = 6.0 + hash(colId) * 18.0;
    float head = fract(hash(colId + 3.0) + t * speed * 0.04) * inputSize.y;
    float dist = mod(head - gp.y + inputSize.y, inputSize.y);

    float trailLen = 8.0 + hash(colId + 9.0) * 18.0;
    float trail = 1.0 - smoothstep(0.0, trailLen, dist);
    float glyph = step(0.45, hash2(vec2(colId, floor((gp.y - t * speed) / 2.0))));
    float rain = trail * glyph;
    float lead = 1.0 - smoothstep(0.0, 1.5, dist);

    float lum = dot(src, vec3(0.299, 0.587, 0.114));
    vec3 green = vec3(0.05, 0.35, 0.08) * lum;
    green += vec3(0.15, 0.85, 0.25) * rain * 0.85;
    green += vec3(0.7, 1.0, 0.75) * lead * glyph;

    vec3 col = mix(src, green, 0.72);
    return vec4(clamp(col, 0.0, 1.0), 1.0);
}