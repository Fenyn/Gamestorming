class_name BaseMinigame
extends Control

signal resolved(hit: bool)

const TIMEOUT_DURATION: float = 3.0
const RESULT_HOLD: float = 0.4

var _active: bool = false
var _start_frame: int = 0

@onready var _result_label: Label = %ResultLabel


func start() -> void:
	_active = true
	_start_frame = Engine.get_process_frames()
	visible = true
	set_process(true)
	if _result_label:
		_result_label.visible = false
	_on_start()
	_start_timeout()


func _on_start() -> void:
	pass


func _input(event: InputEvent) -> void:
	if not _active:
		return
	if Engine.get_process_frames() == _start_frame:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			get_viewport().set_input_as_handled()
			var hit: bool = _evaluate_hit()
			_finish(hit)


func _evaluate_hit() -> bool:
	return false


func _finish(hit: bool) -> void:
	if not _active:
		return
	_active = false
	set_process(false)
	_show_result(hit)
	var timer: SceneTreeTimer = get_tree().create_timer(RESULT_HOLD)
	await timer.timeout
	visible = false
	resolved.emit(hit)


func _show_result(hit: bool) -> void:
	if _result_label:
		_result_label.text = "HIT!" if hit else "MISS"
		_result_label.modulate = Color.GREEN if hit else Color.RED
		_result_label.visible = true


func _start_timeout() -> void:
	var timer: SceneTreeTimer = get_tree().create_timer(TIMEOUT_DURATION)
	await timer.timeout
	if _active:
		_finish(false)
