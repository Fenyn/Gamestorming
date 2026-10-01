shader_type canvas_item;

// The coach's thread to where the player should look. A glow runs along it from the box to the
// target every `period` seconds, and nothing past `reveal` (a share of its length) is drawn, so the
// thread can grow out of the box. Line2D gives UV.x along the line and UV.y across it.
uniform vec4 tint : source_color = vec4(0.93, 0.91, 0.87, 0.8);
uniform float reveal : hint_range(0.0, 1.0) = 1.0;
uniform float period = 1.4;
uniform float glow = 0.14;
uniform float motion : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	if (UV.x > reveal) {
		discard;
	}
	float head = fract(TIME / period);
	float pulse = motion * (1.0 - smoothstep(0.0, glow, abs(UV.x - head)));
	float across = 1.0 - abs(UV.y - 0.5) * 2.0;
	float alpha = tint.a * mix(0.6, 1.0, pulse) * smoothstep(0.0, 0.45, across);
	COLOR = vec4(mix(tint.rgb, vec3(1.0), pulse * 0.35), alpha);
}
