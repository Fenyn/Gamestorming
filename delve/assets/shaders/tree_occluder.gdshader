// Partial occluder fade for a TreeProp sprite. Applied (as a material override) ONLY while the
// CPU-side TreeFader says the tree stands between the camera and the battlefield; the rest of the
// time the sprite renders with Sprite3D's stock opaque billboard material.
//
// Per fragment: cast the eye ray through this pixel's world position and slab-test it against the
// battlefield box (min + size uniforms). If the ray goes on to cross more than clear_depth of
// battlefield volume, the pixel is covering the fight and fades to fade_alpha, feathered over
// `feather` world units — so only the band of canopy actually over the action ghosts, while the
// treetop against the sky stays solid. Mirrors TreeFader's test exactly; keep the two in step.
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D sprite_tex : source_color, filter_nearest;
uniform vec3 battlefield_min = vec3(0.0);
uniform vec3 battlefield_size = vec3(0.0);
uniform float clear_depth = 3.0;
uniform float fade_alpha = 0.25;
uniform float feather = 2.0;

varying vec3 world_pos;

void vertex() {
	// Fixed-Y billboard with model scale kept — the same maths BaseMaterial3D's billboard uses,
	// re-done here because a material override replaces the sprite's built-in billboard.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
		vec4(0.0, 1.0, 0.0, 0.0),
		vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
		MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	world_pos = (INV_VIEW_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec4 tex = texture(sprite_tex, UV);
	if (tex.a < 0.5) {
		discard;
	}

	float occl = 0.0;
	if (battlefield_size.x > 0.0) {
		vec3 eye = CAMERA_POSITION_WORLD;
		vec3 delta = world_pos - eye;
		float dist = max(length(delta), 1e-4);
		vec3 dir = delta / dist;
		vec3 sgn = vec3(
			dir.x >= 0.0 ? 1.0 : -1.0,
			dir.y >= 0.0 ? 1.0 : -1.0,
			dir.z >= 0.0 ? 1.0 : -1.0);
		vec3 safe = sgn * max(abs(dir), vec3(1e-5));
		vec3 t0 = (battlefield_min - eye) / safe;
		vec3 t1 = (battlefield_min + battlefield_size - eye) / safe;
		vec3 lo = min(t0, t1);
		vec3 hi = max(t0, t1);
		float enter = max(max(lo.x, lo.y), lo.z);
		float exit = min(min(hi.x, hi.y), hi.z);
		if (exit > max(enter, 0.0)) {
			occl = smoothstep(clear_depth, clear_depth + feather, exit - dist);
		}
	}

	ALBEDO = tex.rgb;
	ALPHA = mix(1.0, fade_alpha, occl);
}
