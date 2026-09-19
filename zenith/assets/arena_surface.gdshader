shader_type spatial;
render_mode unshaded;

uniform vec4 stone_color : source_color = vec4(0.045, 0.065, 0.085, 1.0);
uniform vec4 inlay_color : source_color = vec4(0.26, 0.21, 0.12, 1.0);

float line(float value, float target, float thickness) {
	return 1.0 - smoothstep(thickness, thickness + 0.006, abs(value - target));
}

void fragment() {
	vec2 p = (UV - 0.5) * vec2(1.4, 1.0);
	float radius = length(p);
	float angle = atan(p.y, p.x);
	float grain = fract(sin(dot(UV * 1800.0, vec2(12.9898, 78.233))) * 43758.5453);
	float edge = max(abs(p.x) / 0.7, abs(p.y));
	float circles = line(radius, 0.30, 0.001) * 0.24 + line(radius, 0.32, 0.001) * 0.16;
	float ticks = pow(abs(cos(angle * 24.0)), 36.0) * line(radius, 0.31, 0.008) * 0.6;
	float diamond = line(abs(p.x) + abs(p.y), 0.17, 0.001) * 0.35;
	float rim = line(max(abs(UV.x - 0.5), abs(UV.y - 0.5)), 0.483, 0.001);
	vec3 base = stone_color.rgb * (0.83 + grain * 0.18 + 0.3 * (1.0 - smoothstep(0.0, 0.65, radius)));
	ALBEDO = base + inlay_color.rgb * (circles + ticks + diamond + rim * 0.5);
}
