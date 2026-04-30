class_name StirMiniGame
extends BaseMiniGame

const TARGET_ROTATIONS := 5.0
const MIN_MOTION := 3.0

var _total_angle := 0.0
var _prev_angle := 0.0
var _has_prev := false
var _rotations_done := 0.0

var _status_label: Label3D = null

func _ready() -> void:
	super._ready()
	station_name = "stir"

	_status_label = Label3D.new()
	_status_label.text = ""
	_status_label.font_size = 12
	_status_label.position = Vector3(0, 0.35, 0.01)
	_status_label.pixel_size = 0.002
	_status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_status_label)

func _on_start() -> void:
	_total_angle = 0.0
	_prev_angle = 0.0
	_has_prev = false
	_rotations_done = 0.0
	if _status_label:
		_status_label.text = "Move mouse in circles to stir"

func _handle_input(event: InputEvent) -> void:
	if not event is InputEventMouseMotion:
		return
	var motion := event as InputEventMouseMotion
	if motion.relative.length() < MIN_MOTION:
		return

	var angle := atan2(motion.relative.y, motion.relative.x)
	if _has_prev:
		var delta := angle - _prev_angle
		while delta > PI:
			delta -= TAU
		while delta < -PI:
			delta += TAU
		_total_angle += absf(delta)
		_rotations_done = _total_angle / TAU

	_prev_angle = angle
	_has_prev = true

	if _status_label:
		_status_label.text = "Stir: %.1f / %.0f" % [_rotations_done, TARGET_ROTATIONS]

	if _rotations_done >= TARGET_ROTATIONS:
		complete(1.0)

func _update_mini_game(_delta: float) -> void:
	pass
