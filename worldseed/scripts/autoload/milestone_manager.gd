extends Node

var milestone_data: Array[MilestoneData] = []
var earned: Array[String] = []

const MILESTONE_PATHS: Array[String] = [
	"res://scripts/data_instances/milestones/atmo_25.tres",
	"res://scripts/data_instances/milestones/atmo_50.tres",
	"res://scripts/data_instances/milestones/atmo_100.tres",
	"res://scripts/data_instances/milestones/soil_33.tres",
	"res://scripts/data_instances/milestones/soil_66.tres",
	"res://scripts/data_instances/milestones/soil_100.tres",
	"res://scripts/data_instances/milestones/hydro_33.tres",
	"res://scripts/data_instances/milestones/hydro_66.tres",
	"res://scripts/data_instances/milestones/hydro_100.tres",
]


func _ready() -> void:
	_load_data()


func _load_data() -> void:
	for path in MILESTONE_PATHS:
		if ResourceLoader.exists(path):
			var res: Resource = load(path)
			if res is MilestoneData:
				milestone_data.append(res as MilestoneData)


func check_milestones() -> void:
	for data in milestone_data:
		if data.id in earned:
			continue
		if _evaluate_condition(data):
			_award(data)


func _evaluate_condition(data: MilestoneData) -> bool:
	match data.condition_type:
		"atmosphere_delivered":
			return GameState.atmosphere_delivered >= int(data.condition_value)
		"soil_delivered":
			return GameState.soil_delivered >= int(data.condition_value)
		"hydro_delivered":
			return GameState.hydro_delivered >= int(data.condition_value)
	return false


func _award(data: MilestoneData) -> void:
	earned.append(data.id)

	match data.reward_type:
		"unlock_bees":
			BeeManager.unlock_bees()
		"unlock_plant":
			GameState.unlock_plant(data.reward_target)
		"world_transform":
			WorldProgressor.apply_milestone(data.id)
		"retire_o2":
			O2Manager.retire_tank()
		"win":
			WorldProgressor.apply_milestone(data.id)
			if not GameState.sandbox_mode:
				EventBus.game_won.emit()

	EventBus.milestone_reached.emit(data.id)


func is_earned(milestone_id: String) -> bool:
	return milestone_id in earned


func reset_to_defaults() -> void:
	earned.clear()
