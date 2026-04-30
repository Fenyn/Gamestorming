extends StaticBody3D

# Player flow:
# 1. Pick up pitcher from shelf (or bring one with milk)
# 2. Carry pitcher to fridge, get milk
# 3. Carry pitcher back, place on steam station
# 4. [E] Steam milk mini-game (careful — scalds if left too long!)
# 5. Pick up pitcher (has steamed milk)
# 6. Carry to cup, pour milk in (interact with cup or station holding cup)

enum State { IDLE, PITCHER_PLACED, STEAMING, MILK_READY, SCALDED }

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
	_steam_game.mini_game_completed.connect(_on_steam_complete)

	_spawn_shelf_pitcher()

	_status_label = Label3D.new()
	_status_label.text = ""
	_status_label.font_size = 12
	_status_label.position = Vector3(0, 0.3, 0.15)
	_status_label.pixel_size = 0.002
	_status_label.add_to_group("world_label")
	add_child(_status_label)
	_update_label()

func _spawn_shelf_pitcher() -> void:
	_shelf_pitcher = Pitcher.new()
	_shelf_pitcher.name = "PitcherShelf"
	add_child(_shelf_pitcher)
	_shelf_pitcher.position = Vector3(0.15, 0.12, 0)

func interact(player: Player) -> void:
	match state:
		State.IDLE:
			_try_pickup_shelf_pitcher(player)
		State.PITCHER_PLACED:
			if _placed_pitcher and _placed_pitcher.has_milk:
				state = State.STEAMING
				_steam_game.start(player)
			else:
				if _status_label:
					_status_label.text = "Pitcher needs milk!\nTake to fridge first"
		State.STEAMING:
			if _steam_game.is_active():
				_steam_game.stop()
			else:
				_steam_game.start(player)
		State.MILK_READY:
			if _status_label:
				_status_label.text = "Pick up pitcher!"
		State.SCALDED:
			_reset()

func _try_pickup_shelf_pitcher(player: Player) -> void:
	if not player.has_held_item() and _shelf_pitcher and is_instance_valid(_shelf_pitcher):
		player.pickup_item(_shelf_pitcher)
		_shelf_pitcher = null
		_update_label()

func receive_item(item: Node3D) -> bool:
	if not item is Pitcher:
		return false
	if _placed_pitcher:
		return false
	_placed_pitcher = item as Pitcher
	item.global_position = _pitcher_slot.global_position
	item.global_rotation = Vector3.ZERO
	if item is RigidBody3D:
		(item as RigidBody3D).freeze = true
	for child in item.get_children():
		if child is CollisionShape3D:
			child.disabled = true
	state = State.PITCHER_PLACED
	_update_label()
	return true

func _on_steam_complete(quality: float) -> void:
	if quality > 0 and _placed_pitcher:
		_placed_pitcher.set_steamed(quality)
		state = State.MILK_READY
	else:
		state = State.SCALDED
	_update_label()

func _process(_delta: float) -> void:
	if state == State.STEAMING and not _steam_game.is_active():
		if _steam_game.is_scalded():
			state = State.SCALDED
			_update_label()
		elif _steam_game.is_heating():
			if _status_label:
				_status_label.text = "STEAMING... %.0f C\n[E] Check milk" % _steam_game.get_temperature()

	_check_removed_items()

func _check_removed_items() -> void:
	if _placed_pitcher:
		if not is_instance_valid(_placed_pitcher):
			_placed_pitcher = null
			if state != State.IDLE:
				_reset()
		elif _placed_pitcher.global_position.distance_to(_pitcher_slot.global_position) > 0.5:
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
				_status_label.text = "[E] Pick up pitcher\n(take to fridge for milk)"
			else:
				_status_label.text = "Bring pitcher with milk\n[Click] to place"
		State.PITCHER_PLACED:
			if _placed_pitcher and _placed_pitcher.has_milk:
				_status_label.text = "[E] Start steaming"
			else:
				_status_label.text = "Needs milk!\nTake pitcher to fridge"
		State.STEAMING:
			_status_label.text = "[E] Steaming..."
		State.MILK_READY:
			_status_label.text = "Milk ready!\n[Click] Pick up pitcher"
		State.SCALDED:
			_status_label.text = "SCALDED!\n[E] Reset & dump"
