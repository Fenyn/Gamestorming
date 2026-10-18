shader_type spatial;

// Top of a bed of coffee grounds on a square quad (UV 0..1), cut to a disc.
// saturation: small greyscale map, white = soaked, sampled with linear
// filtering so the grid cells blend into soft wet patches. The map's texel
// centres span the disc edge to edge. bloom > 0 adds CO2 bubbles over wet areas.

uniform sampler2D saturation : filter_linear, repeat_disable, hint_default_black;
uniform float grid_size = 7.0;
uniform vec4 dry_color : source_color = vec4(0.55, 0.38, 0.22, 1.0);
uniform vec4 wet_color : source_color = vec4(0.17, 0.095, 0.045, 1.0);
uniform vec4 foam_color : source_color = vec4(0.6, 0.44, 0.3, 1.0);
uniform float bloom = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float r2 = dot(c, c);
	if (r2 > 1.0) {
		discard;
	}
	vec2 suv = (c * 0.5 + 0.5) * ((grid_size - 1.0) / grid_size) + 0.5 / grid_size;
	float s = smoothstep(0.0, 1.0, texture(saturation, suv).r);
	float grain = hash(floor(UV * 160.0));
	vec3 col = mix(dry_color.rgb, wet_color.rgb, s);
	col *= 0.86 + 0.28 * grain;

	// Blooming: bubbles swell and pop across the wet grounds.
	vec2 g = UV * 34.0;
	vec2 id = floor(g);
	vec2 f = fract(g) - 0.5;
	float h = hash(id);
	float t = fract(TIME * 0.35 + h);
	float rad = 0.12 + 0.28 * t;
	float ring = smoothstep(0.07, 0.0, abs(length(f) - rad)) * (1.0 - t) * step(0.45, h);
	float froth = bloom * s * (0.35 + 0.65 * ring);
	col = mix(col, foam_color.rgb, clamp(froth, 0.0, 0.85));

	// Darker towards the filter wall, where the bed meets the paper.
	col *= mix(1.0, 0.8, smoothstep(0.6, 1.0, r2));
	ALBEDO = col;
	ROUGHNESS = mix(0.95, 0.3, s);
	SPECULAR = mix(0.15, 0.6, s);
}
