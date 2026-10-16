class_name MovingCar
extends Node3D

## A car driving straight along a road lane, with a slight suspension bob.
## Frees itself at end_x.

var direction := 1.0
var speed := 8.0
var end_x := 34.0
var _time := 0.0

func _ready() -> void:
	_time = randf() * TAU

func _process(delta: float) -> void:
	_time += delta
	global_position.x += direction * speed * delta
	var body := get_child(0) as Node3D
	if body:
		body.position.y = sin(_time * 9.0) * 0.015
		body.rotation.z = sin(_time * 5.0) * 0.008
	if (direction > 0.0 and global_position.x > end_x) or (direction < 0.0 and global_position.x < end_x):
		queue_free()
