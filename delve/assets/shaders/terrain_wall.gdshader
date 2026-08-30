// Cliff / wall faces of the battle map. The mesh supplies world-anchored UVs (see
// TerrainMeshBuilder.AddWallQuad): U runs along the wall in world metres, V is depth below the top
// lip in metres. One texture tile covers one metre on both axes, so nothing is stretched. The top
// drape_depth metres sample top_texture — the transition tile whose upper band is the overhanging
// surface art (grass or earth draping over rock) — at that natural scale, clipped at the drape
// depth, and everything deeper repeats body_texture from the seam down, so the painted
// top-to-side transition always sits exactly at the lip no matter how tall the cliff is.
//
// drape_depth is ONE elevation (0.5 m), not one metre. At one metre a two-elevation drop was drape
// all the way down while a four-elevation drop next to it showed rock, so a single cliff line came
// out half grass and half stone. The band used to squeeze the whole tile into that half metre,
// which drew every brick at 2:1; now a one-elevation face shows the tile's top half as painted.
shader_type spatial;
render_mode cull_back;

uniform sampler2D top_texture : source_color, filter_nearest, repeat_enable;
uniform sampler2D body_texture : source_color, filter_nearest, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);

// Depth below the lip, in metres, the surface art drapes over. MapMaterials.BuildWall sets it from
// the theme's height scale; the default is that value for the shipped 0.125 scale.
uniform float drape_depth : hint_range(0.05, 4.0) = 0.5;

void fragment() {
    vec3 c = UV.y < drape_depth
        ? texture(top_texture, UV).rgb
        : texture(body_texture, vec2(UV.x, UV.y - drape_depth)).rgb;
    ALBEDO = c * tint.rgb;
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;
}
