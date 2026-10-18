extends StaticBody3D

# Player flow:
# 1. Place cup on station
# 2. Pick up dripper from shelf, carry to grinder, grind, carry back
# 3. Place dripper on the stand's ring, over the cup
# 4. Hold kettle with hot water, [E] → bloom pour (brief active)
# 5. Bloom wait (passive ~20s — walk away!)
# 6. Come back, [E] → main pour (active, saturation)
# 7. Draw-down (passive ~15s — walk away again!)
# 8. Coffee ready in cup, pick up

enum State { IDLE, CUP_ONLY, READY_TO_POUR, BLOOMING, BLOOM_WAIT, MAIN_POUR, DRAINING, READY, STALE }

var state := State.IDLE
var _placed_cup: Cup = null
var _placed_dripper: Dripper = null
var _shelf_dripper: Dripper = null

var _pour_game: PourMiniGame = null
var _correct_grind := true
var _grind_quality := 1.0
var _pour_quality := 0.0
var _pouring_player: Player = null
var _pour_kettle: Kettle = null

var _cup_slot: Marker3D = null
var _dripper_slot: Marker3D = null
var _cam_xform := Transform3D.IDENTITY
var _cup_spot := Vector3.ZERO
var _ring_seat := Vector3.ZERO
var _dripper_rest := Vector3.ZERO
## Fallbacks for a dripper's shape, used before one exists.
const DRIPPER_BASE_Y := -0.05
const DRIPPER_GROUNDS_TOP := 0.008
var _status_label: Label3D = null
var _pour_tween: Tween = null
var _drips: GPUParticles3D = null
## Brew scale on the stand: time since the bloom pour began and grams of water.
var _scale_readout: Label3D = null
var _brew_time := 0.0
var _timing := false
## Water for a small cup at full saturation; larger cups scale with the pour game.
const BREW_WATER_G := 250.0
## How far from the bed's centre the stream can land.
const AIM_RADIUS := 0.024

func _ready() -> void:
	add_to_group("station")

	_cup_spot = StationUtils.model_marker(self, "CupSpot", Vector3(-0.03, 0.032, 0))
	_ring_seat = StationUtils.model_marker(self, "RingSeat", Vector3(-0.03, 0.235, 0))
	_dripper_rest = StationUtils.model_marker(self, "DripperRest", Vector3(0.092, 0.008, 0.035))

	_cup_slot = Marker3D.new()
	_cup_slot.name = "CupSlot"
	_cup_slot.position = _cup_spot + Vector3(0, 0.06, 0)
	add_child(_cup_slot)

	_dripper_slot = Marker3D.new()
	_dripper_slot.name = "DripperSlot"
	_dripper_slot.position = _ring_seat - Vector3(0, DRIPPER_BASE_Y, 0)
	add_child(_dripper_slot)

	var cam_xform := Transform3D(Basis.from_euler(Vector3(deg_to_rad(-70), 0, 0)), Vector3(0, 0.5, 0.1))
	var view := get_node_or_null("Model/CameraView") as Node3D
	if view:
		cam_xform = global_transform.affine_inverse() * view.global_transform

	_pour_game = PourMiniGame.new()
	_pour_game.name = "PourMiniGame"
	_pour_game.pour_mode = PourMiniGame.PourMode.SATURATION
	var cam := Marker3D.new()
	cam.name = "CameraPoint"
	_pour_game.add_child(cam)
	add_child(_pour_game)
	_pour_game._camera_point = cam
	_cam_xform = cam_xform
	_pour_game.mini_game_completed.connect(_on_pour_complete)
	_pour_game.camera_fov = 42.0

	_set_camera(cam_xform)
	_spawn_shelf_dripper()
	_scale_readout = get_node_or_null("Model/BrewScale/Readout") as Label3D

	_status_label = StationUtils.create_status_label(self, _ring_seat + Vector3(0.08, 0.12, 0.04))
	_update_label()

	# Coffee dripping from the dripper into the cup during draw-down.
	_drips = Fx.make_specks(Color(0.22, 0.12, 0.05), 0.007, -4.0, 0.2, 5)
	_drips.position = (_dripper_slot.position + _cup_slot.position) * 0.5 + Vector3(0, 0.02, 0)
	add_child(_drips)

func _spawn_shelf_dripper() -> void:
	_shelf_dripper = Dripper.new()
	_shelf_dripper.name = "DripperShelf"
	add_child(_shelf_dripper)
	_shelf_dripper.position = _rest_position(_shelf_dripper)

func _base_y(dripper: Node3D) -> float:
	return (dripper as Dripper).base_y if dripper is Dripper else DRIPPER_BASE_Y

func _rest_position(dripper: Node3D) -> Vector3:
	return _dripper_rest - Vector3(0, _base_y(dripper), 0)

func _ring_position(dripper: Node3D) -> Vector3:
	return _ring_seat - Vector3(0, _base_y(dripper), 0)

func _set_camera(xform: Transform3D) -> void:
	_pour_game._camera_point.transform = xform

## World offset of the stream's landing point from the bed centre, from the aim.
func _aim_offset() -> Vector3:
	var p := _pour_game.get_pour_position() * AIM_RADIUS
	return global_basis * Vector3(p.x, 0, p.y)

func _saucer_free() -> bool:
	return _shelf_dripper == null or not is_instance_valid(_shelf_dripper)

func _return_to_saucer(dripper: Dripper) -> void:
	dripper.reset_device()
	StationUtils.cancel_settle(dripper)
	dripper.global_position = to_global(_rest_position(dripper))
	dripper.global_basis = global_basis
	StationUtils.set_item_collision(dripper, true)
	_shelf_dripper = dripper

func interact(player: Player) -> void:
	if _pour_game.is_active():
		return
	match state:
		State.IDLE:
			_try_pickup_shelf_dripper(player)
		State.CUP_ONLY:
			if _placed_dripper and not _placed_dripper.has_grounds():
				_try_pickup_placed_dripper(player)
			elif _shelf_dripper:
				_try_pickup_shelf_dripper(player)
			elif not player.has_held_item() and _placed_cup:
				if StationUtils.try_pickup_placed(player, _placed_cup):
					_placed_cup = null
					_recalculate_state()
		State.READY_TO_POUR:
			_try_start_bloom(player)
		State.BLOOMING:
			pass
		State.BLOOM_WAIT:
			pass
		State.MAIN_POUR:
			_try_start_main_pour(player)
		State.DRAINING:
			pass
		State.READY, State.STALE:
			if not player.has_held_item() and _placed_cup:
				if StationUtils.try_pickup_placed(player, _placed_cup):
					_placed_cup = null
					_recalculate_state()

func _try_start_bloom(player: Player) -> void:
	var held := player.get_held_item()
	if held is Kettle and (held as Kettle).has_water:
		_pouring_player = player
		_pour_kettle = held as Kettle
		state = State.BLOOMING
		_update_label()
		_pour_game.start(player)
		_start_pour_animation()
		_brew_time = 0.0
		_timing = true
	elif _status_label:
		_status_label.text = "Hold a filled kettle\n[E] Bloom pour"

func _try_start_main_pour(player: Player) -> void:
	var held := player.get_held_item()
	if held is Kettle and (held as Kettle).has_water:
		_pouring_player = player
		_pour_kettle = held as Kettle
		state = State.MAIN_POUR
		_update_label()
		_pour_game.start(player)
		_start_pour_animation()
	elif _status_label:
		_status_label.text = "Hold a filled kettle\n[E] Main pour"

func _start_pour_animation() -> void:
	if not _pour_kettle or not _pouring_player:
		return
	if _pour_tween and _pour_tween.is_valid():
		_pour_tween.kill()
	var bed := _dripper_slot.global_position
	if _placed_dripper:
		bed = _placed_dripper.to_global(Vector3(0, _placed_dripper.grounds_top_y, 0))
	_pour_tween = StationUtils.start_kettle_pour(_pouring_player, _pour_kettle, bed, Vector3(0, 0.1, 0), _pour_game.is_pouring, Vector3.LEFT, _aim_offset)

func _stop_pour_animation() -> void:
	StationUtils.stop_kettle_pour(_pour_tween, _pour_kettle, _pouring_player)
	_pour_tween = null

func _try_pickup_shelf_dripper(player: Player) -> void:
	if StationUtils.try_pickup_shelf(player, _shelf_dripper):
		_shelf_dripper = null
		_update_label()

func _try_pickup_placed_dripper(player: Player) -> void:
	if StationUtils.try_pickup_placed(player, _placed_dripper):
		_placed_dripper = null
		_recalculate_state()

func receive_item(item: Node3D) -> bool:
	if _pour_game.is_active():
		return false
	if item is Cup:
		if _placed_cup:
			return false
		var cup := item as Cup
		if cup.has_pour_over_coffee:
			return false
		_placed_cup = cup
		_cup_slot.position = _cup_spot + Vector3(0, StationUtils.item_half_height(cup, 0.06), 0)
		_place_at_slot(item, _cup_slot)
		item.global_basis = global_basis
		_recalculate_state()
		return true
	if item is Dripper:
		if _placed_dripper:
			# Ring taken: set it on the saucer if that is free.
			if not _saucer_free():
				return false
			StationUtils.place_at_slot(item, to_global(_rest_position(item)))
			item.global_basis = global_basis
			StationUtils.set_item_collision(item, true)
			_shelf_dripper = item as Dripper
			_update_label()
			return true
		_placed_dripper = item as Dripper
		_dripper_slot.position = _ring_position(item)
		_place_at_slot(item, _dripper_slot)
		item.global_basis = global_basis
		if _placed_dripper.has_grounds():
			_correct_grind = (_placed_dripper.grounds.grind_level == DrinkData.GrindLevel.COARSE)
			_grind_quality = _placed_dripper.grounds.grind_quality
		_recalculate_state()
		return true
	return false

func _place_at_slot(item: Node3D, slot: Marker3D) -> void:
	StationUtils.place_at_slot(item, slot.global_position)

func _recalculate_state() -> void:
	if _placed_cup and _placed_dripper:
		if not _placed_dripper.has_grounds():
			state = State.CUP_ONLY
			if _status_label:
				_status_label.text = "Dripper needs grounds!\n[E] Pick up dripper"
			return
		else:
			state = State.READY_TO_POUR
	elif _placed_cup and not _placed_dripper:
		state = State.CUP_ONLY
	else:
		state = State.IDLE
	_update_label()

func _on_pour_complete(quality: float) -> void:
	_pour_quality = quality
	if _pour_kettle and is_instance_valid(_pour_kettle):
		_pour_kettle.use_water(Kettle.POUR_OVER_COST)
	_stop_pour_animation()
	_pour_kettle = null
	_pouring_player = null
	state = State.DRAINING
	_update_label()

## Bloom froth: builds with the bloom pour, peaks as the wait starts, settles.
func _bloom_amount() -> float:
	match state:
		State.BLOOMING:
			return clampf(_pour_game._get_avg_saturation() / PourMiniGame.BLOOM_TARGET, 0.0, 1.0)
		State.BLOOM_WAIT:
			return clampf(_pour_game.get_bloom_timer() / PourMiniGame.BLOOM_WAIT_TIME, 0.0, 1.0) * 0.8 + 0.2
	return 0.0

## Brew time and water poured, like a real brew scale.
func _update_scale() -> void:
	if not _scale_readout:
		return
	var grams := 0.0
	if state in [State.BLOOMING, State.BLOOM_WAIT, State.MAIN_POUR, State.DRAINING, State.READY, State.STALE]:
		var mult := DrinkData.get_size_multiplier(_placed_cup.cup_size) if _placed_cup else 1.0
		grams = minf(_pour_game._get_avg_saturation() / PourMiniGame.MAIN_TARGET, 1.0) * BREW_WATER_G * mult
	var t := int(_brew_time)
	_scale_readout.text = "%d:%02d  %dg" % [t / 60, t % 60, roundi(grams)]

func _process(_delta: float) -> void:
	# Track bloom → bloom_wait transition
	if state == State.BLOOMING and not _pour_game.is_active():
		if _pour_game.is_bloom_waiting():
			state = State.BLOOM_WAIT
			if _pour_kettle and is_instance_valid(_pour_kettle):
				_pour_kettle.use_water(Kettle.BLOOM_COST)
			_stop_pour_animation()
			_pour_kettle = null
			_pouring_player = null
			_update_label()

	if state == State.BLOOM_WAIT and _pour_game.is_ready_for_main_pour():
		state = State.MAIN_POUR
		_update_label()

	if _drips:
		_drips.emitting = state == State.DRAINING
		if state == State.DRAINING:
			_drips.position = _dripper_slot.position + Vector3(0, -0.045, 0)
	if (state == State.READY or state == State.STALE) and _placed_cup:
		_placed_cup.heat = _pour_game.get_coffee_freshness()

	if state == State.DRAINING and _pour_game.is_coffee_ready():
		_finish_drip()

	if state == State.READY:
		if _pour_game.get_coffee_freshness() < 0.3:
			state = State.STALE
			_update_label()

	if _placed_dripper and state in [State.BLOOMING, State.BLOOM_WAIT, State.MAIN_POUR, State.DRAINING]:
		_placed_dripper.set_saturation(_pour_game._get_avg_saturation())
		_placed_dripper.set_saturation_map(_pour_game.get_saturation_image())
		_placed_dripper.set_bloom(_bloom_amount())
	_update_water_level()
	if _timing:
		_brew_time += _delta
	_update_scale()

	_check_removed_items()

func _update_water_level() -> void:
	if not _placed_dripper:
		return
	var level := 0.0
	match state:
		State.BLOOMING:
			level = 0.15 * clampf(_pour_game._get_avg_saturation() / PourMiniGame.BLOOM_TARGET, 0.0, 1.0)
		State.BLOOM_WAIT:
			level = 0.15 * clampf(_pour_game.get_bloom_timer() / PourMiniGame.BLOOM_WAIT_TIME, 0.0, 1.0)
		State.MAIN_POUR:
			if _pour_game.is_active():
				level = clampf(_pour_game._get_avg_saturation(), 0.0, 1.0) * 0.6
		State.DRAINING:
			level = 0.6 * clampf(_pour_game.phase_timer / PourMiniGame.DRAW_DOWN_TIME, 0.0, 1.0)
	_placed_dripper.set_water_level(level)

func _finish_drip() -> void:
	SoundManager.stop_loop("drip_loop")
	SoundManager.play("drip_done")
	_timing = false
	if _placed_cup:
		var freshness := _pour_game.get_coffee_freshness()
		_placed_cup.has_pour_over_coffee = true
		if _placed_cup.order:
			_placed_cup.order.pour_quality = _pour_quality * freshness
			_placed_cup.order.correct_grind_level = _correct_grind
			_placed_cup.order.grind_quality = _grind_quality * (1.0 if _correct_grind else 0.5)
		_placed_cup.set_fill(0.85, Color(0.35, 0.22, 0.1))
		StationUtils.set_item_collision(_placed_cup, true)

	if _placed_dripper:
		var used := _placed_dripper
		_placed_dripper = null
		if _saucer_free():
			_return_to_saucer(used)
		else:
			used.reset_device()

	state = State.READY
	_update_label()

func _check_removed_items() -> void:
	# is_item_removed() is true for null, so only check items that are here.
	if _placed_cup and StationUtils.is_item_removed(_placed_cup, _cup_slot.global_position):
		_placed_cup = null
		_recalculate_state()
	if _placed_dripper and StationUtils.is_item_removed(_placed_dripper, _dripper_slot.global_position):
		_placed_dripper = null
		_recalculate_state()
	if _shelf_dripper and StationUtils.is_item_removed(_shelf_dripper, to_global(_rest_position(_shelf_dripper)), 0.15):
		_shelf_dripper = null
		_update_label()

func _update_label() -> void:
	if not _status_label:
		return
	match state:
		State.IDLE:
			var has_shelf := _shelf_dripper != null and is_instance_valid(_shelf_dripper)
			_status_label.text = "[E] Pick up dripper" if has_shelf else "[Click] Place cup"
		State.CUP_ONLY:
			var has_shelf := _shelf_dripper != null and is_instance_valid(_shelf_dripper)
			_status_label.text = "[E] Pick up dripper" if has_shelf else "Bring dripper w/ grounds"
		State.READY_TO_POUR:
			_status_label.text = "[E] Bloom pour\nHold a filled kettle"
		State.BLOOMING:
			_status_label.text = ""
		State.BLOOM_WAIT:
			_status_label.text = "Blooming"
		State.MAIN_POUR:
			_status_label.text = "[E] Main pour\nHold a filled kettle"
		State.DRAINING:
			_status_label.text = "Draining"
		State.READY:
			_status_label.text = "[E] Pick up cup"
		State.STALE:
			_status_label.text = "Going cold\n[E] Pick up cup"
