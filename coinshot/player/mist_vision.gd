class_name MistVision
extends MeshInstance3D

const COLOR_BASE := Color(0.4, 0.7, 1.0, 0.55)
const COLOR_ACTIVE := Color(0.55, 0.85, 1.0, 1.0)
const MASS_REF := 50.0
const MASS_BRIGHT_GAIN := 0.6
const DIST_FALLOFF := 60.0
const ACTIVE_SEGMENTS := 24
const ACTIVE_HALF_WIDTH := 0.04

var _imm: ImmediateMesh
var _allomancy: Allomancy
var _camera: Camera3D
var overlay_on: bool = true

func _ready() -> void:
	_imm = ImmediateMesh.new()
	mesh = _imm
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	top_level = true
	global_transform = Transform3D.IDENTITY
	material_override = preload("res://materials/mistline.tres")
	_camera = get_parent() as Camera3D
	var player_node := _camera.get_parent()
	_allomancy = player_node.get_node("Allomancy") as Allomancy

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("mist_vision_toggle"):
		overlay_on = not overlay_on
		if not overlay_on:
			_imm.clear_surfaces()
		visible = overlay_on

func _process(_delta: float) -> void:
	if not overlay_on:
		return
	_imm.clear_surfaces()
	if _allomancy == null or _camera == null:
		return
	var forward: Vector3 = -_camera.global_transform.basis.z
	var origin: Vector3 = _camera.global_position + forward * 0.05

	if _allomancy.nearby_anchors.is_empty():
		return

	var is_pushing := Input.is_action_pressed("push")
	var is_pulling := Input.is_action_pressed("pull")
	var active_targets: Array = []
	if _allomancy._is_locked:
		active_targets = _allomancy._locked_targets.filter(func(t): return is_instance_valid(t) and t is Node3D)

	_imm.surface_begin(Mesh.PRIMITIVE_LINES)
	for n in _allomancy.nearby_anchors:
		if n == null or not (n is Node3D):
			continue
		if n in active_targets:
			continue
		var pos: Vector3 = (n as Node3D).global_position
		var dist: float = origin.distance_to(pos)
		var dist_alpha: float = clampf(1.0 - (dist / DIST_FALLOFF), 0.1, 1.0)
		var mass_kg: float = Allomancy.get_anchor_mass(n)
		var mass_term: float = clampf(mass_kg / MASS_REF, 0.25, 4.0)
		var brightness: float = clampf(0.5 + MASS_BRIGHT_GAIN * log(mass_term + 1.0), 0.4, 1.4)

		var col := COLOR_BASE
		col.a = clampf(col.a * dist_alpha * brightness, 0.0, 1.0)

		_imm.surface_set_color(col)
		_imm.surface_add_vertex(origin)
		_imm.surface_set_color(col)
		_imm.surface_add_vertex(pos)
	_imm.surface_end()

	if not active_targets.is_empty():
		var active_origin := _camera.global_position + Vector3(0, -0.3, 0) + forward * 0.15
		var pulsing := is_pushing or is_pulling
		for t in active_targets:
			_draw_active_line(active_origin, (t as Node3D).global_position, is_pushing or not is_pulling, pulsing)

func _draw_active_line(origin: Vector3, target: Vector3, pushing: bool, pulsing: bool) -> void:
	var diff := target - origin
	var length := diff.length()
	if length < 0.01:
		return
	var dir := diff / length

	var cam_fwd := -_camera.global_transform.basis.z
	var perp1 := dir.cross(cam_fwd)
	if perp1.length_squared() < 0.001:
		perp1 = dir.cross(Vector3.UP)
	perp1 = perp1.normalized()
	var perp2 := dir.cross(perp1).normalized()

	var time := fmod(Time.get_ticks_msec() / 1000.0, 100.0)

	var perp3 := (perp1 + perp2).normalized()
	var perp4 := (perp1 - perp2).normalized()

	for axis in [perp1, perp2, perp3, perp4]:
		_imm.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for i in range(ACTIVE_SEGMENTS + 1):
			var t := float(i) / float(ACTIVE_SEGMENTS)
			var pos := origin + diff * t

			var w: float
			var col := COLOR_ACTIVE
			if pulsing:
				var phase: float
				if pushing:
					phase = t * 6.0 - time * 4.0
				else:
					phase = t * 6.0 + time * 4.0
				var pulse := (sin(phase) + 1.0) * 0.5
				w = ACTIVE_HALF_WIDTH * (0.5 + pulse * 0.5)
				col.a = 0.4 + pulse * 0.6
			else:
				w = ACTIVE_HALF_WIDTH
				col.a = 0.7

			_imm.surface_set_color(col)
			_imm.surface_add_vertex(pos + axis * w)
			_imm.surface_set_color(col)
			_imm.surface_add_vertex(pos - axis * w)
		_imm.surface_end()
