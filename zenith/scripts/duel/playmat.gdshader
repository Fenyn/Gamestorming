shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_never;

// A transparent print over the stone dais: each seat's half washed in its Mastery school's colour
// (ArenaAtmosphere.set_schools), fading out toward the board's edge, one faint rule along the
// centre line, and a darkening toward the frame's edges. Distances are in table units on a plane
// of `plane_size`, centred on the table. The stone itself is ArenaAtmosphere's `stone_tint` and
// `stone_brightness`. Whose turn it is shows on the TurnToken, not in the print.

uniform sampler2D fabric : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 plane_size = vec2(13.0, 8.2);
uniform float tile = 3.07;
// The wash: seat 0's colour on the +z half and seat 1's on the -z half, crossing over within
// `wash_blend` of the centre line; its opacity, the half size of the rectangle it covers fully,
// that rectangle's corner radius, and how far past it the wash fades out.
uniform vec4 wash_seat0 : source_color = vec4(0.45, 0.45, 0.45, 1.0);
uniform vec4 wash_seat1 : source_color = vec4(0.45, 0.45, 0.45, 1.0);
uniform float wash_blend = 0.6;
uniform float wash_alpha = 0.16;
uniform vec2 wash_half = vec2(3.7, 2.6);
uniform float wash_corner = 0.6;
uniform float wash_fade = 0.9;
uniform float weave = 0.35;
uniform vec4 ink : source_color = vec4(0.72, 0.68, 0.62, 0.08);
uniform float rule_half_length = 4.1;
// The vignette, in screen space: its centre (the board's, left of the HUD column), how dark the
// frame's corners get, and where the darkening starts and ends as a share of the distance from
// the screen centre to a corner.
uniform vec2 vignette_centre = vec2(0.42, 0.5);
uniform float vignette_strength = 0.35;
uniform float vignette_start = 0.55;
uniform float vignette_end = 1.1;

float round_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

// `top` (colour, alpha) laid over (col, alpha) with ordinary alpha blending.
vec4 over(vec4 under, vec3 top, float top_alpha) {
	float alpha = top_alpha + under.a * (1.0 - top_alpha);
	vec3 col = (top * top_alpha + under.rgb * under.a * (1.0 - top_alpha)) / max(alpha, 0.0001);
	return vec4(col, alpha);
}

void fragment() {
	vec2 p = (UV - 0.5) * plane_size;
	float inside = 1.0 - smoothstep(-wash_fade, 0.0, round_box(p, wash_half, wash_corner));
	// The fabric texture is khaki; its hue is dropped so the tint alone sets the wash's colour.
	float grain = dot(texture(fabric, p / tile).rgb, vec3(0.3, 0.59, 0.11));
	vec3 tint = mix(wash_seat1.rgb, wash_seat0.rgb, smoothstep(-wash_blend, wash_blend, p.y));
	vec4 print = vec4(tint * mix(1.0, grain * 1.4, weave), wash_alpha * inside);
	float line = (1.0 - smoothstep(0.012, 0.024, abs(p.y))) * (1.0 - smoothstep(rule_half_length - 0.4, rule_half_length, abs(p.x)));
	print = over(print, ink.rgb, line * ink.a);
	vec2 from_centre = (SCREEN_UV - vignette_centre) * 2.0 / sqrt(2.0);
	float vignette = vignette_strength * smoothstep(vignette_start, vignette_end, length(from_centre));
	print = over(print, vec3(0.0), vignette);
	ALBEDO = print.rgb;
	ALPHA = print.a;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
