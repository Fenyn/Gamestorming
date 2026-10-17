extends StaticBody3D


enum State { IDLE, DEVICE_PLACED, GRINDING, DUMPING, GROUNDS_READY }

var state := State.IDLE
var _mini_game: GrindMiniGame = null
var _placed_device: Node3D = null
var _device_slot: Marker3D = null
var _status_label: Label3D = null
var _dust: GPUParticles3D = null
var _crank_pivot: Node3D = null
var _crank_axis := Vector3.RIGHT
var _crank_rest := Basis.IDENTITY
var _catch_cup: Node3D = null
var _cup_lip: Node3D = null
var _cup_home := Transform3D.IDENTITY
var _dump_tween: Tween = null
var _pending_grounds: Grounds = null
## Crank angle while the cup is tipped, keeping the arm out of its way.
const CRANK_PARK_ANGLE := PI * 0.5
var _crank_turn := 0.0

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

	_build_fx()
	_status_label = StationUtils.create_status_label(self, StationUtils.model_marker(self, "SpoutTip", Vector3(0, 0.17, 0.05)) + Vector3(0, 0.25, 0.02))
	_update_label()

func _build_fx() -> void:
	var model := get_node_or_null("Model")
	var pad := model.get_node_or_null("DevicePad") as Node3D if model else null
	if pad:
		_device_slot.global_position = pad.global_position
	var spout := model.get_node_or_null("SpoutTip") as Node3D if model else null
	_crank_pivot = model.get_node_or_null("Crank") as Node3D if model else null
	if _crank_pivot:
		_crank_rest = _crank_pivot.basis
		_crank_axis = model.get_meta("crank_axis", Vector3.RIGHT)
	_catch_cup = model.get_node_or_null("CatchCup") as Node3D if model else null
	if _catch_cup:
		_cup_home = _catch_cup.transform
		_cup_lip = _catch_cup.get_node_or_null("CupLip") as Node3D

	# Gauges are positioned relative to the game node, so move the node to
	# GaugeAnchor and pull its camera back by the same amount.
	var cam: Marker3D = _mini_game._camera_point
	var view := model.get_node_or_null("CameraView") as Node3D if model else null
	if view:
		cam.transform = global_transform.affine_inverse() * view.global_transform
	var anchor := StationUtils.model_marker(self, "GaugeAnchor", Vector3(-0.2, 0.3, 0.06))
	var offset := anchor - Vector3(0, 0.125, 0.18)
	_mini_game.position = offset
	cam.position -= offset

	_dust = Fx.make_specks(Color(0.32, 0.2, 0.1), 0.006, -1.5, 0.45, 30)
	add_child(_dust)
	_dust.global_position = spout.global_position if spout else _device_slot.global_position + Vector3(0, 0.1, 0)
	_dust.emitting = false

func interact(player: Player) -> void:
	match state:
		State.IDLE:
			if _status_label:
				_status_label.text = "Place device here\n(dripper or shot press)"
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
	if not (item is ShotPress or item is Dripper):
		return false
	_placed_device = item
	StationUtils.place_at_slot(item, _device_slot.global_position + Vector3(0, StationUtils.item_half_height(item), 0))
	state = State.DEVICE_PLACED
	_update_label()
	return true

func _on_grind_complete(quality: float) -> void:
	if not _placed_device:
		return
	var g := Grounds.new()
	g.grind_level = _mini_game.grind_level
	g.grind_quality = quality
	if _catch_cup:
		_pending_grounds = g
		state = State.DUMPING
		_update_label()
		_start_dump()
	else:
		_give_grounds(g)

func _give_grounds(g: Grounds) -> void:
	if _placed_device is ShotPress:
		(_placed_device as ShotPress).add_grounds(g)
	elif _placed_device is Dripper:
		(_placed_device as Dripper).add_grounds(g)
	state = State.GROUNDS_READY
	_update_label()

## Catch cup: unscrew, swing over the device, tip, return. The device gets its
## grounds as they pour.
func _start_dump() -> void:
	var model := get_node_or_null("Model") as Node3D
	var dump := model.get_node_or_null("DumpPoint") as Node3D if model else null
	var tipped := dump.transform if dump else _cup_home.translated(Vector3(0.12, 0.15, 0.03))
	var upright_over := Transform3D(_cup_home.basis, tipped.origin + Vector3(0.0, 0.01, 0.0))
	var unscrewed := Transform3D(_cup_home.basis.rotated(Vector3.UP, -1.2), _cup_home.origin + Vector3(0, 0, 0.045))
	_dump_tween = create_tween()
	_dump_tween.tween_property(_catch_cup, "transform", unscrewed, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_dump_tween.tween_property(_catch_cup, "transform", upright_over, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_dump_tween.tween_property(_catch_cup, "transform", tipped, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_dump_tween.tween_callback(func() -> void:
		if _dust:
			_dust.emitting = true
		if _pending_grounds and _placed_device:
			_give_grounds(_pending_grounds)
			state = State.DUMPING
		_pending_grounds = null)
	_dump_tween.tween_interval(0.6)
	_dump_tween.tween_callback(func() -> void:
		if _dust:
			_dust.emitting = false)
	_dump_tween.tween_property(_catch_cup, "transform", upright_over, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_dump_tween.tween_property(_catch_cup, "transform", unscrewed, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_dump_tween.tween_property(_catch_cup, "transform", _cup_home, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_dump_tween.tween_callback(func() -> void:
		if state == State.DUMPING:
			state = State.GROUNDS_READY if _placed_device else State.IDLE
			_update_label())

func _cancel_dump() -> void:
	if _dump_tween and _dump_tween.is_valid():
		_dump_tween.kill()
	_dump_tween = null
	_pending_grounds = null
	if _catch_cup:
		_catch_cup.transform = _cup_home
	if _dust:
		_dust.emitting = false

func _update_label() -> void:
	if not _status_label:
		return
	match state:
		State.IDLE:
			_status_label.text = "Place device to grind\n[Click] with dripper/shot press"
		State.DEVICE_PLACED:
			var level_str := "FINE" if _mini_game.grind_level == DrinkData.GrindLevel.FINE else "COARSE"
			_status_label.text = "[E] Start grinding (%s)\nRClick: toggle level" % level_str
		State.GRINDING:
			_status_label.text = "Move mouse to grind!\nE: stop"
		State.DUMPING:
			_status_label.text = "Tipping grounds in..."
		State.GROUNDS_READY:
			_status_label.text = "Done! [E] pick up device"

func _input(event: InputEvent) -> void:
	if state == State.DEVICE_PLACED and not _mini_game.is_active():
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_mini_game.toggle_grind_level()
			_update_label()

func _process(delta: float) -> void:
	if _dust and not _catch_cup:
		_dust.emitting = _mini_game.is_cranking()
	if _dust and _cup_lip and state == State.DUMPING:
		_dust.global_position = _cup_lip.global_position
	if _crank_pivot:
		# A top crank turns once per mouse circle; a side wheel is geared down.
		var turn := -_mini_game.get_crank_rotation() * (1.0 if _crank_axis == Vector3.UP else 0.35)
		if state == State.DUMPING:
			turn = CRANK_PARK_ANGLE
			_crank_turn = lerp_angle(_crank_turn, turn, minf(delta * 8.0, 1.0))
		else:
			_crank_turn = turn
		_crank_pivot.basis = Basis(_crank_axis, _crank_turn) * _crank_rest

	if state == State.GRINDING and not _mini_game.is_active():
		state = State.DEVICE_PLACED
		_update_label()

	if state == State.DUMPING and _placed_device and StationUtils.is_item_removed(_placed_device, _device_slot.global_position):
		_cancel_dump()
		_placed_device = null
		state = State.IDLE
		_update_label()

	if (state == State.DEVICE_PLACED or state == State.GROUNDS_READY) and StationUtils.is_item_removed(_placed_device, _device_slot.global_position):
		_placed_device = null
		state = State.IDLE
		_update_label()
