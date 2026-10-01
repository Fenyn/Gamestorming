shader_type spatial;
// Dev mock of the camp ground for a growing village (HubMockSpike.Village): worn patches,
// roads of any width, and a textured stream. Edges dither on the hero texel grid (20 per unit).
uniform sampler2D grass_texture : source_color, filter_nearest, repeat_enable;
uniform sampler2D dirt_texture : source_color, filter_nearest, repeat_enable;
uniform sampler2D rock_texture : source_color, filter_nearest, repeat_enable;
uniform sampler2D water_texture : source_color, filter_nearest, repeat_enable;
uniform vec4 patches[32];
uniform vec4 roads[32];
uniform float road_widths[32];
uniform vec4 stream[12];
uniform float stream_width = 1.5;
// The trailhead (x, z): ground past it darkens with depth, as the trees do.
uniform vec2 gloom_from = vec2(-2.4, -14.6);
varying vec3 world;
varying vec3 ground_normal;
void vertex() {
    world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    ground_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
}
float segment(vec2 p, vec2 a, vec2 b) {
    vec2 ab = b - a;
    float t = clamp(dot(p - a, ab) / max(dot(ab, ab), 0.0001), 0.0, 1.0);
    return length(p - (a + ab * t));
}
float bayer(vec2 cell) {
    float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
    ivec2 i = ivec2(mod(cell, 4.0));
    return (m[i.x + i.y * 4] + 0.5) / 16.0;
}
void fragment() {
    vec2 cell = floor(world.xz * 20.0);
    vec2 p = cell / 20.0;
    float threshold = bayer(cell);
    float edge = sin(p.x * 1.7 + sin(p.y * 0.7)) * 0.06 + sin(p.y * 2.4) * 0.035;
    float worn = 9.0;
    for (int i = 0; i < 32; i++)
        if (patches[i].z > 0.0) worn = min(worn, length((p - patches[i].xy) / patches[i].zw));
    for (int i = 0; i < 32; i++)
        if (road_widths[i] > 0.0) worn = min(worn, segment(p, roads[i].xy, roads[i].zw) / road_widths[i]);
    // A narrow dithered band: the edge breaks into pixels over about two texels, not a soft fade.
    float wear = step(threshold, 1.0 - smoothstep(0.93, 1.05, worn + edge));
    vec3 grass = texture(grass_texture, p / 2.0).rgb * vec3(0.68, 0.73, 0.62);
    vec3 dirt = texture(dirt_texture, p / 2.0).rgb * vec3(0.98, 0.88, 0.72);
    vec3 rock = texture(rock_texture, p / 2.5).rgb * vec3(0.72, 0.77, 0.71);
    ALBEDO = mix(grass, dirt, wear);
    ALBEDO = mix(ALBEDO, rock, smoothstep(0.38, 0.8, 1.0 - normalize(ground_normal).y) * 0.75);
    float river = 9.0;
    for (int i = 0; i < 12; i++)
        if (dot(stream[i], stream[i]) > 0.0) river = min(river, segment(p, stream[i].xy, stream[i].zw));
    float bank = step(threshold, 1.0 - smoothstep(stream_width + 0.2, stream_width + 0.9, river + edge * 4.0));
    ALBEDO = mix(ALBEDO, rock * 0.8, bank);
    float wet = step(threshold, 1.0 - smoothstep(stream_width - 0.3, stream_width + 0.1, river + edge * 3.0));
    vec3 water = texture(water_texture, p / vec2(1.8, 1.6)).rgb;
    ALBEDO = mix(ALBEDO, water, wet);
    float depth = clamp((gloom_from.y - 1.5 - p.y) / 12.0, 0.0, 1.0) * clamp(1.4 - abs(p.x - gloom_from.x) / 14.0, 0.0, 1.0);
    ALBEDO *= mix(vec3(1.0), vec3(0.42, 0.48, 0.56), depth);
    ROUGHNESS = mix(1.0, 0.35, wet);
    SPECULAR = wet * 0.3;
}
