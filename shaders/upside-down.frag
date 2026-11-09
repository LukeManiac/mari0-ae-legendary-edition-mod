/*
    Upside Down
    Stranger Things: drained blue-grey world, slow breathing ripple, pale
    spores drifting up through the air and the odd red flash, like the
    storm outside the gate. Dark, heavy vignette.
    Drop into shaders/ and pick "upside-down" from the shader menu.
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

// one layer of ash and spores, size in game pixels, rising at speed px/s
float spores(vec2 gp, float size, float speed, float t)
{
    vec2 q = vec2(gp.x + sin(t * 0.7 + gp.y * 0.05) * 4.0, gp.y + t * speed);
    vec2 cell = floor(q / size);
    vec2 f = fract(q / size);

    vec2 pos = 0.2 + 0.6 * vec2(hash(cell), hash(cell + 17.0));
    float on = step(0.55, hash(cell + 41.0));
    float d = length(f - pos) * size;
    float r = 0.6 + hash(cell + 7.0) * 0.8;
    float twinkle = 0.6 + 0.4 * sin(t * 2.0 + hash(cell) * 6.28);

    return on * twinkle * (1.0 - smoothstep(r * 0.5, r * 1.4, d));
}

vec4 effect(vec4 vcolor, Image tex, vec2 uv, vec2 pixel_coords)
{
    float t = mod(time, 1000.0);
    vec2 gp = uv * inputSize;

    // the air breathes
    vec2 p = uv;
    p.x += sin(uv.y * 14.0 + t * 0.9) * 0.0016;
    p.y += sin(uv.x * 11.0 + t * 0.7) * 0.0016;

    vec3 src = Texel(tex, p).rgb;
    float lum = luma(src);

    // drained, cold and dark
    vec3 col = mix(vec3(lum), src, 0.22) * vec3(0.55, 0.78, 1.05);
    col = pow(clamp(col, 0.0, 1.0), vec3(1.25));

    // red flashes, a hard hit that fades out over the slot
    float slot = floor(t * 5.0);
    float flash = step(0.9, hash(vec2(slot, 3.0))) * (1.0 - fract(t * 5.0));
    col += vec3(0.30, 0.01, 0.01) * flash * (0.4 + lum);
    col = mix(col, col * vec3(1.5, 0.5, 0.45), flash * 0.45);

    // spores, two layers
    float sp = spores(gp, 14.0, 9.0, t) + 0.6 * spores(gp + 37.0, 22.0, 5.0, t);
    col += vec3(1.0, 0.85, 0.6) * sp * 0.55;

    float aspect = inputSize.x / inputSize.y;
    float r = length((uv - 0.5) * vec2(aspect, 1.0));
    col *= 1.0 - smoothstep(0.4, 1.1, r) * 0.7;

    return vec4(clamp(col, 0.0, 1.0), 1.0);
}