class_name EnergyBar
extends ProgressBar


func _ready() -> void:
	min_value = 0.0
	max_value = GameState.MAX_ENERGY
	value = GameState.energy
	show_percentage = false
	EventBus.energy_changed.connect(_on_energy_changed)
	_update_tint()


func _on_energy_changed(current: float, max_energy: float) -> void:
	max_value = max_energy
	value = current
	_update_tint()


func _update_tint() -> void:
	var ratio_full: float = value / max_value if max_value > 0.0 else 0.0
	modulate = Color(1.0, 0.35, 0.3, 1).lerp(Color(0.55, 1.0, 0.55, 1), ratio_full)
