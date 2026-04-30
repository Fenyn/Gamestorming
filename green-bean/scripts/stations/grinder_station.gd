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

	_status_label = StationUtils.create_status_label(self)
	_update_label()

func interact(player: Player) -> void:
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
		State.GRINDING:
			_mini_game.stop()
			state = State.DEVICE_PLACED
			_update_label()
		State.GROUNDS_READY:
			if StationUtils.try_pickup_placed(player, _placed_device):
				_placed_device = null
				state = State.IDLE
				_update_label()

func receive_item(item: Node3D) -> bool:
	if state != State.IDLE:
		return false
	if not (item is AeropressDevice or item is Dripper):
		return false
	_placed_device = item
	StationUtils.place_at_slot(item, _device_slot.global_position)
	state = State.DEVICE_PLACED
	_update_label()
	return true

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

	if (state == State.DEVICE_PLACED or state == State.GROUNDS_READY) and StationUtils.is_item_removed(_placed_device, _device_slot.global_position):
		_placed_device = null
		state = State.IDLE
		_update_label()
