class_name BaseMiniGame
extends Node3D

signal mini_game_completed(quality: float)

@export var station_name := ""
@export var camera_point_path: NodePath

var _active := false
var _player: Player = null
var _camera_point: Marker3D = null
var _quality := 1.0

func _ready() -> void:
	if camera_point_path:
		_camera_point = get_node_or_null(camera_point_path)
	if not _camera_point:
		_camera_point = _find_camera_point()

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
	_player = player_ref
	_quality = 1.0
	if _camera_point:
		_player.enter_mini_game(_camera_point.global_transform)
	EventBus.mini_game_started.emit(station_name)
	_on_start()

func stop() -> void:
	if not _active:
		return
	_active = false
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

func is_active() -> bool:
	return _active

func _input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed("interact"):
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
