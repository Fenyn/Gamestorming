extends Node

var node_data: Array[EssenceNodeData] = []
var _data_map: Dictionary = {}
var node_levels: Dictionary = {}

const NODE_PATHS := [
	"res://scripts/data_instances/essence_nodes/mana_magnetism.tres",
	"res://scripts/data_instances/essence_nodes/head_start.tres",
	"res://scripts/data_instances/essence_nodes/generator_memory.tres",
	"res://scripts/data_instances/essence_nodes/warden_gate.tres",
	"res://scripts/data_instances/essence_nodes/spire_gate.tres",
	"res://scripts/data_instances/essence_nodes/cascade_resonance.tres",
	"res://scripts/data_instances/essence_nodes/echo_amplifier.tres",
	"res://scripts/data_instances/essence_nodes/tier_mastery.tres",
	"res://scripts/data_instances/essence_nodes/aether_gate.tres",
	"res://scripts/data_instances/essence_nodes/worldpulse_gate.tres",
	"res://scripts/data_instances/essence_nodes/primordial_gate.tres",
	"res://scripts/data_instances/essence_nodes/infinite_growth.tres",
	"res://scripts/data_instances/essence_nodes/surge_frequency.tres",
	"res://scripts/data_instances/essence_nodes/quick_recovery.tres",
	"res://scripts/data_instances/essence_nodes/sustained_pulse.tres",
	"res://scripts/data_instances/essence_nodes/dual_surge.tres",
	"res://scripts/data_instances/essence_nodes/surge_mastery.tres",
	"res://scripts/data_instances/essence_nodes/convergence_surge.tres",
	"res://scripts/data_instances/essence_nodes/sanctum_mastery.tres",
	"res://scripts/data_instances/essence_nodes/sanctum_unlock.tres",
	"res://scripts/data_instances/essence_nodes/auto_tend.tres",
	"res://scripts/data_instances/essence_nodes/vital_seedling.tres",
	"res://scripts/data_instances/essence_nodes/deep_roots.tres",
	"res://scripts/data_instances/essence_nodes/bloom_cascade.tres",
	"res://scripts/data_instances/essence_nodes/eternal_garden.tres",
	"res://scripts/data_instances/essence_nodes/overgrowth.tres",
	"res://scripts/data_instances/essence_nodes/vital_strength.tres",
	"res://scripts/data_instances/essence_nodes/endurance.tres",
	"res://scripts/data_instances/essence_nodes/beat_enrichment.tres",
	"res://scripts/data_instances/essence_nodes/step_compounding.tres",
	"res://scripts/data_instances/essence_nodes/living_investment.tres",
	"res://scripts/data_instances/essence_nodes/vital_bloom.tres",
	"res://scripts/data_instances/essence_nodes/essence_echo.tres",
	"res://scripts/data_instances/essence_nodes/swift_rebirth.tres",
	"res://scripts/data_instances/essence_nodes/cycle_momentum.tres",
	"res://scripts/data_instances/essence_nodes/memory_palace.tres",
	"res://scripts/data_instances/essence_nodes/arcanum_key.tres",
	"res://scripts/data_instances/essence_nodes/transcendence.tres",
]


func _ready() -> void:
	_load_data()


func _load_data() -> void:
	for path in NODE_PATHS:
		var res: Resource = load(path)
		if res is EssenceNodeData:
			node_data.append(res)
			_data_map[res.id] = res
			if not node_levels.has(res.id):
				node_levels[res.id] = 0


func can_prestige() -> bool:
	return GameState.get_generator_owned(2) >= 1.0


func calculate_essence() -> int:
	var base: int = int(floor(sqrt(GameState.total_mana_earned / 1000.0)))
	var echo_bonus: float = 1.0 + get_blessing_effect("essence_bonus")
	return int(float(base) * echo_bonus)


func execute_prestige() -> void:
	if not can_prestige():
		return

	var earned: int = calculate_essence()
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
	var head_start_mana: float = get_blessing_effect("starting_mana")
	if head_start_mana > 0.0:
		GameState.add_mana(head_start_mana)

	var memory_tiers: int = int(get_blessing_effect("starting_tiers"))
	if memory_tiers > 0:
		for tier in range(memory_tiers):
			GameState.unlock_tier(tier)

	UpgradeManager.recalc_all_multipliers()


# --- Node queries ---


func are_prereqs_met(node_id: String) -> bool:
	var data: EssenceNodeData = _data_map.get(node_id)
	if not data:
		return false
	for prereq_id in data.prerequisite_ids:
		if node_levels.get(prereq_id, 0) <= 0:
			return false
	return true


func is_node_unlocked(node_id: String) -> bool:
	return are_prereqs_met(node_id)


func is_node_purchased(node_id: String) -> bool:
	return node_levels.get(node_id, 0) > 0


func is_node_maxed(node_id: String) -> bool:
	var data: EssenceNodeData = _data_map.get(node_id)
	if not data:
		return true
	return node_levels.get(node_id, 0) >= data.max_level


func get_node_cost(node_id: String) -> int:
	var data: EssenceNodeData = _data_map.get(node_id)
	if not data:
		return 0
	var level: int = node_levels.get(node_id, 0)
	return data.base_cost + data.cost_scaling * level


func purchase_node(node_id: String) -> bool:
	var data: EssenceNodeData = _data_map.get(node_id)
	if not data or is_node_maxed(node_id):
		return false
	if not are_prereqs_met(node_id):
		return false

	var cost: int = get_node_cost(node_id)
	if GameState.essence < cost:
		return false

	GameState.essence -= cost
	node_levels[node_id] = node_levels.get(node_id, 0) + 1

	_apply_immediate_effect(data)

	EventBus.blessing_purchased.emit(node_id, node_levels[node_id])
	EventBus.notification.emit(
		"%s upgraded to level %d!" % [data.display_name, node_levels[node_id]],
		"upgrade"
	)

	UpgradeManager.recalc_all_multipliers()
	return true


func _apply_immediate_effect(data: EssenceNodeData) -> void:
	match data.effect_type:
		"unlock_plot":
			PlotManager.milestone_unlock("seedbed")


func is_tier_gate_unlocked(tier: int) -> bool:
	for data in node_data:
		if data.tier_gate == tier:
			return node_levels.get(data.id, 0) > 0
	return true


func get_node_data(node_id: String) -> EssenceNodeData:
	return _data_map.get(node_id)


func get_nodes_for_branch(branch: String) -> Array[EssenceNodeData]:
	var result: Array[EssenceNodeData] = []
	for data in node_data:
		if data.branch == branch:
			result.append(data)
	return result


func get_all_branches() -> Array[String]:
	return ["verdant", "pulse", "bloom", "vital", "arcane"]


# --- Backward-compatible aliases ---


func get_blessing_level(node_id: String) -> int:
	return node_levels.get(node_id, 0)


func get_blessing_effect(effect_type: String) -> float:
	var total: float = 0.0
	for data in node_data:
		var level: int = node_levels.get(data.id, 0)
		if level > 0 and data.effect_type == effect_type:
			total += data.effect_value * level
	return total


# --- Save/Load ---


func reset_to_defaults() -> void:
	node_levels.clear()
	for data in node_data:
		node_levels[data.id] = 0


func to_dict() -> Dictionary:
	return node_levels.duplicate()


func from_dict(data: Dictionary) -> void:
	for key in data:
		node_levels[key] = int(data[key])
