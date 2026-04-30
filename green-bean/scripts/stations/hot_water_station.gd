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

func _ready() -> void:
	add_to_group("station")

	_fill_cam = Marker3D.new()
	_fill_cam.name = "FillCam"
	_fill_cam.position = FILL_CAM_POS
	_fill_cam.rotation_degrees = FILL_CAM_ROT
	add_child(_fill_cam)

	_pour_game = PourMiniGame.new()
	_pour_game.name = "WaterPourGame"
	_pour_game.pour_mode = PourMiniGame.PourMode.FILL_LINE
	var cam := Marker3D.new()
	cam.name = "CameraPoint"
	cam.position = FILL_CAM_POS
	cam.rotation_degrees = FILL_CAM_ROT
	_pour_game.add_child(cam)
	add_child(_pour_game)
	_pour_game._camera_point = cam
	_pour_game.mini_game_completed.connect(_on_pour_complete)

	_spawn_shelf_kettle()

	_status_label = Label3D.new()
	_status_label.text = ""
	_status_label.font_size = 12
	_status_label.position = Vector3(0, 0.3, 0.15)
	_status_label.pixel_size = 0.002
	_status_label.add_to_group("world_label")
	add_child(_status_label)

	_fill_label = Label3D.new()
	_fill_label.text = ""
	_fill_label.font_size = 14
	_fill_label.position = Vector3(0, 0.20, 0.18)
	_fill_label.pixel_size = 0.001
	_fill_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_fill_label.visible = false
	add_child(_fill_label)

	_update_label()

func _spawn_shelf_kettle() -> void:
	_shelf_kettle = Kettle.new()
	_shelf_kettle.name = "KettleShelf"
	add_child(_shelf_kettle)
	_shelf_kettle.position = Vector3(0.12, 0.2, 0)

func interact(player: Player) -> void:
	if _pour_game.is_active() or _filling:
		return

	var held := player.get_held_item()

	if not held and _shelf_kettle and is_instance_valid(_shelf_kettle):
		player.pickup_item(_shelf_kettle)
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
		_player_ref.enter_mini_game(_fill_cam.global_transform)
		_fill_label.visible = true
		return

	if held is Cup:
		var cup := held as Cup
		if cup.has_shot and not cup.has_hot_water:
			_player_ref = player
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
	if Engine.get_process_frames() == _fill_frame:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("move_left") or event.is_action_pressed("move_right") or event.is_action_pressed("move_back"):
		_stop_filling()

func _process(delta: float) -> void:
	if _filling and _filling_kettle and is_instance_valid(_filling_kettle):
		_filling_kettle.water_level = minf(_filling_kettle.water_level + FILL_RATE * delta, Kettle.MAX_WATER)
		if _fill_label:
			_fill_label.text = "Filling... %.0f%%\n[E] Stop" % _filling_kettle.get_level_percent()
		if _filling_kettle.water_level >= Kettle.MAX_WATER - 0.01:
			_stop_filling()

func _stop_filling() -> void:
	_filling = false
	_filling_kettle = null
	_fill_label.visible = false
	if _player_ref and is_instance_valid(_player_ref):
		_player_ref.exit_mini_game()
		_player_ref = null
	_update_label()

func _on_pour_complete(quality: float) -> void:
	if not _player_ref:
		return
	var held := _player_ref.get_held_item()
	if held and held is Cup:
		var cup := held as Cup
		cup.has_hot_water = true
		if cup.order:
			cup.order.pour_quality = quality
		cup.set_fill(0.85, Color(0.3, 0.2, 0.1))
	_player_ref = null
	_update_label()

func _update_label() -> void:
	if not _status_label:
		return
	var has_shelf := _shelf_kettle != null and is_instance_valid(_shelf_kettle)
	if has_shelf:
		_status_label.text = "[E] Pick up kettle"
	else:
		_status_label.text = "[E] Fill kettle / pour"
