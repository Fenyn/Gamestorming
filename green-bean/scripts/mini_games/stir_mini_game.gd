class_name StirMiniGame
extends BaseMiniGame

## Stir the shot press slurry with circular mouse motions. The paddle is a real
## model that dips into the press and follows the stir; the station turns
## get_progress() into the floating crust breaking up.
## The node's origin is the liquid surface's centre (the station places it).

const TARGET_ROTATIONS := 5.0
const MIN_MOTION := 3.0
const ANGLE_SCALE := 0.5
const PADDLE_SCENE := preload("res://scenes/props/stir_paddle.tscn")
## Blade path radius inside the chamber, how deep the blade bottom sits below
## the surface, and how far the paddle leans out at the top.
const PADDLE_RADIUS := 0.012
const PADDLE_DIP := 0.04
const PADDLE_LEAN_DEG := 12.0

var _total_angle := 0.0
var _prev_angle := 0.0
var _has_prev := false
var _rotations_done := 0.0
var _paddle_angle := 0.0
var _paddle: Node3D = null

func _ready() -> void:
	super._ready()
	station_name = "stir"
	_paddle = PADDLE_SCENE.instantiate()
	_paddle.name = "Paddle"
	add_child(_paddle)
	_update_paddle()

func _on_start() -> void:
	_total_angle = 0.0
	_prev_angle = 0.0
	_has_prev = false
	_rotations_done = 0.0
	_paddle_angle = 0.0
	_update_paddle()
	SoundManager.play_loop("stir_loop")

func _on_stop() -> void:
	SoundManager.stop_loop("stir_loop")

func get_controls_hint() -> String:
	return hint([["Circle mouse", "Stir"], ["E", "Leave"]])

func get_assist_readout() -> String:
	return "Stirred  %d%%" % roundi(get_progress() * 100.0)

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

	if _rotations_done >= TARGET_ROTATIONS:
		SoundManager.stop_loop("stir_loop")
		complete(1.0, 0.4)

## 0 = just poured, 1 = fully stirred.
func get_progress() -> float:
	return clampf(_rotations_done / TARGET_ROTATIONS, 0.0, 1.0)

## Paddle angle round the chamber, for swirling the crust with it.
func get_swirl() -> float:
	return _paddle_angle

## Blade circles the chamber, leaning outward so the grip swings wider.
func _update_paddle() -> void:
	if not _paddle:
		return
	var dir := Vector3(cos(_paddle_angle), 0, sin(_paddle_angle))
	_paddle.position = dir * PADDLE_RADIUS + Vector3(0, -PADDLE_DIP, 0)
	# Blade broadside to the motion, top tipped away from the centre.
	var face := Basis(Vector3.UP, -_paddle_angle)
	var tilt := Basis(dir.cross(Vector3.UP).normalized(), deg_to_rad(-PADDLE_LEAN_DEG))
	_paddle.basis = tilt * face
