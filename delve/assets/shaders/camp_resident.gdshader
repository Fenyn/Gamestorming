shader_type canvas_item;
uniform bool selected = false;
uniform vec4 outline_color : source_color = vec4(0.8, 0.6, 0.3, 1.0);
void fragment() {
    vec4 body = texture(TEXTURE, UV);
    vec2 px = TEXTURE_PIXEL_SIZE;
    float edge = max(max(texture(TEXTURE, UV + vec2(px.x, 0)).a, texture(TEXTURE, UV - vec2(px.x, 0)).a),
                     max(texture(TEXTURE, UV + vec2(0, px.y)).a, texture(TEXTURE, UV - vec2(0, px.y)).a));
    COLOR = selected && body.a < 0.5 && edge > 0.5 ? outline_color : body;
}
