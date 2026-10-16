// Overlay for whatever is under the crosshair. Adds a soft, pulsing rim light.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;

uniform vec4 rim_color : source_color = vec4(1.0, 0.82, 0.5, 1.0);
uniform float strength = 0.55;
uniform float rim_power = 2.2;
uniform float base_glow = 0.05;

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - facing, rim_power);
	float pulse = 0.8 + 0.2 * sin(TIME * 6.0);
	ALBEDO = rim_color.rgb * (rim * strength + base_glow) * pulse;
}
