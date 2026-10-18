class_name Customer
extends CharacterBody3D

const ORDER_PATIENCE := 300.0
const PICKUP_PATIENCE := 300.0
const SYRUP_CHANCE := 0.3
const SAUCE_CHANCE := 0.15
const ARRIVE_DISTANCE := 0.2
const IDLE_BARK_MIN := 9.0
const IDLE_BARK_MAX := 18.0

## WALKING_TO_REGISTER means walking to the customer's spot in the register line.
## QUEUED means standing in line behind someone. Only the front of the line orders.
enum State { WALKING_TO_REGISTER, WAITING_TO_ORDER, PAYING, WALKING_TO_PICKUP, WAITING_FOR_DRINK, LEAVING, QUEUED }

var state := State.WALKING_TO_REGISTER
var order_data: OrderData = null
var drink_type: DrinkData.DrinkType = DrinkData.DrinkType.POUR_OVER
var cup_size: DrinkData.CupSize = DrinkData.CupSize.MEDIUM
var syrup_type: int = -1
var sauce_type: int = -1
## Who this customer is. Generated in _ready unless set before adding to the tree.
var profile: CustomerProfile = null
var _payment_amount := 0.0

var _order_patience_max := ORDER_PATIENCE
var _pickup_patience_max := PICKUP_PATIENCE
var _order_patience := ORDER_PATIENCE
var _pickup_patience := PICKUP_PATIENCE
var _target_pos := Vector3.ZERO
var _register_pos := Vector3.ZERO
var _pickup_pos := Vector3.ZERO
var _exit_pos := Vector3.ZERO
var _leave_reason := ""
var _warned_impatient := false
var _leave_pending := false

var _visual: CharacterVisual = null
var _nav_agent: NavigationAgent3D = null
var _speech_label: Label3D = null
var _patience_bar_bg: CSGBox3D = null
var _patience_bar_fill: CSGBox3D = null
var _anim_time := 0.0
var _patience_ratio := 1.0
var _bar_shake := 0.0
var _bark_timer := 0.0
## Place in the register line, set by the spawner. 0 is at the register.
## -1 means no line manager (e.g. debug scenes); the customer then acts as the front.
var queue_index := -1
var _line_look_target := Vector3.ZERO
var _in_line := false
var _greeted := false
var _avoidance_requested := false
var _stuck_time := 0.0
var _last_progress_pos := Vector3.ZERO
var _player: Node3D = null

func _ready() -> void:
	if profile == null:
		profile = CustomerProfile.generate()
	_order_patience_max = ORDER_PATIENCE * profile.patience_mult
	_pickup_patience_max = PICKUP_PATIENCE * profile.patience_mult
	_order_patience = _order_patience_max
	_pickup_patience = _pickup_patience_max
	_bark_timer = randf_range(IDLE_BARK_MIN, IDLE_BARK_MAX)
	_build_visual()
	_build_navigation()
	_randomize_order()

func _build_visual() -> void:
	_visual = CharacterVisual.new()
	_visual.setup(profile)
	add_child(_visual)
	_anim_time = randf() * TAU

	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.2
	shape.height = 1.6
	col.shape = shape
	col.position.y = 0.8
	add_child(col)

	_speech_label = Label3D.new()
	_speech_label.text = ""
	_speech_label.font_size = 40
	_speech_label.position = Vector3(0, 2.02, 0)
	_speech_label.pixel_size = 0.0012
	_speech_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	UiStyle.world_label(_speech_label, UiStyle.W_BLACK)
	_speech_label.visible = false
	_speech_label.add_to_group("world_label")
	add_child(_speech_label)

	# Patience: a slim roast track with a fill that runs green, amber, red.
	_patience_bar_bg = CSGBox3D.new()
	_patience_bar_bg.size = Vector3(0.5, 0.04, 0.02)
	_patience_bar_bg.position = Vector3(0, 1.88, 0)
	var bg_mat := StandardMaterial3D.new()
	bg_mat.albedo_color = UiStyle.ROAST
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_patience_bar_bg.material = bg_mat
	add_child(_patience_bar_bg)

	_patience_bar_fill = CSGBox3D.new()
	_patience_bar_fill.size = Vector3(0.5, 0.028, 0.03)
	_patience_bar_fill.position = Vector3(0, 1.88, 0)
	var fill_mat := StandardMaterial3D.new()
	fill_mat.albedo_color = UiStyle.GREEN
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_patience_bar_fill.material = fill_mat
	add_child(_patience_bar_fill)

## Paths around stalls, planters and seating come from the shop's baked navmesh.
## Avoidance keeps customers from walking through each other.
func _build_navigation() -> void:
	_nav_agent = NavigationAgent3D.new()
	# Path points sit a little above the ground, so this must be larger than that gap.
	_nav_agent.path_desired_distance = 0.5
	_nav_agent.target_desired_distance = ARRIVE_DISTANCE
	_nav_agent.radius = 0.35
	_nav_agent.height = 1.7
	_nav_agent.max_speed = profile.walk_speed
	_nav_agent.avoidance_enabled = true
	_nav_agent.neighbor_distance = 3.0
	_nav_agent.time_horizon_agents = 1.0
	_nav_agent.velocity_computed.connect(_on_velocity_computed)
	add_child(_nav_agent)

func _randomize_order() -> void:
	var available_drinks := UnlockManager.get_menu_drinks()
	if available_drinks.is_empty():
		available_drinks = [DrinkData.DrinkType.POUR_OVER]
	drink_type = available_drinks[randi() % available_drinks.size()] as DrinkData.DrinkType

	var available_sizes := UnlockManager.owned_sizes.duplicate()
	if available_sizes.is_empty():
		available_sizes = [DrinkData.CupSize.SMALL]
	cup_size = available_sizes[randi() % available_sizes.size()] as DrinkData.CupSize

	var available_syrups := UnlockManager.owned_syrups.duplicate()
	if not available_syrups.is_empty() and randf() < SYRUP_CHANCE * profile.modifier_chance_mult:
		syrup_type = available_syrups[randi() % available_syrups.size()]
	else:
		syrup_type = -1

	if DrinkData.has_step(drink_type, DrinkData.Step.ADD_SAUCE):
		sauce_type = DrinkData.SauceType.MOCHA
	else:
		var available_sauces := UnlockManager.owned_sauces.duplicate()
		if not available_sauces.is_empty() and randf() < SAUCE_CHANCE * profile.modifier_chance_mult:
			sauce_type = available_sauces[randi() % available_sauces.size()]
		else:
			sauce_type = -1

func setup(register: Vector3, pickup: Vector3, exit: Vector3) -> void:
	_register_pos = register
	_pickup_pos = pickup
	_exit_pos = exit
	_set_target(_register_pos)
	state = State.WALKING_TO_REGISTER

func _set_target(pos: Vector3) -> void:
	_target_pos = pos
	_stuck_time = 0.0
	_last_progress_pos = global_position
	if _nav_agent:
		_nav_agent.target_position = pos

func _process(delta: float) -> void:
	_animate(delta)
	_tick_barks(delta)

func _animate(delta: float) -> void:
	if _visual == null:
		return
	var flat_velocity := Vector3(velocity.x, 0, velocity.z)
	var moving := flat_velocity.length() > 0.1
	_anim_time += delta * 2.0

	# Face the walk direction, or the player while waiting at the counter.
	var face_dir := Vector3.ZERO
	if moving:
		face_dir = flat_velocity
	elif state == State.QUEUED:
		face_dir = _line_look_target - global_position
	elif state == State.WAITING_TO_ORDER or state == State.PAYING or state == State.WAITING_FOR_DRINK:
		if _player == null or not is_instance_valid(_player):
			_player = get_tree().get_first_node_in_group("player") as Node3D
		if _player:
			face_dir = _player.global_position - global_position
	face_dir.y = 0.0
	if face_dir.length() > 0.05:
		var target_yaw := atan2(face_dir.x, face_dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-8.0 * delta))

	_visual.set_moving(flat_velocity.length() if moving else 0.0)
	if moving:
		_visual.rotation.z = 0.0
	else:
		# Impatient customers sway from side to side.
		var impatience := clampf((0.35 - _patience_ratio) / 0.35, 0.0, 1.0)
		_visual.rotation.z = sin(_anim_time * 3.0) * 0.04 * impatience

	if _patience_bar_fill and _patience_bar_bg:
		_bar_shake = sin(Time.get_ticks_msec() * 0.06) * 0.012 if _patience_ratio < 0.25 else 0.0
		_patience_bar_bg.position.x = _bar_shake
		_patience_bar_fill.position.x = -0.25 * (1.0 - _patience_ratio) + _bar_shake

## Occasional small talk while waiting for the drink.
func _tick_barks(delta: float) -> void:
	if state != State.WAITING_FOR_DRINK and state != State.QUEUED:
		return
	_bark_timer -= delta
	if _bark_timer <= 0.0:
		_bark_timer = randf_range(IDLE_BARK_MIN, IDLE_BARK_MAX)
		if _patience_ratio > 0.25:
			bark(CustomerProfile.pick(CustomerProfile.WAITING))

func bark(text: String, color: Color = UiStyle.CREMA) -> void:
	Fx.float_text(global_position + Vector3(0, 2.2, 0), text, color, 36)

## HUD prompt when the crosshair is on this customer.
func get_prompt() -> String:
	if state == State.PAYING:
		return "[E] Take $%.0f" % _payment_amount
	return ""

func _physics_process(delta: float) -> void:
	match state:
		State.WALKING_TO_REGISTER:
			_move_toward_target(delta)
			# Once in line, shuffling forward still counts as waiting.
			if _in_line:
				_tick_order_patience(delta)
				if state == State.LEAVING:
					return
			if _at_target():
				_stop()
				_in_line = true
				if queue_index <= 0:
					state = State.WAITING_TO_ORDER
					_show_order()
					if not _greeted:
						_greeted = true
						bark(CustomerProfile.pick(CustomerProfile.GREETINGS))
					SoundManager.play("customer_arrive")
				else:
					state = State.QUEUED
		State.QUEUED:
			_stop()
			_tick_order_patience(delta)
		State.WAITING_TO_ORDER, State.PAYING:
			_stop()
			_tick_order_patience(delta)
		State.WALKING_TO_PICKUP:
			_move_toward_target(delta)
			if _at_target():
				_stop()
				state = State.WAITING_FOR_DRINK
				if profile.uses_phone:
					_visual.hold_in_hand(CharacterVisual.make_phone())
		State.WAITING_FOR_DRINK:
			_stop()
			_pickup_patience -= delta
			_update_patience_bar(_pickup_patience / _pickup_patience_max)
			if _pickup_patience <= 0:
				_leave("impatient_pickup")
		State.LEAVING:
			if _leave_pending:
				_stop()
				return
			_move_toward_target(delta)
			if _at_target():
				EventBus.customer_left.emit(self, _leave_reason)
				queue_free()

func _tick_order_patience(delta: float) -> void:
	_order_patience -= delta
	_update_patience_bar(_order_patience / _order_patience_max)
	if _order_patience <= 0:
		_leave("impatient_order")

## Called by the spawner when this customer's place in line changes.
## look_target is the spot they face while waiting (the person ahead, or the register).
func assign_queue_spot(index: int, pos: Vector3, look_target: Vector3) -> void:
	queue_index = index
	_line_look_target = look_target
	if index == 0:
		_register_pos = pos
	if state == State.WALKING_TO_REGISTER or state == State.QUEUED:
		state = State.WALKING_TO_REGISTER
		_set_target(pos)

## Called by the spawner to give this customer their own spot at the pickup counter.
func assign_pickup_spot(pos: Vector3) -> void:
	_pickup_pos = pos
	if state == State.WALKING_TO_PICKUP:
		_set_target(pos)

func is_in_register_line() -> bool:
	return state == State.WALKING_TO_REGISTER or state == State.QUEUED or state == State.WAITING_TO_ORDER or state == State.PAYING

func is_at_pickup() -> bool:
	return state == State.WALKING_TO_PICKUP or state == State.WAITING_FOR_DRINK

func _stop() -> void:
	velocity = Vector3.ZERO
	if _nav_agent and _nav_agent.avoidance_enabled:
		_nav_agent.velocity = Vector3.ZERO

const STUCK_TIMEOUT := 4.0

func _move_toward_target(delta: float) -> void:
	_check_stuck(delta)
	var next := _target_pos
	if _nav_agent and _nav_ready() and not _nav_agent.is_navigation_finished():
		next = _nav_agent.get_next_path_position()
	var dir := next - global_position
	dir.y = 0
	var desired := Vector3.ZERO
	if not _at_target() and dir.length() > 0.01:
		desired = dir.normalized() * profile.walk_speed
	if _nav_agent and _nav_agent.avoidance_enabled and _nav_ready() and not _nav_agent.is_navigation_finished():
		# The agent adjusts the velocity around other customers, then calls back.
		_avoidance_requested = true
		_nav_agent.velocity = desired
	else:
		# No navmesh yet, or the agent counts the path as done while we are still
		# a few centimetres short: walk straight to the spot.
		_apply_velocity(desired)

func _on_velocity_computed(safe_velocity: Vector3) -> void:
	# The agent reports every physics frame; only act on frames where we asked.
	if not _avoidance_requested:
		return
	_avoidance_requested = false
	if state == State.WALKING_TO_REGISTER or state == State.WALKING_TO_PICKUP or (state == State.LEAVING and not _leave_pending):
		_apply_velocity(safe_velocity)

## If a walking customer makes no progress for a few seconds (pinned on a prop or
## another customer), put them on the spot so the day can't stall behind them.
func _check_stuck(delta: float) -> void:
	if global_position.distance_to(_last_progress_pos) > 0.25:
		_last_progress_pos = global_position
		_stuck_time = 0.0
		return
	_stuck_time += delta
	if _stuck_time > STUCK_TIMEOUT:
		_stuck_time = 0.0
		global_position = Vector3(_target_pos.x, global_position.y, _target_pos.z)
		_last_progress_pos = global_position

func _apply_velocity(v: Vector3) -> void:
	velocity = Vector3(v.x, velocity.y, v.z)
	if not is_on_floor():
		velocity.y -= 9.8 * get_physics_process_delta_time()
	else:
		velocity.y = 0.0
	move_and_slide()

func _nav_ready() -> bool:
	var map := _nav_agent.get_navigation_map()
	return map.is_valid() and NavigationServer3D.map_get_iteration_id(map) > 0

func _at_target() -> bool:
	var dist := (_target_pos - global_position)
	dist.y = 0
	return dist.length() < ARRIVE_DISTANCE

func _show_order() -> void:
	if _speech_label:
		var parts: Array[String] = [DrinkData.get_size_name(cup_size)]
		if syrup_type >= 0:
			parts.append(DrinkData.get_syrup_name(syrup_type as DrinkData.SyrupType))
		if sauce_type >= 0 and not DrinkData.has_step(drink_type, DrinkData.Step.ADD_SAUCE):
			parts.append(DrinkData.get_sauce_name(sauce_type as DrinkData.SauceType))
		parts.append(DrinkData.get_drink_name(drink_type))
		_speech_label.text = " ".join(parts)
		_speech_label.visible = true
		Fx.pop(_speech_label, 1.4, 0.3)

func start_paying(price: float) -> void:
	state = State.PAYING
	if price <= 5.0:
		_payment_amount = 5.0
	elif price <= 10.0:
		_payment_amount = 10.0
	else:
		_payment_amount = 20.0
	if _speech_label:
		_speech_label.text = "$%.0f" % _payment_amount
		_speech_label.visible = true
		Fx.pop(_speech_label, 1.4, 0.3)

func interact(_player: Player) -> void:
	if state == State.PAYING:
		SoundManager.play("cash_collect")
		EventBus.cash_collected.emit(self, _payment_amount)
		if _speech_label:
			_speech_label.visible = false

func order_taken(order: OrderData = null) -> void:
	order_data = order
	_speech_label.visible = false
	state = State.WALKING_TO_PICKUP
	_set_target(_pickup_pos)
	_pickup_patience = _pickup_patience_max

func drink_received(stars: float = 0.0) -> void:
	_speech_label.visible = false
	_visual.hold_in_hand(CharacterVisual.make_takeaway_cup())
	bark(profile.review_line(stars), UiStyle.AMBER if stars >= 4.5 else UiStyle.CREMA)
	if stars >= 4.5:
		# Happy hop, then head off.
		_leave("satisfied")
		_leave_pending = true
		_visual.play_jump()
		get_tree().create_timer(1.0).timeout.connect(func() -> void: _leave_pending = false)
	else:
		_leave("satisfied")

func matches_drink(order: OrderData) -> bool:
	return order.drink_type == drink_type and order.cup_size == cup_size and order.requested_syrup == syrup_type and order.requested_sauce == sauce_type

func _leave(reason: String) -> void:
	if state == State.LEAVING:
		return
	state = State.LEAVING
	_set_target(_exit_pos)
	_speech_label.visible = false
	_leave_reason = reason
	if reason == "satisfied":
		SoundManager.play("customer_happy")
	else:
		_visual.hold_in_hand(null)
		bark(CustomerProfile.pick(CustomerProfile.ANGRY), UiStyle.RED)
		SoundManager.play("customer_angry")

func _update_patience_bar(ratio: float) -> void:
	ratio = clampf(ratio, 0.0, 1.0)
	if ratio < 0.25 and not _warned_impatient:
		_warned_impatient = true
		bark(CustomerProfile.pick(CustomerProfile.IMPATIENT), UiStyle.AMBER)
		SoundManager.play("customer_impatient")
	_patience_ratio = ratio
	if _patience_bar_fill:
		_patience_bar_fill.size.x = 0.5 * ratio
		_patience_bar_fill.position.x = -0.25 * (1.0 - ratio) + _bar_shake
		var mat := _patience_bar_fill.material as StandardMaterial3D
		if mat:
			# Smooth green -> amber -> red instead of three hard steps.
			var green := UiStyle.GREEN
			var yellow := UiStyle.AMBER
			var red := UiStyle.RED
			if ratio > 0.5:
				mat.albedo_color = yellow.lerp(green, (ratio - 0.5) / 0.5)
			else:
				mat.albedo_color = red.lerp(yellow, ratio / 0.5)
			if ratio < 0.25:
				mat.emission_enabled = true
				mat.emission = red * (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012))
			else:
				mat.emission_enabled = false
