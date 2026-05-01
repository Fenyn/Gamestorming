class_name SauceBottle
extends RigidBody3D

const DRIZZLE_COST := 0.07
const MAX_FILL := 1.0

var sauce_type: int = -1
var fill_level := 0.0

var _body_mesh: CSGCylinder3D = null
var _fill_mesh: CSGCylinder3D = null
var _cap_mesh: CSGCylinder3D = null

func _ready() -> void:
	add_to_group("carriable")
	add_to_group("sauce_bottle")
	freeze = true

	_body_mesh = CSGCylinder3D.new()
	_body_mesh.radius = 0.025
	_body_mesh.height = 0.12
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.85, 0.85, 0.4)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_body_mesh.material = mat
	add_child(_body_mesh)

	_fill_mesh = CSGCylinder3D.new()
	_fill_mesh.radius = 0.022
	_fill_mesh.height = 0.001
	_fill_mesh.position.y = -0.05
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.4, 0.3, 0.2)
	_fill_mesh.material = fmat
	_fill_mesh.visible = false
	add_child(_fill_mesh)

	_cap_mesh = CSGCylinder3D.new()
	_cap_mesh.radius = 0.015
	_cap_mesh.height = 0.025
	_cap_mesh.position.y = 0.07
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color(0.3, 0.3, 0.3)
	_cap_mesh.material = cmat
	add_child(_cap_mesh)

	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.025
	shape.height = 0.12
	col.shape = shape
	add_child(col)

	_update_fill_visual()

func is_empty() -> bool:
	return fill_level <= 0.01

func is_filled() -> bool:
	return fill_level > 0.01

func has_sauce_type(type: DrinkData.SauceType) -> bool:
	return sauce_type == type and is_filled()

func use_drizzle() -> bool:
	if is_empty():
		return false
	fill_level = maxf(fill_level - DRIZZLE_COST, 0.0)
	_update_fill_visual()
	return true

func fill_with(type: DrinkData.SauceType) -> void:
	sauce_type = type
	fill_level = MAX_FILL
	_update_fill_visual()

func empty_out() -> void:
	sauce_type = -1
	fill_level = 0.0
	_update_fill_visual()

func _update_fill_visual() -> void:
	if not _fill_mesh:
		return
	if is_empty():
		_fill_mesh.visible = false
		if _cap_mesh:
			(_cap_mesh.material as StandardMaterial3D).albedo_color = Color(0.3, 0.3, 0.3)
		return
	_fill_mesh.visible = true
	var h := 0.10 * fill_level
	_fill_mesh.height = maxf(h, 0.002)
	_fill_mesh.position.y = -0.05 + h * 0.5
	var color := Color(0.4, 0.3, 0.2)
	if sauce_type >= 0:
		color = DrinkData.get_sauce_color(sauce_type as DrinkData.SauceType)
	(_fill_mesh.material as StandardMaterial3D).albedo_color = color
	if _cap_mesh:
		(_cap_mesh.material as StandardMaterial3D).albedo_color = color.darkened(0.3)

static func create_empty() -> SauceBottle:
	var b := SauceBottle.new()
	return b

static func create_filled(type: DrinkData.SauceType) -> SauceBottle:
	var b := SauceBottle.new()
	b.sauce_type = type
	b.fill_level = MAX_FILL
	return b
