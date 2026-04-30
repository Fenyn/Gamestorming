extends StaticBody3D

# Player flow:
# 1. Place cup on station
# 2. Pick up dripper from shelf, carry to grinder, grind, carry back
# 3. Place dripper on station (on top of cup)
# 4. Hold kettle with hot water, [E] → bloom pour (brief active)
# 5. Bloom wait (passive ~20s — walk away!)
# 6. Come back, [E] → main pour (active, saturation)
# 7. Draw-down (passive ~15s — walk away again!)
# 8. Coffee ready in cup, pick up

enum State { IDLE, CUP_ONLY, READY_TO_POUR, BLOOMING, BLOOM_WAIT, MAIN_POUR, DRAINING, READY, STALE }

var state := State.IDLE
var _placed_cup: Cup = null
var _placed_dripper: Dripper = null
var _shelf_dripper: Dripper = null

var _pour_game: PourMiniGame = null
var _correct_grind := true
var _grind_quality := 1.0
var _pour_quality := 0.0
var _pouring_player: Player = null
var _pour_kettle: Kettle = null

var _cup_slot: Marker3D = null
var _dripper_slot: Marker3D = null
var _status_label: Label3D = null
var _pour_tween: Tween = null

func _ready() -> void:
	add_to_group("station")

	_cup_slot = Marker3D.new()
	_cup_slot.name = "CupSlot"
	_cup_slot.position = Vector3(0, 0.12, 0)
	add_child(_cup_slot)

	_dripper_slot = Marker3D.new()
	_dripper_slot.name = "DripperSlot"
	_dripper_slot.position = Vector3(0, 0.22, 0)
	add_child(_dripper_slot)

	_pour_game = PourMiniGame.new()
	_pour_game.name = "PourMiniGame"
	_pour_game.pour_mode = PourMiniGame.PourMode.SATURATION
	var cam := Marker3D.new()
	cam.name = "CameraPoint"
	cam.position = Vector3(0, 0.50, 0.10)
	cam.rotation_degrees = Vector3(-70, 0, 0)
	_pour_game.add_child(cam)
	add_child(_pour_game)
	_pour_game._camera_point = cam
	_pour_game.mini_game_completed.connect(_on_pour_complete)

	_spawn_shelf_dripper()

	_status_label = Label3D.new()
	_status_label.text = ""
	_status_label.font_size = 12
	_status_label.position = Vector3(0, 0.3, 0.15)
	_status_label.pixel_size = 0.002
	_status_label.add_to_group("world_label")
	add_child(_status_label)
	_update_label()

func _spawn_shelf_dripper() -> void:
	_shelf_dripper = Dripper.new()
	_shelf_dripper.name = "DripperShelf"
	add_child(_shelf_dripper)
	_shelf_dripper.position = Vector3(0.15, 0.15, 0)

func interact(player: Player) -> void:
	if _pour_game.is_active():
		return
	match state:
		State.IDLE:
			_try_pickup_shelf_dripper(player)
		State.CUP_ONLY:
			if _placed_dripper and not _placed_dripper.has_grounds():
				_try_pickup_placed_dripper(player)
			else:
				_try_pickup_shelf_dripper(player)
		State.READY_TO_POUR:
			_try_start_bloom(player)
		State.BLOOMING:
			pass
		State.BLOOM_WAIT:
			pass
		State.MAIN_POUR:
			_try_start_main_pour(player)
		State.DRAINING:
			pass
		State.READY, State.STALE:
			pass

func _try_start_bloom(player: Player) -> void:
	var held := player.get_held_item()
	if held is Kettle and (held as Kettle).has_water:
		_pouring_player = player
		_pour_kettle = held as Kettle
		_start_pour_animation()
		if _placed_dripper:
			_set_dripper_opacity(0.45)
		state = State.BLOOMING
		_update_label()
		_pour_game.start(player)
	elif _status_label:
		_status_label.text = "Hold filled kettle!\n[E] Start bloom pour"

func _try_start_main_pour(player: Player) -> void:
	var held := player.get_held_item()
	if held is Kettle and (held as Kettle).has_water:
		_pouring_player = player
		_pour_kettle = held as Kettle
		_start_pour_animation()
		if _placed_dripper:
			_set_dripper_opacity(0.45)
		state = State.MAIN_POUR
		_update_label()
		_pour_game.start(player)
	elif _status_label:
		_status_label.text = "Hold filled kettle!\n[E] Main pour"

func _start_pour_animation() -> void:
	if not _pour_kettle or not _pouring_player:
		return
	_pouring_player._held_item = null
	var pour_pos := _dripper_slot.global_position + Vector3(-0.10, 0.12, 0.06)
	_pour_kettle.global_position = pour_pos
	_pour_kettle.global_rotation_degrees = Vector3(0, 0, -35)
	if _pour_tween and _pour_tween.is_valid():
		_pour_tween.kill()
	_pour_tween = create_tween().set_loops()
	_pour_tween.tween_property(_pour_kettle, "global_rotation_degrees:z", -45.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pour_tween.tween_property(_pour_kettle, "global_rotation_degrees:z", -30.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _set_dripper_opacity(alpha: float) -> void:
	if not _placed_dripper:
		return
	_placed_dripper.visible = true
	for child in _placed_dripper.get_children():
		if child is CSGPrimitive3D and child.material is StandardMaterial3D:
			var mat := child.material as StandardMaterial3D
			mat.albedo_color.a = alpha
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if alpha < 0.99 else BaseMaterial3D.TRANSPARENCY_DISABLED

func _stop_pour_animation() -> void:
	if _pour_tween and _pour_tween.is_valid():
		_pour_tween.kill()
		_pour_tween = null
	if _pour_kettle and is_instance_valid(_pour_kettle):
		_pour_kettle.global_rotation_degrees = Vector3.ZERO
		if _pouring_player and is_instance_valid(_pouring_player):
			_pouring_player.pickup_item(_pour_kettle)

func _try_pickup_shelf_dripper(player: Player) -> void:
	if not player.has_held_item() and _shelf_dripper and is_instance_valid(_shelf_dripper):
		player.pickup_item(_shelf_dripper)
		_shelf_dripper = null
		_update_label()

func _try_pickup_placed_dripper(player: Player) -> void:
	if not player.has_held_item() and _placed_dripper and is_instance_valid(_placed_dripper):
		for child in _placed_dripper.get_children():
			if child is CollisionShape3D:
				child.disabled = false
		player.pickup_item(_placed_dripper)
		_placed_dripper = null
		_recalculate_state()

func receive_item(item: Node3D) -> bool:
	if _pour_game.is_active():
		return false
	if item is Cup:
		if _placed_cup:
			return false
		_placed_cup = item as Cup
		_place_at_slot(item, _cup_slot)
		_recalculate_state()
		return true
	if item is Dripper:
		if _placed_dripper:
			return false
		_placed_dripper = item as Dripper
		_place_at_slot(item, _dripper_slot)
		if _placed_dripper.has_grounds():
			_correct_grind = (_placed_dripper.grounds.grind_level == DrinkData.GrindLevel.COARSE)
			_grind_quality = _placed_dripper.grounds.grind_quality
		_recalculate_state()
		return true
	return false

func _place_at_slot(item: Node3D, slot: Marker3D) -> void:
	item.global_position = slot.global_position
	item.global_rotation = Vector3.ZERO
	if item is RigidBody3D:
		(item as RigidBody3D).freeze = true
	for child in item.get_children():
		if child is CollisionShape3D:
			child.disabled = true

func _recalculate_state() -> void:
	if _placed_cup and _placed_dripper:
		if not _placed_dripper.has_grounds():
			state = State.CUP_ONLY
			if _status_label:
				_status_label.text = "Dripper needs grounds!\n[E] Pick up dripper"
			return
		else:
			state = State.READY_TO_POUR
	elif _placed_cup and not _placed_dripper:
		state = State.CUP_ONLY
	else:
		state = State.IDLE
	_update_label()

func _on_pour_complete(quality: float) -> void:
	_pour_quality = quality
	if _pour_kettle and is_instance_valid(_pour_kettle):
		_pour_kettle.use_water(Kettle.POUR_OVER_COST)
	_stop_pour_animation()
	if _placed_dripper:
		_set_dripper_opacity(0.5)
	_pour_kettle = null
	_pouring_player = null
	state = State.DRAINING
	_update_label()

func _process(_delta: float) -> void:
	# Track bloom → bloom_wait transition
	if state == State.BLOOMING and not _pour_game.is_active():
		if _pour_game.is_bloom_waiting():
			state = State.BLOOM_WAIT
			if _pour_kettle and is_instance_valid(_pour_kettle):
				_pour_kettle.use_water(Kettle.BLOOM_COST)
			_stop_pour_animation()
			if _placed_dripper:
				_set_dripper_opacity(0.5)
			_pour_kettle = null
			_pouring_player = null
			_update_label()

	# Show bloom countdown while walking
	if state == State.BLOOM_WAIT:
		if _pour_game.is_ready_for_main_pour():
			state = State.MAIN_POUR
			_update_label()
		elif _status_label:
			_status_label.text = "Bloom... %.0fs\n[E] when ready (hold kettle)" % _pour_game.get_bloom_timer()

	# Show drain countdown
	if state == State.DRAINING:
		if _pour_game.is_coffee_ready():
			_finish_drip()
		elif _status_label:
			_status_label.text = "Draining... %.0fs" % maxf(_pour_game.phase_timer, 0)

	if state == State.READY:
		if _pour_game.get_coffee_freshness() < 0.3:
			state = State.STALE
			_update_label()

	# Update dripper saturation visual during active pours
	if (state == State.BLOOMING or state == State.MAIN_POUR) and _pour_game.is_active() and _placed_dripper:
		_placed_dripper.set_saturation(_pour_game._get_avg_saturation())

	_check_removed_items()

func _finish_drip() -> void:
	if _placed_cup:
		var freshness := _pour_game.get_coffee_freshness()
		_placed_cup.has_pour_over_coffee = true
		if _placed_cup.order:
			_placed_cup.order.pour_quality = _pour_quality * freshness
			_placed_cup.order.correct_grind_level = _correct_grind
			_placed_cup.order.grind_quality = _grind_quality * (1.0 if _correct_grind else 0.5)
		_placed_cup.set_fill(0.85, Color(0.35, 0.22, 0.1))
		for child in _placed_cup.get_children():
			if child is CollisionShape3D:
				child.disabled = false

	if _placed_dripper:
		_placed_dripper.reset_device()
		_placed_dripper.global_position = Vector3(global_position.x + 0.15, global_position.y + 0.15, global_position.z)
		_shelf_dripper = _placed_dripper
		_placed_dripper = null

	state = State.READY
	_update_label()

func _check_removed_items() -> void:
	if _placed_cup:
		if not is_instance_valid(_placed_cup):
			_placed_cup = null
			_recalculate_state()
		elif _placed_cup.global_position.distance_to(_cup_slot.global_position) > 0.5:
			_placed_cup = null
			_recalculate_state()
	if _placed_dripper:
		if not is_instance_valid(_placed_dripper):
			_placed_dripper = null
			_recalculate_state()
		elif _placed_dripper.global_position.distance_to(_dripper_slot.global_position) > 0.5:
			_placed_dripper = null
			_recalculate_state()

func _update_label() -> void:
	if not _status_label:
		return
	match state:
		State.IDLE:
			var has_shelf := _shelf_dripper != null and is_instance_valid(_shelf_dripper)
			_status_label.text = "[E] Pick up dripper" if has_shelf else "[Click] Place cup"
		State.CUP_ONLY:
			var has_shelf := _shelf_dripper != null and is_instance_valid(_shelf_dripper)
			_status_label.text = "[E] Pick up dripper" if has_shelf else "Bring dripper w/ grounds"
		State.READY_TO_POUR:
			_status_label.text = "[E] Bloom pour\n(hold filled kettle)"
		State.BLOOMING:
			_status_label.text = "Blooming..."
		State.BLOOM_WAIT:
			_status_label.text = "Bloom wait..."
		State.MAIN_POUR:
			_status_label.text = "[E] Main pour\n(hold filled kettle)"
		State.DRAINING:
			_status_label.text = "Draining..."
		State.READY:
			_status_label.text = "Coffee ready!\n[Click] Pick up cup"
		State.STALE:
			_status_label.text = "Getting cold!\n[Click] Pick up cup"
