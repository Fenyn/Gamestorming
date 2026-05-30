shader_type sky;

uniform vec3 base_color : source_color = vec3(0.005, 0.005, 0.02);
uniform vec3 nebula_color_a : source_color = vec3(0.06, 0.01, 0.08);
uniform vec3 nebula_color_b : source_color = vec3(0.01, 0.03, 0.08);
uniform float star_density : hint_range(0.0, 1.0) = 0.55;
uniform float star_brightness : hint_range(0.0, 5.0) = 2.5;
uniform float nebula_intensity : hint_range(0.0, 0.5) = 0.08;

vec3 hash33(vec3 p) {
	p = vec3(
		dot(p, vec3(127.1, 311.7, 74.7)),
		dot(p, vec3(269.5, 183.3, 246.1)),
		dot(p, vec3(113.5, 271.9, 124.6))
	);
	return fract(sin(p) * 43758.5453123);
}

float hash13(vec3 p) {
	float h = dot(p, vec3(127.1, 311.7, 74.7));
	return fract(sin(h) * 43758.5453123);
}

float value_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);

	return mix(
		mix(
			mix(hash13(i + vec3(0, 0, 0)), hash13(i + vec3(1, 0, 0)), f.x),
			mix(hash13(i + vec3(0, 1, 0)), hash13(i + vec3(1, 1, 0)), f.x),
			f.y
		),
		mix(
			mix(hash13(i + vec3(0, 0, 1)), hash13(i + vec3(1, 0, 1)), f.x),
			mix(hash13(i + vec3(0, 1, 1)), hash13(i + vec3(1, 1, 1)), f.x),
			f.y
		),
		f.z
	);
}

float fbm(vec3 p, int octaves) {
	float value = 0.0;
	float amplitude = 0.5;
	float frequency = 1.0;
	for (int i = 0; i < octaves; i++) {
		value += amplitude * value_noise(p * frequency);
		frequency *= 2.2;
		amplitude *= 0.45;
	}
	return value;
}

float stars(vec3 dir, float cell_size) {
	vec3 p = dir * cell_size;
	vec3 cell = floor(p);
	vec3 local = fract(p);
	float brightness = 0.0;

	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			for (int z = -1; z <= 1; z++) {
				vec3 neighbor = vec3(float(x), float(y), float(z));
				vec3 cell_id = cell + neighbor;
				vec3 star_pos = hash33(cell_id);
				float star_hash = hash13(cell_id + 77.7);

				if (star_hash > (1.0 - star_density * 0.04)) {
					float dist = length(local - neighbor - star_pos);
					float radius = 0.01 + star_hash * 0.008;
					float b = smoothstep(radius, radius * 0.2, dist);
					float twinkle = 0.7 + 0.3 * star_hash;
					brightness += b * twinkle;
				}
			}
		}
	}
	return brightness;
}

void sky() {
	vec3 dir = EYEDIR;
	vec3 col = base_color;

	float n = fbm(dir * 4.0 + vec3(10.0, 20.0, 30.0), 6);
	float n2 = fbm(dir * 5.0 + vec3(50.0, 60.0, 70.0), 5);
	float nebula = smoothstep(0.35, 0.65, n) * nebula_intensity;
	col += mix(nebula_color_a, nebula_color_b, n2) * nebula;

	float s1 = stars(dir, 100.0);
	float s2 = stars(dir, 200.0) * 0.5;
	float s3 = stars(dir, 50.0) * 0.3;
	float total_stars = (s1 + s2 + s3) * star_brightness;

	float temp = hash13(floor(dir * 100.0));
	vec3 star_color = mix(
		vec3(0.7, 0.8, 1.0),
		mix(vec3(1.0, 0.95, 0.8), vec3(1.0, 0.6, 0.4), step(0.9, temp)),
		temp
	);
	col += star_color * total_stars;

	COLOR = col;
}
