extends Node

var _applied_milestones: Array[String] = []


func apply_milestone(milestone_id: String) -> void:
	if milestone_id in _applied_milestones:
		return
	_applied_milestones.append(milestone_id)


func is_applied(milestone_id: String) -> bool:
	return milestone_id in _applied_milestones


func reset_to_defaults() -> void:
	_applied_milestones.clear()
