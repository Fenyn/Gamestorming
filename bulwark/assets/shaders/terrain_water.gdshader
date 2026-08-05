// Battle-map water surface: a translucent sheet that bobs gently.
//
// Applied by MapMaterials to every SurfaceType.Water TOP face of a generated terrain mesh — the open
// water, the cross-section band on map-edge skirts, and the fill drawn under a bridge span. The three
// share one material on purpose: the band has to move with the surface it joins, or the seam between
// them opens and closes as the wave passes.
//
// COLOR.a gates the displacement per vertex. TerrainMeshBuilder writes 1 everywhere except the bottom
// row of a skirt band, which gets 0 so the water/bedrock seam stays welded to the rock while the
// surface above it moves. Nothing else in the mesh reads vertex colour.
//
// The wave only ever displaces DOWNWARD (sin - 1 is never positive): the mesh position is the rest
// level, so the surface can dip away from a bank lip but never rise through it. Its amplitude must
// stay under TerrainMeshBuilder.WaterWallDepth in world units (0.5 m) — that is how far bank walls
// extend below the water line to cover the trough.
//
// Spatial shader, so colours are authored as ordinary sRGB (the `source_color` hint handles the
// conversion). The project's linear-buffer caveat applies to the 2D canvas post stack, not here.

shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_disabled;

uniform vec4 water_color : source_color = vec4(0.16, 0.38, 0.62, 0.8);

// Peak-to-trough dip in metres. 0.12 = a quarter of the wall depth that hides it.
uniform float wave_amplitude : hint_range(0.0, 0.4) = 0.12;

// Radians per second.
uniform float wave_speed : hint_range(0.0, 4.0) = 0.8;

// Radians per metre along the (x + z) diagonal — one crest roughly every 18 m at 0.35.
uniform float wave_frequency : hint_range(0.0, 2.0) = 0.35;

void vertex() {
	float phase = (VERTEX.x + VERTEX.z) * wave_frequency + TIME * wave_speed;
	VERTEX.y += (sin(phase) - 1.0) * 0.5 * wave_amplitude * COLOR.a;
}

void fragment() {
	ALBEDO = water_color.rgb;
	ALPHA = water_color.a;
	ROUGHNESS = 0.35;
	METALLIC = 0.0;
}
