class_name BattleHUD
extends Control

signal end_turn_pressed

@onready var _end_turn_button: Button = %EndTurnButton
@onready var _turn_label: Label = %TurnLabel
@onready var _result_label: Label = %ResultLabel
@onready var _attack_preview: PanelContainer = %AttackPreview
@onready var _preview_weapon: Label = %PreviewWeapon
@onready var _preview_damage: Label = %PreviewDamage
@onready var _preview_target_hp: Label = %PreviewTargetHP
@onready var _preview_ap_cost: Label = %PreviewAPCost
@onready var _move_preview: PanelContainer = %MovePreview
@onready var _move_ap_cost: Label = %MoveAPCost
@onready var _move_targets: Label = %MoveTargets
@onready var _unit_stats: PanelContainer = %UnitStats
@onready var _stats_name: Label = %StatsName
@onready var _stats_hp: Label = %StatsHP
@onready var _stats_ap: Label = %StatsAP
@onready var _stats_weapon: Label = %StatsWeapon
@onready var _stats_range: Label = %StatsRange
@onready var _hover_info: PanelContainer = %HoverInfo
@onready var _hover_name: Label = %HoverName
@onready var _hover_hp: Label = %HoverHP


func _ready() -> void:
	_end_turn_button.pressed.connect(func() -> void: end_turn_pressed.emit())
	_result_label.visible = false
	_attack_preview.visible = false
	_move_preview.visible = false
	_unit_stats.visible = false
	_hover_info.visible = false


func set_player_turn() -> void:
	_end_turn_button.visible = true
	_end_turn_button.disabled = false


func set_enemy_turn() -> void:
	_end_turn_button.visible = false


func set_turn_count(turn: int) -> void:
	_turn_label.text = "Turn %d — Player Phase" % turn


func update_end_turn_label(units_with_ap: int) -> void:
	if units_with_ap > 0:
		_end_turn_button.text = "End Turn (%d ready)" % units_with_ap
	else:
		_end_turn_button.text = "End Turn"


func show_result(text: String) -> void:
	_result_label.text = text
	_result_label.visible = true
	_end_turn_button.visible = false


func show_unit_stats(unit_label: String, hp: int, max_hp: int, ap: int, max_ap: int, weapon_name: String, weapon_range: int) -> void:
	_stats_name.text = unit_label
	_stats_hp.text = "HP: %d / %d" % [hp, max_hp]
	_stats_ap.text = "AP: %d / %d" % [ap, max_ap]
	_stats_weapon.text = weapon_name if weapon_name != "" else "None"
	_stats_range.text = "Range: %d" % weapon_range if weapon_range > 0 else "Range: --"
	_unit_stats.visible = true


func hide_unit_stats() -> void:
	_unit_stats.visible = false


func show_hover_info(unit_label: String, hp: int, max_hp: int) -> void:
	_hover_name.text = unit_label
	_hover_hp.text = "HP: %d / %d" % [hp, max_hp]
	_hover_info.visible = true


func hide_hover_info() -> void:
	_hover_info.visible = false


func show_attack_preview(weapon_name: String, damage: int, target_hp: int, target_max_hp: int, ap_cost: int, modifiers: String = "") -> void:
	_preview_weapon.text = weapon_name
	_preview_damage.text = "Damage: %d" % damage
	_preview_target_hp.text = "Target HP: %d / %d" % [target_hp, target_max_hp]
	_preview_ap_cost.text = "AP Cost: %d" % ap_cost
	if modifiers != "":
		_preview_ap_cost.text += "\n" + modifiers
	_attack_preview.visible = true


func hide_attack_preview() -> void:
	_attack_preview.visible = false


func show_move_preview(ap_cost: int, targets_in_range: int) -> void:
	_move_ap_cost.text = "Move Cost: %d AP" % ap_cost
	if targets_in_range > 0:
		_move_targets.text = "%d target%s in range" % [targets_in_range, "s" if targets_in_range > 1 else ""]
		_move_targets.modulate = Color.GREEN
	else:
		_move_targets.text = "No targets in range"
		_move_targets.modulate = Color.GRAY
	_move_preview.visible = true


func hide_move_preview() -> void:
	_move_preview.visible = false
