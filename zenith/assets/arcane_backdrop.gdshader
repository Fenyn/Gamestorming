shader_type canvas_item;
render_mode unshaded;

uniform vec4 school_color : source_color = vec4(0.34, 0.74, 0.82, 1.0);
uniform vec4 rival_color : source_color = vec4(0.62, 0.56, 0.96, 1.0);
uniform float clock = 24.0;
uniform float aspect = 1.7778;
uniform float pulse = 0.0;
uniform bool portrait = false;
uniform bool hall_visible = false;

float hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
		mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float cloud(vec2 p) {
	return noise(p) * 0.57 + noise(p * 2.03 + 7.0) * 0.28 + noise(p * 4.1) * 0.15;
}
float ring(float radius, float target, float width) {
	return 1.0 - smoothstep(width, width + 0.002, abs(radius - target));
}
void fragment() {
	vec2 p = (UV - 0.5) * vec2(aspect, 1.0);
	float stone = cloud(p * 7.0);
	float veins = pow(1.0 - abs(noise(p * 19.0 + stone * 2.0) * 2.0 - 1.0), 20.0);
	vec3 base = mix(vec3(0.027, 0.039, 0.085), vec3(0.075, 0.13, 0.17), stone);
	base += vec3(0.08, 0.13, 0.15) * veins * 0.10;
	vec2 center = portrait ? vec2(0.0, -0.03) : vec2(aspect * 0.28, -0.02);
	vec2 q = p - center;
	float radius = length(q);
	float angle = atan(q.y, q.x);
	float halo = exp(-radius * radius * (portrait ? 5.5 : 2.6));
	base += school_color.rgb * halo * (portrait ? 0.16 : 0.09);
	base += rival_color.rgb * exp(-length(p + vec2(aspect * 0.42, 0.12)) * 2.8) * 0.075;
	float etching = ring(radius, 0.32, 0.001) * 0.45 + ring(radius, 0.35, 0.002) * 0.6;
	etching += ring(radius, 0.39, 0.001) * 0.25;
	etching += ring(radius, 0.366, 0.012) * pow(abs(cos(angle * 28.0)), 22.0) * 0.65;
	etching += ring(max(abs(q.x * 0.707 + q.y * 0.707), abs(q.x * 0.707 - q.y * 0.707)), 0.245, 0.001) * 0.18;
	base += mix(vec3(0.32, 0.25, 0.14), school_color.rgb * 0.4, 0.3) * etching;
	float mist = cloud(p * vec2(3.0, 5.0) + vec2(clock * 0.013, -clock * 0.009));
	float banks = smoothstep(0.12, 0.52, abs(p.y)) + smoothstep(aspect * 0.25, aspect * 0.55, abs(p.x)) * 0.45;
	base += mix(vec3(0.075, 0.22, 0.25), school_color.rgb * 0.3, 0.4) * smoothstep(0.38, 0.82, mist) * banks;
	// Sparse drifting motes, stable in reduced motion. No textures or game RNG needed.
	vec2 field = p * 17.0 + vec2(clock * 0.035, clock * 0.14);
	vec2 cell = floor(field);
	vec2 point = fract(field) - vec2(0.2 + hash(cell) * 0.6, 0.2 + hash(cell + 8.0) * 0.6);
	float dot_light = exp(-dot(point, point) * 850.0) + exp(-dot(point, point) * 65.0) * 0.12;
	float life = 0.45 + 0.55 * sin(clock * 0.7 + hash(cell) * 24.0);
	base += mix(vec3(0.8, 0.51, 0.20), school_color.rgb, 0.4) * dot_light * step(0.84, hash(cell + 17.0)) * life * 0.7;
	base += school_color.rgb * pulse * halo * 0.15;
	base *= 1.0 - 0.38 * smoothstep(0.35, 0.95, length((UV - 0.5) * 1.35));
	float feather = smoothstep(0.0, 0.10, min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y)));
	COLOR = vec4(base, portrait ? feather * 0.8 : (hall_visible ? 0.38 : 1.0));
}
