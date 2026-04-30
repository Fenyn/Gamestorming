class_name PourMiniGame
extends BaseMiniGame

enum PourMode { SATURATION, FILL_LINE }
enum Phase { IDLE, BLOOM_POUR, BLOOM_WAIT, MAIN_POUR, DRAW_DOWN, COOLING }

const GRID_SIZE := 7
const GRID_RADIUS := 0.035
const CELL_RADIUS := 0.005
const POUR_RATE := 0.3
const SATURATION_PER_HIT := 5.0
const SATURATION_SPREAD := 0.4
const BLOOM_TARGET := 0.15
const BLOOM_WAIT_TIME := 20.0
const DRAW_DOWN_TIME := 15.0
const COFFEE_COOL_TIME := 20.0
const FILL_OVERFLOW_THRESHOLD := 1.05
const MOUSE_SENSITIVITY := 0.004

const DRY_COLOR := Color(0.55, 0.4, 0.25)
const WET_COLOR := Color(0.2, 0.12, 0.05)

@export var pour_mode: PourMode = PourMode.SATURATION

var phase := Phase.IDLE
var phase_timer := 0.0

var _saturation_grid: Array[float] = []
var _grid_positions: Array[Vector2] = []
var _grid_visuals: Array[CSGCylinder3D] = []
var _pour_position := Vector2(0.0, 0.0)
var _pour_cursor: CSGCylinder3D = null
var _pouring := false
var _fill_level := 0.0
var _fill_target := 1.0
var _overflowed := false
var _bloom_quality := 1.0
var _size_multiplier := 1.0

var _status_label: Label3D = null

func _ready() -> void:
	super._ready()
	station_name = "pour_over"

	_status_label = Label3D.new()
	_status_label.text = ""
	_status_label.font_size = 12
	_status_label.position = Vector3(0.06, 0.24, -0.04)
	_status_label.pixel_size = 0.001
	_status_label.rotation_degrees = Vector3(-65, 0, 0)
	add_child(_status_label)

	if pour_mode == PourMode.SATURATION:
		_build_grid_visuals()

func _build_grid_visuals() -> void:
	_grid_positions.clear()
	var half := (GRID_SIZE - 1) / 2.0
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var nx := (x - half) / half
			var ny := (y - half) / half
			if Vector2(nx, ny).length() > 1.1:
				continue
			_grid_positions.append(Vector2(nx, ny))

	for pos in _grid_positions:
		var cell := CSGCylinder3D.new()
		cell.radius = CELL_RADIUS
		cell.height = 0.002
		cell.position = Vector3(pos.x * GRID_RADIUS, 0.24, pos.y * GRID_RADIUS)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = DRY_COLOR
		cell.material = mat
		add_child(cell)
		_grid_visuals.append(cell)
		_saturation_grid.append(0.0)

	_pour_cursor = CSGCylinder3D.new()
	_pour_cursor.radius = 0.003
	_pour_cursor.height = 0.004
	_pour_cursor.position = Vector3(0, 0.25, 0)
	var cursor_mat := StandardMaterial3D.new()
	cursor_mat.albedo_color = Color(0.6, 0.8, 1.0, 0.7)
	cursor_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_pour_cursor.material = cursor_mat
	add_child(_pour_cursor)

func _init_grid() -> void:
	for i in range(_saturation_grid.size()):
		_saturation_grid[i] = 0.0
	_update_grid_colors()

func set_mode(mode: PourMode) -> void:
	pour_mode = mode

func set_size_multiplier(mult: float) -> void:
	_size_multiplier = mult

func _on_start() -> void:
	if phase == Phase.MAIN_POUR:
		_pouring = false
		return
	_init_grid()
	_pour_position = Vector2(0.0, 0.0)
	_pouring = false
	_fill_level = 0.0
	_fill_target = 1.0
	_overflowed = false
	_bloom_quality = 1.0
	phase_timer = 0.0
	if pour_mode == PourMode.SATURATION:
		phase = Phase.BLOOM_POUR
		if _status_label:
			_status_label.text = "BLOOM: wet the grounds\nHold LClick + move"
	else:
		phase = Phase.MAIN_POUR
		if _status_label:
			_status_label.text = "Hold LClick to pour\nRelease at fill line"

func _on_stop() -> void:
	_pouring = false

func _handle_input(event: InputEvent) -> void:
	if phase == Phase.BLOOM_WAIT or phase == Phase.DRAW_DOWN or phase == Phase.COOLING:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_pouring = event.pressed

	if event is InputEventMouseMotion and _pouring:
		if phase == Phase.BLOOM_POUR or phase == Phase.MAIN_POUR:
			_pour_position.x += event.relative.x * MOUSE_SENSITIVITY
			_pour_position.y += event.relative.y * MOUSE_SENSITIVITY
			var len := _pour_position.length()
			if len > 1.0:
				_pour_position = _pour_position / len

func _process(delta: float) -> void:
	_tick_passive(delta)
	if _active:
		_update_mini_game(delta)

func _tick_passive(delta: float) -> void:
	match phase:
		Phase.BLOOM_WAIT:
			phase_timer -= delta
			if phase_timer <= 0:
				phase = Phase.MAIN_POUR
		Phase.DRAW_DOWN:
			phase_timer -= delta
			if phase_timer <= 0:
				phase = Phase.COOLING
				phase_timer = COFFEE_COOL_TIME
		Phase.COOLING:
			phase_timer -= delta

func _update_mini_game(delta: float) -> void:
	if _pour_cursor:
		_pour_cursor.position = Vector3(_pour_position.x * GRID_RADIUS, 0.25, _pour_position.y * GRID_RADIUS)
		_pour_cursor.visible = _pouring and (phase == Phase.BLOOM_POUR or phase == Phase.MAIN_POUR)

	match phase:
		Phase.BLOOM_POUR:
			_update_saturation_pour(delta, true)
		Phase.BLOOM_WAIT:
			if _status_label:
				_status_label.text = "Bloom... %.0fs\nE to walk away" % maxf(phase_timer, 0)
		Phase.MAIN_POUR:
			if pour_mode == PourMode.SATURATION:
				_update_saturation_pour(delta, false)
			else:
				_update_fill(delta)
		Phase.DRAW_DOWN:
			if _status_label:
				_status_label.text = "Draining... %.0fs" % maxf(phase_timer, 0)
		Phase.COOLING:
			if _status_label:
				_status_label.text = "READY! (cooling...)"

func _update_saturation_pour(delta: float, is_bloom: bool) -> void:
	if not _pouring:
		var avg := _get_avg_saturation()
		if _status_label:
			if is_bloom:
				_status_label.text = "BLOOM: wet grounds\nHold LClick + move"
			else:
				_status_label.text = "Pour: %.0f%%\nHold LClick + move" % (avg * 100)
		return

	for i in range(_grid_positions.size()):
		var dist := _grid_positions[i].distance_to(_pour_position)
		if dist < SATURATION_SPREAD:
			var strength := 1.0 - (dist / SATURATION_SPREAD)
			var rate := SATURATION_PER_HIT * strength * delta * (1.0 / _size_multiplier)
			if is_bloom:
				rate *= 0.25
			_saturation_grid[i] = minf(_saturation_grid[i] + rate, 1.0)

	_cascade_overflow(delta)
	_update_grid_colors()
	var avg := _get_avg_saturation()

	if _status_label:
		if is_bloom:
			_status_label.text = "Bloom: %.0f%%" % (avg / BLOOM_TARGET * 100)
		else:
			_status_label.text = "Saturation: %.0f%%" % (avg * 100)

	if is_bloom and avg >= BLOOM_TARGET:
		_bloom_quality = _calculate_evenness()
		_pouring = false
		phase = Phase.BLOOM_WAIT
		phase_timer = BLOOM_WAIT_TIME
		_complete_bloom()
	elif not is_bloom and avg >= 0.85:
		_pouring = false
		phase = Phase.DRAW_DOWN
		phase_timer = DRAW_DOWN_TIME
		var quality := _calculate_evenness() * _bloom_quality
		complete(quality)

func _cascade_overflow(delta: float) -> void:
	var cascade_rate := 3.0 * delta
	for i in range(_grid_positions.size()):
		if _saturation_grid[i] < 0.95:
			continue
		var pos_i := _grid_positions[i]
		var dist_i := pos_i.length()
		for j in range(_grid_positions.size()):
			if i == j or _saturation_grid[j] >= 1.0:
				continue
			var pos_j := _grid_positions[j]
			var cell_dist := pos_i.distance_to(pos_j)
			if cell_dist > 0.35:
				continue
			var dist_j := pos_j.length()
			if dist_j >= dist_i:
				_saturation_grid[j] = minf(_saturation_grid[j] + cascade_rate * (1.0 - cell_dist / 0.35), 1.0)

func _complete_bloom() -> void:
	if _active:
		_active = false
		if _player:
			_player.exit_mini_game()
		_player = null

func _update_fill(delta: float) -> void:
	if not _pouring:
		if _fill_level >= 0.9:
			complete(_calculate_fill_quality())
		return
	_fill_level += POUR_RATE * delta / _size_multiplier
	if _status_label:
		_status_label.text = "Fill: %.0f%%" % (minf(_fill_level, 1.0) * 100)
	if _fill_level >= FILL_OVERFLOW_THRESHOLD:
		_overflowed = true
		complete(0.0)

func _get_avg_saturation() -> float:
	if _saturation_grid.is_empty():
		return 0.0
	var total := 0.0
	for s in _saturation_grid:
		total += s
	return total / _saturation_grid.size()

func _update_grid_colors() -> void:
	for i in range(_grid_visuals.size()):
		var sat := clampf(_saturation_grid[i], 0.0, 1.0)
		var color := DRY_COLOR.lerp(WET_COLOR, sat)
		var mat := _grid_visuals[i].material as StandardMaterial3D
		if mat:
			mat.albedo_color = color

func _calculate_evenness() -> float:
	if _saturation_grid.is_empty():
		return 0.0
	var total := 0.0
	var min_val := 1.0
	for s in _saturation_grid:
		total += s
		min_val = minf(min_val, s)
	var avg := total / _saturation_grid.size()
	return clampf(min_val / maxf(avg, 0.01), 0.0, 1.0)

func _calculate_fill_quality() -> float:
	var distance := absf(_fill_level - _fill_target)
	return clampf(1.0 - distance * 5.0, 0.0, 1.0)

func is_bloom_waiting() -> bool:
	return phase == Phase.BLOOM_WAIT

func is_ready_for_main_pour() -> bool:
	return phase == Phase.MAIN_POUR and not _active

func is_draw_down_active() -> bool:
	return phase == Phase.DRAW_DOWN

func is_coffee_ready() -> bool:
	return phase == Phase.COOLING

func get_bloom_timer() -> float:
	if phase == Phase.BLOOM_WAIT:
		return phase_timer
	return 0.0

func get_coffee_freshness() -> float:
	if phase != Phase.COOLING:
		return 1.0
	return clampf(phase_timer / COFFEE_COOL_TIME, 0.0, 1.0)
