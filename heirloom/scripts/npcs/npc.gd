extends CharacterBody3D

@export var npc_id: String = ""
@export var display_name: String = ""
@export var dialogue_by_level: Array[PackedStringArray] = []

@export_group("Schedule")
@export var has_schedule: bool = false
@export var open_hour: int = 7
@export var close_hour: int = 20
@export var work_position: Vector3 = Vector3.ZERO
@export var home_position: Vector3 = Vector3.ZERO

var _in_dialogue := false
var _dialogue_index: int = 0
var _current_lines: PackedStringArray = PackedStringArray()
var _is_available := true

const WALK_SPEED := 2.0


func _ready() -> void:
	if has_schedule:
		work_position = global_position
		EventBus.hour_changed.connect(_on_hour_changed)


func _physics_process(delta: float) -> void:
	if not has_schedule:
		return

	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8) as float
	if not is_on_floor():
		velocity.y -= gravity * delta

	if home_position == Vector3.ZERO:
		move_and_slide()
		return

	var target: Vector3 = work_position if _is_available else home_position
	var to_target: Vector3 = target - global_position
	to_target.y = 0.0

	if to_target.length() > 0.5:
		var dir: Vector3 = to_target.normalized()
		velocity.x = dir.x * WALK_SPEED
		velocity.z = dir.z * WALK_SPEED
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	move_and_slide()


func get_interact_hint(_player: Node3D) -> String:
	if not _is_available:
		return "%s is closed for the day" % display_name
	return "[E] Talk to %s" % display_name


func interact(player: Node3D) -> void:
	if not _is_available:
		return

	if _in_dialogue:
		_advance_dialogue()
		return

	_start_dialogue()


func _start_dialogue() -> void:
	var level: int = GameState.get_friendship(npc_id)
	level = mini(level, dialogue_by_level.size() - 1)
	if level < 0 or dialogue_by_level.is_empty():
		return

	_current_lines = dialogue_by_level[level]
	if _current_lines.is_empty():
		return

	_in_dialogue = true
	_dialogue_index = 0
	EventBus.dialogue_started.emit(npc_id)
	_show_line()


func _advance_dialogue() -> void:
	_dialogue_index += 1
	if _dialogue_index >= _current_lines.size():
		_end_dialogue()
		return
	_show_line()


func _show_line() -> void:
	var line: String = _current_lines[_dialogue_index]
	var dialogue_ui: Node = get_tree().get_first_node_in_group("dialogue_ui")
	if dialogue_ui and dialogue_ui.has_method("show_dialogue"):
		dialogue_ui.show_dialogue(display_name, line)


func _end_dialogue() -> void:
	_in_dialogue = false
	_dialogue_index = 0

	var friendship: int = GameState.get_friendship(npc_id)
	if friendship < 5:
		GameState.set_friendship(npc_id, friendship + 1)

	var dialogue_ui: Node = get_tree().get_first_node_in_group("dialogue_ui")
	if dialogue_ui and dialogue_ui.has_method("hide_dialogue"):
		dialogue_ui.hide_dialogue()

	EventBus.dialogue_ended.emit(npc_id)


func _on_hour_changed(hour: int) -> void:
	var display_hour: int = hour % 24
	_is_available = display_hour >= open_hour and display_hour < close_hour


func is_available() -> bool:
	return _is_available
