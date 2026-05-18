class_name LoadoutScreen
extends Control

const CELL_SIZE: Vector2 = Vector2(120, 72)
const CELL_GAP: float = 3.0
const GRID_ORIGIN: Vector2 = Vector2(40, 80)

@onready var _inventory_list: VBoxContainer = %InventoryList
@onready var _info_label: Label = %InfoLabel
@onready var _done_button: Button = %DoneButton

var _held_module: ModuleData
var _held_source: String = ""
var _held_inventory_index: int = -1
var _held_rotation: int = 0
var _hover_cell: Vector2i = Vector2i(-1, -1)
var _unlock_mode: bool = false
var _font: Font


func _ready() -> void:
	theme = ThemeBuilder.build()
	_font = ThemeDB.fallback_font
	_done_button.pressed.connect(_on_done_pressed)
	_rebuild_inventory()

	if RunState.pending_cell_unlock:
		_unlock_mode = true
		_info_label.text = "Click a highlighted cell to unlock it."
		_info_label.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
	else:
		_info_label.text = "Click a module to pick it up. R to rotate while held."


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_hover_cell = _screen_to_grid(event.position)
		queue_redraw()

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_on_click(mb.position)

	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.pressed and key.keycode == KEY_R and _held_module:
			_held_rotation = (_held_rotation + 1) % 4
			queue_redraw()

		if key.pressed and key.keycode == KEY_ESCAPE and _held_module:
			_cancel_held()


func _on_click(pos: Vector2) -> void:
	var cell: Vector2i = _screen_to_grid(pos)

	if _unlock_mode:
		if _is_valid_cell(cell) and RunState.loadout_grid.can_unlock_cell(cell.x, cell.y):
			RunState.loadout_grid.unlock_cell(cell.x, cell.y)
			RunState.pending_cell_unlock = false
			_unlock_mode = false
			_info_label.text = "Cell unlocked! Click a module to pick it up. R to rotate."
			_info_label.add_theme_color_override("font_color", Color(0.85, 0.75, 0.3))
			queue_redraw()
		return

	if _held_module:
		if _is_valid_cell(cell) and RunState.loadout_grid.can_place(_held_module, cell.x, cell.y, _held_rotation):
			RunState.loadout_grid.place(_held_module, cell.x, cell.y, _held_rotation)
			_held_module = null
			_held_source = ""
			_info_label.text = ""
			_rebuild_inventory()
			queue_redraw()
		elif not _is_on_grid(pos):
			_cancel_held()
		return

	if _is_valid_cell(cell):
		var module: ModuleData = RunState.loadout_grid.get_module_at(cell.x, cell.y)
		if module:
			RunState.loadout_grid.remove_at(cell.x, cell.y)
			_held_module = module
			_held_source = "grid"
			_held_rotation = 0
			_info_label.text = module.display_name + " — R to rotate, click grid to place, ESC to cancel"
			_rebuild_inventory()
			queue_redraw()
			return

	var inv_index: int = _inventory_hit_test(pos)
	if inv_index >= 0:
		_held_module = RunState.module_inventory[inv_index]
		RunState.module_inventory.remove_at(inv_index)
		_held_source = "inventory"
		_held_inventory_index = inv_index
		_held_rotation = 0
		_info_label.text = _held_module.display_name + " — R to rotate, click grid to place, ESC to cancel"
		_rebuild_inventory()
		queue_redraw()


func _cancel_held() -> void:
	if not _held_module:
		return
	RunState.module_inventory.append(_held_module)
	_held_module = null
	_held_source = ""
	_held_rotation = 0
	_info_label.text = ""
	_rebuild_inventory()
	queue_redraw()


func _draw() -> void:
	_draw_grid_cells()
	_draw_placed_modules()
	_draw_grid_stats()
	if _held_module:
		_draw_ghost()


func _draw_grid_stats() -> void:
	var used: int = 0
	var unlocked: int = RunState.loadout_grid.get_unlocked_count()
	for row: int in LoadoutGrid.ROWS:
		for col: int in LoadoutGrid.COLS:
			if RunState.loadout_grid.get_module_at(col, row) != null:
				used += 1
	var stats: String = "Cells: " + str(used) + "/" + str(unlocked) + " used | Modules: " + str(RunState.loadout_grid.get_module_count()) + " placed, " + str(RunState.module_inventory.size()) + " in inventory"
	var stats_pos: Vector2 = GRID_ORIGIN + Vector2(0, LoadoutGrid.ROWS * (CELL_SIZE.y + CELL_GAP) + 8)
	draw_string(_font, stats_pos, stats, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ThemeBuilder.TEXT_SECONDARY)


func _draw_grid_cells() -> void:
	for row: int in LoadoutGrid.ROWS:
		for col: int in LoadoutGrid.COLS:
			var rect: Rect2 = _cell_rect(col, row)

			if not RunState.loadout_grid.is_unlocked(col, row):
				if _unlock_mode and RunState.loadout_grid.can_unlock_cell(col, row):
					draw_rect(rect, Color(0.12, 0.25, 0.12, 0.6), true)
					draw_rect(rect, Color(0.3, 0.9, 0.3, 0.7), false, 2.0)
				else:
					draw_rect(rect, Color(0.04, 0.04, 0.06, 0.3), true)
					draw_rect(rect, Color(0.10, 0.10, 0.12, 0.3), false)
			elif RunState.loadout_grid.is_cell_empty(col, row):
				draw_rect(rect, Color(0.10, 0.12, 0.18, 0.5), true)
				draw_rect(rect, Color(0.20, 0.25, 0.30, 0.5), false)


func _draw_placed_modules() -> void:
	for placement: Dictionary in RunState.loadout_grid.get_placements():
		var module: ModuleData = placement["module"] as ModuleData
		if not module:
			continue
		var origin: Vector2i = placement["origin"] as Vector2i
		var shape: Array = placement.get("shape", module.grid_shape) as Array
		var fill: Color = _module_fill_color(module)
		var border: Color = _module_border_color(module)

		_draw_shape(shape, origin, fill, border)

		var max_shape_col: int = 0
		for offset: Variant in shape:
			var v: Vector2i = offset as Vector2i
			max_shape_col = maxi(max_shape_col, v.x)
		var text_width: int = int((max_shape_col + 1) * (CELL_SIZE.x + CELL_GAP) - 12)
		var label_pos: Vector2 = _cell_rect(origin.x, origin.y).position

		draw_string(_font, label_pos + Vector2(6, 18), module.display_name,
			HORIZONTAL_ALIGNMENT_LEFT, text_width, 12, border)

		var tag: String = _effect_tag(module)
		draw_string(_font, label_pos + Vector2(6, 34), tag,
			HORIZONTAL_ALIGNMENT_LEFT, text_width, 10, border.lerp(ThemeBuilder.TEXT_SECONDARY, 0.4))

		if module.description.length() > 0:
			draw_string(_font, label_pos + Vector2(6, 48), module.description,
				HORIZONTAL_ALIGNMENT_LEFT, text_width, 8, ThemeBuilder.TEXT_SECONDARY)


func _draw_ghost() -> void:
	if not _held_module or _hover_cell == Vector2i(-1, -1):
		return

	var shape: Array[Vector2i] = _held_module.get_rotated_shape(_held_rotation)
	var can_place: bool = RunState.loadout_grid.can_place(_held_module, _hover_cell.x, _hover_cell.y, _held_rotation)
	var module_border: Color = _module_border_color(_held_module)

	var ghost_fill: Color
	var ghost_border: Color
	if can_place:
		ghost_fill = _module_fill_color(_held_module) * Color(1, 1, 1, 0.6)
		ghost_border = module_border * Color(1, 1, 1, 0.8)
	else:
		ghost_fill = Color(0.35, 0.08, 0.08, 0.4)
		ghost_border = Color(0.9, 0.25, 0.2, 0.6)

	var shape_as_array: Array = []
	for v: Vector2i in shape:
		shape_as_array.append(v)
	_draw_shape(shape_as_array, _hover_cell, ghost_fill, ghost_border)

	var name_rect: Rect2 = _cell_rect(_hover_cell.x, _hover_cell.y)
	draw_string(_font, name_rect.position + Vector2(6, 18), _held_module.display_name,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE if can_place else Color(0.9, 0.4, 0.4))


func _draw_shape(shape: Array, origin: Vector2i, fill: Color, border: Color) -> void:
	for offset: Variant in shape:
		var v: Vector2i = offset as Vector2i
		draw_rect(_cell_rect(origin.x + v.x, origin.y + v.y), fill, true)

	for offset: Variant in shape:
		var v: Vector2i = offset as Vector2i
		var rect: Rect2 = _cell_rect(origin.x + v.x, origin.y + v.y)
		if Vector2i(v.x + 1, v.y) in shape:
			draw_rect(Rect2(rect.end.x, rect.position.y, CELL_GAP, CELL_SIZE.y), fill, true)
		if Vector2i(v.x, v.y + 1) in shape:
			draw_rect(Rect2(rect.position.x, rect.end.y, CELL_SIZE.x, CELL_GAP), fill, true)

	for offset: Variant in shape:
		var v: Vector2i = offset as Vector2i
		var rect: Rect2 = _cell_rect(origin.x + v.x, origin.y + v.y)
		if Vector2i(v.x - 1, v.y) not in shape:
			draw_line(rect.position, Vector2(rect.position.x, rect.end.y), border, 2.0)
		if Vector2i(v.x + 1, v.y) not in shape:
			draw_line(Vector2(rect.end.x, rect.position.y), rect.end, border, 2.0)
		if Vector2i(v.x, v.y - 1) not in shape:
			draw_line(rect.position, Vector2(rect.end.x, rect.position.y), border, 2.0)
		if Vector2i(v.x, v.y + 1) not in shape:
			draw_line(Vector2(rect.position.x, rect.end.y), rect.end, border, 2.0)


func _rebuild_inventory() -> void:
	for child: Node in _inventory_list.get_children():
		child.queue_free()

	if RunState.module_inventory.is_empty():
		var empty := Label.new()
		empty.text = "No modules in inventory"
		empty.add_theme_font_size_override("font_size", 12)
		empty.add_theme_color_override("font_color", ThemeBuilder.TEXT_SECONDARY)
		_inventory_list.add_child(empty)
		return

	for i: int in RunState.module_inventory.size():
		var module: ModuleData = RunState.module_inventory[i]
		var btn := Button.new()
		btn.text = module.display_name + " [" + _effect_tag(module) + "] — " + module.description
		btn.add_theme_font_size_override("font_size", 11)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.name = "InvItem" + str(i)
		_inventory_list.add_child(btn)


func _inventory_hit_test(screen_pos: Vector2) -> int:
	for i: int in _inventory_list.get_child_count():
		var child: Control = _inventory_list.get_child(i) as Control
		if not child:
			continue
		var rect: Rect2 = child.get_global_rect()
		if rect.has_point(screen_pos):
			if i < RunState.module_inventory.size():
				return i
	return -1


func _cell_rect(col: int, row: int) -> Rect2:
	var pos: Vector2 = GRID_ORIGIN + Vector2(
		col * (CELL_SIZE.x + CELL_GAP),
		row * (CELL_SIZE.y + CELL_GAP),
	)
	return Rect2(pos, CELL_SIZE)


func _screen_to_grid(screen_pos: Vector2) -> Vector2i:
	var local: Vector2 = screen_pos - GRID_ORIGIN
	var col: int = int(local.x / (CELL_SIZE.x + CELL_GAP))
	var row: int = int(local.y / (CELL_SIZE.y + CELL_GAP))
	if col < 0 or col >= LoadoutGrid.COLS or row < 0 or row >= LoadoutGrid.ROWS:
		return Vector2i(-1, -1)
	var cell_local_x: float = local.x - col * (CELL_SIZE.x + CELL_GAP)
	var cell_local_y: float = local.y - row * (CELL_SIZE.y + CELL_GAP)
	if cell_local_x > CELL_SIZE.x or cell_local_y > CELL_SIZE.y:
		return Vector2i(-1, -1)
	return Vector2i(col, row)


func _is_valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < LoadoutGrid.COLS and cell.y >= 0 and cell.y < LoadoutGrid.ROWS


func _is_on_grid(pos: Vector2) -> bool:
	var grid_rect: Rect2 = Rect2(
		GRID_ORIGIN,
		Vector2(
			LoadoutGrid.COLS * (CELL_SIZE.x + CELL_GAP),
			LoadoutGrid.ROWS * (CELL_SIZE.y + CELL_GAP),
		)
	)
	return grid_rect.has_point(pos)


func _on_done_pressed() -> void:
	if _held_module:
		_cancel_held()
	if RunState.loadout_grid.get_all_modules().is_empty():
		_info_label.text = "WARNING: No modules on grid! Place at least one module before proceeding."
		_info_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.2))
		return
	var return_to: String = "trader" if RunState.pending_cell_unlock else "map"
	RunState.pending_cell_unlock = false
	EventBus.screen_transition_requested.emit(return_to)


func _module_fill_color(module: ModuleData) -> Color:
	match module.effect_type:
		ModuleData.EffectType.DAMAGE:
			return Color(0.22, 0.08, 0.08, 0.85)
		ModuleData.EffectType.SHIELD:
			return Color(0.08, 0.16, 0.24, 0.85)
		ModuleData.EffectType.HEAL:
			return Color(0.08, 0.20, 0.10, 0.85)
		ModuleData.EffectType.DEBUFF_WEAK:
			return Color(0.16, 0.08, 0.20, 0.85)
		ModuleData.EffectType.DEBUFF_VULNERABLE:
			return Color(0.20, 0.08, 0.16, 0.85)
		ModuleData.EffectType.BUFF_STRENGTH:
			return Color(0.20, 0.16, 0.06, 0.85)
	return Color(0.12, 0.12, 0.18, 0.85)


func _module_border_color(module: ModuleData) -> Color:
	match module.effect_type:
		ModuleData.EffectType.DAMAGE:
			return Color(0.9, 0.35, 0.2)
		ModuleData.EffectType.SHIELD:
			return Color(0.3, 0.7, 0.85)
		ModuleData.EffectType.HEAL:
			return Color(0.3, 0.8, 0.4)
		ModuleData.EffectType.DEBUFF_WEAK:
			return Color(0.7, 0.4, 0.8)
		ModuleData.EffectType.DEBUFF_VULNERABLE:
			return Color(0.8, 0.4, 0.6)
		ModuleData.EffectType.BUFF_STRENGTH:
			return Color(0.9, 0.7, 0.3)
	return Color(0.5, 0.6, 0.7)


func _effect_tag(module: ModuleData) -> String:
	var tag: String = ""
	match module.effect_type:
		ModuleData.EffectType.DAMAGE: tag = "DMG"
		ModuleData.EffectType.SHIELD: tag = "SHD"
		ModuleData.EffectType.HEAL: tag = "HEAL"
		ModuleData.EffectType.DEBUFF_WEAK: tag = "WEAK"
		ModuleData.EffectType.DEBUFF_VULNERABLE: tag = "VULN"
		ModuleData.EffectType.BUFF_STRENGTH: tag = "STR"
	var sockets: int = module.socket_requirements.size()
	return tag + " · " + str(sockets) + " slot" + ("s" if sockets != 1 else "")
