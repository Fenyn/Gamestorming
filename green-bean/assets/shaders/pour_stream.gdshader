// Thin stream of falling liquid. Apply to a unit cylinder stretched between two points.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

uniform vec4 stream_color : source_color = vec4(0.82, 0.9, 0.95, 0.55);
uniform float flow_speed = 3.0;

void vertex() {
	// Slight sideways waver so the stream doesn't look like a rod.
	float w = sin(TIME * 13.0 + VERTEX.y * 25.0) * 0.12;
	VERTEX.x += w * VERTEX.x;
	VERTEX.z += w * VERTEX.z;
}

void fragment() {
	float bands = 0.5 + 0.5 * sin((UV.y * 14.0 + TIME * flow_speed) * 6.2831);
	ALBEDO = stream_color.rgb * (0.9 + 0.2 * bands);
	ALPHA = stream_color.a * (0.75 + 0.25 * bands);
	ROUGHNESS = 0.1;
	SPECULAR = 0.8;
}
