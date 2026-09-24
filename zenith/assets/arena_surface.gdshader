shader_type spatial;
render_mode unshaded;

uniform vec4 stone_color : source_color = vec4(0.12, 0.20, 0.23, 1.0);
uniform vec4 inlay_color : source_color = vec4(0.40, 0.31, 0.17, 1.0);
uniform vec4 seat_zero : source_color = vec4(0.34, 0.74, 0.82, 1.0);
uniform vec4 seat_one : source_color = vec4(0.62, 0.56, 0.96, 1.0);
uniform float clock = 24.0;
// The surface is unshaded, so the lights never darken it: this scales the stone and falls it off
// towards the rim, so the table has depth instead of reading as one flat, milky field.
uniform float surface_gain = 0.72;
uniform float rim_shade = 0.5;
uniform sampler2D stone_texture : source_color, repeat_enable, filter_linear_mipmap;

float hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float line(float value, float target, float thickness) {
	return 1.0 - smoothstep(thickness, thickness + 0.006, abs(value - target));
}

void fragment() {
	vec2 p = (UV - 0.5) * vec2(1.4, 1.0);
	float radius = length(p);
	float angle = atan(p.y, p.x);
	float stone = noise(p * 14.0) * 0.6 + noise(p * 39.0) * 0.3 + noise(p * 120.0) * 0.1;
	float veins = pow(1.0 - abs(noise(p * 26.0 + stone * 2.0) * 2.0 - 1.0), 24.0);
	float circles = line(radius, 0.30, 0.0008) * 0.44 + line(radius, 0.33, 0.0005) * 0.3;
	circles += line(radius, 0.40, 0.0007) * 0.24;
	float ticks = pow(abs(cos(angle * 32.0)), 40.0) * line(radius, 0.315, 0.007) * 0.8;
	float diamond = line(abs(p.x) + abs(p.y), 0.185, 0.0005) * 0.3;
	float edge = max(abs(UV.x - 0.5), abs(UV.y - 0.5));
	float rim = line(edge, 0.478, 0.0015) + line(edge, 0.46, 0.0006) * 0.3;
	vec3 base = stone_color.rgb * (0.38 + stone * 0.40) + vec3(0.025, 0.040, 0.038) * veins * 0.08;
	vec3 mineral = texture(stone_texture, UV * vec2(2.8, 2.0)).rgb;
	float relief = dot(mineral, vec3(0.299, 0.587, 0.114));
	base *= 0.62 + relief * 1.5;
	base *= surface_gain * mix(1.0, rim_shade, smoothstep(0.22, 0.72, radius));
	vec3 school = mix(seat_one.rgb, seat_zero.rgb, smoothstep(-0.10, 0.10, p.y));
	float side_light = smoothstep(0.12, 0.65, abs(p.x)) * 0.038;
	base += school * side_light;
	float wear = 0.55 + noise(p * 75.0) * 0.45;
	base += inlay_color.rgb * (circles + ticks + diamond + rim * 0.65) * wear * 0.55;
	float breath = 0.75 + sin(clock * 0.55) * 0.12;
	vec3 magic = school * (line(edge, 0.489, 0.0006) * 0.32 + ticks * 0.04) * breath;
	ALBEDO = base;
	EMISSION = magic;
}
