extends Node

var beat_count: int = 0


func _ready() -> void:
	EventBus.heartbeat_fired.connect(_on_heartbeat)


func reset_to_defaults() -> void:
	beat_count = 0


func _on_heartbeat() -> void:
	beat_count += 1
	EventBus.tick_fired.emit(beat_count)
