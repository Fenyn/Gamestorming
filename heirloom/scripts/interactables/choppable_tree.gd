extends StaticBody3D

enum State { STANDING, CHOPPING, FALLEN }

@export var log_scene: PackedScene = null
@export var logs_to_spawn: int = 3

var _state: State = State.STANDING
var _chop_progress: float = 0.0
const CHOPS_NEEDED := 5.0


func interact(player: Node3D) -> void:
	if _state != State.STANDING:
		return
	if player.has_held_item():
		return
	_state = State.CHOPPING
	_chop_progress += 1.0
	if _chop_progress >= CHOPS_NEEDED:
		_fell_tree()


func _fell_tree() -> void:
	_state = State.FALLEN

	if log_scene:
		for i: int in logs_to_spawn:
			var log_item: Node3D = log_scene.instantiate()
			get_parent().add_child(log_item)
			var offset := Vector3(randf_range(-1.0, 1.0), 0.5, randf_range(-1.0, 1.0))
			log_item.global_position = global_position + offset

	_hide_tree()


func _hide_tree() -> void:
	for child: Node in get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).visible = false


func reset() -> void:
	_state = State.STANDING
	_chop_progress = 0.0
	for child: Node in get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).visible = true
