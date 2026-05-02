extends Node3D

@onready var _safe_zone: Area3D = $SafeZone


func _ready() -> void:
	_safe_zone.body_entered.connect(_on_safe_zone_entered)
	_safe_zone.body_exited.connect(_on_safe_zone_exited)
	EventBus.player_died.connect(_on_player_died)

	_generate_collision_for_children(self)


func _generate_collision_for_children(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var mi: MeshInstance3D = child as MeshInstance3D
			if mi.mesh != null:
				mi.create_trimesh_collision()
		if child is Node:
			_generate_collision_for_children(child)


func _on_safe_zone_entered(body: Node3D) -> void:
	if body is Player:
		O2Manager.enter_safe_zone()


func _on_safe_zone_exited(body: Node3D) -> void:
	if body is Player:
		O2Manager.exit_safe_zone()


func _on_player_died() -> void:
	get_tree().reload_current_scene()
