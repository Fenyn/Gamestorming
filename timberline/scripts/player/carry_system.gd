class_name CarrySystem
extends Node
## Pick up / carry / drop / toss for physics bodies in the "carryable"
## group (bucked logs, wood limb debris). Carrying is a physics hold:
## each physics frame the body's velocities are driven toward a hold
## point in front of the camera, so heavy pieces lag and sway instead
## of snapping rigidly to the view. Encumbrance lives on the Player
## (carried_mass slows walking and jumping); pieces over the player's
## max_carry_mass can't be lifted at all, which is what forces bucking
## big trunks down before hauling them.
##
## Pieces heavier than max_carry_mass but at most max_drag_mass are
## dragged instead: the grab holds the aimed end of the body and a
## spring force hauls it along the ground behind the player, gravity
## and friction still on. Past max_drag_mass nothing moves.
##
## Controls: `interact` picks up (or grabs) / drops, `secondary` tosses
## a carried piece (releases a dragged one).

## Hold point distance in front of the camera, meters.
const HOLD_DISTANCE: float = 1.15
## Hold point drop below the eye line, meters.
const HOLD_DROP: float = 0.3
## Velocity gain pulling the body to the hold point, 1/s.
const PULL_STRENGTH: float = 12.0
## Angular velocity gain turning the body across the view, 1/s.
const TURN_STRENGTH: float = 8.0
const MAX_TURN_RATE: float = 6.0
## The carry breaks if the body gets stuck this far from the hold point.
const BREAK_DISTANCE: float = 2.6
## Toss momentum, kg*m/s: a light branch flies, a heavy log flops.
const TOSS_MOMENTUM: float = 260.0
const TOSS_SPEED_MIN: float = 2.0
const TOSS_SPEED_MAX: float = 7.0

## Dragging: the grabbed end is pulled toward a point this far in front
## of the player's feet, lifted a little off the ground.
const DRAG_DISTANCE: float = 1.0
const DRAG_HEIGHT: float = 0.35
## Spring/damper accelerations on the grabbed end, 1/s^2 and 1/s.
const DRAG_PULL: float = 30.0
const DRAG_DAMP: float = 5.0
const DRAG_MAX_ACCEL: float = 25.0
## The grab slips if the grabbed end lags this far behind, meters.
const DRAG_BREAK_DISTANCE: float = 3.0
## Fraction of a dragged mass that counts against encumbrance; the
## ground bears the rest.
const DRAG_BURDEN: float = 0.5

@export var camera: Camera3D
@export var aim_ray: RayCast3D
@export var axe: Axe

var _carried: RigidBody3D = null
var _dragging: bool = false
var _grab_local: Vector3 = Vector3.ZERO
var _player: Player = null
var _saved_gravity_scale: float = 1.0
var _saved_can_sleep: bool = true
var _hint: String = ""


func _ready() -> void:
	_player = owner as Player


func _physics_process(_delta: float) -> void:
	if _carried != null and not is_instance_valid(_carried):
		_carried = null
		_after_release()
	# The hold keeps running with the mouse released so the body never
	# floats gravityless; only the inputs need a captured mouse.
	var captured: bool = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if _carried == null:
		if not captured:
			_set_hint("")
			return
		var target: RigidBody3D = _aim_target()
		_update_hint(target)
		if target != null and Input.is_action_just_pressed("interact") \
				and target.mass <= _player.max_drag_mass:
			_pick_up(target)
	elif captured and Input.is_action_just_pressed("interact"):
		_drop()
	elif captured and Input.is_action_just_pressed("secondary"):
		if _dragging:
			_drop()
		else:
			_toss()
	elif _dragging:
		_hold_drag()
	else:
		_hold()


## The carryable rigid body under the crosshair, if any.
func _aim_target() -> RigidBody3D:
	if aim_ray == null or not aim_ray.is_colliding():
		return null
	var collider: Object = aim_ray.get_collider()
	if collider is RigidBody3D and (collider as Node).is_in_group("carryable"):
		return collider
	return null


func _pick_up(body: RigidBody3D) -> void:
	_carried = body
	_saved_gravity_scale = body.gravity_scale
	_saved_can_sleep = body.can_sleep
	body.can_sleep = false
	body.sleeping = false
	body.add_collision_exception_with(_player)
	# Stations (the sell bin) skip bodies still in the player's hands.
	body.set_meta("carried", true)
	if axe != null:
		axe.set_lowered(true)
	_dragging = body.mass > _player.max_carry_mass
	if _dragging:
		# Grab the aimed end; gravity stays on, the ground carries most
		# of the weight.
		var grab_world: Vector3 = body.global_position
		if aim_ray != null and aim_ray.is_colliding() and aim_ray.get_collider() == body:
			grab_world = aim_ray.get_collision_point()
		_grab_local = body.to_local(grab_world)
		_player.carried_mass = body.mass * DRAG_BURDEN
		_set_hint("dragging %d kg    E release" % roundi(body.mass))
	else:
		body.gravity_scale = 0.0
		_player.carried_mass = body.mass
		_set_hint("%d kg    E drop  ·  right-click toss" % roundi(body.mass))


## Drive the body toward the hold point and turn it to lie across the
## view. Velocities are set absolutely, so gravity barely bites.
func _hold() -> void:
	var forward: Vector3 = -camera.global_basis.z
	var hold: Vector3 = camera.global_position + forward * HOLD_DISTANCE \
		+ Vector3.DOWN * HOLD_DROP
	var com: Vector3 = _carried.to_global(_carried.center_of_mass)
	if com.distance_to(hold) > BREAK_DISTANCE:
		_drop()
		return
	_carried.linear_velocity = (hold - com) * PULL_STRENGTH

	# Turn the body's long axis (carry_axis if it names one, local Y
	# otherwise) horizontal across the view; roll about that axis is
	# left free, which looks natural for branches.
	var target_dir: Vector3 = camera.global_basis.x
	target_dir.y = 0.0
	if target_dir.length_squared() < 0.001:
		return
	target_dir = target_dir.normalized()
	var axis_local: Vector3 = Vector3.UP
	if _carried.has_method("carry_axis"):
		axis_local = _carried.call("carry_axis")
	var current: Vector3 = (_carried.global_basis * axis_local).normalized()
	if current.dot(target_dir) < 0.0:
		target_dir = -target_dir
	var arc: Quaternion = Quaternion(current, target_dir)
	var angle: float = arc.get_angle()
	if angle < 0.02:
		_carried.angular_velocity = Vector3.ZERO
		return
	var rate: Vector3 = arc.get_axis().normalized() * (angle * TURN_STRENGTH)
	_carried.angular_velocity = rate.limit_length(MAX_TURN_RATE)


## Spring/damper on the grabbed end, hauling it toward a point ahead of
## the player's feet. Force scales with mass so the follow feel is
## uniform; the cost is the encumbrance slowdown and the clumsy trailing
## body, not a weaker spring.
func _hold_drag() -> void:
	var forward: Vector3 = -camera.global_basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.001:
		return
	forward = forward.normalized()
	var anchor: Vector3 = _player.global_position + forward * DRAG_DISTANCE \
		+ Vector3.UP * DRAG_HEIGHT
	var grab_world: Vector3 = _carried.to_global(_grab_local)
	if grab_world.distance_to(anchor) > DRAG_BREAK_DISTANCE:
		_drop()
		return
	var point_velocity: Vector3 = _carried.linear_velocity \
		+ _carried.angular_velocity.cross(grab_world - _carried.to_global(_carried.center_of_mass))
	var accel: Vector3 = (anchor - grab_world) * DRAG_PULL - point_velocity * DRAG_DAMP
	accel = accel.limit_length(DRAG_MAX_ACCEL)
	_carried.apply_force(accel * _carried.mass, grab_world - _carried.global_position)


func _drop() -> void:
	var body: RigidBody3D = _release()
	body.linear_velocity = body.linear_velocity * 0.4


func _toss() -> void:
	var forward: Vector3 = -camera.global_basis.z
	var body: RigidBody3D = _release()
	var speed: float = clampf(TOSS_MOMENTUM / body.mass, TOSS_SPEED_MIN, TOSS_SPEED_MAX)
	body.linear_velocity = forward * speed + Vector3.UP * (speed * 0.2)


## Restores the carried body's physics config and clears carry state.
func _release() -> RigidBody3D:
	var body: RigidBody3D = _carried
	_carried = null
	_dragging = false
	body.gravity_scale = _saved_gravity_scale
	body.can_sleep = _saved_can_sleep
	body.remove_collision_exception_with(_player)
	body.set_meta("carried", false)
	_after_release()
	return body


func _after_release() -> void:
	_dragging = false
	_player.carried_mass = 0.0
	if axe != null:
		axe.set_lowered(false)
	_set_hint("")


func _update_hint(target: RigidBody3D) -> void:
	if target == null:
		_set_hint("")
	elif target.mass > _player.max_drag_mass:
		_set_hint("Too heavy to budge — %d kg" % roundi(target.mass))
	elif target.mass > _player.max_carry_mass:
		_set_hint("E drag  (%d kg)" % roundi(target.mass))
	else:
		_set_hint("E pick up  (%d kg)" % roundi(target.mass))


func _set_hint(text: String) -> void:
	if text == _hint:
		return
	_hint = text
	EventBus.interact_hint_changed.emit(text)
