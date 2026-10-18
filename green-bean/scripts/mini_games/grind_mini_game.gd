class_name GrindMiniGame
extends BaseMiniGame

## Fires when the setting changes, so the station can turn the ring.
signal grind_level_changed(level: DrinkData.GrindLevel)

const BASE_GRIND_TARGET := 10.0
const CRANK_SPEED := 0.15

var grind_level: DrinkData.GrindLevel = DrinkData.GrindLevel.COARSE
var grind_progress := 0.0
var grind_target := BASE_GRIND_TARGET
var _last_mouse_angle := 0.0
var _total_rotation := 0.0
var _size_multiplier := 1.0
var _last_crank_msec := -100000

func _ready() -> void:
	super._ready()
	station_name = "grinder"

func set_grind_level(level: DrinkData.GrindLevel) -> void:
	if level == grind_level:
		return
	grind_level = level
	grind_level_changed.emit(level)

func toggle_grind_level() -> void:
	if grind_level == DrinkData.GrindLevel.COARSE:
		set_grind_level(DrinkData.GrindLevel.FINE)
	else:
		set_grind_level(DrinkData.GrindLevel.COARSE)

func set_size_multiplier(mult: float) -> void:
	_size_multiplier = mult
	grind_target = BASE_GRIND_TARGET * _size_multiplier

## Empty hopper for the next device; progress otherwise survives stepping away.
func reset_progress() -> void:
	grind_progress = 0.0

func _on_start() -> void:
	grind_target = BASE_GRIND_TARGET * _size_multiplier
	_last_mouse_angle = 0.0
	SoundManager.play_loop("grind_loop")

func _on_stop() -> void:
	SoundManager.stop_loop("grind_loop")

func get_controls_hint() -> String:
	return hint([["Circle mouse", "Crank"], ["Right-click", "Fine / coarse"], ["E", "Leave"]])

func get_assist_readout() -> String:
	return "%s   %d%%" % ["FINE" if grind_level == DrinkData.GrindLevel.FINE else "COARSE", roundi(get_grind_ratio() * 100.0)]

func _handle_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var angle := atan2(motion.relative.y, motion.relative.x)
		var delta_angle := angle - _last_mouse_angle
		while delta_angle > PI:
			delta_angle -= TAU
		while delta_angle < -PI:
			delta_angle += TAU
		_total_rotation += absf(delta_angle)
		_last_mouse_angle = angle

		grind_progress += absf(delta_angle) * CRANK_SPEED
		if absf(delta_angle) > 0.01:
			_last_crank_msec = Time.get_ticks_msec()
		if grind_progress >= grind_target:
			grind_progress = grind_target
			SoundManager.play("grind_complete")
			complete(1.0)

	if event.is_action_pressed("alt_use"):
		toggle_grind_level()

## True while the player has cranked in the last fraction of a second.
func is_cranking() -> bool:
	return _active and Time.get_ticks_msec() - _last_crank_msec < 150

## Total crank rotation in radians, for animating a handle.
func get_crank_rotation() -> float:
	return _total_rotation

func get_grind_ratio() -> float:
	if grind_target <= 0:
		return 1.0
	return clampf(grind_progress / grind_target, 0.0, 1.0)
