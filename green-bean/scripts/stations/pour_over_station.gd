extends StaticBody3D

# Player flow:
# 1. Place cup on station
# 2. Pick up dripper from shelf, carry to grinder, grind, carry back
# 3. Place dripper on station (on top of cup)
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
var _cup_spot := Vector3.ZERO
var _ring_seat := Vector3.ZERO
var _dripper_rest := Vector3.ZERO
## Top of the grounds bed in a hanging dripper, relative to the dripper's centre.
const GROUNDS_TOP := 0.004
var _status_label: Label3D = null
var _pour_tween: Tween = null
var _drips: GPUParticles3D = null

func _ready() -> void:
	add_to_group("station")

	# Positions come from the model scene (scenes/props/pour_over_stand.tscn).
	# The cup stands on the scale at CupSpot, the dripper hangs in the ring at
	# RingSeat, and the spare dripper waits on the saucer at DripperRest.
	_cup_spot = StationUtils.model_marker(self, "CupSpot", Vector3(-0.03, 0.032, 0))
	_ring_seat = StationUtils.model_marker(self, "RingSeat", Vector3(-0.03, 0.235, 0))
	_dripper_rest = StationUtils.model_marker(self, "DripperRest", Vector3(0.092, 0.008, 0.035))

	_cup_slot = Marker3D.new()
	_cup_slot.name = "CupSlot"
	_cup_slot.position = _cup_spot + Vector3(0, 0.06, 0)
	add_child(_cup_slot)

	_dripper_slot = Marker3D.new()
	_dripper_slot.name = "DripperSlot"
	# A dripper hangs with the outside of its cone in the ring.
	_dripper_slot.position = _ring_seat + Vector3(0, 0.016, 0)
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
	# The saturation grid is drawn 0.24 above the mini-game's origin. Move the
	# mini-game so the grid lies on the grounds in the hanging dripper, and keep
	# the camera where the model's CameraView puts it.
	var grid_offset := _dripper_slot.position + Vector3(0, GROUNDS_TOP + 0.001 - 0.24, 0)
	_pour_game.position = grid_offset
	cam.transform = Transform3D(cam_xform.basis, cam_xform.origin - grid_offset)
	_pour_game.mini_game_completed.connect(_on_pour_complete)

	_spawn_shelf_dripper()

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

## Where a dripper stands on the saucer (station-local), by its own height.
func _rest_position(dripper: Node3D) -> Vector3:
	return _dripper_rest + Vector3(0, StationUtils.item_half_height(dripper, 0.04), 0)

func _ring_position(dripper: Node3D) -> Vector3:
	var contact := (dripper as Dripper).ring_contact_y if dripper is Dripper else -0.016
	return _ring_seat - Vector3(0, contact, 0)

func _saucer_free() -> bool:
	return _shelf_dripper == null or not is_instance_valid(_shelf_dripper)

## Sends the dripper back to the saucer, emptied.
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
		_start_pour_animation()
		state = State.BLOOMING
		_update_label()
		_pour_game.start(player)
	elif _status_label:
		_status_label.text = "Hold filled kettle!\n[E] Start bloom pour"

func _try_start_main_pour(player: Player) -> void:
	var held := player.get_held_item()
	if held is Kettle and (held as Kettle).has_water:
		_pouring_player = player
		_pour_kettle = held as Kettle
		_start_pour_animation()
		state = State.MAIN_POUR
		_update_label()
		_pour_game.start(player)
	elif _status_label:
		_status_label.text = "Hold filled kettle!\n[E] Main pour"

func _start_pour_animation() -> void:
	if not _pour_kettle or not _pouring_player:
		return
	if _pour_tween and _pour_tween.is_valid():
		_pour_tween.kill()
	_pour_tween = StationUtils.start_kettle_pour(_pouring_player, _pour_kettle, _dripper_slot.global_position, Vector3(0, 0.09, 0), _pour_game.is_pouring, Vector3.LEFT)

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

	# Show bloom countdown while walking
	if state == State.BLOOM_WAIT:
		if _pour_game.is_ready_for_main_pour():
			state = State.MAIN_POUR
			_update_label()
		elif _status_label:
			_status_label.text = "Bloom... %.0fs\n[E] when ready (hold kettle)" % _pour_game.get_bloom_timer()

	if _drips:
		_drips.emitting = state == State.DRAINING
		if state == State.DRAINING:
			# Drips fall from the dripper's hole toward the cup.
			_drips.position = _dripper_slot.position + Vector3(0, -0.045, 0)
	if (state == State.READY or state == State.STALE) and _placed_cup:
		_placed_cup.heat = _pour_game.get_coffee_freshness()

	# Show drain countdown
	if state == State.DRAINING:
		if _pour_game.is_coffee_ready():
			_finish_drip()
		elif _status_label:
			_status_label.text = "Draining... %.0fs" % maxf(_pour_game.phase_timer, 0)

	if state == State.READY:
		if _pour_game.get_coffee_freshness() < 0.3:
			state = State.STALE
			_update_label()

	# Update dripper saturation visual during active pours
	if (state == State.BLOOMING or state == State.MAIN_POUR) and _pour_game.is_active() and _placed_dripper:
		_placed_dripper.set_saturation(_pour_game._get_avg_saturation())

	_check_removed_items()

func _finish_drip() -> void:
	SoundManager.stop_loop("drip_loop")
	SoundManager.play("drip_done")
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
	# Only check items that are actually here: is_item_removed() is true for a
	# null item, which used to knock READY back to CUP_ONLY every frame.
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
			_status_label.text = "[E] Bloom pour\n(hold filled kettle)"
		State.BLOOMING:
			_status_label.text = "Blooming..."
		State.BLOOM_WAIT:
			_status_label.text = "Bloom wait..."
		State.MAIN_POUR:
			_status_label.text = "[E] Main pour\n(hold filled kettle)"
		State.DRAINING:
			_status_label.text = "Draining..."
		State.READY:
			_status_label.text = "Coffee ready!\n[E] Pick up cup"
		State.STALE:
			_status_label.text = "Getting cold!\n[E] Pick up cup"
