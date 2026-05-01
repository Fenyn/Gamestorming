extends Node

const CHECK_INTERVAL := 30

var milestone_data: Array[MilestoneData] = []
var earned: Array[String] = []
var surges_completed: int = 0

var _check_counter: int = 0
var _prestige_unlocked: bool = false

const MILESTONE_PATHS := [
	"res://scripts/data_instances/milestones/cascade_begins.tres",
	"res://scripts/data_instances/milestones/sigil_inscribed.tres",
	"res://scripts/data_instances/milestones/first_resonance.tres",
	"res://scripts/data_instances/milestones/three_fold.tres",
	"res://scripts/data_instances/milestones/full_spectrum.tres",
	"res://scripts/data_instances/milestones/surge_channeled.tres",
	"res://scripts/data_instances/milestones/bloom_mastery.tres",
	"res://scripts/data_instances/milestones/vital_walker.tres",
	"res://scripts/data_instances/milestones/new_beginning.tres",
	"res://scripts/data_instances/milestones/convergence.tres",
]


func _ready() -> void:
	_load_data()
	EventBus.tick_fired.connect(_on_tick)
	EventBus.surge_completed.connect(_on_surge_completed)
	_prestige_unlocked = "full_spectrum" in earned


func _load_data() -> void:
	for path in MILESTONE_PATHS:
		var res := load(path)
		if res is MilestoneData:
			milestone_data.append(res)


func _on_tick(_tick_number: int) -> void:
	_check_counter += 1
	if _check_counter >= CHECK_INTERVAL:
		_check_counter = 0
		_check_milestones()


func _on_surge_completed(_surge_id: String) -> void:
	surges_completed += 1


func _check_milestones() -> void:
	for data in milestone_data:
		if data.id in earned:
			continue
		if _evaluate_condition(data):
			_award(data)


func _evaluate_condition(data: MilestoneData) -> bool:
	match data.condition_type:
		"any_tier_above_0":
			for tier in range(1, 5):
				if GameState.get_generator_owned(tier) >= data.condition_value:
					return true
			return false
		"total_planted":
			return _get_total_planted() >= int(data.condition_value)
		"total_blooms":
			return _get_total_blooms() >= int(data.condition_value)
		"active_tiers":
			return _get_active_tier_count() >= int(data.condition_value)
		"surges_completed":
			return surges_completed >= int(data.condition_value)
		"vitality_lifetime":
			return GameState.vitality_lifetime >= data.condition_value
		"life_cycles":
			return GameState.life_cycles >= int(data.condition_value)
		"sanctums_with_plants":
			return _get_sanctums_with_plants() >= int(data.condition_value)
	return false


func _award(data: MilestoneData) -> void:
	earned.append(data.id)

	match data.reward_type:
		"unlock_upgrade":
			UpgradeManager.milestone_unlock(data.reward_target)
		"unlock_plot":
			PlotManager.milestone_unlock(data.reward_target)
		"unlock_prestige":
			_prestige_unlocked = true
		"production_burst":
			_grant_production_burst(data.reward_value)
		"bonus_essence":
			GameState.essence += int(data.reward_value)
			GameState.lifetime_essence += int(data.reward_value)
		"free_generators":
			_grant_free_generators(int(data.reward_value))

	EventBus.milestone_earned.emit(data.id)
	EventBus.notification.emit(
		"%s: %s" % [data.display_name, data.flavor_text],
		"milestone"
	)
	TutorialManager.show_tip("first_milestone")


func _grant_production_burst(seconds: float) -> void:
	var mana_per_beat := GeneratorManager.get_total_mana_per_beat()
	var bpm := HeartRateManager.smoothed_bpm
	if bpm <= 0.0 or mana_per_beat <= 0.0:
		return
	var beats := (bpm / 60.0) * seconds
	var burst := mana_per_beat * beats
	GameState.add_mana(burst)
	EventBus.notification.emit(
		"Production burst! +%s mana!" % GameFormulas.format_number(burst),
		"surge"
	)


func _grant_free_generators(count: int) -> void:
	for tier in GameState.unlocked_tiers:
		if GameState.get_generator_count(tier) > 0.0:
			GameState.add_generator_owned(tier, float(count))
			EventBus.generator_purchased.emit(tier, GameState.get_generator_count(tier))
	EventBus.notification.emit(
		"Convergence! A free spell of every kind!",
		"surge"
	)


func is_prestige_unlocked() -> bool:
	return _prestige_unlocked


func _get_total_blooms() -> int:
	var total := 0
	for plot_id in GameState.plots:
		total += int(GameState.plots[plot_id].get("bloom_count", 0))
	return total


func _get_total_planted() -> int:
	var total := 0
	for plot_id in GameState.plots:
		var state: Dictionary = GameState.plots[plot_id]
		if not state.get("unlocked", false):
			continue
		for slot in state.get("slots", []):
			if slot.get("planted", false):
				total += 1
	return total


func _get_active_tier_count() -> int:
	var count := 0
	for tier in GameState.unlocked_tiers:
		if GameState.get_generator_count(tier) > 0.0:
			count += 1
	return count


func _get_sanctums_with_plants() -> int:
	var count := 0
	for plot_id in GameState.plots:
		var state: Dictionary = GameState.plots[plot_id]
		if not state.get("unlocked", false):
			continue
		for slot in state.get("slots", []):
			if slot.get("planted", false):
				count += 1
				break
	return count


func is_earned(milestone_id: String) -> bool:
	return milestone_id in earned


func get_earned_count() -> int:
	return earned.size()


func get_total_count() -> int:
	return milestone_data.size()


func reset_to_defaults() -> void:
	earned.clear()
	surges_completed = 0
	_check_counter = 0
	_prestige_unlocked = false


func to_dict() -> Dictionary:
	return {
		"earned": earned.duplicate(),
		"surges_completed": surges_completed,
	}


func from_dict(data: Dictionary) -> void:
	earned.clear()
	var saved: Array = data.get("earned", [])
	for m_id in saved:
		earned.append(str(m_id))
	surges_completed = int(data.get("surges_completed", 0))
	_prestige_unlocked = "full_spectrum" in earned
