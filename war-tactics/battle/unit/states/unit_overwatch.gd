class_name UnitOverwatch
extends State

var _unit: Unit = null
var _cone_tiles: Array[Vector2i] = []
var _watching: bool = false


func enter(msg: Dictionary = {}) -> void:
	_unit = owner as Unit
	_cone_tiles = msg.get("cone_tiles", [] as Array[Vector2i])
	var ap_cost: int = msg.get("ap_cost", 0) as int
	_unit.spend_ap(ap_cost)
	_watching = true
	_unit.overwatch_cone = _cone_tiles


func exit() -> void:
	_watching = false
	_unit.overwatch_cone = []


func is_watching() -> bool:
	return _watching


func check_tile(tile: Vector2i) -> bool:
	return _watching and _cone_tiles.has(tile)


func fire_at(target: Unit) -> Dictionary:
	if not _watching:
		return {"hit": false, "damage": 0}
	_watching = false
	var in_cover: bool = Grid.defender_has_cover_from(target.current_tile, _unit.current_tile)
	var hit: bool = CombatCalc.roll_hit(CombatCalc.OVERWATCH_HIT_CHANCE, in_cover)
	var damage: int = 0
	if hit and _unit.attacker.weapon:
		var elev_diff: int = Grid.get_elevation(_unit.current_tile) - Grid.get_elevation(target.current_tile)
		damage = CombatCalc.compute_damage(_unit.attacker.weapon.damage, elev_diff, in_cover)
		target.health.take_damage(damage)
	state_machine.transition_to(Unit.STATE_IDLE)
	return {"hit": hit, "damage": damage}
