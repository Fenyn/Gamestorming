shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform vec4 tint : source_color = vec4(1.0, 0.3, 0.2, 0.7);
uniform float pulse = 1.0;
uniform float border_width = 0.035;
uniform float fill_opacity = 0.12;

void fragment() {
    float edge = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
    float border = 1.0 - smoothstep(border_width, border_width + 0.008, edge);
    ALBEDO = tint.rgb * pulse;
    ALPHA = tint.a * mix(fill_opacity, 0.85, border);
}
