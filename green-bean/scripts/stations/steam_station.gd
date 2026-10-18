extends StaticBody3D

enum State { IDLE, PITCHER_PLACED, STRETCHING, TEXTURING, READY, MILK_DONE, SCALDED }

var state: State = State.IDLE
var _steam_game: SteamMiniGame = null
var _placed_pitcher: Pitcher = null
var _shelf_pitcher: Pitcher = null

var _pitcher_slot: Marker3D = null
var _status_label: Label3D = null
var _steam_puffs: SteamPuffs = null
var _tip: Node3D = null
var _lever: Node3D = null
var _lever_rest := 0.0
const LEVER_OPEN_DEG := 40.0
## Pitcher lift shown on screen, eased toward the game's.
var _shown_lift := 0.0
## Fine bubbles while stretching well; spray when the tip is at the surface.
var _microfoam: GPUParticles3D = null
var _spray: GPUParticles3D = null

func _ready() -> void:
	add_to_group("station")

	_pitcher_slot = Marker3D.new()
	_pitcher_slot.name = "PitcherSlot"
	# Pitchers are lifted by half their height to stand on the model's markers.
	_pitcher_slot.position = StationUtils.model_marker(self, "PitcherPad", Vector3(0, 0.125, 0))
	add_child(_pitcher_slot)

	_steam_game = SteamMiniGame.new()
	_steam_game.name = "SteamMiniGame"
	var cam: Marker3D = Marker3D.new()
	cam.name = "CameraPoint"
	var view := get_node_or_null("Model/CameraView") as Node3D
	if view:
		# The mini-game node sits at the station origin, so station-local works here.
		cam.transform = global_transform.affine_inverse() * view.global_transform
	else:
		cam.position = Vector3(0, 0.4, 0.4)
		cam.rotation_degrees = Vector3(-25, 0, 0)
	_steam_game.add_child(cam)
	add_child(_steam_game)
	_steam_game._camera_point = cam
	_steam_game.mini_game_completed.connect(_on_steam_complete)
	_steam_game.camera_fov = 50.0

	_spawn_shelf_pitcher()

	_steam_puffs = SteamPuffs.new(40, 0.07, 0.16)
	_steam_puffs.position = StationUtils.model_marker(self, "SteamVent", Vector3(0, 0.22, 0))
	add_child(_steam_puffs)

	_tip = get_node_or_null("Model/Wand/TipEnd") as Node3D
	_lever = get_node_or_null("Model/Head/Lever") as Node3D
	if _lever:
		_lever_rest = _lever.rotation_degrees.x
	_microfoam = Fx.make_specks(Color(1.0, 1.0, 0.98, 0.9), 0.0025, 0.05, 0.35, 30)
	add_child(_microfoam)
	_spray = Fx.make_specks(Color(0.97, 0.96, 0.92, 0.9), 0.004, -4.0, 0.4, 24)
	(_spray.process_material as ParticleProcessMaterial).direction = Vector3.UP
	(_spray.process_material as ParticleProcessMaterial).spread = 50.0
	(_spray.process_material as ParticleProcessMaterial).initial_velocity_min = 0.25
	(_spray.process_material as ParticleProcessMaterial).initial_velocity_max = 0.5
	add_child(_spray)

	_status_label = StationUtils.create_status_label(self)
	_update_label()

## Tells the game how high the wand tip sits above fresh milk in this pitcher
## while it stands on the tray, and how far foam lifts the surface.
func _measure_wand(pitcher: Pitcher) -> void:
	if not _tip:
		return
	# From where it stands on the pad, not where it is now (it may still be settling).
	var surface := (_pitcher_home(pitcher) + global_basis.y * pitcher.surface_y(0.0)).y
	_steam_game.tip_clearance = _tip.global_position.y - surface
	_steam_game.foam_rise_m = pitcher.milk_height * pitcher.foam_rise

func _pitcher_home(pitcher: Node3D) -> Vector3:
	return _pitcher_slot.global_position + Vector3(0, StationUtils.item_half_height(pitcher), 0)

func _spawn_shelf_pitcher() -> void:
	_shelf_pitcher = Pitcher.new()
	_shelf_pitcher.name = "PitcherShelf"
	add_child(_shelf_pitcher)
	_shelf_pitcher.position = _rest_position(_shelf_pitcher)

## Station-local centre of a pitcher standing on the mat.
func _rest_position(pitcher: Node3D) -> Vector3:
	return StationUtils.model_marker(self, "PitcherRest", Vector3(0.12, -0.12, 0.03)) + Vector3(0, StationUtils.item_half_height(pitcher), 0)

func interact(player: Player) -> void:
	if _steam_game.is_active():
		return
	match state:
		State.IDLE:
			_try_pickup_shelf_pitcher(player)
		State.PITCHER_PLACED:
			if _placed_pitcher and _placed_pitcher.has_milk:
				var foam_target: float = _get_foam_target(player)
				_steam_game.set_foam_target(foam_target)
				_measure_wand(_placed_pitcher)
				state = State.STRETCHING
				_update_label()
				_steam_game.start(player)
			else:
				_try_pickup_placed_pitcher(player)
		State.STRETCHING:
			# Stepped away mid-stretch: pick up where it was.
			_steam_game.start(player)
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
		# Pad is taken: park the pitcher on the mat if it is free.
		return receive_on_mat(item)
	_placed_pitcher = item as Pitcher
	StationUtils.place_at_slot(item, _pitcher_slot.global_position + Vector3(0, StationUtils.item_half_height(item), 0))
	item.global_rotation = global_rotation
	state = State.PITCHER_PLACED
	_update_label()
	return true

## Called through MatArea when a pitcher is clicked onto the mat.
func receive_on_mat(item: Node3D) -> bool:
	if not item is Pitcher or _mat_occupied():
		return false
	StationUtils.place_at_slot(item, to_global(_rest_position(item)))
	item.global_rotation = global_rotation
	# Keep its collider on so it can be clicked up again.
	StationUtils.set_item_collision(item, true)
	_shelf_pitcher = item as Pitcher
	if state == State.IDLE:
		_update_label()
	return true

func _mat_occupied() -> bool:
	return _shelf_pitcher != null and is_instance_valid(_shelf_pitcher)

func _on_steam_complete(quality: float) -> void:
	if quality > 0 and _placed_pitcher:
		_placed_pitcher.set_steamed(quality)
		_placed_pitcher.foam_level = _steam_game.foam_level
		state = State.MILK_DONE
	elif quality <= 0:
		state = State.SCALDED
	_update_label()

func _get_foam_target(player: Player) -> float:
	var order: OrderData = player.get_active_order()
	if order:
		return DrinkData.get_foam_target(order.drink_type)
	return DrinkData.DEFAULT_FOAM_TARGET

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

	if state == State.READY and not _steam_game.is_active():
		if _steam_game.is_scalded():
			state = State.SCALDED
			_update_label()

	_update_pitcher_lift(_delta)
	_update_steam_fx()
	_update_lever(_delta)
	_check_removed_items()

## The pitcher rides up and down with the game's lift while stretching and
## settles back on the tray after.
func _update_pitcher_lift(delta: float) -> void:
	if not _placed_pitcher:
		_shown_lift = 0.0
		return
	var target := _steam_game.lift if state == State.STRETCHING and _steam_game.is_active() else 0.0
	if target == 0.0 and _shown_lift == 0.0:
		return
	_shown_lift = lerpf(_shown_lift, target, minf(delta * 18.0, 1.0))
	if target == 0.0 and _shown_lift < 0.0005:
		_shown_lift = 0.0
	_placed_pitcher.global_position = _pitcher_home(_placed_pitcher) + global_basis.y * _shown_lift

func _steam_on() -> bool:
	return _steam_game.is_steaming() or state == State.TEXTURING or state == State.READY

func _update_lever(delta: float) -> void:
	if not _lever:
		return
	var target := _lever_rest + (LEVER_OPEN_DEG if _steam_on() else 0.0)
	_lever.rotation_degrees.x = lerpf(_lever.rotation_degrees.x, target, minf(delta * 16.0, 1.0))

func _update_steam_fx() -> void:
	var temp_ratio := clampf((_steam_game.get_temperature() - 20.0) / (SteamMiniGame.TARGET_TEMP - 20.0), 0.0, 1.0)
	match state:
		State.STRETCHING:
			_steam_puffs.set_level(0.9 if _steam_game.is_steaming() else 0.1)
		State.TEXTURING:
			_steam_puffs.set_level(0.4 + 0.4 * temp_ratio)
		State.READY:
			# Past target and still heating: steam starts to get aggressive.
			var over := clampf((_steam_game.get_temperature() - SteamMiniGame.TARGET_TEMP) / (SteamMiniGame.SCALD_TEMP - SteamMiniGame.TARGET_TEMP), 0.0, 1.0)
			_steam_puffs.set_level(0.8 + 0.2 * over, over > 0.6)
		State.SCALDED:
			_steam_puffs.set_level(1.0, true)
		_:
			_steam_puffs.set_level(0.0)
	if _placed_pitcher and _placed_pitcher.has_milk and state != State.MILK_DONE:
		_placed_pitcher.update_milk_visual(temp_ratio, _steam_game.foam_level, state == State.SCALDED)
		_placed_pitcher.set_temperature(_steam_game.get_temperature())
		_update_milk_motion()
	else:
		_microfoam.emitting = false
		_spray.emitting = false

## What the tip does to the milk: a spinning vortex when steaming, fine bubbles
## at the right depth, spray and big bubbles when it is too shallow, a slow
## roll when deep, and a hard boil once scalded.
func _update_milk_motion() -> void:
	var stretching := state == State.STRETCHING and _steam_game.is_steaming()
	var depth := _steam_game.tip_depth()
	var shallow := stretching and depth < SteamMiniGame.TIP_ZONE.x
	var in_zone := stretching and not shallow and depth <= SteamMiniGame.TIP_ZONE.y
	var swirl := 0.0
	var agitation := 0.0
	if stretching:
		swirl = 0.6 if shallow else 1.0
		agitation = 1.0 if shallow else (0.35 if in_zone else 0.15)
	elif state == State.TEXTURING or state == State.READY:
		swirl = 0.7
		agitation = 0.2
	elif state == State.SCALDED:
		agitation = 1.0
	_placed_pitcher.set_agitation(swirl, agitation)
	var surface := _placed_pitcher.to_global(Vector3(0, _placed_pitcher.surface_y(_steam_game.foam_level), 0))
	var at_tip := Vector3(_tip.global_position.x, surface.y, _tip.global_position.z) if _tip else surface
	_microfoam.global_position = at_tip
	_spray.global_position = at_tip
	_microfoam.emitting = in_zone
	_spray.emitting = shallow

func _check_removed_items() -> void:
	if _shelf_pitcher and StationUtils.is_item_removed(_shelf_pitcher, to_global(_rest_position(_shelf_pitcher)), 0.15):
		_shelf_pitcher = null
		if state == State.IDLE:
			_update_label()
	if _placed_pitcher and StationUtils.is_item_removed(_placed_pitcher, _pitcher_slot.global_position):
		_placed_pitcher = null
		if state != State.IDLE:
			_reset()

func _reset() -> void:
	state = State.IDLE
	_steam_game.reset_steam()
	if _placed_pitcher:
		_placed_pitcher.reset_pitcher()
		if _mat_occupied():
			# The mat already has a pitcher, so the emptied one stays on the pad.
			state = State.PITCHER_PLACED
		else:
			StationUtils.cancel_settle(_placed_pitcher)
			_placed_pitcher.global_position = to_global(_rest_position(_placed_pitcher))
			StationUtils.set_item_collision(_placed_pitcher, true)
			_shelf_pitcher = _placed_pitcher
			_placed_pitcher = null
	_update_label()

func _update_label() -> void:
	if not _status_label:
		return
	match state:
		State.IDLE:
			if _mat_occupied():
				_status_label.text = "[E] Pick up pitcher"
			else:
				_status_label.text = "Needs a pitcher of milk"
		State.PITCHER_PLACED:
			if _placed_pitcher and _placed_pitcher.has_milk:
				_status_label.text = "[E] Start steaming"
			else:
				_status_label.text = "No milk in it\n[E] Pick up pitcher"
		State.STRETCHING:
			_status_label.text = ""
		State.TEXTURING:
			_status_label.text = "Heating\n[E] Watch it"
		State.READY:
			_status_label.text = "Milk's hot\n[E] Steam off"
		State.MILK_DONE:
			_status_label.text = "[E] Pick up pitcher"
		State.SCALDED:
			_status_label.text = "Scalded\n[E] Dump and reset"
