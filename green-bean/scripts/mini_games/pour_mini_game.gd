class_name PourMiniGame
extends BaseMiniGame

## Two pours share this game:
## - SATURATION (pour-over): aim the kettle stream over the grounds bed and wet it
##   evenly. A bloom pour, a passive bloom wait, the main pour, then draw-down and
##   cooling. The station draws the bed from get_saturation_image().
## - FILL_LINE (shot press water, americano): hold to pour, let go at the line.
##   Pouring on past overflow_level spills.
## Nothing here is drawn: the stations show the result on their own models.

enum PourMode { SATURATION, FILL_LINE }
enum Phase { IDLE, BLOOM_POUR, BLOOM_WAIT, MAIN_POUR, DRAW_DOWN, COOLING }

const GRID_SIZE := 7
const POUR_RATE := 0.3
const SATURATION_PER_HIT := 5.0
const SATURATION_SPREAD := 0.4
const BLOOM_TARGET := 0.15
const MAIN_TARGET := 0.85
const BLOOM_WAIT_TIME := 20.0
const DRAW_DOWN_TIME := 15.0
const COFFEE_COOL_TIME := 20.0
const FILL_OVERFLOW_THRESHOLD := 1.05
const MOUSE_SENSITIVITY := 0.004

@export var pour_mode: PourMode = PourMode.SATURATION
## Fill level (1 = the line) where the liquid reaches the rim and spills.
var overflow_level := FILL_OVERFLOW_THRESHOLD

var phase := Phase.IDLE
var phase_timer := 0.0

## Saturation 0..1 per cell; cells outside the round bed are skipped.
var _saturation_grid: Array[float] = []
var _grid_positions: Array[Vector2] = []
var _grid_cells: Array[Vector2i] = []
var _saturation_image: Image = null
var _pour_position := Vector2(0.0, 0.0)
var _pouring := false
var _fill_level := 0.0
var _fill_target := 1.0
var _overflowed := false
var _bloom_quality := 1.0
var _size_multiplier := 1.0

func _ready() -> void:
	super._ready()
	station_name = "pour_over"
	_build_grid()

func _build_grid() -> void:
	_grid_positions.clear()
	_grid_cells.clear()
	_saturation_grid.clear()
	var half := (GRID_SIZE - 1) / 2.0
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var nx := (x - half) / half
			var ny := (y - half) / half
			if Vector2(nx, ny).length() > 1.1:
				continue
			_grid_positions.append(Vector2(nx, ny))
			_grid_cells.append(Vector2i(x, y))
			_saturation_grid.append(0.0)
	_saturation_image = Image.create(GRID_SIZE, GRID_SIZE, false, Image.FORMAT_L8)

func _init_grid() -> void:
	for i in range(_saturation_grid.size()):
		_saturation_grid[i] = 0.0

func set_mode(mode: PourMode) -> void:
	pour_mode = mode

func set_size_multiplier(mult: float) -> void:
	_size_multiplier = mult

func _on_start() -> void:
	SoundManager.play_loop("pour_loop")
	if phase == Phase.MAIN_POUR and pour_mode == PourMode.SATURATION:
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
	else:
		phase = Phase.MAIN_POUR

func _on_stop() -> void:
	_pouring = false
	SoundManager.stop_loop("pour_loop")

func get_controls_hint() -> String:
	if pour_mode == PourMode.FILL_LINE:
		return hint([["Hold click", "Pour"], ["Release", "Stop at the line"], ["E", "Leave"]])
	return hint([["Hold click", "Pour"], ["Move mouse", "Aim the stream"], ["E", "Leave"]])

func get_assist_readout() -> String:
	if pour_mode == PourMode.FILL_LINE:
		return "Fill  %d%%" % roundi(_fill_level * 100.0)
	var avg := _get_avg_saturation()
	if phase == Phase.BLOOM_POUR:
		return "Bloom  %d%%" % roundi(minf(avg / BLOOM_TARGET, 1.0) * 100.0)
	return "Wet  %d%%      Even  %d%%" % [roundi(minf(avg / MAIN_TARGET, 1.0) * 100.0), roundi(_calculate_evenness() * 100.0)]

func _handle_input(event: InputEvent) -> void:
	if phase == Phase.BLOOM_WAIT or phase == Phase.DRAW_DOWN or phase == Phase.COOLING:
		return

	if event.is_action("use"):
		_pouring = event.is_pressed()

	if event is InputEventMouseMotion and pour_mode == PourMode.SATURATION:
		# The kettle can be aimed before the water starts.
		_pour_position.x += event.relative.x * MOUSE_SENSITIVITY
		_pour_position.y += event.relative.y * MOUSE_SENSITIVITY
		var len := _pour_position.length()
		if len > 1.0:
			_pour_position = _pour_position / len

func _process(delta: float) -> void:
	_tick_passive(delta)
	if is_playing():
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
	match phase:
		Phase.BLOOM_POUR:
			_update_saturation_pour(delta, true)
		Phase.MAIN_POUR:
			if pour_mode == PourMode.SATURATION:
				_update_saturation_pour(delta, false)
			else:
				_update_fill(delta)

func _update_saturation_pour(delta: float, is_bloom: bool) -> void:
	if not _pouring:
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
	var avg := _get_avg_saturation()

	if is_bloom and avg >= BLOOM_TARGET:
		_bloom_quality = _calculate_evenness()
		_pouring = false
		phase = Phase.BLOOM_WAIT
		phase_timer = BLOOM_WAIT_TIME
		SoundManager.stop_loop("pour_loop")
		end_after(0.6)
	elif not is_bloom and avg >= MAIN_TARGET:
		_pouring = false
		phase = Phase.DRAW_DOWN
		phase_timer = DRAW_DOWN_TIME
		SoundManager.stop_loop("pour_loop")
		SoundManager.play_loop("drip_loop")
		var quality := _calculate_evenness() * _bloom_quality
		complete(quality, 0.6)

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

func _update_fill(delta: float) -> void:
	if not _pouring:
		if _fill_level >= 0.9:
			SoundManager.stop_loop("pour_loop")
			complete(_calculate_fill_quality(), 0.45)
		return
	_fill_level += POUR_RATE * delta / _size_multiplier
	if _fill_level >= overflow_level:
		_fill_level = overflow_level
		_overflowed = true
		_pouring = false
		SoundManager.stop_loop("pour_loop")
		SoundManager.play("spill")
		complete(0.0, 0.9)

func _get_avg_saturation() -> float:
	if _saturation_grid.is_empty():
		return 0.0
	var total := 0.0
	for s in _saturation_grid:
		total += s
	return total / _saturation_grid.size()

## Saturation as a GRID_SIZE square greyscale image (white = soaked), for the
## station to filter smoothly across the grounds bed.
func get_saturation_image() -> Image:
	_saturation_image.fill(Color.BLACK)
	for i in range(_grid_cells.size()):
		var v := clampf(_saturation_grid[i], 0.0, 1.0)
		_saturation_image.set_pixelv(_grid_cells[i], Color(v, v, v))
	return _saturation_image

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

## Where the stream lands, in the unit circle over the bed (+x right, +y toward
## the camera).
func get_pour_position() -> Vector2:
	return _pour_position

func is_pouring() -> bool:
	return is_playing() and _pouring

func is_overflowed() -> bool:
	return _overflowed

func get_fill_level() -> float:
	return _fill_level

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
