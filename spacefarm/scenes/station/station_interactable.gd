class_name StationInteractable
extends StaticBody2D

signal interacted

@export var interactable_name: String = "OBJECT"
@export var interact_hint_text: String = "E/Click: Use"
@export var marker_texture: Texture2D = null


func interact(_player: Node2D) -> void:
	interacted.emit()


func get_interact_hint() -> String:
	return interact_hint_text
