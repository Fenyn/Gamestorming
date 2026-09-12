shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D sprite_tex : source_color, filter_nearest, repeat_disable;
uniform sampler2D scene_depth : hint_depth_texture, filter_nearest, repeat_disable;
uniform vec4 silhouette_color : source_color = vec4(0.82, 0.88, 0.77, 0.3);
uniform float edge_opacity = 0.5;
uniform float depth_bias = 0.025;
uniform float body_alpha = 1.0;
varying float body_depth;

void vertex() {
    // Match the token's fixed-Y billboard, including model scale and authored sprite offset.
    MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
        vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
        vec4(0.0, 1.0, 0.0, 0.0),
        vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
        MODEL_MATRIX[3]);
    MODELVIEW_MATRIX *= mat4(
        vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
        vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
        vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
        vec4(0.0, 0.0, 0.0, 1.0));
    body_depth = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
}

void fragment() {
    if (texture(sprite_tex, UV).a < 0.5 || body_alpha <= 0.0) discard;
    float depth = texture(scene_depth, SCREEN_UV).r;
    #if CURRENT_RENDERER == RENDERER_COMPATIBILITY
        vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
    #else
        vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
    #endif
    vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
    float surface_depth = -view.z / view.w;
    // Visible sprite pixels (including its own depth prepass) receive no overlay at all.
    if (body_depth <= surface_depth + depth_bias) discard;
    vec2 px = 1.0 / vec2(textureSize(sprite_tex, 0));
    float neighbor = min(min(texture(sprite_tex, UV + vec2(px.x, 0.0)).a,
                             texture(sprite_tex, UV - vec2(px.x, 0.0)).a),
                         min(texture(sprite_tex, UV + vec2(0.0, px.y)).a,
                             texture(sprite_tex, UV - vec2(0.0, px.y)).a));
    ALBEDO = silhouette_color.rgb;
    ALPHA = mix(edge_opacity, silhouette_color.a, step(0.5, neighbor)) * body_alpha;
}
