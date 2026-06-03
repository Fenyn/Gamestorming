extends StaticBody3D

var _sleeping := false


func interact(_player: Node3D) -> void:
	if _sleeping:
		return
	_sleeping = true
	_do_sleep()


func _do_sleep() -> void:
	TimeManager.paused = true

	var fade: Node = get_tree().get_first_node_in_group("screen_fade")
	if not fade:
		fade = _find_fade()

	if fade and fade.has_method("fade_to_black"):
		await fade.fade_to_black(0.8)

	var restore: float = GameState.get_sleep_restore()
	GameState.fatigue = restore
	GameState.hunger = maxf(GameState.hunger - 0.1, 0.0)
	GameState.thirst = maxf(GameState.thirst - 0.1, 0.0)

	TimeManager.advance_to_morning()
	SaveManager.save_game()

	if fade and fade.has_method("show_day_text"):
		fade.show_day_text("Day %d" % GameState.day)

	if fade and fade.has_method("fade_from_black"):
		await fade.fade_from_black(0.8)

	TimeManager.paused = false
	_sleeping = false


func _find_fade() -> Node:
	var nodes: Array[Node] = get_tree().get_nodes_in_group("screen_fade")
	if not nodes.is_empty():
		return nodes[0]
	for node: Node in get_tree().root.get_children():
		if node.has_method("fade_to_black"):
			return node
	return null
