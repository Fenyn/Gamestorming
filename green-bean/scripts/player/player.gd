class_name Player
extends CharacterBody3D

const MOVE_SPEED := 4.5
const JUMP_VELOCITY := 4.0
const ACCEL := 30.0
const FRICTION := 20.0
const MOUSE_SENSITIVITY := 0.002
const INTERACT_DISTANCE := 2.5

enum InteractMode { FREE, MINI_GAME, SCREEN, INFO }

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
var _recipe_container: VBoxContainer = null
var _recipe_title: Label = null
var _recipe_step_labels: Array[Label] = []
var _recipe_step_data: Array[Dictionary] = []
var _recipe_built_for := ""
var _tooltip_panel: PanelContainer = null
var _tooltip_label: Label = null
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
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		if _mode == InteractMode.FREE:
			_enter_info_mode()
		elif _mode == InteractMode.INFO:
			_exit_info_mode()
		get_viewport().set_input_as_handled()
		return

	if _mode == InteractMode.INFO:
		return

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

	if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
		if GameManager.prep_active:
			GameManager.start_day()
			return
		if _day_ended:
			get_tree().reload_current_scene()
			return

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

	_recipe_container = VBoxContainer.new()
	_recipe_container.anchor_left = 1.0
	_recipe_container.anchor_right = 1.0
	_recipe_container.anchor_bottom = 0.5
	_recipe_container.offset_left = -260
	_recipe_container.offset_right = -20
	_recipe_container.offset_top = 10
	_recipe_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_recipe_container)

	_recipe_title = Label.new()
	_recipe_title.add_theme_font_size_override("font_size", 15)
	_recipe_title.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	_recipe_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_recipe_container.add_child(_recipe_title)

	_tooltip_panel = PanelContainer.new()
	_tooltip_panel.visible = false
	_tooltip_panel.anchor_left = 1.0
	_tooltip_panel.anchor_right = 1.0
	_tooltip_panel.offset_left = -580
	_tooltip_panel.offset_right = -275
	_tooltip_panel.offset_top = 10
	_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tip_style := StyleBoxFlat.new()
	tip_style.bg_color = Color(0.08, 0.06, 0.04, 0.92)
	tip_style.set_corner_radius_all(8)
	tip_style.content_margin_left = 16
	tip_style.content_margin_right = 16
	tip_style.content_margin_top = 14
	tip_style.content_margin_bottom = 14
	_tooltip_panel.add_theme_stylebox_override("panel", tip_style)
	_tooltip_label = Label.new()
	_tooltip_label.add_theme_font_size_override("font_size", 14)
	_tooltip_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.78))
	_tooltip_label.add_theme_constant_override("line_spacing", 6)
	_tooltip_panel.add_child(_tooltip_label)
	hud.add_child(_tooltip_panel)

func _update_hud() -> void:
	if _timer_label:
		if GameManager.prep_active:
			_timer_label.text = "PREP"
			_timer_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
		else:
			var t := GameManager.get_time_remaining()
			var mins := int(t) / 60
			var secs := int(t) % 60
			_timer_label.text = "%d:%02d" % [mins, secs]
			if t < 30:
				_timer_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
			else:
				_timer_label.add_theme_color_override("font_color", Color.WHITE)

	if _money_label:
		if GameManager.prep_active:
			_money_label.text = "Bank: $%.2f | Stars: %d\n[Enter] Open shop" % [UnlockManager.money, UnlockManager.stars]
		elif _day_ended:
			_money_label.text = ""
		elif GameManager.total_tips > 0.0:
			_money_label.text = "$%.2f (+$%.2f tips)" % [GameManager.total_earned, GameManager.total_tips]
		else:
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

	_update_recipe_display()
	_process_info_hover()

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
	StationUtils.set_item_collision(item, false)
	item.global_position = hold_point.global_transform.origin
	SoundManager.play("item_pickup")

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
				SoundManager.play("item_place")
				return
	var place_pos := hold_point.global_transform.origin + (-camera.global_transform.basis.z * 0.3)
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
	var item := _held_item
	_held_item = null
	return item

func get_held_item() -> Node3D:
	return _held_item

func has_held_item() -> bool:
	return _held_item != null and is_instance_valid(_held_item)

func get_active_order() -> OrderData:
	return _active_order

func _set_world_labels_visible(vis: bool) -> void:
	for label in get_tree().get_nodes_in_group("world_label"):
		(label as Node3D).visible = vis
	if _interact_label:
		_interact_label.visible = vis


func _on_ticket_printed(data: Dictionary) -> void:
	_active_order = data["order"] as OrderData

func _on_drink_handed_off(data: Dictionary) -> void:
	_active_order = null
	var order: OrderData = data.get("order")
	var stars: float = data.get("stars", 0.0)
	var tip: float = data.get("tip", 0.0)
	_show_review_popup(stars, tip, order)

func _show_review_popup(stars: float, tip: float, order: OrderData = null) -> void:
	var hud := $HUD

	var container := VBoxContainer.new()
	container.anchors_preset = Control.PRESET_CENTER
	container.anchor_left = 0.5
	container.anchor_right = 0.5
	container.anchor_top = 0.4
	container.anchor_bottom = 0.4
	container.offset_left = -160
	container.offset_right = 160
	container.add_theme_constant_override("separation", 4)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var star_label := Label.new()
	star_label.text = "%.1f / 5" % stars
	if tip > 0.0:
		star_label.text += "   +$%.2f tip!" % tip
	star_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	star_label.add_theme_font_size_override("font_size", 42)
	star_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var star_color := Color(1.0, 0.2, 0.2)
	if stars >= 5.0: star_color = Color(1.0, 0.85, 0.0)
	elif stars >= 4.0: star_color = Color(0.3, 0.9, 0.3)
	elif stars >= 3.0: star_color = Color(1.0, 1.0, 1.0)
	elif stars >= 2.0: star_color = Color(1.0, 0.6, 0.2)
	star_label.add_theme_color_override("font_color", star_color)
	container.add_child(star_label)

	if order:
		var breakdown := _build_quality_breakdown(order)
		if not breakdown.is_empty():
			var detail := Label.new()
			detail.text = breakdown
			detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			detail.add_theme_font_size_override("font_size", 16)
			detail.add_theme_color_override("font_color", Color(0.85, 0.82, 0.7))
			detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
			container.add_child(detail)

	hud.add_child(container)
	var tween := create_tween()
	tween.tween_interval(2.5)
	tween.tween_property(container, "modulate:a", 0.0, 1.0)
	tween.tween_callback(container.queue_free)

func _build_quality_breakdown(order: OrderData) -> String:
	var lines: Array[String] = []
	if order.grind_quality >= 0.0:
		lines.append("Grind: %s" % _quality_tag(order.grind_quality))
	if not order.correct_grind_level:
		lines.append("Wrong grind level!")
	if order.brew_quality >= 0.0 and DrinkData.has_step(order.drink_type, DrinkData.Step.AEROPRESS_BREW):
		lines.append("Extraction: %s" % _quality_tag(order.brew_quality))
	if order.pour_quality >= 0.0 and DrinkData.has_step(order.drink_type, DrinkData.Step.POUR_OVER_BREW):
		lines.append("Pour: %s" % _quality_tag(order.pour_quality))
	if order.pour_quality >= 0.0 and DrinkData.has_step(order.drink_type, DrinkData.Step.HOT_WATER):
		lines.append("Water: %s" % _quality_tag(order.pour_quality))
	if order.steam_quality >= 0.0 and DrinkData.has_step(order.drink_type, DrinkData.Step.STEAM_MILK):
		lines.append("Steam: %s" % _quality_tag(order.steam_quality))
	if order.syrup_quality >= 0.0 and order.requested_syrup >= 0:
		lines.append("Syrup: %s" % _quality_tag(order.syrup_quality))
	if order.sauce_quality >= 0.0 and order.has_sauce():
		lines.append("Sauce: %s" % _quality_tag(order.sauce_quality))
	return "  |  ".join(lines)

func _quality_tag(q: float) -> String:
	var pct := int(q * 100)
	if q >= 0.95: return "%d%% perfect" % pct
	if q >= 0.80: return "%d%% good" % pct
	if q >= 0.60: return "%d%% ok" % pct
	if q >= 0.40: return "%d%% rough" % pct
	return "%d%% bad" % pct

func _update_recipe_display() -> void:
	if not _active_order:
		if not _recipe_built_for.is_empty():
			_clear_recipe_labels()
			_recipe_title.text = ""
			_recipe_built_for = ""
		_tooltip_panel.visible = false
		return

	var order_key := _active_order.ticket_code
	if order_key != _recipe_built_for:
		_rebuild_recipe_labels()
		_recipe_built_for = order_key

	_refresh_recipe_checks()

func _clear_recipe_labels() -> void:
	for lbl in _recipe_step_labels:
		lbl.queue_free()
	_recipe_step_labels.clear()
	_recipe_step_data.clear()

func _rebuild_recipe_labels() -> void:
	_clear_recipe_labels()

	var drink_name := DrinkData.get_drink_name(_active_order.drink_type)
	_recipe_title.text = "[%s] %s  (Tab: info)" % [_active_order.ticket_code, drink_name]

	_recipe_step_data = []
	_recipe_step_data.append({"name": "Grab cup", "step": -1, "tip": ""})

	var recipe_steps: Array = DrinkData.get_recipe(_active_order.drink_type)["steps"]
	for s in recipe_steps:
		var step := s as DrinkData.Step
		var sname := DrinkData.get_step_name(step, _active_order.drink_type)
		if sname.is_empty():
			continue
		_recipe_step_data.append({
			"name": sname,
			"step": step,
			"tip": DrinkData.get_step_tooltip(step),
		})

	if _active_order.has_syrup():
		var syn := DrinkData.get_syrup_name(_active_order.requested_syrup as DrinkData.SyrupType)
		_recipe_step_data.append({
			"name": "Add %s syrup" % syn,
			"step": DrinkData.Step.ADD_SYRUP,
			"tip": "1.  Place cup at syrup station\n2.  [E] to start pumping\n3.  Hold click ~0.8s per pump\n4.  Match target pump count for size",
		})

	if _active_order.requested_sauce >= 0 and not DrinkData.has_step(_active_order.drink_type, DrinkData.Step.ADD_SAUCE):
		var san := DrinkData.get_sauce_name(_active_order.requested_sauce as DrinkData.SauceType)
		_recipe_step_data.append({
			"name": "Add %s sauce" % san,
			"step": DrinkData.Step.ADD_SAUCE,
			"tip": DrinkData.get_step_tooltip(DrinkData.Step.ADD_SAUCE),
		})

	_recipe_step_data.append({"name": "Add lid", "step": DrinkData.Step.LID, "tip": "Hold cup, [E] at lid dispenser"})
	_recipe_step_data.append({"name": "Hand off", "step": -2, "tip": "Place finished cup on hand-off counter"})

	var in_info := _mode == InteractMode.INFO
	for entry in _recipe_step_data:
		var lbl := Label.new()
		lbl.text = "  [ ] %s" % entry["name"]
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.mouse_filter = Control.MOUSE_FILTER_PASS if in_info else Control.MOUSE_FILTER_IGNORE
		if not (entry["tip"] as String).is_empty():
			lbl.set_meta("step_tooltip", entry["tip"])
		_recipe_container.add_child(lbl)
		_recipe_step_labels.append(lbl)

func _refresh_recipe_checks() -> void:
	var cup := _find_active_cup()
	var checks: Array[bool] = []
	for entry in _recipe_step_data:
		var step_id: int = entry["step"]
		var done := false
		match step_id:
			-1: done = cup != null
			-2: done = false
			_: done = _is_step_done(step_id as DrinkData.Step, cup)
		checks.append(done)

	var highest := -1
	for i in range(checks.size()):
		if checks[i]:
			highest = i

	for i in range(_recipe_step_labels.size()):
		var done := i <= highest
		var check := "x" if done else " "
		_recipe_step_labels[i].text = "  [%s] %s" % [check, _recipe_step_data[i]["name"]]
		var color := Color(0.5, 0.7, 0.5) if done else Color(1, 0.95, 0.8)
		_recipe_step_labels[i].add_theme_color_override("font_color", color)

func _is_step_done(step: DrinkData.Step, cup: Cup) -> bool:
	if cup == null:
		return false
	match step:
		DrinkData.Step.AEROPRESS_BREW: return cup.has_shot
		DrinkData.Step.POUR_OVER_BREW: return cup.has_pour_over_coffee
		DrinkData.Step.HOT_WATER: return cup.has_hot_water
		DrinkData.Step.STEAM_MILK: return cup.has_steamed_milk
		DrinkData.Step.ADD_SAUCE: return cup.has_sauce
		DrinkData.Step.ADD_SYRUP: return cup.syrup_pumps > 0.0
		DrinkData.Step.LID: return cup.has_lid
	return false

func _find_active_cup() -> Cup:
	for node in get_tree().get_nodes_in_group("cup"):
		if node is Cup and node.order == _active_order:
			return node
	return null

func _enter_info_mode() -> void:
	if _mode != InteractMode.FREE:
		return
	_mode = InteractMode.INFO
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	for lbl in _recipe_step_labels:
		lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	_recipe_container.mouse_filter = Control.MOUSE_FILTER_PASS

func _exit_info_mode() -> void:
	if _mode != InteractMode.INFO:
		return
	_mode = InteractMode.FREE
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_tooltip_panel.visible = false
	for lbl in _recipe_step_labels:
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_recipe_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process_info_hover() -> void:
	if _mode != InteractMode.INFO:
		return
	var mouse_pos := get_viewport().get_mouse_position()
	var found_tip := false
	for lbl in _recipe_step_labels:
		if not lbl.has_meta("step_tooltip"):
			continue
		var rect := lbl.get_global_rect()
		if rect.has_point(mouse_pos):
			var tip_text: String = lbl.get_meta("step_tooltip")
			_tooltip_label.text = tip_text
			_tooltip_panel.offset_top = lbl.global_position.y
			_tooltip_panel.visible = true
			found_tip = true
			break
	if not found_tip:
		_tooltip_panel.visible = false

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

	var avg_stars := GameManager.get_average_stars()
	var stars_label := Label.new()
	stars_label.text = "%.1f / 5 avg  (%d drinks)" % [avg_stars, GameManager.drinks_reviewed]
	stars_label.add_theme_font_size_override("font_size", 22)
	stars_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	stars_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stars_label)

	var revenue := GameManager.total_earned
	var spent := GameManager.total_spent
	var profit := GameManager.get_profit()
	var profit_parts: Array[String] = []
	profit_parts.append("Revenue: $%.2f" % revenue)
	if GameManager.total_tips > 0.0:
		profit_parts[-1] += " (incl $%.2f tips)" % GameManager.total_tips
	if spent > 0.0:
		profit_parts.append("Supplies: -$%.2f" % spent)
	profit_parts.append("Profit: $%.2f" % profit)

	var earnings := Label.new()
	earnings.text = "\n".join(profit_parts)
	earnings.add_theme_font_size_override("font_size", 16)
	earnings.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5) if profit >= 0 else Color(1.0, 0.3, 0.3))
	earnings.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(earnings)

	var customers := Label.new()
	customers.text = "%d served / %d lost" % [GameManager.customers_served, GameManager.customers_lost]
	customers.add_theme_font_size_override("font_size", 16)
	customers.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	customers.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(customers)

	var star_earned := int(GameManager.total_stars)
	var bank := Label.new()
	bank.text = "+%d stars earned | Bank: $%.2f | Stars: %d" % [star_earned, UnlockManager.money, UnlockManager.stars]
	bank.add_theme_font_size_override("font_size", 14)
	bank.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	bank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(bank)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size.y = 10
	vbox.add_child(spacer2)

	var cont := Label.new()
	cont.text = "[Enter] Next Day"
	cont.add_theme_font_size_override("font_size", 18)
	cont.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
	cont.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(cont)

	_end_panel.add_child(vbox)
	hud.add_child(_end_panel)
