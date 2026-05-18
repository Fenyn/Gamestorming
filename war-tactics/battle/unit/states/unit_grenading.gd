class_name UnitGrenading
extends State

signal grenade_resolved(aoe_tiles: Array[Vector2i], damage: int)

var _unit: Unit = null


func enter(msg: Dictionary = {}) -> void:
	_unit = owner as Unit
	var target_tile: Vector2i = msg.get("target_tile", Vector2i.ZERO) as Vector2i
	var weapon: WeaponData = msg.get("weapon", null) as WeaponData
	if weapon == null:
		state_machine.transition_to(Unit.STATE_IDLE)
		return
	_resolve_grenade(target_tile, weapon)


func _resolve_grenade(target_tile: Vector2i, weapon: WeaponData) -> void:
	_unit.spend_ap(weapon.ap_cost)
	var aoe_tiles: Array[Vector2i] = Grid.tiles_in_diamond_aoe(target_tile, weapon.aoe_radius)
	var atk_elev: int = Grid.get_elevation(_unit.current_tile)
	var avg_def_elev: int = Grid.get_elevation(target_tile)
	var elev_diff: int = atk_elev - avg_def_elev
	var final_damage: int = CombatCalc.compute_damage(weapon.damage, elev_diff, false)

	var timer: SceneTreeTimer = get_tree().create_timer(0.3)
	await timer.timeout

	grenade_resolved.emit(aoe_tiles, final_damage)
	state_machine.transition_to(Unit.STATE_IDLE)
