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
var _searched := false


func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	if not _searched:
		_find_lighting()
		_searched = true

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


func _find_lighting() -> void:
	if not _sun:
		var suns: Array[Node] = get_tree().get_nodes_in_group("sun")
		if not suns.is_empty():
			_sun = suns[0] as DirectionalLight3D
		else:
			for node: Node in get_tree().root.get_children():
				var found: DirectionalLight3D = _find_child_of_type(node, "DirectionalLight3D") as DirectionalLight3D
				if found:
					_sun = found
					break

	if not _env:
		for node: Node in get_tree().root.get_children():
			var found: WorldEnvironment = _find_child_of_type(node, "WorldEnvironment") as WorldEnvironment
			if found:
				_env = found
				break


func _find_child_of_type(node: Node, type_name: String) -> Node:
	if node.get_class() == type_name:
		return node
	for child: Node in node.get_children():
		if child.get_class() == type_name:
			return child
	return null


func _update_lighting() -> void:
	if not _sun:
		return

	var time_frac: float = float(current_hour) + current_minute / 60.0
	var sun_angle: float = remap(time_frac, 6.0, 20.0, -80.0, 80.0)
	sun_angle = clampf(sun_angle, -80.0, 80.0)
	_sun.rotation_degrees.x = -sun_angle

	# Sun color: warm at dawn/dusk, neutral midday
	var is_night: bool = current_hour >= 21 or current_hour < 5
	if is_night:
		_sun.light_energy = 0.05
		_sun.light_color = Color(0.3, 0.35, 0.5)
	elif current_hour >= 19:
		var t: float = (time_frac - 19.0) / 2.0
		_sun.light_energy = lerpf(0.9, 0.05, t)
		_sun.light_color = Color(1.0, 0.7, 0.4).lerp(Color(0.3, 0.35, 0.5), t)
	elif current_hour <= 7:
		var t: float = (time_frac - 5.0) / 2.0
		_sun.light_energy = lerpf(0.05, 0.9, t)
		_sun.light_color = Color(0.3, 0.35, 0.5).lerp(Color(1.0, 0.75, 0.5), t)
	elif current_hour <= 9:
		var t: float = (time_frac - 7.0) / 2.0
		_sun.light_energy = lerpf(0.9, 1.0, t)
		_sun.light_color = Color(1.0, 0.75, 0.5).lerp(Color(1.0, 0.95, 0.9), t)
	elif current_hour >= 17:
		var t: float = (time_frac - 17.0) / 2.0
		_sun.light_energy = lerpf(1.0, 0.9, t)
		_sun.light_color = Color(1.0, 0.95, 0.9).lerp(Color(1.0, 0.7, 0.4), t)
	else:
		_sun.light_energy = 1.0
		_sun.light_color = Color(1.0, 0.95, 0.9)
