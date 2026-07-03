class_name CombatHUD
extends CanvasLayer

var _player: Node = null
var _opponent: Node = null
var _feedback_timer: float = 0.0
var _hit_flash_timer: float = 0.0

@onready var player_hp_bar: ProgressBar = %PlayerHPBar
@onready var player_posture_bar: ProgressBar = %PlayerPostureBar
@onready var player_stamina_bar: ProgressBar = %PlayerStaminaBar
@onready var opponent_hp_bar: ProgressBar = %OpponentHPBar
@onready var opponent_posture_bar: ProgressBar = %OpponentPostureBar
@onready var player_stance_widget: StanceWidget = %PlayerStanceWidget
@onready var opponent_stance_widget: StanceWidget = %OpponentStanceWidget
@onready var state_label: Label = %StateLabel
@onready var feedback_label: Label = %FeedbackLabel
@onready var crosshair: Control = %Crosshair
@onready var player_hp_label: Label = %PlayerHPLabel
@onready var opponent_hp_label: Label = %OpponentHPLabel


func setup(player: Node, opponent: Node) -> void:
	_player = player
	_opponent = opponent

	EventBus.hp_changed.connect(_on_hp_changed)
	EventBus.posture_changed.connect(_on_posture_changed)
	EventBus.stamina_changed.connect(_on_stamina_changed)
	EventBus.attack_landed.connect(_on_attack_landed)
	EventBus.attack_blocked.connect(_on_attack_blocked)
	EventBus.attack_deflected.connect(_on_attack_deflected)
	EventBus.posture_broken.connect(_on_posture_broken)
	EventBus.perilous_warning.connect(_on_perilous_warning)
	EventBus.perilous_countered.connect(_on_perilous_countered)
	EventBus.exhaustion_changed.connect(_on_exhaustion_changed)

	if player_stance_widget:
		player_stance_widget.setup(player)
	if opponent_stance_widget:
		opponent_stance_widget.setup(opponent)

	_init_bars(player, opponent)


func _init_bars(player: Node, opponent: Node) -> void:
	if player and player.has_method("get_stats"):
		var stats: FighterStats = player.get_stats()
		if stats:
			player_hp_bar.max_value = stats.max_hp
			player_hp_bar.value = stats.max_hp
			player_posture_bar.max_value = stats.max_posture
			player_posture_bar.value = 0
			player_stamina_bar.max_value = stats.max_stamina
			player_stamina_bar.value = stats.max_stamina
			_update_hp_label(player_hp_label, stats.max_hp, stats.max_hp)

	if opponent and opponent.has_method("get_stats"):
		var stats: FighterStats = opponent.get_stats()
		if stats:
			opponent_hp_bar.max_value = stats.max_hp
			opponent_hp_bar.value = stats.max_hp
			opponent_posture_bar.max_value = stats.max_posture
			opponent_posture_bar.value = 0
			_update_hp_label(opponent_hp_label, stats.max_hp, stats.max_hp)


func _show_feedback(text: String, color: Color = Color.WHITE) -> void:
	if feedback_label:
		feedback_label.text = text
		feedback_label.add_theme_color_override(&"font_color", color)
		_feedback_timer = 1.0


func _on_hp_changed(fighter: Node, current: int, max_val: int) -> void:
	if fighter == _player:
		player_hp_bar.max_value = max_val
		player_hp_bar.value = current
		_update_hp_label(player_hp_label, current, max_val)
	elif fighter == _opponent:
		opponent_hp_bar.max_value = max_val
		opponent_hp_bar.value = current
		_update_hp_label(opponent_hp_label, current, max_val)


func _on_posture_changed(fighter: Node, current: int, max_val: int) -> void:
	if fighter == _player:
		player_posture_bar.max_value = max_val
		player_posture_bar.value = current
	elif fighter == _opponent:
		opponent_posture_bar.max_value = max_val
		opponent_posture_bar.value = current


func _on_stamina_changed(fighter: Node, current: float, max_val: float) -> void:
	if fighter == _player:
		player_stamina_bar.max_value = max_val
		player_stamina_bar.value = current


func _on_attack_landed(attacker: Node, defender: Node, _attack_data: Resource) -> void:
	if attacker == _player:
		_show_feedback("HIT!", Color(1.0, 0.3, 0.3))
	elif defender == _player:
		_show_feedback("HIT!", Color(1.0, 0.2, 0.2))
		_hit_flash_timer = 0.15


func _on_attack_blocked(attacker: Node, defender: Node, _attack_data: Resource) -> void:
	if defender == _player:
		_show_feedback("BLOCKED", Color(0.5, 0.7, 1.0))
	elif attacker == _player:
		_show_feedback("BLOCKED", Color(0.6, 0.6, 0.7))


func _on_attack_deflected(attacker: Node, defender: Node, _attack_data: Resource) -> void:
	if defender == _player:
		_show_feedback("DEFLECT!", Color(0.2, 1.0, 1.0))
	elif attacker == _player:
		_show_feedback("DEFLECTED!", Color(1.0, 0.5, 0.2))


func _on_posture_broken(fighter: Node) -> void:
	if fighter == _opponent:
		_show_feedback("POSTURE BREAK!", Color(1.0, 0.8, 0.0))
	elif fighter == _player:
		_show_feedback("POSTURE BROKEN!", Color(1.0, 0.0, 0.0))


func _on_perilous_warning(_attacker: Node, indicator_color: Color) -> void:
	_show_feedback("DANGER!", indicator_color)
	if player_stance_widget:
		player_stance_widget.flash(indicator_color, 0.6)


func _on_perilous_countered(attacker: Node, _defender: Node, counter_type: StringName) -> void:
	if attacker == _opponent:
		var text: String = counter_type.to_upper() + "!"
		_show_feedback(text, Color(0.0, 1.0, 0.5))


func _on_exhaustion_changed(fighter: Node, is_exhausted: bool) -> void:
	if fighter == _player and is_exhausted:
		_show_feedback("EXHAUSTED!", Color(0.3, 0.3, 0.8))


func _update_hp_label(label: Label, current: int, max_val: int) -> void:
	if label:
		label.text = "%d / %d" % [current, max_val]


func _process(delta: float) -> void:
	if _player and state_label:
		if _player.has_method("get_current_state_name"):
			state_label.text = str(_player.get_current_state_name())

	if _feedback_timer > 0.0:
		_feedback_timer -= delta
		if feedback_label:
			feedback_label.modulate.a = clampf(_feedback_timer / 0.3, 0.0, 1.0)
			if _feedback_timer <= 0.0:
				feedback_label.text = ""
				feedback_label.modulate.a = 1.0

	if _hit_flash_timer > 0.0:
		_hit_flash_timer -= delta
