class_name RacingLine
extends Node3D

const RIBBON_WIDTH: float = 1.0
const RIBBON_ALPHA: float = 0.6
const ARROW_DISTANCE: float = 8.0
const ARROW_MIN_SCALE: float = 0.3
const ARROW_MAX_SCALE: float = 2.5
const LOOKAHEAD_WINDOW: int = 30
const GREEN_THRESHOLD: float = 0.6
const YELLOW_THRESHOLD: float = 0.85

var points: Array[Vector3] = []
var speeds: Array[float] = []
var max_speed: float = 120.0
var ship: RigidBody3D
var current_line_index: int = 0

@onready var _ribbon_mesh: MeshInstance3D = %RibbonMesh
@onready var _arrow_mesh: MeshInstance3D = %ArrowMesh

var _ribbon_material: StandardMaterial3D
var _arrow_material: StandardMaterial3D


func _ready() -> void:
	_ribbon_material = StandardMaterial3D.new()
	_ribbon_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ribbon_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ribbon_material.vertex_color_use_as_albedo = true
	_ribbon_material.no_depth_test = false
	_ribbon_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ribbon_mesh.material_override = _ribbon_material

	_arrow_material = StandardMaterial3D.new()
	_arrow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_arrow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_arrow_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_arrow_mesh.material_override = _arrow_material


func build_ribbon() -> void:
	if points.size() < 2:
		return

	var im: ImmediateMesh = ImmediateMesh.new()
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)

	for i: int in range(points.size()):
		var color: Color = _speed_to_color(speeds[i] if i < speeds.size() else 0.0)
		color.a = RIBBON_ALPHA

		var tangent: Vector3 = Vector3.FORWARD
		if i < points.size() - 1:
			tangent = (points[i + 1] - points[i]).normalized()
		elif i > 0:
			tangent = (points[i] - points[i - 1]).normalized()

		var up: Vector3 = Vector3.UP
		if absf(tangent.dot(up)) > 0.95:
			up = Vector3.RIGHT
		var right: Vector3 = tangent.cross(up).normalized() * RIBBON_WIDTH * 0.5

		im.surface_set_color(color)
		im.surface_add_vertex(points[i] + right)
		im.surface_set_color(color)
		im.surface_add_vertex(points[i] - right)

	im.surface_end()
	_ribbon_mesh.mesh = im


func _physics_process(_delta: float) -> void:
	if ship == null or points.size() < 2:
		_arrow_mesh.visible = false
		return

	_advance_line_index()
	_update_thrust_vector()


func _advance_line_index() -> void:
	var ship_pos: Vector3 = ship.global_position
	var best_dist: float = INF
	var best_idx: int = current_line_index

	var end: int = mini(current_line_index + LOOKAHEAD_WINDOW, points.size() - 1)
	for i: int in range(current_line_index, end + 1):
		var dist: float = ship_pos.distance_squared_to(points[i])
		if dist < best_dist:
			best_dist = dist
			best_idx = i

	current_line_index = best_idx


func _update_thrust_vector() -> void:
	var idx: int = mini(current_line_index + 2, points.size() - 2)
	var tangent: Vector3 = (points[idx + 1] - points[idx]).normalized()
	var desired_speed: float = speeds[idx] if idx < speeds.size() else 60.0
	var desired_vel: Vector3 = tangent * desired_speed

	var delta_v: Vector3 = desired_vel - ship.linear_velocity
	var magnitude: float = delta_v.length()

	if magnitude < 1.0:
		_arrow_mesh.visible = false
		return

	_arrow_mesh.visible = true

	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return

	var anchor: Vector3 = cam.global_position + (-cam.global_basis.z * ARROW_DISTANCE)
	_arrow_mesh.global_position = anchor

	var arrow_scale: float = clampf(magnitude / 30.0, ARROW_MIN_SCALE, ARROW_MAX_SCALE)
	_arrow_mesh.scale = Vector3.ONE * arrow_scale

	var dir: Vector3 = delta_v.normalized()
	if dir.length() > 0.5:
		_arrow_mesh.global_basis = Basis.looking_at(dir, Vector3.UP)

	var ratio: float = clampf(magnitude / 50.0, 0.0, 1.0)
	var color: Color
	if ratio < 0.3:
		color = Color.GREEN
	elif ratio < 0.7:
		color = Color.YELLOW
	else:
		color = Color.RED
	color.a = 0.7
	_arrow_material.albedo_color = color


func _speed_to_color(speed: float) -> Color:
	var ratio: float = speed / maxf(max_speed, 1.0)
	if ratio <= GREEN_THRESHOLD:
		return Color.GREEN
	elif ratio <= YELLOW_THRESHOLD:
		var t: float = (ratio - GREEN_THRESHOLD) / (YELLOW_THRESHOLD - GREEN_THRESHOLD)
		return Color.GREEN.lerp(Color.YELLOW, t)
	else:
		var t: float = (ratio - YELLOW_THRESHOLD) / (1.0 - YELLOW_THRESHOLD)
		return Color.YELLOW.lerp(Color.RED, clampf(t, 0.0, 1.0))


func reset() -> void:
	current_line_index = 0
