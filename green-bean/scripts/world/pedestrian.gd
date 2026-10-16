class_name Pedestrian
extends Node3D

## A passer-by walking straight along a sidewalk. Frees itself at end_x.

var profile: CustomerProfile = null
var direction := 1.0
var end_x := 24.0
var _visual: CharacterVisual = null
var _speed := 1.5
var _pause := 0.0
var _paused_once := false

func _ready() -> void:
	if profile == null:
		profile = CustomerProfile.generate()
	# Passers-by stroll a bit slower than customers on a mission.
	_speed = profile.walk_speed * randf_range(0.7, 0.85)
	_visual = CharacterVisual.new()
	_visual.setup(profile)
	add_child(_visual)
	rotation.y = PI * 0.5 * direction
	var roll := randf()
	if roll < 0.3:
		_visual.hold_in_hand(CharacterVisual.make_takeaway_cup())
	elif roll < 0.55 and profile.uses_phone:
		_visual.hold_in_hand(CharacterVisual.make_phone())

func _process(delta: float) -> void:
	# Now and then someone stops to look at the stand.
	if _pause > 0.0:
		_pause -= delta
		_visual.set_moving(0.0)
		# Turn to look at the stand, then turn back to keep walking.
		var look_yaw := PI if _pause > 0.4 else PI * 0.5 * direction
		rotation.y = lerp_angle(rotation.y, look_yaw, 1.0 - exp(-6.0 * delta))
		return
	# About a one-in-five chance per pass, independent of frame rate.
	if not _paused_once and absf(global_position.x) < 1.5 and randf() < 0.7 * delta:
		_paused_once = true
		_pause = randf_range(1.5, 3.0)
		return
	global_position.x += direction * _speed * delta
	_visual.set_moving(_speed)
	if (direction > 0.0 and global_position.x > end_x) or (direction < 0.0 and global_position.x < end_x):
		queue_free()
