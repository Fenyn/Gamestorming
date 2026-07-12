// Diagonal volumetric-style light shaft for HD-2D ambiance. Additive quad: a soft angled beam
// that fades toward the bottom and slowly sways/pulses. Place a ColorRect with this material
// over windows, tree canopies, or cave openings (see scenes/fx/light_shaft.tscn).
shader_type canvas_item;
render_mode blend_add;

uniform vec3 beam_color : source_color = vec3(1.0, 0.93, 0.72);
uniform float intensity : hint_range(0.0, 2.0) = 0.55;
uniform float angle : hint_range(-1.0, 1.0) = 0.35; // horizontal skew of the beam per unit height
uniform float beam_width : hint_range(0.05, 0.6) = 0.28;
uniform float sway_speed : hint_range(0.0, 4.0) = 0.5;
uniform float sway_amount : hint_range(0.0, 0.2) = 0.04;

void fragment() {
	// Beam center line skews with height and sways over time.
	float sway = sin(TIME * sway_speed) * sway_amount;
	float center = 0.5 + (UV.y - 0.5) * angle + sway * (1.0 - UV.y);
	float d = abs(UV.x - center);

	float across = smoothstep(beam_width, beam_width * 0.25, d);
	float along = (1.0 - UV.y) * smoothstep(0.0, 0.15, UV.y * 4.0);
	float pulse = 0.9 + 0.1 * sin(TIME * (sway_speed * 2.3) + UV.y * 3.0);

	COLOR = vec4(beam_color * intensity * across * along * pulse, 1.0);
}
