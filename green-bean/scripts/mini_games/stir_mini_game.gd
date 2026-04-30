class_name StirMiniGame
extends BaseMiniGame

const TARGET_ROTATIONS := 3.0
const ROTATION_THRESHOLD := TAU

var _total_rotation := 0.0
var _last_angle := 0.0
var _accumulated_angle := 0.0
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
	add_child(_status_label)

func _on_start() -> void:
	_total_rotation = 0.0
	_last_angle = 0.0
	_accumulated_angle = 0.0
	_rotations_done = 0.0
	if _status_label:
		_status_label.text = "Move mouse in circles to stir"

func _handle_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var angle := atan2(event.relative.y, event.relative.x)
		var delta := angle - _last_angle
		while delta > PI:
			delta -= TAU
		while delta < -PI:
			delta += TAU
		_accumulated_angle += delta
		_last_angle = angle
		_total_rotation += absf(delta)

		_rotations_done = _total_rotation / TAU

		if _status_label:
			_status_label.text = "Stir: %.1f / %.0f" % [_rotations_done, TARGET_ROTATIONS]

		if _rotations_done >= TARGET_ROTATIONS:
			var consistency := minf(_rotations_done / TARGET_ROTATIONS, 1.0)
			complete(consistency)

func _update_mini_game(_delta: float) -> void:
	pass
