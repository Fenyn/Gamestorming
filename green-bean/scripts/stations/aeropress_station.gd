extends StaticBody3D

# Player flow:
# 1. Place cup on station
# 2. Pick up aeropress device from shelf (or bring one)
# 3. Carry device to grinder, grind (grounds go into device)
# 4. Carry device back, place on station (on top of cup)
# 5. [E] Pour water into chamber → water mini-game
# 6. [E] Stir → stir mini-game
# 7. Steep (passive — walk away)
# 8. [E] Press → press mini-game → shot into cup
# 9. Pick up cup (has shot)

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

	_press_game = PressMiniGame.new()
	_press_game.name = "PressMiniGame"
	var cam1 := Marker3D.new()
	cam1.name = "CameraPoint"
	cam1.position = Vector3(0, 0.4, 0.4)
	cam1.rotation_degrees = Vector3(-30, 0, 0)
	_press_game.add_child(cam1)
	add_child(_press_game)
	_press_game.mini_game_completed.connect(_on_press_complete)

	_stir_game = StirMiniGame.new()
	_stir_game.name = "StirMiniGame"
	var cam2 := Marker3D.new()
	cam2.name = "CameraPoint"
	cam2.position = Vector3(0, 0.4, 0.4)
	cam2.rotation_degrees = Vector3(-30, 0, 0)
	_stir_game.add_child(cam2)
	add_child(_stir_game)
	_stir_game.mini_game_completed.connect(_on_stir_complete)

	_water_game = PourMiniGame.new()
	_water_game.name = "WaterPourMiniGame"
	_water_game.pour_mode = PourMiniGame.PourMode.FILL_LINE
	var cam3 := Marker3D.new()
	cam3.name = "CameraPoint"
	cam3.position = Vector3(0, 0.4, 0.4)
	cam3.rotation_degrees = Vector3(-30, 0, 0)
	_water_game.add_child(cam3)
	add_child(_water_game)
	_water_game.mini_game_completed.connect(_on_water_complete)

	_spawn_shelf_device()

	_status_label = Label3D.new()
	_status_label.text = ""
	_status_label.font_size = 12
	_status_label.position = Vector3(0, 0.3, 0.15)
	_status_label.pixel_size = 0.002
	add_child(_status_label)
	_update_label()

func _spawn_shelf_device() -> void:
	_shelf_device = AeropressDevice.new()
	_shelf_device.name = "AeropressShelf"
	add_child(_shelf_device)
	_shelf_device.position = Vector3(0.15, 0.18, 0)

func interact(player: Player) -> void:
	match state:
		State.IDLE:
			_try_pickup_shelf_device(player)
		State.CUP_ONLY:
			_try_pickup_shelf_device(player)
		State.DEVICE_ONLY:
			if _status_label:
				_status_label.text = "Place a cup first!"
		State.READY_FOR_WATER:
			if _water_game.is_active():
				_water_game.stop()
			else:
				_water_game.start(player)
		State.HAS_WATER:
			if _stir_game.is_active():
				_stir_game.stop()
			else:
				_stir_game.start(player)
		State.STEEPING:
			pass
		State.READY_TO_PRESS:
			if _press_game.is_active():
				_press_game.stop()
			else:
				state = State.PRESSING
				_update_label()
				_press_game.start(player)
		State.PRESSING:
			_press_game.stop()
		State.DONE:
			if _status_label:
				_status_label.text = "Pick up cup!\n(has shot)"
		State.DEAD:
			_reset()

func _try_pickup_shelf_device(player: Player) -> void:
	if not player.has_held_item() and _shelf_device and is_instance_valid(_shelf_device):
		player.pickup_item(_shelf_device)
		_shelf_device = null
		_update_label()

func receive_item(item: Node3D) -> bool:
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
		var dev := item as AeropressDevice
		_placed_device = dev
		_place_at_slot(item, _device_slot)
		if dev.has_grounds():
			_correct_grind = (dev.grounds.grind_level == DrinkData.GrindLevel.FINE)
			_grind_quality = dev.grounds.grind_quality
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
			if _status_label:
				_status_label.text = "Device needs grounds!\nTake to grinder first"
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
	if state == State.STEEPING:
		if _press_game.phase == PressMiniGame.Phase.READY:
			state = State.READY_TO_PRESS
			_update_label()
		elif _press_game.phase == PressMiniGame.Phase.DEAD:
			state = State.DEAD
			_update_label()

	if state == State.READY_TO_PRESS:
		if _press_game.phase == PressMiniGame.Phase.DEAD:
			state = State.DEAD
			_update_label()

	if state == State.PRESSING and not _press_game.is_active():
		if _press_game.phase == PressMiniGame.Phase.DEAD:
			state = State.DEAD
		elif _press_game.phase in [PressMiniGame.Phase.READY, PressMiniGame.Phase.OVER_EXTRACTING]:
			state = State.READY_TO_PRESS
		_update_label()

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
			if has_shelf:
				_status_label.text = "[E] Pick up aeropress\nor [Click] place cup"
			else:
				_status_label.text = "[Click] Place cup"
		State.CUP_ONLY:
			var has_shelf := _shelf_device != null and is_instance_valid(_shelf_device)
			if has_shelf:
				_status_label.text = "Cup placed\n[E] Pick up aeropress"
			else:
				_status_label.text = "Cup placed\nBring aeropress with grounds"
		State.DEVICE_ONLY:
			if _placed_device and _placed_device.has_grounds():
				_status_label.text = "Place a cup first!"
			else:
				_status_label.text = "Device needs grounds!\nTake to grinder"
		State.READY_FOR_WATER:
			_status_label.text = "[E] Pour water"
		State.HAS_WATER:
			_status_label.text = "[E] Stir"
		State.STEEPING:
			_status_label.text = "STEEPING..."
		State.READY_TO_PRESS:
			if _press_game.phase == PressMiniGame.Phase.OVER_EXTRACTING:
				_status_label.text = "[E] PRESS NOW!\n(over-extracting!)"
			else:
				_status_label.text = "[E] PRESS NOW!"
		State.PRESSING:
			_status_label.text = "PRESSING..."
		State.DONE:
			_status_label.text = "Shot ready!\n[Click] Pick up cup"
		State.DEAD:
			_status_label.text = "Shot dead!\n[E] Reset"
