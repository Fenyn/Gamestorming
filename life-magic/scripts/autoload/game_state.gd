extends Node

const STARTING_MANA := 15.0
const SAVE_VERSION := 3

var mana: float = STARTING_MANA
var total_mana_earned: float = 0.0
var generators: Dictionary = {}
var unlocked_tiers: Array[int] = [0]
var tick_speed_level: int = 0
var season_tokens: int = 0
var rebirths_done: int = 0
var total_play_time: float = 0.0
var plots: Dictionary = {}

var settings: Dictionary = {
	"age": 30.0,
	"hr_cap_pct": 0.85,
	"simulated_bpm": 80.0,
	"hr_source": "demo",
}


func _ready() -> void:
	_init_generators()


func reset_to_defaults() -> void:
	mana = STARTING_MANA
	total_mana_earned = 0.0
	generators.clear()
	_init_generators()
	unlocked_tiers = [0]
	tick_speed_level = 0
	season_tokens = 0
	rebirths_done = 0
	total_play_time = 0.0
	plots.clear()

	UpgradeManager.reset_to_defaults()
	PlotManager.reset_to_defaults()
	TickEngine.reset_to_defaults()
	HeartRateManager.reset_to_defaults()

	EventBus.mana_changed.emit(mana, 0.0)


func _init_generators() -> void:
	for tier in range(8):
		if not generators.has(tier):
			generators[tier] = {"owned": 0.0, "produced": 0.0, "multiplier": 1.0}


func add_mana(amount: float) -> void:
	mana += amount
	total_mana_earned += amount
	EventBus.mana_changed.emit(mana, amount)


func spend_mana(amount: float) -> bool:
	if mana < amount:
		return false
	mana -= amount
	EventBus.mana_changed.emit(mana, -amount)
	return true


func get_generator_count(tier: int) -> float:
	if generators.has(tier):
		return generators[tier]["owned"] + generators[tier]["produced"]
	return 0.0


func get_generator_owned(tier: int) -> float:
	if generators.has(tier):
		return generators[tier]["owned"]
	return 0.0


func get_generator_produced(tier: int) -> float:
	if generators.has(tier):
		return generators[tier]["produced"]
	return 0.0


func add_generator_owned(tier: int, amount: float) -> void:
	if not generators.has(tier):
		generators[tier] = {"owned": 0.0, "produced": 0.0, "multiplier": 1.0}
	generators[tier]["owned"] += amount


func add_generator_produced(tier: int, amount: float) -> void:
	if not generators.has(tier):
		generators[tier] = {"owned": 0.0, "produced": 0.0, "multiplier": 1.0}
	generators[tier]["produced"] += amount


func get_generator_multiplier(tier: int) -> float:
	if generators.has(tier):
		return generators[tier]["multiplier"]
	return 1.0


func set_generator_multiplier(tier: int, mult: float) -> void:
	if not generators.has(tier):
		generators[tier] = {"owned": 0.0, "produced": 0.0, "multiplier": 1.0}
	generators[tier]["multiplier"] = mult


func unlock_tier(tier: int) -> void:
	if tier not in unlocked_tiers:
		unlocked_tiers.append(tier)
		unlocked_tiers.sort()
		EventBus.generator_unlocked.emit(tier)


func is_tier_unlocked(tier: int) -> bool:
	return tier in unlocked_tiers


func to_dict() -> Dictionary:
	var gen_data := {}
	for tier in generators:
		gen_data[str(tier)] = generators[tier].duplicate()
	return {
		"save_version": SAVE_VERSION,
		"timestamp": int(Time.get_unix_time_from_system()),
		"mana": mana,
		"total_mana_earned": total_mana_earned,
		"generators": gen_data,
		"unlocked_tiers": unlocked_tiers.duplicate(),
		"tick_speed_level": tick_speed_level,
		"season_tokens": season_tokens,
		"rebirths_done": rebirths_done,
		"total_play_time": total_play_time,
		"settings": settings.duplicate(),
		"upgrades": UpgradeManager.to_dict(),
		"plots": PlotManager.to_dict(),
	}


func from_dict(data: Dictionary) -> void:
	mana = data.get("mana", STARTING_MANA)
	total_mana_earned = data.get("total_mana_earned", 0.0)
	tick_speed_level = data.get("tick_speed_level", 0)
	season_tokens = data.get("season_tokens", 0)
	rebirths_done = data.get("rebirths_done", 0)
	total_play_time = data.get("total_play_time", 0.0)

	generators.clear()
	var gen_data: Dictionary = data.get("generators", {})
	for key in gen_data:
		var entry: Dictionary = gen_data[key].duplicate()
		if entry.has("count") and not entry.has("owned"):
			entry["owned"] = entry["count"]
			entry["produced"] = 0.0
			entry.erase("count")
		generators[int(key)] = entry
	_init_generators()

	unlocked_tiers.clear()
	var tiers_data: Array = data.get("unlocked_tiers", [0])
	for t in tiers_data:
		unlocked_tiers.append(int(t))

	var saved_settings: Dictionary = data.get("settings", {})
	for key in saved_settings:
		settings[key] = saved_settings[key]

	var upgrade_levels: Dictionary = data.get("upgrades", {})
	if not upgrade_levels.is_empty():
		UpgradeManager.from_dict(upgrade_levels)

	var plot_data_saved: Dictionary = data.get("plots", {})
	if not plot_data_saved.is_empty():
		PlotManager.from_dict(plot_data_saved)

	EventBus.mana_changed.emit(mana, 0.0)
