extends Node

const STARTING_MANA := 15.0
const SAVE_VERSION := 3

var mana: float = STARTING_MANA
var total_mana_earned: float = 0.0
var generators: Dictionary = {}
var unlocked_tiers: Array[int] = [0]
var season_tokens: int = 0
var rebirths_done: int = 0
var essence: int = 0
var lifetime_essence: int = 0
var life_cycles: int = 0
var total_play_time: float = 0.0
var plots: Dictionary = {}
var vitality: float = 0.0
var vitality_earned_at: int = 0
var vitality_lifetime: float = 0.0

var settings: Dictionary = {
	"age": 30.0,
	"hr_cap_pct": 0.85,
	"simulated_bpm": 80.0,
	"hr_source": "demo",
}


func get_age() -> float:
	return settings.get("age", 30.0)


func get_hr_cap_pct() -> float:
	return settings.get("hr_cap_pct", 0.85)


func get_simulated_bpm() -> float:
	return settings.get("simulated_bpm", 80.0)


func get_hr_source() -> String:
	return settings.get("hr_source", "demo")


func _ready() -> void:
	_init_generators()


func reset_to_defaults() -> void:
	mana = STARTING_MANA
	total_mana_earned = 0.0
	generators.clear()
	_init_generators()
	unlocked_tiers = [0]
	season_tokens = 0
	rebirths_done = 0
	essence = 0
	lifetime_essence = 0
	life_cycles = 0
	total_play_time = 0.0
	plots.clear()
	vitality = 0.0
	vitality_earned_at = 0
	vitality_lifetime = 0.0

	UpgradeManager.reset_to_defaults()
	PlotManager.reset_to_defaults()
	TickEngine.reset_to_defaults()
	HeartRateManager.reset_to_defaults()
	SurgeManager.reset_to_defaults()
	TutorialManager.reset_to_defaults()
	MilestoneManager.reset_to_defaults()
	PrestigeManager.reset_to_defaults()

	EventBus.mana_changed.emit(mana, 0.0)


func _init_generators() -> void:
	for tier in range(8):
		_ensure_generator(tier)


func _ensure_generator(tier: int) -> void:
	if not generators.has(tier):
		generators[tier] = {"owned": 0.0, "produced": 0.0, "multiplier": 1.0}


const VITALITY_EXPIRY_SECONDS := 86400


func add_vitality(amount: float) -> void:
	vitality += amount
	vitality_lifetime += amount
	vitality_earned_at = int(Time.get_unix_time_from_system())
	EventBus.vitality_changed.emit(vitality)


func spend_vitality(amount: float) -> bool:
	if vitality < amount:
		return false
	vitality -= amount
	EventBus.vitality_changed.emit(vitality)
	return true


func _expire_vitality() -> void:
	if vitality <= 0.0 or vitality_earned_at <= 0:
		return
	var elapsed := int(Time.get_unix_time_from_system()) - vitality_earned_at
	if elapsed >= VITALITY_EXPIRY_SECONDS:
		vitality = 0.0
		vitality_earned_at = 0


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
	_ensure_generator(tier)
	generators[tier]["owned"] += amount


func add_generator_produced(tier: int, amount: float) -> void:
	_ensure_generator(tier)
	generators[tier]["produced"] += amount


func get_generator_multiplier(tier: int) -> float:
	if generators.has(tier):
		return generators[tier]["multiplier"]
	return 1.0


func set_generator_multiplier(tier: int, mult: float) -> void:
	_ensure_generator(tier)
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
		"season_tokens": season_tokens,
		"rebirths_done": rebirths_done,
		"essence": essence,
		"lifetime_essence": lifetime_essence,
		"life_cycles": life_cycles,
		"blessings": PrestigeManager.to_dict(),
		"total_play_time": total_play_time,
		"settings": settings.duplicate(),
		"upgrades": UpgradeManager.to_dict(),
		"plots": PlotManager.to_dict(),
		"vitality": vitality,
		"vitality_earned_at": vitality_earned_at,
		"vitality_lifetime": vitality_lifetime,
		"tutorials": TutorialManager.to_dict(),
		"milestones": MilestoneManager.to_dict(),
	}


func from_dict(data: Dictionary) -> void:
	mana = data.get("mana", STARTING_MANA)
	total_mana_earned = data.get("total_mana_earned", 0.0)
	season_tokens = data.get("season_tokens", 0)
	rebirths_done = data.get("rebirths_done", 0)
	essence = int(data.get("essence", data.get("season_tokens", 0)))
	lifetime_essence = int(data.get("lifetime_essence", 0))
	life_cycles = int(data.get("life_cycles", data.get("rebirths_done", 0)))
	total_play_time = data.get("total_play_time", 0.0)
	vitality = data.get("vitality", 0.0)
	vitality_earned_at = int(data.get("vitality_earned_at", 0))
	vitality_lifetime = data.get("vitality_lifetime", 0.0)
	_expire_vitality()

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

	var blessing_save: Dictionary = data.get("blessings", {})
	if not blessing_save.is_empty():
		PrestigeManager.from_dict(blessing_save)

	var tutorial_data: Dictionary = data.get("tutorials", {})
	if not tutorial_data.is_empty():
		TutorialManager.from_dict(tutorial_data)

	var milestone_save: Dictionary = data.get("milestones", {})
	if not milestone_save.is_empty():
		MilestoneManager.from_dict(milestone_save)

	EventBus.mana_changed.emit(mana, 0.0)
