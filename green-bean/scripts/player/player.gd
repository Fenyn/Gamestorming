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
var _screen_yaw_center := 0.0
var _screen_pitch_center := 0.0
var _saved_yaw := 0.0
var _saved_pitch := 0.0
const SCREEN_LOOK_RANGE := 0.35

@onready var camera: Camera3D = $Camera3D
@onready var interact_ray: RayCast3D = $Camera3D/InteractRay
@onready var hold_point: Marker3D = $Camera3D/HoldPoint
@onready var crosshair: CenterContainer = $HUD/Crosshair

var _timer_label: Label = null
var _money_label: Label = null
var _interact_label: Label = null
var _recipe_label: Label = null
var _end_panel: PanelContainer = null
var _day_ended := false
var _active_order: OrderData = null

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_build_hud()
	EventBus.day_ended.connect(_on_day_ended)
	EventBus.ticket_printed.connect(_on_ticket_printed)
	EventBus.drink_handed_off.connect(_on_drink_handed_off)

func _input(event: InputEvent) -> void:
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseButton and event.pressed:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		return

	if _mode == InteractMode.MINI_GAME:
		return

	if _mode == InteractMode.SCREEN:
		if event is InputEventMouseMotion:
			var m := event as InputEventMouseMotion
			camera.rotation.y -= m.relative.x * MOUSE_SENSITIVITY
			camera.rotation.x -= m.relative.y * MOUSE_SENSITIVITY
			camera.rotation.y = clampf(camera.rotation.y, _screen_yaw_center - SCREEN_LOOK_RANGE, _screen_yaw_center + SCREEN_LOOK_RANGE)
			camera.rotation.x = clampf(camera.rotation.x, _screen_pitch_center - SCREEN_LOOK_RANGE, _screen_pitch_center + SCREEN_LOOK_RANGE)
		return

	if event is InputEventMouseMotion:
		var m := event as InputEventMouseMotion
		_yaw -= m.relative.x * MOUSE_SENSITIVITY
		_pitch -= m.relative.y * MOUSE_SENSITIVITY
		_pitch = clampf(_pitch, -1.4, 1.4)
		rotation.y = _yaw
		camera.rotation.x = _pitch

	if event.is_action_pressed("interact"):
		_try_interact()

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_try_click()

func _physics_process(delta: float) -> void:
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
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
	var wish := (transform.basis * input_dir) * MOVE_SPEED

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
	var hud := $HUD

	_timer_label = Label.new()
	_timer_label.text = "3:00"
	_timer_label.position = Vector2(20, 10)
	_timer_label.add_theme_font_size_override("font_size", 28)
	_timer_label.add_theme_color_override("font_color", Color.WHITE)
	hud.add_child(_timer_label)

	_money_label = Label.new()
	_money_label.text = "$0.00"
	_money_label.position = Vector2(20, 45)
	_money_label.add_theme_font_size_override("font_size", 22)
	_money_label.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
	hud.add_child(_money_label)

	_interact_label = Label.new()
	_interact_label.text = ""
	_interact_label.anchors_preset = Control.PRESET_CENTER
	_interact_label.position = Vector2(940, 560)
	_interact_label.add_theme_font_size_override("font_size", 16)
	_interact_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	hud.add_child(_interact_label)

	_recipe_label = Label.new()
	_recipe_label.text = ""
	_recipe_label.anchor_left = 1.0
	_recipe_label.anchor_right = 1.0
	_recipe_label.offset_left = -280
	_recipe_label.offset_right = -20
	_recipe_label.offset_top = 10
	_recipe_label.add_theme_font_size_override("font_size", 14)
	_recipe_label.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	hud.add_child(_recipe_label)

func _update_hud() -> void:
	if _timer_label:
		var t := GameManager.get_time_remaining()
		var mins := int(t) / 60
		var secs := int(t) % 60
		_timer_label.text = "%d:%02d" % [mins, secs]
		if t < 30:
			_timer_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))

	if _money_label:
		_money_label.text = "$%.2f" % GameManager.total_earned

	if _interact_label:
		if interact_ray.is_colliding():
			var collider := interact_ray.get_collider()
			if _held_item is Pitcher and collider is Cup:
				_interact_label.text = "[Click] Pour milk"
			elif collider and collider.has_method("interact"):
				_interact_label.text = "[E] " + collider.name
			elif collider and collider.has_method("receive_item") and _held_item:
				_interact_label.text = "[Click] Place"
			elif collider and collider.is_in_group("carriable") and not _held_item:
				_interact_label.text = "[Click] Pick up"
			else:
				_interact_label.text = ""
		else:
			_interact_label.text = ""

	if _recipe_label:
		_recipe_label.text = _get_recipe_text()

func _update_held_item() -> void:
	if _held_item and is_instance_valid(_held_item):
		var target := hold_point.global_transform.origin
		_held_item.global_position = _held_item.global_position.lerp(target, 0.2)
		_held_item.global_rotation = camera.global_rotation

func _try_interact() -> void:
	if not interact_ray.is_colliding():
		return
	var collider := interact_ray.get_collider()
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
	var collider := interact_ray.get_collider()
	if collider and collider.is_in_group("carriable"):
		pickup_item(collider)

func pickup_item(item: Node3D) -> void:
	if _held_item:
		return
	_held_item = item
	if item is RigidBody3D:
		(item as RigidBody3D).freeze = true
	_set_item_collision(item, false)
	item.global_position = hold_point.global_transform.origin

func _try_place_item() -> void:
	if not _held_item:
		return
	if interact_ray.is_colliding():
		var collider := interact_ray.get_collider()
		# Pitcher + Cup interaction: pour milk
		if _held_item is Pitcher and collider is Cup:
			var cup := collider as Cup
			if cup.pour_milk_from(_held_item as Pitcher):
				return
		if collider and collider.has_method("receive_item"):
			if collider.receive_item(_held_item):
				_held_item = null
				return
	var place_pos := hold_point.global_transform.origin + (-camera.global_transform.basis.z * 0.3)
	_held_item.global_position = place_pos
	if _held_item is RigidBody3D:
		(_held_item as RigidBody3D).freeze = false
	_set_item_collision(_held_item, true)
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

func _set_item_collision(item: Node3D, enabled: bool) -> void:
	for child in item.get_children():
		if child is CollisionShape3D:
			child.disabled = not enabled

func _on_ticket_printed(data: Dictionary) -> void:
	_active_order = data["order"] as OrderData

func _on_drink_handed_off(_data: Dictionary, _earned: float) -> void:
	_active_order = null

func _get_recipe_text() -> String:
	if not _active_order:
		return ""
	var cup := _find_active_cup()
	var lines: Array[String] = []
	var code := _active_order.ticket_code
	match _active_order.drink_type:
		DrinkData.DrinkType.POUR_OVER:
			lines.append("[%s] Pour Over" % code)
			lines.append(_step("Grab cup from stack", cup != null))
			lines.append(_step("Pick up dripper", false))
			lines.append(_step("Grind beans (coarse)", _check_grounds_ready(DrinkData.GrindLevel.COARSE)))
			lines.append(_step("Place dripper + cup at station", false))
			lines.append(_step("Pour water (saturation)", cup != null and cup.has_pour_over_coffee))
			lines.append(_step("Wait for draw-down", cup != null and cup.has_pour_over_coffee))
			lines.append(_step("Hand off drink", false))
		DrinkData.DrinkType.AMERICANO:
			lines.append("[%s] Americano" % code)
			lines.append(_step("Grab cup from stack", cup != null))
			lines.append(_step("Pick up aeropress", false))
			lines.append(_step("Grind beans (fine)", _check_grounds_ready(DrinkData.GrindLevel.FINE)))
			lines.append(_step("Place aeropress + cup at station", false))
			lines.append(_step("Pour water into chamber", cup != null and cup.has_shot))
			lines.append(_step("Stir", cup != null and cup.has_shot))
			lines.append(_step("Wait for steep", cup != null and cup.has_shot))
			lines.append(_step("Press shot", cup != null and cup.has_shot))
			lines.append(_step("Add hot water", cup != null and cup.has_hot_water))
			lines.append(_step("Hand off drink", false))
		DrinkData.DrinkType.LATTE:
			lines.append("[%s] Latte" % code)
			lines.append(_step("Grab cup from stack", cup != null))
			lines.append(_step("Pull aeropress shot into cup", cup != null and cup.has_shot))
			lines.append(_step("Pick up pitcher", false))
			lines.append(_step("Get milk from fridge", false))
			lines.append(_step("Steam milk", false))
			lines.append(_step("Pour milk into cup", cup != null and cup.has_steamed_milk))
			lines.append(_step("Hand off drink", false))
	return "\n".join(lines)

func _step(text: String, done: bool) -> String:
	return ("  [x] " if done else "  [ ] ") + text

func _find_active_cup() -> Cup:
	for node in get_tree().get_nodes_in_group("cup"):
		if node is Cup and node.order == _active_order:
			return node
	return null

func _check_grounds_ready(_level: DrinkData.GrindLevel) -> bool:
	return false

func enter_mini_game(cam_transform: Transform3D) -> void:
	_mode = InteractMode.MINI_GAME
	camera.global_transform = cam_transform

func enter_screen_mode(look_target: Vector3, cam_pos: Vector3) -> void:
	_mode = InteractMode.SCREEN
	_saved_yaw = _yaw
	_saved_pitch = _pitch
	camera.global_position = cam_pos
	camera.look_at(look_target, Vector3.UP)
	_screen_yaw_center = camera.rotation.y
	_screen_pitch_center = camera.rotation.x

func exit_screen_mode() -> void:
	_mode = InteractMode.FREE
	_yaw = _saved_yaw
	_pitch = _saved_pitch
	rotation.y = _yaw
	camera.rotation.x = _pitch
	camera.position = Vector3(0, 1.7, 0)
	camera.rotation.y = 0
	camera.rotation.z = 0

func exit_mini_game() -> void:
	_mode = InteractMode.FREE
	camera.rotation.x = _pitch
	rotation.y = _yaw

func _on_day_ended() -> void:
	_day_ended = true
	var hud := $HUD

	_end_panel = PanelContainer.new()
	_end_panel.anchors_preset = Control.PRESET_CENTER
	_end_panel.anchor_left = 0.5
	_end_panel.anchor_top = 0.5
	_end_panel.anchor_right = 0.5
	_end_panel.anchor_bottom = 0.5
	_end_panel.offset_left = -200
	_end_panel.offset_top = -150
	_end_panel.offset_right = 200
	_end_panel.offset_bottom = 150

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.06, 0.92)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 30
	style.content_margin_bottom = 30
	_end_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var title := Label.new()
	title.text = "DAY OVER"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.6))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 20
	vbox.add_child(spacer)

	var grade := Label.new()
	grade.text = "Grade: %s" % GameManager.get_grade()
	grade.add_theme_font_size_override("font_size", 48)
	grade.add_theme_color_override("font_color", Color.WHITE)
	grade.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(grade)

	var earnings := Label.new()
	earnings.text = "$%.2f / $%.2f" % [GameManager.total_earned, GameManager.total_possible_earnings]
	earnings.add_theme_font_size_override("font_size", 22)
	earnings.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
	earnings.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(earnings)

	var customers := Label.new()
	customers.text = "%d served / %d lost" % [GameManager.customers_served, GameManager.customers_lost]
	customers.add_theme_font_size_override("font_size", 18)
	customers.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	customers.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(customers)

	_end_panel.add_child(vbox)
	hud.add_child(_end_panel)
