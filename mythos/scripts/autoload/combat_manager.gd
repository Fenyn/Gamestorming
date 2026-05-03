extends Node

const ATTACK_DELAY: float = 0.35

signal battle_finished()

func resolve_battle(attacker_index: int) -> void:
	var defender_index: int = 1 - attacker_index
	_apply_building_buffs(attacker_index)
	_apply_building_buffs(defender_index)
	await _resolve_side(attacker_index, defender_index)
	await _resolve_side(defender_index, attacker_index)
	_clear_building_buffs(attacker_index)
	_clear_building_buffs(defender_index)
	EventBus.combat_resolved.emit()
	battle_finished.emit()

func _apply_building_buffs(player_index: int) -> void:
	var player: PlayerState = GameState.get_player(player_index)
	var blacksmith_count: int = 0
	var has_powder_hall: bool = false
	for i: int in range(25):
		var building: BuildingInstance = player.city_grid[i]
		if building == null:
			continue
		if building.data.id == "blacksmith":
			blacksmith_count += 1
		elif building.data.id == "powder_hall":
			has_powder_hall = true
	for lane: int in range(5):
		var unit: UnitInstance = player.get_lane_unit(lane)
		if unit == null:
			continue
		unit.bonus_attack = blacksmith_count * 3
		if has_powder_hall and unit.data.id == "dwarven_sapper":
			unit.bonus_attack += 0
			unit.bonus_health += 3

func _clear_building_buffs(player_index: int) -> void:
	var player: PlayerState = GameState.get_player(player_index)
	for lane: int in range(5):
		var unit: UnitInstance = player.get_lane_unit(lane)
		if unit == null:
			continue
		unit.bonus_attack = 0
		unit.bonus_health = 0

func _resolve_side(attacker_index: int, defender_index: int) -> void:
	for lane: int in range(5):
		if not GameState.game_active:
			return
		var had_attack: bool = await _resolve_lane(lane, attacker_index, defender_index)
		if had_attack:
			await get_tree().create_timer(ATTACK_DELAY).timeout

func _resolve_lane(lane: int, attacker_index: int, defender_index: int) -> bool:
	var attacker_player: PlayerState = GameState.get_player(attacker_index)
	var unit: UnitInstance = attacker_player.get_lane_unit(lane)
	if unit == null or unit.summoning_sickness:
		return false

	var damage: int = unit.get_effective_attack()
	if damage <= 0:
		return false

	var target: Variant = _get_target(lane, attacker_index, defender_index)
	if target == null:
		return false

	EventBus.unit_attacked.emit(lane, attacker_index)

	if target is UnitInstance:
		var target_unit: UnitInstance = target as UnitInstance
		var actual_damage: int = target_unit.take_damage(damage)
		var target_lane: int = _find_unit_lane(target_unit, defender_index)
		EventBus.unit_damaged.emit(target_lane, defender_index, actual_damage)
		_check_berserker(target_unit, actual_damage)
		if actual_damage > 0 and target_unit.has_reflect:
			var reflect_dmg: int = unit.take_damage(1)
			EventBus.unit_damaged.emit(lane, attacker_index, reflect_dmg)
			_check_berserker(unit, reflect_dmg)
			if unit.is_dead():
				_destroy_unit(lane, attacker_index, unit)
		if target_unit.is_dead():
			if _try_valkyrie_save(target_unit, defender_index):
				EventBus.unit_damaged.emit(target_lane, defender_index, 0)
			else:
				_destroy_unit(target_lane, defender_index, target_unit)
	elif target is BuildingInstance:
		var target_building: BuildingInstance = target as BuildingInstance
		var siege: int = unit.get_siege()
		var total_damage: int = damage + siege
		target_building.take_damage(total_damage)
		EventBus.building_damaged.emit(target_building.grid_pos, defender_index, total_damage)
		if target_building.is_destroyed():
			_destroy_building(target_building, defender_index)
	return true

func _check_berserker(unit: UnitInstance, damage: int) -> void:
	if damage > 0 and unit.data.id == "berserker":
		unit.current_attack += 2

func _try_valkyrie_save(dying_unit: UnitInstance, owner_index: int) -> bool:
	var player: PlayerState = GameState.get_player(owner_index)
	for lane: int in range(5):
		var unit: UnitInstance = player.get_lane_unit(lane)
		if unit == null:
			continue
		if unit.data.id == "valkyrie" and not unit.valkyrie_used:
			unit.valkyrie_used = true
			dying_unit.current_health = dying_unit.data.health
			return true
	return false

func _get_target(lane: int, _attacker_index: int, defender_index: int) -> Variant:
	var defender: PlayerState = GameState.get_player(defender_index)

	var opposing_unit: UnitInstance = defender.get_lane_unit(lane)
	if opposing_unit != null:
		return opposing_unit

	var start_row: int = 0 if defender_index == 0 else 4
	var step: int = 1 if defender_index == 0 else -1
	var col: int = mini(lane, 4)

	for i: int in range(5):
		var row: int = start_row + step * i
		var building: BuildingInstance = defender.get_grid_cell(Vector2i(col, row))
		if building != null:
			return building

	var hq: BuildingInstance = defender.get_grid_cell(Vector2i(2, 2))
	if hq != null:
		return hq

	return null

func _find_unit_lane(unit: UnitInstance, player_index: int) -> int:
	var player: PlayerState = GameState.get_player(player_index)
	for i: int in range(5):
		if player.get_lane_unit(i) == unit:
			return i
	return unit.lane_index

func _destroy_unit(lane: int, owner_index: int, unit: UnitInstance) -> void:
	var player: PlayerState = GameState.get_player(owner_index)
	player.set_lane_unit(lane, null)
	player.graveyard.append(unit.data)
	EventBus.unit_destroyed.emit(lane, owner_index, unit.data)

func _destroy_building(building: BuildingInstance, owner_index: int) -> void:
	var player: PlayerState = GameState.get_player(owner_index)
	player.set_grid_cell(building.grid_pos, null)
	EventBus.building_destroyed.emit(building.grid_pos, owner_index)
	if building.data.is_hq:
		GameState.game_active = false
		EventBus.game_won.emit(1 - owner_index)
