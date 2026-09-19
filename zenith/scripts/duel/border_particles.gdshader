shader_type particles;

float hash(float n) { return fract(sin(n * 127.1 + 311.7) * 43758.5453); }

vec2 perimeter(float t) {
    float s = fract(t) * 4.0;
    vec2 p;
    if (s < 1.0) { p = vec2(mix(-0.318, 0.318, s), -0.443); }
    else if (s < 2.0) { p = vec2(0.318, mix(-0.443, 0.443, s - 1.0)); }
    else if (s < 3.0) { p = vec2(mix(0.318, -0.318, s - 2.0), 0.443); }
    else { p = vec2(-0.318, mix(0.443, -0.443, s - 3.0)); }
    vec2 corner = clamp(p, vec2(-0.293, -0.418), vec2(0.293, 0.418));
    return corner + normalize(p - corner) * 0.025;
}

void start() {
    CUSTOM = vec4(0.0, hash(float(INDEX) + float(RANDOM_SEED % 997u)), 0.0, 0.0);
    VELOCITY = vec3(0.0);
    COLOR = vec4(1.0, 1.0, 1.0, 0.0);
}

void process() {
    CUSTOM.x += DELTA / LIFETIME;
    float phase = CUSTOM.y + CUSTOM.x * 0.17;
    vec2 p = perimeter(phase);
    vec2 tangent = normalize(perimeter(phase + 0.0001) - p);
    TRANSFORM[0].xyz = vec3(tangent, 0.0);
    TRANSFORM[1].xyz = vec3(-tangent.y, tangent.x, 0.0);
    TRANSFORM[2].xyz = vec3(0.0, 0.0, 1.0);
    TRANSFORM[3].xyz = vec3(p, 0.004);
    COLOR.a = sin(clamp(CUSTOM.x, 0.0, 1.0) * 3.14159) * 0.8;
}
