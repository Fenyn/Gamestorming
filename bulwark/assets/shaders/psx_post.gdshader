// PSX-era post-process grade: color-depth crush + ordered dither + resolution drop + optional punch.
// Spike answering "can retexturing to PSX be faked cheaply with a screen-space grade?" — this shader
// only touches the FINAL rendered frame; it does not touch materials, textures or geometry, so it is
// a fully reversible toggle over the existing Winlu-textured 3D scene. See scenes/dev/psx_spike.tscn
// for the comparison-render rig that exercises it.
//
// OUT OF SCOPE: true PS1 affine texture warp and vertex snapping are per-vertex/per-pixel effects
// that need to run on the geometry's OWN material (a spatial shader), not a screen-space pass. See
// psx_spike.tscn's header comment for a rough estimate of what that would take.
//
// Applied to a full-rect ColorRect on a CanvasLayer, the same pattern the (now retired) HD-2D grade
// used in assets/shaders/hd2d_post.gdshader — a CanvasLayer sitting above the 3D viewport samples
// hint_screen_texture, which hands back whatever was already composited below it that frame.
//
// GAMMA NOTE. project.godot sets viewport/hdr_2d = true, so the screen texture comes back in linear
// light. PS1 hardware had no linear pipeline; a 5-bit-per-channel crush is defined against the actual
// framebuffer values, i.e. display-referred (gamma) space. This shader converts to gamma space before
// dither/crush/punch and converts back before writing COLOR, exactly like hd2d_post.gdshader did.
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest, repeat_disable;

// --- resolution drop --------------------------------------------------------------------------
// Snaps SCREEN_UV to a virtual low-res grid before sampling, so the frame pixelates uniformly.
// Sampling stays NEAREST (see the sampler hint above) so the blocks stay crisp, not blurred.
uniform bool enable_resolution_drop = false;
/// Target vertical resolution of the virtual grid (PS1-era: 240/360/480 read as progressively
/// "PSX-er"). Horizontal resolution is derived from the real screen aspect ratio.
uniform float target_vertical_resolution : hint_range(60.0, 720.0) = 240.0;

// --- ordered dither (4x4 Bayer, applied pre-quantization) -------------------------------------
uniform bool enable_dither = true;
uniform float dither_strength : hint_range(0.0, 1.0) = 1.0;

// --- color depth crush --------------------------------------------------------------------------
uniform bool enable_crush = true;
/// Bits kept per channel after quantization. PS1 framebuffer was 5-5-5-1 (15-bit colour) -> 5.
uniform int bits_per_channel : hint_range(1, 8) = 5;

// --- optional punch (subtle, OFF by default) ----------------------------------------------------
uniform bool enable_color_lift = false;
uniform float saturation_lift : hint_range(0.5, 2.0) = 1.15;
uniform float contrast_lift : hint_range(0.5, 2.0) = 1.08;

// Same matrix/threshold convention as assets/shaders/xray_cutaway.gdshader's dither, reused here so
// the two ordered-dither passes in this project agree on what "the" Bayer 4x4 looks like.
const float bayer4x4[16] = float[16](
	 0.0,  8.0,  2.0, 10.0,
	12.0,  4.0, 14.0,  6.0,
	 3.0, 11.0,  1.0,  9.0,
	15.0,  7.0, 13.0,  5.0
);

/// Bayer cell for this fragment, centred on 0 (range -0.5..0.5) so it can push a sample up or down
/// before rounding instead of only ever brightening it.
float bayer_signed(vec2 frag_coord) {
	int x = int(mod(frag_coord.x, 4.0));
	int y = int(mod(frag_coord.y, 4.0));
	return (bayer4x4[y * 4 + x] + 0.5) / 16.0 - 0.5;
}

void fragment() {
	vec2 uv = SCREEN_UV;

	if (enable_resolution_drop) {
		vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
		float aspect = screen_size.x / screen_size.y;
		vec2 grid = vec2(target_vertical_resolution * aspect, target_vertical_resolution);
		uv = (floor(uv * grid) + 0.5) / grid;
	}

	vec4 raw = texture(screen_texture, uv);

	// Pure passthrough when nothing needs display-referred (gamma) space: skip the linear<->gamma
	// round trip entirely so the "everything off" path (and "resolution drop only, no grade") is a
	// bit-exact copy of the screen at the sampled UV, not just a numerically-close one. Previously
	// this round trip ran unconditionally, which is idempotent in exact math but leaves a needless
	// (if sub-LSB) precision gap on the control shot the whole grade is judged against.
	// NOTE: Godot's shading language rejects `return` inside fragment(), so the rest of the grade
	// is gated in an else branch rather than an early-out.
	bool needs_grade = enable_dither || enable_crush || enable_color_lift;
	if (!needs_grade) {
		COLOR = raw;
	} else {
		vec3 col = pow(max(raw.rgb, vec3(0.0)), vec3(1.0 / 2.2)); // linear -> display-referred

		if (enable_dither && enable_crush) {
			float levels = pow(2.0, float(bits_per_channel)) - 1.0;
			col += vec3(bayer_signed(FRAGCOORD.xy) * dither_strength / levels);
		}
		if (enable_crush) {
			float levels = pow(2.0, float(bits_per_channel)) - 1.0;
			col = floor(clamp(col, 0.0, 1.0) * levels + 0.5) / levels;
		}

		if (enable_color_lift) {
			col = (col - 0.5) * contrast_lift + 0.5;
			float luma = dot(col, vec3(0.299, 0.587, 0.114));
			col = mix(vec3(luma), col, saturation_lift);
		}

		COLOR = vec4(pow(clamp(col, 0.0, 1.0), vec3(2.2)), raw.a); // display-referred -> linear
	}
}
