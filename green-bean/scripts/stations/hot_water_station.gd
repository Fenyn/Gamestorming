extends StaticBody3D

const FILL_RATE := 0.5
const FILL_CAM_POS := Vector3(0, 0.4, 0.4)
const FILL_CAM_ROT := Vector3(-25, 0, 0)

var _shelf_kettle: Kettle = null
var _status_label: Label3D = null
var _fill_label: Label3D = null

var _pour_game: PourMiniGame = null
var _player_ref: Player = null
var _filling_kettle: Kettle = null
var _filling := false
var _fill_frame := -1
var _fill_cam: Marker3D = null
var _stream: PourStream = null
## Cup or kettle standing under the spout while it fills. It is taken from the
## player's hand for the fill and handed back afterwards.
var _under_spout: Node3D = null
var _cup_start_fill := 0.0
var _fill_point := Vector3.ZERO
## Faucet lever in the model. It swings down while water runs.
var _lever: Node3D = null
var _lever_rest := 0.0
const LEVER_PULL_DEG := 30.0

func _ready() -> void:
	add_to_group("station")

	# Camera, spout and fill positions come from the model scene
	# (scenes/props/hot_water_dispenser.tscn). Its CameraView is placed so the
	# held cup or kettle lands under the spout while filling.
	var cam_xform := Transform3D(Basis.from_euler(FILL_CAM_ROT * PI / 180.0), FILL_CAM_POS)
	var view := get_node_or_null("Model/CameraView") as Node3D
	if view:
		cam_xform = global_transform.affine_inverse() * view.global_transform
	_fill_point = StationUtils.model_marker(self, "FillPoint", Vector3(0, 0.03, 0.15))
	var fill_point := _fill_point

	_fill_cam = Marker3D.new()
	_fill_cam.name = "FillCam"
	_fill_cam.transform = cam_xform
	add_child(_fill_cam)

	_pour_game = PourMiniGame.new()
	_pour_game.name = "WaterPourGame"
	_pour_game.pour_mode = PourMiniGame.PourMode.FILL_LINE
	var cam := Marker3D.new()
	cam.name = "CameraPoint"
	cam.transform = cam_xform
	_pour_game.add_child(cam)
	add_child(_pour_game)
	# The pour game's prompt is laid flat for the pour-over; here it stands
	# beside the cup, facing the camera.
	_pour_game._status_label.position = fill_point + Vector3(-0.13, 0.16, 0.0)
	_pour_game._status_label.rotation_degrees = Vector3.ZERO
	_pour_game._status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_pour_game._camera_point = cam
	_pour_game.mini_game_completed.connect(_on_pour_complete)

	_spawn_shelf_kettle()

	_status_label = StationUtils.create_status_label(self, _fill_point + Vector3(0, 0.31, 0.1))

	_fill_label = Label3D.new()
	_fill_label.text = ""
	_fill_label.font_size = 14
	_fill_label.position = fill_point + Vector3(-0.13, 0.16, 0.0)
	_fill_label.pixel_size = 0.001
	_fill_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_fill_label.visible = false
	add_child(_fill_label)

	_update_label()

	_lever = get_node_or_null("Model/Faucet/Lever") as Node3D
	if _lever:
		_lever_rest = _lever.rotation_degrees.x

	# Water from the dispenser spout into whatever the player is holding.
	_stream = PourStream.new(Color(0.85, 0.92, 0.97, 0.75), 0.005)
	_stream.source = self
	_stream.source_offset = StationUtils.model_marker(self, "Spout", Vector3(0, 0.05, 0.11))
	_stream.flow_check = _is_dispensing
	add_child(_stream)

func _is_dispensing() -> bool:
	var target := _under_spout
	if target == null or not is_instance_valid(target):
		return false
	if not (_filling or _pour_game.is_pouring()):
		return false
	_stream.target_node = target
	_stream.target_offset = Vector3(0, StationUtils.item_half_height(target) * 0.6, 0)
	return true

## Stands the held item on the grate under the spout for the fill.
func _take_under_spout(player: Player, item: Node3D) -> void:
	player.detach_held_item()
	_under_spout = item
	StationUtils.place_at_slot(item, to_global(_fill_point + Vector3(0, StationUtils.item_half_height(item), 0)))
	item.global_rotation = global_rotation

## Hands the filled item back to the player.
func _return_from_spout(player: Player) -> void:
	var item := _under_spout
	_under_spout = null
	if item == null or not is_instance_valid(item):
		return
	StationUtils.cancel_settle(item)
	if player and is_instance_valid(player) and not player.has_held_item():
		player.pickup_item(item)

func _spawn_shelf_kettle() -> void:
	_shelf_kettle = Kettle.new()
	_shelf_kettle.name = "KettleShelf"
	add_child(_shelf_kettle)
	_shelf_kettle.position = _rest_position(_shelf_kettle)
	_shelf_kettle.global_basis = _rest_basis()

## Where the kettle waits beside the unit: the model's KettleRest marker, raised
## by half the kettle's height (station-local).
func _rest_position(kettle: Node3D) -> Vector3:
	return StationUtils.model_marker(self, "KettleRest", Vector3(0.175, 0, 0.12)) + Vector3(0, StationUtils.item_half_height(kettle), 0)

## Facing for the kettle at rest, from the KettleRest marker's rotation.
func _rest_basis() -> Basis:
	var marker := get_node_or_null("Model/KettleRest") as Node3D
	return marker.global_basis if marker else global_basis

func _kettle_on_rest() -> bool:
	return _shelf_kettle != null and is_instance_valid(_shelf_kettle)

## Clicking the dispenser with a kettle sets it back on its spot, if free.
func receive_item(item: Node3D) -> bool:
	if not item is Kettle or _kettle_on_rest() or _filling or _pour_game.is_active():
		return false
	StationUtils.place_at_slot(item, to_global(_rest_position(item)))
	item.global_basis = _rest_basis()
	# Leave it clickable, like the kettle the station starts with.
	StationUtils.set_item_collision(item, true)
	_shelf_kettle = item as Kettle
	_update_label()
	return true

func interact(player: Player) -> void:
	if _pour_game.is_active() or _filling:
		return

	var held := player.get_held_item()

	if StationUtils.try_pickup_shelf(player, _shelf_kettle):
		_shelf_kettle = null
		_update_label()
		return

	if held is Kettle:
		var kettle := held as Kettle
		if kettle.water_level >= Kettle.MAX_WATER - 0.01:
			if _status_label:
				_status_label.text = "Kettle already full"
			return
		_filling = true
		_fill_frame = Engine.get_process_frames()
		_filling_kettle = kettle
		_player_ref = player
		_take_under_spout(player, kettle)
		kettle.set_lid_open(true)
		_player_ref.enter_mini_game(_fill_cam.global_transform)
		_fill_label.visible = true
		SoundManager.play_loop("kettle_fill_loop")
		return

	if held is Cup:
		var cup := held as Cup
		if cup.has_shot and not cup.has_hot_water:
			_player_ref = player
			_cup_start_fill = cup.get_fill()
			_take_under_spout(player, cup)
			_pour_game.start(player)
			return
		if not cup.has_shot:
			if _status_label:
				_status_label.text = "Cup needs shot first!"
			return

	if not held:
		if _status_label:
			_status_label.text = "Pick up kettle or\nhold cup with shot"

func _input(event: InputEvent) -> void:
	if not _filling:
		return
	if StationUtils.is_same_frame(_fill_frame):
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("move_left") or event.is_action_pressed("move_right") or event.is_action_pressed("move_back"):
		_stop_filling()

func _process(delta: float) -> void:
	# The cup pour ended (finished, spilled or the player left): hand the cup back.
	if _under_spout and not _filling and not _pour_game.is_active():
		if _under_spout is Cup and not (_under_spout as Cup).has_hot_water:
			(_under_spout as Cup).set_fill(_cup_start_fill, Color(0.3, 0.2, 0.1))
		_return_from_spout(_player_ref)
		_player_ref = null
	if _lever:
		var flowing := _under_spout != null and (_filling or _pour_game.is_pouring())
		var target := _lever_rest + (LEVER_PULL_DEG if flowing else 0.0)
		_lever.rotation_degrees.x = lerpf(_lever.rotation_degrees.x, target, minf(delta * 14.0, 1.0))
	# Show the cup filling as the player pours.
	if _pour_game.is_active() and _under_spout is Cup:
		var level := clampf(_pour_game._fill_level, 0.0, 1.0)
		(_under_spout as Cup).set_fill(lerpf(_cup_start_fill, 0.85, level), Color(0.3, 0.2, 0.1))
	# The kettle can be clicked up straight off its spot; forget it then.
	if _shelf_kettle and StationUtils.is_item_removed(_shelf_kettle, to_global(_rest_position(_shelf_kettle)), 0.15):
		_shelf_kettle = null
		_update_label()
	if _filling and _filling_kettle and is_instance_valid(_filling_kettle):
		_filling_kettle.water_level = minf(_filling_kettle.water_level + FILL_RATE * delta, Kettle.MAX_WATER)
		if _fill_label:
			_fill_label.text = "Filling... %.0f%%\n[E] Stop" % _filling_kettle.get_level_percent()
		if _filling_kettle.water_level >= Kettle.MAX_WATER - 0.01:
			_stop_filling()

func _stop_filling() -> void:
	_filling = false
	SoundManager.stop_loop("kettle_fill_loop")
	if _filling_kettle and _filling_kettle.water_level >= Kettle.MAX_WATER - 0.01:
		SoundManager.play("kettle_full")
	if _filling_kettle and is_instance_valid(_filling_kettle):
		_filling_kettle.set_lid_open(false)
	_filling_kettle = null
	_fill_label.visible = false
	_return_from_spout(_player_ref)
	if _player_ref and is_instance_valid(_player_ref):
		_player_ref.exit_mini_game()
		_player_ref = null
	_update_label()

func _on_pour_complete(quality: float) -> void:
	var held := _under_spout
	if held and is_instance_valid(held) and held is Cup:
		var cup := held as Cup
		cup.has_hot_water = true
		if cup.order:
			cup.order.pour_quality = quality
		cup.set_fill(0.85, Color(0.3, 0.2, 0.1))
	_update_label()

func _update_label() -> void:
	if not _status_label:
		return
	if _kettle_on_rest():
		_status_label.text = "[E] Pick up kettle"
	else:
		_status_label.text = "[E] Fill kettle / pour"
