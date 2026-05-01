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
const BAR_WIDTH := 0.2

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
var _jug_visual: CSGCylinder3D = null
var _jug_fill: CSGCylinder3D = null
var _bag_visual: CSGBox3D = null
var _cut_line: CSGBox3D = null
var _stir_bar_bg: CSGBox3D = null
var _stir_bar_fill: CSGBox3D = null
var _bottle_slot: Marker3D = null
var _cam_point: Marker3D = null

func _ready() -> void:
	add_to_group("station")

	_bottle_slot = Marker3D.new()
	_bottle_slot.name = "BottleSlot"
	_bottle_slot.position = Vector3(0.15, 0.12, 0)
	add_child(_bottle_slot)

	_cam_point = Marker3D.new()
	_cam_point.name = "CameraPoint"
	_cam_point.position = Vector3(0, 0.4, 0.35)
	_cam_point.rotation_degrees = Vector3(-35, 0, 0)
	add_child(_cam_point)

	_jug_visual = CSGCylinder3D.new()
	_jug_visual.radius = 0.06
	_jug_visual.height = 0.14
	_jug_visual.position = Vector3(-0.08, 0.12, 0)
	var jmat := StandardMaterial3D.new()
	jmat.albedo_color = Color(0.8, 0.8, 0.82, 0.5)
	jmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	jmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_jug_visual.material = jmat
	add_child(_jug_visual)

	_jug_fill = CSGCylinder3D.new()
	_jug_fill.radius = 0.055
	_jug_fill.height = 0.001
	_jug_fill.position = Vector3(-0.08, 0.06, 0)
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.25, 0.15, 0.08)
	_jug_fill.material = fmat
	_jug_fill.visible = false
	add_child(_jug_fill)

	_bag_visual = CSGBox3D.new()
	_bag_visual.size = Vector3(0.08, 0.06, 0.05)
	_bag_visual.position = Vector3(0.08, 0.1, 0)
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.35, 0.2, 0.1)
	_bag_visual.material = bmat
	add_child(_bag_visual)

	_cut_line = CSGBox3D.new()
	_cut_line.size = Vector3(0.001, 0.003, 0.05)
	_cut_line.position = Vector3(0.04, 0.13, 0)
	var clmat := StandardMaterial3D.new()
	clmat.albedo_color = Color(1, 1, 1)
	_cut_line.material = clmat
	_cut_line.visible = false
	add_child(_cut_line)

	_stir_bar_bg = CSGBox3D.new()
	_stir_bar_bg.size = Vector3(BAR_WIDTH, 0.012, 0.012)
	_stir_bar_bg.position = Vector3(0, 0.22, 0.15)
	var sbg := StandardMaterial3D.new()
	sbg.albedo_color = Color(0.2, 0.2, 0.2)
	_stir_bar_bg.material = sbg
	_stir_bar_bg.visible = false
	add_child(_stir_bar_bg)

	_stir_bar_fill = CSGBox3D.new()
	_stir_bar_fill.size = Vector3(0.001, 0.012, 0.013)
	_stir_bar_fill.position = Vector3(-BAR_WIDTH / 2.0, 0.22, 0.15)
	var sbf := StandardMaterial3D.new()
	sbf.albedo_color = Color(0.25, 0.15, 0.08)
	_stir_bar_fill.material = sbf
	_stir_bar_fill.visible = false
	add_child(_stir_bar_fill)

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
				(held as Kettle).use_water(Kettle.AEROPRESS_COST)
				jug_level = 0.0
				_update_jug_visual()
				state = State.NEEDS_CUT
				_update_label()
		State.NEEDS_CUT:
			_player_ref = player
			_stir_game_active = true
			_cut_progress = 0.0
			_cut_line.visible = true
			player.enter_mini_game(_cam_point.global_transform)
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
			_stir_bar_bg.visible = true
			_stir_bar_fill.visible = true
			_update_label()
			_player_ref = player
			_stir_game_active = true
			player.enter_mini_game(_cam_point.global_transform)
			SoundManager.play_loop("sauce_prep_loop")
			state = State.STIRRING
			_update_label()
		State.STIRRING:
			SoundManager.stop_loop("sauce_prep_loop")
			_stir_bar_bg.visible = false
			_stir_bar_fill.visible = false
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
			_stir_bar_bg.visible = true
			_stir_bar_fill.visible = true
			player.enter_mini_game(_cam_point.global_transform)
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
	StationUtils.place_at_slot(item, _bottle_slot.global_position)
	_update_label()
	return true

func _fill_bottle() -> void:
	if not _placed_bottle or _placed_bottle.is_filled():
		return
	_placed_bottle.fill_with(DrinkData.SauceType.MOCHA)
	jug_level -= BOTTLE_FILL_COST
	_update_jug_visual()
	SoundManager.play("sauce_batch_done")
	state = State.JUG_READY
	_update_label()

func _exit_cam() -> void:
	_stir_game_active = false
	if _player_ref and is_instance_valid(_player_ref):
		_player_ref.exit_mini_game()
	_player_ref = null

func _input(event: InputEvent) -> void:
	if not _stir_game_active:
		return

	if event.is_action_pressed("interact"):
		if not StationUtils.is_same_frame(_activate_frame):
			match state:
				State.CUTTING:
					_exit_cam()
					_cut_line.visible = false
					state = State.NEEDS_CUT
					_update_label()
				State.STIRRING:
					SoundManager.stop_loop("sauce_prep_loop")
					_stir_bar_bg.visible = false
					_stir_bar_fill.visible = false
					_exit_cam()
					state = State.NEEDS_STIR
					_update_label()
		return

	if state == State.CUTTING:
		if event is InputEventMouseMotion:
			var mx := absf(event.relative.x)
			if mx > 5.0:
				_cut_progress += mx * 0.005
				_cut_line.size.x = minf(_cut_progress * 0.08, 0.08)
				_cut_line.position.x = 0.04 + _cut_line.size.x * 0.5
				if _cut_progress >= 1.0:
					_cut_line.visible = false
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
			_prev_angle = angle
			_has_prev = true
			_update_stir_bar()
			if _stir_progress >= STIR_TARGET:
				SoundManager.stop_loop("sauce_prep_loop")
				SoundManager.play("sauce_batch_done")
				_stir_bar_bg.visible = false
				_stir_bar_fill.visible = false
				_exit_cam()
				jug_level = JUG_CAPACITY
				_update_jug_visual()
				_bag_visual.visible = true
				state = State.JUG_READY
				_update_label()

func _update_stir_bar() -> void:
	if not _stir_bar_fill:
		return
	var ratio := clampf(_stir_progress / STIR_TARGET, 0.0, 1.0)
	var w := BAR_WIDTH * ratio
	_stir_bar_fill.size.x = maxf(w, 0.001)
	_stir_bar_fill.position.x = -BAR_WIDTH / 2.0 + w / 2.0

func _update_jug_visual() -> void:
	if not _jug_fill:
		return
	if jug_level <= 0.01:
		_jug_fill.visible = false
		return
	_jug_fill.visible = true
	var ratio := clampf(jug_level / JUG_CAPACITY, 0.0, 1.0)
	var h := 0.12 * ratio
	_jug_fill.height = maxf(h, 0.002)
	_jug_fill.position.y = 0.06 + h * 0.5

func _process(_delta: float) -> void:
	if _placed_bottle and StationUtils.is_item_removed(_placed_bottle, _bottle_slot.global_position):
		_placed_bottle = null
		_update_label()

func _update_label() -> void:
	if not _status_label:
		return
	var jug_str := ""
	if jug_level > 0.01:
		jug_str = " (jug: %.0f%%)" % (jug_level / JUG_CAPACITY * 100)
	match state:
		State.IDLE:
			_status_label.text = "Mocha Prep\n[E] Start batch"
		State.NEEDS_WATER:
			_status_label.text = "Hold filled kettle\n[E] Add hot water"
		State.NEEDS_CUT:
			_status_label.text = "[E] Cut open powder bag"
		State.CUTTING:
			_status_label.text = "Slash mouse across bag!"
		State.NEEDS_DUMP:
			_status_label.text = "[E] Dump powder + stir"
		State.NEEDS_STIR:
			_status_label.text = "[E] Stir with whisk"
		State.STIRRING:
			_status_label.text = "Stir! Move mouse in circles\n%.0f%%" % (clampf(_stir_progress / STIR_TARGET, 0, 1) * 100)
		State.JUG_READY:
			if _placed_bottle and _placed_bottle.is_empty() and jug_level >= BOTTLE_FILL_COST:
				_status_label.text = "Mocha ready%s\n[E] Fill bottle" % jug_str
			elif _placed_bottle and _placed_bottle.is_filled():
				_status_label.text = "Bottle full!%s\n[E] Pick up" % jug_str
			else:
				_status_label.text = "Mocha ready%s\nPlace empty bottle" % jug_str
		State.FILLING_BOTTLE:
			_status_label.text = "Filling bottle..."
