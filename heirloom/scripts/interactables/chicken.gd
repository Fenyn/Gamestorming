extends CharacterBody3D

enum ChickenState { IDLE, WALKING, EATING, LAYING }

const WANDER_SPEED := 1.2
const WANDER_RADIUS := 4.0
const IDLE_TIME_MIN := 2.0
const IDLE_TIME_MAX := 6.0
const HUNGER_DRAIN_PER_DAY := 0.35

var hunger: float = 1.0
var _state: ChickenState = ChickenState.IDLE
var _timer: float = 0.0
var _target_pos: Vector3 = Vector3.ZERO
var _home_pos: Vector3 = Vector3.ZERO
var _has_laid_today := false
var _egg_scene: PackedScene = null


func _ready() -> void:
	_home_pos = global_position
	_pick_idle_time()

	_egg_scene = load("res://scenes/items/egg.tscn") as PackedScene


func setup(home: Vector3, starting_hunger: float) -> void:
	_home_pos = home
	hunger = starting_hunger


func _physics_process(delta: float) -> void:
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8) as float
	if not is_on_floor():
		velocity.y -= gravity * delta

	match _state:
		ChickenState.IDLE:
			_process_idle(delta)
		ChickenState.WALKING:
			_process_walking(delta)
		ChickenState.EATING:
			_process_eating(delta)
		ChickenState.LAYING:
			_process_laying(delta)

	move_and_slide()


func _process_idle(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_timer -= delta
	if _timer <= 0.0:
		if randf() < 0.7:
			_pick_wander_target()
			_state = ChickenState.WALKING
		else:
			_pick_idle_time()


func _process_walking(delta: float) -> void:
	var to_target := _target_pos - global_position
	to_target.y = 0.0

	if to_target.length() < 0.3:
		_state = ChickenState.IDLE
		_pick_idle_time()
		return

	var dir: Vector3 = to_target.normalized()
	velocity.x = dir.x * WANDER_SPEED
	velocity.z = dir.z * WANDER_SPEED

	look_at(global_position + dir, Vector3.UP)


func _process_eating(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_timer -= delta
	if _timer <= 0.0:
		_state = ChickenState.IDLE
		_pick_idle_time()


func _process_laying(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_timer -= delta
	if _timer <= 0.0:
		_lay_egg()
		_state = ChickenState.IDLE
		_pick_idle_time()


func feed(amount: float) -> void:
	hunger = clampf(hunger + amount, 0.0, 1.0)
	_state = ChickenState.EATING
	_timer = 2.0


func try_lay() -> void:
	if _has_laid_today:
		return
	if hunger < 0.3:
		return
	_state = ChickenState.LAYING
	_timer = 1.5


func _lay_egg() -> void:
	_has_laid_today = true
	if _egg_scene:
		var egg: Node3D = _egg_scene.instantiate()
		get_parent().add_child(egg)
		egg.global_position = global_position + Vector3(0, 0.1, -0.3)


func on_new_day() -> void:
	hunger = clampf(hunger - HUNGER_DRAIN_PER_DAY, 0.0, 1.0)
	_has_laid_today = false

	if hunger >= 0.3:
		try_lay()


func _pick_wander_target() -> void:
	var angle: float = randf() * TAU
	var dist: float = randf_range(1.0, WANDER_RADIUS)
	_target_pos = _home_pos + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)


func _pick_idle_time() -> void:
	_timer = randf_range(IDLE_TIME_MIN, IDLE_TIME_MAX)


func is_hungry() -> bool:
	return hunger < 0.5
