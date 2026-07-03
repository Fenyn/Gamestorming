class_name DialoguePanel
extends Control

signal dialogue_finished

var _sequence: Array[Dictionary] = []
var _current_index: int = 0
var _waiting_for_choice: bool = false

@onready var _speaker_label: Label = %SpeakerLabel
@onready var _text_label: RichTextLabel = %TextLabel
@onready var _continue_button: Button = %ContinueButton
@onready var _choice_container: VBoxContainer = %ChoiceContainer


func _ready() -> void:
	visible = false
	_continue_button.pressed.connect(_advance)


func show_single(speaker: String, text: String) -> void:
	_sequence = [{"speaker": speaker, "text": text}]
	_current_index = 0
	_display_current()


func show_sequence(sequence: Array[Dictionary]) -> void:
	if sequence.is_empty():
		dialogue_finished.emit()
		return
	_sequence = sequence
	_current_index = 0
	_display_current()


func _display_current() -> void:
	if _current_index >= _sequence.size():
		dialogue_finished.emit()
		return
	var entry: Dictionary = _sequence[_current_index]
	_speaker_label.text = entry.get("speaker", "")
	_text_label.text = entry.get("text", "")

	for child: Node in _choice_container.get_children():
		child.queue_free()

	var choices: Array = entry.get("choices", [])
	if choices.size() > 0:
		_continue_button.visible = false
		_waiting_for_choice = true
		for i: int in range(choices.size()):
			var choice: Dictionary = choices[i]
			var btn: Button = Button.new()
			btn.text = choice.get("label", "...")
			btn.pressed.connect(_on_choice_selected.bind(i))
			_choice_container.add_child(btn)
	else:
		_continue_button.visible = true
		_waiting_for_choice = false


func _advance() -> void:
	if _waiting_for_choice:
		return
	_current_index += 1
	if _current_index >= _sequence.size():
		dialogue_finished.emit()
	else:
		_display_current()


func _on_choice_selected(index: int) -> void:
	var entry: Dictionary = _sequence[_current_index]
	var choices: Array = entry.get("choices", [])
	if index >= 0 and index < choices.size():
		var choice: Dictionary = choices[index]
		var points: int = choice.get("points", 0) as int
		var crew_id: String = entry.get("crew_id", entry.get("speaker", ""))
		if points != 0 and crew_id != "":
			CrewManager.add_friendship(crew_id, points)
	_waiting_for_choice = false
	_advance()


func on_opened() -> void:
	pass


func on_closed() -> void:
	_sequence = []
	_current_index = 0
	_waiting_for_choice = false
	for child: Node in _choice_container.get_children():
		child.queue_free()
