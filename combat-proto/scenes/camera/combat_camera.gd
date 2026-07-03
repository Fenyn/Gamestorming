class_name CombatCamera
extends Node3D

@export var shoulder_offset: Vector3 = Vector3(1.0, 2.0, 3.0)
@export var follow_speed: float = 10.0
@export var look_ahead: float = 0.6

var follow_target: Node3D = null
var lock_target: Node3D = null
var is_pvp_mode: bool = false
var pvp_target_b: Node3D = null

@onready var _camera: Camera3D = %Camera3D


func _ready() -> void:
	if _camera:
		_camera.current = true
		_camera.fov = 65.0


func setup_pve(player: Node3D, opponent: Node3D) -> void:
	follow_target = player
	lock_target = opponent
	is_pvp_mode = false
	_snap_to_target()


func setup_pvp(fighter_a: Node3D, fighter_b: Node3D) -> void:
	follow_target = fighter_a
	pvp_target_b = fighter_b
	is_pvp_mode = true


func _snap_to_target() -> void:
	if follow_target == null or _camera == null:
		return
	var cam_pos: Vector3 = _compute_camera_position()
	_camera.global_position = cam_pos
	if lock_target:
		_camera.look_at(_compute_look_target())


func _physics_process(delta: float) -> void:
	if _camera == null:
		return
	if is_pvp_mode:
		_update_pvp(delta)
	else:
		_update_pve(delta)


func _update_pve(delta: float) -> void:
	if follow_target == null:
		return

	var desired_pos: Vector3 = _compute_camera_position()
	_camera.global_position = _camera.global_position.lerp(desired_pos, follow_speed * delta)

	var look_target: Vector3 = _compute_look_target()
	_camera.look_at(look_target)


func _compute_camera_position() -> Vector3:
	var player_pos: Vector3 = follow_target.global_position

	if lock_target:
		var to_opponent: Vector3 = (lock_target.global_position - player_pos)
		to_opponent.y = 0.0
		if to_opponent.length_squared() < 0.01:
			to_opponent = Vector3.FORWARD
		to_opponent = to_opponent.normalized()

		var behind: Vector3 = -to_opponent
		var right: Vector3 = behind.cross(Vector3.UP).normalized()

		return player_pos + behind * shoulder_offset.z + right * shoulder_offset.x + Vector3.UP * shoulder_offset.y
	else:
		var basis: Basis = follow_target.global_transform.basis
		return player_pos - basis.z * shoulder_offset.z + basis.x * shoulder_offset.x + Vector3.UP * shoulder_offset.y


func _compute_look_target() -> Vector3:
	var player_pos: Vector3 = follow_target.global_position
	player_pos.y += 1.0

	if lock_target:
		var opponent_pos: Vector3 = lock_target.global_position
		opponent_pos.y += 1.0
		return player_pos.lerp(opponent_pos, look_ahead)

	return player_pos + follow_target.global_transform.basis.z * -5.0


func _update_pvp(delta: float) -> void:
	if follow_target == null or pvp_target_b == null:
		return
	var midpoint: Vector3 = (follow_target.global_position + pvp_target_b.global_position) / 2.0
	var dist: float = follow_target.global_position.distance_to(pvp_target_b.global_position)
	var zoom: float = clampf(dist * 0.8 + 4.0, 6.0, 16.0)

	var desired: Vector3 = midpoint + Vector3(0.0, zoom * 0.5, zoom)
	_camera.global_position = _camera.global_position.lerp(desired, follow_speed * delta)
	_camera.look_at(midpoint + Vector3.UP * 1.0)
