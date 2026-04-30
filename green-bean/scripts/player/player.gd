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
var _screen_look_range := 0.35
var _exit_frame := -1
const EXIT_COOLDOWN_FRAMES := 10

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
			camera.rotation.y = clampf(camera.rotation.y, _screen_yaw_center - _screen_look_range, _screen_yaw_center + _screen_look_range)
			camera.rotation.x = clampf(camera.rotation.x, _screen_pitch_center - _screen_look_range, _screen_pitch_center + _screen_look_range)
		if event.is_action_pressed("move_left") or event.is_action_pressed("move_right") or event.is_action_pressed("move_back"):
			exit_screen_mode()
		return

	var in_cooldown := Engine.get_process_frames() - _exit_frame <= EXIT_COOLDOWN_FRAMES

	if event is InputEventMouseMotion and not in_cooldown:
		var m := event as InputEventMouseMotion
		_yaw -= m.relative.x * MOUSE_SENSITIVITY
		_pitch -= m.relative.y * MOUSE_SENSITIVITY
		_pitch = clampf(_pitch, -1.4, 1.4)
		rotation.y = _yaw
		camera.rotation.x = _pitch

	if event.is_action_pressed("interact"):
		_try_interact()

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not in_cooldown:
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
	_timer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_timer_label)

	_money_label = Label.new()
	_money_label.text = "$0.00"
	_money_label.position = Vector2(20, 45)
	_money_label.add_theme_font_size_override("font_size", 22)
	_money_label.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
	_money_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_money_label)

	_interact_label = Label.new()
	_interact_label.text = ""
	_interact_label.anchors_preset = Control.PRESET_CENTER
	_interact_label.position = Vector2(940, 560)
	_interact_label.add_theme_font_size_override("font_size", 16)
	_interact_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	_interact_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	_recipe_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
			elif _held_item is MilkJug and collider is Pitcher:
				_interact_label.text = "[Click] Pour into pitcher"
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
		print("[Interact] Ray not colliding with anything")
		return
	var collider := interact_ray.get_collider()
	print("[Interact] Hit: ", collider.name, " type=", collider.get_class(), " has_interact=", collider.has_method("interact"))
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
		# Pitcher + Cup interaction: pour steamed milk
		if _held_item is Pitcher and collider is Cup:
			var cup := collider as Cup
			if cup.pour_milk_from(_held_item as Pitcher):
				return
		# Milk jug + Pitcher interaction: pour milk into pitcher
		if _held_item is MilkJug and collider is Pitcher:
			var pitcher := collider as Pitcher
			if not pitcher.has_milk:
				pitcher.fill_milk()
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

func _set_world_labels_visible(vis: bool) -> void:
	for label in get_tree().get_nodes_in_group("world_label"):
		(label as Node3D).visible = vis
	if _interact_label:
		_interact_label.visible = vis

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
	var held_dev := _find_active_device()
	var any_dev := _find_device_anywhere()
	var lines: Array[String] = []
	var code := _active_order.ticket_code
	var holding_dev := held_dev != null
	var dev := any_dev if any_dev else held_dev
	var dev_has_grounds := dev != null and dev.has_grounds()
	var dev_has_water := dev != null and dev.has_water
	var dev_stirred := dev != null and dev.is_stirred

	match _active_order.drink_type:
		DrinkData.DrinkType.POUR_OVER:
			var drip := _find_active_dripper()
			var drip_has_grounds := drip != null and drip.has_grounds()
			var po_checks: Array[bool] = [
				cup != null,
				drip != null,
				drip_has_grounds,
				false,
				cup != null and cup.has_pour_over_coffee,
				cup != null and cup.has_pour_over_coffee,
				false,
			]
			po_checks = _waterfall(po_checks)
			var po_names := [
				"Grab cup from stack",
				"Pick up dripper",
				"Grind beans (coarse)",
				"Place dripper + cup at station",
				"Pour water (saturation)",
				"Wait for draw-down",
				"Hand off drink",
			]
			lines.append("[%s] Pour Over" % code)
			for i in range(po_names.size()):
				lines.append(_step(po_names[i], po_checks[i]))
		DrinkData.DrinkType.AMERICANO:
			var has_kettle_water := _find_filled_kettle()
			var checks: Array[bool] = [
				cup != null,
				holding_dev or dev_has_grounds,
				dev_has_grounds,
				dev_has_grounds,
				has_kettle_water or dev_has_water,
				dev_has_water,
				dev_stirred,
				cup != null and cup.has_shot,
				cup != null and cup.has_hot_water,
				false,
			]
			checks = _waterfall(checks)
			var step_names := [
				"Grab cup from stack",
				"Pick up aeropress",
				"Grind beans (fine)",
				"Place device + cup at station",
				"Fill kettle at hot water",
				"Pour water into chamber",
				"Stir",
				"Wait for steep + press",
				"Fill kettle + add hot water",
				"Hand off drink",
			]
			lines.append("[%s] Americano" % code)
			for i in range(step_names.size()):
				lines.append(_step(step_names[i], checks[i]))
		DrinkData.DrinkType.LATTE:
			var has_milk_jug_out := _find_milk_jug_out()
			var lt_checks: Array[bool] = [
				cup != null,
				holding_dev or dev_has_grounds,
				cup != null and cup.has_shot,
				has_milk_jug_out,
				_find_active_pitcher_with_milk(),
				_find_steamed_pitcher(),
				cup != null and cup.has_steamed_milk,
				false,
			]
			lt_checks = _waterfall(lt_checks)
			var lt_names := [
				"Grab cup + pull shot",
				"Grind + press into cup",
				"Set cup on counter pad",
				"Get milk jug from fridge",
				"Pour milk into pitcher",
				"Steam milk",
				"Pour milk into cup",
				"Hand off drink",
			]
			lines.append("[%s] Latte" % code)
			for i in range(lt_names.size()):
				lines.append(_step(lt_names[i], lt_checks[i]))
	return "\n".join(lines)

func _waterfall(steps: Array[bool]) -> Array[bool]:
	var highest := -1
	for i in range(steps.size()):
		if steps[i]:
			highest = i
	var result: Array[bool] = []
	for i in range(steps.size()):
		result.append(i <= highest)
	return result

func _step(text: String, done: bool) -> String:
	return ("  [x] " if done else "  [ ] ") + text

func _find_active_cup() -> Cup:
	for node in get_tree().get_nodes_in_group("cup"):
		if node is Cup and node.order == _active_order:
			return node
	return null

func _find_active_device() -> AeropressDevice:
	if _held_item is AeropressDevice:
		return _held_item as AeropressDevice
	return null

func _find_device_anywhere() -> AeropressDevice:
	if _held_item is AeropressDevice:
		return _held_item as AeropressDevice
	for node in get_tree().get_nodes_in_group("aeropress_device"):
		var dev := node as AeropressDevice
		if dev.has_grounds() or dev.has_water or dev.is_stirred:
			return dev
	return null

func _find_active_dripper() -> Dripper:
	if _held_item is Dripper:
		return _held_item as Dripper
	return null

func _find_active_pitcher_with_milk() -> bool:
	for node in get_tree().get_nodes_in_group("pitcher"):
		if node is Pitcher and (node as Pitcher).has_milk:
			return true
	if _held_item is Pitcher and (_held_item as Pitcher).has_milk:
		return true
	return false

func _find_milk_jug_out() -> bool:
	if _held_item is MilkJug:
		return true
	for node in get_tree().get_nodes_in_group("milk_jug"):
		if node is MilkJug and node.visible:
			return true
	return false

func _find_filled_kettle() -> bool:
	if _held_item is Kettle and (_held_item as Kettle).has_water:
		return true
	for node in get_tree().get_nodes_in_group("kettle"):
		if node is Kettle and (node as Kettle).has_water:
			return true
	return false

func _find_steamed_pitcher() -> bool:
	for node in get_tree().get_nodes_in_group("pitcher"):
		if node is Pitcher and (node as Pitcher).is_steamed:
			return true
	if _held_item is Pitcher and (_held_item as Pitcher).is_steamed:
		return true
	return false

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

func exit_screen_mode() -> void:
	_restore_camera()

func exit_mini_game() -> void:
	_restore_camera()

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
