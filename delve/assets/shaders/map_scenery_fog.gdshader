shader_type canvas_item;
uniform float density = 0.34;
uniform vec4 fog_color : source_color = vec4(0.44, 0.51, 0.47, 1.0);
uniform vec2 ward_position = vec2(0.5, 0.9);
uniform float ward_strength = 1.0;
uniform float aspect = 1.0;
uniform vec4 ward_color : source_color = vec4(0.5, 0.8, 0.7, 1.0);
float hash(vec2 p) {
    vec3 q = fract(vec3(p.xyx) * 0.1031);
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
}
float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1,0)), f.x),
        mix(hash(i + vec2(0,1)), hash(i + vec2(1)), f.x), f.y);
}
void fragment() {
    vec2 p = UV * vec2(5.0, 9.0);
    float t = TIME * 0.025;
    float banks = noise(p + vec2(t, t * 0.15)) * 0.65
        + noise(p * 2.1 + vec2(-t * 0.7, 13.0)) * 0.35;
    float far = 1.0 - UV.y;
    float mist = smoothstep(0.25, 0.8, banks) * density + far * density * 0.35;
    float distance_to_ward = length((UV - ward_position) * vec2(aspect, 1.0));
    float sanctuary = 1.0 - smoothstep(0.025, mix(0.09, 0.30, ward_strength), distance_to_ward);
    mist *= mix(1.35, 1.0, ward_strength) * (1.0 - sanctuary * 0.90);
    float edge = smoothstep(0.28, 0.72, length((UV - 0.5) * vec2(1.0, 0.85)));
    float darkness = edge * mix(0.38, 0.16, ward_strength);
    vec3 atmosphere = mix(fog_color.rgb, vec3(0.018, 0.028, 0.025), darkness);
    atmosphere = mix(atmosphere, ward_color.rgb, sanctuary * 0.45);
    COLOR = vec4(atmosphere, clamp(mist + darkness + sanctuary * 0.045, 0.0, 0.75));
}
