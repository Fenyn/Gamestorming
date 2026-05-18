class_name Mover
extends Node

signal walk_finished
signal tile_stepped(old_tile: Vector2i, new_tile: Vector2i)

const WALK_SPEED: float = 0.15

var _is_walking: bool = false
var _active_tween: Tween = null


func is_walking() -> bool:
	return _is_walking


func cancel() -> void:
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
		_active_tween = null
	_is_walking = false


func walk_path(tile_path: Array[Vector2i], move_cost: int) -> void:
	if _is_walking:
		return
	var unit: Unit = owner as Unit
	if unit == null:
		return
	_is_walking = true

	for i: int in range(1, tile_path.size()):
		if unit.action_points < move_cost:
			break
		var old_tile: Vector2i = unit.current_tile
		var target_tile: Vector2i = tile_path[i]
		var target_world: Vector2 = Grid.tile_to_world(target_tile)
		_active_tween = unit.create_tween()
		_active_tween.tween_property(unit, "position", target_world, WALK_SPEED)
		await _active_tween.finished
		_active_tween = null
		unit.current_tile = target_tile
		unit.spend_ap(move_cost)
		tile_stepped.emit(old_tile, target_tile)

	_is_walking = false
	walk_finished.emit()
