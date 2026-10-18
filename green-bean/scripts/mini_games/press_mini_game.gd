class_name PressMiniGame
extends BaseMiniGame

enum Phase { IDLE, STEEPING, READY, PRESSING, OVER_EXTRACTING, DEAD }

const STEEP_TIME := 10.0
const READY_WINDOW := 8.0
const OVER_EXTRACT_TIME := 10.0
const PRESS_DURATION := 8.0

## The plunger wanders off-centre and the mouse pushes it back; the station shows
## it as the bubble level on the cap and the press leaning. Offsets run -0.5..0.5
## from centre; inside ZONE_RADIUS counts as a straight press. The wander speeds
## up through the press.
const NEEDLE_DRIFT_START := 0.3
const NEEDLE_DRIFT_END := 0.55
const NEEDLE_CORRECTION := 0.006
const ZONE_RADIUS := 0.24

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

func _ready() -> void:
	super._ready()
	station_name = "shot_press"

func _on_start() -> void:
	press_progress = 0.0
	_pressing = false
	_needle_x = 0.5
	_needle_y = 0.5
	_drift_x = (randf() - 0.5) * 2.0
	_drift_y = (randf() - 0.5) * 2.0
	_in_zone_time = 0.0
	_total_press_time = 0.0

func _on_stop() -> void:
	SoundManager.stop_loop("press_loop")
	if phase == Phase.PRESSING:
		phase = _started_phase
		press_progress = 0.0
		_pressing = false

func get_controls_hint() -> String:
	return hint([["Hold click", "Press down"], ["Move mouse", "Keep the bubble in the ring"], ["E", "Leave"]])

func get_assist_readout() -> String:
	var line := "Pressed  %d%%      %s" % [roundi(press_progress * 100.0), "Straight" if is_in_zone() else "Leaning"]
	if phase == Phase.OVER_EXTRACTING or (phase == Phase.PRESSING and _started_phase == Phase.OVER_EXTRACTING):
		line += "      Over-extracting"
	return line

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
	if is_playing():
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

			var drift := lerpf(NEEDLE_DRIFT_START, NEEDLE_DRIFT_END, clampf(press_progress, 0.0, 1.0))
			_needle_x += _drift_x * drift * delta
			_needle_y += _drift_y * drift * delta

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

			if is_in_zone():
				_in_zone_time += delta

		if press_progress >= 1.0:
			press_progress = 1.0
			_finish_press()

func _handle_input(event: InputEvent) -> void:
	if phase == Phase.READY or phase == Phase.OVER_EXTRACTING:
		if event.is_action("use"):
			if event.is_pressed():
				_started_phase = phase
				phase = Phase.PRESSING
				_pressing = true
				SoundManager.play_loop("press_loop")
			else:
				_pressing = false
				SoundManager.stop_loop("press_loop")

	if phase == Phase.PRESSING:
		if event.is_action("use"):
			_pressing = event.is_pressed()

		if event is InputEventMouseMotion and _pressing:
			_needle_x += event.relative.x * NEEDLE_CORRECTION
			_needle_y -= event.relative.y * NEEDLE_CORRECTION
			_needle_x = clampf(_needle_x, 0.0, 1.0)
			_needle_y = clampf(_needle_y, 0.0, 1.0)

## Plunger offset from straight, each axis -0.5..0.5 (+x right, +y away).
func get_lean() -> Vector2:
	return Vector2(_needle_x - 0.5, _needle_y - 0.5)

func is_in_zone() -> bool:
	return get_lean().length() <= ZONE_RADIUS

func is_pressing() -> bool:
	return is_playing() and phase == Phase.PRESSING and _pressing

func _finish_press() -> void:
	SoundManager.stop_loop("press_loop")
	SoundManager.play("shot_complete")
	var quality := 1.0
	if _started_phase == Phase.OVER_EXTRACTING:
		quality *= 0.5
	if _total_press_time > 0:
		quality *= clampf(_in_zone_time / _total_press_time, 0.0, 1.0)
	complete(clampf(quality, 0.0, 1.0), 0.6)

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
