class_name Player
extends CharacterBody3D

const MOVE_SPEED_NORMAL: float = 5.0
const MOVE_SPEED_MAG: float = 2.5
const MOUSE_SENSITIVITY: float = 0.002
const GRAVITY: float = 9.8
const PITCH_LIMIT: float = 1.4
const INERTIAL_SENSITIVITY: float = 1.0
const JUMP_VELOCITY: float = 4.5

@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera3D
@onready var _interact_ray: RayCast3D = $Head/Camera3D/InteractRay
@onready var _full_body: Node3D = $FullBody
@onready var _fp_arms: Node3D = $FPArms

var _input_context: InputContext.Mode = InputContext.Mode.PLAYER
var _pitch: float = 0.0
var _hovered_station: Node3D = null
var _current_station: Node3D = null

var health: int = 100
var mag_boots: bool = false
var anim_state: StringName = &"idle"
var current_room_id: String = ""


func _ready() -> void:
	if not is_multiplayer_authority():
		_camera.current = false
		_full_body.visible = true
		_fp_arms.visible = false
		set_process_input(false)
		set_process_unhandled_input(false)
		return

	_camera.current = true
	_full_body.visible = false
	_fp_arms.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if event.is_action_pressed(&"ui_cancel") and _input_context == InputContext.Mode.PLAYER:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mouse_event: InputEventMouseMotion = event as InputEventMouseMotion
		_apply_mouse_look(mouse_event.relative)


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return

	match _input_context:
		InputContext.Mode.PLAYER:
			_process_player_movement(delta)
			_process_interaction()
		InputContext.Mode.HELM:
			_process_station_input(delta)
		InputContext.Mode.TURRET:
			_process_station_input(delta)
		InputContext.Mode.TERMINAL:
			_process_station_input(delta)
		InputContext.Mode.DISABLED:
			pass

	_process_shared_input()
	_update_anim_state()


func _apply_mouse_look(relative: Vector2) -> void:
	rotate_y(-relative.x * MOUSE_SENSITIVITY)
	_pitch = clampf(_pitch - relative.y * MOUSE_SENSITIVITY, -PITCH_LIMIT, PITCH_LIMIT)
	_head.rotation.x = _pitch


func _process_player_movement(delta: float) -> void:
	var grounded: bool = is_on_floor()

	if not grounded:
		velocity.y -= GRAVITY * delta
	elif not mag_boots and Input.is_action_just_pressed(&"thrust_up"):
		velocity.y = JUMP_VELOCITY

	var input_dir: Vector2 = Input.get_vector(
		&"move_left", &"move_right", &"move_forward", &"move_back"
	)

	var move_speed: float = MOVE_SPEED_MAG if mag_boots else MOVE_SPEED_NORMAL
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	if grounded:
		if direction.length() > 0.0:
			velocity.x = direction.x * move_speed
			velocity.z = direction.z * move_speed
		else:
			var decel: float = move_speed * 10.0 * delta
			velocity.x = move_toward(velocity.x, 0.0, decel)
			velocity.z = move_toward(velocity.z, 0.0, decel)
	else:
		# Airborne: reduced control, momentum carries
		var air_control: float = 0.3
		if direction.length() > 0.0:
			velocity.x += direction.x * move_speed * air_control * delta
			velocity.z += direction.z * move_speed * air_control * delta

	move_and_slide()


func _process_interaction() -> void:
	var new_hover: Node3D = null
	if _interact_ray.is_colliding():
		var collider: Object = _interact_ray.get_collider()
		if collider is Node3D:
			var node: Node3D = collider as Node3D
			if node.is_in_group(&"stations"):
				new_hover = node
			elif node.get_parent().is_in_group(&"stations"):
				new_hover = node.get_parent() as Node3D

	_hovered_station = new_hover

	if _hovered_station and Input.is_action_just_pressed(&"interact"):
		if _hovered_station.has_method(&"request_occupy"):
			_hovered_station.request_occupy.rpc_id(1, multiplayer.get_unique_id())


func _process_station_input(_delta: float) -> void:
	if Input.is_action_just_pressed(&"exit_station"):
		if _current_station and _current_station.has_method(&"request_vacate"):
			_current_station.request_vacate.rpc_id(1, multiplayer.get_unique_id())


func _process_shared_input() -> void:
	if Input.is_action_just_pressed(&"toggle_mag_boots"):
		mag_boots = not mag_boots

	if Input.is_action_just_pressed(&"toggle_debug"):
		pass


func _update_anim_state() -> void:
	if _input_context != InputContext.Mode.PLAYER:
		anim_state = &"station"
		return

	if velocity.length() > 0.5:
		anim_state = &"walk"
	else:
		anim_state = &"idle"


func enter_station(station: Node3D, station_camera: Camera3D, context: InputContext.Mode = InputContext.Mode.TERMINAL) -> void:
	_current_station = station
	_input_context = context
	velocity = Vector3.ZERO

	if is_multiplayer_authority() and station_camera:
		_camera.current = false
		station_camera.current = true


func exit_station() -> void:
	if is_multiplayer_authority() and _current_station:
		var station_camera: Camera3D = _current_station.get(&"station_camera") as Camera3D
		if station_camera:
			station_camera.current = false
		_camera.current = true

	_current_station = null
	_input_context = InputContext.Mode.PLAYER


func set_input_context(mode: InputContext.Mode) -> void:
	_input_context = mode


func get_move_speed() -> float:
	return MOVE_SPEED_MAG if mag_boots else MOVE_SPEED_NORMAL


func get_inertial_sensitivity() -> float:
	return 0.0 if mag_boots else INERTIAL_SENSITIVITY
