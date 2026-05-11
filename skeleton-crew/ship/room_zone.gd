extends Area3D

func _ready() -> void:
	add_to_group(&"room_zones")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		var player: Player = body as Player
		var room_id: String = get_parent().name
		player.current_room_id = room_id
		EventBus.player_room_changed.emit(player.get_multiplayer_authority(), room_id)


func _on_body_exited(_body: Node3D) -> void:
	pass
