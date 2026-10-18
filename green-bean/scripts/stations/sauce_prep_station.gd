extends StaticBody3D

enum State { IDLE, BOTTLE_PLACED, PREPPING, DONE }

@export var sauce_type: DrinkData.SauceType = DrinkData.SauceType.MOCHA

var state := State.IDLE
var _mini_game: SaucePrepMiniGame = null
var _placed_bottle: SauceBottle = null
var _bottle_slot: Marker3D = null
var _status_label: Label3D = null
var _activate_frame := -1
var _pouch: Node3D = null
var _pouch_rest := Transform3D()
var _pouch_pour := Transform3D()
var _pouch_tween: Tween = null
var _stream: PourStream = null
## Pouch spout tip in the pouch's space, from the model.
const POUCH_SPOUT := Vector3(0.035, 0.124, 0)
func _ready() -> void:
	add_to_group("station")
	add_to_group("sauce_prep")

	_bottle_slot = Marker3D.new()
	_bottle_slot.name = "BottleSlot"
	_bottle_slot.position = StationUtils.model_marker(self, "BottleSpot", Vector3(0.065, 0.015, 0.01))
	add_child(_bottle_slot)
	_pouch = get_node_or_null("Model/Pouch") as Node3D
	var pour := get_node_or_null("Model/PouchPour") as Node3D
	if _pouch and pour:
		_pouch_rest = _pouch.transform
		_pouch_pour = pour.transform
		var label := _pouch.get_node_or_null("PouchLabel") as Label3D
		if label:
			label.text = DrinkData.get_sauce_name(sauce_type)

	_mini_game = SaucePrepMiniGame.new()
	_mini_game.name = "SaucePrepMiniGame"
	match sauce_type:
		DrinkData.SauceType.MOCHA, DrinkData.SauceType.WHITE_MOCHA:
			_mini_game.prep_mode = SaucePrepMiniGame.PrepMode.STIR_MIX
		DrinkData.SauceType.CARAMEL_SAUCE:
			_mini_game.prep_mode = SaucePrepMiniGame.PrepMode.SLEEVE_FILL
	var cam := Marker3D.new()
	cam.name = "CameraPoint"
	var view := get_node_or_null("Model/CameraView") as Node3D
	if view:
		cam.transform = view.transform
	else:
		cam.position = Vector3(0, 0.45, 0.38)
		cam.rotation_degrees = Vector3(-30, 0, 0)
	_mini_game.add_child(cam)
	add_child(_mini_game)
	_mini_game._camera_point = cam
	_mini_game.mini_game_completed.connect(_on_prep_complete)
	_mini_game.camera_fov = 55.0
	if _pouch:
		_stream = PourStream.new(DrinkData.get_sauce_color(sauce_type), 0.0035)
		_stream.source = _pouch
		_stream.source_offset = POUCH_SPOUT
		_stream.flow_check = _sauce_flowing
		add_child(_stream)

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
					_tip_pouch(true)
					_update_label()
		State.PREPPING:
			_mini_game.stop()
			_end_prep_visuals()
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
	StationUtils.place_at_slot(item, _bottle_position(item))
	state = State.BOTTLE_PLACED
	_update_label()
	return true

func _bottle_position(item: Node3D) -> Vector3:
	return _bottle_slot.global_position + Vector3(0, StationUtils.item_half_height(item, 0.1), 0)

## Pouch over the bottle while prepping, back on the board otherwise.
func _tip_pouch(over_bottle: bool) -> void:
	if _pouch == null:
		return
	if _pouch_tween and _pouch_tween.is_valid():
		_pouch_tween.kill()
	_pouch_tween = create_tween()
	_pouch_tween.tween_property(_pouch, "transform", _pouch_pour if over_bottle else _pouch_rest, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _sauce_flowing() -> bool:
	if not _mini_game.is_squeezing() or not _placed_bottle:
		return false
	_stream.target_point = _placed_bottle.to_global(Vector3(0, 0.06, 0))
	return true

func _end_prep_visuals() -> void:
	_tip_pouch(false)
	if _pouch:
		_pouch.scale = Vector3.ONE
	if _placed_bottle and is_instance_valid(_placed_bottle):
		_placed_bottle._update_fill_visual()

func _on_prep_complete(_quality: float) -> void:
	_tip_pouch(false)
	if _pouch:
		_pouch.scale = Vector3.ONE
	if _placed_bottle:
		_placed_bottle.fill_with(sauce_type)
	state = State.DONE
	_update_label()

func _process(_delta: float) -> void:
	if state == State.PREPPING:
		if not _mini_game.is_active():
			_end_prep_visuals()
			state = State.BOTTLE_PLACED
			_update_label()
		elif _placed_bottle:
			_placed_bottle.preview_level(sauce_type, _mini_game.progress())
			# The pouch flattens as it empties.
			if _pouch and _mini_game.prep_mode == SaucePrepMiniGame.PrepMode.SLEEVE_FILL:
				_pouch.scale = Vector3(1.0, 1.0, lerpf(1.0, 0.45, _mini_game.progress()))
	if _placed_bottle and StationUtils.is_item_removed(_placed_bottle, _bottle_position(_placed_bottle)):
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
			_status_label.text = "[Click] Set down an empty bottle"
		State.BOTTLE_PLACED:
			if _placed_bottle and _placed_bottle.is_filled():
				_status_label.text = "[E] Pick up bottle"
			elif is_mix:
				_status_label.text = "[E] Mix %s" % sauce_name.to_lower()
			else:
				_status_label.text = "[E] Fill from the pouch"
		State.PREPPING:
			_status_label.text = ""
		State.DONE:
			_status_label.text = "[E] Pick up bottle"
