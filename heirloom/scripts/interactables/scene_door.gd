extends Area3D

@export var target_scene: String = ""
@export var spawn_marker_name: String = "SpawnPoint"

var _transitioning := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if _transitioning:
		return
	if not body is CharacterBody3D:
		return
	if target_scene.is_empty():
		return

	_transitioning = true
	EventBus.scene_transition_requested.emit(target_scene)
