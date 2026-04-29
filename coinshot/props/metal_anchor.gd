class_name MetalAnchor
extends Node

@export var mass_kg: float = 50.0
@export var is_anchored: bool = true

func _ready() -> void:
	var p := get_parent()
	if p:
		p.add_to_group("metal")
