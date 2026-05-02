shader_type spatial;

uniform float terrain_scale : hint_range(0.001, 0.1) = 0.015;
uniform float terrain_height : hint_range(0.0, 80.0) = 25.0;
uniform float ridge_sharpness : hint_range(0.0, 3.0) = 1.2;
uniform int octaves : hint_range(1, 8) = 5;
uniform float lacunarity : hint_range(1.0, 4.0) = 2.2;
uniform float persistence : hint_range(0.0, 1.0) = 0.45;
uniform vec2 offset = vec2(0.0, 0.0);

uniform vec3 color_low : source_color = vec3(0.12, 0.08, 0.06);
uniform vec3 color_mid : source_color = vec3(0.28, 0.2, 0.14);
uniform vec3 color_high : source_color = vec3(0.45, 0.35, 0.25);
uniform vec3 color_peak : source_color = vec3(0.55, 0.45, 0.35);
uniform float roughness_val : hint_range(0.0, 1.0) = 0.92;

varying float v_height;
varying vec3 v_world_normal;

// Hash-based noise (no texture needed)
vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float gradient_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);

	return mix(mix(dot(hash2(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0)),
				   dot(hash2(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0)), u.x),
			   mix(dot(hash2(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0)),
				   dot(hash2(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0)), u.x), u.y);
}

float ridged_noise(vec2 p) {
	float n = gradient_noise(p);
	n = abs(n);
	n = 1.0 - n;
	n = pow(n, ridge_sharpness);
	return n;
}

float fbm_ridged(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	float frequency = 1.0;
	for (int i = 0; i < octaves; i++) {
		value += ridged_noise(p * frequency) * amplitude;
		frequency *= lacunarity;
		amplitude *= persistence;
	}
	return value;
}

uniform float flat_radius : hint_range(0.0, 100.0) = 30.0;
uniform float flat_falloff : hint_range(1.0, 40.0) = 15.0;
uniform vec2 flat_center = vec2(0.0, 0.0);

float get_height(vec2 world_xz) {
	vec2 p = (world_xz + offset) * terrain_scale;
	float h = fbm_ridged(p);
	// Add broader rolling hills underneath
	float broad = gradient_noise(p * 0.3) * 0.5 + 0.5;
	h = mix(h, h * broad, 0.4);
	h *= terrain_height;
	// Flatten around the base
	float dist = length(world_xz - flat_center);
	float flatten = smoothstep(flat_radius - flat_falloff, flat_radius, dist);
	return h * flatten;
}

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = get_height(world_pos.xz);
	VERTEX.y += h;
	v_height = h / terrain_height;

	// Compute normal from neighboring heights
	float eps = 0.5;
	float hL = get_height(world_pos.xz + vec2(-eps, 0.0));
	float hR = get_height(world_pos.xz + vec2(eps, 0.0));
	float hD = get_height(world_pos.xz + vec2(0.0, -eps));
	float hU = get_height(world_pos.xz + vec2(0.0, eps));
	vec3 computed_normal = normalize(vec3(hL - hR, 2.0 * eps, hD - hU));
	NORMAL = computed_normal;
	v_world_normal = computed_normal;
}

void fragment() {
	float h = clamp(v_height, 0.0, 1.0);

	vec3 col;
	if (h < 0.25) {
		col = mix(color_low, color_mid, h / 0.25);
	} else if (h < 0.55) {
		col = mix(color_mid, color_high, (h - 0.25) / 0.3);
	} else {
		col = mix(color_high, color_peak, (h - 0.55) / 0.45);
	}

	// Darken steep slopes for crag definition
	float slope = 1.0 - v_world_normal.y;
	col *= mix(1.0, 0.6, smoothstep(0.3, 0.8, slope));

	ALBEDO = col;
	ROUGHNESS = roughness_val;
}
