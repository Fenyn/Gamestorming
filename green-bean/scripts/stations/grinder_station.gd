extends StaticBody3D

const GrinderModel := preload("res://model_src/hand_grinder.gd")

enum State { IDLE, DEVICE_PLACED, GRINDING, GROUNDS_READY }

var state := State.IDLE
var _mini_game: GrindMiniGame = null
var _placed_device: Node3D = null
var _device_slot: Marker3D = null
var _status_label: Label3D = null
var _dust: GPUParticles3D = null
var _crank_pivot: Node3D = null

func _ready() -> void:
	add_to_group("station")

	_device_slot = Marker3D.new()
	_device_slot.name = "DeviceSlot"
	# On the dosing pad in front of the spout. Devices are lifted by half their
	# height when placed, so their base sits on the pad.
	_device_slot.position = Vector3(0, GrinderModel.BASE_TOP, 0.055)
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
	_build_fx()

func _build_fx() -> void:
	# Grounds falling into the device while the player cranks.
	_dust = Fx.make_specks(Color(0.32, 0.2, 0.1), 0.006, -1.5, 0.45, 30)
	_dust.position = GrinderModel.SPOUT_TIP
	add_child(_dust)

	# Crank handle on the right side that turns with the player's mouse circles.
	_crank_pivot = Node3D.new()
	_crank_pivot.position = GrinderModel.CRANK_PIVOT + Vector3(0.012, 0, 0)
	add_child(_crank_pivot)
	var crank_mat := StandardMaterial3D.new()
	crank_mat.albedo_color = Color(0.25, 0.25, 0.27)
	crank_mat.metallic = 0.6
	crank_mat.roughness = 0.35
	var arm := CSGBox3D.new()
	arm.size = Vector3(0.01, 0.075, 0.016)
	arm.position = Vector3(0, 0.0375, 0)
	arm.material = crank_mat
	_crank_pivot.add_child(arm)
	var knob_mat := StandardMaterial3D.new()
	knob_mat.albedo_color = Color(0.45, 0.28, 0.16)
	var knob := CSGCylinder3D.new()
	knob.radius = 0.012
	knob.height = 0.03
	knob.rotation_degrees = Vector3(0, 0, 90)
	knob.position = Vector3(0.018, 0.075, 0)
	knob.material = knob_mat
	_crank_pivot.add_child(knob)

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
	StationUtils.place_at_slot(item, _device_slot.global_position + Vector3(0, _half_height(item), 0))
	state = State.DEVICE_PLACED
	_update_label()
	return true

func _half_height(item: Node3D) -> float:
	for child in item.get_children():
		if child is CollisionShape3D and (child as CollisionShape3D).shape is CylinderShape3D:
			return ((child as CollisionShape3D).shape as CylinderShape3D).height * 0.5
	return 0.05

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
	if _dust:
		_dust.emitting = _mini_game.is_cranking()
	if _crank_pivot:
		_crank_pivot.rotation.x = -_mini_game.get_crank_rotation() * 0.35

	if state == State.GRINDING and not _mini_game.is_active():
		state = State.DEVICE_PLACED
		_update_label()

	if (state == State.DEVICE_PLACED or state == State.GROUNDS_READY) and StationUtils.is_item_removed(_placed_device, _device_slot.global_position):
		_placed_device = null
		state = State.IDLE
		_update_label()
