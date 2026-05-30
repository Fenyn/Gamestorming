class_name ChaseCam
extends Camera3D

const FOLLOW_DISTANCE: float = 6.0
const FOLLOW_HEIGHT: float = 2.0
const LERP_SPEED: float = 3.0

var target: Node3D


func _physics_process(delta: float) -> void:
	if target == null:
		return

	var target_pos: Vector3 = target.global_position
	var behind: Vector3 = target.global_basis.z.normalized() * FOLLOW_DISTANCE
	var desired: Vector3 = target_pos + behind + Vector3.UP * FOLLOW_HEIGHT

	global_position = global_position.lerp(desired, LERP_SPEED * delta)
	look_at(target_pos, Vector3.UP)
