class_name CombatScreen
extends Control

const DAMAGE_NUMBER_SCENE: String = "res://scenes/combat/damage_number.tscn"

@onready var _dice_tray: DiceTray = %DiceTray
@onready var _loadout_grid: LoadoutGridDisplay = %LoadoutGrid
@onready var _roll_button: Button = %RollButton
@onready var _end_turn_button: Button = %EndTurnButton
@onready var _reroll_label: Label = %RerollLabel
@onready var _drifter_hp_bar: HPBar = %DrifterHPBar
@onready var _creature_hp_bar: HPBar = %CreatureHPBar
@onready var _shield_label: Label = %ShieldLabel
@onready var _creature_name_label: Label = %CreatureNameLabel
@onready var _intent_label: Label = %IntentLabel
@onready var _turn_manager: TurnManager = %TurnManager
@onready var _drifter_display: DrifterDisplay = %DrifterDisplay
@onready var _creature_display: CreatureDisplay = %CreatureDisplay
@onready var _creature_shield_label: Label = %CreatureShieldLabel
@onready var _drifter_status_label: Label = %DrifterStatusLabel
@onready var _creature_status_label: Label = %CreatureStatusLabel
@onready var _implant_panel: HBoxContainer = %ImplantPanel
@onready var _implant_flash_label: Label = %ImplantFlashLabel
@onready var _result_overlay: Control = %ResultOverlay
@onready var _result_label: Label = %ResultLabel
@onready var _result_button: Button = %ResultButton
@onready var _phase_label: Label = %PhaseLabel

var _creature_data: CreatureData
var _implant_flash_tween: Tween
var _phase_tween: Tween
var _current_intent: IntentData
var _combat_started: bool = false
var _prev_drifter_hp: int = 0
var _prev_creature_hp: int = 0
var _prev_drifter_shield: int = 0
var _prev_creature_shield: int = 0
var _damage_number_scene: PackedScene


func _ready() -> void:
	theme = ThemeBuilder.build()
	_result_overlay.visible = false
	_phase_label.text = ""
	_phase_label.modulate.a = 0.0
	_damage_number_scene = load(DAMAGE_NUMBER_SCENE) as PackedScene

	_roll_button.pressed.connect(_on_roll_pressed)
	_end_turn_button.pressed.connect(_on_end_turn_pressed)
	_result_button.pressed.connect(_on_result_button_pressed)

	_turn_manager.phase_changed.connect(_on_phase_changed)
	_connect_event_bus()
	_setup_visuals()


func _process(_delta: float) -> void:
	if not _combat_started:
		_combat_started = true
		_begin_combat()
		set_process(false)


func _exit_tree() -> void:
	_disconnect_event_bus()


func _connect_event_bus() -> void:
	EventBus.all_dice_settled.connect(_on_all_settled)
	EventBus.module_fired.connect(_on_module_fired)
	EventBus.drifter_hp_changed.connect(_on_drifter_hp_changed)
	EventBus.drifter_shield_changed.connect(_on_drifter_shield_changed)
	EventBus.creature_hp_changed.connect(_on_creature_hp_changed)
	EventBus.creature_shield_changed.connect(_on_creature_shield_changed)
	EventBus.creature_intent_revealed.connect(_on_intent_revealed)
	EventBus.reroll_used.connect(_on_reroll_used)
	EventBus.status_applied.connect(_on_status_changed)
	EventBus.status_expired.connect(_on_status_expired)
	EventBus.implant_triggered.connect(_on_implant_triggered)
	EventBus.player_turn_started.connect(_on_player_turn_started)
	EventBus.magnetic_pulse_eject.connect(_on_magnetic_pulse_eject)
	EventBus.combat_won.connect(_on_combat_won)
	EventBus.combat_lost.connect(_on_combat_lost)


func _disconnect_event_bus() -> void:
	EventBus.all_dice_settled.disconnect(_on_all_settled)
	EventBus.module_fired.disconnect(_on_module_fired)
	EventBus.drifter_hp_changed.disconnect(_on_drifter_hp_changed)
	EventBus.drifter_shield_changed.disconnect(_on_drifter_shield_changed)
	EventBus.creature_hp_changed.disconnect(_on_creature_hp_changed)
	EventBus.creature_shield_changed.disconnect(_on_creature_shield_changed)
	EventBus.creature_intent_revealed.disconnect(_on_intent_revealed)
	EventBus.reroll_used.disconnect(_on_reroll_used)
	EventBus.status_applied.disconnect(_on_status_changed)
	EventBus.status_expired.disconnect(_on_status_expired)
	EventBus.implant_triggered.disconnect(_on_implant_triggered)
	EventBus.player_turn_started.disconnect(_on_player_turn_started)
	EventBus.magnetic_pulse_eject.disconnect(_on_magnetic_pulse_eject)
	EventBus.combat_won.disconnect(_on_combat_won)
	EventBus.combat_lost.disconnect(_on_combat_lost)


func _setup_visuals() -> void:
	_creature_data = RunState.current_creature
	if not _creature_data:
		_creature_data = load("res://resources/creatures/lurker.tres") as CreatureData

	_creature_name_label.text = _creature_data.display_name
	_creature_display.setup(_creature_data)
	_creature_display.build_anims()

	_loadout_grid.build_from_grid(RunState.loadout_grid)

	_drifter_hp_bar.setup("Drifter", RunState.drifter_max_hp, ThemeBuilder.HP_TEAL)
	_creature_hp_bar.setup(_creature_data.display_name, _creature_data.max_hp, ThemeBuilder.HP_RED)
	_prev_drifter_hp = RunState.drifter_hp
	_prev_creature_hp = _creature_data.max_hp

	_shield_label.text = ""
	_creature_shield_label.text = ""
	_implant_flash_label.text = ""
	_implant_flash_label.modulate.a = 0.0
	_setup_implant_display()


func _begin_combat() -> void:
	RunState.dice_bag.reshuffle_all()
	_turn_manager.start_combat(_creature_data)


func _on_roll_pressed() -> void:
	if _turn_manager.phase == TurnManager.Phase.PLAYER_ACTION:
		_turn_manager.request_reroll()


func _on_end_turn_pressed() -> void:
	_turn_manager.end_player_turn()
	_resolve_creature_turn()


func _resolve_creature_turn() -> void:
	if _current_intent and _current_intent.type == IntentData.IntentType.SPECIAL_MAGNETIC_PULSE:
		_creature_display.play_punch()
	else:
		_creature_display.play_attack()
	var tween: Tween = create_tween()
	tween.tween_callback(_do_resolve_creature).set_delay(0.4)


func _do_resolve_creature() -> void:
	var hp_before: int = RunState.drifter_hp
	_turn_manager.resolve_creature_turn()
	if RunState.drifter_hp > 0 and RunState.drifter_hp < hp_before:
		_drifter_display.play_hit()


func _on_phase_changed(new_phase: TurnManager.Phase) -> void:
	match new_phase:
		TurnManager.Phase.ROLLING:
			_roll_button.disabled = true
			_end_turn_button.disabled = true
			_reroll_label.text = "Rolling..."
			_dice_tray.roll_all_free()
		TurnManager.Phase.PLAYER_ACTION:
			_roll_button.disabled = not _turn_manager.can_reroll()
			_end_turn_button.disabled = false
			_update_reroll_label()
			_flash_phase("YOUR TURN", ThemeBuilder.ACCENT_GLOW)
		TurnManager.Phase.CREATURE_TURN:
			_roll_button.disabled = true
			_end_turn_button.disabled = true
			_reroll_label.text = "Enemy turn..."
			_flash_phase("ENEMY TURN", ThemeBuilder.TEXT_DAMAGE)
		TurnManager.Phase.COMBAT_OVER:
			_roll_button.disabled = true
			_end_turn_button.disabled = true
			_reroll_label.text = ""


func _on_player_turn_started() -> void:
	_dice_tray.draw_from_bag()
	for card: ModuleCard in _loadout_grid.get_cards():
		card.reset_turn()


func _on_all_settled(_values: Array[int]) -> void:
	_turn_manager.on_all_dice_settled()


func _on_module_fired(module_index: int, effect_type: int, total_value: int, _pip_total: int) -> void:
	var cards: Array[ModuleCard] = _loadout_grid.get_cards()
	if module_index < cards.size():
		var card: ModuleCard = cards[module_index]
		_drifter_display.play_attack(card.module_data.attack_anim)
		_dice_tray.discard_fired_dice(card.get_last_fired_cell_indices())
	if effect_type == ModuleData.EffectType.DAMAGE:
		_creature_display.play_hit()
	_turn_manager.apply_module_effect(effect_type, total_value)
	_update_reroll_label()


func _on_drifter_hp_changed(current: int, _max_val: int) -> void:
	var delta: int = current - _prev_drifter_hp
	_drifter_hp_bar.set_value(current)
	if delta < 0:
		_spawn_damage_number(_drifter_display, Vector2(200, 80), absi(delta), DamageNumber.Type.DAMAGE)
		_drifter_display.shake()
	elif delta > 0:
		_spawn_damage_number(_drifter_display, Vector2(200, 80), delta, DamageNumber.Type.HEAL)
	_prev_drifter_hp = current


func _on_drifter_shield_changed(current: int) -> void:
	_drifter_hp_bar.set_shield(current)
	var delta: int = current - _prev_drifter_shield
	if delta > 0:
		_spawn_damage_number(_drifter_display, Vector2(200, 80), delta, DamageNumber.Type.SHIELD)
	_prev_drifter_shield = current
	_shield_label.text = ""


func _on_creature_hp_changed(_idx: int, current: int, _max_val: int) -> void:
	var delta: int = current - _prev_creature_hp
	_creature_hp_bar.set_value(current)
	if delta < 0:
		_spawn_damage_number(_creature_display, Vector2(200, 40), absi(delta), DamageNumber.Type.DAMAGE)
		_creature_display.shake()
	_prev_creature_hp = current


func _on_creature_shield_changed(current: int) -> void:
	_creature_hp_bar.set_shield(current)
	var delta: int = current - _prev_creature_shield
	if delta > 0:
		_spawn_damage_number(_creature_display, Vector2(200, 40), delta, DamageNumber.Type.SHIELD)
	_prev_creature_shield = current
	_creature_shield_label.text = ""


func _on_status_changed(_target: String, _effect_type: int, _stacks: int) -> void:
	_refresh_status_labels()


func _on_status_expired(_target: String, _effect_type: int) -> void:
	_refresh_status_labels()


func _on_implant_triggered(_implant_id: String, effect_text: String) -> void:
	_implant_flash_label.text = effect_text
	if _implant_flash_tween:
		_implant_flash_tween.kill()
	_implant_flash_tween = create_tween()
	_implant_flash_label.modulate.a = 1.0
	_implant_flash_tween.tween_property(_implant_flash_label, "modulate:a", 0.0, 1.2).set_delay(0.5)


func _on_magnetic_pulse_eject() -> void:
	var filled_sockets: Array[Dictionary] = []
	for card: ModuleCard in _loadout_grid.get_cards():
		if card.is_exhausted():
			continue
		for i: int in card.get_socket_count():
			var slot: SocketSlot = card.get_socket(i)
			if slot and slot.is_filled():
				filled_sockets.append({"card": card, "socket": slot})

	if filled_sockets.is_empty():
		_drifter_status_label.text = "Magnetic Pulse — no dice to eject"
		return

	var target: Dictionary = filled_sockets[randi() % filled_sockets.size()]
	var card: ModuleCard = target["card"] as ModuleCard
	var slot: SocketSlot = target["socket"] as SocketSlot
	var ejected_value: int = slot.filled_value
	var ejected: Dictionary = slot.eject()
	var cell_index: int = ejected["cell_index"] as int
	_dice_tray.unsocket_to_discard(cell_index)
	_drifter_status_label.text = "Magnetic Pulse ejected " + str(ejected_value) + " from " + card.module_data.display_name + "!"


func _on_intent_revealed(intent: IntentData) -> void:
	_current_intent = intent
	_intent_label.text = _format_intent(intent)
	_intent_label.add_theme_color_override("font_color", _intent_color(intent))
	_pulse_intent()


func _on_reroll_used(_remaining: int) -> void:
	_update_reroll_label()
	_roll_button.disabled = not _turn_manager.can_reroll()


func _on_combat_won() -> void:
	_creature_display.play_death()
	_result_label.text = "Victory!"
	_result_button.text = "Continue"
	_result_overlay.visible = true


func _on_combat_lost() -> void:
	_drifter_display.play_death()
	_result_label.text = "Expedition Failed"
	_result_button.text = "Return to Camp"
	_result_overlay.visible = true


func _on_result_button_pressed() -> void:
	if RunState.drifter_hp > 0:
		EventBus.screen_transition_requested.emit("salvage")
	else:
		GameState.record_expedition()
		GameState.add_data_logs(5)
		EventBus.screen_transition_requested.emit("camp")


func _update_reroll_label() -> void:
	var text: String = "Turn " + str(_turn_manager.turn_number) + " | Rerolls: " + str(_turn_manager.rerolls_remaining)
	if _turn_manager.has_free_reroll_available():
		text += " +1"
	text += " | Bag: " + str(_dice_tray.get_bag_remaining()) + " / Discard: " + str(_dice_tray.get_discard_count())
	_reroll_label.text = text


func _refresh_status_labels() -> void:
	_drifter_status_label.text = _format_statuses(_turn_manager.get_drifter_statuses())
	_creature_status_label.text = _format_statuses(_turn_manager.get_creature_statuses())


func _format_statuses(effects: Array[StatusEffect]) -> String:
	if effects.is_empty():
		return ""
	var parts: Array[String] = []
	for e: StatusEffect in effects:
		var label: String = ""
		match e.type:
			StatusEffect.Type.WEAK:
				label = "Weak"
			StatusEffect.Type.VULNERABLE:
				label = "Vuln"
			StatusEffect.Type.STRENGTH:
				label = "Str"
			StatusEffect.Type.REGEN:
				label = "Regen"
		parts.append(label + " x" + str(e.stacks) + " (" + str(e.duration_turns) + "t)")
	return " | ".join(parts)


func _setup_implant_display() -> void:
	for child: Node in _implant_panel.get_children():
		if child != _implant_flash_label:
			child.queue_free()
	for implant: ImplantData in RunState.implants:
		var label := Label.new()
		label.text = "[" + implant.display_name + "]"
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_color", ThemeBuilder.ACCENT_GLOW)
		label.tooltip_text = implant.description
		_implant_panel.add_child(label)
		_implant_panel.move_child(label, 0)


func _format_intent(intent: IntentData) -> String:
	match intent.type:
		IntentData.IntentType.ATTACK:
			return "Intent: Attack " + str(intent.value)
		IntentData.IntentType.DEFEND:
			return "Intent: Defend +" + str(intent.value)
		IntentData.IntentType.BUFF:
			return "Intent: Buff"
		IntentData.IntentType.DEBUFF:
			return "Intent: Debuff"
		IntentData.IntentType.SPECIAL_SUMMON:
			return "Intent: Summon (" + str(intent.value) + ")"
		IntentData.IntentType.SPECIAL_SUSTAINED_FIRE:
			return "Intent: Sustained Fire x" + str(intent.value)
		IntentData.IntentType.SPECIAL_MAGNETIC_PULSE:
			return "Intent: Magnetic Pulse"
	return "Intent: ?"


func _intent_color(intent: IntentData) -> Color:
	match intent.type:
		IntentData.IntentType.ATTACK:
			return ThemeBuilder.TEXT_DAMAGE
		IntentData.IntentType.DEFEND:
			return ThemeBuilder.TEXT_SHIELD
		IntentData.IntentType.BUFF:
			return Color(0.9, 0.7, 0.3)
		IntentData.IntentType.DEBUFF:
			return Color(0.7, 0.4, 0.8)
		IntentData.IntentType.SPECIAL_SUMMON:
			return Color(0.8, 0.6, 0.3)
		IntentData.IntentType.SPECIAL_SUSTAINED_FIRE:
			return ThemeBuilder.TEXT_DAMAGE
		IntentData.IntentType.SPECIAL_MAGNETIC_PULSE:
			return Color(0.5, 0.7, 0.9)
	return ThemeBuilder.TEXT_PRIMARY


func _pulse_intent() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_intent_label, "modulate", Color(1.5, 1.5, 1.5), 0.1)
	tween.tween_property(_intent_label, "modulate", Color.WHITE, 0.3).set_ease(Tween.EASE_OUT)


func _flash_phase(text: String, color: Color) -> void:
	if _phase_tween:
		_phase_tween.kill()
	_phase_label.text = text
	_phase_label.add_theme_color_override("font_color", color)
	_phase_label.modulate.a = 1.0
	_phase_label.scale = Vector2(1.2, 1.2)
	_phase_label.pivot_offset = _phase_label.size * 0.5

	_phase_tween = create_tween()
	_phase_tween.set_parallel(true)
	_phase_tween.tween_property(_phase_label, "scale", Vector2.ONE, 0.25) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_phase_tween.tween_property(_phase_label, "modulate:a", 0.0, 0.6).set_delay(0.8)


func _spawn_damage_number(parent: Control, pos: Vector2, value: int, type: DamageNumber.Type) -> void:
	var num: DamageNumber = _damage_number_scene.instantiate() as DamageNumber
	num.setup(value, type)
	num.position = pos + Vector2(randf_range(-20.0, 20.0), 0.0)
	parent.add_child(num)
