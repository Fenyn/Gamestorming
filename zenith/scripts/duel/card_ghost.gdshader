shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_back, fog_disabled;

uniform sampler2D face_texture : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 spirit : source_color = vec4(0.66, 0.84, 0.96, 1.0);
uniform float opacity = 0.72;
uniform float dim = 0.0;
uniform float motion = 1.0;

void fragment() {
    vec4 face = texture(face_texture, UV);
    float luma = dot(face.rgb, vec3(0.299, 0.587, 0.114));
    vec3 cold = mix(vec3(luma), spirit.rgb * (0.25 + luma * 0.9), 0.6);
    float drift = 0.5 + 0.5 * sin(UV.y * 36.0 - TIME * 1.6 * motion);
    vec2 inset = min(UV, vec2(1.0) - UV);
    float edge = smoothstep(0.0, 0.06, min(inset.x, inset.y * 0.72));
    ALBEDO = cold * mix(1.0, 0.5, dim) + spirit.rgb * (1.0 - edge) * 0.25;
    ALPHA = face.a * opacity * mix(0.82, 1.0, drift) * mix(0.55, 1.0, edge) * mix(1.0, 0.75, dim);
}
