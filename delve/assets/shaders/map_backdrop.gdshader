shader_type canvas_item;

// Foggy wilderness backdrop for the run map. Ridge silhouettes recede toward the top of the
// chart - deeper into the delve - under two slowly drifting fog layers, and a vignette keeps the
// edges dark so the node medallions stay the brightest thing on screen. The floor theme hands in
// its two palette colours; everything else is derived from them so the strata stay one family.

uniform vec4 base_color : source_color = vec4(0.086, 0.106, 0.094, 1.0);
uniform vec4 fog_color : source_color = vec4(0.353, 0.42, 0.365, 1.0);
uniform float fog_density : hint_range(0.0, 1.0) = 0.55;
uniform float drift_speed : hint_range(0.0, 0.2) = 0.018;
uniform float ridge_strength : hint_range(0.0, 1.0) = 0.65;

// Sin-free hash (Hoskins): the usual fract(sin(dot)) collapses into plateaus once its argument
// grows past a few thousand on GPU, which paints rectangular seams into the noise.
float hash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * vnoise(p);
        p *= 2.03;
        a *= 0.5;
    }
    return v;
}

void fragment() {
    vec2 uv = UV;
    float t = TIME * drift_speed;
    float far = 1.0 - uv.y; // 1 at the top of the chart, the deep end

    // Atmospheric perspective: the deep end sits lighter in haze, the near end darker.
    vec3 col = mix(base_color.rgb, fog_color.rgb, far * 0.26);

    // Ridge lines, farthest first so nearer ones paint over. Each crest carries a big rolling
    // swell plus a high-frequency fuzz that reads as a distant treeline; wide swells and soft
    // edges keep them from reading as flat bands.
    for (int k = 0; k < 3; k++) {
        float fk = float(k);
        float nearness = fk / 2.0;
        float crest = 0.72 - fk * 0.26
            + fbm(vec2(uv.x * (1.6 + fk * 0.8) + fk * 13.7, fk * 7.31)) * 0.17
            + vnoise(vec2(uv.x * 38.0 + fk * 31.0, fk)) * 0.03;
        float below = smoothstep(crest + 0.012, crest - 0.012, far);
        vec3 ridge_col = mix(
            mix(fog_color.rgb, base_color.rgb, 0.45),  // far ridge: half-swallowed by haze
            base_color.rgb * 0.82,                     // near ridge: nearly silhouette-black
            nearness);
        col = mix(col, ridge_col, below * ridge_strength * (0.3 + 0.7 * nearness));
    }

    // Two fog banks drifting against each other, denser toward the deep end.
    float f1 = fbm(uv * vec2(3.0, 2.2) + vec2(t, 0.0));
    float f2 = fbm(uv * vec2(5.2, 4.1) + vec2(-t * 1.7, t * 0.3) + 17.0);
    float fog = smoothstep(0.32, 0.85, f1 * 0.65 + f2 * 0.35);
    col = mix(col, fog_color.rgb, fog * fog_density * (0.4 + 0.45 * far));

    // Vignette so the chart's own frame swallows the corners.
    vec2 c = uv - 0.5;
    float vig = smoothstep(0.82, 0.3, length(c * vec2(1.15, 1.0)));
    col *= mix(0.68, 1.0, vig);

    COLOR = vec4(col, 1.0);
}
