extends StaticBody3D

enum State { IDLE, BOTTLE_PLACED, PREPPING, DONE }

@export var sauce_type: DrinkData.SauceType = DrinkData.SauceType.MOCHA

var state := State.IDLE
var _mini_game: SaucePrepMiniGame = null
var _placed_bottle: SauceBottle = null
var _bottle_slot: Marker3D = null
var _status_label: Label3D = null
var _activate_frame := -1

func _ready() -> void:
	add_to_group("station")
	add_to_group("sauce_prep")

	_bottle_slot = Marker3D.new()
	_bottle_slot.name = "BottleSlot"
	_bottle_slot.position = Vector3(0, 0.12, 0)
	add_child(_bottle_slot)

	_mini_game = SaucePrepMiniGame.new()
	_mini_game.name = "SaucePrepMiniGame"
	match sauce_type:
		DrinkData.SauceType.MOCHA, DrinkData.SauceType.WHITE_MOCHA:
			_mini_game.prep_mode = SaucePrepMiniGame.PrepMode.STIR_MIX
		DrinkData.SauceType.CARAMEL_SAUCE:
			_mini_game.prep_mode = SaucePrepMiniGame.PrepMode.SLEEVE_FILL
	var cam := Marker3D.new()
	cam.name = "CameraPoint"
	cam.position = Vector3(0, 0.35, 0.35)
	cam.rotation_degrees = Vector3(-30, 0, 0)
	_mini_game.add_child(cam)
	add_child(_mini_game)
	_mini_game._camera_point = cam
	_mini_game.mini_game_completed.connect(_on_prep_complete)
	_mini_game.set_sauce_color(DrinkData.get_sauce_color(sauce_type))

	_status_label = StationUtils.create_status_label(self)
	_update_label()

func interact(player: Player) -> void:
	if StationUtils.is_same_frame(_activate_frame):
		return
	match state:
		State.IDLE:
			pass
		State.BOTTLE_PLACED:
			if not player.has_held_item():
				if _placed_bottle.is_filled():
					if StationUtils.try_pickup_placed(player, _placed_bottle):
						_placed_bottle = null
						state = State.IDLE
						_update_label()
				else:
					_activate_frame = Engine.get_process_frames()
					state = State.PREPPING
					_mini_game.start(player)
					_update_label()
		State.PREPPING:
			_mini_game.stop()
			state = State.BOTTLE_PLACED
			_update_label()
		State.DONE:
			if not player.has_held_item():
				if StationUtils.try_pickup_placed(player, _placed_bottle):
					_placed_bottle = null
					state = State.IDLE
					_update_label()

func receive_item(item: Node3D) -> bool:
	if state != State.IDLE:
		return false
	if not item is SauceBottle:
		return false
	var bottle := item as SauceBottle
	if bottle.is_filled():
		return false
	_placed_bottle = bottle
	StationUtils.place_at_slot(item, _bottle_slot.global_position)
	state = State.BOTTLE_PLACED
	_update_label()
	return true

func _on_prep_complete(_quality: float) -> void:
	if _placed_bottle:
		_placed_bottle.fill_with(sauce_type)
	state = State.DONE
	_update_label()

func _process(_delta: float) -> void:
	if state == State.PREPPING and not _mini_game.is_active():
		state = State.BOTTLE_PLACED
		_update_label()
	if _placed_bottle and StationUtils.is_item_removed(_placed_bottle, _bottle_slot.global_position):
		_placed_bottle = null
		state = State.IDLE
		_update_label()

func _update_label() -> void:
	if not _status_label:
		return
	var sauce_name := DrinkData.get_sauce_name(sauce_type)
	var is_mix := sauce_type in [DrinkData.SauceType.MOCHA, DrinkData.SauceType.WHITE_MOCHA]
	match state:
		State.IDLE:
			_status_label.text = "%s Prep\nPlace empty bottle" % sauce_name
		State.BOTTLE_PLACED:
			if _placed_bottle and _placed_bottle.is_filled():
				_status_label.text = "Bottle filled!\n[E] Pick up"
			elif is_mix:
				_status_label.text = "[E] Mix powder + water"
			else:
				_status_label.text = "[E] Squeeze sleeve"
		State.PREPPING:
			_status_label.text = "Prepping %s..." % sauce_name
		State.DONE:
			_status_label.text = "%s bottle filled!\n[E] Pick up" % sauce_name
