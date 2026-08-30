class_name TickEmitter
extends Node

signal tick_fired(tick_count: int)

@export var tick_interval: float = 0.25
@export var auto_start: bool = true

var tick_count: int = 0
var paused: bool = false

var _accumulator: float = 0.0


func _ready() -> void:
	set_process(auto_start)


func _process(delta: float) -> void:
	if paused:
		return
	_accumulator += delta
	while _accumulator >= tick_interval:
		_accumulator -= tick_interval
		tick_count += 1
		tick_fired.emit(tick_count)


func start() -> void:
	set_process(true)


func stop() -> void:
	set_process(false)


func reset() -> void:
	tick_count = 0
	_accumulator = 0.0
