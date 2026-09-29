// The halo treatment: terrain outside the board darkens and loses colour with distance, so the
// fight reads as the lit stage. TerrainStage writes the board rect; the active LookScene writes
// the strength, and turns it off (w = 0) where there is no halo, such as dungeon rooms.
global uniform vec4 look_board_rect; // x0, z0, x1, z1 in world metres
global uniform vec4 look_halo; // desaturate 0..1, darken 0..1, falloff metres, enabled

vec3 look_halo_apply(vec3 color, vec3 world) {
	if (look_halo.w < 0.5) {
		return color;
	}
	vec2 outside = max(look_board_rect.xy - world.xz, world.xz - look_board_rect.zw);
	float t = smoothstep(0.0, max(look_halo.z, 0.01), length(max(outside, vec2(0.0))));
	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(color, vec3(luma), look_halo.x * t);
	return color * (1.0 - look_halo.y * t);
}
