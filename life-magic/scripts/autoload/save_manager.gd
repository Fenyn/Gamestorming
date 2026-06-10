extends Node

const SAVE_PATH: String = "user://save_game.json"
const AUTO_SAVE_BEATS: int = 30
const BASE_OFFLINE_BEATS: int = 600

var _handler: SaveFileHandler
var _beat_counter: int = 0
var _last_save_timestamp: int = 0


func _ready() -> void:
	_handler = SaveFileHandler.new(SAVE_PATH, GameState.SAVE_VERSION)
	load_game()
	EventBus.tick_fired.connect(_on_tick)
	EventBus.generator_purchased.connect(func(_t, _c): save_game())


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		save_game()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


func _on_tick(_tick_number: int) -> void:
	_beat_counter += 1
	if _beat_counter >= AUTO_SAVE_BEATS:
		_beat_counter = 0
		save_game()


func save_game() -> void:
	var data: Dictionary = GameState.to_dict()
	var saved: bool = _handler.save_dict(data)
	_last_save_timestamp = data.get("timestamp", _last_save_timestamp) as int
	if saved:
		EventBus.save_completed.emit()


func load_game() -> void:
	var data: Dictionary = _handler.load_dict()
	if data.is_empty():
		return

	data = _handler.migrate(data, {1: _migrate_v1_to_v2, 2: _migrate_v2_to_v3})
	GameState.from_dict(data)
	_last_save_timestamp = data.get("timestamp", 0)

	_process_offline_progress()
	EventBus.load_completed.emit()


func _migrate_v1_to_v2(data: Dictionary) -> Dictionary:
	var gens: Dictionary = data.get("generators", {})
	for key in gens:
		if gens[key].has("count") and not gens[key].has("owned"):
			gens[key]["owned"] = gens[key]["count"]
			gens[key]["produced"] = 0.0
			gens[key].erase("count")
	return data


func _migrate_v2_to_v3(data: Dictionary) -> Dictionary:
	if not data.has("plots"):
		data["plots"] = {}
	return data


func _process_offline_progress() -> void:
	if _last_save_timestamp <= 0:
		return

	var now := int(Time.get_unix_time_from_system())
	var elapsed := now - _last_save_timestamp
	if elapsed < 10:
		return

	var resting_bpm := GameFormulas.resting_heart_rate(GameState.get_age())
	var beats_per_sec := resting_bpm / 60.0
	var raw_beats := int(float(elapsed) * beats_per_sec)
	var max_beats := BASE_OFFLINE_BEATS + UpgradeManager.get_offline_beat_bonus()
	var offline_ticks := mini(raw_beats, max_beats)

	if offline_ticks <= 0:
		return

	var mana_before := GameState.mana
	for _i in offline_ticks:
		_simulate_beat()
	var mana_gained := GameState.mana - mana_before

	if mana_gained > 0.0:
		var time_str := _format_duration(elapsed)
		var mana_str := GameFormulas.format_number(mana_gained)
		EventBus.notification.emit(
			"Welcome back! You earned %s Life Mana in %s." % [mana_str, time_str],
			"info"
		)


func _simulate_beat() -> void:
	GeneratorManager.process_production(1.0, false)
	PlotManager.advance_growth()
	PlotManager.check_full_blooms()


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
	_handler.delete_save()
