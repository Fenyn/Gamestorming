extends StaticBody3D

enum State { IDLE, CUP_ONLY, DEVICE_ONLY, READY_FOR_WATER, HAS_WATER, STEEPING, READY_TO_PRESS, PRESSING, DONE, DEAD }

var state := State.IDLE
var _placed_cup: Cup = null
var _placed_device: AeropressDevice = null
var _shelf_device: AeropressDevice = null

var _press_game: PressMiniGame = null
var _stir_game: StirMiniGame = null
var _water_game: PourMiniGame = null

var _grind_quality := 1.0
var _correct_grind := true
var _stir_quality := 1.0
var _shot_quality := 0.0
var _pouring_player: Player = null
var _pour_kettle: Kettle = null
var _pour_tween: Tween = null
var _kettle_rest_pos := Vector3.ZERO

var _cup_slot: Marker3D = null
var _device_slot: Marker3D = null
var _status_label: Label3D = null

func _ready() -> void:
	add_to_group("station")

	_cup_slot = Marker3D.new()
	_cup_slot.name = "CupSlot"
	_cup_slot.position = Vector3(0, 0.15, 0)
	add_child(_cup_slot)

	_device_slot = Marker3D.new()
	_device_slot.name = "DeviceSlot"
	_device_slot.position = Vector3(0, 0.25, 0)
	add_child(_device_slot)

	var cam_pos := Vector3(0, 0.4, 0.4)
	var cam_rot := Vector3(-30, 0, 0)

	_press_game = PressMiniGame.new()
	_press_game.name = "PressMiniGame"
	var cam1 := Marker3D.new()
	cam1.name = "CameraPoint"
	cam1.position = cam_pos
	cam1.rotation_degrees = cam_rot
	_press_game.add_child(cam1)
	add_child(_press_game)
	_press_game._camera_point = cam1
	_press_game.mini_game_completed.connect(_on_press_complete)

	_stir_game = StirMiniGame.new()
	_stir_game.name = "StirMiniGame"
	var cam2 := Marker3D.new()
	cam2.name = "CameraPoint"
	cam2.position = cam_pos
	cam2.rotation_degrees = cam_rot
	_stir_game.add_child(cam2)
	add_child(_stir_game)
	_stir_game._camera_point = cam2
	_stir_game.mini_game_completed.connect(_on_stir_complete)

	_water_game = PourMiniGame.new()
	_water_game.name = "WaterPourMiniGame"
	_water_game.pour_mode = PourMiniGame.PourMode.FILL_LINE
	var cam3 := Marker3D.new()
	cam3.name = "CameraPoint"
	cam3.position = cam_pos
	cam3.rotation_degrees = cam_rot
	_water_game.add_child(cam3)
	add_child(_water_game)
	_water_game._camera_point = cam3
	_water_game.mini_game_completed.connect(_on_water_complete)

	_spawn_shelf_device()

	_status_label = Label3D.new()
	_status_label.text = ""
	_status_label.font_size = 12
	_status_label.position = Vector3(0, 0.3, 0.15)
	_status_label.pixel_size = 0.002
	_status_label.add_to_group("world_label")
	add_child(_status_label)
	_update_label()

func _spawn_shelf_device() -> void:
	_shelf_device = AeropressDevice.new()
	_shelf_device.name = "AeropressShelf"
	add_child(_shelf_device)
	_shelf_device.position = Vector3(0.15, 0.18, 0)

func _any_game_active() -> bool:
	return _press_game.is_active() or _stir_game.is_active() or _water_game.is_active()

func interact(player: Player) -> void:
	if _any_game_active():
		return
	match state:
		State.IDLE:
			_try_pickup_shelf_device(player)
		State.CUP_ONLY:
			_try_pickup_shelf_device(player)
		State.DEVICE_ONLY:
			_try_pickup_placed_device(player)
		State.READY_FOR_WATER:
			var held := player.get_held_item()
			if held is Kettle and (held as Kettle).has_water:
				_pouring_player = player
				_pour_kettle = held as Kettle
				_start_pour_animation()
				_water_game.start(player)
			elif _status_label:
				_status_label.text = "Hold filled kettle!\n[E] Pour water"
		State.HAS_WATER:
			_stir_game.start(player)
		State.STEEPING:
			pass
		State.READY_TO_PRESS:
			state = State.PRESSING
			_update_label()
			if _placed_device:
				_placed_device.show_plunger()
			_press_game.start(player)
		State.PRESSING:
			pass
		State.DONE:
			pass
		State.DEAD:
			_reset()

func _try_pickup_shelf_device(player: Player) -> void:
	if not player.has_held_item() and _shelf_device and is_instance_valid(_shelf_device):
		player.pickup_item(_shelf_device)
		_shelf_device = null
		_update_label()

func _try_pickup_placed_device(player: Player) -> void:
	if not player.has_held_item() and _placed_device and is_instance_valid(_placed_device):
		for child in _placed_device.get_children():
			if child is CollisionShape3D:
				child.disabled = false
		player.pickup_item(_placed_device)
		_placed_device = null
		_recalculate_state()

func receive_item(item: Node3D) -> bool:
	if _any_game_active():
		return false
	if item is Cup:
		if _placed_cup:
			return false
		_placed_cup = item as Cup
		_place_at_slot(item, _cup_slot)
		_recalculate_state()
		return true
	if item is AeropressDevice:
		if _placed_device:
			return false
		_placed_device = item as AeropressDevice
		_place_at_slot(item, _device_slot)
		if _placed_device.has_grounds():
			_correct_grind = (_placed_device.grounds.grind_level == DrinkData.GrindLevel.FINE)
			_grind_quality = _placed_device.grounds.grind_quality
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
	if _placed_cup and _placed_device:
		if not _placed_device.has_grounds():
			state = State.DEVICE_ONLY
		elif not _placed_device.has_water:
			state = State.READY_FOR_WATER
		elif not _placed_device.is_stirred:
			state = State.HAS_WATER
		else:
			state = State.STEEPING
	elif _placed_cup and not _placed_device:
		state = State.CUP_ONLY
	elif _placed_device and not _placed_cup:
		state = State.DEVICE_ONLY
	else:
		state = State.IDLE
	_update_label()

func _on_water_complete(quality: float) -> void:
	if _placed_device:
		_placed_device.has_water = true
		_placed_device.set_liquid_level(1.0)
	_stop_pour_animation()
	if _pouring_player:
		if _pour_kettle and is_instance_valid(_pour_kettle):
			_pour_kettle.use_water(Kettle.AEROPRESS_COST)
		_pouring_player = null
	_pour_kettle = null
	state = State.HAS_WATER
	_update_label()

func _start_pour_animation() -> void:
	if not _pour_kettle or not _pouring_player:
		return
	# Detach from player hold so _update_held_item doesn't fight us
	_pouring_player._held_item = null

	var pour_pos := _device_slot.global_position + Vector3(-0.12, 0.10, 0.08)
	_pour_kettle.global_position = pour_pos
	_pour_kettle.global_rotation_degrees = Vector3(0, 0, -35)

	if _pour_tween and _pour_tween.is_valid():
		_pour_tween.kill()
	_pour_tween = create_tween().set_loops()
	_pour_tween.tween_property(_pour_kettle, "global_rotation_degrees:z", -45.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pour_tween.tween_property(_pour_kettle, "global_rotation_degrees:z", -30.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _stop_pour_animation() -> void:
	if _pour_tween and _pour_tween.is_valid():
		_pour_tween.kill()
		_pour_tween = null
	if _pour_kettle and is_instance_valid(_pour_kettle):
		_pour_kettle.global_rotation_degrees = Vector3.ZERO
		# Give back to player
		if _pouring_player and is_instance_valid(_pouring_player):
			_pouring_player.pickup_item(_pour_kettle)

func _on_stir_complete(quality: float) -> void:
	_stir_quality = quality
	if _placed_device:
		_placed_device.is_stirred = true
	state = State.STEEPING
	_press_game.start_steeping()
	_update_label()

func _process(_delta: float) -> void:
	match state:
		State.STEEPING:
			if _press_game.phase == PressMiniGame.Phase.READY:
				state = State.READY_TO_PRESS
				_update_label()
			elif _press_game.phase == PressMiniGame.Phase.DEAD:
				state = State.DEAD
				_update_label()
			elif _status_label:
				_status_label.text = "Steeping... %.0fs" % maxf(_press_game.phase_timer, 0)
		State.READY_TO_PRESS:
			if _press_game.phase == PressMiniGame.Phase.DEAD:
				state = State.DEAD
				_update_label()
			elif _press_game.phase == PressMiniGame.Phase.OVER_EXTRACTING:
				if _status_label:
					_status_label.text = "[E] PRESS NOW!\n(over-extracting!)"
		State.PRESSING:
			if _placed_device:
				_placed_device.set_plunger_progress(_press_game.press_progress)
			if not _press_game.is_active():
				if _placed_device:
					_placed_device.hide_plunger()
				if _press_game.phase == PressMiniGame.Phase.DEAD:
					state = State.DEAD
				elif _press_game.phase in [PressMiniGame.Phase.READY, PressMiniGame.Phase.OVER_EXTRACTING]:
					state = State.READY_TO_PRESS
				_update_label()

	# Animate liquid fill during water pour
	if state == State.READY_FOR_WATER and _water_game.is_active() and _placed_device:
		_placed_device.set_liquid_level(_water_game._fill_level)

	_check_removed_items()

func _check_removed_items() -> void:
	if _placed_cup:
		if not is_instance_valid(_placed_cup):
			_placed_cup = null
			_recalculate_state()
		elif _placed_cup.global_position.distance_to(_cup_slot.global_position) > 0.5:
			_placed_cup = null
			_recalculate_state()
	if _placed_device:
		if not is_instance_valid(_placed_device):
			_placed_device = null
			_recalculate_state()
		elif _placed_device.global_position.distance_to(_device_slot.global_position) > 0.5:
			_placed_device = null
			_recalculate_state()

func _on_press_complete(quality: float) -> void:
	if quality <= 0:
		state = State.DEAD
		_update_label()
		return
	_shot_quality = quality
	if _placed_cup:
		_placed_cup.has_shot = true
		if _placed_cup.order:
			_placed_cup.order.brew_quality = _shot_quality * _stir_quality
			_placed_cup.order.correct_grind_level = _correct_grind
			_placed_cup.order.grind_quality = _grind_quality * (1.0 if _correct_grind else 0.5)
		_placed_cup.set_fill(0.3, Color(0.25, 0.15, 0.05))
	if _placed_device:
		_placed_device.reset_device()
		_placed_device.global_position = Vector3(global_position.x + 0.15, global_position.y + 0.18, global_position.z)
		_shelf_device = _placed_device
		_placed_device = null
	if _placed_cup:
		for child in _placed_cup.get_children():
			if child is CollisionShape3D:
				child.disabled = false
	state = State.DONE
	_update_label()

func _reset() -> void:
	state = State.IDLE
	_shot_quality = 0.0
	_stir_quality = 1.0
	_grind_quality = 1.0
	_correct_grind = true
	_press_game.reset_phase()
	if _placed_device:
		_placed_device.reset_device()
		_placed_device.global_position = Vector3(global_position.x + 0.15, global_position.y + 0.18, global_position.z)
		_shelf_device = _placed_device
		_placed_device = null
	_update_label()

func _update_label() -> void:
	if not _status_label:
		return
	match state:
		State.IDLE:
			var has_shelf := _shelf_device != null and is_instance_valid(_shelf_device)
			_status_label.text = "[E] Pick up aeropress" if has_shelf else "[Click] Place cup"
		State.CUP_ONLY:
			var has_shelf := _shelf_device != null and is_instance_valid(_shelf_device)
			_status_label.text = "[E] Pick up aeropress" if has_shelf else "Bring aeropress w/ grounds"
		State.DEVICE_ONLY:
			if _placed_device and _placed_device.has_grounds():
				_status_label.text = "[Click] Place cup"
			else:
				_status_label.text = "[E] Pick up device\n(needs grounds)"
		State.READY_FOR_WATER:
			_status_label.text = "[E] Pour water\n(hold filled kettle)"
		State.HAS_WATER:
			_status_label.text = "[E] Stir"
		State.STEEPING:
			_status_label.text = "Steeping..."
		State.READY_TO_PRESS:
			_status_label.text = "[E] Press!"
		State.PRESSING:
			_status_label.text = "Pressing..."
		State.DONE:
			_status_label.text = "[Click] Pick up cup"
		State.DEAD:
			_status_label.text = "[E] Reset (dead)"
