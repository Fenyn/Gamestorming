extends Node

var _transitioning := false


func _ready() -> void:
	EventBus.scene_transition_requested.connect(_on_transition)


func _on_transition(target_scene: String) -> void:
	if _transitioning:
		return
	_transitioning = true

	var fade: Node = get_tree().get_first_node_in_group("screen_fade")
	if fade and fade.has_method("fade_to_black"):
		await fade.fade_to_black(0.5)

	get_tree().change_scene_to_file(target_scene)

	await get_tree().process_frame
	fade = get_tree().get_first_node_in_group("screen_fade")
	if fade and fade.has_method("fade_from_black"):
		await fade.fade_from_black(0.5)

	_transitioning = false
