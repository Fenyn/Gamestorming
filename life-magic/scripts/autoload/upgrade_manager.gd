extends Node

var upgrade_data: Array[UpgradeData] = []
var _data_map: Dictionary = {}
var levels: Dictionary = {}
var unlocked: Dictionary = {}

const UPGRADE_PATHS := [
	"res://scripts/data_instances/upgrades/upgrade_sprout_mult.tres",
	"res://scripts/data_instances/upgrades/upgrade_herb_mult.tres",
	"res://scripts/data_instances/upgrades/upgrade_flower_mult.tres",
	"res://scripts/data_instances/upgrades/upgrade_vine_mult.tres",
	"res://scripts/data_instances/upgrades/upgrade_shrub_mult.tres",
	"res://scripts/data_instances/upgrades/upgrade_all_mult.tres",
	"res://scripts/data_instances/upgrades/upgrade_cascade_echo.tres",
	"res://scripts/data_instances/upgrades/upgrade_bloom_burst.tres",
	"res://scripts/data_instances/upgrades/upgrade_harmonic.tres",
]


func _ready() -> void:
	_load_data()
	EventBus.tick_fired.connect(func(_t): _check_unlocks())
	_apply_all_effects()


func _load_data() -> void:
	for path in UPGRADE_PATHS:
		var res := load(path)
		if res is UpgradeData:
			upgrade_data.append(res)
			_data_map[res.id] = res
			if not levels.has(res.id):
				levels[res.id] = 0
			unlocked[res.id] = res.unlock_total_mana <= 0.0


func reset_to_defaults() -> void:
	levels.clear()
	unlocked.clear()
	for data in upgrade_data:
		levels[data.id] = 0
		unlocked[data.id] = data.unlock_total_mana <= 0.0


func get_level(id: String) -> int:
	return levels.get(id, 0)


func get_cost(id: String) -> float:
	var data: UpgradeData = _data_map.get(id)
	if not data:
		return 0.0
	return data.base_cost * pow(data.cost_multiplier, levels.get(id, 0))


func is_maxed(id: String) -> bool:
	var data: UpgradeData = _data_map.get(id)
	if not data:
		return true
	return data.max_level > 0 and levels.get(id, 0) >= data.max_level


func is_unlocked(id: String) -> bool:
	return unlocked.get(id, false)


func purchase(id: String) -> bool:
	var data: UpgradeData = _data_map.get(id)
	if not data or is_maxed(id):
		return false

	var cost := get_cost(id)
	if not GameState.spend_mana(cost):
		return false

	levels[id] = levels.get(id, 0) + 1
	_apply_effect(data)
	EventBus.notification.emit(
		"%s upgraded to level %d!" % [data.display_name, levels[id]], "upgrade"
	)
	return true


func _check_unlocks() -> void:
	for data in upgrade_data:
		if unlocked.get(data.id, false):
			continue
		if data.unlock_total_mana > 0.0 and GameState.total_mana_earned >= data.unlock_total_mana:
			unlocked[data.id] = true


func _apply_effect(data: UpgradeData) -> void:
	match data.effect_type:
		"generator_mult":
			_apply_generator_mult(data)


func _apply_all_effects() -> void:
	for data in upgrade_data:
		var level: int = levels.get(data.id, 0)
		if level > 0:
			match data.effect_type:
				"generator_mult":
					_apply_generator_mult(data)


func _apply_generator_mult(data: UpgradeData) -> void:
	if data.effect_target == "all":
		for tier in range(8):
			_recalc_tier_multiplier(tier)
	else:
		var tier := int(data.effect_target)
		_recalc_tier_multiplier(tier)


func recalc_all_multipliers() -> void:
	for tier in range(8):
		_recalc_tier_multiplier(tier)


func _recalc_tier_multiplier(tier: int) -> void:
	var mult := 1.0
	for data in upgrade_data:
		if data.effect_type != "generator_mult":
			continue
		var level: int = levels.get(data.id, 0)
		if level <= 0:
			continue
		if data.effect_target == "all" or int(data.effect_target) == tier:
			mult *= (1.0 + data.effect_per_level * level)
	var pm := get_node_or_null("/root/PlotManager")
	if pm:
		mult *= pm.get_generator_mult(tier)
		mult *= pm.get_bloom_mult(tier)
	var prestm := get_node_or_null("/root/PrestigeManager")
	if prestm:
		mult *= 1.0 + prestm.get_blessing_effect("all_production")
	GameState.set_generator_multiplier(tier, mult)



func get_cascade_echo_chance() -> float:
	var data: UpgradeData = _data_map.get("cascade_echo")
	if not data:
		return 0.0
	var level: int = levels.get("cascade_echo", 0)
	return data.effect_per_level * level


func get_bloom_burst_seconds() -> float:
	var data: UpgradeData = _data_map.get("bloom_burst")
	if not data:
		return 0.0
	var level: int = levels.get("bloom_burst", 0)
	return data.effect_per_level * level


func get_harmonic_interval() -> int:
	var level: int = levels.get("harmonic", 0)
	if level <= 0:
		return 0
	return maxi(20 - (level - 1) * 3, 5)


func milestone_unlock(upgrade_id: String) -> void:
	if _data_map.has(upgrade_id):
		unlocked[upgrade_id] = true


func get_data(id: String) -> UpgradeData:
	return _data_map.get(id)


func get_visible_upgrades() -> Array[UpgradeData]:
	var result: Array[UpgradeData] = []
	for data in upgrade_data:
		if unlocked.get(data.id, false) and not is_maxed(data.id):
			result.append(data)
	return result


func to_dict() -> Dictionary:
	return levels.duplicate()


func from_dict(data: Dictionary) -> void:
	for key in data:
		levels[key] = int(data[key])
	_apply_all_effects()
