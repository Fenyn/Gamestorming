class_name Player
extends CharacterBody3D
## First-person controller: mouse look, WASD, jump. Esc releases the mouse,
## clicking the window recaptures it.
##
## Encumbrance: CarrySystem writes carried_mass while hauling; walking
## and jumping scale down linearly toward carry_speed_floor at
## max_carry_mass. Pieces over max_carry_mass can't be lifted at all.

@export var walk_speed: float = 4.5
@export var acceleration: float = 10.0
@export var jump_velocity: float = 4.4
@export var mouse_sensitivity: float = 0.0022
@export_range(-90.0, 0.0, 1.0, "radians_as_degrees") var pitch_min: float = -1.4
@export_range(0.0, 90.0, 1.0, "radians_as_degrees") var pitch_max: float = 1.4

@export_group("Carry")
@export var max_carry_mass: float = 90.0
## Heavier than max_carry_mass but at most this can still be dragged
## along the ground; past it the piece won't budge at all.
@export var max_drag_mass: float = 350.0
## Speed multiplier at a full max_carry_mass load.
@export_range(0.05, 1.0) var carry_speed_floor: float = 0.25

## Body-pushing: walking into a rigid body (a downed trunk, a big
## trunk piece) shoves it at the contact point. Effective push force in
## newtons; heavy bodies barely beat ground friction and creep.
const PUSH_FORCE: float = 3900.0
## Acceleration cap just above ground friction (~9.8 m/s^2), so even
## light bodies only scoot, m/s^2.
const PUSH_ACCEL_CAP: float = 14.0
## Never push a body past this speed, m/s.
const PUSH_MAX_SPEED: float = 0.4

## Mass of whatever is being carried, kg. Set by CarrySystem.
var carried_mass: float = 0.0

var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))

@onready var head: Node3D = $Head


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion: InputEventMouseMotion = event
		rotate_y(-motion.relative.x * mouse_sensitivity)
		head.rotate_x(-motion.relative.y * mouse_sensitivity)
		head.rotation.x = clampf(head.rotation.x, pitch_min, pitch_max)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		var button: InputEventMouseButton = event
		if button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	var encumbrance: float = encumbrance_factor()
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity * lerpf(1.0, 0.55, 1.0 - encumbrance)

	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var speed: float = walk_speed * encumbrance
	var target: Vector3 = direction * speed
	velocity.x = move_toward(velocity.x, target.x, acceleration * speed * delta)
	velocity.z = move_toward(velocity.z, target.z, acceleration * speed * delta)

	move_and_slide()
	_push_bodies(delta)


## Shove rigid bodies the capsule slid against this frame, horizontally
## only. Applied at the contact point so pushing a trunk's end pivots it.
func _push_bodies(delta: float) -> void:
	for i in get_slide_collision_count():
		var collision: KinematicCollision3D = get_slide_collision(i)
		var body: RigidBody3D = collision.get_collider() as RigidBody3D
		if body == null or body.freeze:
			continue
		var dir: Vector3 = -collision.get_normal()
		dir.y = 0.0
		if dir.length_squared() < 0.001:
			continue
		dir = dir.normalized()
		if body.linear_velocity.dot(dir) > PUSH_MAX_SPEED:
			continue
		var accel: float = minf(PUSH_FORCE / body.mass, PUSH_ACCEL_CAP)
		body.apply_impulse(
			dir * (body.mass * accel * delta),
			collision.get_position() - body.global_position
		)


## 1.0 unburdened, carry_speed_floor at a full load.
func encumbrance_factor() -> float:
	var burden: float = clampf(carried_mass / max_carry_mass, 0.0, 1.0)
	return lerpf(1.0, carry_speed_floor, burden)
