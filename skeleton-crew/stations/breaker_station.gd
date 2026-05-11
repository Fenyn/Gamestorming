class_name BreakerStation
extends Station

@onready var _weapons_lever: Node3D = $BreakerPanel/WeaponsLever
@onready var _shields_lever: Node3D = $BreakerPanel/ShieldsLever
@onready var _engines_lever: Node3D = $BreakerPanel/EnginesLever

var _weapons_pips: int = 2
var _shields_pips: int = 2
var _engines_pips: int = 2
const TOTAL_PIPS: int = 6
const MAX_PIPS: int = 4
const LEVER_MIN_Y: float = 0.2
const LEVER_MAX_Y: float = 1.0

var _selected_system: int = 0


func _ready() -> void:
	super._ready()
	station_id = "breaker"
	station_type = InputContext.Mode.TERMINAL
	_update_levers()


func _process(_delta: float) -> void:
	if _occupant_id != multiplayer.get_unique_id():
		return

	if Input.is_action_just_pressed(&"move_forward"):
		_adjust_selected(1)
	elif Input.is_action_just_pressed(&"move_back"):
		_adjust_selected(-1)
	elif Input.is_action_just_pressed(&"move_left"):
		_selected_system = wrapi(_selected_system - 1, 0, 3)
	elif Input.is_action_just_pressed(&"move_right"):
		_selected_system = wrapi(_selected_system + 1, 0, 3)


func _adjust_selected(direction: int) -> void:
	var w: int = _weapons_pips
	var s: int = _shields_pips
	var e: int = _engines_pips

	match _selected_system:
		0: w = clampi(w + direction, 0, MAX_PIPS)
		1: s = clampi(s + direction, 0, MAX_PIPS)
		2: e = clampi(e + direction, 0, MAX_PIPS)

	var total: int = w + s + e
	if total > TOTAL_PIPS:
		var overflow: int = total - TOTAL_PIPS
		match _selected_system:
			0:
				var steal_s: int = mini(overflow, s)
				s -= steal_s
				overflow -= steal_s
				e -= overflow
			1:
				var steal_w: int = mini(overflow, w)
				w -= steal_w
				overflow -= steal_w
				e -= overflow
			2:
				var steal_w: int = mini(overflow, w)
				w -= steal_w
				overflow -= steal_w
				s -= overflow

	if w + s + e != TOTAL_PIPS:
		return

	_weapons_pips = w
	_shields_pips = s
	_engines_pips = e
	_update_levers()
	EventBus.power_changed.emit(w, s, e)


func _update_levers() -> void:
	_set_lever_position(_weapons_lever, _weapons_pips)
	_set_lever_position(_shields_lever, _shields_pips)
	_set_lever_position(_engines_lever, _engines_pips)
	_update_pips()


func _set_lever_position(lever: Node3D, pips: int) -> void:
	if not lever:
		return
	var t: float = float(pips) / float(MAX_PIPS)
	lever.position.y = lerpf(LEVER_MIN_Y, LEVER_MAX_Y, t)


func _update_pips() -> void:
	_set_pip_colors($BreakerPanel/WeaponsPips, _weapons_pips, _selected_system == 0)
	_set_pip_colors($BreakerPanel/ShieldsPips, _shields_pips, _selected_system == 1)
	_set_pip_colors($BreakerPanel/EnginesPips, _engines_pips, _selected_system == 2)


func _set_pip_colors(pip_container: Node3D, active_count: int, selected: bool) -> void:
	if not pip_container:
		return
	for i: int in pip_container.get_child_count():
		var pip: MeshInstance3D = pip_container.get_child(i) as MeshInstance3D
		if not pip:
			continue
		var mat: StandardMaterial3D = pip.material_override as StandardMaterial3D
		if not mat:
			mat = StandardMaterial3D.new()
			mat.emission_enabled = true
			pip.material_override = mat

		if i < active_count:
			mat.emission = Color(0.2, 0.9, 0.2) if not selected else Color(0.4, 1.0, 0.4)
			mat.emission_energy_multiplier = 2.0 if selected else 1.5
			mat.albedo_color = Color(0.1, 0.4, 0.1)
		else:
			mat.emission = Color(0.15, 0.15, 0.15)
			mat.emission_energy_multiplier = 0.3
			mat.albedo_color = Color(0.05, 0.05, 0.05)
