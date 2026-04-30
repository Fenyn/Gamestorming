extends StaticBody3D

var _pour_game: PourMiniGame = null
var _player_ref: Player = null

var _status_label: Label3D = null

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
	_pour_game.mini_game_completed.connect(_on_pour_complete)

	_status_label = Label3D.new()
	_status_label.text = "[E] Add hot water\n(hold cup with shot)"
	_status_label.font_size = 12
	_status_label.position = Vector3(0, 0.3, 0.15)
	_status_label.pixel_size = 0.002
	add_child(_status_label)

func interact(player: Player) -> void:
	var held := player.get_held_item()
	if not held or not held is Cup:
		if _status_label:
			_status_label.text = "Hold cup with shot!"
		return
	var cup := held as Cup
	if not cup.has_shot:
		if _status_label:
			_status_label.text = "Cup needs a shot first!"
		return
	if _pour_game.is_active():
		_pour_game.stop()
		return
	_player_ref = player
	_pour_game.start(player)

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
	if _status_label:
		_status_label.text = "[E] Add hot water\n(hold cup with shot)"
