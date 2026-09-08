shader_type canvas_item;
uniform float density = 0.34;
uniform vec4 fog_color : source_color = vec4(0.44, 0.51, 0.47, 1.0);
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
    COLOR = vec4(fog_color.rgb, mist);
}
