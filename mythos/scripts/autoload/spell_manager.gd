extends Node

var spell_tracks: Array = [[], []]

func reset() -> void:
	spell_tracks = [[], []]

func cast_spell(player_index: int, spell_data: SpellData, target_lane: int) -> void:
	var instance: SpellInstance = SpellInstance.new()
	instance.data = spell_data
	instance.current_position = spell_data.start_position
	instance.target_lane = target_lane
	instance.owner_index = player_index
	spell_tracks[player_index].append(instance)
	EventBus.spell_cast.emit(player_index, spell_data, target_lane)

func advance_spells(player_index: int) -> void:
	var track: Array = spell_tracks[player_index]
	var resolved: Array[SpellInstance] = []

	for spell: SpellInstance in track:
		spell.advance()
		EventBus.spell_advanced.emit(player_index, spell.current_position)
		if spell.is_resolved():
			resolved.append(spell)

	for spell: SpellInstance in resolved:
		_resolve_spell(spell)
		track.erase(spell)

func get_track(player_index: int) -> Array:
	return spell_tracks[player_index]

func _resolve_spell(spell: SpellInstance) -> void:
	var owner: int = spell.owner_index
	var player: PlayerState = GameState.get_player(owner)

	match spell.data.id:
		"grand_melee":
			_resolve_grand_melee(player)
		"eirs_mending":
			_resolve_eirs_mending(player)
		"hlins_bulwark":
			_resolve_hlins_bulwark(player)
		"blood_fury":
			_resolve_blood_fury(player, spell.target_lane)
		"armor_of_retribution":
			_resolve_armor_of_retribution(player, spell.target_lane)
		"lightning_storm":
			_resolve_lightning_storm()
		"barrel_of_mead":
			_resolve_barrel_of_mead(player, owner)

	EventBus.spell_resolved.emit(owner, spell.data)
	player.graveyard.append(spell.data)

func _resolve_grand_melee(player: PlayerState) -> void:
	for lane: int in range(5):
		var unit: UnitInstance = player.get_lane_unit(lane)
		if unit == null:
			continue
		if unit.current_health < unit.data.health:
			unit.current_attack += 3

func _resolve_eirs_mending(player: PlayerState) -> void:
	for lane: int in range(5):
		var unit: UnitInstance = player.get_lane_unit(lane)
		if unit == null:
			continue
		if unit.current_health < unit.data.health:
			unit.current_health = mini(unit.current_health + 2, unit.data.health)

func _resolve_hlins_bulwark(player: PlayerState) -> void:
	for lane: int in range(5):
		var unit: UnitInstance = player.get_lane_unit(lane)
		if unit == null:
			continue
		if unit.current_health < unit.data.health:
			unit.bonus_armor += 3

func _resolve_blood_fury(player: PlayerState, target_lane: int) -> void:
	var unit: UnitInstance = player.get_lane_unit(target_lane)
	if unit == null:
		return
	unit.current_attack += 5
	unit.current_health += 5

func _resolve_armor_of_retribution(player: PlayerState, target_lane: int) -> void:
	var unit: UnitInstance = player.get_lane_unit(target_lane)
	if unit == null:
		return
	unit.has_reflect = true

func _resolve_lightning_storm() -> void:
	for p: int in range(2):
		var player: PlayerState = GameState.get_player(p)
		var dead_units: Array[int] = []
		for lane: int in range(5):
			var unit: UnitInstance = player.get_lane_unit(lane)
			if unit == null:
				continue
			unit.take_damage(1)
			EventBus.unit_damaged.emit(lane, p, 1)
			if unit.is_dead():
				dead_units.append(lane)
		for lane: int in dead_units:
			var unit: UnitInstance = player.get_lane_unit(lane)
			if unit != null:
				player.set_lane_unit(lane, null)
				player.graveyard.append(unit.data)
				EventBus.unit_destroyed.emit(lane, p, unit.data)

func _resolve_barrel_of_mead(player: PlayerState, owner_index: int) -> void:
	var units: Array[UnitInstance] = []
	var occupied_lanes: Array[int] = []
	for lane: int in range(5):
		var unit: UnitInstance = player.get_lane_unit(lane)
		if unit != null:
			units.append(unit)
			occupied_lanes.append(lane)
			player.set_lane_unit(lane, null)
	if units.size() <= 1:
		for i: int in range(units.size()):
			player.set_lane_unit(occupied_lanes[i], units[i])
		return
	for i: int in range(units.size() - 1, 0, -1):
		var j: int = GameState.rng.randi_range(0, i)
		var temp: UnitInstance = units[i]
		units[i] = units[j]
		units[j] = temp
	for i: int in range(units.size()):
		units[i].lane_index = occupied_lanes[i]
		player.set_lane_unit(occupied_lanes[i], units[i])
		EventBus.unit_moved.emit(owner_index, -1, occupied_lanes[i])
