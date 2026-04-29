extends Node

const SAVE_PATH := "user://save_game.json"
const CURRENT_VERSION := 3
const AUTO_SAVE_TICKS := 30
const MAX_OFFLINE_TICKS := 500

var _tick_counter: int = 0
var _last_save_timestamp: int = 0


func _ready() -> void:
	load_game()
	EventBus.tick_fired.connect(_on_tick)
	EventBus.generator_purchased.connect(func(_t, _c): save_game())


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		save_game()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


func _on_tick(_tick_number: int) -> void:
	_tick_counter += 1
	if _tick_counter >= AUTO_SAVE_TICKS:
		_tick_counter = 0
		save_game()


func save_game() -> void:
	var data := GameState.to_dict()
	data["timestamp"] = int(Time.get_unix_time_from_system())
	_last_save_timestamp = data["timestamp"]

	var json_string := JSON.stringify(data, "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_warning("SaveManager: Could not open save file for writing")
		return
	file.store_string(json_string)
	file.close()
	EventBus.save_completed.emit()


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_warning("SaveManager: Could not open save file for reading")
		return

	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result := json.parse(json_string)
	if parse_result != OK:
		push_warning("SaveManager: Failed to parse save file, starting fresh")
		return

	var data: Dictionary = json.data
	if data.is_empty():
		return

	data = _migrate(data)
	GameState.from_dict(data)
	_last_save_timestamp = data.get("timestamp", 0)

	_process_offline_progress()
	EventBus.load_completed.emit()


func _migrate(data: Dictionary) -> Dictionary:
	var version: int = data.get("save_version", 1)
	while version < CURRENT_VERSION:
		match version:
			1:
				var gens: Dictionary = data.get("generators", {})
				for key in gens:
					if gens[key].has("count") and not gens[key].has("owned"):
						gens[key]["owned"] = gens[key]["count"]
						gens[key]["produced"] = 0.0
						gens[key].erase("count")
			2:
				if not data.has("plots"):
					data["plots"] = {}
		version += 1
		data["save_version"] = version
	return data


func _process_offline_progress() -> void:
	if _last_save_timestamp <= 0:
		return

	var now := int(Time.get_unix_time_from_system())
	var elapsed := now - _last_save_timestamp
	if elapsed < 10:
		return

	var interval := GameFormulas.effective_tick_interval(
		TickEngine.BASE_INTERVAL, 1.0, 1.0
	)
	if interval <= 0.0:
		return

	var offline_ticks := int(float(elapsed) / interval)
	offline_ticks = mini(offline_ticks, MAX_OFFLINE_TICKS)

	if offline_ticks <= 0:
		return

	var mana_before := GameState.mana
	for _i in offline_ticks:
		_simulate_tick()
	var mana_gained := GameState.mana - mana_before

	if mana_gained > 0.0:
		var time_str := _format_duration(elapsed)
		var mana_str := GameFormulas.format_number(mana_gained)
		EventBus.notification.emit(
			"Welcome back! You earned %s Life Mana in %s." % [mana_str, time_str],
			"info"
		)


func _simulate_tick() -> void:
	var tier_data := GeneratorManager.tier_data
	for i in range(tier_data.size() - 1, -1, -1):
		var data := tier_data[i]
		var count := GameState.get_generator_count(data.tier)
		if count <= 0.0:
			continue
		var multiplier := GameState.get_generator_multiplier(data.tier)
		var produced := GameFormulas.generator_production(count, data.base_production, multiplier)
		if data.produces_tier == -1:
			GameState.add_mana(produced)
		else:
			GameState.add_generator_produced(data.produces_tier, produced)
	PlotManager._advance_growth()
	PlotManager._check_full_blooms()


func _format_duration(seconds: int) -> String:
	if seconds < 60:
		return "%ds" % seconds
	elif seconds < 3600:
		return "%dm %ds" % [seconds / 60, seconds % 60]
	else:
		var hours := seconds / 3600
		var mins := (seconds % 3600) / 60
		return "%dh %dm" % [hours, mins]


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
