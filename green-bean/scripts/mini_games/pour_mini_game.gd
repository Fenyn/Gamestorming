class_name PourMiniGame
extends BaseMiniGame

enum PourMode { SATURATION, FILL_LINE }

const GRID_SIZE := 5
const POUR_RATE := 0.3
const SATURATION_PER_HIT := 0.25
const DRAW_DOWN_TIME := 15.0
const COFFEE_COOL_TIME := 20.0
const FILL_OVERFLOW_THRESHOLD := 1.05

@export var pour_mode: PourMode = PourMode.SATURATION

var _saturation_grid: Array[float] = []
var _pour_position := Vector2(0.5, 0.5)
var _pouring := false
var _fill_level := 0.0
var _fill_target := 1.0
var _overflowed := false
var _draw_down_active := false
var _draw_down_timer := 0.0
var _coffee_cooling := false
var _cool_timer := 0.0
var _size_multiplier := 1.0

var _status_label: Label3D = null

func _ready() -> void:
	super._ready()
	station_name = "pour_over"
	_init_grid()

	_status_label = Label3D.new()
	_status_label.text = ""
	_status_label.font_size = 12
	_status_label.position = Vector3(0, 0.35, 0.01)
	_status_label.pixel_size = 0.002
	add_child(_status_label)

func _init_grid() -> void:
	_saturation_grid.clear()
	for i in range(GRID_SIZE * GRID_SIZE):
		_saturation_grid.append(0.0)

func set_mode(mode: PourMode) -> void:
	pour_mode = mode

func set_size_multiplier(mult: float) -> void:
	_size_multiplier = mult

func _on_start() -> void:
	_init_grid()
	_pour_position = Vector2(0.5, 0.5)
	_pouring = false
	_fill_level = 0.0
	_fill_target = 1.0
	_overflowed = false
	_draw_down_active = false
	_draw_down_timer = 0.0
	_coffee_cooling = false
	_cool_timer = 0.0
	if _status_label:
		match pour_mode:
			PourMode.SATURATION:
				_status_label.text = "Hold LClick + move mouse to pour\nSaturate the grounds evenly"
			PourMode.FILL_LINE:
				_status_label.text = "Hold LClick to pour\nRelease at the fill line"

func _handle_input(event: InputEvent) -> void:
	if _draw_down_active or _coffee_cooling:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_pouring = event.pressed

	if event is InputEventMouseMotion and _pouring:
		_pour_position.x += event.relative.x * 0.003
		_pour_position.y += event.relative.y * 0.003
		_pour_position.x = clampf(_pour_position.x, 0.0, 1.0)
		_pour_position.y = clampf(_pour_position.y, 0.0, 1.0)

func _process(delta: float) -> void:
	_tick_passive(delta)
	if _active:
		_update_mini_game(delta)

func _tick_passive(delta: float) -> void:
	if _draw_down_active:
		_draw_down_timer -= delta
		if _status_label:
			_status_label.text = "DRAINING... %.0f" % maxf(_draw_down_timer, 0)
		if _draw_down_timer <= 0:
			_draw_down_active = false
			_coffee_cooling = true
			_cool_timer = COFFEE_COOL_TIME
	elif _coffee_cooling:
		_cool_timer -= delta
		if _status_label:
			_status_label.text = "READY! (cooling...)"

func _update_mini_game(delta: float) -> void:
	if _draw_down_active or _coffee_cooling:
		return

	if not _pouring:
		if pour_mode == PourMode.FILL_LINE and _fill_level >= 0.9:
			complete(_calculate_fill_quality())
		return

	match pour_mode:
		PourMode.SATURATION:
			_update_saturation(delta)
		PourMode.FILL_LINE:
			_update_fill(delta)

func _update_saturation(delta: float) -> void:
	var grid_x := int(_pour_position.x * GRID_SIZE)
	var grid_y := int(_pour_position.y * GRID_SIZE)
	grid_x = clampi(grid_x, 0, GRID_SIZE - 1)
	grid_y = clampi(grid_y, 0, GRID_SIZE - 1)
	var idx := grid_y * GRID_SIZE + grid_x
	_saturation_grid[idx] = minf(_saturation_grid[idx] + SATURATION_PER_HIT * delta * (1.0 / _size_multiplier), 1.0)

	var total := 0.0
	for s in _saturation_grid:
		total += s
	var avg := total / _saturation_grid.size()

	if _status_label:
		_status_label.text = "Saturation: %.0f%%" % (avg * 100)

	if avg >= 0.85:
		_draw_down_active = true
		_draw_down_timer = DRAW_DOWN_TIME
		_pouring = false
		var quality := _calculate_saturation_quality()
		complete(quality)

func _update_fill(delta: float) -> void:
	_fill_level += POUR_RATE * delta / _size_multiplier
	if _status_label:
		_status_label.text = "Fill: %.0f%%" % (minf(_fill_level, 1.0) * 100)

	if _fill_level >= FILL_OVERFLOW_THRESHOLD:
		_overflowed = true
		complete(0.0)
		return

	if not _pouring and _fill_level >= 0.9:
		complete(_calculate_fill_quality())

func _finish_pour_over() -> void:
	var quality := _calculate_saturation_quality()
	complete(quality)

func _calculate_saturation_quality() -> float:
	if _saturation_grid.is_empty():
		return 0.0
	var total := 0.0
	var min_val := 1.0
	for s in _saturation_grid:
		total += s
		min_val = minf(min_val, s)
	var avg := total / _saturation_grid.size()
	var evenness := min_val / maxf(avg, 0.01)
	return clampf(evenness, 0.0, 1.0)

func _calculate_fill_quality() -> float:
	var distance_from_target := absf(_fill_level - _fill_target)
	return clampf(1.0 - distance_from_target * 5.0, 0.0, 1.0)

func is_draw_down_active() -> bool:
	return _draw_down_active

func is_coffee_ready() -> bool:
	return _coffee_cooling

func get_coffee_freshness() -> float:
	if not _coffee_cooling:
		return 1.0
	return clampf(_cool_timer / COFFEE_COOL_TIME, 0.0, 1.0)
