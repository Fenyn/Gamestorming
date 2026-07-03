class_name CargoPod
extends StaticBody2D

signal pod_opened


func interact(_player: Node2D) -> void:
	pod_opened.emit()


func get_interact_hint() -> String:
	return "E/Click: Open supply station"
