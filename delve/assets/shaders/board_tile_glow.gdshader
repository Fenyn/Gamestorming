// A board tile highlight in the FFT style: a translucent fill with a bright bevelled rim that
// breathes. The marker mesh spans UV 0..1 across the highlighted rect on flat and sloped boards.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.3, 0.6, 1.0, 0.35);
// Fill alpha as a fraction of the tint alpha.
uniform float fill_alpha : hint_range(0.0, 2.0) = 0.8;
// Rim width as a fraction of the tile side.
uniform float rim_width : hint_range(0.0, 0.5) = 0.1;
uniform float rim_alpha : hint_range(0.0, 1.0) = 0.95;
// Brightening of the rim colour. The nearest band's rim crosses the glow threshold and blooms, as in FFT.
uniform float rim_boost : hint_range(0.0, 2.0) = 1.2;
// Edges facing +U/+V catch the light, the opposite edges fall into shade.
uniform float bevel : hint_range(0.0, 1.0) = 0.35;
uniform float pulse_hz : hint_range(0.0, 4.0) = 0.7;
uniform float pulse_depth : hint_range(0.0, 1.0) = 0.25;
// A band fainter than this keeps only a trace of fill, so its rim carries it and the far bands
// do not flood the board with colour.
uniform float faint_below : hint_range(0.0, 1.0) = 0.3;
uniform float faint_fill : hint_range(0.0, 1.0) = 0.25;

void fragment() {
	vec2 uv = UV;
	float edge = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
	float rim = 1.0 - smoothstep(0.0, rim_width, edge);
	float lit = step(uv.x + uv.y, 1.0);
	float shade = mix(1.0 - bevel, 1.0 + bevel, lit);
	float breath = 1.0 - pulse_depth * (0.5 + 0.5 * sin(TIME * 6.2831853 * pulse_hz));
	vec3 rim_color = tint.rgb * (1.0 + rim_boost) * shade;
	ALBEDO = mix(tint.rgb, rim_color, rim);
	// Faint bands keep faint rims, so only the nearest band glows at full strength.
	float rim_strength = rim_alpha * clamp(tint.a * 1.4, 0.0, 1.0);
	float fill = tint.a * fill_alpha * breath * mix(faint_fill, 1.0, step(faint_below, tint.a));
	ALPHA = mix(fill, rim_strength, rim);
}
