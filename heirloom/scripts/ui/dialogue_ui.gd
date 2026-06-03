extends CanvasLayer

@onready var _panel: PanelContainer = $Panel
@onready var _name_label: Label = $Panel/Margin/VBox/NameLabel
@onready var _text_label: Label = $Panel/Margin/VBox/TextLabel
@onready var _continue_label: Label = $Panel/Margin/VBox/ContinueLabel


func _ready() -> void:
	add_to_group("dialogue_ui")
	_panel.visible = false


func show_dialogue(speaker_name: String, text: String) -> void:
	_name_label.text = speaker_name
	_text_label.text = text
	_continue_label.text = "[E] Continue"
	_panel.visible = true


func hide_dialogue() -> void:
	_panel.visible = false
