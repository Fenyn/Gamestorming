extends Node

const SECONDS_PER_GAME_HOUR: float = 10.0
const HOURS_PER_DAY: int = 16
const DAYS_PER_SEASON: int = 14
const DAY_START_HOUR: int = 6
const DAY_END_HOUR: int = 22

var current_hour: int = DAY_START_HOUR
var paused: bool = false

var _tick_emitter: TickEmitter = null
var _seconds_into_hour: float = 0.0


func _ready() -> void:
	_tick_emitter = TickEmitter.new()
	_tick_emitter.tick_interval = SECONDS_PER_GAME_HOUR
	_tick_emitter.auto_start = false
	add_child(_tick_emitter)
	_tick_emitter.tick_fired.connect(_on_tick)


func start_day() -> void:
	current_hour = DAY_START_HOUR
	paused = false
	_seconds_into_hour = 0.0
	_tick_emitter.reset()
	_tick_emitter.start()
	EventBus.day_started.emit(GameState.day)


func pause_time() -> void:
	paused = true
	_tick_emitter.paused = true


func resume_time() -> void:
	paused = false
	_tick_emitter.paused = false


func _process(delta: float) -> void:
	if paused or not _tick_emitter:
		return
	_seconds_into_hour += delta


func _on_tick(_tick_count: int) -> void:
	if paused:
		return
	_seconds_into_hour = 0.0
	current_hour += 1
	EventBus.hour_changed.emit(current_hour)
	if current_hour >= DAY_END_HOUR:
		_end_day()


func _end_day() -> void:
	_tick_emitter.stop()
	var ended_day: int = GameState.day
	GameState.day += 1
	GameState.total_days += 1
	EventBus.day_ended.emit(ended_day)
	if GameState.day > DAYS_PER_SEASON:
		_end_season()


func _end_season() -> void:
	paused = true
	EventBus.season_ended.emit(GameState.season)


func advance_to_next_season() -> void:
	GameState.day = 1
	GameState.season += 1
	start_day()


func get_time_string() -> String:
	var minute: int = int(_seconds_into_hour * 60.0 / SECONDS_PER_GAME_HOUR)
	return "%02d:%02d" % [current_hour, minute]


func get_day_progress() -> float:
	var hours_elapsed: float = float(current_hour - DAY_START_HOUR)
	return hours_elapsed / float(HOURS_PER_DAY)


func is_peak_sun() -> bool:
	return current_hour >= 10 and current_hour <= 14


func is_night() -> bool:
	return current_hour >= 20 or current_hour < 6
