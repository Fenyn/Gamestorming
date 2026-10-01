class_name ConfirmModal
extends Control
## A dimmed question with two or three answers, for leaving with unsaved work, replacing a deck
## and deleting one. `ask` shows it and returns the index of the answer picked; Esc or a click on
## the dim picks the last answer, which callers make the safe one.

signal answered(index: int)

@onready var heading: Label = $Center/Panel/Column/Heading
@onready var body: Label = $Center/Panel/Column/Body
@onready var buttons: HBoxContainer = $Center/Panel/Column/Buttons
@onready var dim: ColorRect = $Dim

var _count: int = 0


func _ready() -> void:
	($Center/Panel as PanelContainer).add_theme_stylebox_override("panel", ZenithTheme.modal_panel())
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			answered.emit(_count - 1))
	visible = false


## `answers` left to right; the first is styled as the main action. A `danger` first answer reads
## in the warning colour.
func ask(title: String, text: String, answers: Array[String], danger: bool = false) -> int:
	heading.text = title
	body.text = text
	for child in buttons.get_children():
		buttons.remove_child(child)
		child.queue_free()
	_count = answers.size()
	for i in range(answers.size()):
		var button: Button = Button.new()
		button.text = answers[i]
		button.custom_minimum_size = Vector2(180, 0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if i == 0:
			button.theme_type_variation = &"AccentButton"
			if danger:
				button.add_theme_color_override("font_color", ZenithTheme.WARN)
		var index: int = i
		button.pressed.connect(func() -> void: answered.emit(index))
		buttons.add_child(button)
	visible = true
	(buttons.get_child(0) as Button).grab_focus()
	var picked: int = await answered
	visible = false
	return picked


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		answered.emit(_count - 1)
		get_viewport().set_input_as_handled()
