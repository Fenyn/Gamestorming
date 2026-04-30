class_name StirMiniGame
extends BaseMiniGame

const TARGET_ROTATIONS := 5.0
const MIN_MOTION := 3.0
const ANGLE_SCALE := 0.5

var _total_angle := 0.0
var _prev_angle := 0.0
var _has_prev := false
var _rotations_done := 0.0
var _paddle_angle := 0.0

var _status_label: Label3D = null
var _paddle: Node3D = null
const PADDLE_RADIUS := 0.025

func _ready() -> void:
	super._ready()
	station_name = "stir"

	_status_label = Label3D.new()
	_status_label.text = ""
	_status_label.font_size = 14
	_status_label.position = Vector3(0, 0.20, 0.18)
	_status_label.pixel_size = 0.001
	_status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_status_label)

	_paddle = Node3D.new()
	_paddle.position = Vector3(0, 0, 0)
	add_child(_paddle)

	var paddle_mat := StandardMaterial3D.new()
	paddle_mat.albedo_color = Color(0.2, 0.2, 0.22)

	# Wide flat head on top (the grip)
	var head := CSGBox3D.new()
	head.size = Vector3(0.028, 0.008, 0.004)
	head.position = Vector3(0, 0.355, 0)
	head.material = paddle_mat
	_paddle.add_child(head)

	# Thin flat handle going down into the press
	var handle := CSGBox3D.new()
	handle.size = Vector3(0.005, 0.04, 0.003)
	handle.position = Vector3(0, 0.33, 0)
	handle.material = paddle_mat
	_paddle.add_child(handle)

func _on_start() -> void:
	_total_angle = 0.0
	_prev_angle = 0.0
	_has_prev = false
	_rotations_done = 0.0
	_paddle_angle = 0.0
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
		_total_angle += absf(delta) * ANGLE_SCALE
		_rotations_done = _total_angle / TAU
		_paddle_angle += delta

	_prev_angle = angle
	_has_prev = true

	_update_paddle()

	if _status_label:
		_status_label.text = "Stir: %.1f / %.0f" % [_rotations_done, TARGET_ROTATIONS]

	if _rotations_done >= TARGET_ROTATIONS:
		complete(1.0)

func _update_paddle() -> void:
	if not _paddle:
		return
	var px := cos(_paddle_angle) * PADDLE_RADIUS
	var pz := sin(_paddle_angle) * PADDLE_RADIUS
	_paddle.position = Vector3(px, 0, pz)

func _update_mini_game(_delta: float) -> void:
	pass
