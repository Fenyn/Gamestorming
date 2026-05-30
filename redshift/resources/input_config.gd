class_name InputConfig
extends Resource

@export_group("Mouse")
@export var mouse_sensitivity: float = 0.012
@export var mouse_invert_y: bool = false

@export_group("Gamepad Look")
@export var stick_sensitivity: float = 3.0
@export var stick_deadzone: float = 0.15
@export var stick_invert_y: bool = false

@export_group("Gamepad Throttle")
@export var trigger_deadzone: float = 0.05
