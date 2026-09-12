shader_type spatial;
render_mode cull_disabled;
uniform vec3 cloth : source_color = vec3(0.55, 0.42, 0.27);
void fragment() {
    vec2 p = floor(UV * 96.0) / 96.0;
    float fold = 0.85 + floor((sin(p.x * 31.4) * 0.5 + 0.5) * 4.0) * 0.045;
    float seam = step(fract(p.x * 4.0), 0.04);
    float hem = step(p.y, 0.045) + step(0.955, p.y);
    float stitch = step(fract(p.y * 32.0), 0.42) * seam;
    ALBEDO = cloth * fold * (1.0 - seam * 0.23 - hem * 0.22) + vec3(stitch * 0.05);
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;
}
