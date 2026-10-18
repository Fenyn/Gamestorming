class_name SauceMiniGame
extends BaseMiniGame

## Drizzle sauce over the drink: move the mouse to steer the bottle, hold to
## squeeze. Coverage of the surface (a grid of cells hit by the line) and how
## evenly it is spread across the four quarters set the quality. The cursor
## drifts back toward the middle slowly. The station draws the bottle, the
## stream and the sauce lines; nothing here is visual.

const DRIZZLE_SPEED := 0.003
const GRAVITY_PULL := 0.15
## Cursor range and grid in the game's own units (the cup's radius is 0.4).
const CUP_RADIUS := 0.4
const CELL_SIZE := 0.08
const DRIZZLE_WIDTH := 0.06

var _squeezing := false
var _cursor_pos := Vector2.ZERO
var _trail_cells: Array[Vector2] = []
var _cell_hit: Dictionary = {}
var _total_cells := 0

func _ready() -> void:
	super._ready()
	station_name = "sauce"
	_build_grid()

func _build_grid() -> void:
	_trail_cells.clear()
	_cell_hit.clear()
	_total_cells = 0
	var r := CUP_RADIUS - CELL_SIZE * 0.5
	for x_i in range(-5, 6):
		for y_i in range(-5, 6):
			var pos := Vector2(x_i * CELL_SIZE, y_i * CELL_SIZE)
			if pos.length() > r:
				continue
			_trail_cells.append(pos)
			_cell_hit[_total_cells] = false
			_total_cells += 1

func _on_start() -> void:
	_squeezing = false
	_cursor_pos = Vector2.ZERO
	for i in range(_total_cells):
		_cell_hit[i] = false

func _on_stop() -> void:
	_squeezing = false
	SoundManager.stop_loop("sauce_drizzle_loop")
	var coverage := _get_coverage()
	var evenness := _calc_evenness()
	_quality = clampf(coverage * 0.5 + evenness * 0.5, 0.0, 1.0)
	if coverage > 0.1:
		mini_game_completed.emit(_quality)

func get_controls_hint() -> String:
	return hint([["Hold click", "Squeeze"], ["Move mouse", "Drizzle across the cup"], ["E", "Done"]])

func get_assist_readout() -> String:
	return "Covered  %d%%      Even  %d%%" % [roundi(_get_coverage() * 100.0), roundi(_calc_evenness() * 100.0)]

func _handle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_squeezing = event.pressed
		if _squeezing:
			SoundManager.play_loop("sauce_drizzle_loop")
		else:
			SoundManager.stop_loop("sauce_drizzle_loop")

	if event is InputEventMouseMotion:
		_cursor_pos.x += event.relative.x * DRIZZLE_SPEED
		_cursor_pos.y += event.relative.y * DRIZZLE_SPEED

func _update_mini_game(delta: float) -> void:
	# The hand drifts back toward the middle.
	_cursor_pos = _cursor_pos.lerp(Vector2.ZERO, GRAVITY_PULL * delta)
	if _cursor_pos.length() > CUP_RADIUS:
		_cursor_pos = _cursor_pos.normalized() * CUP_RADIUS
	if _squeezing:
		for i in range(_total_cells):
			if _cell_hit[i]:
				continue
			if _cursor_pos.distance_to(_trail_cells[i]) <= DRIZZLE_WIDTH:
				_cell_hit[i] = true

## Where the bottle points, as a fraction of the cup's radius (+x right, +y
## toward the camera).
func get_aim() -> Vector2:
	return _cursor_pos / CUP_RADIUS

func is_squeezing() -> bool:
	return is_playing() and _squeezing

func _get_coverage() -> float:
	if _total_cells <= 0:
		return 0.0
	var hit := 0
	for i in range(_total_cells):
		if _cell_hit[i]:
			hit += 1
	return float(hit) / float(_total_cells)

func _calc_evenness() -> float:
	if _total_cells <= 0:
		return 0.0
	# Divide the cup into 4 quadrants and score how evenly they are covered.
	var quad_counts := [0, 0, 0, 0]
	var quad_totals := [0, 0, 0, 0]
	for i in range(_total_cells):
		var p := _trail_cells[i]
		var qi := 0
		if p.x >= 0 and p.y >= 0: qi = 0
		elif p.x < 0 and p.y >= 0: qi = 1
		elif p.x < 0 and p.y < 0: qi = 2
		else: qi = 3
		quad_totals[qi] += 1
		if _cell_hit[i]:
			quad_counts[qi] += 1
	var ratios: Array[float] = []
	for q in range(4):
		if quad_totals[q] > 0:
			ratios.append(float(quad_counts[q]) / float(quad_totals[q]))
		else:
			ratios.append(0.0)
	var avg := 0.0
	for r in ratios:
		avg += r
	avg /= ratios.size()
	var variance := 0.0
	for r in ratios:
		variance += (r - avg) * (r - avg)
	variance /= ratios.size()
	return clampf(1.0 - variance * 4.0, 0.0, 1.0)
