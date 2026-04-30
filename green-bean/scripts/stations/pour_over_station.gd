extends StaticBody3D

# Player flow:
# 1. Place cup on station
# 2. Pick up dripper from shelf (or bring one)
# 3. Carry dripper to grinder, grind (grounds go into dripper)
# 4. Carry dripper back, place on station (on top of cup)
# 5. [E] Pour water → saturation mini-game
# 6. Draw-down (passive — walk away)
# 7. Come back, coffee is in cup, dripper resets to shelf
# 8. Pick up cup

enum State { IDLE, CUP_ONLY, READY_TO_POUR, POURING, DRAINING, READY, STALE }

var state := State.IDLE
var _placed_cup: Cup = null
var _placed_dripper: Dripper = null
var _shelf_dripper: Dripper = null

var _pour_game: PourMiniGame = null
var _correct_grind := true
var _grind_quality := 1.0
var _pour_quality := 0.0

var _cup_slot: Marker3D = null
var _dripper_slot: Marker3D = null

var _status_label: Label3D = null

func _ready() -> void:
	add_to_group("station")

	_cup_slot = Marker3D.new()
	_cup_slot.name = "CupSlot"
	_cup_slot.position = Vector3(0, 0.12, 0)
	add_child(_cup_slot)

	_dripper_slot = Marker3D.new()
	_dripper_slot.name = "DripperSlot"
	_dripper_slot.position = Vector3(0, 0.22, 0)
	add_child(_dripper_slot)

	_pour_game = PourMiniGame.new()
	_pour_game.name = "PourMiniGame"
	_pour_game.pour_mode = PourMiniGame.PourMode.SATURATION
	var cam := Marker3D.new()
	cam.name = "CameraPoint"
	cam.position = Vector3(0, 0.4, 0.4)
	cam.rotation_degrees = Vector3(-35, 0, 0)
	_pour_game.add_child(cam)
	add_child(_pour_game)
	_pour_game.mini_game_completed.connect(_on_pour_complete)

	_spawn_shelf_dripper()

	_status_label = Label3D.new()
	_status_label.text = ""
	_status_label.font_size = 12
	_status_label.position = Vector3(0, 0.3, 0.15)
	_status_label.pixel_size = 0.002
	_status_label.add_to_group("world_label")
	add_child(_status_label)
	_update_label()

func _spawn_shelf_dripper() -> void:
	_shelf_dripper = Dripper.new()
	_shelf_dripper.name = "DripperShelf"
	add_child(_shelf_dripper)
	_shelf_dripper.position = Vector3(0.15, 0.15, 0)

func interact(player: Player) -> void:
	match state:
		State.IDLE:
			_try_pickup_shelf_dripper(player)
		State.CUP_ONLY:
			_try_pickup_shelf_dripper(player)
		State.READY_TO_POUR:
			if _pour_game.is_active():
				_pour_game.stop()
			else:
				_pour_game.start(player)
		State.POURING:
			_pour_game.stop()
		State.DRAINING:
			pass
		State.READY, State.STALE:
			if _status_label:
				_status_label.text = "Pick up cup!\n(has coffee)"

func _try_pickup_shelf_dripper(player: Player) -> void:
	if not player.has_held_item() and _shelf_dripper and is_instance_valid(_shelf_dripper):
		player.pickup_item(_shelf_dripper)
		_shelf_dripper = null
		_update_label()

func receive_item(item: Node3D) -> bool:
	if item is Cup:
		if _placed_cup:
			return false
		_placed_cup = item as Cup
		_place_at_slot(item, _cup_slot)
		_recalculate_state()
		return true

	if item is Dripper:
		if _placed_dripper:
			return false
		var drip := item as Dripper
		_placed_dripper = drip
		_place_at_slot(item, _dripper_slot)
		if drip.has_grounds():
			_correct_grind = (drip.grounds.grind_level == DrinkData.GrindLevel.COARSE)
			_grind_quality = drip.grounds.grind_quality
		_recalculate_state()
		return true

	return false

func _place_at_slot(item: Node3D, slot: Marker3D) -> void:
	item.global_position = slot.global_position
	item.global_rotation = Vector3.ZERO
	if item is RigidBody3D:
		(item as RigidBody3D).freeze = true
	for child in item.get_children():
		if child is CollisionShape3D:
			child.disabled = true

func _recalculate_state() -> void:
	if _placed_cup and _placed_dripper:
		if not _placed_dripper.has_grounds():
			state = State.CUP_ONLY
			if _status_label:
				_status_label.text = "Dripper needs grounds!\nTake to grinder first"
		else:
			state = State.READY_TO_POUR
	elif _placed_cup and not _placed_dripper:
		state = State.CUP_ONLY
	else:
		state = State.IDLE
	_update_label()

func _on_pour_complete(quality: float) -> void:
	_pour_quality = quality
	state = State.DRAINING
	_update_label()

func _process(_delta: float) -> void:
	if state == State.DRAINING:
		if _pour_game.is_coffee_ready():
			_finish_drip()

	if state == State.READY:
		if _pour_game.get_coffee_freshness() < 0.3:
			state = State.STALE
			_update_label()

	_check_removed_items()

func _finish_drip() -> void:
	if _placed_cup:
		var freshness := _pour_game.get_coffee_freshness()
		_placed_cup.has_pour_over_coffee = true
		if _placed_cup.order:
			_placed_cup.order.pour_quality = _pour_quality * freshness
			_placed_cup.order.correct_grind_level = _correct_grind
			_placed_cup.order.grind_quality = _grind_quality * (1.0 if _correct_grind else 0.5)
		_placed_cup.set_fill(0.85, Color(0.35, 0.22, 0.1))

	if _placed_dripper:
		_placed_dripper.reset_device()
		_placed_dripper.global_position = Vector3(global_position.x + 0.15, global_position.y + 0.15, global_position.z)
		_shelf_dripper = _placed_dripper
		_placed_dripper = null

	state = State.READY
	_update_label()

func _check_removed_items() -> void:
	if _placed_cup:
		if not is_instance_valid(_placed_cup):
			_placed_cup = null
			_recalculate_state()
		elif _placed_cup.global_position.distance_to(_cup_slot.global_position) > 0.5:
			_placed_cup = null
			_recalculate_state()
	if _placed_dripper:
		if not is_instance_valid(_placed_dripper):
			_placed_dripper = null
			_recalculate_state()
		elif _placed_dripper.global_position.distance_to(_dripper_slot.global_position) > 0.5:
			_placed_dripper = null
			_recalculate_state()

func _update_label() -> void:
	if not _status_label:
		return
	match state:
		State.IDLE:
			var has_shelf := _shelf_dripper != null and is_instance_valid(_shelf_dripper)
			if has_shelf:
				_status_label.text = "[E] Pick up dripper\nor [Click] place cup"
			else:
				_status_label.text = "[Click] Place cup"
		State.CUP_ONLY:
			var has_shelf := _shelf_dripper != null and is_instance_valid(_shelf_dripper)
			if has_shelf:
				_status_label.text = "Cup placed\n[E] Pick up dripper"
			else:
				_status_label.text = "Cup placed\nBring dripper with grounds"
		State.READY_TO_POUR:
			_status_label.text = "[E] Pour water"
		State.POURING:
			_status_label.text = "POURING..."
		State.DRAINING:
			_status_label.text = "DRAINING..."
		State.READY:
			_status_label.text = "Coffee ready!\n[Click] Pick up cup"
		State.STALE:
			_status_label.text = "Coffee getting cold!\n[Click] Pick up cup"
