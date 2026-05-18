class_name LoadoutGridDisplay
extends Control

const CELL_SIZE: Vector2 = Vector2(120, 72)
const CELL_GAP: float = 3.0
const MODULE_CARD_SCENE: String = "res://scenes/combat/module_card.tscn"

const COLOR_UNLOCKED: Color = Color(0.10, 0.12, 0.18, 0.4)
const COLOR_LOCKED: Color = Color(0.04, 0.04, 0.06, 0.2)
const COLOR_EXPANDABLE: Color = Color(0.12, 0.18, 0.12, 0.3)
const BORDER_UNLOCKED: Color = Color(0.20, 0.25, 0.30, 0.3)
const BORDER_LOCKED: Color = Color(0.12, 0.12, 0.15, 0.2)
const BORDER_EXPANDABLE: Color = Color(0.20, 0.35, 0.20, 0.4)

var _card_scene: PackedScene
var _cards: Array[ModuleCard] = []
var _grid_ref: LoadoutGrid


func _ready() -> void:
	_card_scene = load(MODULE_CARD_SCENE) as PackedScene
	custom_minimum_size = _get_grid_pixel_size()


func build_from_grid(grid: LoadoutGrid) -> void:
	_grid_ref = grid
	_cards.clear()
	for child: Node in get_children():
		child.queue_free()

	custom_minimum_size = _get_grid_pixel_size()

	var module_index: int = 0
	for placement: Dictionary in grid.get_placements():
		var module: ModuleData = placement["module"] as ModuleData
		if not module:
			continue

		var origin: Vector2i = placement["origin"] as Vector2i
		var shape: Array = placement.get("shape", module.grid_shape) as Array

		var card: ModuleCard = _card_scene.instantiate() as ModuleCard
		card.setup(module, module_index)

		var bounds: Rect2 = _get_shape_bounds(shape)
		card.position = _cell_to_pixel(origin.x, origin.y)
		card.custom_minimum_size = Vector2(
			bounds.size.x * (CELL_SIZE.x + CELL_GAP) - CELL_GAP,
			bounds.size.y * (CELL_SIZE.y + CELL_GAP) - CELL_GAP
		)
		card.size = card.custom_minimum_size

		add_child(card)
		_cards.append(card)
		module_index += 1

	queue_redraw()


func get_cards() -> Array[ModuleCard]:
	return _cards


func _draw() -> void:
	if not _grid_ref:
		return
	for row: int in LoadoutGrid.ROWS:
		for col: int in LoadoutGrid.COLS:
			var pos: Vector2 = _cell_to_pixel(col, row)
			var bg: Color = COLOR_LOCKED
			var border: Color = BORDER_LOCKED

			if _grid_ref.is_unlocked(col, row):
				bg = COLOR_UNLOCKED
				border = BORDER_UNLOCKED
			elif _grid_ref.can_unlock_cell(col, row):
				bg = COLOR_EXPANDABLE
				border = BORDER_EXPANDABLE

			draw_rect(Rect2(pos, CELL_SIZE), bg, true)
			draw_rect(Rect2(pos, CELL_SIZE), border, false)


func _cell_to_pixel(col: int, row: int) -> Vector2:
	return Vector2(
		col * (CELL_SIZE.x + CELL_GAP),
		row * (CELL_SIZE.y + CELL_GAP),
	)


func _get_grid_pixel_size() -> Vector2:
	return Vector2(
		LoadoutGrid.COLS * (CELL_SIZE.x + CELL_GAP) - CELL_GAP,
		LoadoutGrid.ROWS * (CELL_SIZE.y + CELL_GAP) - CELL_GAP,
	)


func _get_shape_bounds(shape: Array) -> Rect2:
	if shape.is_empty():
		return Rect2(0, 0, 1, 1)
	var min_x: int = 999
	var min_y: int = 999
	var max_x: int = -999
	var max_y: int = -999
	for cell: Variant in shape:
		var v: Vector2i = cell as Vector2i
		min_x = mini(min_x, v.x)
		min_y = mini(min_y, v.y)
		max_x = maxi(max_x, v.x)
		max_y = maxi(max_y, v.y)
	return Rect2(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
