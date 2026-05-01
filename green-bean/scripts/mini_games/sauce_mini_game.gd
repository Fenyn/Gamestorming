class_name SauceMiniGame
extends BaseMiniGame

const DRIZZLE_SPEED := 0.003
const GRAVITY_PULL := 0.15
const CUP_RADIUS := 0.4
const CELL_SIZE := 0.08
const DRIZZLE_WIDTH := 0.06

var _squeezing := false
var _cursor_pos := Vector2.ZERO
var _trail_cells: Array[Vector2] = []
var _cell_hit: Dictionary = {}
var _total_cells := 0

var _cell_visuals: Array[CSGCylinder3D] = []
var _cursor_visual: CSGCylinder3D = null
var _trail_parent: Node3D = null
var _count_label: Label3D = null
var _sauce_color := Color(0.25, 0.15, 0.08)

func _ready() -> void:
	super._ready()
	station_name = "sauce"
	_build_grid()
	_build_cursor()

	_count_label = Label3D.new()
	_count_label.text = ""
	_count_label.font_size = 16
	_count_label.pixel_size = 0.001
	_count_label.position = Vector3(0, 0.30, 0.08)
	_count_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_count_label)

func _build_grid() -> void:
	_trail_parent = Node3D.new()
	_trail_parent.name = "TrailCells"
	add_child(_trail_parent)

	_trail_cells.clear()
	_cell_visuals.clear()
	_cell_hit.clear()
	_total_cells = 0

	var step := CELL_SIZE
	var r := CUP_RADIUS - CELL_SIZE * 0.5
	for x_i in range(-5, 6):
		for y_i in range(-5, 6):
			var pos := Vector2(x_i * step, y_i * step)
			if pos.length() > r:
				continue
			_trail_cells.append(pos)
			var idx := _total_cells
			_cell_hit[idx] = false
			_total_cells += 1

			var cell := CSGCylinder3D.new()
			cell.radius = CELL_SIZE * 0.45
			cell.height = 0.002
			cell.position = Vector3(pos.x * 0.12, 0.18, pos.y * 0.12)
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.15, 0.12, 0.1, 0.15)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			cell.material = mat
			_trail_parent.add_child(cell)
			_cell_visuals.append(cell)

func _build_cursor() -> void:
	_cursor_visual = CSGCylinder3D.new()
	_cursor_visual.radius = DRIZZLE_WIDTH * 0.5 * 0.12
	_cursor_visual.height = 0.005
	_cursor_visual.position = Vector3(0, 0.19, 0)
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = _sauce_color
	_cursor_visual.material = cmat
	add_child(_cursor_visual)

func _on_start() -> void:
	_squeezing = false
	_cursor_pos = Vector2.ZERO
	for i in range(_total_cells):
		_cell_hit[i] = false
	_update_visuals()
	_update_label()

func _on_stop() -> void:
	_squeezing = false
	SoundManager.stop_loop("sauce_drizzle_loop")
	var coverage := _get_coverage()
	var evenness := _calc_evenness()
	_quality = clampf(coverage * 0.5 + evenness * 0.5, 0.0, 1.0)
	if coverage > 0.1:
		mini_game_completed.emit(_quality)

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
	# Gravity: sauce drifts toward center slightly
	_cursor_pos = _cursor_pos.lerp(Vector2.ZERO, GRAVITY_PULL * delta)

	# Clamp to cup radius
	if _cursor_pos.length() > CUP_RADIUS:
		_cursor_pos = _cursor_pos.normalized() * CUP_RADIUS

	# Paint cells while squeezing
	if _squeezing:
		for i in range(_total_cells):
			if _cell_hit[i]:
				continue
			var dist := _cursor_pos.distance_to(_trail_cells[i])
			if dist <= DRIZZLE_WIDTH:
				_cell_hit[i] = true

	_update_visuals()
	_update_label()

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
	# Divide cup into 4 quadrants, score evenness across them
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
	if ratios.is_empty():
		return 0.0
	var avg := 0.0
	for r in ratios:
		avg += r
	avg /= ratios.size()
	var variance := 0.0
	for r in ratios:
		variance += (r - avg) * (r - avg)
	variance /= ratios.size()
	return clampf(1.0 - variance * 4.0, 0.0, 1.0)

func _update_visuals() -> void:
	for i in range(_total_cells):
		if i >= _cell_visuals.size():
			break
		var mat := _cell_visuals[i].material as StandardMaterial3D
		if mat:
			if _cell_hit[i]:
				mat.albedo_color = _sauce_color
				mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			else:
				mat.albedo_color = Color(0.15, 0.12, 0.1, 0.15)
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	if _cursor_visual:
		_cursor_visual.position = Vector3(_cursor_pos.x * 0.12, 0.19, _cursor_pos.y * 0.12)
		_cursor_visual.visible = _squeezing

func _update_label() -> void:
	if _count_label:
		var pct := _get_coverage() * 100.0
		if _squeezing:
			_count_label.text = "Coverage: %.0f%%\nDrizzling..." % pct
		else:
			_count_label.text = "Coverage: %.0f%%\nHold click to drizzle" % pct

func set_sauce_color(color: Color) -> void:
	_sauce_color = color
	if _cursor_visual:
		(_cursor_visual.material as StandardMaterial3D).albedo_color = color
