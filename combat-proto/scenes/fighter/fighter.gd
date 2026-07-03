class_name Fighter
extends CharacterBody3D

signal attack_started(attack_data: AttackData)
signal attack_active()
signal attack_recovered()
signal block_entered(direction: StanceDirection.Direction)
signal hit_absorbed(attack_data: AttackData)
signal dodge_started(direction: Vector3)
signal dodge_ended()
signal jump_started()
signal jump_ended()

@export var profile: FighterProfile = null

var stats: FighterStats:
	get:
		if profile:
			return profile.stats
		return null

var input: FighterInput = null
var opponent: Fighter = null
var is_locked_on: bool = false
var gravity: float = 18.0

@onready var combat_resource: CombatResource = %CombatResource
@onready var stance_manager: StanceManager = %StanceManager
@onready var hitbox: Area3D = %Hitbox
@onready var hurtbox: Area3D = %Hurtbox
@onready var state_machine: BaseStateMachine = %StateMachine
@onready var fighter_mesh: MeshInstance3D = %FighterMesh
@onready var fighter_animator: FighterAnimator = %FighterAnimator


func _ready() -> void:
	if profile and profile.stats:
		combat_resource.setup(profile.stats)
	combat_resource.posture_broken.connect(_on_posture_broken)
	combat_resource.died.connect(_on_died)
	combat_resource.exhaustion_changed.connect(_on_exhaustion_changed)
	hitbox.monitoring = false
	EventBus.fighter_spawned.emit(self)


func start() -> void:
	state_machine.start()


func get_stats() -> FighterStats:
	if profile:
		return profile.stats
	return null


func get_attack_data(attack_key: String) -> AttackData:
	if profile:
		return profile.get_attack(attack_key)
	return null


func get_directional_attack(type: String) -> AttackData:
	if profile:
		return profile.get_directional_attack(type, stance_manager.current_stance)
	return null


func get_current_state_name() -> StringName:
	return state_machine.get_current_state_name()


func face_opponent() -> void:
	if opponent == null or not is_locked_on:
		return
	var target_pos: Vector3 = opponent.global_position
	target_pos.y = global_position.y
	if global_position.distance_squared_to(target_pos) > 0.01:
		look_at(target_pos)


func get_direction_to_opponent() -> Vector3:
	if opponent == null:
		return -global_transform.basis.z
	return (opponent.global_position - global_position).normalized()


func toggle_lock_on() -> void:
	if opponent == null:
		return
	is_locked_on = not is_locked_on
	EventBus.lock_on_changed.emit(self, opponent if is_locked_on else null)


func apply_hit_result(result: HitResult, from_attacker: Fighter) -> void:
	if result.hp_damage_to_defender > 0:
		combat_resource.take_hp_damage(result.hp_damage_to_defender)
	if result.posture_damage_to_defender > 0:
		combat_resource.take_posture_damage(result.posture_damage_to_defender)
	if result.stamina_cost_to_defender > 0.0:
		combat_resource.spend_stamina(result.stamina_cost_to_defender)
	if result.posture_damage_to_attacker > 0 and from_attacker:
		from_attacker.combat_resource.take_posture_damage(result.posture_damage_to_attacker)
	if result.defender_state_transition != &"":
		state_machine.transition_to(result.defender_state_transition)


func reset_fighter() -> void:
	combat_resource.full_reset()
	velocity = Vector3.ZERO
	state_machine.transition_to(&"Idle")


func _on_posture_broken() -> void:
	state_machine.transition_to(&"PostureBreak")


func _on_died() -> void:
	state_machine.transition_to(&"Dead")


func _on_exhaustion_changed(is_exhausted: bool) -> void:
	if is_exhausted:
		var current: StringName = get_current_state_name()
		if current == &"Idle" or current == &"Moving":
			state_machine.transition_to(&"Exhausted")
