class_name StationInteractable3D
extends StaticBody3D

signal interacted

@export var interactable_name: String = "OBJECT"
@export var interact_hint_text: String = "E/Click: Use"


func interact(_player: Node3D) -> void:
	interacted.emit()


func get_interact_hint() -> String:
	return interact_hint_text
