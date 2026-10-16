// Liquid inside a cup or pitcher. Apply to a cylinder centred on its origin.
// The top face tilts with `wobble` (set from code as the container moves),
// and the top `foam_fraction` of the height is drawn as foam.
shader_type spatial;

uniform vec4 liquid_color : source_color = vec4(0.3, 0.2, 0.1, 1.0);
uniform vec4 foam_color : source_color = vec4(0.93, 0.88, 0.8, 1.0);
uniform float foam_fraction : hint_range(0.0, 1.0) = 0.0;
uniform float half_height = 0.05;
uniform vec2 wobble = vec2(0.0);
uniform float ripple = 0.0015;

varying float local_y;

void vertex() {
	if (VERTEX.y > 0.0) {
		float wave = sin(TIME * 5.0 + VERTEX.x * 90.0) * ripple;
		VERTEX.y += VERTEX.x * wobble.x + VERTEX.z * wobble.y + wave;
	}
	local_y = VERTEX.y;
}

void fragment() {
	float foam_start = half_height - foam_fraction * 2.0 * half_height;
	float foam = foam_fraction > 0.001 ? smoothstep(foam_start - 0.002, foam_start + 0.002, local_y) : 0.0;
	ALBEDO = mix(liquid_color.rgb, foam_color.rgb, foam);
	ROUGHNESS = mix(0.35, 0.75, foam);
	SPECULAR = 0.35;
}
