class_name AIBrain
extends Node

enum ActionType { MOVE, ATTACK }


func decide(unit: Unit, player_units: Array[Unit], unit_at_tile: Dictionary) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	var weapon: WeaponData = unit.attacker.weapon
	if weapon == null:
		return actions

	var nearest_player: Unit = _find_nearest_alive(unit, player_units)
	if nearest_player == null:
		return actions

	if _can_attack_from(unit.current_tile, nearest_player.current_tile, weapon):
		actions.append({"type": ActionType.ATTACK, "target": nearest_player})
		return actions

	var best_attack_tile: Vector2i = _find_attack_position(unit, nearest_player, weapon, unit_at_tile)
	if best_attack_tile != Vector2i(-999, -999):
		actions.append({"type": ActionType.MOVE, "target_tile": best_attack_tile})
		var ap_after: int = unit.action_points - _tile_distance(unit.current_tile, best_attack_tile)
		if ap_after >= weapon.ap_cost:
			actions.append({"type": ActionType.ATTACK, "target": nearest_player})
		return actions

	var advance_tile: Vector2i = _find_advance_position(unit, nearest_player, unit_at_tile)
	if advance_tile != Vector2i(-999, -999):
		actions.append({"type": ActionType.MOVE, "target_tile": advance_tile})

	return actions


func _find_nearest_alive(unit: Unit, targets: Array[Unit]) -> Unit:
	var best: Unit = null
	var best_dist: int = 9999
	for target: Unit in targets:
		if not target.is_alive():
			continue
		var dist: int = _chebyshev(unit.current_tile, target.current_tile)
		if dist < best_dist:
			best_dist = dist
			best = target
	return best


func _can_attack_from(from: Vector2i, target_tile: Vector2i, weapon: WeaponData) -> bool:
	var dist: int = _chebyshev(from, target_tile)
	return dist <= weapon.attack_range and Grid.has_line_of_sight(from, target_tile)


func _find_attack_position(unit: Unit, target: Unit, weapon: WeaponData, unit_at_tile: Dictionary) -> Vector2i:
	var move_budget: int = unit.action_points - weapon.ap_cost
	if move_budget <= 0:
		return Vector2i(-999, -999)
	Grid.set_tile_solid(unit.current_tile, false)
	var reachable: Array[Vector2i] = Grid.reachable_tiles(unit.current_tile, move_budget)
	Grid.set_tile_solid(unit.current_tile, true)
	var best: Vector2i = Vector2i(-999, -999)
	var best_score: int = -9999
	for tile: Vector2i in reachable:
		if unit_at_tile.has(tile):
			continue
		if not _can_attack_from(tile, target.current_tile, weapon):
			continue
		var score: int = 0
		if _has_adjacent_cover_from(tile, target.current_tile):
			score += 10
		score += Grid.get_elevation(tile)
		if score > best_score:
			best_score = score
			best = tile
	return best


func _find_advance_position(unit: Unit, target: Unit, unit_at_tile: Dictionary) -> Vector2i:
	Grid.set_tile_solid(unit.current_tile, false)
	var reachable: Array[Vector2i] = Grid.reachable_tiles(unit.current_tile, unit.action_points)
	Grid.set_tile_solid(unit.current_tile, true)
	var best: Vector2i = Vector2i(-999, -999)
	var best_dist: int = 9999
	for tile: Vector2i in reachable:
		if unit_at_tile.has(tile):
			continue
		var dist: int = _chebyshev(tile, target.current_tile)
		if dist < best_dist or (dist == best_dist and _has_adjacent_cover_from(tile, target.current_tile)):
			best_dist = dist
			best = tile
	return best


func _has_adjacent_cover_from(tile: Vector2i, threat_tile: Vector2i) -> bool:
	return Grid.defender_has_cover_from(tile, threat_tile)


func _chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


func _tile_distance(a: Vector2i, b: Vector2i) -> int:
	var path: Array[Vector2i] = Grid.path(a, b)
	if path.is_empty():
		return 9999
	return path.size() - 1
