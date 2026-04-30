extends Node

var plot_data: Array[PlotData] = []
var _data_map: Dictionary = {}

const PLOT_PATHS := [
	"res://scripts/data_instances/plots/plot_seedbed.tres",
]


func _ready() -> void:
	_load_data()
	EventBus.tick_fired.connect(_on_tick)


func _load_data() -> void:
	for path in PLOT_PATHS:
		var res := load(path)
		if res is PlotData:
			plot_data.append(res)
			_data_map[res.id] = res
			if res.unlock_total_mana <= 0.0:
				_ensure_state(res.id, res)
				GameState.plots[res.id]["unlocked"] = true


func _ensure_state(plot_id: String, data: PlotData) -> void:
	if GameState.plots.has(plot_id):
		return
	var slots := []
	for _i in data.slot_count:
		slots.append({"planted": false, "growth": 0.0})
	GameState.plots[plot_id] = {
		"unlocked": false,
		"slots": slots,
		"tend_allocation": {},
		"bloom_count": 0,
	}


func reset_to_defaults() -> void:
	GameState.plots.clear()
	for data in plot_data:
		if data.unlock_total_mana <= 0.0:
			_ensure_state(data.id, data)
			GameState.plots[data.id]["unlocked"] = true


func _on_tick(_tick_number: int) -> void:
	_check_unlocks()
	var grew := _advance_growth()
	var bloomed := _check_full_blooms()
	if grew or bloomed:
		UpgradeManager.recalc_all_multipliers()
		EventBus.plot_growth_tick.emit()


func _check_unlocks() -> void:
	for data in plot_data:
		var state: Dictionary = GameState.plots.get(data.id, {})
		if state.get("unlocked", false):
			continue
		if data.unlock_total_mana > 0.0 and GameState.total_mana_earned >= data.unlock_total_mana:
			_ensure_state(data.id, data)
			GameState.plots[data.id]["unlocked"] = true
			EventBus.plot_unlocked.emit(data.id)


func _advance_growth() -> bool:
	var changed := false
	for plot_id in GameState.plots:
		var state: Dictionary = GameState.plots[plot_id]
		if not state["unlocked"]:
			continue
		var data: PlotData = _data_map.get(plot_id)
		if not data or data.growth_ticks <= 0:
			continue
		var increment := 1.0 / data.growth_ticks
		for slot in state["slots"]:
			if slot["planted"] and slot["growth"] < 1.0:
				slot["growth"] = minf(slot["growth"] + increment, 1.0)
				changed = true
	return changed


func _check_full_blooms() -> bool:
	var any_bloomed := false
	for plot_id in GameState.plots:
		var state: Dictionary = GameState.plots[plot_id]
		if not state["unlocked"]:
			continue
		var data: PlotData = _data_map.get(plot_id)
		if not data:
			continue
		var all_planted := true
		var all_blooming := true
		for slot in state["slots"]:
			if not slot["planted"]:
				all_planted = false
				break
			if slot["growth"] < 1.0:
				all_blooming = false
		if not all_planted or not all_blooming:
			continue
		state["bloom_count"] = state.get("bloom_count", 0) + 1
		for slot in state["slots"]:
			slot["planted"] = false
			slot["growth"] = 0.0
		any_bloomed = true
		EventBus.plot_full_bloom.emit(plot_id, state["bloom_count"])
		EventBus.notification.emit(
			"%s reached Full Resonance! (x%d)" % [data.display_name, state["bloom_count"]],
			"bloom"
		)
	return any_bloomed


# --- Planting ---

func plant_seed(plot_id: String) -> bool:
	var data: PlotData = _data_map.get(plot_id)
	if not data:
		return false
	var state: Dictionary = GameState.plots.get(plot_id, {})
	if not state.get("unlocked", false):
		return false

	var slot_index := -1
	var planted_count := 0
	for i in state["slots"].size():
		if state["slots"][i]["planted"]:
			planted_count += 1
		elif slot_index == -1:
			slot_index = i

	if slot_index == -1:
		return false

	var cost := get_plant_cost(plot_id)
	if not GameState.spend_mana(cost):
		return false

	state["slots"][slot_index]["planted"] = true
	state["slots"][slot_index]["growth"] = 0.0
	EventBus.plot_seed_planted.emit(plot_id, slot_index)
	return true


func get_plant_cost(plot_id: String) -> float:
	var data: PlotData = _data_map.get(plot_id)
	if not data:
		return 0.0
	var state: Dictionary = GameState.plots.get(plot_id, {})
	var planted_count := 0
	for slot in state.get("slots", []):
		if slot["planted"]:
			planted_count += 1
	return GameFormulas.plant_seed_cost(data.plant_cost_base, data.plant_cost_mult, planted_count)


func has_empty_slot(plot_id: String) -> bool:
	var state: Dictionary = GameState.plots.get(plot_id, {})
	for slot in state.get("slots", []):
		if not slot["planted"]:
			return true
	return false


# --- Tend allocation ---

func reallocate_tend(plot_id: String, allocation: Dictionary) -> bool:
	var data: PlotData = _data_map.get(plot_id)
	if not data:
		return false
	var state: Dictionary = GameState.plots.get(plot_id, {})
	if not state.get("unlocked", false):
		return false

	var total_points := 0
	for key in allocation:
		if key not in data.tend_options:
			return false
		var pts: int = int(allocation[key])
		if pts < 0:
			return false
		total_points += pts
	if total_points > data.tend_points:
		return false

	state["tend_allocation"] = allocation.duplicate()
	UpgradeManager.recalc_all_multipliers()
	EventBus.plot_tend_changed.emit(plot_id)
	return true


# --- Multiplier queries (called by UpgradeManager) ---

func get_generator_mult(tier: int) -> float:
	var mult := 1.0
	var target_key := "gen_%d" % tier
	for plot_id in GameState.plots:
		var state: Dictionary = GameState.plots[plot_id]
		if not state.get("unlocked", false):
			continue
		var data: PlotData = _data_map.get(plot_id)
		if not data:
			continue
		var alloc: Dictionary = state.get("tend_allocation", {})
		var points: int = int(alloc.get(target_key, 0))
		if tier == 0:
			points += int(alloc.get("mana", 0))
		if points <= 0:
			continue
		var avg := _get_average_maturity(state)
		mult *= 1.0 + (data.tend_power_base * avg * points)
	return mult


func get_bloom_mult(tier: int) -> float:
	var mult := 1.0
	for plot_id in GameState.plots:
		var state: Dictionary = GameState.plots[plot_id]
		var data: PlotData = _data_map.get(plot_id)
		if not data:
			continue
		var bloom_count: int = state.get("bloom_count", 0)
		if bloom_count <= 0:
			continue
		if data.full_bloom_bonus.has("all_generators"):
			mult *= pow(float(data.full_bloom_bonus["all_generators"]), bloom_count)
		var tier_key := "gen_%d" % tier
		if data.full_bloom_bonus.has(tier_key):
			mult *= pow(float(data.full_bloom_bonus[tier_key]), bloom_count)
	return mult


func get_tick_speed_mult() -> float:
	var mult := 1.0
	for plot_id in GameState.plots:
		var state: Dictionary = GameState.plots[plot_id]
		if not state.get("unlocked", false):
			continue
		var data: PlotData = _data_map.get(plot_id)
		if not data:
			continue
		var points: int = int(state.get("tend_allocation", {}).get("tick_speed", 0))
		if points <= 0:
			continue
		var avg := _get_average_maturity(state)
		mult *= 1.0 + (data.tend_power_base * avg * points)
	return mult


# --- Helpers ---

func get_plot_data(plot_id: String) -> PlotData:
	return _data_map.get(plot_id)


func get_plant_stage(growth: float) -> String:
	if growth >= 0.8: return "Ascended"
	if growth >= 0.6: return "Resonant"
	if growth >= 0.4: return "Surging"
	if growth >= 0.2: return "Pulsing"
	return "Inscribed"


func get_stage_power(growth: float) -> float:
	if growth >= 0.8: return 1.0
	if growth >= 0.6: return 0.75
	if growth >= 0.4: return 0.5
	if growth >= 0.2: return 0.25
	return 0.1


func _get_average_maturity(state: Dictionary) -> float:
	var total := 0.0
	var count := 0
	for slot in state["slots"]:
		if slot["planted"]:
			total += get_stage_power(slot["growth"])
			count += 1
	if count == 0:
		return 0.0
	return total / count


func get_tend_label(target: String) -> String:
	match target:
		"mana": return "Mana"
		"tick_speed": return "Tick Speed"
		_:
			if target.begins_with("gen_"):
				var tier := int(target.substr(4))
				var gen_data := GeneratorManager.get_tier_data(tier)
				if gen_data:
					return gen_data.display_name
			return target


# --- Save/Load ---

func to_dict() -> Dictionary:
	var result := {}
	for plot_id in GameState.plots:
		var state: Dictionary = GameState.plots[plot_id]
		var serialized := {
			"unlocked": state["unlocked"],
			"slots": [],
			"tend_allocation": state.get("tend_allocation", {}).duplicate(),
			"bloom_count": state.get("bloom_count", 0),
		}
		for slot in state["slots"]:
			serialized["slots"].append(slot.duplicate())
		result[plot_id] = serialized
	return result


func from_dict(data: Dictionary) -> void:
	for plot_id in data:
		if not _data_map.has(plot_id):
			continue
		var plot_def: PlotData = _data_map[plot_id]
		_ensure_state(plot_id, plot_def)
		var state: Dictionary = GameState.plots[plot_id]
		var saved: Dictionary = data[plot_id]
		state["unlocked"] = saved.get("unlocked", false)
		state["bloom_count"] = saved.get("bloom_count", 0)
		state["tend_allocation"] = saved.get("tend_allocation", {}).duplicate()
		var saved_slots: Array = saved.get("slots", [])
		for i in mini(saved_slots.size(), state["slots"].size()):
			state["slots"][i] = saved_slots[i].duplicate()
	UpgradeManager.recalc_all_multipliers()
