class_name ScreenManager
extends Node

signal screen_changed(old_key: String, new_key: String)

@export var screen_container: Control = null
@export var fade_node: ScreenFade = null

var _screens: Dictionary = {}
var _current_key: String = ""
var _current_screen: Node = null
var _transitioning: bool = false


func register_screen(key: String, scene_path: String) -> void:
	_screens[key] = scene_path


func register_screens(screens: Dictionary) -> void:
	for key: String in screens:
		_screens[key] = screens[key]


func transition_to(key: String, fade_duration: float = 0.3) -> void:
	if _transitioning:
		return
	if key not in _screens:
		push_warning("ScreenManager: screen '%s' not registered" % key)
		return
	_transitioning = true
	var old_key: String = _current_key

	if fade_node and _current_screen:
		await fade_node.fade_to_black(fade_duration)

	_unload_current()
	_load_screen(key)

	if fade_node:
		await fade_node.fade_from_black(fade_duration)

	_transitioning = false
	screen_changed.emit(old_key, key)


func load_initial(key: String) -> void:
	if key not in _screens:
		push_warning("ScreenManager: screen '%s' not registered" % key)
		return
	_load_screen(key)


func get_current_screen_key() -> String:
	return _current_key


func get_current_screen() -> Node:
	return _current_screen


func is_transitioning() -> bool:
	return _transitioning


func _load_screen(key: String) -> void:
	var path: String = _screens[key] as String
	var scene: PackedScene = load(path) as PackedScene
	if not scene:
		push_warning("ScreenManager: could not load scene at '%s'" % path)
		return
	_current_screen = scene.instantiate()
	_current_key = key
	if screen_container:
		screen_container.add_child(_current_screen)
	else:
		add_child(_current_screen)


func _unload_current() -> void:
	if _current_screen:
		_current_screen.queue_free()
		_current_screen = null
	_current_key = ""
