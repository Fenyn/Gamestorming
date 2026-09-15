shader_type canvas_item;
render_mode unshaded;

uniform sampler2D noise_map : repeat_enable, filter_linear;

void fragment() {
    // Broad banks at the forest edge, with fine wisps moving across them.
    vec2 p = UV * vec2(1.4, 0.9);
    vec2 wind = vec2(TIME * 0.004, -TIME * 0.0015);
    float billow = texture(noise_map, p + wind).r * 0.7
        + texture(noise_map, p * 2.7 - wind * 1.3).r * 0.3;
    float sides = smoothstep(0.23, 0.49, abs(UV.x - 0.5));
    float distant = 1.0 - smoothstep(0.02, 0.34, UV.y);
    float foreground = smoothstep(0.82, 1.1, UV.y);
    float bank = max(max(sides, distant), foreground);
    float alpha = bank * (0.08 + smoothstep(0.18, 0.82, billow) * 0.60);
    vec3 tint = mix(vec3(0.12, 0.19, 0.20), vec3(0.34, 0.44, 0.42), billow);
    COLOR = vec4(tint, alpha);
}
