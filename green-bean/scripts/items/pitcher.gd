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

var _milk_visual: CSGCylinder3D = null
var _milk_mat: ShaderMaterial = null

func _ready() -> void:
	add_to_group("carriable")
	add_to_group("pitcher")
	freeze = true

	# Steel pitcher, hollowed so the milk inside is visible.
	var body := CSGCylinder3D.new()
	body.radius = 0.04
	body.height = 0.12
	body.sides = 16
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.72, 0.72, 0.74)
	mat.metallic = 0.7
	mat.roughness = 0.3
	body.material = mat
	add_child(body)
	var hollow := CSGCylinder3D.new()
	hollow.operation = CSGShape3D.OPERATION_SUBTRACTION
	hollow.radius = 0.036
	hollow.height = 0.112
	hollow.position.y = 0.006
	hollow.sides = 16
	body.add_child(hollow)

	# Milk: bottom sits on the inner floor (y = -0.05).
	_milk_visual = CSGCylinder3D.new()
	_milk_visual.radius = 0.035
	_milk_visual.height = MILK_HEIGHT
	_milk_visual.position.y = -0.05 + MILK_HEIGHT * 0.5
	_milk_visual.sides = 16
	_milk_mat = ShaderMaterial.new()
	_milk_mat.shader = LIQUID_SHADER
	_milk_mat.set_shader_parameter("liquid_color", MILK_COLOR)
	_milk_mat.set_shader_parameter("foam_color", Color(1.0, 0.99, 0.96))
	_milk_mat.set_shader_parameter("half_height", MILK_HEIGHT * 0.5)
	_milk_visual.material = _milk_mat
	_milk_visual.visible = has_milk
	add_child(_milk_visual)

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
	# Changing a CSG size rebuilds its mesh, so skip tiny changes.
	if absf(height - _milk_visual.height) < 0.0005:
		return
	_milk_visual.height = height
	_milk_visual.position.y = -0.05 + height * 0.5
	_milk_mat.set_shader_parameter("half_height", height * 0.5)

func set_steamed(quality: float) -> void:
	is_steamed = true
	steam_quality = quality

func reset_pitcher() -> void:
	has_milk = false
	is_steamed = false
	steam_quality = 0.0
	foam_level = 0.0
	update_milk_visual(0.0, 0.0, false)
