shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
uniform vec2 board_size = vec2(20.0);
uniform float margin = 12.0;
uniform float opacity = 0.23;
uniform float layer_phase = 0.0;
uniform vec4 mist_color : source_color = vec4(0.27, 0.36, 0.34, 1.0);
varying vec2 world_xz;
float hash(vec2 p) {
    vec3 q = fract(vec3(p.xyx) * 0.1031);
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
}
float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1,0)), f.x),
        mix(hash(i + vec2(0,1)), hash(i + vec2(1)), f.x), f.y);
}
void vertex() { world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz; }
void fragment() {
    vec2 outside = max(-world_xz, world_xz - board_size);
    float edge_distance = max(outside.x, outside.y);
    // Stay outside the playable rectangle; no distance haze across its floor or targeting grid.
    float outskirts = smoothstep(0.3, 3.5, edge_distance);
    float fade_outer = 1.0 - smoothstep(margin - 4.0, margin, edge_distance);
    vec2 p = world_xz * 0.17 + layer_phase;
    float t = TIME * 0.035;
    float bank = noise(p + vec2(t, -t * 0.3)) * 0.7
        + noise(p * 2.3 + vec2(-t * 0.8, 9.0)) * 0.3;
    ALBEDO = mist_color.rgb;
    ALPHA = outskirts * fade_outer * smoothstep(0.2, 0.85, bank) * opacity;
}
