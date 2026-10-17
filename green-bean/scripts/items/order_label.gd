class_name OrderLabel
extends RefCounted

## Paper label for an order, used on cup stickers and printed tickets. Size and
## drink sit in captioned rows so "L" (large) and "L" (latte) never run together.
static func build(order: OrderData, size: Vector2, row_px: int, pixel: float) -> MeshInstance3D:
	var paper := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = size
	paper.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.98, 0.97, 0.92)
	mat.roughness = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	paper.material_override = mat
	paper.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var rows: Array = []
	if not order.customer_name.is_empty():
		rows.append(["", order.customer_name])
	var size_code: String = DrinkData.SIZE_CODES[order.cup_size]
	rows.append(["SIZE", size_code])
	rows.append(["DRINK", order.ticket_code.substr(size_code.length()).strip_edges()])

	var row_h := float(row_px) * pixel * 1.15
	var top := row_h * float(rows.size() - 1) * 0.5
	var left := -size.x * 0.5 + size.x * 0.08
	for i in rows.size():
		var y := top - float(i) * row_h
		var caption := String(rows[i][0])
		var value := String(rows[i][1])
		if not caption.is_empty():
			var cap := _text(caption, int(row_px * 0.45), pixel, Color(0.45, 0.4, 0.35))
			cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			cap.position = Vector3(left, y, 0.001)
			paper.add_child(cap)
		var val := _text(value, row_px, pixel, Color(0.12, 0.08, 0.06))
		if caption.is_empty():
			val.position = Vector3(0, y, 0.001)
		else:
			val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			val.position = Vector3(size.x * 0.5 - size.x * 0.08, y, 0.001)
		paper.add_child(val)
	return paper

static func _text(text: String, px: int, pixel: float, color: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = px
	l.pixel_size = pixel
	l.modulate = color
	l.outline_size = 0
	return l
