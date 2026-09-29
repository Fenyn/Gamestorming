// Film grain and vignette drawn over the 3D view, under the HUD. It never reads the screen: the
// vignette is a dark overlay and the grain is sparse light and dark specks blended on top.
shader_type canvas_item;

uniform vec3 vignette_color : source_color = vec3(0.0);
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.6;
// Distance from the centre, as a fraction of the half diagonal, where darkening starts.
uniform float vignette_radius : hint_range(0.0, 1.5) = 0.55;
uniform float vignette_softness : hint_range(0.05, 1.5) = 0.65;
uniform float grain_strength : hint_range(0.0, 0.5) = 0.0;
// Grain cell size in screen pixels.
uniform float grain_size : hint_range(1.0, 4.0) = 1.5;
uniform float grain_fps : hint_range(1.0, 60.0) = 8.0;

// Sin-free hash (Hoskins): stable on GPUs at large arguments.
float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 centred = SCREEN_UV - 0.5;
	centred.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float half_diagonal = length(vec2(0.5 * SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 0.5));
	float r = length(centred) / half_diagonal;
	float vignette = smoothstep(vignette_radius, vignette_radius + vignette_softness, r) * vignette_strength;

	float frame = floor(TIME * grain_fps);
	float g = hash12(floor(FRAGCOORD.xy / grain_size) + frame * vec2(17.0, 31.0)) - 0.5;
	float grain_alpha = abs(g) * 2.0 * grain_strength;
	vec3 grain_color = vec3(step(0.0, g));

	float alpha = grain_alpha + vignette * (1.0 - grain_alpha);
	vec3 rgb = (grain_color * grain_alpha + vignette_color * vignette * (1.0 - grain_alpha)) / max(alpha, 1e-4);
	COLOR = vec4(rgb, alpha);
}
