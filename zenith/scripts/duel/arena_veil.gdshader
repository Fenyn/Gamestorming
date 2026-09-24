shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

// A dark veil hung just above the flat cards while an exchange is live. It leaves a soft hole over
// the arena ring, so the cards standing there and the hand in front of the camera stay bright
// while the rest of the table recedes. `amount` fades it in and out.

uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform float darkness : hint_range(0.0, 1.0) = 0.88;
uniform vec2 plane_size = vec2(40.0, 40.0);
uniform float hole_radius = 0.9;
uniform float feather = 0.45;
uniform vec3 tint : source_color = vec3(0.02, 0.018, 0.016);

void fragment() {
	vec2 p = (UV - 0.5) * plane_size;
	float open = 1.0 - smoothstep(hole_radius, hole_radius + feather, length(p));
	ALBEDO = tint;
	ALPHA = amount * darkness * (1.0 - open);
}
