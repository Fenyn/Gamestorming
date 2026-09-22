shader_type canvas_item;
void fragment() {
	float sides = smoothstep(0.0, 0.06, UV.x) * smoothstep(0.0, 0.06, 1.0 - UV.x);
	float ends = smoothstep(0.0, 0.04, UV.y) * smoothstep(0.0, 0.14, 1.0 - UV.y);
	COLOR.a *= sides * ends;
}
