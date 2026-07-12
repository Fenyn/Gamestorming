// HD-2D full-screen post pass: tilt-shift blur + vignette + color grade.
// Applied to a full-rect ColorRect on a high CanvasLayer (see scenes/fx/hd2d_stack.tscn).
// The tilt-shift samples progressively lower screen-texture mips away from a horizontal
// focus band, producing the diorama look HD-2D games use; grade runs after the blur.
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// Tilt-shift: screen-space Y of the sharp band center (0 top, 1 bottom) and its half-height —
// everything within focus_range of the center is pin-sharp; blur then ramps in from there and
// only reaches blur_strength (in mip levels) at the extreme frame edge (fixed 0.55 ramp end).
uniform float focus_center : hint_range(0.0, 1.0) = 0.55;
uniform float focus_range : hint_range(0.01, 0.5) = 0.34;
uniform float blur_strength : hint_range(0.0, 4.0) = 0.8;

// Vignette.
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.1;
uniform float vignette_extent : hint_range(0.5, 2.0) = 1.55;

// Grade. Split-toning pulls the look from "cozy farm" toward "rugged fantasy": shadows lean
// steely-cool while highlights stay warm amber, so torchlight keeps its warmth as midtones
// desaturate. shadow/highlight tints blend by luma around the 0.25–0.75 band.
uniform float saturation : hint_range(0.0, 2.0) = 1.02;
uniform float contrast : hint_range(0.5, 1.5) = 1.1;
uniform float brightness : hint_range(0.5, 1.5) = 1.0;
uniform vec3 tint : source_color = vec3(1.0, 0.99, 0.97);
uniform vec3 shadow_tint : source_color = vec3(0.9, 0.95, 1.04);
uniform vec3 highlight_tint : source_color = vec3(1.05, 1.0, 0.92);

void fragment() {
	vec2 uv = SCREEN_UV;

	// --- Tilt-shift ---
	float dist = abs(uv.y - focus_center);
	float blur = smoothstep(focus_range, 0.55, dist) * blur_strength;
	vec3 col = textureLod(screen_texture, uv, blur).rgb;

	// --- Grade (in gamma space: the hdr_2d screen buffer is linear, and a 0.5-pivot
	// contrast applied to linear values crushes every shadow tone to black) ---
	col = pow(max(col, vec3(0.0)), vec3(1.0 / 2.2));
	col *= brightness * tint;
	col = (col - 0.5) * contrast + 0.5;
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(luma), col, saturation);

	// --- Split-toning (after saturation so the tints read cleanly) ---
	float tone = smoothstep(0.25, 0.75, luma);
	col *= mix(shadow_tint, highlight_tint, tone);

	// --- Vignette ---
	vec2 centered = (uv - 0.5) * 2.0;
	float vig = smoothstep(vignette_extent, vignette_extent * 0.45, length(centered));
	col *= mix(1.0 - vignette_intensity, 1.0, vig);

	COLOR = vec4(pow(max(col, vec3(0.0)), vec3(2.2)), 1.0);
}
