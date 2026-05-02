extends Node

const TANK_DURATIONS: Array[float] = [60.0, 120.0, 180.0]

var o2_level: float = 1.0
var in_safe_zone: bool = false
var is_retired: bool = false

var _max_duration: float = 60.0


func _ready() -> void:
	_update_max_duration()


func _process(delta: float) -> void:
	if is_retired or in_safe_zone:
		if not is_retired and o2_level < 1.0:
			o2_level = minf(o2_level + delta / 3.0, 1.0)
		return

	var drain_rate: float = 1.0 / _max_duration
	o2_level -= drain_rate * delta

	if o2_level <= 0.0:
		o2_level = 0.0
		EventBus.o2_depleted.emit()
		_on_death()


func enter_safe_zone() -> void:
	if in_safe_zone:
		return
	in_safe_zone = true
	EventBus.safe_zone_entered.emit()
	GameState.autosave()


func exit_safe_zone() -> void:
	if not in_safe_zone:
		return
	in_safe_zone = false
	EventBus.safe_zone_exited.emit()


func upgrade_tank() -> void:
	if GameState.o2_tank_tier < 2:
		GameState.o2_tank_tier += 1
		_update_max_duration()


func retire_tank() -> void:
	is_retired = true
	o2_level = 1.0


func get_max_duration() -> float:
	return _max_duration


func _update_max_duration() -> void:
	var tier: int = clampi(GameState.o2_tank_tier, 0, TANK_DURATIONS.size() - 1)
	_max_duration = TANK_DURATIONS[tier]


func _on_death() -> void:
	EventBus.player_died.emit()
	GameState.load_autosave()


func reset_to_defaults() -> void:
	o2_level = 1.0
	in_safe_zone = true
	is_retired = false
	_update_max_duration()
