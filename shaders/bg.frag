#version 440
// Build-plate background: soft warm/teal gradient, a slowly drifting plate grid,
// "printed layer" lines rising from the bottom, and little hot specks of filament.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;        // accumulated animation time (already speed-scaled in QML)
    vec2 resolution;
    float energy;      // 0 = calm, 1 = excited (dragging / working)
    float quality;     // 1 = full, 0 = low power (skips specks)
    float night;       // 0 = warm day, 1 = dark slate (animated in QML)
};

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
               mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * noise(p);
        p = p * 2.02 + vec2(17.1, 3.7);
        a *= 0.5;
    }
    return v;
}

// 1 on a grid line, 0 elsewhere (soft edge, no derivatives so it runs on GLES too)
float gridLine(vec2 g, float w) {
    vec2 d = abs(fract(g - 0.5) - 0.5);
    return 1.0 - smoothstep(w * 0.5, w * 1.5, min(d.x, d.y));
}

void main() {
    vec2 uv = qt_TexCoord0;
    float asp = resolution.x / resolution.y;
    vec2 p = (uv - 0.5) * vec2(asp, 1.0);
    float t = time * 0.1;

    vec3 cream  = mix(vec3(1.00, 0.92, 0.82), vec3(0.060, 0.080, 0.115), night);
    vec3 sand   = mix(vec3(0.98, 0.84, 0.68), vec3(0.090, 0.115, 0.165), night);
    vec3 teal   = mix(vec3(0.72, 0.89, 0.88), vec3(0.050, 0.150, 0.190), night);
    vec3 orange = mix(vec3(1.00, 0.68, 0.40), vec3(0.420, 0.170, 0.060), night);

    // slow domain-warped colour field
    vec2 q = vec2(fbm(p * 1.2 + t * 0.5), fbm(p * 1.2 + vec2(5.2, 1.3) - t * 0.4));
    float r = fbm(p * 1.0 + 1.8 * q + vec2(t * 0.25, -t * 0.15));
    vec3 col = mix(cream, sand, smoothstep(0.25, 0.75, r));
    col = mix(col, teal, smoothstep(0.55, 0.95, q.y) * 0.75);
    col = mix(col, orange, smoothstep(0.62, 1.0, q.x) * (0.45 + 0.25 * night));

    // build-plate grid (minor every 1 unit, major every 5), drifting a little
    vec2 g = p * 11.0 + vec2(t * 0.8, t * 0.3);
    float minorL = gridLine(g, 0.03);
    float majorL = gridLine(g / 5.0, 0.012);
    vec3 gridCol = mix(vec3(0.45, 0.30, 0.18), vec3(0.65, 0.80, 1.0), night);
    col = mix(col, gridCol, minorL * (0.045 + 0.02 * night) + majorL * (0.085 + 0.04 * night));

    // printed layer lines: fine horizontal ridges that fade upward, wobbling slightly
    float base = -0.5;
    float height = 0.55 + 0.08 * sin(p.x * 2.3 + time * 0.25) + 0.05 * sin(p.x * 5.1 - time * 0.2);
    float mask = smoothstep(base + height, base + height - 0.35, p.y) * 0.9;
    float ly = (p.y - base) * 70.0 - time * (0.35 + 0.8 * energy);
    float ridge = smoothstep(0.0, 0.5, abs(fract(ly) - 0.5));
    vec3 ridgeCol = mix(vec3(1.0, 0.55, 0.20), vec3(1.0, 0.55, 0.25), night);
    col = mix(col, ridgeCol, (1.0 - ridge) * mask * (0.10 + 0.06 * energy + 0.04 * night));

    // hot specks of filament drifting up
    if (quality > 0.5) {
        for (int layer = 0; layer < 2; layer++) {
            float fl = float(layer);
            vec2 sg = p * (8.0 + 6.0 * fl) + vec2(0.0, -time * (0.07 + 0.04 * fl));
            vec2 id = floor(sg);
            vec2 f = fract(sg) - 0.5;
            float h = hash(id + fl * 31.0);
            vec2 pos = (vec2(hash(id + 1.7), hash(id + 9.2)) - 0.5) * 0.6;
            vec2 d = f - pos;
            float tw = 0.5 + 0.5 * sin(time * (0.7 + h * 2.0) + h * 6.2831);
            float core = exp(-dot(d, d) * (700.0 - 250.0 * fl));
            float on = step(0.80 - 0.12 * energy, h);
            col += mix(vec3(1.0, 0.62, 0.28), vec3(1.0, 0.70, 0.35), night) * core * tw * on
                   * (0.55 + 0.7 * energy + 0.5 * night);
        }
    }

    col = mix(col, col * 1.08 + vec3(0.04, 0.02, 0.0), energy);

    // vignette + grain
    col *= 1.0 - (0.22 + 0.22 * night) * dot(p * 0.9, p * 0.9);
    col += (hash(uv * resolution + fract(time)) - 0.5) * 0.022;

    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0) * qt_Opacity;
}
