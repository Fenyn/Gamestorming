class_name Unit
extends Node2D

signal ap_changed(current: int)
signal unit_died(unit: Unit)

var current_tile: Vector2i = Vector2i.ZERO
var action_points: int = 0
var is_enemy: bool = false
var unit_data: UnitData = null

@onready var _visual: Polygon2D = %Visual
@onready var _unit_label: Label = %UnitLabel
@onready var _ap_label: Label = %APLabel
@onready var _hp_bar: HPBar = %HPBar
@onready var health: Health = %Health
@onready var mover: Mover = %Mover
@onready var attacker: Attacker = %Attacker
@onready var state_machine: StateMachine = %StateMachine
@onready var _target_pip: Polygon2D = %TargetPip


func _ready() -> void:
	state_machine.start()
	_target_pip.visible = false


func setup(tile: Vector2i, data: UnitData) -> void:
	unit_data = data
	is_enemy = data.is_enemy
	current_tile = tile
	position = Grid.tile_to_world(tile)
	action_points = data.max_ap

	_visual.color = data.unit_color
	_unit_label.text = data.unit_label
	_update_ap_display()

	health.hp_changed.connect(_hp_bar.update_bar)
	health.died.connect(_on_died)
	health.setup(data.max_hp)

	if data.weapon:
		attacker.setup(data.weapon)


func is_alive() -> bool:
	return health.is_alive()


func can_move() -> bool:
	return action_points >= unit_data.move_cost and not mover.is_walking() and is_alive()


func can_attack() -> bool:
	return attacker.can_attack(action_points) and not mover.is_walking() and is_alive()


func spend_ap(cost: int) -> void:
	action_points -= cost
	_update_ap_display()
	ap_changed.emit(action_points)


func refresh_ap() -> void:
	action_points = unit_data.max_ap
	_update_ap_display()
	ap_changed.emit(action_points)


func _update_ap_display() -> void:
	if _ap_label:
		_ap_label.text = "AP: " + str(action_points)


func set_exhausted(exhausted: bool) -> void:
	if not is_alive():
		return
	_visual.modulate = Color(0.6, 0.6, 0.6, 0.8) if exhausted else Color.WHITE


func show_target_pip(show: bool, actionable: bool = true) -> void:
	if _target_pip:
		_target_pip.visible = show
		if show:
			_target_pip.color = Color(1.0, 0.15, 0.15, 1.0) if actionable else Color(0.35, 0.15, 0.15, 0.6)


func _on_died() -> void:
	show_target_pip(false)
	state_machine.transition_to("Dead")
	unit_died.emit(self)
