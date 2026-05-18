class_name Unit
extends Node2D

signal ap_changed(current: int)
signal walk_finished

const MAX_AP: int = 3
const MOVE_COST: int = 1
const WALK_SPEED: float = 0.15

var current_tile: Vector2i = Vector2i.ZERO
var action_points: int = MAX_AP
var _is_walking: bool = false

@onready var _ap_label: Label = %APLabel


func setup(tile: Vector2i) -> void:
	current_tile = tile
	position = Grid.tile_to_world(tile)
	action_points = MAX_AP
	_update_ap_display()


func can_move() -> bool:
	return action_points >= MOVE_COST and not _is_walking


func walk_path(tile_path: Array[Vector2i]) -> void:
	if _is_walking:
		return
	_is_walking = true

	for i: int in range(1, tile_path.size()):
		if action_points < MOVE_COST:
			break
		var target_tile: Vector2i = tile_path[i]
		var target_world: Vector2 = Grid.tile_to_world(target_tile)
		var tween: Tween = create_tween()
		tween.tween_property(self, "position", target_world, WALK_SPEED)
		await tween.finished
		current_tile = target_tile
		action_points -= MOVE_COST
		_update_ap_display()
		ap_changed.emit(action_points)

	_is_walking = false
	walk_finished.emit()


func _update_ap_display() -> void:
	if _ap_label:
		_ap_label.text = "AP: " + str(action_points)
