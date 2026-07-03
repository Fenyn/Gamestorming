class_name FighterDeathblowState
extends BaseState

const ATTACKER_DURATION: float = 0.8
const DEFENDER_DURATION: float = 1.0

var _fighter: Fighter = null
var _timer: float = 0.0
var _is_attacker: bool = false


func enter(msg: Dictionary = {}) -> void:
	_fighter = owner as Fighter
	_is_attacker = msg.get("is_attacker", false) as bool

	if _is_attacker:
		_timer = ATTACKER_DURATION
	else:
		_timer = DEFENDER_DURATION
		var damage: int = int(_fighter.stats.deathblow_damage_percent * _fighter.stats.max_hp)
		_fighter.combat_resource.take_hp_damage(damage)
		_fighter.combat_resource.reset_posture()
		EventBus.deathblow_executed.emit(
			msg.get("attacker", null),
			_fighter,
			damage,
		)


func physics_update(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		if _is_attacker:
			state_machine.transition_to(&"Idle")
		else:
			if _fighter.combat_resource.current_hp <= 0:
				state_machine.transition_to(&"Dead")
			else:
				state_machine.transition_to(&"Idle")
		return

	_fighter.velocity = Vector3.ZERO
	_fighter.velocity.y -= 18.0 * delta
	_fighter.move_and_slide()
