class_name BaseMiniGame
extends Node3D

signal mini_game_completed(quality: float)

@export var station_name := ""
@export var camera_point_path: NodePath

var _active := false
var _player: Player = null
var _camera_point: Marker3D = null
var _quality := 1.0
var _start_frame := -1

func _ready() -> void:
	if camera_point_path:
		_camera_point = get_node_or_null(camera_point_path)
	if not _camera_point:
		_camera_point = _find_camera_point()
	call_deferred("_set_ui_visible", false)

func _find_camera_point() -> Marker3D:
	for child in get_children():
		if child is Marker3D and child.name == "CameraPoint":
			return child
	return null

func can_start(_player_ref: Player) -> bool:
	return not _active

func start(player_ref: Player) -> void:
	if not can_start(player_ref):
		return
	_active = true
	_start_frame = Engine.get_process_frames()
	_player = player_ref
	_quality = 1.0
	if _camera_point:
		_player.enter_mini_game(_camera_point.global_transform)
	_set_ui_visible(true)
	EventBus.mini_game_started.emit(station_name)
	_on_start()

func stop() -> void:
	if not _active:
		return
	_active = false
	_set_ui_visible(false)
	if _player:
		_player.exit_mini_game()
	EventBus.mini_game_ended.emit(station_name, _quality)
	_on_stop()
	_player = null

func complete(quality: float) -> void:
	_quality = quality
	mini_game_completed.emit(quality)
	stop()

func _on_start() -> void:
	pass

func _on_stop() -> void:
	pass

func _set_ui_visible(vis: bool) -> void:
	for child in get_children():
		if child is Label3D and child != _camera_point:
			child.visible = vis
		if child is CSGBox3D:
			child.visible = vis

func is_active() -> bool:
	return _active

func _input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed("interact"):
		if Engine.get_process_frames() != _start_frame:
			stop()
		return
	_handle_input(event)

func _handle_input(_event: InputEvent) -> void:
	pass

func _process(delta: float) -> void:
	if not _active:
		return
	_update_mini_game(delta)

func _update_mini_game(_delta: float) -> void:
	pass
