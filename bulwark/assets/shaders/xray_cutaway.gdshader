// X-ray cutaway for .glb-imported scenery (walls, roofs, props).
//
// Replaces the "knee-high south wall" staging convention on interior sets. Instead of authoring the
// camera-side wall short enough to see over, the wall is built full height and DISSOLVES wherever it
// stands between the camera and a focus point — cutscene actors now, the player later. Driven by
// Bulwark.Fx.CutawayApplier, which builds one of these materials per distinct source material and
// pushes `focus_point` every frame.
//
// MATERIAL CONTRACT. Godot's glTF importer turns the Winlu/crocotile surfaces into StandardMaterial3D
// with: base-colour texture, NEAREST filter and CLAMP wrap (intro_road.glb's sampler says 9728/33071),
// alpha mode MASK at cutoff 0.5, doubleSided, metallic 0, roughness 1. This shader reproduces all of it
// so a surface is pixel-identical with the cutaway off. Two points matter:
//   * It is NOT `unshaded`. Interiors are keyed by an OmniLight hearth and the walls have to take that
//     light, so ALBEDO/ROUGHNESS/METALLIC are written and Godot's standard lighting runs on top.
//   * The alpha test is a plain `discard`, which is what alpha-scissor compiles to. The material stays
//     in the OPAQUE pass, so nothing has to sort — same as the imported material.
// `albedo_tint` covers the untextured case too (the greybox interiors are flat-colour materials with no
// albedo texture): an unassigned sampler reads as white, so the tint alone carries the colour.
//
// THE CUT. Pure arithmetic — no screen texture, no depth buffer read, two dot products. Per fragment,
// against the camera→focus ray:
//     along  = how far along the ray the fragment projects   (dot)
//     radial = how far it sits off the ray                   (dot via length of the rejection)
// A fragment dissolves when it lies within `cut_radius` of the ray AND is closer to the camera than
// (focus distance − `cut_margin`). That margin is the whole reason the hole is usable: the cut stops
// short of the focus instead of reaching it, so the floor under the actors — and the table, hearth and
// props they stand among — stay solid while everything in front of them opens up.
//
// The dissolve is a 4×4 ordered (Bayer) dither keyed off FRAGCOORD rather than alpha blending: screen-
// door transparency needs no sorting, costs one `discard`, and reads as a deliberate cutaway rather
// than a ghost. Both edges of the hole — the radial rim and the near-focus end — fade across
// `cut_softness`, so the dither thins out gradually instead of terminating on a hard circle.
//
// CAVEAT. `CAMERA_POSITION_WORLD` is the position of whatever is rendering, so during a shadow pass it
// is the LIGHT's position and the hole is carved along the light axis instead of the view axis. It only
// bites on shadow-casting lights over alpha-discard materials; the hearth OmniLight in the homestead
// interior does not cast shadows, so the intended target is unaffected. If a shadow-casting rig ever
// shows a streak of missing shadow, feed the camera position in as a uniform from CutawayApplier
// instead of reading the built-in.

shader_type spatial;
render_mode cull_disabled;

// --- imported-material contract -------------------------------------------------------------------

uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_disable;
uniform vec4 albedo_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float alpha_scissor : hint_range(0.0, 1.0) = 0.5;

// --- cutaway --------------------------------------------------------------------------------------

uniform bool enabled = true;

/// World-space point the camera must be able to see (the actors' midpoint, later the player).
uniform vec3 focus_point = vec3(0.0, 0.0, 0.0);

/// Radius of the hole around the camera→focus ray, in metres.
uniform float cut_radius : hint_range(0.0, 12.0) = 2.2;

/// Width of the dithered falloff at both edges of the hole, in metres.
uniform float cut_softness : hint_range(0.01, 6.0) = 0.8;

/// How far short of the focus the cut stops, in metres. Keeps the ground under the focus and the props
/// beside it out of the hole.
uniform float cut_margin : hint_range(0.0, 4.0) = 0.75;

// Standard 4×4 Bayer matrix. Read with a +0.5 bias so the thresholds span 1/32 … 31/32: at mask 0 even
// the lowest cell discards (a solid hole, no stray surviving pixel) and at mask 1 even the highest cell
// survives (no speckling on untouched geometry).
const float bayer4x4[16] = float[16](
	 0.0,  8.0,  2.0, 10.0,
	12.0,  4.0, 14.0,  6.0,
	 3.0, 11.0,  1.0,  9.0,
	15.0,  7.0, 13.0,  5.0
);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec4 tex = texture(albedo_texture, UV) * albedo_tint;

	// Alpha scissor first: cutout foliage and fence gaps have to punch through before anything else.
	if (tex.a < alpha_scissor) {
		discard;
	}

	if (enabled) {
		vec3 to_focus = focus_point - CAMERA_POSITION_WORLD;
		float focus_dist = length(to_focus);

		if (focus_dist > 0.001) {
			vec3 ray = to_focus / focus_dist;
			vec3 rel = world_pos - CAMERA_POSITION_WORLD;
			float along = dot(rel, ray);
			float radial = length(rel - ray * along);

			// `mask` is how much of the surface SURVIVES: 1 = untouched, 0 = fully cut. It only reaches
			// 0 where every test agrees the fragment is in the way.
			float rim = smoothstep(cut_radius - cut_softness, cut_radius, radial);
			float stop = focus_dist - cut_margin;
			float tail = smoothstep(stop - cut_softness, stop, along);
			// Guard for a focus behind the camera (a cutscene pan can swing the view off the actors):
			// without it the backward ray would carve a hole straight down the middle of the shot.
			float behind = step(along, 0.0);
			float mask = max(max(rim, tail), behind);

			int cell = int(mod(FRAGCOORD.y, 4.0)) * 4 + int(mod(FRAGCOORD.x, 4.0));
			if ((bayer4x4[cell] + 0.5) / 16.0 > mask) {
				discard;
			}
		}
	}

	ALBEDO = tex.rgb;
	ROUGHNESS = 1.0;  // glTF roughnessFactor on every Winlu surface
	METALLIC = 0.0;   // glTF metallicFactor on every Winlu surface
}
