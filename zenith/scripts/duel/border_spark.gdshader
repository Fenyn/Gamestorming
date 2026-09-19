shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec4 tint : source_color = vec4(1.0, 0.7, 0.2, 1.0);

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float glow = exp(-dot(p, p) * 5.0);
	float core = exp(-dot(p, p) * 40.0);
	ALBEDO = mix(tint.rgb, vec3(1.0), core * 0.25) * 1.2;
	EMISSION = tint.rgb * glow * 0.8;
	ALPHA = (glow + core) * COLOR.a * tint.a;
}
