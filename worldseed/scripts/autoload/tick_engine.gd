extends Node

const TICK_INTERVAL: float = 0.25

var tick_count: int = 0
var _accumulator: float = 0.0


func _process(delta: float) -> void:
	_accumulator += delta
	while _accumulator >= TICK_INTERVAL:
		_accumulator -= TICK_INTERVAL
		tick_count += 1
		EventBus.tick_fired.emit(tick_count)


func reset_to_defaults() -> void:
	tick_count = 0
	_accumulator = 0.0
