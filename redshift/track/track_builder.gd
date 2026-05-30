class_name TrackBuilder
extends Node3D

signal checkpoint_reached(index: int)

const CHECKPOINT_SCENE: PackedScene = preload("res://track/checkpoint.tscn")
const RACING_LINE_SCENE: PackedScene = preload("res://track/racing_line.tscn")

@export var track: TrackDefinition

var _checkpoints: Array[Checkpoint] = []
var _racing_line: RacingLine


func build(ship: RigidBody3D) -> void:
	if track == null:
		return

	_build_checkpoints()
	_build_racing_line(ship)


func _build_checkpoints() -> void:
	var count: int = track.checkpoints.size()
	for i: int in range(count):
		var cp: Checkpoint = CHECKPOINT_SCENE.instantiate() as Checkpoint
		cp.index = i
		cp.position = track.checkpoints[i]

		var approach_dir: Vector3
		if i == 0:
			approach_dir = (track.checkpoints[i] - track.start_transform.origin).normalized()
		else:
			approach_dir = (track.checkpoints[i] - track.checkpoints[i - 1]).normalized()

		if approach_dir.length() > 0.01:
			var up: Vector3 = Vector3.UP
			if absf(approach_dir.dot(up)) > 0.95:
				up = Vector3.RIGHT
			cp.basis = Basis.looking_at(approach_dir, up)

		cp.checkpoint_reached.connect(_on_checkpoint_reached)
		add_child(cp)
		_checkpoints.append(cp)


func _build_racing_line(ship: RigidBody3D) -> void:
	if track.racing_line_points.is_empty():
		return

	_racing_line = RACING_LINE_SCENE.instantiate() as RacingLine
	_racing_line.points = track.racing_line_points
	_racing_line.speeds = track.racing_line_speeds
	_racing_line.max_speed = track.racing_line_speeds.max() if not track.racing_line_speeds.is_empty() else 120.0
	_racing_line.ship = ship
	add_child(_racing_line)
	_racing_line.build_ribbon()


func set_active_checkpoint(index: int) -> void:
	for i: int in range(_checkpoints.size()):
		if i < index:
			_checkpoints[i].set_passed()
		elif i == index:
			_checkpoints[i].set_active()
		else:
			_checkpoints[i].set_inactive()


func get_checkpoint_count() -> int:
	return _checkpoints.size()


func reset() -> void:
	set_active_checkpoint(0)
	if _racing_line:
		_racing_line.reset()


func set_racing_line_visible(visible: bool) -> void:
	if _racing_line:
		_racing_line.visible = visible


func _on_checkpoint_reached(index: int) -> void:
	checkpoint_reached.emit(index)
