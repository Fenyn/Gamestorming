shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

// A band of grey metal light swept across a card face, lower left to upper right, as `sweep` runs
// from 0 to 1. Added over the face, so the card stays readable under it.
uniform vec4 tint : source_color = vec4(0.72, 0.76, 0.82, 1.0);
uniform float sweep : hint_range(0.0, 1.0) = 0.0;
uniform float width = 0.16;
uniform float strength = 0.9;

void fragment() {
	float diagonal = (UV.x + (1.0 - UV.y)) * 0.5;
	float centre = mix(-width, 1.0 + width, sweep);
	float band = 1.0 - smoothstep(0.0, width, abs(diagonal - centre));
	float fade = sin(sweep * 3.14159);
	ALBEDO = tint.rgb * band * strength * fade;
	ALPHA = band * fade;
}
