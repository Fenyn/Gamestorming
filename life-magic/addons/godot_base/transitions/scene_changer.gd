class_name SceneChanger
extends Node

signal scene_change_started(target_path: String)
signal scene_change_completed(target_path: String)

@export var fade_node: ScreenFade = null

var _transitioning: bool = false


func change_scene(target_path: String, fade_duration: float = 0.5) -> void:
	if _transitioning:
		return
	_transitioning = true
	scene_change_started.emit(target_path)

	if fade_node:
		await fade_node.fade_to_black(fade_duration)

	get_tree().change_scene_to_file(target_path)
	await get_tree().process_frame

	if fade_node:
		await fade_node.fade_from_black(fade_duration)

	_transitioning = false
	scene_change_completed.emit(target_path)


func is_transitioning() -> bool:
	return _transitioning
