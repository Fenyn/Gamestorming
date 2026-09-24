shader_type spatial;
render_mode cull_back;

// The hourglass playmat. One lobe per seat, a narrower waist between them where the fighters
// meet, and a ring at the centre for the cards in play. Outside the shape the stone table shows.
// Distances are in table units on a plane of `plane_size`, centred on the table.

uniform sampler2D fabric : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rim_fabric : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 plane_size = vec2(10.4, 7.4);
uniform float tile = 3.07;
uniform vec2 lobe_half = vec2(4.4, 1.62);
uniform float lobe_centre = 2.08;
uniform vec2 waist_half = vec2(2.4, 0.75);
uniform float ring_radius = 1.2;
uniform float corner = 0.3;
uniform float fillet = 0.35;
uniform float rim = 0.12;
uniform vec4 fabric_tint : source_color = vec4(0.50, 0.20, 0.20, 1.0);
uniform vec4 rim_tint : source_color = vec4(0.18, 0.14, 0.13, 1.0);
uniform vec4 ink : source_color = vec4(0.90, 0.86, 0.80, 0.45);

float round_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float smooth_union(float a, float b, float k) {
	float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
	return mix(b, a, h) - k * h * (1.0 - h);
}

float shape(vec2 p) {
	float lobes = min(
		round_box(p - vec2(0.0, lobe_centre), lobe_half, corner),
		round_box(p + vec2(0.0, lobe_centre), lobe_half, corner));
	float waist = round_box(p, waist_half, corner);
	return min(smooth_union(lobes, waist, fillet), length(p) - ring_radius);
}

float rule(float d, float width) {
	return 1.0 - smoothstep(width * 0.5, width, abs(d));
}

void fragment() {
	vec2 p = (UV - 0.5) * plane_size;
	float d = shape(p);
	if (d > 0.0) {
		discard;
	}
	vec2 uv = p / tile;
	// The fabric texture is khaki; its hue is dropped so the tint alone sets the mat's colour.
	vec3 weave = vec3(dot(texture(fabric, uv).rgb, vec3(0.3, 0.59, 0.11)));
	vec3 col = weave * fabric_tint.rgb * 1.4;
	col = mix(col, texture(rim_fabric, uv).rgb * rim_tint.rgb, smoothstep(-rim - 0.012, -rim + 0.012, d));
	// One printed rule round the arena. The rim alone marks the edge, so captions near it stay clear.
	float ink_mask = rule(length(p) - ring_radius + 0.1, 0.024);
	col = mix(col, ink.rgb, ink_mask * ink.a);
	ALBEDO = col;
	ROUGHNESS = 1.0;
}
