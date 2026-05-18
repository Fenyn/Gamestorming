class_name UnitAttacking
extends State

signal attack_resolved(target: Unit, hit: bool)

var _unit: Unit = null


func enter(msg: Dictionary = {}) -> void:
	_unit = owner as Unit
	var target: Unit = msg.get("target", null) as Unit
	var weapon: WeaponData = msg.get("weapon", null) as WeaponData
	var minigame_layer: Node = msg.get("minigame_layer", null)
	if target == null or weapon == null or minigame_layer == null:
		state_machine.transition_to("Idle")
		return
	_run_attack(target, weapon, minigame_layer)


func _run_attack(target: Unit, weapon: WeaponData, minigame_layer: Node) -> void:
	minigame_layer.open(weapon.minigame_type)
	var hit: bool = await minigame_layer.minigame_resolved

	if hit and target.is_alive():
		target.health.take_damage(weapon.damage)

	_unit.spend_ap(weapon.ap_cost)
	attack_resolved.emit(target, hit)
	state_machine.transition_to("Idle")
