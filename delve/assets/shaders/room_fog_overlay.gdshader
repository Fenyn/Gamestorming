// Crawl fog of war for props with plain materials: a black overlay whose opacity is the room's
// darkness (1 - brightness), set per instance by DungeonRoomPrefab.SetLight.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;

instance uniform float room_dark : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	ALBEDO = vec3(0.0);
	ALPHA = room_dark;
}
