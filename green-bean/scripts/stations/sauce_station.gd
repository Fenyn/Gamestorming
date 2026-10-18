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
## While drizzling the bottle is turned over the cup and steered by the game;
## the sauce lines are drawn onto the drink as a MultiMesh under the cup.
const MAX_BLOBS := 1200
const BLOB_SPACING := 0.0018
const NOZZLE_Y := 0.102
const HOVER := 0.035
var _bottle_home := Transform3D.IDENTITY
var _bottle_model: Node3D = null
var _drizzle: MultiMeshInstance3D = null
var _blob_count := 0
var _last_blob := Vector3(INF, INF, INF)
var _stream: PourStream = null
var _completed := false
func _ready() -> void:
	add_to_group("station")

	# Floor spots from the model; items are stood on them by half their height.
	_cup_slot = Marker3D.new()
	_cup_slot.name = "CupSlot"
	_cup_slot.position = StationUtils.model_marker(self, "CupSpot", Vector3(-0.03, 0.005, 0.02))
	add_child(_cup_slot)

	_bottle_slot = Marker3D.new()
	_bottle_slot.name = "BottleSlot"
	_bottle_slot.position = StationUtils.model_marker(self, "BottleSpot", Vector3(0.085, 0.005, -0.02))
	add_child(_bottle_slot)

	_mini_game = SauceMiniGame.new()
	_mini_game.name = "SauceMiniGame"
	var cam := Marker3D.new()
	cam.name = "CameraPoint"
	cam.position = Vector3(0, 0.4, 0.14)
	cam.rotation_degrees = Vector3(-68, 0, 0)
	_mini_game.add_child(cam)
	add_child(_mini_game)
	# Camera framed on the cup.
	_mini_game.position = Vector3(_cup_slot.position.x, 0, _cup_slot.position.z)
	_mini_game._camera_point = cam
	_mini_game.camera_fov = 45.0
	_mini_game.mini_game_completed.connect(_on_drizzle_complete)

	_stream = PourStream.new(DrinkData.get_sauce_color(sauce_type), 0.0016)
	_stream.source = self
	_stream.flow_check = _sauce_flowing
	add_child(_stream)

	var card := get_node_or_null("Model/NameCard") as Label3D
	if card:
		card.text = DrinkData.get_sauce_name(sauce_type)
	_status_label = StationUtils.create_status_label(self)
	_update_label()

func _on_slot(slot: Marker3D, item: Node3D) -> Vector3:
	return slot.global_position + Vector3(0, StationUtils.item_half_height(item), 0)

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
			_status_label.text = "Bottle's empty\nRefill it at prep"
		return
	_mini_game.start(player)
	if _mini_game.is_active():
		_activate_frame = Engine.get_process_frames()
		state = State.DRIZZLING
		_completed = false
		_begin_drizzle_visuals()
		_update_label()

func _begin_drizzle_visuals() -> void:
	_bottle_home = _placed_bottle.global_transform
	_bottle_model = _placed_bottle.get_node_or_null("Model") as Node3D
	_stream.source = _placed_bottle
	_stream.source_offset = Vector3(0, NOZZLE_Y, 0)
	_drizzle = _placed_cup.get_node_or_null("Drizzle") as MultiMeshInstance3D
	if _drizzle == null:
		var blob := SphereMesh.new()
		blob.radius = 0.0021
		blob.height = 0.0012
		blob.radial_segments = 8
		blob.rings = 3
		var mat := StandardMaterial3D.new()
		mat.albedo_color = DrinkData.get_sauce_color(sauce_type)
		mat.roughness = 0.25
		blob.material = mat
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = blob
		mm.instance_count = MAX_BLOBS
		mm.visible_instance_count = 0
		_drizzle = MultiMeshInstance3D.new()
		_drizzle.name = "Drizzle"
		_drizzle.multimesh = mm
		_placed_cup.add_child(_drizzle)
	_drizzle.position = Vector3(0, _placed_cup.surface_y() + 0.0004, 0)
	_blob_count = _drizzle.multimesh.visible_instance_count
	_last_blob = Vector3(INF, INF, INF)

## Point on the drink surface under the bottle, in the cup's space.
func _aim_local() -> Vector3:
	var r := _placed_cup.surface_radius() * 0.9
	var a := _mini_game.get_aim()
	return Vector3(a.x * r, _placed_cup.surface_y(), a.y * r)

func _sauce_flowing() -> bool:
	if state != State.DRIZZLING or not _placed_cup or not _mini_game.is_squeezing():
		return false
	_stream.target_point = _placed_cup.to_global(_aim_local())
	return true

## Bottle upside down over the cup, following the aim, squashed while squeezed.
func _update_drizzle(delta: float) -> void:
	if not _placed_bottle or not _placed_cup:
		return
	var aim := _placed_cup.to_global(_aim_local())
	# Upside down and tipped toward the barista; the nozzle hovers over the aim.
	var basis := global_basis * Basis(Vector3.RIGHT, PI - 0.25)
	var target := Transform3D(basis, aim + global_basis.y * HOVER - basis * Vector3(0, NOZZLE_Y, 0))
	_placed_bottle.global_transform = _placed_bottle.global_transform.interpolate_with(target, minf(delta * 20.0, 1.0))
	if _bottle_model:
		var squash := 0.88 if _mini_game.is_squeezing() else 1.0
		var sxz := lerpf(_bottle_model.scale.x, squash, minf(delta * 14.0, 1.0))
		_bottle_model.scale = Vector3(sxz, 1.0, sxz)
	if not _mini_game.is_squeezing():
		_last_blob = Vector3(INF, INF, INF)
		return
	# Lay blobs every BLOB_SPACING along the path since the last one, so a fast
	# flick still draws a continuous line.
	var p := _aim_local() - Vector3(0, _placed_cup.surface_y(), 0)
	if _last_blob.x == INF:
		_add_blob(p)
		return
	var run := p.distance_to(_last_blob)
	var steps := mini(int(run / BLOB_SPACING), 24)
	var from := _last_blob
	for i in range(1, steps + 1):
		_add_blob(from.lerp(p, float(i) / float(steps)))

func _add_blob(p: Vector3) -> void:
	if _blob_count >= MAX_BLOBS:
		return
	_drizzle.multimesh.set_instance_transform(_blob_count, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * randf_range(0.85, 1.15)), p))
	_blob_count += 1
	_drizzle.multimesh.visible_instance_count = _blob_count
	_last_blob = p

func _end_drizzle_visuals() -> void:
	if _placed_bottle and is_instance_valid(_placed_bottle):
		_placed_bottle.global_transform = _bottle_home
		if _bottle_model:
			_bottle_model.scale = Vector3.ONE
	# Too little to count: wipe it off.
	if not _completed and _drizzle and is_instance_valid(_drizzle):
		_drizzle.queue_free()
	_drizzle = null
	_bottle_model = null

func receive_item(item: Node3D) -> bool:
	if item is Cup:
		if _placed_cup:
			return false
		var cup := item as Cup
		if cup.has_sauce:
			return false
		_placed_cup = cup
		StationUtils.place_at_slot(item, _on_slot(_cup_slot, item))
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
		StationUtils.place_at_slot(item, _on_slot(_bottle_slot, item))
		_recalc_state()
		return true
	return false

func _on_drizzle_complete(quality: float) -> void:
	if not _placed_cup or not _placed_bottle:
		return
	_completed = true
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
			_status_label.text = "[Click] Set down a %s bottle and a cup" % sauce_name.to_lower()
		State.BOTTLE_ONLY:
			_status_label.text = "[Click] Set down a cup"
		State.CUP_ONLY:
			_status_label.text = "Needs a %s bottle" % sauce_name.to_lower()
		State.READY:
			if _placed_cup and _placed_cup.has_sauce:
				_status_label.text = "[E] Pick up cup"
			elif _placed_bottle and _placed_bottle.is_empty():
				_status_label.text = "Bottle's empty\n[E] Pick up bottle"
			else:
				_status_label.text = "[E] Drizzle %s" % sauce_name
		State.DRIZZLING:
			_status_label.text = ""

func _process(delta: float) -> void:
	if state == State.DRIZZLING and _mini_game.is_active():
		_update_drizzle(delta)
	if _bottle_model and not _mini_game.is_active():
		_end_drizzle_visuals()
	if state == State.DRIZZLING and not _mini_game.is_active():
		_recalc_state()
	if _placed_cup and StationUtils.is_item_removed(_placed_cup, _on_slot(_cup_slot, _placed_cup)):
		_placed_cup = null
		_recalc_state()
	if _placed_bottle and StationUtils.is_item_removed(_placed_bottle, _on_slot(_bottle_slot, _placed_bottle)):
		_placed_bottle = null
		_recalc_state()
