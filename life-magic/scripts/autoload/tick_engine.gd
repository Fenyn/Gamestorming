extends Node

const BASE_INTERVAL := 8.0
const TICK_SPEED_PER_LEVEL := 0.05

var tick_count: int = 0
var upgrade_multiplier: float = 1.0

var _accumulator: float = 0.0
var _last_interval: float = -1.0


func _ready() -> void:
	_update_upgrade_multiplier()


func reset_to_defaults() -> void:
	tick_count = 0
	upgrade_multiplier = 1.0
	_accumulator = 0.0
	_last_interval = -1.0


func _process(delta: float) -> void:
	var interval := get_current_interval()

	if not is_equal_approx(interval, _last_interval):
		_last_interval = interval
		EventBus.tick_speed_changed.emit(interval)

	_accumulator += delta
	while _accumulator >= interval:
		_accumulator -= interval
		tick_count += 1
		EventBus.tick_fired.emit(tick_count)


func get_current_interval() -> float:
	return GameFormulas.effective_tick_interval(
		BASE_INTERVAL,
		upgrade_multiplier,
		HeartRateManager.get_hr_factor()
	)


func get_progress() -> float:
	var interval := get_current_interval()
	if interval <= 0.0:
		return 0.0
	return clampf(_accumulator / interval, 0.0, 1.0)


func get_ticks_per_second() -> float:
	var interval := get_current_interval()
	if interval <= 0.0:
		return 0.0
	return 1.0 / interval


func _update_upgrade_multiplier() -> void:
	upgrade_multiplier = 1.0 + TICK_SPEED_PER_LEVEL * GameState.tick_speed_level


func set_tick_speed_level(level: int) -> void:
	GameState.tick_speed_level = level
	_update_upgrade_multiplier()
