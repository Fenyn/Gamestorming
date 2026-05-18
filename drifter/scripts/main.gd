class_name Main
extends Control

const SCENES: Dictionary = {
	"camp": "res://scenes/camp/camp_screen.tscn",
	"combat": "res://scenes/combat/combat_screen.tscn",
	"map": "res://scenes/expedition/expedition_map.tscn",
	"salvage": "res://scenes/salvage/salvage_screen.tscn",
	"trader": "res://scenes/salvage/trader_screen.tscn",
	"loadout": "res://scenes/expedition/loadout_screen.tscn",
}

@onready var _screen_container: Control = %CurrentScreen
@onready var _fade_rect: ColorRect = %FadeRect

var _current_screen: Control
var _transitioning: bool = false


func _ready() -> void:
	theme = ThemeBuilder.build()
	_fade_rect.color = Color.BLACK
	_fade_rect.modulate.a = 0.0
	EventBus.screen_transition_requested.connect(_on_transition_requested)
	_load_screen("camp")


func _on_transition_requested(target: String) -> void:
	if _transitioning:
		return
	_transition_to(target)


func _transition_to(target: String) -> void:
	_transitioning = true
	var tween: Tween = create_tween()
	tween.tween_property(_fade_rect, "modulate:a", 1.0, 0.25)
	tween.tween_callback(_load_screen.bind(target))
	tween.tween_property(_fade_rect, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func() -> void: _transitioning = false)


func _load_screen(screen_key: String) -> void:
	if _current_screen:
		_current_screen.queue_free()
		_current_screen = null

	if screen_key not in SCENES:
		return

	var scene: PackedScene = load(SCENES[screen_key]) as PackedScene
	if not scene:
		return

	_current_screen = scene.instantiate() as Control
	_screen_container.add_child(_current_screen)
