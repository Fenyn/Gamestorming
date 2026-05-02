extends Node

var bees_unlocked: bool = false
var fleet: Array[Node3D] = []
var assignments: Dictionary = {}

var speed_tier: int = 0
var carry_tier: int = 0


func unlock_bees() -> void:
	bees_unlocked = true


func assign_bee(bee: Node3D, role: String) -> void:
	assignments[bee] = role
	EventBus.bee_assigned.emit(bee, role)


func unassign_bee(bee: Node3D) -> void:
	assignments.erase(bee)
	EventBus.bee_unassigned.emit(bee)


func get_active_count() -> int:
	return assignments.size()


func get_power_draw() -> float:
	return float(assignments.size()) * 2.0


func reset_to_defaults() -> void:
	bees_unlocked = false
	fleet.clear()
	assignments.clear()
	speed_tier = 0
	carry_tier = 0
