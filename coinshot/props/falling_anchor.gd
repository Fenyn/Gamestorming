class_name FallingAnchor
extends RigidBody3D

@export var mass_kg: float = 100.0
@export var fall_delay: float = 1.5

var _activated: bool = false
var _timer: float = 0.0

func _ready() -> void:
	mass = mass_kg
	add_to_group("metal")
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC

func on_allomantic_force() -> void:
	if not _activated:
		_activated = true

func _physics_process(delta: float) -> void:
	if _activated:
		_timer += delta
		if _timer >= fall_delay and freeze:
			freeze = false
