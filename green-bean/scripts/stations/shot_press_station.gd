extends StaticBody3D

enum State { IDLE, CUP_ONLY, DEVICE_ONLY, READY_FOR_WATER, HAS_WATER, STEEPING, READY_TO_PRESS, PRESSING, DONE, DEAD }

var state := State.IDLE
var _placed_cup: Cup = null
var _placed_device: ShotPress = null
var _shelf_device: ShotPress = null

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

var _cup_slot: Marker3D = null
var _device_slot: Marker3D = null
var _cup_spot := Vector3.ZERO
var _device_rest := Vector3.ZERO
var _gauge_anchor := Vector3.ZERO
var _status_label: Label3D = null

func _ready() -> void:
	add_to_group("station")

	_cup_spot = StationUtils.model_marker(self, "CupSpot", Vector3(-0.045, 0.005, 0.02))
	_device_rest = StationUtils.model_marker(self, "DeviceRest", Vector3(0.09, 0.021, -0.02))
	_gauge_anchor = StationUtils.model_marker(self, "GaugeAnchor", _cup_spot + Vector3(0.17, 0.26, 0.04))

	_cup_slot = Marker3D.new()
	_cup_slot.name = "CupSlot"
	_cup_slot.position = _cup_spot
	add_child(_cup_slot)

	_device_slot = Marker3D.new()
	_device_slot.name = "DeviceSlot"
	_device_slot.position = _cup_spot + Vector3(0, 0.18, 0)
	add_child(_device_slot)

	var cam_xform := Transform3D(Basis.from_euler(Vector3(deg_to_rad(-30), 0, 0)), Vector3(0, 0.4, 0.4))
	var view := get_node_or_null("Model/CameraView") as Node3D
	if view:
		cam_xform = global_transform.affine_inverse() * view.global_transform
	var cam_pos := cam_xform.origin
	var cam_rot := cam_xform.basis.get_euler() * 180.0 / PI

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

	# Mini-game gauges are positioned relative to the game node, so move the node.
	_offset_game(_press_game, _gauge_anchor - Vector3(0, 0.2, 0.18))
	_offset_game(_water_game, Vector3.ZERO)
	_water_game._status_label.position = _gauge_anchor
	_water_game._status_label.rotation_degrees = Vector3.ZERO
	_water_game._status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED

	_spawn_shelf_device()
	_status_label = StationUtils.create_status_label(self, _cup_spot + Vector3(0.06, 0.36, 0.05))
	_update_label()

## Moves a mini-game node by offset while keeping its camera in place.
func _offset_game(game: Node3D, offset: Vector3) -> void:
	var cam_world_local: Vector3 = game.position + game._camera_point.position
	game.position = offset
	game._camera_point.position = cam_world_local - offset

func _spawn_shelf_device() -> void:
	_shelf_device = ShotPress.new()
	_shelf_device.name = "ShotPressShelf"
	add_child(_shelf_device)
	_shelf_device.position = _rest_position(_shelf_device)

func _rest_position(device: Node3D) -> Vector3:
	return _device_rest + Vector3(0, StationUtils.item_half_height(device, 0.06), 0)

func _cup_position(cup: Node3D) -> Vector3:
	return _cup_spot + Vector3(0, StationUtils.item_half_height(cup, 0.06), 0)

## Device centre with its flange on the placed cup's rim.
func _device_on_cup_position(device: Node3D) -> Vector3:
	var cup_top := _cup_spot.y + (StationUtils.item_half_height(_placed_cup, 0.06) * 2.0 if _placed_cup else 0.12)
	var rim_offset := (device as ShotPress).rim_rest_y if device is ShotPress else -0.05
	return Vector3(_cup_spot.x, cup_top - rim_offset, _cup_spot.z)

func _stand_free() -> bool:
	return _shelf_device == null or not is_instance_valid(_shelf_device)

func _return_to_stand(device: ShotPress) -> void:
	device.reset_device()
	StationUtils.cancel_settle(device)
	device.global_position = to_global(_rest_position(device))
	device.global_basis = global_basis
	StationUtils.set_item_collision(device, true)
	_shelf_device = device

func _place_stir_game() -> void:
	if not _placed_device:
		return
	var top := _device_on_cup_position(_placed_device).y + 0.0605
	# The paddle's handle is drawn 0.33 above the stir node; dip it 1 cm in.
	var offset := Vector3(_cup_spot.x, top - 0.01 - 0.33, _cup_spot.z)
	_offset_game(_stir_game, offset)
	_stir_game._status_label.position = _gauge_anchor - offset

func _any_game_active() -> bool:
	return _press_game.is_active() or _stir_game.is_active() or _water_game.is_active()

func interact(player: Player) -> void:
	if _any_game_active():
		return
	match state:
		State.IDLE:
			if StationUtils.try_pickup_shelf(player, _shelf_device):
				_shelf_device = null
				_update_label()
		State.CUP_ONLY:
			if _shelf_device and StationUtils.try_pickup_shelf(player, _shelf_device):
				_shelf_device = null
				_update_label()
			elif not player.has_held_item() and _placed_cup:
				if StationUtils.try_pickup_placed(player, _placed_cup):
					_placed_cup = null
					_recalculate_state()
		State.DEVICE_ONLY:
			if StationUtils.try_pickup_placed(player, _placed_device):
				_placed_device = null
				_recalculate_state()
		State.READY_FOR_WATER:
			var held := player.get_held_item()
			if held is Kettle and (held as Kettle).has_water:
				_pouring_player = player
				_pour_kettle = held as Kettle
				_pour_tween = StationUtils.start_kettle_pour(player, _pour_kettle, _placed_device.global_position, Vector3(0, 0.10, 0), _water_game.is_pouring)
				_water_game.start(player)
			elif _status_label:
				_status_label.text = "Hold filled kettle!\n[E] Pour water"
		State.HAS_WATER:
			_place_stir_game()
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
			if not player.has_held_item() and _placed_cup:
				if StationUtils.try_pickup_placed(player, _placed_cup):
					_placed_cup = null
					_recalculate_state()
		State.DEAD:
			_reset()

func receive_item(item: Node3D) -> bool:
	if _any_game_active():
		return false
	if item is Cup:
		if _placed_cup:
			return false
		var cup := item as Cup
		if cup.has_shot:
			return false
		_placed_cup = cup
		_cup_slot.position = _cup_position(cup)
		StationUtils.place_at_slot(item, _cup_slot.global_position)
		item.global_basis = global_basis
		# A loaded shot press waiting in the stand goes straight onto the cup.
		if not _placed_device and not _stand_free() and _shelf_device.has_grounds():
			var waiting := _shelf_device
			_shelf_device = null
			_mount_device(waiting)
		_recalculate_state()
		return true
	if item is ShotPress:
		if _placed_device:
			return false
		if _placed_cup:
			_mount_device(item as ShotPress)
		elif _stand_free():
			# No cup yet: stand it in the cradle until one arrives.
			StationUtils.place_at_slot(item, to_global(_rest_position(item)))
			item.global_basis = global_basis
			StationUtils.set_item_collision(item, true)
			_shelf_device = item as ShotPress
		else:
			return false
		_recalculate_state()
		return true
	return false

func _mount_device(device: ShotPress) -> void:
	_placed_device = device
	_device_slot.position = _device_on_cup_position(device)
	StationUtils.place_at_slot(device, _device_slot.global_position)
	device.global_basis = global_basis
	if device.has_grounds():
		_correct_grind = (device.grounds.grind_level == DrinkData.GrindLevel.FINE)
		_grind_quality = device.grounds.grind_quality

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
	StationUtils.stop_kettle_pour(_pour_tween, _pour_kettle, _pouring_player)
	_pour_tween = null
	if _pour_kettle and is_instance_valid(_pour_kettle):
		_pour_kettle.use_water(Kettle.SHOT_PRESS_COST)
	_pouring_player = null
	_pour_kettle = null
	state = State.HAS_WATER
	_update_label()

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

	if state == State.READY_FOR_WATER and _water_game.is_active() and _placed_device:
		_placed_device.set_liquid_level(_water_game._fill_level)

	_check_removed_items()

func _check_removed_items() -> void:
	if _shelf_device and StationUtils.is_item_removed(_shelf_device, to_global(_rest_position(_shelf_device)), 0.15):
		_shelf_device = null
		_update_label()
	# is_item_removed() is true for null, so only check items that are here.
	if _placed_cup and StationUtils.is_item_removed(_placed_cup, _cup_slot.global_position):
		_placed_cup = null
		_recalculate_state()
	if _placed_device and StationUtils.is_item_removed(_placed_device, _device_slot.global_position):
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
		StationUtils.set_item_collision(_placed_cup, true)
	if _placed_device:
		var used := _placed_device
		_placed_device = null
		if _stand_free():
			_return_to_stand(used)
		else:
			used.reset_device()
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
		var used := _placed_device
		_placed_device = null
		if _stand_free():
			_return_to_stand(used)
		else:
			used.reset_device()
	_update_label()

func _update_label() -> void:
	if not _status_label:
		return
	match state:
		State.IDLE:
			if not _stand_free() and _shelf_device.has_grounds():
				_status_label.text = "[Click] Place cup"
			elif not _stand_free():
				_status_label.text = "[E] Pick up shot press"
			else:
				_status_label.text = "[Click] Place cup"
		State.CUP_ONLY:
			var has_shelf := _shelf_device != null and is_instance_valid(_shelf_device)
			_status_label.text = "[E] Pick up shot press" if has_shelf else "Bring shot press w/ grounds"
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
			_status_label.text = "[E] Pick up cup"
		State.DEAD:
			_status_label.text = "[E] Reset (dead)"
