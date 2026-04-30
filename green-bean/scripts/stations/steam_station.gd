extends StaticBody3D

enum State { IDLE, PITCHER_PLACED, STRETCHING, TEXTURING, READY, MILK_DONE, SCALDED }

var state := State.IDLE
var _steam_game: SteamMiniGame = null
var _placed_pitcher: Pitcher = null
var _shelf_pitcher: Pitcher = null

var _pitcher_slot: Marker3D = null
var _status_label: Label3D = null

func _ready() -> void:
	add_to_group("station")

	_pitcher_slot = Marker3D.new()
	_pitcher_slot.name = "PitcherSlot"
	_pitcher_slot.position = Vector3(0, 0.15, 0)
	add_child(_pitcher_slot)

	_steam_game = SteamMiniGame.new()
	_steam_game.name = "SteamMiniGame"
	var cam := Marker3D.new()
	cam.name = "CameraPoint"
	cam.position = Vector3(0, 0.4, 0.4)
	cam.rotation_degrees = Vector3(-25, 0, 0)
	_steam_game.add_child(cam)
	add_child(_steam_game)
	_steam_game._camera_point = cam
	_steam_game.mini_game_completed.connect(_on_steam_complete)

	_spawn_shelf_pitcher()

	_status_label = StationUtils.create_status_label(self)
	_update_label()

func _spawn_shelf_pitcher() -> void:
	_shelf_pitcher = Pitcher.new()
	_shelf_pitcher.name = "PitcherShelf"
	add_child(_shelf_pitcher)
	_shelf_pitcher.position = Vector3(0.15, 0.12, 0)

func interact(player: Player) -> void:
	if _steam_game.is_active():
		return
	match state:
		State.IDLE:
			_try_pickup_shelf_pitcher(player)
		State.PITCHER_PLACED:
			if _placed_pitcher and _placed_pitcher.has_milk:
				state = State.STRETCHING
				_update_label()
				_steam_game.start(player)
			else:
				_try_pickup_placed_pitcher(player)
		State.STRETCHING:
			pass
		State.TEXTURING:
			# Re-enter to check on milk
			_steam_game.start(player)
		State.READY:
			# Re-enter to finish
			_steam_game.start(player)
		State.MILK_DONE:
			_try_pickup_placed_pitcher(player)
		State.SCALDED:
			_reset()

func _try_pickup_shelf_pitcher(player: Player) -> void:
	if StationUtils.try_pickup_shelf(player, _shelf_pitcher):
		_shelf_pitcher = null
		_update_label()

func _try_pickup_placed_pitcher(player: Player) -> void:
	if StationUtils.try_pickup_placed(player, _placed_pitcher):
		_placed_pitcher = null
		state = State.IDLE
		_steam_game.reset_steam()
		_update_label()

func receive_item(item: Node3D) -> bool:
	if _steam_game.is_active():
		return false
	if not item is Pitcher:
		return false
	if _placed_pitcher:
		return false
	_placed_pitcher = item as Pitcher
	StationUtils.place_at_slot(item, _pitcher_slot.global_position)
	state = State.PITCHER_PLACED
	_update_label()
	return true

func _on_steam_complete(quality: float) -> void:
	if quality > 0 and _placed_pitcher:
		_placed_pitcher.set_steamed(quality)
		state = State.MILK_DONE
	elif quality <= 0:
		state = State.SCALDED
	_update_label()

func _process(_delta: float) -> void:
	# Track phase transitions from the mini-game
	if state == State.STRETCHING and not _steam_game.is_active():
		if _steam_game.steam_phase == SteamMiniGame.SteamPhase.TEXTURING:
			state = State.TEXTURING
			_update_label()
		elif _steam_game.is_scalded():
			state = State.SCALDED
			_update_label()

	if state == State.TEXTURING:
		if _steam_game.is_scalded():
			state = State.SCALDED
			_update_label()
		elif _steam_game.is_ready():
			state = State.READY
			_update_label()
		elif not _steam_game.is_active() and _status_label:
			var temp := _steam_game.get_temperature()
			_status_label.text = "Texturing... %.0f C\n[E] Check milk" % temp

	if state == State.READY and not _steam_game.is_active():
		if _status_label:
			_status_label.text = "%.0f C - READY!\n[E] Finish steaming" % _steam_game.get_temperature()
		if _steam_game.is_scalded():
			state = State.SCALDED
			_update_label()

	_check_removed_items()

func _check_removed_items() -> void:
	if _placed_pitcher and StationUtils.is_item_removed(_placed_pitcher, _pitcher_slot.global_position):
		_placed_pitcher = null
		if state != State.IDLE:
			_reset()

func _reset() -> void:
	state = State.IDLE
	_steam_game.reset_steam()
	if _placed_pitcher:
		_placed_pitcher.reset_pitcher()
		_placed_pitcher.global_position = Vector3(global_position.x + 0.15, global_position.y + 0.12, global_position.z)
		_shelf_pitcher = _placed_pitcher
		_placed_pitcher = null
	_update_label()

func _update_label() -> void:
	if not _status_label:
		return
	match state:
		State.IDLE:
			var has_shelf := _shelf_pitcher != null and is_instance_valid(_shelf_pitcher)
			if has_shelf:
				_status_label.text = "[E] Pick up pitcher"
			else:
				_status_label.text = "Bring pitcher with milk"
		State.PITCHER_PLACED:
			if _placed_pitcher and _placed_pitcher.has_milk:
				_status_label.text = "[E] Start steaming"
			else:
				_status_label.text = "Needs milk!\n[E] Pick up pitcher"
		State.STRETCHING:
			_status_label.text = "Stretching..."
		State.TEXTURING:
			_status_label.text = "Texturing..."
		State.READY:
			_status_label.text = "READY! [E] Finish"
		State.MILK_DONE:
			_status_label.text = "Milk done!\n[E] Pick up pitcher"
		State.SCALDED:
			_status_label.text = "SCALDED!\n[E] Reset & dump"
