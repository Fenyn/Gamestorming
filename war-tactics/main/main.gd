class_name Main
extends Control

const SCENES: Dictionary = {
	"title": preload("res://title/title_screen.tscn"),
	"battle": preload("res://battle/battle.tscn"),
}

const FADE_DURATION: float = 0.25

var _transitioning: bool = false

@onready var _current_screen: Control = %CurrentScreen
@onready var _fade_rect: ColorRect = %FadeRect


func _ready() -> void:
	Events.screen_transition_requested.connect(_on_transition_requested)
	_fade_rect.modulate.a = 0.0
	_load_screen("title")


func _on_transition_requested(target: String) -> void:
	if _transitioning:
		return
	if not SCENES.has(target):
		push_warning("Main: unknown screen '%s'" % target)
		return
	_transition_to(target)


func _transition_to(target: String) -> void:
	_transitioning = true
	var tween: Tween = create_tween()
	tween.tween_property(_fade_rect, "modulate:a", 1.0, FADE_DURATION)
	tween.tween_callback(_load_screen.bind(target))
	tween.tween_property(_fade_rect, "modulate:a", 0.0, FADE_DURATION)
	tween.tween_callback(func() -> void: _transitioning = false)


func _load_screen(screen_key: String) -> void:
	for child: Node in _current_screen.get_children():
		child.queue_free()

	var scene: PackedScene = SCENES[screen_key] as PackedScene
	var instance: Node = scene.instantiate()
	_current_screen.add_child(instance)
