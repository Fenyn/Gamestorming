extends Node

const BEAT_SCALE := 0.125

var tier_data: Array[GeneratorData] = []
var _tier_map: Dictionary = {}


func _ready() -> void:
	_load_generator_data()
	EventBus.tick_fired.connect(_on_tick)


func _load_generator_data() -> void:
	var paths := [
		"res://scripts/data_instances/generators/generator_sprout.tres",
		"res://scripts/data_instances/generators/generator_herb.tres",
		"res://scripts/data_instances/generators/generator_flower.tres",
		"res://scripts/data_instances/generators/generator_vine.tres",
		"res://scripts/data_instances/generators/generator_shrub.tres",
	]

	for path in paths:
		var res := load(path)
		if res is GeneratorData:
			tier_data.append(res)
			_tier_map[res.tier] = res

	tier_data.sort_custom(func(a: GeneratorData, b: GeneratorData): return a.tier < b.tier)

	for data in tier_data:
		if data.unlock_total_mana <= 0.0:
			GameState.unlock_tier(data.tier)


func _on_tick(_tick_number: int) -> void:
	_check_unlocks()
	_process_cascade()


func _process_cascade() -> void:
	var harmonic_mult := 1.0
	var interval := UpgradeManager.get_harmonic_interval()
	if interval > 0 and TickEngine.beat_count % interval == 0:
		harmonic_mult = 3.0
	var total_mult := SurgeManager.production_multiplier * SurgeManager.get_vital_charge_mult() * harmonic_mult
	process_production(total_mult, true)


func process_production(surge_mult: float = 1.0, emit_signals: bool = true) -> void:
	for i in range(tier_data.size() - 1, -1, -1):
		var data := tier_data[i]
		var count := GameState.get_generator_count(data.tier)
		if count <= 0.0:
			continue

		var multiplier := GameState.get_generator_multiplier(data.tier)
		var produced := GameFormulas.generator_production(count, data.base_production, multiplier) * BEAT_SCALE * surge_mult

		if data.produces_tier >= 0:
			var echo_chance := UpgradeManager.get_cascade_echo_chance()
			if echo_chance > 0.0 and randf() < echo_chance:
				produced *= 2.0

		if data.produces_tier == -1:
			GameState.add_mana(produced)
		else:
			GameState.add_generator_produced(data.produces_tier, produced)

		if emit_signals:
			EventBus.generator_production_tick.emit(data.tier, produced)


func _check_unlocks() -> void:
	for data in tier_data:
		if GameState.is_tier_unlocked(data.tier):
			continue
		if data.unlock_total_mana > 0.0 and GameState.total_mana_earned >= data.unlock_total_mana:
			GameState.unlock_tier(data.tier)


func purchase_generator(tier: int, amount: int = 1) -> bool:
	var data: GeneratorData = _tier_map.get(tier)
	if not data:
		return false

	var owned := GameState.get_generator_owned(tier)
	var cost := GameFormulas.generator_bulk_cost(data.base_cost, data.cost_multiplier, owned, amount)

	if not GameState.spend_mana(cost):
		return false

	GameState.add_generator_owned(tier, float(amount))
	EventBus.generator_purchased.emit(tier, GameState.get_generator_count(tier))
	return true


func get_next_cost(tier: int) -> float:
	var data: GeneratorData = _tier_map.get(tier)
	if not data:
		return 0.0
	return GameFormulas.generator_cost(data.base_cost, data.cost_multiplier, GameState.get_generator_owned(tier))


func get_bulk_cost(tier: int, amount: int) -> float:
	var data: GeneratorData = _tier_map.get(tier)
	if not data:
		return 0.0
	return GameFormulas.generator_bulk_cost(data.base_cost, data.cost_multiplier, GameState.get_generator_owned(tier), amount)


func get_max_affordable(tier: int) -> int:
	var data: GeneratorData = _tier_map.get(tier)
	if not data:
		return 0
	return GameFormulas.generator_max_affordable(data.base_cost, data.cost_multiplier, GameState.get_generator_owned(tier), GameState.mana)


func get_tier_data(tier: int) -> GeneratorData:
	return _tier_map.get(tier)


func get_production_per_beat(tier: int) -> float:
	var data: GeneratorData = _tier_map.get(tier)
	if not data:
		return 0.0
	return GameFormulas.generator_production(
		GameState.get_generator_count(tier),
		data.base_production,
		GameState.get_generator_multiplier(tier)
	) * BEAT_SCALE


func get_total_mana_per_beat() -> float:
	var total := 0.0
	for data in tier_data:
		if data.produces_tier == -1:
			total += get_production_per_beat(data.tier)
	return total
