class_name Axe
extends Node3D
## Axe view-model. Holding `primary` swings while the mouse is captured.
## At the strike moment the aim ray fires from the crosshair; a hit
## collider that implements receive_chop(damage, point, normal) takes
## the chop. Nothing implements it yet, felling adds it to ConiferTree.
##
## Node layout: this node carries walk bob and mouse-look sway, the
## SwingPivot child carries the held rest pose and the swing animation,
## and SwingPivot/Model holds the placeholder meshes (swap that node's
## contents for an artist asset later). Meshes live on render layer 2
## and are drawn by the HUD's ViewModelCamera, not the main camera, so
## the axe never clips into world geometry.

const WINDUP_ROT: Vector3 = Vector3(0.55, -0.5, -0.35)
const WINDUP_POS: Vector3 = Vector3(0.06, 0.08, 0.1)
const STRIKE_ROT: Vector3 = Vector3(-1.4, 0.45, 0.4)
const STRIKE_POS: Vector3 = Vector3(-0.1, -0.12, -0.22)
const RECOIL_ROT: Vector3 = Vector3(0.3, -0.1, -0.1)
const FOLLOW_ROT: Vector3 = Vector3(-0.3, 0.15, 0.1)
const FOLLOW_POS: Vector3 = Vector3(-0.03, -0.04, -0.04)
## Offset and tilt of the lowered pose while the hands are full.
const LOWER_POS: Vector3 = Vector3(0.12, -0.38, 0.08)
const LOWER_TILT: float = -0.9

@export var damage: float = 1.0
@export var swing_time: float = 0.55
@export var aim_ray: RayCast3D

@export_group("Feel")
@export var bob_amount: float = 0.014
@export var bob_speed: float = 11.0
@export var sway_amount: float = 0.0015
@export var sway_max: float = 0.035
@export var sway_recover: float = 9.0

var _swinging: bool = false
var _lowered: bool = false
var _lower_amount: float = 0.0
var _lower_tween: Tween = null
var _hovered_piece: TrunkPiece = null
var _rest_position: Vector3 = Vector3.ZERO
var _pivot_rest_rotation: Vector3 = Vector3.ZERO
var _time: float = 0.0
var _bob_phase: float = 0.0
var _bob_intensity: float = 0.0
var _sway: Vector2 = Vector2.ZERO
var _player: Player = null

@onready var swing_pivot: Node3D = $SwingPivot


func _ready() -> void:
	_rest_position = position
	_pivot_rest_rotation = swing_pivot.rotation
	_player = owner as Player


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion: InputEventMouseMotion = event
		_sway.x = clampf(_sway.x - motion.relative.x * sway_amount, -sway_max, sway_max)
		_sway.y = clampf(_sway.y + motion.relative.y * sway_amount, -sway_max, sway_max)


func _process(delta: float) -> void:
	_update_feel(delta)
	_update_buck_preview()
	if _swinging or _lowered or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if Input.is_action_pressed("primary"):
		_swing()


## CarrySystem stows the axe while something is carried; the lowered
## pose blends in through _lower_amount so the feel motion keeps running.
func set_lowered(lowered: bool) -> void:
	if _lowered == lowered:
		return
	_lowered = lowered
	if _lower_tween != null and _lower_tween.is_valid():
		_lower_tween.kill()
	_lower_tween = create_tween()
	_lower_tween.tween_property(self, "_lower_amount", 1.0 if lowered else 0.0, 0.25) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Shows the cut preview on the oversized trunk piece under the
## crosshair, and hides it when the aim moves off.
func _update_buck_preview() -> void:
	var target: TrunkPiece = null
	if not _lowered and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED \
			and aim_ray != null and aim_ray.is_colliding():
		var collider: Object = aim_ray.get_collider()
		if collider is TrunkPiece:
			var piece: TrunkPiece = collider
			if not piece.is_log():
				target = piece
	if _hovered_piece != null and is_instance_valid(_hovered_piece) and _hovered_piece != target:
		_hovered_piece.hide_cut_preview()
	_hovered_piece = target
	if target != null:
		target.show_cut_preview(aim_ray.get_collision_point())


## Lags the axe against mouse look, bobs it with ground movement, and
## adds a slow breathing drift while standing still.
func _update_feel(delta: float) -> void:
	_time += delta
	_sway = _sway.lerp(Vector2.ZERO, 1.0 - exp(-sway_recover * delta))

	var target: float = 0.0
	if _player != null and _player.is_on_floor():
		var hvel: Vector3 = _player.velocity
		hvel.y = 0.0
		target = clampf(hvel.length() / _player.walk_speed, 0.0, 1.0)
	_bob_intensity = lerpf(_bob_intensity, target, 1.0 - exp(-6.0 * delta))
	_bob_phase += delta * bob_speed * _bob_intensity

	var bob: Vector3 = Vector3(
		sin(_bob_phase) * bob_amount,
		-absf(cos(_bob_phase)) * bob_amount,
		0.0
	) * _bob_intensity
	var breathe: Vector3 = Vector3(
		sin(_time * 0.9) * 0.002,
		sin(_time * 1.7) * 0.004,
		0.0
	) * (1.0 - _bob_intensity)
	position = _rest_position + Vector3(_sway.x, _sway.y, 0.0) + bob + breathe \
		+ LOWER_POS * _lower_amount
	rotation.z = _sway.x * 1.6
	rotation.x = LOWER_TILT * _lower_amount


func _swing() -> void:
	_swinging = true
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	# Wind up over the shoulder, decelerating into the top of the arc.
	tween.tween_property(swing_pivot, "rotation", _pivot_rest_rotation + WINDUP_ROT, swing_time * 0.3) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(swing_pivot, "position", WINDUP_POS, swing_time * 0.3) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Anticipation beat before committing.
	tween.chain().tween_interval(swing_time * 0.05)
	# The chop: accelerates the whole way down.
	tween.chain().tween_property(swing_pivot, "rotation", _pivot_rest_rotation + STRIKE_ROT, swing_time * 0.16) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tween.tween_property(swing_pivot, "position", STRIKE_POS, swing_time * 0.16) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(_resolve_strike)


## Runs the hit check at the bottom of the chop, then plays the matching
## back half: recoil off a solid hit, follow-through on a whiff.
func _resolve_strike() -> void:
	var strike_rot: Vector3 = _pivot_rest_rotation + STRIKE_ROT
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	if _strike():
		# Bounce off the impact.
		tween.tween_property(swing_pivot, "rotation", strike_rot + RECOIL_ROT, swing_time * 0.08) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.chain().tween_property(swing_pivot, "rotation", _pivot_rest_rotation, swing_time * 0.41) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(swing_pivot, "position", Vector3.ZERO, swing_time * 0.41) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		# Nothing stopped the swing: carry through the arc, then recover.
		tween.tween_property(swing_pivot, "rotation", strike_rot + FOLLOW_ROT, swing_time * 0.12) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(swing_pivot, "position", STRIKE_POS + FOLLOW_POS, swing_time * 0.12) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.chain().tween_property(swing_pivot, "rotation", _pivot_rest_rotation, swing_time * 0.45) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(swing_pivot, "position", Vector3.ZERO, swing_time * 0.45) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.chain().tween_callback(_end_swing)


## Returns true when the ray hit anything solid; delivers the chop when
## the collider supports it.
func _strike() -> bool:
	if aim_ray == null:
		return false
	aim_ray.force_raycast_update()
	if not aim_ray.is_colliding():
		return false
	var collider: Object = aim_ray.get_collider()
	if collider == null:
		return false
	var point: Vector3 = aim_ray.get_collision_point()
	var normal: Vector3 = aim_ray.get_collision_normal()
	if collider.has_method("receive_chop"):
		collider.call("receive_chop", damage, point, normal)
		Fx.wood_chips(self, point, normal)
	else:
		Fx.dust_puff(self, point, 0.12)
	return true


func _end_swing() -> void:
	_swinging = false
