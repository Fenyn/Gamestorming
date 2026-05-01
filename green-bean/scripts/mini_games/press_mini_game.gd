class_name PressMiniGame
extends BaseMiniGame

enum Phase { IDLE, STEEPING, READY, PRESSING, OVER_EXTRACTING, DEAD }

const STEEP_TIME := 10.0
const READY_WINDOW := 8.0
const OVER_EXTRACT_TIME := 10.0
const PRESS_DURATION := 8.0
const BAR_WIDTH := 0.2

const NEEDLE_DRIFT_SPEED := 0.4
const NEEDLE_CORRECTION := 0.006
const ZONE_START := 0.35
const ZONE_END := 0.18

var phase := Phase.IDLE
var phase_timer := 0.0
var press_progress := 0.0
var _pressing := false
var _started_phase := Phase.READY
var _needle_x := 0.5
var _needle_y := 0.5
var _drift_x := 1.0
var _drift_y := 0.5
var _in_zone_time := 0.0
var _total_press_time := 0.0

var _indicator_label: Label3D = null
var _bar_bg: CSGBox3D = null
var _bar_fill: CSGBox3D = null
var _zone_ring: CSGBox3D = null
var _needle_dot: CSGBox3D = null

func _ready() -> void:
	super._ready()
	station_name = "aeropress"

	_indicator_label = Label3D.new()
	_indicator_label.text = ""
	_indicator_label.font_size = 14
	_indicator_label.position = Vector3(0, 0.28, 0.18)
	_indicator_label.pixel_size = 0.001
	_indicator_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_indicator_label)

	_bar_bg = CSGBox3D.new()
	_bar_bg.size = Vector3(BAR_WIDTH, 0.015, 0.015)
	_bar_bg.position = Vector3(0, 0.22, 0.18)
	var bg := StandardMaterial3D.new()
	bg.albedo_color = Color(0.2, 0.2, 0.2)
	_bar_bg.material = bg
	add_child(_bar_bg)

	_bar_fill = CSGBox3D.new()
	_bar_fill.size = Vector3(0.001, 0.015, 0.016)
	_bar_fill.position = Vector3(-BAR_WIDTH / 2.0, 0.22, 0.18)
	var bf := StandardMaterial3D.new()
	bf.albedo_color = Color(0.3, 0.7, 0.9)
	_bar_fill.material = bf
	add_child(_bar_fill)

	_zone_ring = CSGBox3D.new()
	_zone_ring.size = Vector3(0.08, 0.08, 0.01)
	_zone_ring.position = Vector3(0, 0.12, 0.18)
	var zmat := StandardMaterial3D.new()
	zmat.albedo_color = Color(0.15, 0.3, 0.15)
	_zone_ring.material = zmat
	add_child(_zone_ring)

	_needle_dot = CSGBox3D.new()
	_needle_dot.size = Vector3(0.015, 0.015, 0.012)
	_needle_dot.position = Vector3(0, 0.12, 0.18)
	var nmat := StandardMaterial3D.new()
	nmat.albedo_color = Color(0.9, 0.9, 0.2)
	_needle_dot.material = nmat
	add_child(_needle_dot)

func _on_start() -> void:
	press_progress = 0.0
	_pressing = false
	_needle_x = 0.5
	_needle_y = 0.5
	_drift_x = (randf() - 0.5) * 2.0
	_drift_y = (randf() - 0.5) * 2.0
	_in_zone_time = 0.0
	_total_press_time = 0.0
	if _indicator_label:
		_indicator_label.text = "Hold LClick\nKeep pressure centered"

func _on_stop() -> void:
	SoundManager.stop_loop("press_loop")
	if phase == Phase.PRESSING:
		phase = _started_phase
		press_progress = 0.0
		_pressing = false

func can_start(_player_ref: Player) -> bool:
	return not _active and (phase == Phase.READY or phase == Phase.OVER_EXTRACTING)

func start_steeping() -> void:
	phase = Phase.STEEPING
	phase_timer = STEEP_TIME

func reset_phase() -> void:
	phase = Phase.IDLE
	phase_timer = 0.0
	press_progress = 0.0
	_pressing = false
	_needle_x = 0.5
	_needle_y = 0.5

func _process(delta: float) -> void:
	_tick_passive(delta)
	if _active:
		_update_mini_game(delta)

func _tick_passive(delta: float) -> void:
	match phase:
		Phase.STEEPING:
			phase_timer -= delta
			if phase_timer <= 0:
				phase = Phase.READY
				phase_timer = READY_WINDOW
				SoundManager.play("shot_ready")
		Phase.READY:
			if not _active:
				phase_timer -= delta
				if phase_timer <= 0:
					phase = Phase.OVER_EXTRACTING
					phase_timer = OVER_EXTRACT_TIME
					SoundManager.play("over_extract_warn")
		Phase.OVER_EXTRACTING:
			phase_timer -= delta
			if phase_timer <= 0:
				phase = Phase.DEAD
				SoundManager.play("shot_dead")

func _update_mini_game(delta: float) -> void:
	if phase == Phase.PRESSING:
		if _pressing:
			press_progress += delta / PRESS_DURATION
			_total_press_time += delta

			_needle_x += _drift_x * NEEDLE_DRIFT_SPEED * delta
			_needle_y += _drift_y * NEEDLE_DRIFT_SPEED * delta

			if randf() < 0.05:
				_drift_x = (randf() - 0.5) * 2.0
			if randf() < 0.05:
				_drift_y = (randf() - 0.5) * 2.0

			_needle_x = clampf(_needle_x, 0.0, 1.0)
			_needle_y = clampf(_needle_y, 0.0, 1.0)

			if _needle_x <= 0.05 or _needle_x >= 0.95:
				_drift_x = -_drift_x
			if _needle_y <= 0.05 or _needle_y >= 0.95:
				_drift_y = -_drift_y

			var progress_ratio := clampf(press_progress, 0.0, 1.0)
			var zone_radius := lerpf(ZONE_START, ZONE_END, progress_ratio)
			var dist := Vector2(_needle_x - 0.5, _needle_y - 0.5).length()
			if dist <= zone_radius:
				_in_zone_time += delta

		_update_visuals()

		if _indicator_label:
			_indicator_label.text = "PRESSING %.0f%%\nHold LClick, keep centered" % (press_progress * 100)

		if press_progress >= 1.0:
			press_progress = 1.0
			_update_visuals()
			_finish_press()

	elif phase == Phase.READY:
		if _indicator_label:
			_indicator_label.text = "Hold LClick to press\n%.0fs left" % maxf(phase_timer, 0)
	elif phase == Phase.OVER_EXTRACTING:
		if _indicator_label:
			_indicator_label.text = "OVER-EXTRACTING!\nHold LClick to press"

func _handle_input(event: InputEvent) -> void:
	if phase == Phase.READY or phase == Phase.OVER_EXTRACTING:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_started_phase = phase
				phase = Phase.PRESSING
				_pressing = true
				SoundManager.play_loop("press_loop")
			else:
				_pressing = false
				SoundManager.stop_loop("press_loop")

	if phase == Phase.PRESSING:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			_pressing = event.pressed

		if event is InputEventMouseMotion and _pressing:
			_needle_x += event.relative.x * NEEDLE_CORRECTION
			_needle_y -= event.relative.y * NEEDLE_CORRECTION
			_needle_x = clampf(_needle_x, 0.0, 1.0)
			_needle_y = clampf(_needle_y, 0.0, 1.0)

func _update_visuals() -> void:
	if _bar_fill:
		var ratio := clampf(press_progress, 0.0, 1.0)
		var w := BAR_WIDTH * ratio
		_bar_fill.size.x = maxf(w, 0.001)
		_bar_fill.position.x = -BAR_WIDTH / 2.0 + w / 2.0
		var mat := _bar_fill.material as StandardMaterial3D
		if mat:
			mat.albedo_color = Color(0.3, 0.7, 0.9) if ratio < 1.0 else Color(0.3, 1.0, 0.5)

	if _zone_ring:
		var progress_ratio := clampf(press_progress, 0.0, 1.0)
		var zone_radius := lerpf(ZONE_START, ZONE_END, progress_ratio)
		var zone_size := zone_radius * 0.24
		_zone_ring.size = Vector3(zone_size, zone_size, 0.01)

	if _needle_dot and _zone_ring:
		var ox := (_needle_x - 0.5) * 0.12
		var oy := (_needle_y - 0.5) * 0.12
		_needle_dot.position.x = _zone_ring.position.x + ox
		_needle_dot.position.y = _zone_ring.position.y + oy

		var progress_ratio := clampf(press_progress, 0.0, 1.0)
		var zone_radius := lerpf(ZONE_START, ZONE_END, progress_ratio)
		var dist := Vector2(_needle_x - 0.5, _needle_y - 0.5).length()
		var in_zone := dist <= zone_radius
		var nmat := _needle_dot.material as StandardMaterial3D
		if nmat:
			nmat.albedo_color = Color(0.2, 0.9, 0.3) if in_zone else Color(0.9, 0.3, 0.2)

func _finish_press() -> void:
	SoundManager.stop_loop("press_loop")
	SoundManager.play("shot_complete")
	var quality := 1.0
	if _started_phase == Phase.OVER_EXTRACTING:
		quality *= 0.5
	if _total_press_time > 0:
		quality *= clampf(_in_zone_time / _total_press_time, 0.0, 1.0)
	complete(clampf(quality, 0.0, 1.0))

func is_dead() -> bool:
	return phase == Phase.DEAD

func get_phase_name() -> String:
	match phase:
		Phase.IDLE: return "idle"
		Phase.STEEPING: return "steeping"
		Phase.READY: return "ready"
		Phase.PRESSING: return "pressing"
		Phase.OVER_EXTRACTING: return "over_extracting"
		Phase.DEAD: return "dead"
	return "unknown"
