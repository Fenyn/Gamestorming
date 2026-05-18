class_name DiceTray
extends SubViewportContainer

const TRAY_SPAWN_Y: float = 1.5
const MAX_CELLS: int = 10

var _cells: Array[PowerCell] = []
var _cell_data_map: Array[CellData] = []
var _labels: Array[Label] = []
var _settled_count: int = 0
var _free_count: int = 0
var _dragging_cell_index: int = -1

@onready var _viewport: SubViewport = %DiceTrayViewport
@onready var _camera: Camera3D = %TrayCamera


func _ready() -> void:
	pass


func draw_from_bag() -> void:
	_discard_free_dice()
	_clear_active_cells()

	var drawn: Array[CellData] = RunState.dice_bag.draw()
	var count: int = drawn.size()
	var spread: float = min(2.0, 4.0 / maxi(count, 1))
	var start_x: float = -spread * (count - 1) / 2.0

	for i: int in count:
		var cell_data: CellData = drawn[i]
		var cell := PowerCell.new()
		cell.cell_index = _cells.size()
		cell.settled.connect(_on_cell_settled)

		var spawn_x: float = start_x + spread * i + randf_range(-0.2, 0.2)
		cell.position = Vector3(spawn_x, TRAY_SPAWN_Y, randf_range(-0.4, 0.4))

		_viewport.add_child(cell)
		cell.apply_cell_data(cell_data)
		_cells.append(cell)
		_cell_data_map.append(cell_data)

		var label := Label.new()
		label.text = ""
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override("font_color", cell_data.tint)
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		label.add_theme_constant_override("outline_size", 4)
		label.custom_minimum_size = Vector2(32, 32)
		label.size = Vector2(32, 32)
		label.visible = false
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
		_labels.append(label)


func roll_all_free() -> void:
	_settled_count = 0
	_free_count = 0
	_hide_all_labels()

	var free_indices: Array[int] = []
	for cell: PowerCell in _cells:
		if not cell.is_socketed:
			free_indices.append(cell.cell_index)
	_free_count = free_indices.size()
	if _free_count == 0:
		EventBus.all_dice_settled.emit(_get_free_values())
		return

	var spread: float = min(2.0, 4.0 / _free_count)
	var start_x: float = -spread * (_free_count - 1) / 2.0

	for i: int in _free_count:
		var cell: PowerCell = _cells[free_indices[i]]
		var spawn_x: float = start_x + spread * i + randf_range(-0.2, 0.2)
		var spawn_z: float = randf_range(-0.4, 0.4)
		cell.global_position = Vector3(spawn_x, TRAY_SPAWN_Y, spawn_z)
		cell.roll()


func discard_fired_dice(cell_indices: Array[int]) -> void:
	for idx: int in cell_indices:
		_consume_cell(idx)


func unsocket_to_discard(cell_index: int) -> void:
	_consume_cell(cell_index)


func _hide_socketed_cell(cell_index: int) -> void:
	if cell_index >= 0 and cell_index < _cells.size():
		_cells[cell_index].visible = false


func _consume_cell(cell_index: int) -> void:
	if cell_index >= 0 and cell_index < _cells.size():
		var cell: PowerCell = _cells[cell_index]
		cell.visible = false
		cell.is_socketed = true
		cell.set_physics_process(false)
	if cell_index >= 0 and cell_index < _cell_data_map.size():
		var data: CellData = _cell_data_map[cell_index]
		if data:
			RunState.dice_bag.discard(data)
			_cell_data_map[cell_index] = null
	if cell_index >= 0 and cell_index < _labels.size():
		_labels[cell_index].visible = false


func unsocket_cell(cell_index: int) -> void:
	if cell_index >= 0 and cell_index < _cells.size():
		_cells[cell_index].unsocket()
		_show_label(cell_index)


func get_cell(index: int) -> PowerCell:
	if index >= 0 and index < _cells.size():
		return _cells[index]
	return null


func get_cell_data(index: int) -> CellData:
	if index >= 0 and index < _cell_data_map.size():
		return _cell_data_map[index]
	return null


func get_settled_free_cells() -> Array[PowerCell]:
	var result: Array[PowerCell] = []
	for cell: PowerCell in _cells:
		if cell.is_settled and not cell.is_socketed:
			result.append(cell)
	return result


func restore_dragged_cell() -> void:
	if _dragging_cell_index >= 0 and _dragging_cell_index < _cells.size():
		_cells[_dragging_cell_index].unsocket()
		_show_label(_dragging_cell_index)
	_dragging_cell_index = -1


func get_bag_remaining() -> int:
	return RunState.dice_bag.get_bag_size()


func get_discard_count() -> int:
	return RunState.dice_bag.get_discard_size()


func _discard_free_dice() -> void:
	for i: int in _cells.size():
		var cell: PowerCell = _cells[i]
		if not cell.is_socketed and i < _cell_data_map.size():
			var data: CellData = _cell_data_map[i]
			if data:
				RunState.dice_bag.discard(data)


func _clear_active_cells() -> void:
	for cell: PowerCell in _cells:
		if is_instance_valid(cell):
			cell.queue_free()
	for label: Label in _labels:
		if is_instance_valid(label):
			label.queue_free()
	_cells.clear()
	_cell_data_map.clear()
	_labels.clear()


func _process(_delta: float) -> void:
	if not _camera or not _camera.is_inside_tree():
		return
	var vp_size: Vector2 = Vector2(_viewport.size)
	var container_size: Vector2 = size
	if container_size.x <= 0 or container_size.y <= 0:
		return
	var vp_scale: Vector2 = container_size / vp_size

	for i: int in _cells.size():
		if i >= _labels.size():
			break
		var label: Label = _labels[i]
		if not label.visible:
			continue
		var cell: PowerCell = _cells[i]
		var top_pos: Vector3 = cell.global_position + Vector3(0, 0.18, 0)
		var screen_pos: Vector2 = _camera.unproject_position(top_pos) * vp_scale
		label.position = screen_pos - label.size / 2.0


func _hide_all_labels() -> void:
	for label: Label in _labels:
		label.visible = false


func _show_label(cell_index: int) -> void:
	if cell_index < 0 or cell_index >= _cells.size():
		return
	if cell_index >= _labels.size():
		return
	var cell: PowerCell = _cells[cell_index]
	var label: Label = _labels[cell_index]
	label.text = str(cell.face_value)
	if cell.cell_data:
		label.add_theme_color_override("font_color", cell.cell_data.tint)
	label.visible = true


func _on_cell_settled(cell_index: int, face_value: int) -> void:
	_settled_count += 1
	_show_label(cell_index)
	EventBus.die_settled.emit(cell_index, face_value)
	if _settled_count >= _free_count:
		EventBus.all_dice_settled.emit(_get_free_values())


func _get_free_values() -> Array[int]:
	var values: Array[int] = []
	for cell: PowerCell in _cells:
		if not cell.is_socketed:
			values.append(cell.face_value)
	return values


func _get_drag_data(at_position: Vector2) -> Variant:
	var cell: PowerCell = _find_cell_at(at_position)
	if not cell or not cell.is_settled or cell.is_socketed:
		return null

	_dragging_cell_index = cell.cell_index
	if cell.cell_index < _labels.size():
		_labels[cell.cell_index].visible = false
	cell.begin_drag()

	var is_wild: bool = cell.cell_data != null and cell.cell_data.is_wild
	var drag_data: Dictionary = {
		"cell_index": cell.cell_index,
		"face_value": cell.face_value,
		"is_wild": is_wild,
		"source": self,
	}

	var preview := Label.new()
	preview.text = str(cell.face_value)
	preview.add_theme_font_size_override("font_size", 28)
	var preview_color: Color = ThemeBuilder.ACCENT_GLOW
	if cell.cell_data:
		preview_color = cell.cell_data.tint
	preview.add_theme_color_override("font_color", preview_color)
	preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview.custom_minimum_size = Vector2(40, 40)
	set_drag_preview(preview)

	return drag_data


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		if _dragging_cell_index >= 0:
			if is_drag_successful():
				_hide_socketed_cell(_dragging_cell_index)
			else:
				restore_dragged_cell()
			_dragging_cell_index = -1


func _find_cell_at(screen_pos: Vector2) -> PowerCell:
	if not _camera:
		return null

	var viewport_size: Vector2 = Vector2(_viewport.size)
	var container_size: Vector2 = size
	if container_size.x <= 0 or container_size.y <= 0:
		return null
	var scale_factor: Vector2 = viewport_size / container_size
	var viewport_pos: Vector2 = screen_pos * scale_factor

	var from: Vector3 = _camera.project_ray_origin(viewport_pos)
	var dir: Vector3 = _camera.project_ray_normal(viewport_pos)

	var best_cell: PowerCell = null
	var best_dist: float = INF

	for cell: PowerCell in _cells:
		if not is_instance_valid(cell):
			continue
		if not cell.is_settled or cell.is_socketed or not cell.visible:
			continue
		var cell_pos: Vector3 = cell.global_position
		var to_cell: Vector3 = cell_pos - from
		var t: float = to_cell.dot(dir)
		if t < 0.0:
			continue
		var closest: Vector3 = from + dir * t
		var dist: float = closest.distance_to(cell_pos)
		if dist < 0.5 and dist < best_dist:
			best_dist = dist
			best_cell = cell

	return best_cell
