extends StaticBody3D

var _shelf_kettle: Kettle = null
var _status_label: Label3D = null

var _pour_game: PourMiniGame = null
var _player_ref: Player = null

func _ready() -> void:
	add_to_group("station")

	_pour_game = PourMiniGame.new()
	_pour_game.name = "WaterPourGame"
	_pour_game.pour_mode = PourMiniGame.PourMode.FILL_LINE
	var cam := Marker3D.new()
	cam.name = "CameraPoint"
	cam.position = Vector3(0, 0.4, 0.4)
	cam.rotation_degrees = Vector3(-25, 0, 0)
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
	_update_label()

func _spawn_shelf_kettle() -> void:
	_shelf_kettle = Kettle.new()
	_shelf_kettle.name = "KettleShelf"
	add_child(_shelf_kettle)
	_shelf_kettle.position = Vector3(0.12, 0.2, 0)

func interact(player: Player) -> void:
	if _pour_game.is_active():
		return

	var held := player.get_held_item()

	# Pick up shelf kettle
	if not held and _shelf_kettle and is_instance_valid(_shelf_kettle):
		player.pickup_item(_shelf_kettle)
		_shelf_kettle = null
		_update_label()
		return

	# Fill empty kettle
	if held is Kettle:
		var kettle := held as Kettle
		if not kettle.has_water:
			kettle.fill()
			if _status_label:
				_status_label.text = "Kettle filled!"
			return
		else:
			if _status_label:
				_status_label.text = "Kettle already full"
			return

	# Americano: pour hot water into cup with shot
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
