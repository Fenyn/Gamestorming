class_name Pitcher
extends RigidBody3D

const LIQUID_SHADER := preload("res://assets/shaders/liquid.gdshader")
const MILK_COLOR := Color(0.96, 0.95, 0.91)
const HOT_MILK_COLOR := Color(0.97, 0.93, 0.85)
const SCALDED_COLOR := Color(0.82, 0.68, 0.45)
const MILK_HEIGHT := 0.06

var has_milk := false:
	set(value):
		has_milk = value
		if _milk_visual:
			_milk_visual.visible = value
var is_steamed := false
var steam_quality := 0.0
var foam_level := 0.0

const MODEL := preload("res://scenes/props/milk_pitcher.tscn")

var _milk_visual: MeshInstance3D = null
var _milk_mesh: CylinderMesh = null
var _milk_mat: ShaderMaterial = null
var _milk_floor := -0.054
## Inside wall of the model as (radius, y), low to high.
var _inner_profile := PackedVector2Array([Vector2(0.035, -0.054), Vector2(0.032, 0.06)])

func _ready() -> void:
	add_to_group("carriable")
	add_to_group("pitcher")
	freeze = true

	# Visual model lives in scenes/props/milk_pitcher.tscn so it can be edited
	# in the editor. Its MilkFloor marker and inner_profile metadata place the milk.
	var model: Node3D = MODEL.instantiate()
	model.name = "Model"
	add_child(model)
	var floor_marker := model.get_node_or_null("MilkFloor") as Node3D
	if floor_marker:
		_milk_floor = floor_marker.position.y
	if model.has_meta("inner_profile"):
		_inner_profile = model.get_meta("inner_profile")

	_milk_mesh = CylinderMesh.new()
	_milk_mesh.radial_segments = 20
	_milk_mesh.rings = 1
	_milk_visual = MeshInstance3D.new()
	_milk_visual.name = "Milk"
	_milk_visual.mesh = _milk_mesh
	_milk_mat = ShaderMaterial.new()
	_milk_mat.shader = LIQUID_SHADER
	_milk_mat.set_shader_parameter("liquid_color", MILK_COLOR)
	_milk_mat.set_shader_parameter("foam_color", Color(1.0, 0.99, 0.96))
	_milk_visual.material_override = _milk_mat
	_milk_visual.visible = has_milk
	add_child(_milk_visual)
	_set_milk_height(MILK_HEIGHT)

	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.04
	shape.height = 0.12
	col.shape = shape
	add_child(col)

func fill_milk() -> void:
	has_milk = true
	update_milk_visual(0.0, 0.0, false)
	if _milk_visual:
		Fx.pop(_milk_visual, 0.3, 0.25)

## heat_ratio 0 = fridge cold, 1 = target temperature. Foam raises the milk level.
func update_milk_visual(heat_ratio: float, foam: float, scalded: bool) -> void:
	if _milk_mat == null:
		return
	var color := MILK_COLOR.lerp(HOT_MILK_COLOR, clampf(heat_ratio, 0.0, 1.0))
	if scalded:
		color = SCALDED_COLOR
	_milk_mat.set_shader_parameter("liquid_color", color)
	_milk_mat.set_shader_parameter("foam_fraction", clampf(foam * 0.7, 0.0, 0.7))
	_milk_mat.set_shader_parameter("foam_color", Color(0.9, 0.82, 0.66) if scalded else Color(1.0, 0.99, 0.96))
	var height := MILK_HEIGHT * (1.0 + clampf(foam, 0.0, 1.0) * 0.6)
	# Rebuilding the mesh every frame is wasteful, so skip tiny changes.
	if absf(height - _milk_mesh.height) < 0.0005:
		return
	_set_milk_height(height)

func _set_milk_height(height: float) -> void:
	_milk_mesh.height = height
	# Follow the wall so the milk never pokes through where the pitcher narrows.
	_milk_mesh.bottom_radius = _inner_radius(_milk_floor + 0.002) - 0.001
	_milk_mesh.top_radius = _inner_radius(_milk_floor + height) - 0.001
	_milk_visual.position.y = _milk_floor + height * 0.5
	_milk_mat.set_shader_parameter("half_height", height * 0.5)

func _inner_radius(y: float) -> float:
	var pts := _inner_profile
	if y <= pts[0].y:
		return pts[0].x
	for i in range(1, pts.size()):
		if y <= pts[i].y:
			var t := (y - pts[i - 1].y) / maxf(pts[i].y - pts[i - 1].y, 0.0001)
			return lerpf(pts[i - 1].x, pts[i].x, t)
	return pts[pts.size() - 1].x

func set_steamed(quality: float) -> void:
	is_steamed = true
	steam_quality = quality

func reset_pitcher() -> void:
	has_milk = false
	is_steamed = false
	steam_quality = 0.0
	foam_level = 0.0
	update_milk_visual(0.0, 0.0, false)
