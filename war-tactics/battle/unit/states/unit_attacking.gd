class_name UnitAttacking
extends State

signal attack_resolved(target: Unit, hit: bool, damage_dealt: int)

var _unit: Unit = null


func enter(msg: Dictionary = {}) -> void:
	_unit = owner as Unit
	var target: Unit = msg.get("target", null) as Unit
	var weapon: WeaponData = msg.get("weapon", null) as WeaponData
	var minigame_layer: Node = msg.get("minigame_layer", null)
	var elev_diff: int = msg.get("elev_diff", 0) as int
	var in_cover: bool = msg.get("in_cover", false) as bool
	if target == null or weapon == null or minigame_layer == null:
		state_machine.transition_to(Unit.STATE_IDLE)
		return
	_run_attack(target, weapon, minigame_layer, elev_diff, in_cover)


func _run_attack(target: Unit, weapon: WeaponData, minigame_layer: Node, elev_diff: int, in_cover: bool) -> void:
	minigame_layer.open(weapon.minigame_type)
	var hit: bool = await minigame_layer.minigame_resolved
	var damage_dealt: int = 0

	if hit and target.is_alive():
		damage_dealt = CombatCalc.compute_damage(weapon.damage, elev_diff, in_cover)
		target.health.take_damage(damage_dealt)

	_unit.spend_ap(weapon.ap_cost)
	attack_resolved.emit(target, hit, damage_dealt)
	state_machine.transition_to(Unit.STATE_IDLE)
