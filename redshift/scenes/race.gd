extends Node3D

enum State { COUNTDOWN, RACING, FINISHED }

const COUNTDOWN_DURATION: int = 3
const BEST_TIMES_PATH: String = "user://best_times.dat"

@export var track_data: TrackDefinition

@onready var _track_builder: TrackBuilder = %TrackBuilder
@onready var _ship: Ship = %Ship
@onready var _ghost_player: GhostPlayer = %GhostPlayer
@onready var _ghost_recorder: GhostRecorder = %GhostRecorder
@onready var _chase_viewport: SubViewport = %ChaseCamViewport

var _state: State = State.COUNTDOWN
var _race_time: float = 0.0
var _best_time: float = INF
var _countdown_timer: float = 0.0
var _countdown_remaining: int = COUNTDOWN_DURATION
var _next_checkpoint: int = 0
var _total_checkpoints: int = 0
var _racing_line_visible: bool = true


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_track_builder.track = track_data
	_track_builder.build(_ship)
	_track_builder.checkpoint_reached.connect(_on_checkpoint_reached)
	_total_checkpoints = _track_builder.get_checkpoint_count()

	_best_time = _load_best_time(track_data.track_name)
	var hud_node: CanvasLayer = $HUD
	if hud_node.has_method(&"set_best_time"):
		hud_node.set_best_time(_best_time)

	_ghost_player.load_ghost(track_data.track_name)

	var chase_cam: ChaseCam = _chase_viewport.get_node("ChaseCam") as ChaseCam
	chase_cam.target = _ship

	var hud: CanvasLayer = $HUD
	if hud.has_method(&"set_pip_texture"):
		hud.set_pip_texture(_chase_viewport.get_texture())

	_start_countdown()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	match _state:
		State.COUNTDOWN:
			_process_countdown(delta)
		State.RACING:
			_race_time += delta
			EventBus.race_time_updated.emit(_race_time)
		State.FINISHED:
			pass

	if InputManager.is_action_just_pressed(&"restart_race"):
		_restart()

	if InputManager.is_action_just_pressed(&"toggle_line"):
		_racing_line_visible = not _racing_line_visible
		_track_builder.set_racing_line_visible(_racing_line_visible)
		EventBus.racing_line_toggled.emit(_racing_line_visible)


func _process_countdown(delta: float) -> void:
	_countdown_timer += delta
	var new_remaining: int = COUNTDOWN_DURATION - int(_countdown_timer)
	if new_remaining != _countdown_remaining:
		_countdown_remaining = new_remaining
		if _countdown_remaining > 0:
			EventBus.race_countdown_tick.emit(_countdown_remaining)
		else:
			_state = State.RACING
			_ghost_recorder.start(_ship)
			_ghost_player.start()
			EventBus.race_started.emit()


func _on_checkpoint_reached(index: int) -> void:
	if _state != State.RACING:
		return
	if index != _next_checkpoint:
		return

	_next_checkpoint += 1
	EventBus.checkpoint_hit.emit(index, _total_checkpoints, _race_time)
	_track_builder.set_active_checkpoint(_next_checkpoint)

	if _next_checkpoint >= _total_checkpoints:
		_finish_race()


func _finish_race() -> void:
	_state = State.FINISHED
	_ghost_recorder.stop()

	var is_new_best: bool = _race_time < _best_time
	if is_new_best:
		_best_time = _race_time
		_save_best_time(track_data.track_name, _best_time)
		_ghost_recorder.save_ghost(track_data.track_name)
		_ghost_player.set_snapshots(_ghost_recorder.get_snapshots())

	_ghost_player.stop()
	EventBus.race_finished.emit(_race_time, is_new_best)


func _start_countdown() -> void:
	_state = State.COUNTDOWN
	_countdown_timer = 0.0
	_countdown_remaining = COUNTDOWN_DURATION
	_next_checkpoint = 0
	_race_time = 0.0
	_track_builder.set_active_checkpoint(0)
	_ghost_player.reset()
	EventBus.race_countdown_tick.emit(COUNTDOWN_DURATION)


func _restart() -> void:
	_ship.linear_velocity = Vector3.ZERO
	_ship.angular_velocity = Vector3.ZERO
	_ship.global_transform = track_data.start_transform
	_ghost_recorder.stop()
	_track_builder.reset()
	_start_countdown()


func _load_best_time(track_name: String) -> float:
	var times: Dictionary = _load_all_times()
	if times.has(track_name):
		return times[track_name] as float
	return INF


func _save_best_time(track_name: String, time: float) -> void:
	var times: Dictionary = _load_all_times()
	times[track_name] = time

	var file: FileAccess = FileAccess.open(BEST_TIMES_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(times))
	file.close()


func _load_all_times() -> Dictionary:
	if not FileAccess.file_exists(BEST_TIMES_PATH):
		return {}
	var file: FileAccess = FileAccess.open(BEST_TIMES_PATH, FileAccess.READ)
	if file == null:
		return {}
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}
