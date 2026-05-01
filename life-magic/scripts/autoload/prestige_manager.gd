extends Node

var blessing_data: Array[BlessingData] = []
var _data_map: Dictionary = {}
var blessing_levels: Dictionary = {}

const BLESSING_PATHS := [
	"res://scripts/data_instances/blessings/head_start.tres",
	"res://scripts/data_instances/blessings/generator_memory.tres",
	"res://scripts/data_instances/blessings/mana_magnetism.tres",
	"res://scripts/data_instances/blessings/sanctum_mastery.tres",
	"res://scripts/data_instances/blessings/surge_frequency.tres",
	"res://scripts/data_instances/blessings/vital_strength.tres",
	"res://scripts/data_instances/blessings/essence_echo.tres",
	"res://scripts/data_instances/blessings/auto_tend.tres",
	"res://scripts/data_instances/blessings/arcanum_key.tres",
]



func _ready() -> void:
	_load_data()


func _load_data() -> void:
	for path in BLESSING_PATHS:
		var res := load(path)
		if res is BlessingData:
			blessing_data.append(res)
			_data_map[res.id] = res
			if not blessing_levels.has(res.id):
				blessing_levels[res.id] = 0


func can_prestige() -> bool:
	return MilestoneManager.is_prestige_unlocked()


func calculate_essence() -> int:
	var base := int(floor(sqrt(GameState.total_mana_earned / 1e6)))
	var echo_bonus := 1.0 + get_blessing_effect("essence_bonus")
	return int(float(base) * echo_bonus)


func execute_prestige() -> void:
	if not can_prestige():
		return

	var earned := calculate_essence()
	GameState.essence += earned
	GameState.lifetime_essence += earned
	GameState.life_cycles += 1

	_reset_run_state()
	_apply_starting_blessings()

	EventBus.seasonal_rebirth_executed.emit(earned)
	EventBus.loop_completed.emit(GameState.life_cycles)
	TutorialManager.show_tip("first_prestige_complete")
	EventBus.notification.emit(
		"Life Cycle complete! +%d Essence earned. Cycle %d begins." % [earned, GameState.life_cycles],
		"tutorial"
	)

	SaveManager.save_game()


func _reset_run_state() -> void:
	GameState.mana = GameState.STARTING_MANA
	GameState.total_mana_earned = 0.0
	GameState.generators.clear()
	GameState._init_generators()
	GameState.unlocked_tiers = [0]

	UpgradeManager.reset_to_defaults()
	PlotManager.reset_to_defaults()
	TickEngine.reset_to_defaults()
	SurgeManager.reset_to_defaults()

	EventBus.mana_changed.emit(GameState.mana, 0.0)


func _apply_starting_blessings() -> void:
	var head_start_level := get_blessing_level("head_start")
	if head_start_level > 0:
		var bonus_mana: float = 150.0 * head_start_level
		GameState.add_mana(bonus_mana)

	var gen_memory_level := get_blessing_level("generator_memory")
	if gen_memory_level > 0:
		for tier in range(gen_memory_level):
			GameState.unlock_tier(tier)

	UpgradeManager.recalc_all_multipliers()


# --- Blessing queries ---

func get_blessing_level(blessing_id: String) -> int:
	return blessing_levels.get(blessing_id, 0)


func get_blessing_effect(effect_type: String) -> float:
	var total := 0.0
	for data in blessing_data:
		var level: int = blessing_levels.get(data.id, 0)
		if level > 0 and data.effect_type == effect_type:
			total += data.effect_value * level
	return total


func is_blessing_maxed(blessing_id: String) -> bool:
	var data: BlessingData = _data_map.get(blessing_id)
	if not data:
		return true
	return blessing_levels.get(blessing_id, 0) >= data.max_level


func get_blessing_cost(blessing_id: String) -> int:
	var data: BlessingData = _data_map.get(blessing_id)
	if not data:
		return 0
	return data.essence_cost


func purchase_blessing(blessing_id: String) -> bool:
	var data: BlessingData = _data_map.get(blessing_id)
	if not data or is_blessing_maxed(blessing_id):
		return false

	var cost := data.essence_cost
	if GameState.essence < cost:
		return false

	GameState.essence -= cost
	blessing_levels[blessing_id] = blessing_levels.get(blessing_id, 0) + 1

	EventBus.blessing_purchased.emit(blessing_id, blessing_levels[blessing_id])
	EventBus.notification.emit(
		"%s upgraded to level %d!" % [data.display_name, blessing_levels[blessing_id]],
		"upgrade"
	)

	UpgradeManager.recalc_all_multipliers()
	return true


func get_data(blessing_id: String) -> BlessingData:
	return _data_map.get(blessing_id)


# --- Save/Load ---

func reset_to_defaults() -> void:
	blessing_levels.clear()
	for data in blessing_data:
		blessing_levels[data.id] = 0


func to_dict() -> Dictionary:
	return blessing_levels.duplicate()


func from_dict(data: Dictionary) -> void:
	for key in data:
		blessing_levels[key] = int(data[key])
