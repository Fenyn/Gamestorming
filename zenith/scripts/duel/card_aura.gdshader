shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform vec4 tint : source_color = vec4(0.5, 0.9, 1.0, 0.8);
uniform float selected = 0.0;

void fragment() {
	// A quiet edged silhouette, with bright corners instead of a filled rectangular slab.
	vec2 p = abs(UV - vec2(0.5));
	float edge = max(p.x, p.y);
	float rim = smoothstep(0.40, 0.455, edge) * (1.0 - smoothstep(0.475, 0.5, edge));
	float corners = smoothstep(0.30, 0.43, min(p.x, p.y));
	ALBEDO = tint.rgb;
	ALPHA = rim * tint.a * (0.4 + 0.6 * corners + selected * 0.25);
}
