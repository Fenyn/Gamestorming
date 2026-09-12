shader_type spatial;
render_mode cull_disabled;
uniform sampler2D masonry : source_color, filter_nearest, repeat_enable;
varying vec3 world;
varying vec3 stone_normal;
void vertex() {
    world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    stone_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
}
void fragment() {
    vec3 n = abs(normalize(stone_normal));
    vec2 stone_uv = n.y > 0.65 ? world.xz : (n.x > n.z ? world.zy : world.xy);
    vec3 stone = texture(masonry, stone_uv * 0.65).rgb;
    float grey = dot(stone, vec3(0.299, 0.587, 0.114));
    stone = mix(vec3(grey) * vec3(0.88, 0.95, 0.94), stone, 0.28);
    float damp = 1.0 - smoothstep(0.0, 1.4, world.y);
    float weather = step(0.48, sin(floor(UV.x * 24.0) * 0.31 + floor(UV.y * 24.0) * 0.48));
    ALBEDO = stone * mix(vec3(0.7, 0.73, 0.67), vec3(0.48, 0.57, 0.43), damp * (0.25 + weather * 0.2));
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;
}
