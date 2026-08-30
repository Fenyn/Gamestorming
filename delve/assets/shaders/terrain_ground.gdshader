// Top-down projection of the baked board ground texture (see GroundTextureBaker). A straight
// planar Y projection instead of triplanar: walkable tops sample their own 48px atlas cell, and a
// sloped tile stretches its grass down the incline the way RPG Maker cliffs do — triplanar would
// blend toward the side projections on steep slopes and smear unrelated atlas cells across them.
shader_type spatial;
render_mode cull_back;

uniform sampler2D ground_texture : source_color, filter_nearest, repeat_enable;

// 1 / board size in tiles; world XZ times this spans the atlas exactly once.
uniform vec2 board_inv_size = vec2(0.05, 0.05);

// World XZ of the layout's tile (0,0) corner. A skirted board renders a layout translated by its
// halo margin, so the atlas has to be sampled from there instead of from the world origin.
uniform vec2 board_origin = vec2(0.0);

varying vec2 ground_uv;

void vertex() {
    vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    ground_uv = (world_pos.xz - board_origin) * board_inv_size;
}

void fragment() {
    ALBEDO = texture(ground_texture, ground_uv).rgb;
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;
}
