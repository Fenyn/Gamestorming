class_name Player
extends CharacterBody3D

const MOVE_SPEED := 4.5
const JUMP_VELOCITY := 4.0
const ACCEL := 30.0
const FRICTION := 20.0
const MOUSE_SENSITIVITY := 0.002
const INTERACT_DISTANCE := 2.5
const HOVER_SHADER := preload("res://assets/shaders/hover_rim.gdshader")
const CAMERA_ENTER_TIME := 0.25
const CAMERA_EXIT_TIME := 0.25
const LEAVE_ACTIONS: Array[StringName] = [&"interact", &"leave", &"move_back", &"move_left", &"move_right"]
const SWAY_AMOUNT := 5.0
const SWAY_MAX := 0.35
const SWAY_SMOOTH := 12.0
const BOB_FREQ := 9.0
const BOB_HEIGHT := 0.012

enum InteractMode { FREE, MINI_GAME, SCREEN, INFO }

var _yaw := 0.0
var _pitch := 0.0
var _mode: InteractMode = InteractMode.FREE
var _held_item: Node3D = null
## Screen mode looks around a fixed view: the offset (yaw, pitch) is applied
## in that view's own frame, so the picture never rolls at steep angles.
var _screen_basis := Basis.IDENTITY
var _screen_offset := Vector2.ZERO
var _screen_yaw_range := Vector2(-0.35, 0.35)
var _screen_pitch_range := Vector2(-0.35, 0.35)
var _saved_yaw := 0.0
var _saved_pitch := 0.0
## A lock that ends defers its camera restore to the end of the frame, so a
## station can hand straight over to the next view (Charge to the drawer,
## water pour to stir) without the camera swinging back in between.
var _restore_pending := false
var _click_queued := false
## Field of view outside close-up work; zooms always return to this.
var _base_fov := 75.0
var _fov_tween: Tween = null
const STATUS_ALERT_MS := 3000

var _camera_tween: Tween = null
var _hover_material: ShaderMaterial = null
var _hovered: Node = null
var _sway := Vector2.ZERO
var _prev_yaw := 0.0
var _prev_pitch := 0.0
var _bob_time := 0.0

@onready var camera: Camera3D = $Camera3D
@onready var interact_ray: RayCast3D = $Camera3D/InteractRay
@onready var hold_point: Marker3D = $Camera3D/HoldPoint
@onready var crosshair: CenterContainer = $HUD/Crosshair

const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
var hud: Hud = null
## The mini-game (or station) that locked the camera; it answers
## get_controls_hint() and get_assist_readout() for the HUD.
var _hud_source: Object = null
## Camera shake from shake(): lens offset that decays, so it never moves the
## camera's transform (mini-game cameras are tweened).
var _shake_amount := 0.0
var _shake_time := 0.0
var _shake_left := 0.0
var _day_ended := false
var _active_order: OrderData = null

func _ready() -> void:
	add_to_group("player")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_base_fov = camera.fov
	_hover_material = ShaderMaterial.new()
	_hover_material.shader = HOVER_SHADER
	hud = HUD_SCENE.instantiate()
	$HUD.add_child(hud)
	EventBus.day_ended.connect(_on_day_ended)
	EventBus.ticket_printed.connect(_on_ticket_printed)
	EventBus.drink_handed_off.connect(_on_drink_handed_off)

## Player sees every event before the stations (it is added last). Anything
## that changes the mode is marked handled here, so the press that opens a
## station never also lands inside it.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("info"):
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

	if _mode == InteractMode.MINI_GAME or _mode == InteractMode.SCREEN:
		if _is_leave_event(event):
			get_viewport().set_input_as_handled()
			_leave_lock()
			return
		# Stations aim from the camera, which is still swinging in.
		if _is_camera_easing() and event.is_action_pressed("use"):
			get_viewport().set_input_as_handled()
			return
		if _mode == InteractMode.SCREEN and event is InputEventMouseMotion:
			var m := event as InputEventMouseMotion
			_screen_offset.x = clampf(_screen_offset.x - m.relative.x * MOUSE_SENSITIVITY, _screen_yaw_range.x, _screen_yaw_range.y)
			_screen_offset.y = clampf(_screen_offset.y - m.relative.y * MOUSE_SENSITIVITY, _screen_pitch_range.x, _screen_pitch_range.y)
			_apply_screen_look()
		return

	if event is InputEventMouseMotion:
		var m := event as InputEventMouseMotion
		_yaw -= m.relative.x * MOUSE_SENSITIVITY
		_pitch = clampf(_pitch - m.relative.y * MOUSE_SENSITIVITY, -1.4, 1.4)
		rotation.y = _yaw
		if not _is_camera_easing():
			camera.rotation.x = _pitch
		return

	if event.is_action_pressed("confirm"):
		if GameManager.prep_active:
			GameManager.start_day()
			get_viewport().set_input_as_handled()
			return
		if _day_ended:
			get_tree().reload_current_scene()
			return

	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_try_interact()
	elif event.is_action_pressed("use"):
		get_viewport().set_input_as_handled()
		# A click while the view is still settling back runs once it lands.
		if _is_camera_easing():
			_click_queued = true
		else:
			_try_click()
	elif event.is_action_pressed("alt_use"):
		_try_alt()

## E, Esc and the back and strafe keys leave any locked view. W does not,
## because it is often still held from walking up.
func _is_leave_event(event: InputEvent) -> bool:
	for action in LEAVE_ACTIONS:
		if event.is_action_pressed(action):
			return true
	return false

func _leave_lock() -> void:
	if is_instance_valid(_hud_source) and _hud_source.has_method("leave"):
		_hud_source.call("leave")
	else:
		_restore_camera()

func _physics_process(delta: float) -> void:
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	if not is_on_floor():
		velocity.y -= gravity * delta

	# The camera is a child of the body, so a body still falling from a jump
	# would drag a locked view off its station.
	if _mode != InteractMode.FREE:
		velocity = Vector3.ZERO
		_apply_screen_look()
		_update_held_item(delta)
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
	_update_held_item(delta)
	_update_hud()

## Short camera jolt in metres of lens offset, for thumps and completions.
func shake(amount: float = 0.004, duration: float = 0.18) -> void:
	_shake_amount = maxf(_shake_amount if _shake_left > 0.0 else 0.0, amount)
	_shake_time = duration
	_shake_left = duration

func _update_shake(delta: float) -> void:
	if _shake_left <= 0.0:
		return
	_shake_left -= delta
	var k := clampf(_shake_left / maxf(_shake_time, 0.001), 0.0, 1.0)
	if _shake_left <= 0.0:
		camera.h_offset = 0.0
		camera.v_offset = 0.0
		return
	camera.h_offset = randf_range(-1.0, 1.0) * _shake_amount * k
	camera.v_offset = randf_range(-1.0, 1.0) * _shake_amount * k

func _update_hud() -> void:
	if GameManager.prep_active:
		hud.set_prep(true)
	else:
		hud.set_prep(false)
		hud.set_clock(GameManager.get_time_remaining())
	hud.set_till(GameManager.total_earned)

	_update_hover_highlight()
	_update_station_status()
	_update_prompt()
	_update_mini_game_help()
	_update_shake(get_physics_process_delta_time())
	hud.ticket.show_order(_active_order)
	hud.ticket.refresh(_find_active_cup())

## The prompt under the crosshair: the looked-at thing's name and what the
## keys do there. A station's own status line is more specific than a generic
## verb, so it is used when the station has one.
func _update_prompt() -> void:
	if not interact_ray.is_colliding():
		hud.clear_prompt()
		return
	var collider := interact_ray.get_collider()
	var title := StationUtils.display_name(collider) if collider else ""
	var hint := ""
	var status := _status_text(collider)
	if collider and collider.has_method("get_prompt"):
		status = str(collider.call("get_prompt"))
		if collider is Customer:
			title = (collider as Customer).profile.display_name
	if _held_item is Pitcher and collider is Cup:
		hint = "[Click] Pour milk"
	elif _held_item is MilkJug and collider is Pitcher:
		hint = "[Click] Pour milk in"
	elif not status.is_empty():
		hint = status
	elif collider and collider.has_method("interact"):
		hint = "[E] Use"
	elif collider and collider.has_method("take_item") and not _held_item:
		hint = "[Click] Pick up"
	elif collider and collider.has_method("receive_item") and _held_item:
		hint = "[Click] Set down"
	elif collider and collider.is_in_group("carriable") and not _held_item:
		hint = "[Click] Pick up"
	else:
		title = ""
	hud.set_prompt(title, hint)

func _status_text(node: Object) -> String:
	if not (node is Node):
		return ""
	for child in (node as Node).get_children():
		if child is Label3D and child.is_in_group("station_status"):
			return (child as Label3D).text
	return ""

func _update_mini_game_help() -> void:
	var locked := _mode == InteractMode.MINI_GAME or _mode == InteractMode.SCREEN
	var source := _hud_source if locked and is_instance_valid(_hud_source) else null
	var hint := ""
	var readout := ""
	if source:
		if GameSettings.control_hints and source.has_method("get_controls_hint"):
			hint = str(source.call("get_controls_hint"))
		if GameSettings.assist_readouts and source.has_method("get_assist_readout"):
			readout = str(source.call("get_assist_readout"))
	hud.set_mini_game_help(hint, readout)

## A station's status shows in the HUD prompt while you look at it. Elsewhere
## its world label pops up for STATUS_ALERT_MS when the text changes, so
## alerts ("[E] Press") reach you from across the shop.
func _update_station_status() -> void:
	var now := Time.get_ticks_msec()
	var looked_at: Object = interact_ray.get_collider() if interact_ray.is_colliding() else null
	for node in get_tree().get_nodes_in_group("station_status"):
		var label := node as Label3D
		if label.text != str(label.get_meta("last_text", "")):
			if label.has_meta("last_text"):
				label.set_meta("alert_until", now + STATUS_ALERT_MS)
			label.set_meta("last_text", label.text)
		if _mode != InteractMode.FREE or label.get_parent() == looked_at:
			label.visible = false
			label.transparency = 1.0
			continue
		var show := label.text != "" and int(label.get_meta("alert_until", 0)) > now
		label.transparency = move_toward(label.transparency, 0.0 if show else 1.0, 0.12)
		label.visible = label.transparency < 0.99

func _update_held_item(delta: float) -> void:
	# Look sway: the held item lags behind fast turns, then settles.
	var yaw_delta := wrapf(_yaw - _prev_yaw, -PI, PI)
	var pitch_delta := _pitch - _prev_pitch
	_prev_yaw = _yaw
	_prev_pitch = _pitch
	var sway_target := Vector2(-yaw_delta, -pitch_delta) * SWAY_AMOUNT
	sway_target = sway_target.limit_length(SWAY_MAX)
	_sway = _sway.lerp(sway_target, 1.0 - exp(-SWAY_SMOOTH * delta))

	# Walk bob, scaled by how fast the player is moving.
	var speed_ratio := clampf(Vector2(velocity.x, velocity.z).length() / MOVE_SPEED, 0.0, 1.0)
	if _mode != InteractMode.FREE or not is_on_floor():
		speed_ratio = 0.0
	_bob_time += delta * BOB_FREQ * speed_ratio

	if _held_item and is_instance_valid(_held_item):
		var cam_basis := camera.global_transform.basis
		var target := hold_point.global_transform.origin
		target += cam_basis.x * (_sway.x * 0.06 + cos(_bob_time * 0.5) * BOB_HEIGHT * 0.6 * speed_ratio)
		target += cam_basis.y * (_sway.y * 0.04 + absf(sin(_bob_time * 0.5)) * BOB_HEIGHT * speed_ratio)
		var pos := _held_item.global_position.lerp(target, 0.2)
		var tilt := Basis.from_euler(Vector3(_sway.y * 0.6, _sway.x * 0.5, _sway.x * 0.9))
		_held_item.global_transform = Transform3D(cam_basis.orthonormalized() * tilt, pos)

func _update_hover_highlight() -> void:
	var target: Node = null
	if _mode == InteractMode.FREE and interact_ray.is_colliding():
		var collider := interact_ray.get_collider()
		if collider and _is_actionable(collider):
			target = collider
	if target == _hovered:
		return
	_set_overlay(_hovered, null)
	_hovered = target
	_set_overlay(_hovered, _hover_material)

func _is_actionable(collider: Object) -> bool:
	if _held_item is Pitcher and collider is Cup:
		return true
	if _held_item is MilkJug and collider is Pitcher:
		return true
	if collider.has_method("interact"):
		return true
	if (collider.has_method("receive_item") or collider.has_method("use_held")) and _held_item:
		return true
	if collider.has_method("take_item") and not _held_item:
		return true
	if collider is Node and (collider as Node).is_in_group("carriable") and not _held_item:
		return true
	return false

func _set_overlay(root: Node, mat: Material) -> void:
	if root == null or not is_instance_valid(root):
		return
	for geo in _collect_highlight_geometry(root):
		geo.material_overlay = mat

func _collect_highlight_geometry(root: Node) -> Array[GeometryInstance3D]:
	var found: Array[GeometryInstance3D] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			# Skip nested items (a pitcher sitting on a station) and effects.
			if child is PhysicsBody3D or child is BaseMiniGame:
				continue
			if child is Label3D or child is GPUParticles3D or child is PourStream:
				continue
			if child is GeometryInstance3D:
				found.append(child as GeometryInstance3D)
			stack.append(child)
	return found

## E is the work: start or resume a station's task. A station with nothing to
## work on but something to take hands it over, so E never does nothing there.
func _try_interact() -> void:
	if not interact_ray.is_colliding():
		return
	var collider := interact_ray.get_collider()
	if collider and collider.has_method("interact"):
		collider.interact(self)
	elif collider and collider.has_method("take_item") and not _held_item:
		collider.take_item(self)

## Click is the hand: take, set down, pour into. It never locks the camera.
func _try_click() -> void:
	if _held_item:
		_try_place_item()
	else:
		_try_pickup_item()

func _try_alt() -> void:
	if not interact_ray.is_colliding():
		return
	var collider := interact_ray.get_collider()
	if collider and collider.has_method("alt_interact"):
		collider.alt_interact(self)
		get_viewport().set_input_as_handled()

func _try_pickup_item() -> void:
	if not interact_ray.is_colliding():
		return
	var collider := interact_ray.get_collider()
	if collider and collider.has_method("take_item"):
		collider.take_item(self)
		return
	if collider and collider.is_in_group("carriable"):
		pickup_item(collider)

func pickup_item(item: Node3D) -> void:
	if _held_item:
		return
	_held_item = item
	StationUtils.cancel_settle(item)
	if item is RigidBody3D:
		(item as RigidBody3D).freeze = true
	StationUtils.set_item_collision(item, false)
	# Let the item fly into the hand from where it was, unless it is far away.
	if item.global_position.distance_to(hold_point.global_transform.origin) > 1.5:
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
		# Stations that work on the held item without taking it (the lids).
		if collider and collider.has_method("use_held") and collider.use_held(self):
			return
		# A station that says no keeps the item in your hand.
		if collider and collider.has_method("receive_item"):
			if collider.receive_item(_held_item):
				_held_item = null
				SoundManager.play("item_place")
			else:
				shake(0.003, 0.12)
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
	hud.set_prompt_visible(vis)

func _on_ticket_printed(data: Dictionary) -> void:
	_active_order = data["order"] as OrderData

func _on_drink_handed_off(data: Dictionary) -> void:
	_active_order = null
	var order: OrderData = data.get("order")
	var stars: float = data.get("stars", 0.0)
	var tip: float = data.get("tip", 0.0)
	hud.show_review(stars, tip, _review_issues(order))

## Steps that went wrong, for the review toast. Fine steps are not listed.
func _review_issues(order: OrderData) -> PackedStringArray:
	var out: PackedStringArray = []
	if order == null:
		return out
	if not order.correct_grind_level:
		out.append("Wrong grind setting")
	elif order.grind_quality >= 0.0 and order.grind_quality < 0.6:
		out.append("Uneven grind")
	var checks := [
		[order.brew_quality, DrinkData.Step.SHOT_PRESS_BREW, "Weak shot"],
		[order.pour_quality, DrinkData.Step.POUR_OVER_BREW, "Uneven pour"],
		[order.pour_quality, DrinkData.Step.HOT_WATER, "Off the fill line"],
		[order.steam_quality, DrinkData.Step.STEAM_MILK, "Milk off"],
	]
	for c in checks:
		var q: float = c[0]
		if q >= 0.0 and q < 0.6 and DrinkData.has_step(order.drink_type, c[1] as DrinkData.Step):
			out.append(str(c[2]))
	if order.requested_syrup >= 0 and order.syrup_quality >= 0.0 and order.syrup_quality < 0.6:
		out.append("Pump count off")
	if order.has_sauce() and order.sauce_quality >= 0.0 and order.sauce_quality < 0.6:
		out.append("Patchy drizzle")
	return out

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
	hud.set_info_mode(true)

func _exit_info_mode() -> void:
	if _mode != InteractMode.INFO:
		return
	_mode = InteractMode.FREE
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	hud.set_info_mode(false)

## hud_source answers get_controls_hint() and get_assist_readout() for the
## helper UI. fov > 0 zooms the camera; it goes back on exit.
func enter_mini_game(cam_transform: Transform3D, hud_source: Object = null, fov: float = 0.0) -> void:
	if not _begin_lock(InteractMode.MINI_GAME, hud_source):
		return
	_tween_fov(fov if fov > 0.0 else _base_fov, CAMERA_ENTER_TIME)
	_ease_camera(func() -> Transform3D: return cam_transform, CAMERA_ENTER_TIME, false)

## The camera moves to cam_pos facing look_target; the mouse then looks
## around that view within yaw_range and pitch_range (min, max radians,
## positive is left and up). fov > 0 zooms; it goes back on exit.
func enter_screen_mode(look_target: Vector3, cam_pos: Vector3, yaw_range: Vector2, pitch_range: Vector2, fov: float = 0.0, hud_source: Object = null) -> void:
	if not _begin_lock(InteractMode.SCREEN, hud_source):
		return
	_tween_fov(fov if fov > 0.0 else _base_fov, CAMERA_ENTER_TIME)
	_screen_yaw_range = yaw_range
	_screen_pitch_range = pitch_range
	_screen_offset = Vector2.ZERO
	_screen_basis = Transform3D.IDENTITY.looking_at(look_target - cam_pos, Vector3.UP).basis
	_ease_camera(func() -> Transform3D: return Transform3D(_screen_look_basis(), cam_pos), CAMERA_ENTER_TIME, false)

## False when another lock is active. A lock that ended this frame is taken
## over in place, keeping the free-look direction saved by the first lock.
func _begin_lock(mode: InteractMode, hud_source: Object) -> bool:
	if _restore_pending:
		_restore_pending = false
	elif _mode != InteractMode.FREE:
		return false
	else:
		_saved_yaw = _yaw
		_saved_pitch = _pitch
		_set_world_labels_visible(false)
	_mode = mode
	_hud_source = hud_source
	return true

func _request_restore() -> void:
	if _mode == InteractMode.FREE or _restore_pending:
		return
	_restore_pending = true
	_finish_restore.call_deferred()

func _finish_restore() -> void:
	if not _restore_pending:
		return
	_restore_pending = false
	_restore_camera()

func _restore_camera() -> void:
	if _mode == InteractMode.FREE:
		return
	_mode = InteractMode.FREE
	_hud_source = null
	_yaw = _saved_yaw
	_pitch = _saved_pitch
	_prev_yaw = _yaw
	_prev_pitch = _pitch
	var from := camera.global_transform
	rotation.y = _yaw
	camera.global_transform = from
	# Mouse look keeps turning the body and pitch during the ease.
	_ease_camera(func() -> Transform3D: return Transform3D(Basis.from_euler(Vector3(_pitch, 0, 0)), Vector3(0, 1.7, 0)), CAMERA_EXIT_TIME, true)
	_camera_tween.tween_callback(_run_queued_click)
	_tween_fov(_base_fov, CAMERA_EXIT_TIME)
	_set_world_labels_visible(true)

func _run_queued_click() -> void:
	if _click_queued and _mode == InteractMode.FREE:
		_try_click()
	_click_queued = false

func _screen_look_basis() -> Basis:
	return _screen_basis * Basis.from_euler(Vector3(_screen_offset.y, _screen_offset.x, 0.0))

func _apply_screen_look() -> void:
	if _mode == InteractMode.SCREEN and not _is_camera_easing():
		camera.global_basis = _screen_look_basis()

func _tween_fov(fov: float, time: float) -> void:
	if _fov_tween and _fov_tween.is_valid():
		_fov_tween.kill()
	_fov_tween = null
	if is_equal_approx(camera.fov, fov):
		return
	_fov_tween = create_tween()
	_fov_tween.tween_property(camera, "fov", fov, time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## Eases the camera toward target(), asked again every step, so mouse look
## during the ease is followed instead of landing in one jump at the end.
## local eases camera.transform (relative to the body) instead of global.
func _ease_camera(target: Callable, duration: float, local: bool) -> void:
	_kill_camera_tween()
	var from := camera.transform if local else camera.global_transform
	var step := func(t: float) -> void:
		var xf := from.interpolate_with(target.call() as Transform3D, t)
		if local:
			camera.transform = xf
		else:
			camera.global_transform = xf
	_camera_tween = create_tween()
	_camera_tween.tween_method(step, 0.0, 1.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _kill_camera_tween() -> void:
	if _camera_tween and _camera_tween.is_valid():
		_camera_tween.kill()
	_camera_tween = null

func _is_camera_easing() -> bool:
	return _camera_tween != null and _camera_tween.is_running()

func is_in_screen_mode() -> bool:
	return _mode == InteractMode.SCREEN and not _restore_pending

func exit_screen_mode() -> void:
	_request_restore()

func exit_mini_game() -> void:
	_request_restore()

func _on_day_ended() -> void:
	_day_ended = true
	hud.show_day_summary()
