class_name PressMiniGame
extends BaseMiniGame

enum Phase { IDLE, STEEPING, READY, PRESSING, OVER_EXTRACTING, DEAD }

const STEEP_TIME := 10.0
const READY_WINDOW := 8.0
const OVER_EXTRACT_TIME := 10.0
const PRESS_DURATION := 3.0
const GREEN_ZONE_MIN := 0.3
const GREEN_ZONE_MAX := 0.7
const BAR_WIDTH := 0.2

var phase := Phase.IDLE
var phase_timer := 0.0
var press_progress := 0.0
var _press_samples: Array[float] = []
var _pressing := false
var _started_phase := Phase.READY
var _last_speed := 0.0

var _indicator_label: Label3D = null
var _bar_bg: CSGBox3D = null
var _bar_fill: CSGBox3D = null
var _zone_indicator: CSGBox3D = null

func _ready() -> void:
	super._ready()
	station_name = "aeropress"

	_indicator_label = Label3D.new()
	_indicator_label.text = ""
	_indicator_label.font_size = 14
	_indicator_label.position = Vector3(0, 0.25, 0.18)
	_indicator_label.pixel_size = 0.001
	_indicator_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_indicator_label)

	# Progress bar
	_bar_bg = CSGBox3D.new()
	_bar_bg.size = Vector3(BAR_WIDTH, 0.02, 0.02)
	_bar_bg.position = Vector3(0, 0.17, 0.18)
	var bg_mat := StandardMaterial3D.new()
	bg_mat.albedo_color = Color(0.2, 0.2, 0.2)
	_bar_bg.material = bg_mat
	add_child(_bar_bg)

	_bar_fill = CSGBox3D.new()
	_bar_fill.size = Vector3(0.001, 0.02, 0.021)
	_bar_fill.position = Vector3(-BAR_WIDTH / 2.0, 0.17, 0.18)
	var fill_mat := StandardMaterial3D.new()
	fill_mat.albedo_color = Color(0.3, 0.7, 0.9)
	_bar_fill.material = fill_mat
	add_child(_bar_fill)

	# Speed zone indicator
	_zone_indicator = CSGBox3D.new()
	_zone_indicator.size = Vector3(0.03, 0.025, 0.022)
	_zone_indicator.position = Vector3(0, 0.10, 0.18)
	_zone_indicator.size = Vector3(0.04, 0.03, 0.022)
	var zone_mat := StandardMaterial3D.new()
	zone_mat.albedo_color = Color(0.5, 0.5, 0.5)
	_zone_indicator.material = zone_mat
	add_child(_zone_indicator)

func _on_start() -> void:
	press_progress = 0.0
	_press_samples.clear()
	_pressing = false
	_last_speed = 0.0
	if _indicator_label:
		_indicator_label.text = "Hold LClick + drag down"

func _on_stop() -> void:
	if phase == Phase.PRESSING:
		phase = _started_phase
		press_progress = 0.0
		_press_samples.clear()
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
	_press_samples.clear()
	_pressing = false
	_last_speed = 0.0

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
		Phase.READY:
			if not _active:
				phase_timer -= delta
				if phase_timer <= 0:
					phase = Phase.OVER_EXTRACTING
					phase_timer = OVER_EXTRACT_TIME
		Phase.OVER_EXTRACTING:
			phase_timer -= delta
			if phase_timer <= 0:
				phase = Phase.DEAD

func _update_mini_game(delta: float) -> void:
	if phase == Phase.PRESSING:
		if _pressing:
			press_progress += delta / PRESS_DURATION
		_update_progress_bar()
		_update_zone_indicator()
		if _indicator_label:
			_indicator_label.text = "PRESSING %.0f%%\nHold LClick + drag down" % (press_progress * 100)
		if press_progress >= 1.0:
			press_progress = 1.0
			_update_progress_bar()
			_finish_press()
	elif phase == Phase.READY:
		if _indicator_label:
			_indicator_label.text = "Hold LClick to press\n%.0fs left" % maxf(phase_timer, 0)
	elif phase == Phase.OVER_EXTRACTING:
		if _indicator_label:
			_indicator_label.text = "OVER-EXTRACTING!\nHold LClick to press"

func _update_progress_bar() -> void:
	if not _bar_fill:
		return
	var ratio := clampf(press_progress, 0.0, 1.0)
	var fill_w := BAR_WIDTH * ratio
	_bar_fill.size.x = maxf(fill_w, 0.001)
	_bar_fill.position.x = -BAR_WIDTH / 2.0 + fill_w / 2.0
	var mat := _bar_fill.material as StandardMaterial3D
	if mat:
		mat.albedo_color = Color(0.3, 0.7, 0.9) if ratio < 1.0 else Color(0.3, 1.0, 0.5)

func _update_zone_indicator() -> void:
	if not _zone_indicator:
		return
	var mat := _zone_indicator.material as StandardMaterial3D
	if not mat:
		return
	if _last_speed >= GREEN_ZONE_MIN and _last_speed <= GREEN_ZONE_MAX:
		mat.albedo_color = Color(0.2, 0.9, 0.2)
	elif _last_speed > 0.01:
		mat.albedo_color = Color(0.9, 0.3, 0.2)
	else:
		mat.albedo_color = Color(0.5, 0.5, 0.5)

func _handle_input(event: InputEvent) -> void:
	if phase == Phase.READY or phase == Phase.OVER_EXTRACTING:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_started_phase = phase
				phase = Phase.PRESSING
				_pressing = true
			else:
				_pressing = false

	if phase == Phase.PRESSING:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_pressing = true
			else:
				_pressing = false

		if event is InputEventMouseMotion and _pressing:
			var speed := absf(event.relative.y) / 100.0
			_last_speed = clampf(speed, 0.0, 1.0)
			_press_samples.append(_last_speed)

func _finish_press() -> void:
	var quality := 1.0
	if _started_phase == Phase.OVER_EXTRACTING:
		quality *= 0.5

	if _press_samples.size() > 0:
		var in_zone := 0
		for s in _press_samples:
			if s >= GREEN_ZONE_MIN and s <= GREEN_ZONE_MAX:
				in_zone += 1
		quality *= float(in_zone) / float(_press_samples.size())

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
