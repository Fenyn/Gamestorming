extends Node

var plots: Array[Node3D] = []


func register_plot(plot: Node3D) -> void:
	if plot not in plots:
		plots.append(plot)


func unregister_plot(plot: Node3D) -> void:
	plots.erase(plot)


func _on_tick(_tick_number: int) -> void:
	pass


func reset_to_defaults() -> void:
	plots.clear()
