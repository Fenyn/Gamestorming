class_name HPBar
extends Control

@onready var _fill: ColorRect = %Fill


func update_bar(current: int, max_val: int) -> void:
	if _fill == null:
		return
	if max_val <= 0:
		_fill.scale.x = 0.0
		return
	_fill.scale.x = float(current) / float(max_val)
