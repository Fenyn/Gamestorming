class_name Player
extends CharacterBody3D

const MOVE_SPEED := 6.0
const JUMP_VELOCITY := 5.0
const GROUND_ACCEL := 40.0
const GROUND_DRAG := 12.0
const AIR_STEER := 15.0
const AIR_STEER_FRACTION := 0.3
const AIR_DRAG := 2.0
const GRAVITY_FALLBACK := 18.0
const BURN_GRAVITY_SCALE := 0.6
const SWING_GRAVITY_SCALE := 0.35
const MOUSE_SENSITIVITY := 0.0022
const COINSHOT_SPEED := 100.0
const COIN_SCENE_PATH := "res://coin/coin.tscn"
const MAX_COINS := 32

var _yaw: float = 0.0
var _pitch: float = 0.0
var _coin_scene: PackedScene
var _live_coins: Array = []
var _spawn_position: Vector3 = Vector3.ZERO

@onready var camera: Camera3D = $Camera3D
@onready var allomancy: Allomancy = $Allomancy
@onready var hud: Control = $HUD

func _ready() -> void:
	if OS.get_name() != "Web":
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_coin_scene = load(COIN_SCENE_PATH)
	_spawn_position = global_position

func _input(event: InputEvent) -> void:
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseButton and event.pressed:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		return

	if event is InputEventMouseMotion:
		var m := event as InputEventMouseMotion
		_yaw -= m.relative.x * MOUSE_SENSITIVITY
		_pitch -= m.relative.y * MOUSE_SENSITIVITY
		_pitch = clampf(_pitch, -1.5, 1.5)
		rotation.y = _yaw
		camera.rotation.x = _pitch

	if event.is_action_pressed("quit"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		if OS.get_name() != "Web":
			get_tree().quit()

	if event.is_action_pressed("drop_coin"):
		_spawn_coin(true)
	elif event.is_action_pressed("toss_coin"):
		_spawn_coin(false)
	elif event.is_action_pressed("respawn"):
		_respawn()

func _physics_process(delta: float) -> void:
	# Gravity — reduced while actively burning metals or swinging.
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", GRAVITY_FALLBACK)
	var is_burning := allomancy.last_effective_force > 0.0
	if not is_on_floor():
		var grav_scale := 1.0
		if allomancy.swing_active:
			grav_scale = SWING_GRAVITY_SCALE
		elif is_burning:
			grav_scale = BURN_GRAVITY_SCALE
		velocity.y -= gravity * grav_scale * delta

	# Movement input — relative to player yaw, ignoring pitch.
	var input_x := Input.get_axis("move_left", "move_right")
	var input_z := Input.get_axis("move_forward", "move_back")
	var wish_local := Vector3(input_x, 0.0, input_z)
	var has_input := wish_local.length_squared() > 0.001
	if wish_local.length() > 1.0:
		wish_local = wish_local.normalized()
	var wish: Vector3 = (transform.basis * wish_local) * MOVE_SPEED

	if is_on_floor():
		if has_input:
			velocity.x = move_toward(velocity.x, wish.x, GROUND_ACCEL * delta)
			velocity.z = move_toward(velocity.z, wish.z, GROUND_ACCEL * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, GROUND_DRAG * delta)
			velocity.z = move_toward(velocity.z, 0.0, GROUND_DRAG * delta)
	else:
		if has_input:
			var wish_dir := wish.normalized()
			var horiz_speed := Vector2(velocity.x, velocity.z).length()
			var max_steer := maxf(MOVE_SPEED, horiz_speed * AIR_STEER_FRACTION)
			var speed_in_wish := velocity.x * wish_dir.x + velocity.z * wish_dir.z
			if speed_in_wish < max_steer:
				var add := minf(AIR_STEER * delta, max_steer - speed_in_wish)
				velocity.x += wish_dir.x * add
				velocity.z += wish_dir.z * add
		velocity.x = move_toward(velocity.x, 0.0, AIR_DRAG * delta)
		velocity.z = move_toward(velocity.z, 0.0, AIR_DRAG * delta)

	# Allomantic targeting and forces.
	var lmb_held := Input.is_action_pressed("lock_targets")
	var push_held := Input.is_action_pressed("push")
	var pull_held := Input.is_action_pressed("pull")
	if lmb_held and not allomancy._is_locked:
		allomancy.lock_target()
	elif not lmb_held and allomancy._is_locked:
		allomancy.unlock_target()
	if Input.is_action_just_pressed("add_anchor") and allomancy._is_locked:
		allomancy.add_target()

	if Input.is_action_just_pressed("push") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	allomancy.apply_push_pull(delta, push_held, pull_held)
	allomancy.apply_rope_swing(delta, push_held, pull_held)

	move_and_slide()

func _spawn_coin(drop_mode: bool) -> void:
	# Cull oldest if at the cap.
	_live_coins = _live_coins.filter(func(c): return is_instance_valid(c))
	while _live_coins.size() >= MAX_COINS:
		var oldest: Node = _live_coins.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()

	var coin: RigidBody3D = _coin_scene.instantiate()
	get_tree().current_scene.add_child(coin)
	var cam_xf := camera.global_transform
	var forward: Vector3 = -cam_xf.basis.z
	if drop_mode:
		# Q: drop straight down at the player's feet, near-zero velocity.
		coin.global_position = camera.global_position + Vector3(0.0, -0.4, 0.0)
		coin.linear_velocity = Vector3(0.0, -0.5, 0.0)
	else:
		# F: coinshot — launch along the aim direction as if pushed.
		coin.global_position = camera.global_position + forward * 0.6
		var shot_speed := minf(COINSHOT_SPEED * allomancy.burn_intensity, Allomancy.LOOSE_TARGET_SPEED_CAP)
		coin.linear_velocity = forward * shot_speed
	_live_coins.append(coin)

func coin_count() -> int:
	_live_coins = _live_coins.filter(func(c): return is_instance_valid(c))
	return _live_coins.size()

func set_spawn(pos: Vector3) -> void:
	_spawn_position = pos
	global_position = pos
	velocity = Vector3.ZERO
	for c in _live_coins:
		if is_instance_valid(c):
			c.queue_free()
	_live_coins.clear()

func _respawn() -> void:
	for c in _live_coins:
		if is_instance_valid(c):
			c.queue_free()
	_live_coins.clear()
	velocity = Vector3.ZERO
	global_position = _spawn_position
