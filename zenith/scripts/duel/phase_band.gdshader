shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

// Local units on the table plane: x along the centre line, y across it (the mesh's z).
uniform vec2 half_size = vec2(1.88, 0.135);
uniform float radius = 0.1;
uniform vec4 fill : source_color = vec4(0.02, 0.024, 0.03, 0.74);
uniform vec4 rim : source_color = vec4(0.86, 0.82, 0.74, 0.16);
uniform vec3 edge_color : source_color = vec3(1.0);
uniform float edge_alpha = 0.0;
uniform float edge_z = 0.135;
uniform float edge_width = 0.006;
uniform float edge_glow = 0.045;
uniform float edge_energy = 1.35;
uniform vec3 pool_color : source_color = vec3(1.0);
uniform float pool_alpha = 0.0;
uniform vec2 pool_center = vec2(0.0);
uniform vec2 pool_radius = vec2(0.21, 0.11);

varying vec2 p;

void vertex() {
	p = VERTEX.xz;
}

float rounded_box(vec2 q, vec2 b, float r) {
	vec2 d = abs(q) - b + r;
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - r;
}

vec4 over(vec4 under, vec3 rgb, float a) {
	float out_a = a + under.a * (1.0 - a);
	if (out_a <= 0.0001) {
		return vec4(0.0);
	}
	return vec4((rgb * a + under.rgb * under.a * (1.0 - a)) / out_a, out_a);
}

void fragment() {
	float d = rounded_box(p, half_size, radius);
	float aa = max(fwidth(d), 0.0005);
	float inside = 1.0 - smoothstep(-aa, aa, d);
	vec4 col = vec4(fill.rgb, fill.a * inside);

	vec2 q = (p - pool_center) / pool_radius;
	float pool = pool_alpha * exp(-dot(q, q) * 1.6) * inside;
	col = over(col, pool_color, pool);

	float rim_line = 1.0 - smoothstep(0.5 * aa, 1.5 * aa, abs(d + aa));
	col = over(col, rim.rgb, rim.a * rim_line);

	float dz = abs(p.y - edge_z);
	float az = max(fwidth(p.y), 0.0005);
	float run = 1.0 - smoothstep(half_size.x - radius - 0.2, half_size.x - 0.03, abs(p.x));
	float core = (1.0 - smoothstep(edge_width, edge_width + az, dz)) * run * edge_alpha;
	float glow = exp(-dz / edge_glow) * 0.5 * run * edge_alpha;
	col = over(col, edge_color, glow);
	col = over(col, mix(edge_color, vec3(1.0), 0.35) * edge_energy, core);

	ALBEDO = col.rgb;
	ALPHA = col.a;
}
