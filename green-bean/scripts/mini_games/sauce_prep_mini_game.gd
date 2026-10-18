class_name SaucePrepMiniGame
extends BaseMiniGame

enum PrepMode { STIR_MIX, SLEEVE_FILL }

const MIX_TARGET := 8.0
const MIN_MOTION := 3.0
const ANGLE_SCALE := 0.5
const FILL_RATE := 0.35

var prep_mode := PrepMode.STIR_MIX
var _mix_progress := 0.0
var _fill_progress := 0.0
var _prev_angle := 0.0
var _has_prev := false
var _holding := false


func _ready() -> void:
	super._ready()
	station_name = "sauce_prep"

func _on_start() -> void:
	_mix_progress = 0.0
	_fill_progress = 0.0
	_prev_angle = 0.0
	_has_prev = false
	_holding = false
	SoundManager.play_loop("sauce_prep_loop")

func _on_stop() -> void:
	_holding = false
	SoundManager.stop_loop("sauce_prep_loop")

func get_controls_hint() -> String:
	if prep_mode == PrepMode.STIR_MIX:
		return hint([["Circle mouse", "Mix"], ["E", "Leave"]])
	return hint([["Hold click", "Squeeze the pouch"], ["E", "Leave"]])

func get_assist_readout() -> String:
	return ("Mixed  %d%%" if prep_mode == PrepMode.STIR_MIX else "Filled  %d%%") % roundi(progress() * 100.0)

func is_squeezing() -> bool:
	return is_playing() and prep_mode == PrepMode.SLEEVE_FILL and _holding

func _handle_input(event: InputEvent) -> void:
	match prep_mode:
		PrepMode.STIR_MIX:
			_handle_stir_input(event)
		PrepMode.SLEEVE_FILL:
			_handle_fill_input(event)

func _handle_stir_input(event: InputEvent) -> void:
	if not event is InputEventMouseMotion:
		return
	var motion := event as InputEventMouseMotion
	if motion.relative.length() < MIN_MOTION:
		return
	var angle := atan2(motion.relative.y, motion.relative.x)
	if _has_prev:
		var delta := angle - _prev_angle
		while delta > PI: delta -= TAU
		while delta < -PI: delta += TAU
		_mix_progress += absf(delta) * ANGLE_SCALE / TAU
	_prev_angle = angle
	_has_prev = true

func _handle_fill_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_holding = event.pressed

func _update_mini_game(delta: float) -> void:
	match prep_mode:
		PrepMode.STIR_MIX:
			_update_stir(delta)
		PrepMode.SLEEVE_FILL:
			_update_fill(delta)

func _update_stir(_delta: float) -> void:
	if progress() >= 1.0:
		SoundManager.play("sauce_batch_done")
		complete(1.0, 0.4)

func _update_fill(delta: float) -> void:
	if _holding:
		_fill_progress += FILL_RATE * delta
	if progress() >= 1.0:
		SoundManager.play("sauce_batch_done")
		complete(1.0, 0.4)

## 0..1 through the current prep.
func progress() -> float:
	if prep_mode == PrepMode.STIR_MIX:
		return clampf(_mix_progress / MIX_TARGET, 0.0, 1.0)
	return clampf(_fill_progress, 0.0, 1.0)
