class_name BaseMiniGame
extends Node3D

signal mini_game_completed(quality: float)
## After the game lets go of the camera, finished or left. A station can start
## its next game from here and the camera goes straight across.
signal stopped(player: Player)

@export var station_name := ""
@export var camera_point_path: NodePath

var _active := false
var _player: Player = null
var _camera_point: Marker3D = null
var _quality := 1.0
## True between complete(quality, linger) and the camera letting go.
var _lingering := false
## True when the player pressed a leave key, so a station does not chain
## straight into its next game.
var player_left := false
var _session := 0
## Camera field of view while playing; 0 keeps the player's.
var camera_fov := 0.0

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
	_session += 1
	_lingering = false
	player_left = false
	_player = player_ref
	_quality = 1.0
	if _camera_point:
		_player.enter_mini_game(_camera_point.global_transform, self, camera_fov)
	_set_ui_visible(true)
	EventBus.mini_game_started.emit(station_name)
	_on_start()

func stop() -> void:
	if not _active:
		return
	_active = false
	_lingering = false
	_set_ui_visible(false)
	if _player:
		_player.exit_mini_game()
	EventBus.mini_game_ended.emit(station_name, _quality)
	_on_stop()
	var player := _player
	_player = null
	stopped.emit(player)

## linger keeps the camera on the finished result for that many seconds, with
## input off, so the player sees it land before the view lets go.
func complete(quality: float, linger: float = 0.0) -> void:
	_quality = quality
	if _player:
		_player.shake(0.0025, 0.16)
	mini_game_completed.emit(quality)
	end_after(linger)

## Stops after linger seconds with input off (at once if linger is 0).
func end_after(linger: float) -> void:
	if linger <= 0.0 or not _active:
		stop()
		return
	_lingering = true
	var session := _session
	get_tree().create_timer(linger).timeout.connect(func() -> void:
		if session == _session:
			_lingering = false
			stop())

## Active and taking input (not lingering on a finished result).
func is_playing() -> bool:
	return _active and not _lingering

func _on_start() -> void:
	pass

## Controls strip text for the HUD, for the current phase.
func get_controls_hint() -> String:
	return "[E] Leave"

## Numbers for the optional assist readout; empty hides it.
func get_assist_readout() -> String:
	return ""

## Joins control pairs into one strip line: hint(["Hold click", "pour"], ...).
static func hint(pairs: Array) -> String:
	var parts: PackedStringArray = []
	for pair in pairs:
		parts.append("[%s] %s" % [pair[0], pair[1]])
	return "      ".join(parts)

func _on_stop() -> void:
	pass

func _set_ui_visible(vis: bool) -> void:
	for child in get_children():
		if child == _camera_point:
			continue
		if child is Marker3D:
			continue
		if child is Node3D:
			child.visible = vis

func is_active() -> bool:
	return _active

## Player calls this for the leave keys while this game holds the camera.
## During the linger on a finished result it cuts the linger short.
func leave() -> void:
	player_left = true
	stop()

func _input(event: InputEvent) -> void:
	if not _active or _lingering:
		return
	_handle_input(event)

func _handle_input(_event: InputEvent) -> void:
	pass

func _process(delta: float) -> void:
	if not is_playing():
		return
	_update_mini_game(delta)

func _update_mini_game(_delta: float) -> void:
	pass
