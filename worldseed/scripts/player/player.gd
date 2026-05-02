class_name Player
extends CharacterBody3D

const MOVE_SPEED := 4.5
const JUMP_VELOCITY := 4.0
const ACCEL := 30.0
const FRICTION := 20.0
const MOUSE_SENSITIVITY := 0.002
const INTERACT_DISTANCE := 2.5

enum InteractMode { FREE, MINI_GAME, SCREEN }

var _yaw := 0.0
var _pitch := 0.0
var _mode: InteractMode = InteractMode.FREE
var _held_item: Node3D = null
var _saved_yaw := 0.0
var _saved_pitch := 0.0
var _screen_yaw_center := 0.0
var _screen_pitch_center := 0.0
var _screen_look_range := 0.35
var _exit_frame := -1
const EXIT_COOLDOWN_FRAMES := 10

@onready var camera: Camera3D = $Camera3D
@onready var interact_ray: RayCast3D = $Camera3D/InteractRay
@onready var hold_point: Marker3D = $Camera3D/HoldPoint

var _interact_label: Label = null
var _o2_bar: ProgressBar = null
var _o2_label: Label = null
var _power_label: Label = null


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_build_hud()


func _input(event: InputEvent) -> void:
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseButton and event.pressed:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		return

	if _mode == InteractMode.MINI_GAME:
		return

	if _mode == InteractMode.SCREEN:
		if event is InputEventMouseMotion:
			var m: InputEventMouseMotion = event as InputEventMouseMotion
			camera.rotation.y -= m.relative.x * MOUSE_SENSITIVITY
			camera.rotation.x -= m.relative.y * MOUSE_SENSITIVITY
			camera.rotation.y = clampf(camera.rotation.y, _screen_yaw_center - _screen_look_range, _screen_yaw_center + _screen_look_range)
			camera.rotation.x = clampf(camera.rotation.x, _screen_pitch_center - _screen_look_range, _screen_pitch_center + _screen_look_range)
		if event.is_action_pressed("move_left") or event.is_action_pressed("move_right") or event.is_action_pressed("move_back"):
			exit_screen_mode()
		return

	var in_cooldown: bool = Engine.get_process_frames() - _exit_frame <= EXIT_COOLDOWN_FRAMES

	if event is InputEventMouseMotion and not in_cooldown:
		var m: InputEventMouseMotion = event as InputEventMouseMotion
		_yaw -= m.relative.x * MOUSE_SENSITIVITY
		_pitch -= m.relative.y * MOUSE_SENSITIVITY
		_pitch = clampf(_pitch, -1.4, 1.4)
		rotation.y = _yaw
		camera.rotation.x = _pitch

	if event.is_action_pressed("interact"):
		_try_interact()

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and not in_cooldown:
			_try_click()

	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.pressed and key.keycode == KEY_ESCAPE:
			if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _physics_process(delta: float) -> void:
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8) as float
	if not is_on_floor():
		velocity.y -= gravity * delta

	if _mode != InteractMode.FREE:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		velocity.z = move_toward(velocity.z, 0.0, FRICTION * delta)
		move_and_slide()
		_update_held_item()
		_update_hud()
		return

	var input_dir := Vector3.ZERO
	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.z = Input.get_axis("move_forward", "move_back")
	if input_dir.length() > 1.0:
		input_dir = input_dir.normalized()
	var wish: Vector3 = (transform.basis * input_dir) * MOVE_SPEED

	if is_on_floor():
		if input_dir.length_squared() > 0.001:
			velocity.x = move_toward(velocity.x, wish.x, ACCEL * delta)
			velocity.z = move_toward(velocity.z, wish.z, ACCEL * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
			velocity.z = move_toward(velocity.z, 0.0, FRICTION * delta)
		if Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_VELOCITY

	move_and_slide()
	_update_held_item()
	_update_hud()


func _build_hud() -> void:
	var hud: CanvasLayer = $HUD

	_interact_label = Label.new()
	_interact_label.text = ""
	_interact_label.anchors_preset = Control.PRESET_CENTER
	_interact_label.position = Vector2(940, 560)
	_interact_label.add_theme_font_size_override("font_size", 16)
	_interact_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	_interact_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_interact_label)

	_o2_bar = ProgressBar.new()
	_o2_bar.position = Vector2(20, 10)
	_o2_bar.size = Vector2(200, 24)
	_o2_bar.min_value = 0.0
	_o2_bar.max_value = 1.0
	_o2_bar.value = 1.0
	_o2_bar.show_percentage = false
	_o2_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_o2_bar)

	_o2_label = Label.new()
	_o2_label.position = Vector2(22, 10)
	_o2_label.size = Vector2(196, 24)
	_o2_label.add_theme_font_size_override("font_size", 14)
	_o2_label.add_theme_color_override("font_color", Color.WHITE)
	_o2_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_o2_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_o2_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_o2_label)

	_power_label = Label.new()
	_power_label.text = ""
	_power_label.position = Vector2(20, 40)
	_power_label.add_theme_font_size_override("font_size", 16)
	_power_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	_power_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_power_label)


func _update_hud() -> void:
	if _o2_bar:
		_o2_bar.value = O2Manager.o2_level
		_o2_bar.visible = not O2Manager.is_retired
	if _o2_label:
		_o2_label.visible = not O2Manager.is_retired
		var seconds_left: float = O2Manager.o2_level * O2Manager.get_max_duration()
		_o2_label.text = "O2  %d:%02d" % [int(seconds_left) / 60, int(seconds_left) % 60]

	if _power_label:
		var supply: float = PowerManager.supply
		var demand: float = PowerManager.get_total_demand()
		_power_label.text = "Power: %.0f / %.0fW" % [demand, supply]
		if PowerManager.is_brownout:
			_power_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		else:
			_power_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))

	if _interact_label:
		if interact_ray.is_colliding():
			var collider: Object = interact_ray.get_collider()
			if collider and collider.has_method("interact"):
				_interact_label.text = "[E] " + (collider as Node).name
			elif collider and collider.has_method("receive_item") and _held_item:
				_interact_label.text = "[Click] Place"
			elif collider is Node and (collider as Node).is_in_group("carriable") and not _held_item:
				_interact_label.text = "[Click] Pick up"
			else:
				_interact_label.text = ""
		else:
			_interact_label.text = ""


func _update_held_item() -> void:
	if _held_item and is_instance_valid(_held_item):
		var target: Vector3 = hold_point.global_transform.origin
		_held_item.global_position = _held_item.global_position.lerp(target, 0.2)
		_held_item.global_rotation = camera.global_rotation


func _try_interact() -> void:
	if not interact_ray.is_colliding():
		return
	var collider: Object = interact_ray.get_collider()
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
	var collider: Object = interact_ray.get_collider()
	if collider is Node and (collider as Node).is_in_group("carriable"):
		pickup_item(collider as Node3D)


func pickup_item(item: Node3D) -> void:
	if _held_item:
		return
	_held_item = item
	if item is RigidBody3D:
		(item as RigidBody3D).freeze = true
	StationUtils.set_item_collision(item, false)
	item.global_position = hold_point.global_transform.origin
	SoundManager.play("item_pickup")


func _try_place_item() -> void:
	if not _held_item:
		return
	if interact_ray.is_colliding():
		var collider: Object = interact_ray.get_collider()
		if collider and collider.has_method("receive_item"):
			if collider.receive_item(_held_item):
				_held_item = null
				SoundManager.play("item_place")
				return
	var place_pos: Vector3 = hold_point.global_transform.origin + (-camera.global_transform.basis.z * 0.3)
	_held_item.global_position = place_pos
	if _held_item is RigidBody3D:
		(_held_item as RigidBody3D).freeze = false
	StationUtils.set_item_collision(_held_item, true)
	_held_item = null
	SoundManager.play("item_place")


func drop_held_item() -> void:
	if _held_item and is_instance_valid(_held_item):
		if _held_item is RigidBody3D:
			(_held_item as RigidBody3D).freeze = false
		StationUtils.set_item_collision(_held_item, true)
		_held_item = null


func detach_held_item() -> Node3D:
	var item: Node3D = _held_item
	_held_item = null
	return item


func get_held_item() -> Node3D:
	return _held_item


func has_held_item() -> bool:
	return _held_item != null and is_instance_valid(_held_item)


func _set_world_labels_visible(vis: bool) -> void:
	for label in get_tree().get_nodes_in_group("world_label"):
		(label as Node3D).visible = vis
	if _interact_label:
		_interact_label.visible = vis


func enter_mini_game(cam_transform: Transform3D) -> void:
	if _mode != InteractMode.FREE:
		return
	_mode = InteractMode.MINI_GAME
	_saved_yaw = _yaw
	_saved_pitch = _pitch
	camera.global_transform = cam_transform
	_set_world_labels_visible(false)


func enter_screen_mode(look_target: Vector3, cam_pos: Vector3, look_range: float = 0.35) -> void:
	if _mode != InteractMode.FREE:
		return
	_mode = InteractMode.SCREEN
	_saved_yaw = _yaw
	_saved_pitch = _pitch
	_screen_look_range = look_range
	camera.global_position = cam_pos
	camera.look_at(look_target, Vector3.UP)
	_screen_yaw_center = camera.rotation.y
	_screen_pitch_center = camera.rotation.x
	_set_world_labels_visible(false)


func exit_screen_mode() -> void:
	_restore_camera()


func exit_mini_game() -> void:
	_restore_camera()


func _restore_camera() -> void:
	if _mode == InteractMode.FREE:
		return
	_mode = InteractMode.FREE
	_exit_frame = Engine.get_process_frames()
	_yaw = _saved_yaw
	_pitch = _saved_pitch
	rotation.y = _yaw
	camera.position = Vector3(0, 1.7, 0)
	camera.rotation = Vector3(_pitch, 0, 0)
	_set_world_labels_visible(true)
