/*
    Terminator
    T-800 vision: everything goes red, with scanlines, a sweeping scan
    bar, corner brackets and a column of jumping readout bars down the
    left side.
    Drop into shaders/ and pick "terminator" from the shader menu.
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

    // slight signal wobble
    float wob = (hash(vec2(floor(gp.y / 2.0), floor(t * 20.0))) - 0.5) * 0.0015;
    float lum = dot(Texel(tex, vec2(uv.x + wob, uv.y)).rgb, vec3(0.299, 0.587, 0.114));
    float v = pow(clamp(lum, 0.0, 1.0), 0.9) * 1.15;

    vec3 col = vec3(0.12, 0.0, 0.0) + vec3(1.0, 0.07, 0.03) * v;
    col *= 0.86 + 0.14 * sin(gp.y * 3.14159);

    // scan bar
    float d = abs(uv.y - fract(t * 0.18));
    col += vec3(0.55, 0.05, 0.02) * exp(-d * 60.0) * 0.5;

    // corner brackets, 8px in
    vec2 q = min(gp, inputSize - gp);
    float armH = step(8.0, q.y) * step(q.y, 9.2) * step(8.0, q.x) * step(q.x, 24.0);
    float armV = step(8.0, q.x) * step(q.x, 9.2) * step(8.0, q.y) * step(q.y, 24.0);
    float hud = max(armH, armV);

    // readout bars, seven rows of 10px
    float ry = (gp.y - 36.0) / 10.0;
    float row = floor(ry);
    float len = 6.0 + hash(vec2(row, floor(t * 3.0))) * 44.0;
    float bar = step(fract(ry), 0.4) * step(0.0, row) * step(row, 6.0)
              * step(10.0, gp.x) * step(gp.x, 10.0 + len);
    hud = max(hud, bar);

    col = mix(col, vec3(1.0, 0.25, 0.15), hud * 0.85);
    col *= 0.95 + 0.10 * hash(gp + floor(t * 30.0));

    return vec4(clamp(col, 0.0, 1.0), 1.0);
}