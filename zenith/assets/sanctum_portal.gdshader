shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled;
uniform float clock = 0.0;
uniform vec4 tint : source_color = vec4(0.25, 0.8, 0.75, 1.0);
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float ring = exp(-pow((r - 0.82) * 32.0, 2.0));
	float inner = exp(-pow((r - 0.76) * 65.0, 2.0));
	float runes = pow(abs(sin(a * 12.0 + clock * 0.06)), 18.0) * exp(-pow((r - 0.89) * 40.0, 2.0));
	float wisps = pow(0.5 + 0.5 * sin(a * 5.0 + r * 24.0 - clock * 0.45 + sin(a * 3.0 + clock * 0.2)), 5.0);
	float cloud = wisps * smoothstep(0.85, 0.1, r) * 0.25;
	ALBEDO = tint.rgb * 2.0;
	ALPHA = (ring + inner * 0.45 + runes * 0.65 + cloud) * smoothstep(1.0, 0.92, r);
}
