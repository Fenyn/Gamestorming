class_name SyrupMiniGame
extends BaseMiniGame

const FULL_PUMP_DURATION := 0.8
const MIN_PUMP_DURATION := 0.15
## A dosing pump's stroke.
const PUMP_PUSH_DISTANCE := 0.025

var target_pumps := 3.0
var current_pumps := 0.0
var _holding := false
var _hold_time := 0.0

## The station's pump head, pushed down while the button is held.
var _pump_stem: Node3D = null
var _pump_rest_y := 0.0

func _ready() -> void:
	super._ready()
	station_name = "syrup"

func _on_start() -> void:
	_holding = false
	_hold_time = 0.0

func get_controls_hint() -> String:
	return hint([["Hold click", "Pump"], ["E", "Done"]])

func get_assist_readout() -> String:
	var in_stroke := minf(_hold_time / FULL_PUMP_DURATION, 1.0) if _holding else 0.0
	return "Pumps  %.1f / %d" % [current_pumps + in_stroke, int(target_pumps)]

## True while syrup is coming out of the spout.
func is_dispensing() -> bool:
	return is_playing() and _holding and _hold_time < FULL_PUMP_DURATION

## Pumps so far including the stroke in progress.
func get_dispensed() -> float:
	return current_pumps + (minf(_hold_time / FULL_PUMP_DURATION, 1.0) if _holding else 0.0)

func _on_stop() -> void:
	_holding = false
	_hold_time = 0.0
	if _pump_stem:
		_pump_stem.position.y = _pump_rest_y
	if target_pumps > 0.0:
		var diff := absf(current_pumps - target_pumps)
		_quality = clampf(1.0 - diff / target_pumps, 0.0, 1.0)
	else:
		_quality = 1.0
	mini_game_completed.emit(_quality)

func _handle_input(event: InputEvent) -> void:
	if event.is_action("use"):
		if event.is_pressed():
			_holding = true
			_hold_time = 0.0
		elif _holding:
			_register_pump()
			_holding = false
			_hold_time = 0.0

func _register_pump() -> void:
	if _hold_time < MIN_PUMP_DURATION:
		return
	var pump_amount := minf(_hold_time / FULL_PUMP_DURATION, 1.0)
	current_pumps += pump_amount
	SoundManager.play("syrup_pump")

func _update_mini_game(delta: float) -> void:
	if _pump_stem == null:
		if _holding:
			_hold_time += delta
		return
	if _holding:
		_hold_time += delta
		var ratio := clampf(_hold_time / FULL_PUMP_DURATION, 0.0, 1.0)
		_pump_stem.position.y = _pump_rest_y - (PUMP_PUSH_DISTANCE * ratio)
	else:
		_pump_stem.position.y = lerpf(_pump_stem.position.y, _pump_rest_y, 0.25)

func set_target(pumps: float) -> void:
	target_pumps = pumps

func set_current(pumps: float) -> void:
	current_pumps = pumps

func set_pump(head: Node3D) -> void:
	_pump_stem = head
	_pump_rest_y = head.position.y
