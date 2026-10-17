extends StaticBody3D

enum State { IDLE, CUP_PLACED, PUMPING }

@export var syrup_type: DrinkData.SyrupType = DrinkData.SyrupType.VANILLA

var state := State.IDLE
var _mini_game: SyrupMiniGame = null
var _placed_cup: Cup = null
var _cup_slot: Marker3D = null
var _status_label: Label3D = null
var _activate_frame := -1

func _ready() -> void:
	add_to_group("station")

	# Cup spot on the drip tray under the spout; the cup is stood on it.
	_cup_slot = Marker3D.new()
	_cup_slot.name = "CupSlot"
	_cup_slot.position = StationUtils.model_marker(self, "CupSpot", Vector3(0, 0.012, 0.05))
	add_child(_cup_slot)

	_mini_game = SyrupMiniGame.new()
	_mini_game.name = "SyrupMiniGame"
	var cam := Marker3D.new()
	cam.name = "CameraPoint"
	var view := get_node_or_null("Model/CameraView") as Node3D
	if view:
		cam.transform = view.transform
	else:
		cam.position = Vector3(0, 0.43, 0.36)
		cam.rotation_degrees = Vector3(-28, 0, 0)
	_mini_game.add_child(cam)
	add_child(_mini_game)
	_mini_game._camera_point = cam
	_mini_game.mini_game_completed.connect(_on_pump_complete)
	_mini_game.set_bottle_color(DrinkData.get_syrup_color(syrup_type))
	var pump := get_node_or_null("Model/PumpHead") as Node3D
	if pump:
		_mini_game.set_pump(pump)
	_dress_bottle()

	_status_label = StationUtils.create_status_label(self)
	_update_label()

## Flavour name on the label and syrup colour in the bottle.
func _dress_bottle() -> void:
	var label := get_node_or_null("Model/NameLabel") as Label3D
	if label:
		label.text = DrinkData.get_syrup_name(syrup_type)
	var syrup := get_node_or_null("Model/Syrup") as MeshInstance3D
	if syrup:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = DrinkData.get_syrup_color(syrup_type)
		mat.roughness = 0.25
		syrup.material_override = mat

func _cup_position(item: Node3D) -> Vector3:
	return _cup_slot.global_position + Vector3(0, StationUtils.item_half_height(item), 0)

func interact(player: Player) -> void:
	if StationUtils.is_same_frame(_activate_frame):
		return
	match state:
		State.IDLE:
			pass
		State.CUP_PLACED:
			if _mini_game.is_active():
				return
			if _placed_cup.syrup_pumps > 0.0:
				if StationUtils.try_pickup_placed(player, _placed_cup):
					_placed_cup = null
					state = State.IDLE
					_update_label()
			else:
				_start_pumping(player)
		State.PUMPING:
			_mini_game.stop()
			state = State.CUP_PLACED
			_update_label()

func _start_pumping(player: Player) -> void:
	if player.has_held_item():
		return
	var target := DrinkData.get_target_pumps(_placed_cup.cup_size)
	_mini_game.set_current(_placed_cup.syrup_pumps)
	_mini_game.set_target(float(target))
	_mini_game.start(player)
	if _mini_game.is_active():
		_activate_frame = Engine.get_process_frames()
		state = State.PUMPING
		_update_label()

func receive_item(item: Node3D) -> bool:
	if state != State.IDLE:
		return false
	if not item is Cup:
		return false
	_placed_cup = item as Cup
	StationUtils.place_at_slot(item, _cup_position(item))
	state = State.CUP_PLACED
	_update_label()
	return true

func _on_pump_complete(quality: float) -> void:
	if not _placed_cup:
		return
	_placed_cup.syrup_pumps = _mini_game.current_pumps
	_placed_cup.syrup_type = syrup_type
	if _placed_cup.order:
		_placed_cup.order.syrup_quality = quality

func _update_label() -> void:
	if not _status_label:
		return
	var syrup_name := DrinkData.get_syrup_name(syrup_type)
	match state:
		State.IDLE:
			_status_label.text = "[Click] Place cup under the pump"
		State.CUP_PLACED:
			if _placed_cup and _placed_cup.syrup_pumps > 0.0:
				_status_label.text = "%s: %.1f pumps\n[E] pick up cup" % [syrup_name, _placed_cup.syrup_pumps]
			else:
				_status_label.text = "%s Syrup\n[E] start pumping" % syrup_name
		State.PUMPING:
			_status_label.text = "Pumping %s...\n[E] done" % syrup_name

func _process(_delta: float) -> void:
	if state == State.PUMPING and not _mini_game.is_active():
		state = State.CUP_PLACED
		_update_label()

	if state != State.IDLE and (not _placed_cup or StationUtils.is_item_removed(_placed_cup, _cup_position(_placed_cup))):
		_placed_cup = null
		state = State.IDLE
		_update_label()
