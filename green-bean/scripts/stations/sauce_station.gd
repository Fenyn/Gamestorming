extends StaticBody3D

enum State { IDLE, BOTTLE_ONLY, CUP_ONLY, READY, DRIZZLING }

@export var sauce_type: DrinkData.SauceType = DrinkData.SauceType.MOCHA

var state := State.IDLE
var _mini_game: SauceMiniGame = null
var _placed_cup: Cup = null
var _placed_bottle: SauceBottle = null
var _cup_slot: Marker3D = null
var _bottle_slot: Marker3D = null
var _status_label: Label3D = null
var _activate_frame := -1

func _ready() -> void:
	add_to_group("station")

	_cup_slot = Marker3D.new()
	_cup_slot.name = "CupSlot"
	_cup_slot.position = Vector3(0, 0.05, 0.05)
	add_child(_cup_slot)

	_bottle_slot = Marker3D.new()
	_bottle_slot.name = "BottleSlot"
	_bottle_slot.position = Vector3(0.12, 0.1, 0)
	add_child(_bottle_slot)

	_mini_game = SauceMiniGame.new()
	_mini_game.name = "SauceMiniGame"
	var cam := Marker3D.new()
	cam.name = "CameraPoint"
	cam.position = Vector3(0, 0.45, 0.15)
	cam.rotation_degrees = Vector3(-70, 0, 0)
	_mini_game.add_child(cam)
	add_child(_mini_game)
	_mini_game._camera_point = cam
	_mini_game.mini_game_completed.connect(_on_drizzle_complete)
	_mini_game.set_sauce_color(DrinkData.get_sauce_color(sauce_type))

	_status_label = StationUtils.create_status_label(self)
	_update_label()

func interact(player: Player) -> void:
	if StationUtils.is_same_frame(_activate_frame):
		return
	match state:
		State.IDLE:
			pass
		State.BOTTLE_ONLY:
			if not player.has_held_item():
				if StationUtils.try_pickup_placed(player, _placed_bottle):
					_placed_bottle = null
					_recalc_state()
		State.CUP_ONLY:
			if not player.has_held_item():
				if StationUtils.try_pickup_placed(player, _placed_cup):
					_placed_cup = null
					_recalc_state()
		State.READY:
			if _mini_game.is_active():
				return
			if _placed_cup.has_sauce:
				if not player.has_held_item():
					if StationUtils.try_pickup_placed(player, _placed_cup):
						_placed_cup = null
						_recalc_state()
			else:
				_start_drizzle(player)
		State.DRIZZLING:
			_mini_game.stop()
			_recalc_state()

func _start_drizzle(player: Player) -> void:
	if player.has_held_item():
		return
	if not _placed_bottle or _placed_bottle.is_empty():
		if _status_label:
			_status_label.text = "Bottle empty!\nRefill at prep station"
		return
	_mini_game.start(player)
	if _mini_game.is_active():
		_activate_frame = Engine.get_process_frames()
		state = State.DRIZZLING
		_update_label()

func receive_item(item: Node3D) -> bool:
	if item is Cup:
		if _placed_cup:
			return false
		var cup := item as Cup
		if cup.has_sauce:
			return false
		_placed_cup = cup
		StationUtils.place_at_slot(item, _cup_slot.global_position)
		_recalc_state()
		return true
	if item is SauceBottle:
		if _placed_bottle:
			return false
		var bottle := item as SauceBottle
		if bottle.is_empty():
			return false
		if bottle.sauce_type != sauce_type:
			return false
		_placed_bottle = bottle
		StationUtils.place_at_slot(item, _bottle_slot.global_position)
		_recalc_state()
		return true
	return false

func _on_drizzle_complete(quality: float) -> void:
	if not _placed_cup or not _placed_bottle:
		return
	_placed_bottle.use_drizzle()
	_placed_cup.has_sauce = true
	_placed_cup.sauce_type = sauce_type
	if _placed_cup.order:
		_placed_cup.order.sauce_quality = quality
	_recalc_state()

func _recalc_state() -> void:
	if _placed_cup and _placed_bottle and _placed_bottle.is_filled():
		state = State.READY
	elif _placed_cup and not _placed_bottle:
		state = State.CUP_ONLY
	elif _placed_bottle and not _placed_cup:
		state = State.BOTTLE_ONLY
	else:
		state = State.IDLE
	_update_label()

func _update_label() -> void:
	if not _status_label:
		return
	var sauce_name := DrinkData.get_sauce_name(sauce_type)
	match state:
		State.IDLE:
			_status_label.text = "%s Station\nPlace bottle + cup" % sauce_name
		State.BOTTLE_ONLY:
			var pct := "%.0f%%" % (_placed_bottle.fill_level * 100) if _placed_bottle else ""
			_status_label.text = "%s bottle (%s)\nPlace cup to drizzle" % [sauce_name, pct]
		State.CUP_ONLY:
			_status_label.text = "Cup placed\nNeeds %s bottle" % sauce_name
		State.READY:
			if _placed_cup and _placed_cup.has_sauce:
				_status_label.text = "%s added!\n[E] pick up cup" % sauce_name
			elif _placed_bottle and _placed_bottle.is_empty():
				_status_label.text = "Bottle empty!\n[E] pick up, refill"
			else:
				_status_label.text = "[E] Drizzle %s" % sauce_name
		State.DRIZZLING:
			_status_label.text = "Drizzling %s...\n[E] done" % sauce_name

func _process(_delta: float) -> void:
	if state == State.DRIZZLING and not _mini_game.is_active():
		_recalc_state()
	if _placed_cup and StationUtils.is_item_removed(_placed_cup, _cup_slot.global_position):
		_placed_cup = null
		_recalc_state()
	if _placed_bottle and StationUtils.is_item_removed(_placed_bottle, _bottle_slot.global_position):
		_placed_bottle = null
		_recalc_state()
