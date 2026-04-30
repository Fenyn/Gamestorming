class_name PressMiniGame
extends BaseMiniGame

enum Phase { IDLE, STEEPING, READY, PRESSING, OVER_EXTRACTING, DEAD }

const STEEP_TIME := 10.0
const READY_WINDOW := 8.0
const OVER_EXTRACT_TIME := 10.0
const PRESS_DURATION := 3.0
const GREEN_ZONE_MIN := 0.3
const GREEN_ZONE_MAX := 0.7

var phase := Phase.IDLE
var phase_timer := 0.0
var press_progress := 0.0
var _press_samples: Array[float] = []
var _pressing := false
var _started_phase := Phase.READY

var _indicator_label: Label3D = null

func _ready() -> void:
	super._ready()
	station_name = "aeropress"

	_indicator_label = Label3D.new()
	_indicator_label.text = ""
	_indicator_label.font_size = 12
	_indicator_label.position = Vector3(0, 0.35, 0.01)
	_indicator_label.pixel_size = 0.002
	add_child(_indicator_label)

func _on_start() -> void:
	press_progress = 0.0
	_press_samples.clear()
	_pressing = false
	if _indicator_label:
		_indicator_label.text = "Hold LClick + drag down to press"

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

func _process(delta: float) -> void:
	_tick_passive(delta)
	if _active:
		_update_mini_game(delta)

func _tick_passive(delta: float) -> void:
	match phase:
		Phase.STEEPING:
			phase_timer -= delta
			if _indicator_label:
				_indicator_label.text = "STEEPING... %.0f" % maxf(phase_timer, 0)
			if phase_timer <= 0:
				phase = Phase.READY
				phase_timer = READY_WINDOW
		Phase.READY:
			if not _active:
				phase_timer -= delta
				if _indicator_label:
					_indicator_label.text = "READY! %.0f" % maxf(phase_timer, 0)
				if phase_timer <= 0:
					phase = Phase.OVER_EXTRACTING
					phase_timer = OVER_EXTRACT_TIME
		Phase.OVER_EXTRACTING:
			phase_timer -= delta
			if _indicator_label:
				_indicator_label.text = "OVER-EXTRACTING!"
			if phase_timer <= 0:
				phase = Phase.DEAD
				if _indicator_label:
					_indicator_label.text = "DEAD"

func _update_mini_game(delta: float) -> void:
	if phase == Phase.PRESSING:
		if _pressing:
			press_progress += delta / PRESS_DURATION
		if _indicator_label:
			_indicator_label.text = "PRESSING... %.0f%%\nHold LClick + drag down" % (press_progress * 100)
		if press_progress >= 1.0:
			press_progress = 1.0
			_finish_press()
	elif phase == Phase.READY:
		if _indicator_label:
			_indicator_label.text = "READY! Hold LClick to press\n%.0fs left" % maxf(phase_timer, 0)
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
			_press_samples.append(clampf(speed, 0.0, 1.0))

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
