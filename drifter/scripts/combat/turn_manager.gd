class_name TurnManager
extends Node

enum Phase { IDLE, ROLLING, PLAYER_ACTION, CREATURE_TURN, COMBAT_OVER }

signal phase_changed(new_phase: Phase)

var phase: Phase = Phase.IDLE
var rerolls_remaining: int = 0
var turn_number: int = 0

var _creature_data: CreatureData
var _creature_hp: int = 0
var _creature_shield: int = 0
var _creature_intent_index: int = 0
var _drifter_shield: int = 0

var _status_effects_drifter: Array[StatusEffect] = []
var _status_effects_creature: Array[StatusEffect] = []

var _free_reroll_used: bool = false
var _has_free_reroll: bool = false

var _kinetic_pips_this_turn: int = 0
var _resonance_combo_this_turn: int = 0
var _modules_fired_this_turn: int = 0


func start_combat(creature: CreatureData) -> void:
	_creature_data = creature
	_creature_hp = creature.max_hp
	_creature_shield = 0
	_creature_intent_index = 0
	turn_number = 0
	_status_effects_drifter.clear()
	_status_effects_creature.clear()
	_has_free_reroll = _has_implant_effect(ImplantData.Effect.FREE_REROLL)
	EventBus.creature_hp_changed.emit(0, _creature_hp, _creature_data.max_hp)
	EventBus.creature_shield_changed.emit(0)
	EventBus.drifter_hp_changed.emit(RunState.drifter_hp, RunState.drifter_max_hp)
	_reveal_intent()
	start_player_turn()


func start_player_turn() -> void:
	turn_number += 1
	_drifter_shield = 0
	EventBus.drifter_shield_changed.emit(0)
	rerolls_remaining = RunState.rerolls_per_turn
	_free_reroll_used = false
	_kinetic_pips_this_turn = 0
	_resonance_combo_this_turn = 0
	_modules_fired_this_turn = 0

	_tick_status_effects(_status_effects_drifter, "drifter")
	_process_turn_start_implants()

	EventBus.player_turn_started.emit()
	_set_phase(Phase.ROLLING)


func on_all_dice_settled() -> void:
	if phase == Phase.ROLLING:
		_set_phase(Phase.PLAYER_ACTION)


func can_reroll() -> bool:
	if phase != Phase.PLAYER_ACTION:
		return false
	if _has_free_reroll and not _free_reroll_used:
		return true
	return rerolls_remaining > 0


func request_reroll() -> bool:
	if phase != Phase.PLAYER_ACTION:
		return false
	if _has_free_reroll and not _free_reroll_used:
		_free_reroll_used = true
		EventBus.implant_triggered.emit("auto_loader", "Free reroll!")
		EventBus.reroll_used.emit(rerolls_remaining)
		_set_phase(Phase.ROLLING)
		return true
	if rerolls_remaining <= 0:
		return false
	rerolls_remaining -= 1
	EventBus.reroll_used.emit(rerolls_remaining)
	_set_phase(Phase.ROLLING)
	return true


func end_player_turn() -> void:
	if phase != Phase.PLAYER_ACTION:
		return
	_set_phase(Phase.CREATURE_TURN)
	EventBus.player_turn_ended.emit()


func resolve_creature_turn() -> void:
	var intent: IntentData = _get_current_intent()
	if not intent:
		_advance_intent()
		_post_creature_turn()
		return

	match intent.type:
		IntentData.IntentType.ATTACK:
			var damage: int = _apply_creature_strength(intent.value)
			damage = _apply_drifter_vulnerable(damage)
			damage = _apply_drifter_weak_incoming(damage)
			var after_shield: int = _absorb_shield_drifter(damage)
			RunState.take_damage(after_shield)
		IntentData.IntentType.DEFEND:
			_creature_shield += intent.value
			EventBus.creature_shield_changed.emit(_creature_shield)
		IntentData.IntentType.BUFF:
			var buff := StatusEffect.new()
			buff.type = StatusEffect.Type.STRENGTH
			buff.stacks = intent.value
			buff.duration_turns = 3
			_status_effects_creature.append(buff)
			EventBus.status_applied.emit("creature", buff.type, buff.stacks)
		IntentData.IntentType.DEBUFF:
			var debuff := StatusEffect.new()
			debuff.type = StatusEffect.Type.WEAK
			debuff.stacks = intent.value
			debuff.duration_turns = 2
			_status_effects_drifter.append(debuff)
			EventBus.status_applied.emit("drifter", debuff.type, debuff.stacks)
		IntentData.IntentType.SPECIAL_SUMMON:
			var summon_damage: int = intent.value
			var after_shield: int = _absorb_shield_drifter(summon_damage)
			RunState.take_damage(after_shield)
		IntentData.IntentType.SPECIAL_SUSTAINED_FIRE:
			var damage: int = intent.value * 3
			var after_shield: int = _absorb_shield_drifter(damage)
			RunState.take_damage(after_shield)
		IntentData.IntentType.SPECIAL_MAGNETIC_PULSE:
			EventBus.magnetic_pulse_eject.emit()

	EventBus.creature_turn_started.emit()
	_advance_intent()
	_post_creature_turn()


func _post_creature_turn() -> void:
	_tick_status_effects(_status_effects_creature, "creature")

	if RunState.drifter_hp <= 0:
		_set_phase(Phase.COMBAT_OVER)
		EventBus.combat_lost.emit()
		return

	_reveal_intent()
	EventBus.creature_turn_ended.emit()
	start_player_turn()


func apply_module_effect(effect_type: int, value: int) -> void:
	match effect_type:
		ModuleData.EffectType.DAMAGE:
			var bonus: int = _get_implant_bonus_damage()
			var damage: int = _apply_drifter_strength(value + bonus)
			damage = _apply_creature_vulnerable(damage)
			damage = _apply_drifter_weak_outgoing(damage)
			var after_shield: int = _absorb_shield_creature(damage)
			_creature_hp = maxi(_creature_hp - after_shield, 0)
			EventBus.creature_hp_changed.emit(0, _creature_hp, _creature_data.max_hp)
			if _creature_hp <= 0:
				_process_on_kill_implants()
				_set_phase(Phase.COMBAT_OVER)
				EventBus.combat_won.emit()
		ModuleData.EffectType.SHIELD:
			_drifter_shield += value
			EventBus.drifter_shield_changed.emit(_drifter_shield)
		ModuleData.EffectType.HEAL:
			RunState.heal(value)
		ModuleData.EffectType.DEBUFF_WEAK:
			var debuff := StatusEffect.new()
			debuff.type = StatusEffect.Type.WEAK
			debuff.stacks = value
			debuff.duration_turns = 2
			_status_effects_creature.append(debuff)
			EventBus.status_applied.emit("creature", debuff.type, debuff.stacks)
		ModuleData.EffectType.DEBUFF_VULNERABLE:
			var debuff := StatusEffect.new()
			debuff.type = StatusEffect.Type.VULNERABLE
			debuff.stacks = value
			debuff.duration_turns = 2
			_status_effects_creature.append(debuff)
			EventBus.status_applied.emit("creature", debuff.type, debuff.stacks)
		ModuleData.EffectType.BUFF_STRENGTH:
			var buff := StatusEffect.new()
			buff.type = StatusEffect.Type.STRENGTH
			buff.stacks = value
			buff.duration_turns = 3
			_status_effects_drifter.append(buff)
			EventBus.status_applied.emit("drifter", buff.type, buff.stacks)

	_process_on_fire_implants(effect_type)


func _get_current_intent() -> IntentData:
	if not _creature_data or _creature_data.intent_pattern.is_empty():
		return null
	return _creature_data.intent_pattern[_creature_intent_index]


func _advance_intent() -> void:
	if _creature_data and not _creature_data.intent_pattern.is_empty():
		_creature_intent_index = (_creature_intent_index + 1) % _creature_data.intent_pattern.size()


func _reveal_intent() -> void:
	var intent: IntentData = _get_current_intent()
	if intent:
		EventBus.creature_intent_revealed.emit(intent)


func _set_phase(new_phase: Phase) -> void:
	phase = new_phase
	phase_changed.emit(new_phase)


func _absorb_shield_drifter(damage: int) -> int:
	var absorbed: int = mini(damage, _drifter_shield)
	_drifter_shield -= absorbed
	EventBus.drifter_shield_changed.emit(_drifter_shield)
	return damage - absorbed


func _absorb_shield_creature(damage: int) -> int:
	var absorbed: int = mini(damage, _creature_shield)
	_creature_shield -= absorbed
	if absorbed > 0:
		EventBus.creature_shield_changed.emit(_creature_shield)
	return damage - absorbed


func _has_status(effects: Array[StatusEffect], type: StatusEffect.Type) -> int:
	var total: int = 0
	for e: StatusEffect in effects:
		if e.type == type:
			total += e.stacks
	return total


func _apply_drifter_strength(value: int) -> int:
	return value + _has_status(_status_effects_drifter, StatusEffect.Type.STRENGTH)


func _apply_creature_strength(value: int) -> int:
	return value + _has_status(_status_effects_creature, StatusEffect.Type.STRENGTH)


func _apply_drifter_weak_outgoing(value: int) -> int:
	if _has_status(_status_effects_drifter, StatusEffect.Type.WEAK) > 0:
		return value / 2
	return value


func _apply_drifter_weak_incoming(value: int) -> int:
	if _has_status(_status_effects_creature, StatusEffect.Type.WEAK) > 0:
		return value / 2
	return value


func _apply_creature_vulnerable(value: int) -> int:
	if _has_status(_status_effects_creature, StatusEffect.Type.VULNERABLE) > 0:
		return int(value * 1.5)
	return value


func _apply_drifter_vulnerable(value: int) -> int:
	if _has_status(_status_effects_drifter, StatusEffect.Type.VULNERABLE) > 0:
		return int(value * 1.5)
	return value


func _tick_status_effects(effects: Array[StatusEffect], target: String) -> void:
	var i: int = effects.size() - 1
	while i >= 0:
		if effects[i].tick():
			EventBus.status_expired.emit(target, effects[i].type)
			effects.remove_at(i)
		i -= 1


func _has_implant_effect(effect: ImplantData.Effect) -> bool:
	for implant: ImplantData in RunState.implants:
		if implant.effect == effect:
			return true
	return false


func _get_implant_bonus_damage() -> int:
	var total: int = 0
	for implant: ImplantData in RunState.implants:
		if implant.trigger == ImplantData.Trigger.ON_MODULE_FIRE and implant.effect == ImplantData.Effect.BONUS_DAMAGE:
			total += implant.value
			EventBus.implant_triggered.emit(implant.id, "+" + str(implant.value) + " bonus damage")
	return total


func _process_on_fire_implants(effect_type: int) -> void:
	for implant: ImplantData in RunState.implants:
		if implant.trigger != ImplantData.Trigger.ON_MODULE_FIRE:
			continue
		match implant.effect:
			ImplantData.Effect.HEAL_ON_FIRE:
				RunState.heal(implant.value)
				EventBus.implant_triggered.emit(implant.id, "+" + str(implant.value) + " HP")
			ImplantData.Effect.SHIELD_ON_FIRE:
				_drifter_shield += implant.value
				EventBus.drifter_shield_changed.emit(_drifter_shield)
				EventBus.implant_triggered.emit(implant.id, "+" + str(implant.value) + " shield")


func _process_turn_start_implants() -> void:
	for implant: ImplantData in RunState.implants:
		if implant.trigger != ImplantData.Trigger.ON_TURN_START:
			continue
		match implant.effect:
			ImplantData.Effect.FREE_REROLL:
				pass


func _process_on_kill_implants() -> void:
	for implant: ImplantData in RunState.implants:
		if implant.trigger != ImplantData.Trigger.ON_KILL:
			continue
		match implant.effect:
			ImplantData.Effect.HEAL_ON_FIRE:
				RunState.heal(implant.value)
				EventBus.implant_triggered.emit(implant.id, "+" + str(implant.value) + " HP on kill")


func has_free_reroll_available() -> bool:
	return _has_free_reroll and not _free_reroll_used


func get_drifter_statuses() -> Array[StatusEffect]:
	return _status_effects_drifter


func get_creature_statuses() -> Array[StatusEffect]:
	return _status_effects_creature


func get_creature_shield() -> int:
	return _creature_shield
