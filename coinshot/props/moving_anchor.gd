class_name MovingAnchor
extends AnimatableBody3D

@export var end_offset: Vector3 = Vector3(0, 5, 0)
@export var travel_time: float = 3.0
@export var mass_kg: float = 300.0

var _start_pos: Vector3
var _t: float = 0.0
var _direction: float = 1.0

func _ready() -> void:
	_start_pos = global_position
	var anchor := MetalAnchor.new()
	anchor.mass_kg = mass_kg
	anchor.is_anchored = true
	add_child(anchor)

func _physics_process(delta: float) -> void:
	_t += (delta / travel_time) * _direction
	if _t >= 1.0:
		_t = 1.0
		_direction = -1.0
	elif _t <= 0.0:
		_t = 0.0
		_direction = 1.0
	global_position = _start_pos.lerp(_start_pos + end_offset, _t)
