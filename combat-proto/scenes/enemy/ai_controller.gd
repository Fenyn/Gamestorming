class_name AIController
extends Node

@export var fighter: Fighter = null
@export var aggression: float = 0.5
@export var reaction_time: float = 0.3
@export var block_chance: float = 0.5
@export var deflect_chance: float = 0.2
@export var perilous_chance: float = 0.1
@export var stance_change_interval: float = 1.5

var _ai_input: AIInput = AIInput.new()
var _decision_timer: float = 0.0
var _stance_timer: float = 0.0
var _attack_cooldown: float = 0.0
var _react_timer: float = 0.0
var _should_block: bool = false
var _directions: Array[StanceDirection.Direction] = [
	StanceDirection.Direction.TOP,
	StanceDirection.Direction.BOTTOM_LEFT,
	StanceDirection.Direction.BOTTOM_RIGHT,
]


func _ready() -> void:
	if fighter:
		fighter.input = _ai_input
	EventBus.attack_started.connect(_on_opponent_attack)


func _physics_process(delta: float) -> void:
	if fighter == null or not fighter.combat_resource.is_alive():
		return

	_ai_input.tick()
	_update_stance(delta)
	_update_reaction(delta)
	_update_decision(delta)


func _update_stance(delta: float) -> void:
	_stance_timer -= delta
	if _stance_timer <= 0.0:
		_stance_timer = stance_change_interval + randf_range(-0.3, 0.3)
		var new_dir: StanceDirection.Direction = _directions.pick_random()
		_ai_input.set_stance(new_dir)


func _update_decision(delta: float) -> void:
	_attack_cooldown -= delta
	_decision_timer -= delta
	if _decision_timer > 0.0:
		return

	_decision_timer = randf_range(0.3, 1.5 - aggression)

	if _attack_cooldown > 0.0:
		return

	if _should_block:
		return

	var roll: float = randf()
	if roll < aggression:
		_do_attack()


func _do_attack() -> void:
	var roll: float = randf()
	if roll < perilous_chance and fighter.profile and fighter.profile.available_perilous.size() > 0:
		var perilous: AttackData = fighter.profile.available_perilous.pick_random()
		_ai_input.press_action(&"light_attack")
	elif roll < 0.5:
		_ai_input.press_action(&"light_attack")
	else:
		_ai_input.press_action(&"heavy_attack")
	_attack_cooldown = randf_range(0.8, 2.0)


func _update_reaction(delta: float) -> void:
	if _should_block:
		_react_timer -= delta
		if _react_timer <= 0.0:
			_should_block = false
			if randf() < block_chance:
				_ai_input.press_action(&"guard")
			elif randf() < deflect_chance:
				_ai_input.press_action(&"guard")
			else:
				if randf() < 0.3:
					_ai_input.press_action(&"dodge")


func _on_opponent_attack(attacker: Node, _attack_data: Resource) -> void:
	if fighter == null or attacker == fighter:
		return
	_should_block = true
	_react_timer = reaction_time
