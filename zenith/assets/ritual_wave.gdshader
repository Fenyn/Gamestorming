shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_add;

uniform vec4 tint : source_color = vec4(0.9, 0.38, 0.3, 1.0);
uniform float progress = 0.0;
uniform float strength = 1.0;
uniform bool ward = false;
uniform bool pillar = false;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float radius = length(p);
	float angle = atan(p.y, p.x);
	float fade = 1.0 - smoothstep(0.12, 1.0, progress);
	float light;
	if (pillar) {
		light = pow(1.0 - UV.y, 2.0) * (0.08 + pow(abs(sin(UV.x * 37.699)), 18.0) * 0.42);
		light *= smoothstep(0.0, 0.12, UV.y) * fade;
	} else {
		float target = ward ? mix(0.88, 0.53, progress) : mix(0.08, 0.95, progress);
		float shape = ward ? radius * cos(mod(angle + 0.523599, 1.047198) - 0.523599) : radius;
		float rim = exp(-pow((shape - target) * 42.0, 2.0));
		float glow = exp(-pow((shape - target) * 12.0, 2.0)) * 0.22;
		float rays = pow(abs(cos(angle * (ward ? 6.0 : 11.0))), 28.0) * exp(-radius * 4.0) * (1.0 - progress);
		light = (rim + glow + rays * 0.75) * fade * (1.0 - smoothstep(0.92, 1.0, radius));
	}
	ALBEDO = tint.rgb * 1.4;
	ALPHA = light * strength;
}
