class_name Dripper
extends RigidBody3D

var has_filter := true
var grounds: Grounds = null
var _fill_visual: CSGCylinder3D = null

func _ready() -> void:
	add_to_group("carriable")
	add_to_group("dripper")
	freeze = true

	var body := CSGCylinder3D.new()
	body.radius = 0.05
	body.height = 0.08
	body.cone = true
	body.rotation_degrees = Vector3(180, 0, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.5, 0.4, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	body.material = mat
	add_child(body)

	_fill_visual = CSGCylinder3D.new()
	_fill_visual.radius = 0.035
	_fill_visual.height = 0.001
	_fill_visual.position.y = -0.01
	var fill_mat := StandardMaterial3D.new()
	fill_mat.albedo_color = Color(0.35, 0.22, 0.1)
	_fill_visual.material = fill_mat
	_fill_visual.visible = false
	add_child(_fill_visual)

	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.05
	shape.height = 0.08
	col.shape = shape
	add_child(col)

func has_grounds() -> bool:
	return grounds != null

func add_grounds(g: Grounds) -> void:
	grounds = g

func set_saturation(ratio: float) -> void:
	if not _fill_visual:
		return
	ratio = clampf(ratio, 0.0, 1.0)
	if ratio > 0.01:
		_fill_visual.visible = true
		_fill_visual.height = 0.05 * ratio
		_fill_visual.position.y = -0.01 + (_fill_visual.height / 2.0)
	else:
		_fill_visual.visible = false

func reset_device() -> void:
	has_filter = true
	grounds = null
	if _fill_visual:
		_fill_visual.visible = false
