shader_type canvas_item;

// The beat banner across the table: a band of colour that fades out toward both ends, so it reads
// as laid over the felt rather than as a box, with a darker rule along its top and bottom edges.
uniform vec4 tint : source_color = vec4(0.9, 0.38, 0.3, 0.85);
uniform float edge : hint_range(0.01, 0.5) = 0.18;
uniform float rule : hint_range(0.0, 0.2) = 0.05;

void fragment() {
	float fade = smoothstep(0.0, edge, UV.x) * smoothstep(0.0, edge, 1.0 - UV.x);
	float on_rule = step(UV.y, rule) + step(1.0 - rule, UV.y);
	vec3 rgb = mix(tint.rgb, tint.rgb * 0.55, clamp(on_rule, 0.0, 1.0));
	COLOR = vec4(rgb, tint.a * fade);
}
