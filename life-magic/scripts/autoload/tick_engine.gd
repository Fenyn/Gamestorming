extends Node

const BEAT_STRENGTH_PER_LEVEL := 0.05

var beat_count: int = 0
var upgrade_multiplier: float = 1.0


func _ready() -> void:
	_update_upgrade_multiplier()
	EventBus.heartbeat_fired.connect(_on_heartbeat)


func reset_to_defaults() -> void:
	beat_count = 0
	upgrade_multiplier = 1.0


func _on_heartbeat() -> void:
	beat_count += 1
	EventBus.tick_fired.emit(beat_count)


func _update_upgrade_multiplier() -> void:
	upgrade_multiplier = 1.0 + BEAT_STRENGTH_PER_LEVEL * GameState.tick_speed_level
