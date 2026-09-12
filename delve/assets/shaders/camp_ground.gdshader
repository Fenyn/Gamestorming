shader_type spatial;
uniform sampler2D grass_texture : source_color, filter_nearest, repeat_enable;
uniform sampler2D dirt_texture : source_color, filter_nearest, repeat_enable;
uniform sampler2D rock_texture : source_color, filter_nearest, repeat_enable;
uniform vec4 contact_patches[16];
varying vec3 world;
varying vec3 ground_normal;
void vertex() {
    world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    ground_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
}
float patch(vec2 p, vec2 center, vec2 radius) { return length((p - center) / radius); }
void fragment() {
    vec2 p = floor(world.xz * 24.0) / 24.0;
    float edge = sin(p.x * 1.7 + sin(p.y * 0.7)) * 0.06 + sin(p.y * 2.4) * 0.035;
    float clearing = patch(p, vec2(0.0, 2.6), vec2(7.3, 7.5));
    clearing = min(clearing, patch(p, vec2(-11.0, -4.0), vec2(5.0, 4.5)));
    clearing = min(clearing, patch(p, vec2(11.8, -5.0), vec2(4.6, 4.5)));
    float track = abs(p.x - sin(p.y * 0.22) * 2.0) / 1.5;
    clearing = min(clearing, track);
    float wear = 1.0 - smoothstep(0.84, 1.12, clearing + edge);
    vec3 grass = texture(grass_texture, p / 2.0).rgb * vec3(0.68, 0.73, 0.62);
    vec3 dirt = texture(dirt_texture, p / 2.0).rgb * vec3(0.98, 0.88, 0.72);
    vec3 rock = texture(rock_texture, p / 2.5).rgb * vec3(0.72, 0.77, 0.71);
    ALBEDO = mix(grass, dirt, wear);
    ALBEDO = mix(ALBEDO, rock, smoothstep(0.38, 0.8, 1.0 - normalize(ground_normal).y) * 0.75);
    float contact = 0.0;
    for (int i = 0; i < 16; i++) {
        vec4 spot = contact_patches[i];
        contact = max(contact, (1.0 - smoothstep(0.18, 1.0, patch(p, spot.xy, spot.zw))) * 0.42);
    }
    ALBEDO *= 1.0 - contact;
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;
}
