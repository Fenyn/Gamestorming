class_name LevelScene
extends LevelBase

func _ready() -> void:
	var marker := find_child("SpawnPoint", true, false)
	if marker and marker is Marker3D:
		spawn_point = (marker as Marker3D).global_position

	for goal in find_children("GoalZone*", "Area3D", true):
		(goal as Area3D).body_entered.connect(_on_goal_entered)
