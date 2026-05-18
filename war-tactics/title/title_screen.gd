class_name TitleScreen
extends Control

@onready var _new_game_button: Button = %NewGameButton


func _ready() -> void:
	_new_game_button.pressed.connect(_on_new_game_pressed)


func _on_new_game_pressed() -> void:
	RunState.reset()
	Events.screen_transition_requested.emit("battle")
