shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform vec4 tint : source_color = vec4(0.5, 0.9, 1.0, 0.8);
uniform float selected = 0.0;
uniform float motion = 1.0;
// 0..1 thickens and brightens the filament for a card the pending prompt can act on.
uniform float highlight = 0.0;
uniform vec2 plane_size = vec2(0.693, 0.968);
uniform vec2 border_extent = vec2(0.318, 0.443);
// Widens the filament on a card the table draws small, so it keeps a readable width on screen.
uniform float thickness = 1.0;

void fragment() {
    // A narrow rounded filament at the card edge, with localized traveling highlights.
    vec2 p = (UV - vec2(0.5)) * plane_size;
    float radius = 0.025;
    vec2 q = abs(p) - (border_extent - vec2(radius));
    float distance_to_edge = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
    float phase = atan(p.y, p.x);
    float clock = TIME * motion;
    float ripple = sin(phase * 19.0 - clock * 5.0) * sin(phase * 7.0 + clock * 3.0) * 0.0012 * motion;
    float d = distance_to_edge + ripple;
    float core = exp(-pow(d / (mix(0.0023, 0.0038, highlight) * thickness), 2.0));
    float aura = exp(-pow(d / (mix(0.007, 0.011, highlight) * thickness), 2.0)) * mix(0.19, 0.34, highlight);
    float runner = pow(0.5 + 0.5 * sin(phase * 2.0 - clock * 2.8), 24.0);
    float strength = core * (0.8 + runner * 0.8 + selected * 0.15 + highlight * 0.45) + aura;
    ALBEDO = tint.rgb;
    EMISSION = tint.rgb * (0.5 + runner + highlight * 0.35);
    ALPHA = clamp(strength * tint.a, 0.0, 1.0);
}
