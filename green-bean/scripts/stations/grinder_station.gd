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
	_mini_game.mini_game_completed.connect(_on_grind_complete)

	_status_label = Label3D.new()
	_status_label.text = ""
	_status_label.font_size = 12
	_status_label.position = Vector3(0, 0.3, 0.15)
	_status_label.pixel_size = 0.002
	add_child(_status_label)
	_update_label()

func interact(player: Player) -> void:
	match state:
		State.IDLE:
			if _status_label:
				_status_label.text = "Place a device here\n(dripper or aeropress)"
		State.DEVICE_PLACED:
			if _mini_game.is_active():
				_mini_game.stop()
			else:
				_mini_game.start(player)
		State.GRINDING:
			_mini_game.stop()
		State.GROUNDS_READY:
			_give_device_to_player(player)

func _give_device_to_player(player: Player) -> void:
	if not player.has_held_item() and _placed_device and is_instance_valid(_placed_device):
		_enable_item_collision(_placed_device)
		player.pickup_item(_placed_device)
		_placed_device = null
		state = State.IDLE
		_update_label()

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

func _update_label() -> void:
	if not _status_label:
		return
	match state:
		State.IDLE:
			_status_label.text = "Place device to grind\n[Click] with dripper/aeropress"
		State.DEVICE_PLACED:
			_status_label.text = "[E] Start grinding\nRClick: toggle grind level"
		State.GRINDING:
			_status_label.text = "GRINDING..."
		State.GROUNDS_READY:
			_status_label.text = "Done! [Click] pick up device"

func _process(_delta: float) -> void:
	if _placed_device and (state == State.DEVICE_PLACED or state == State.GROUNDS_READY):
		if not is_instance_valid(_placed_device):
			_placed_device = null
			state = State.IDLE
			_update_label()
		elif _placed_device.global_position.distance_to(_device_slot.global_position) > 0.5:
			_placed_device = null
			state = State.IDLE
			_update_label()
