extends StaticBody3D

enum State {
	IDLE,
	NEEDS_WATER,
	NEEDS_CUT,
	CUTTING,
	NEEDS_DUMP,
	NEEDS_STIR,
	STIRRING,
	JUG_READY,
	FILLING_BOTTLE,
}

const STIR_TARGET := 12.0
const MIN_MOTION := 3.0
const ANGLE_SCALE := 0.5
const JUG_CAPACITY := 5.0
const BOTTLE_FILL_COST := 1.0
## Water and cocoa stand this high in the jug while whisking (fraction of full).
const MIX_LEVEL := 0.6
const POWDER_COLOR := Color(0.55, 0.38, 0.25)
const SAUCE_COLOR := Color(0.25, 0.15, 0.08)
const WHISK_ORBIT := 0.022

var state := State.IDLE
var jug_level := 0.0
var _stir_progress := 0.0
var _prev_angle := 0.0
var _has_prev := false
var _cut_progress := 0.0
var _placed_bottle: SauceBottle = null

var _stir_game_active := false
var _player_ref: Player = null
var _activate_frame := -1

var _status_label: Label3D = null
var _jug_fill: MeshInstance3D = null
var _jug_fill_mesh: CylinderMesh = null
var _jug_floor := Vector3(-0.08, 0.02, -0.01)
var _jug_fill_height := 0.136
var _bag_visual: Node3D = null
var _cut_start := Vector3(0.025, 0.117, -0.03)
## Slit opening across the bag's top as you cut.
var _cut_line: MeshInstance3D = null
var _cut_mesh: BoxMesh = null
var _jug_fill_mat: StandardMaterial3D = null
var _whisk: Node3D = null
var _whisk_rest := Transform3D.IDENTITY
var _whisk_angle := 0.0
var _jug_radius := 0.054
var _bottle_slot: Marker3D = null
var _cam_point: Marker3D = null

func _ready() -> void:
	add_to_group("station")

	_bottle_slot = Marker3D.new()
	_bottle_slot.name = "BottleSlot"
	_bottle_slot.position = StationUtils.model_marker(self, "BottleSpot", Vector3(0.105, 0.015, 0.055))
	add_child(_bottle_slot)

	_cam_point = Marker3D.new()
	_cam_point.name = "CameraPoint"
	var view := get_node_or_null("Model/CameraView") as Node3D
	if view:
		_cam_point.transform = view.transform
	else:
		_cam_point.position = Vector3(0, 0.45, 0.36)
		_cam_point.rotation_degrees = Vector3(-35, 0, 0)
	add_child(_cam_point)

	# Batch level inside the model's jug; the bag hides while its powder is in.
	var model := get_node_or_null("Model")
	_jug_floor = StationUtils.model_marker(self, "JugFloor", _jug_floor)
	_cut_start = StationUtils.model_marker(self, "BagCut", _cut_start)
	_bag_visual = get_node_or_null("Model/PowderBag") as Node3D
	_jug_fill_mesh = CylinderMesh.new()
	_jug_fill_mesh.radial_segments = 24
	_jug_fill_mesh.rings = 1
	var radius := 0.054
	if model:
		radius = float(model.get_meta("jug_radius", radius))
		_jug_fill_height = float(model.get_meta("jug_fill_height", _jug_fill_height))
	_jug_fill_mesh.top_radius = radius
	_jug_fill_mesh.bottom_radius = radius - 0.003
	_jug_fill = MeshInstance3D.new()
	_jug_fill.name = "Batch"
	_jug_fill.mesh = _jug_fill_mesh
	_jug_radius = radius
	_jug_fill_mat = StandardMaterial3D.new()
	_jug_fill_mat.albedo_color = SAUCE_COLOR
	_jug_fill_mat.roughness = 0.3
	_jug_fill.material_override = _jug_fill_mat
	_jug_fill.visible = false
	add_child(_jug_fill)

	_cut_mesh = BoxMesh.new()
	_cut_mesh.size = Vector3(0.001, 0.0025, 0.002)
	_cut_line = MeshInstance3D.new()
	_cut_line.name = "Cut"
	_cut_line.mesh = _cut_mesh
	var clmat := StandardMaterial3D.new()
	clmat.albedo_color = Color(0.12, 0.08, 0.05)
	_cut_line.material_override = clmat
	_cut_line.position = _cut_start
	_cut_line.visible = false
	add_child(_cut_line)

	_whisk = get_node_or_null("Model/Whisk") as Node3D
	if _whisk:
		_whisk_rest = _whisk.transform

	_status_label = StationUtils.create_status_label(self)
	_update_label()
	_update_jug_visual()

func interact(player: Player) -> void:
	if StationUtils.is_same_frame(_activate_frame):
		return
	_activate_frame = Engine.get_process_frames()
	match state:
		State.IDLE:
			state = State.NEEDS_WATER
			_update_label()
		State.NEEDS_WATER:
			var held := player.get_held_item()
			if held is Kettle and (held as Kettle).has_water:
				(held as Kettle).use_water(Kettle.SHOT_PRESS_COST)
				jug_level = 0.0
				_update_jug_visual()
				state = State.NEEDS_CUT
				_update_label()
		State.NEEDS_CUT:
			_player_ref = player
			_stir_game_active = true
			_cut_progress = 0.0
			_cut_line.visible = true
			player.enter_mini_game(_cam_point.global_transform, self, 50.0)
			state = State.CUTTING
			_update_label()
		State.CUTTING:
			_exit_cam()
			_cut_line.visible = false
			state = State.NEEDS_CUT
			_update_label()
		State.NEEDS_DUMP:
			_bag_visual.visible = false
			state = State.NEEDS_STIR
			_stir_progress = 0.0
			_has_prev = false
			_update_label()
			_player_ref = player
			_stir_game_active = true
			_whisk_in(true)
			player.enter_mini_game(_cam_point.global_transform, self, 50.0)
			SoundManager.play_loop("sauce_prep_loop")
			state = State.STIRRING
			_update_label()
		State.STIRRING:
			SoundManager.stop_loop("sauce_prep_loop")
			_whisk_in(false)
			_exit_cam()
			state = State.NEEDS_STIR
			_update_label()
		State.JUG_READY:
			if _placed_bottle:
				if _placed_bottle.is_filled() and not player.has_held_item():
					if StationUtils.try_pickup_placed(player, _placed_bottle):
						_placed_bottle = null
						_update_label()
				elif _placed_bottle.is_empty() and jug_level >= BOTTLE_FILL_COST:
					_fill_bottle()
			if jug_level <= 0.01:
				state = State.IDLE
				_update_label()
		State.NEEDS_STIR:
			_player_ref = player
			_stir_game_active = true
			_has_prev = false
			_whisk_in(true)
			player.enter_mini_game(_cam_point.global_transform, self, 50.0)
			SoundManager.play_loop("sauce_prep_loop")
			state = State.STIRRING
			_update_label()

func receive_item(item: Node3D) -> bool:
	if not item is SauceBottle:
		return false
	if _placed_bottle:
		return false
	var bottle := item as SauceBottle
	if bottle.is_filled():
		return false
	_placed_bottle = bottle
	StationUtils.place_at_slot(item, _bottle_position(item))
	_update_label()
	return true

func _bottle_position(item: Node3D) -> Vector3:
	return _bottle_slot.global_position + Vector3(0, StationUtils.item_half_height(item, 0.1), 0)

func _fill_bottle() -> void:
	if not _placed_bottle or _placed_bottle.is_filled():
		return
	_placed_bottle.fill_with(DrinkData.SauceType.MOCHA)
	jug_level -= BOTTLE_FILL_COST
	_update_jug_visual()
	SoundManager.play("sauce_batch_done")
	state = State.JUG_READY
	_update_label()

## Player calls this for the leave keys while cutting or whisking.
func leave() -> void:
	match state:
		State.CUTTING:
			_exit_cam()
			_cut_line.visible = false
			state = State.NEEDS_CUT
			_update_label()
		State.STIRRING:
			SoundManager.stop_loop("sauce_prep_loop")
			_whisk_in(false)
			_exit_cam()
			state = State.NEEDS_STIR
			_update_label()

func take_item(player: Player) -> bool:
	if state == State.JUG_READY and _placed_bottle and _placed_bottle.is_filled():
		if StationUtils.try_pickup_placed(player, _placed_bottle):
			_placed_bottle = null
			_update_label()
			return true
	return false

func _exit_cam() -> void:
	_stir_game_active = false
	if _player_ref and is_instance_valid(_player_ref):
		_player_ref.exit_mini_game()
	_player_ref = null

func _input(event: InputEvent) -> void:
	if not _stir_game_active:
		return

	if state == State.CUTTING:
		if event is InputEventMouseMotion:
			var mx := absf(event.relative.x)
			if mx > 5.0:
				_cut_progress += mx * 0.005
				_cut_mesh.size.x = minf(_cut_progress * 0.08, 0.08)
				_cut_line.position.x = _cut_start.x + _cut_mesh.size.x * 0.5
				if _cut_progress >= 1.0:
					_cut_line.visible = false
					SoundManager.play("bag_tear")
					_exit_cam()
					state = State.NEEDS_DUMP
					_update_label()

	if state == State.STIRRING:
		if event is InputEventMouseMotion:
			var motion := event as InputEventMouseMotion
			if motion.relative.length() < MIN_MOTION:
				return
			var angle := atan2(motion.relative.y, motion.relative.x)
			if _has_prev:
				var delta := angle - _prev_angle
				while delta > PI: delta -= TAU
				while delta < -PI: delta += TAU
				_stir_progress += absf(delta) * ANGLE_SCALE / TAU
				_whisk_angle += delta
			_prev_angle = angle
			_has_prev = true
			if _stir_progress >= STIR_TARGET:
				SoundManager.stop_loop("sauce_prep_loop")
				SoundManager.play("sauce_batch_done")
				_whisk_in(false)
				_exit_cam()
				jug_level = JUG_CAPACITY
				_update_jug_visual()
				_bag_visual.visible = true
				state = State.JUG_READY
				_update_label()

## Whisk stood upright in the jug while mixing, back on the board after.
func _whisk_in(into_jug: bool) -> void:
	if not _whisk:
		return
	if not into_jug:
		_whisk.transform = _whisk_rest
		_update_jug_visual()
		return
	_update_whisk()

func _update_whisk() -> void:
	if not _whisk:
		return
	var dir := Vector3(cos(_whisk_angle), 0, sin(_whisk_angle))
	# Wires down: the whisk's +Y (handle to wires) points at the jug floor.
	var basis := Basis(Vector3.RIGHT, PI) * Basis(Vector3.UP, _whisk_angle * 2.0)
	basis = Basis(dir.cross(Vector3.UP).normalized(), deg_to_rad(-10.0)) * basis
	var wires_at := _jug_floor + Vector3(0, 0.035, 0) + dir * WHISK_ORBIT
	_whisk.transform = Transform3D(basis, wires_at - basis * Vector3(0, 0.035, 0))

## Mixing: cocoa floats as a pale crust on the water and darkens to sauce.
func _show_mix(progress: float) -> void:
	_jug_fill.visible = true
	var h := _jug_fill_height * MIX_LEVEL
	_jug_fill_mesh.height = h
	_jug_fill.position = _jug_floor + Vector3(0, h * 0.5, 0)
	_jug_fill_mat.albedo_color = POWDER_COLOR.lerp(SAUCE_COLOR, clampf(progress, 0.0, 1.0))

func _update_jug_visual() -> void:
	if not _jug_fill:
		return
	_jug_fill_mat.albedo_color = SAUCE_COLOR
	if jug_level <= 0.01:
		_jug_fill.visible = false
		return
	_jug_fill.visible = true
	var ratio := clampf(jug_level / JUG_CAPACITY, 0.0, 1.0)
	var h := maxf(_jug_fill_height * ratio, 0.002)
	_jug_fill_mesh.height = h
	_jug_fill.position = _jug_floor + Vector3(0, h * 0.5, 0)

## Helper UI while the camera is locked here.
func get_controls_hint() -> String:
	match state:
		State.CUTTING:
			return BaseMiniGame.hint([["Swipe mouse sideways", "Cut the bag open"], ["E", "Leave"]])
		State.STIRRING:
			return BaseMiniGame.hint([["Circle mouse", "Whisk"], ["E", "Leave"]])
	return ""

func get_assist_readout() -> String:
	match state:
		State.CUTTING:
			return "Cut  %d%%" % roundi(clampf(_cut_progress, 0.0, 1.0) * 100.0)
		State.STIRRING:
			return "Mixed  %d%%" % roundi(clampf(_stir_progress / STIR_TARGET, 0.0, 1.0) * 100.0)
	return ""

func _process(_delta: float) -> void:
	if state == State.STIRRING:
		_show_mix(_stir_progress / STIR_TARGET)
		_update_whisk()
	if _placed_bottle and StationUtils.is_item_removed(_placed_bottle, _bottle_position(_placed_bottle)):
		_placed_bottle = null
		_update_label()

func _update_label() -> void:
	if not _status_label:
		return
	match state:
		State.IDLE:
			_status_label.text = "[E] Start a mocha batch"
		State.NEEDS_WATER:
			_status_label.text = "Hold a filled kettle\n[E] Add hot water"
		State.NEEDS_CUT:
			_status_label.text = "[E] Cut the bag open"
		State.CUTTING:
			_status_label.text = ""
		State.NEEDS_DUMP:
			_status_label.text = "[E] Tip in the cocoa"
		State.NEEDS_STIR:
			_status_label.text = "[E] Whisk"
		State.STIRRING:
			_status_label.text = ""
		State.JUG_READY:
			if _placed_bottle and _placed_bottle.is_empty() and jug_level >= BOTTLE_FILL_COST:
				_status_label.text = "[E] Fill the bottle"
			elif _placed_bottle and _placed_bottle.is_filled():
				_status_label.text = "[Click] Pick up bottle"
			else:
				_status_label.text = "[Click] Set down an empty bottle"
		State.FILLING_BOTTLE:
			_status_label.text = ""
