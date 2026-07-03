extends Node3D


func _ready() -> void:
	var training_room_scene: PackedScene = load("res://scenes/arena/training_room.tscn") as PackedScene
	if training_room_scene:
		var room: Node = training_room_scene.instantiate()
		add_child(room)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"quit"):
		get_tree().quit()
	elif event.is_action_pressed(&"reset_round"):
		EventBus.round_reset.emit()
