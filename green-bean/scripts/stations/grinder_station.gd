extends StaticBody3D

enum State { IDLE, DEVICE_PLACED, GRINDING, GROUNDS_READY }

var state := State.IDLE
var _mini_game: GrindMiniGame = null
var _placed_device: Node3D = null
var _device_slot: Marker3D = null

var _status_label: Label3D = null

func _ready() -> void:
	add_to_group("station")

	_device_slot = Marker3D.new()
	_device_slot.name = "DeviceSlot"
	_device_slot.position = Vector3(0, 0.2, 0)
	add_child(_device_slot)

	_mini_game = GrindMiniGame.new()
	_mini_game.name = "GrindMiniGame"
	var cam := Marker3D.new()
	cam.name = "CameraPoint"
	cam.position = Vector3(0, 0.4, 0.4)
	cam.rotation_degrees = Vector3(-30, 0, 0)
	_mini_game.add_child(cam)
	add_child(_mini_game)
	_mini_game._camera_point = cam
	_mini_game.mini_game_completed.connect(_on_grind_complete)
	print("[Grinder] camera_point set: ", _mini_game._camera_point)

	_status_label = Label3D.new()
	_status_label.text = ""
	_status_label.font_size = 12
	_status_label.position = Vector3(0, 0.3, 0.15)
	_status_label.pixel_size = 0.002
	_status_label.add_to_group("world_label")
	add_child(_status_label)
	_update_label()

func interact(player: Player) -> void:
	print("[Grinder] interact, state=", State.keys()[state], " mini_active=", _mini_game.is_active())
	match state:
		State.IDLE:
			if _status_label:
				_status_label.text = "Place device here\n(dripper or aeropress)"
		State.DEVICE_PLACED:
			if _mini_game.is_active():
				_mini_game.stop()
				state = State.DEVICE_PLACED
				_update_label()
			else:
				_mini_game.start(player)
				if _mini_game.is_active():
					state = State.GRINDING
					_update_label()
					print("[Grinder] Grind started! Move mouse to grind.")
		State.GRINDING:
			_mini_game.stop()
			state = State.DEVICE_PLACED
			_update_label()
		State.GROUNDS_READY:
			_give_device_to_player(player)

func _give_device_to_player(player: Player) -> void:
	if not player.has_held_item() and _placed_device and is_instance_valid(_placed_device):
		_enable_item_collision(_placed_device)
		player.pickup_item(_placed_device)
		_placed_device = null
		state = State.IDLE
		_update_label()
		print("[Grinder] Device picked up with grounds")

func receive_item(item: Node3D) -> bool:
	if state != State.IDLE:
		return false
	if not (item is AeropressDevice or item is Dripper):
		return false
	_placed_device = item
	item.global_position = _device_slot.global_position
	item.global_rotation = Vector3.ZERO
	if item is RigidBody3D:
		(item as RigidBody3D).freeze = true
	_disable_item_collision(item)
	state = State.DEVICE_PLACED
	_update_label()
	print("[Grinder] Device placed, ready to grind")
	return true

func _disable_item_collision(item: Node3D) -> void:
	for child in item.get_children():
		if child is CollisionShape3D:
			child.disabled = true

func _enable_item_collision(item: Node3D) -> void:
	for child in item.get_children():
		if child is CollisionShape3D:
			child.disabled = false

func _on_grind_complete(quality: float) -> void:
	if not _placed_device:
		return
	var g := Grounds.new()
	g.grind_level = _mini_game.grind_level
	g.grind_quality = quality
	if _placed_device is AeropressDevice:
		(_placed_device as AeropressDevice).add_grounds(g)
	elif _placed_device is Dripper:
		(_placed_device as Dripper).add_grounds(g)
	state = State.GROUNDS_READY
	_update_label()
	print("[Grinder] Grind complete! Pick up device.")

func _update_label() -> void:
	if not _status_label:
		return
	match state:
		State.IDLE:
			_status_label.text = "Place device to grind\n[Click] with dripper/aeropress"
		State.DEVICE_PLACED:
			var level_str := "FINE" if _mini_game.grind_level == DrinkData.GrindLevel.FINE else "COARSE"
			_status_label.text = "[E] Start grinding (%s)\nRClick: toggle level" % level_str
		State.GRINDING:
			_status_label.text = "Move mouse to grind!\nE: stop"
		State.GROUNDS_READY:
			_status_label.text = "Done! [E] pick up device"

func _input(event: InputEvent) -> void:
	if state == State.DEVICE_PLACED and not _mini_game.is_active():
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_mini_game.toggle_grind_level()
			_update_label()

func _process(_delta: float) -> void:
	if state == State.GRINDING and not _mini_game.is_active():
		state = State.DEVICE_PLACED
		_update_label()

	if _placed_device and (state == State.DEVICE_PLACED or state == State.GROUNDS_READY):
		if not is_instance_valid(_placed_device):
			_placed_device = null
			state = State.IDLE
			_update_label()
		elif _placed_device.global_position.distance_to(_device_slot.global_position) > 0.5:
			_placed_device = null
			state = State.IDLE
			_update_label()
