extends Node

const SECONDS_PER_GAME_HOUR := 60.0
const DAY_START_HOUR := 6
const DAY_END_HOUR := 26
const DAYS_PER_MONTH := 28

var current_hour: int = DAY_START_HOUR
var current_minute: float = 0.0
var paused: bool = false

var _sun: DirectionalLight3D = null
var _env: WorldEnvironment = null


func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	if paused:
		return

	current_minute += (60.0 / SECONDS_PER_GAME_HOUR) * delta
	if current_minute >= 60.0:
		current_minute -= 60.0
		current_hour += 1
		EventBus.hour_changed.emit(current_hour)

	_update_lighting()


func get_time_string() -> String:
	var display_hour: int = current_hour % 24
	var ampm := "AM"
	if display_hour >= 12:
		ampm = "PM"
	if display_hour > 12:
		display_hour -= 12
	if display_hour == 0:
		display_hour = 12
	return "%d:%02d %s" % [display_hour, int(current_minute), ampm]


func get_progress() -> float:
	var total_hours: float = float(DAY_END_HOUR - DAY_START_HOUR)
	var elapsed: float = float(current_hour - DAY_START_HOUR) + current_minute / 60.0
	return clampf(elapsed / total_hours, 0.0, 1.0)


func advance_to_morning() -> void:
	current_hour = DAY_START_HOUR
	current_minute = 0.0
	GameState.day += 1
	GameState.total_days += 1

	if GameState.day > DAYS_PER_MONTH:
		GameState.day = 1
		GameState.month += 1
		EventBus.month_ended.emit(GameState.month - 1)

	EventBus.day_started.emit(GameState.day)


func bind_sun(sun: DirectionalLight3D) -> void:
	_sun = sun


func bind_environment(env: WorldEnvironment) -> void:
	_env = env


func _update_lighting() -> void:
	if not _sun:
		return

	var time_frac: float = float(current_hour) + current_minute / 60.0
	var sun_angle: float = remap(time_frac, 6.0, 20.0, -80.0, 80.0)
	sun_angle = clampf(sun_angle, -80.0, 80.0)
	_sun.rotation_degrees.x = -sun_angle

	var is_night: bool = current_hour >= 21 or current_hour < 5
	if is_night:
		_sun.light_energy = 0.1
	elif current_hour >= 19:
		_sun.light_energy = lerpf(1.0, 0.1, (time_frac - 19.0) / 2.0)
	elif current_hour <= 7:
		_sun.light_energy = lerpf(0.1, 1.0, (time_frac - 5.0) / 2.0)
	else:
		_sun.light_energy = 1.0
