class_name FighterAnimator
extends Node3D

signal swing_finished()

const STANCE_LERP_SPEED: float = 12.0

var _fighter: Fighter = null
var _target_rotation: Vector3 = Vector3.ZERO
var _is_animating: bool = false
var _current_tween: Tween = null

@onready var hand_pivot: Node3D = %HandPivot
@onready var blade_mesh: MeshInstance3D = %BladeMesh
@onready var guard_mesh: MeshInstance3D = %GuardMesh

var _stance_poses: Dictionary = {
	StanceDirection.Direction.TOP: Vector3(deg_to_rad(-70.0), 0.0, 0.0),
	StanceDirection.Direction.BOTTOM_LEFT: Vector3(deg_to_rad(30.0), deg_to_rad(-50.0), deg_to_rad(-20.0)),
	StanceDirection.Direction.BOTTOM_RIGHT: Vector3(deg_to_rad(30.0), deg_to_rad(50.0), deg_to_rad(20.0)),
}

var _attack_arcs: Dictionary = {
	StanceDirection.Direction.TOP: {
		"windup": Vector3(deg_to_rad(-90.0), 0.0, 0.0),
		"strike": Vector3(deg_to_rad(40.0), 0.0, 0.0),
	},
	StanceDirection.Direction.BOTTOM_LEFT: {
		"windup": Vector3(deg_to_rad(45.0), deg_to_rad(-70.0), deg_to_rad(-30.0)),
		"strike": Vector3(deg_to_rad(-20.0), deg_to_rad(40.0), deg_to_rad(20.0)),
	},
	StanceDirection.Direction.BOTTOM_RIGHT: {
		"windup": Vector3(deg_to_rad(45.0), deg_to_rad(70.0), deg_to_rad(30.0)),
		"strike": Vector3(deg_to_rad(-20.0), deg_to_rad(-40.0), deg_to_rad(-20.0)),
	},
}

var _default_blade_color: Color = Color(0.75, 0.78, 0.82, 1.0)
var _blade_material: StandardMaterial3D = null


func _ready() -> void:
	_fighter = owner as Fighter
	if _fighter == null:
		return
	_setup.call_deferred()


func _setup() -> void:
	_blade_material = blade_mesh.get_surface_override_material(0) as StandardMaterial3D
	if _blade_material == null:
		_blade_material = StandardMaterial3D.new()
		_blade_material.albedo_color = _default_blade_color
		_blade_material.metallic = 0.7
		_blade_material.roughness = 0.3
		blade_mesh.set_surface_override_material(0, _blade_material)

	if _fighter.stance_manager:
		_fighter.stance_manager.stance_changed.connect(_on_stance_changed)

	EventBus.attack_started.connect(_on_attack_started_event)
	EventBus.attack_deflected.connect(_on_deflected)
	EventBus.attack_blocked.connect(_on_blocked)
	EventBus.perilous_warning.connect(_on_perilous_warning)
	EventBus.shove_landed.connect(_on_shove_landed)

	_target_rotation = _stance_poses.get(StanceDirection.Direction.TOP, Vector3.ZERO)
	if hand_pivot:
		hand_pivot.rotation = _target_rotation


func _physics_process(delta: float) -> void:
	if hand_pivot == null or _is_animating:
		return
	hand_pivot.rotation = hand_pivot.rotation.lerp(_target_rotation, STANCE_LERP_SPEED * delta)


func _on_stance_changed(new_direction: StanceDirection.Direction) -> void:
	if _is_animating:
		return
	_target_rotation = _stance_poses.get(new_direction, Vector3.ZERO)


func play_attack(direction: StanceDirection.Direction, is_heavy: bool, is_charged: bool) -> void:
	if hand_pivot == null:
		return

	_kill_tween()
	_is_animating = true

	var arc: Dictionary = _attack_arcs.get(direction, _attack_arcs[StanceDirection.Direction.TOP])
	var windup_rot: Vector3 = arc["windup"]
	var strike_rot: Vector3 = arc["strike"]

	var windup_time: float = 0.15 if not is_heavy else 0.3
	var strike_time: float = 0.08 if not is_heavy else 0.12
	var recovery_time: float = 0.15

	if is_charged:
		windup_time = 0.1
		strike_time = 0.06

	_current_tween = create_tween()
	_current_tween.tween_property(hand_pivot, "rotation", windup_rot, windup_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_current_tween.tween_property(hand_pivot, "rotation", strike_rot, strike_time).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_current_tween.tween_property(hand_pivot, "rotation", _target_rotation, recovery_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_current_tween.tween_callback(_on_swing_done)


func play_block_impact() -> void:
	if hand_pivot == null:
		return

	_kill_tween()
	var recoil: Vector3 = hand_pivot.rotation + Vector3(deg_to_rad(10.0), 0.0, 0.0)
	_current_tween = create_tween()
	_current_tween.tween_property(hand_pivot, "rotation", recoil, 0.04).set_trans(Tween.TRANS_CUBIC)
	_current_tween.tween_property(hand_pivot, "rotation", _target_rotation, 0.15).set_ease(Tween.EASE_OUT)


func play_deflect_spark() -> void:
	if hand_pivot == null or _blade_material == null:
		return

	_kill_tween()

	var recoil: Vector3 = hand_pivot.rotation + Vector3(deg_to_rad(-8.0), 0.0, 0.0)
	_current_tween = create_tween()
	_current_tween.set_parallel(true)
	_current_tween.tween_property(hand_pivot, "rotation", recoil, 0.03)
	_current_tween.tween_property(_blade_material, "emission", Color(0.5, 0.9, 1.0), 0.03)
	_current_tween.set_parallel(false)
	_current_tween.tween_property(hand_pivot, "rotation", _target_rotation, 0.12).set_ease(Tween.EASE_OUT)
	_current_tween.tween_property(_blade_material, "emission", Color.BLACK, 0.2)
	_current_tween.tween_property(_blade_material, "emission_enabled", false, 0.0)


func play_shove() -> void:
	if hand_pivot == null:
		return

	_kill_tween()
	_is_animating = true

	var thrust: Vector3 = Vector3(deg_to_rad(-10.0), 0.0, 0.0)
	_current_tween = create_tween()
	_current_tween.tween_property(hand_pivot, "rotation", thrust, 0.12).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_current_tween.tween_property(hand_pivot, "rotation", _target_rotation, 0.2).set_ease(Tween.EASE_OUT)
	_current_tween.tween_callback(_on_swing_done)


func play_perilous_flash(color: Color) -> void:
	if _blade_material == null:
		return

	_blade_material.emission_enabled = true
	_blade_material.emission = color * 2.0

	var tween: Tween = create_tween()
	tween.tween_property(_blade_material, "emission", color * 0.5, 0.3)
	tween.tween_property(_blade_material, "emission", color * 2.0, 0.3)
	tween.set_loops(3)


func stop_perilous_flash() -> void:
	if _blade_material:
		_blade_material.emission_enabled = false
		_blade_material.emission = Color.BLACK


func _on_attack_started_event(attacker: Node, attack_data: Resource) -> void:
	if attacker != _fighter:
		return
	var data: AttackData = attack_data as AttackData
	if data == null:
		return

	if data.attack_type == AttackData.AttackType.SHOVE:
		play_shove()
		return

	if data.is_perilous:
		play_perilous_flash(data.indicator_color)

	var is_heavy: bool = data.attack_type == AttackData.AttackType.HEAVY
	play_attack(data.stance, is_heavy, false)


func _on_shove_landed(attacker: Node, _defender: Node, _vs_block: bool) -> void:
	if attacker == _fighter:
		play_shove()


func _on_deflected(attacker: Node, defender: Node, _attack_data: Resource) -> void:
	if defender == _fighter:
		play_deflect_spark()
	elif attacker == _fighter:
		play_block_impact()


func _on_blocked(attacker: Node, defender: Node, _attack_data: Resource) -> void:
	if defender == _fighter:
		play_block_impact()


func _on_perilous_warning(attacker: Node, indicator_color: Color) -> void:
	if attacker == _fighter:
		play_perilous_flash(indicator_color)


func _on_swing_done() -> void:
	_is_animating = false
	swing_finished.emit()


func _kill_tween() -> void:
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	_current_tween = null
	_is_animating = false
