shader_type spatial;
render_mode unshaded, cull_disabled;

uniform float clock = 24.0;
uniform vec4 seat_zero : source_color = vec4(0.34, 0.74, 0.82, 1.0);
uniform vec4 seat_one : source_color = vec4(0.62, 0.56, 0.96, 1.0);
varying vec2 world;
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
void vertex() { world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz; }
void fragment() {
	vec2 p = world;
	vec2 flow = p * 0.32 + vec2(clock * 0.012, -clock * 0.016);
	float n = noise(flow) * 0.6 + noise(flow * 2.1 + noise(flow)) * 0.28 + noise(flow * 4.0) * 0.12;
	float falloff = exp(-length(p) * 0.048);
	vec3 school = mix(seat_one.rgb, seat_zero.rgb, smoothstep(-2.0, 2.0, p.y));
	float bank = smoothstep(0.32, 0.78, n);
	vec3 base = vec3(0.002, 0.004, 0.010) + vec3(0.004, 0.009, 0.016) * noise(p * 0.18);
	base += mix(vec3(0.008, 0.030, 0.037), school * 0.025, 0.35) * bank * falloff;
	float radius = length(p * vec2(0.8, 1.0));
	float circle = 1.0 - smoothstep(0.014, 0.045, abs(radius - 7.0));
	base += vec3(0.08, 0.07, 0.04) * circle * 0.14;
	ALBEDO = base;
}
