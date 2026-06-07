extends StaticBody3D


func get_interact_hint(_player: Node3D) -> String:
	if not GameState.stove_fixed:
		return "[E] Broken Stove"
	return "[E] Kitchen (coming soon)"


func interact(_player: Node3D) -> void:
	pass
