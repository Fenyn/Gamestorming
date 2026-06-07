extends CharacterBody3D

const WALK_SPEED := 4.5
const SPRINT_SPEED := 6.75
const BIKE_SPEED := 9.0
const JUMP_VELOCITY := 4.0
const ACCEL := 30.0
const FRICTION := 20.0
const MOUSE_SENSITIVITY := 0.002
const INTERACT_DISTANCE := 2.5

const HUNGER_DRAIN_PER_HOUR := 0.042
const THIRST_DRAIN_PER_HOUR := 0.056
const FATIGUE_DRAIN_PER_HOUR := 0.063
const FATIGUE_SPRINT_MULTIPLIER := 2.0
const CRITICAL_THRESHOLD := 0.2

enum Mode { FREE, MINI_GAME, SCREEN }

var _yaw := 0.0
var _pitch := 0.0
var _mode: Mode = Mode.FREE
var _held_item: Node3D = null
var _on_bicycle := false
var _saved_yaw := 0.0
var _saved_pitch := 0.0
var _exit_frame := -1
const EXIT_COOLDOWN_FRAMES := 10

@onready var camera: Camera3D = $Camera3D
@onready var interact_ray: RayCast3D = $Camera3D/InteractRay
@onready var hold_point: Marker3D = $Camera3D/HoldPoint
@onready var hud: CanvasLayer = $HUD


var _collapsed := false


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	add_to_group("player")
	EventBus.player_collapsed.connect(_on_collapse)


func _input(event: InputEvent) -> void:
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseButton and event.pressed:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		return

	if _mode == Mode.MINI_GAME:
		return

	var in_cooldown: bool = Engine.get_process_frames() - _exit_frame <= EXIT_COOLDOWN_FRAMES

	if event is InputEventMouseMotion and not in_cooldown:
		var m: InputEventMouseMotion = event as InputEventMouseMotion
		_yaw -= m.relative.x * MOUSE_SENSITIVITY
		_pitch -= m.relative.y * MOUSE_SENSITIVITY
		_pitch = clampf(_pitch, -1.4, 1.4)
		rotation.y = _yaw
		camera.rotation.x = _pitch

	if event.is_action_pressed("interact") and not in_cooldown:
		_try_interact()

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not in_cooldown:
		_try_click()

	if event.is_action_pressed("toggle_bicycle"):
		_toggle_bicycle()

	if event.is_action_pressed("eat"):
		_try_eat_held()


func _physics_process(delta: float) -> void:
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8) as float
	if not is_on_floor():
		velocity.y -= gravity * delta

	if _mode != Mode.FREE:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		velocity.z = move_toward(velocity.z, 0.0, FRICTION * delta)
		move_and_slide()
		_update_held_item()
		return

	var input_dir := Vector3.ZERO
	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.z = Input.get_axis("move_forward", "move_back")
	if input_dir.length() > 1.0:
		input_dir = input_dir.normalized()

	var speed: float = WALK_SPEED
	var is_sprinting := false
	if _on_bicycle:
		speed = BIKE_SPEED
	elif Input.is_action_pressed("sprint") and GameState.fatigue > 0.3:
		speed = SPRINT_SPEED
		is_sprinting = true

	var wish: Vector3 = (transform.basis * input_dir) * speed

	if is_on_floor():
		if input_dir.length_squared() > 0.001:
			velocity.x = move_toward(velocity.x, wish.x, ACCEL * delta)
			velocity.z = move_toward(velocity.z, wish.z, ACCEL * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
			velocity.z = move_toward(velocity.z, 0.0, FRICTION * delta)
		if Input.is_action_just_pressed("jump") and not _on_bicycle:
			velocity.y = JUMP_VELOCITY

	move_and_slide()
	_update_held_item()
	_drain_needs(delta, is_sprinting)


func _drain_needs(delta: float, is_sprinting: bool) -> void:
	if TimeManager.paused:
		return

	var hours_elapsed: float = delta / TimeManager.SECONDS_PER_GAME_HOUR

	GameState.hunger -= HUNGER_DRAIN_PER_HOUR * hours_elapsed
	GameState.thirst -= THIRST_DRAIN_PER_HOUR * hours_elapsed

	var fatigue_mult: float = FATIGUE_SPRINT_MULTIPLIER if is_sprinting else 1.0
	GameState.fatigue -= FATIGUE_DRAIN_PER_HOUR * hours_elapsed * fatigue_mult

	GameState.hunger = clampf(GameState.hunger, 0.0, 1.0)
	GameState.thirst = clampf(GameState.thirst, 0.0, 1.0)
	GameState.fatigue = clampf(GameState.fatigue, 0.0, 1.0)

	if GameState.hunger <= CRITICAL_THRESHOLD:
		EventBus.need_critical.emit("hunger")
	if GameState.thirst <= CRITICAL_THRESHOLD:
		EventBus.need_critical.emit("thirst")
	if GameState.fatigue <= 0.0:
		EventBus.player_collapsed.emit()


func _update_held_item() -> void:
	if _held_item and is_instance_valid(_held_item):
		var target: Vector3 = hold_point.global_transform.origin
		_held_item.global_position = _held_item.global_position.lerp(target, 0.2)
		_held_item.global_rotation = camera.global_rotation


func _try_interact() -> void:
	if not interact_ray.is_colliding():
		return
	var collider: Node3D = interact_ray.get_collider() as Node3D
	if collider and collider.has_method("interact"):
		collider.interact(self)


func _try_click() -> void:
	if _held_item:
		_try_place_item()
	else:
		_try_pickup_item()


func _try_pickup_item() -> void:
	if not interact_ray.is_colliding():
		return
	var collider: Node3D = interact_ray.get_collider() as Node3D
	if collider and collider.has_method("interact"):
		collider.interact(self)
		return
	if collider and collider.is_in_group("carriable"):
		pickup_item(collider)


func pickup_item(item: Node3D) -> void:
	if _held_item:
		return
	if _on_bicycle:
		return
	_held_item = item
	if item is RigidBody3D:
		(item as RigidBody3D).freeze = true
	_set_item_collision(item, false)
	item.global_position = hold_point.global_transform.origin
	EventBus.item_picked_up.emit(item)


func _try_place_item() -> void:
	if not _held_item:
		return
	if interact_ray.is_colliding():
		var collider: Node3D = interact_ray.get_collider() as Node3D
		if collider and collider.has_method("receive_item"):
			if collider.receive_item(_held_item):
				_held_item = null
				return
	var place_pos: Vector3 = hold_point.global_transform.origin + (-camera.global_transform.basis.z * 0.3)
	_held_item.global_position = place_pos
	if _held_item is RigidBody3D:
		(_held_item as RigidBody3D).freeze = false
	_set_item_collision(_held_item, true)
	EventBus.item_dropped.emit(_held_item)
	_held_item = null


func drop_held_item() -> void:
	if _held_item and is_instance_valid(_held_item):
		if _held_item is RigidBody3D:
			(_held_item as RigidBody3D).freeze = false
		_set_item_collision(_held_item, true)
		_held_item = null


func get_held_item() -> Node3D:
	return _held_item


func has_held_item() -> bool:
	return _held_item != null and is_instance_valid(_held_item)


func _try_eat_held() -> void:
	if not _held_item or not is_instance_valid(_held_item):
		return
	if not _held_item.has_method("is_food"):
		return
	if not _held_item.is_food():
		return

	var restore: float = _held_item.get("hunger_restore") as float
	if restore <= 0.0:
		restore = 0.3

	var cooked_bonus: float = 1.0
	if GameState.stove_fixed:
		cooked_bonus = 1.5

	GameState.hunger = clampf(GameState.hunger + restore * cooked_bonus, 0.0, 1.0)
	EventBus.need_changed.emit("hunger", GameState.hunger)
	_held_item.queue_free()
	_held_item = null


func _toggle_bicycle() -> void:
	if _held_item:
		return
	_on_bicycle = not _on_bicycle


func is_on_bicycle() -> bool:
	return _on_bicycle


func enter_mini_game(cam_transform: Transform3D) -> void:
	if _mode != Mode.FREE:
		return
	_mode = Mode.MINI_GAME
	_saved_yaw = _yaw
	_saved_pitch = _pitch
	camera.global_transform = cam_transform


func exit_mini_game() -> void:
	_restore_camera()


func enter_screen_mode(look_target: Vector3, cam_pos: Vector3) -> void:
	if _mode != Mode.FREE:
		return
	_mode = Mode.SCREEN
	_saved_yaw = _yaw
	_saved_pitch = _pitch
	camera.global_position = cam_pos
	camera.look_at(look_target, Vector3.UP)


func exit_screen_mode() -> void:
	_restore_camera()


func _restore_camera() -> void:
	if _mode == Mode.FREE:
		return
	_mode = Mode.FREE
	_exit_frame = Engine.get_process_frames()
	_yaw = _saved_yaw
	_pitch = _saved_pitch
	rotation.y = _yaw
	camera.position = Vector3(0, 1.7, 0)
	camera.rotation = Vector3(_pitch, 0, 0)


func _on_collapse() -> void:
	if _collapsed:
		return
	_collapsed = true
	TimeManager.paused = true

	var fade: Node = get_tree().get_first_node_in_group("screen_fade")
	if fade and fade.has_method("fade_to_black"):
		await fade.fade_to_black(0.5)

	GameState.fatigue = 0.25
	GameState.hunger = maxf(GameState.hunger - 0.15, 0.0)
	GameState.thirst = maxf(GameState.thirst - 0.15, 0.0)

	TimeManager.current_hour += 4
	if TimeManager.current_hour >= TimeManager.DAY_END_HOUR:
		TimeManager.advance_to_morning()

	if fade and fade.has_method("show_day_text"):
		fade.show_day_text("You passed out...", 2.0)
	if fade and fade.has_method("fade_from_black"):
		await fade.fade_from_black(1.0)

	TimeManager.paused = false
	_collapsed = false


func _set_item_collision(item: Node3D, enabled: bool) -> void:
	if item is RigidBody3D:
		var rb: RigidBody3D = item as RigidBody3D
		for child: Node in rb.get_children():
			if child is CollisionShape3D:
				(child as CollisionShape3D).disabled = not enabled
