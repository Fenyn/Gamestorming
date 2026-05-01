class_name AeropressDevice
extends RigidBody3D

var grounds: Grounds = null
var has_water := false
var is_stirred := false
var _plunger: CSGCylinder3D = null
var _plunger_top := 0.075
var _plunger_bottom := -0.03
var _liquid: CSGCylinder3D = null

func _ready() -> void:
	add_to_group("carriable")
	add_to_group("aeropress_device")
	freeze = true

	var body := CSGCylinder3D.new()
	body.radius = 0.035
	body.height = 0.15
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.4, 0.42, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	body.material = mat
	add_child(body)

	_plunger = CSGCylinder3D.new()
	_plunger.radius = 0.028
	_plunger.height = 0.08
	_plunger.position.y = _plunger_top
	var plunger_mat := StandardMaterial3D.new()
	plunger_mat.albedo_color = Color(0.3, 0.3, 0.32)
	_plunger.material = plunger_mat
	_plunger.visible = false
	add_child(_plunger)

	_liquid = CSGCylinder3D.new()
	_liquid.radius = 0.030
	_liquid.height = 0.001
	_liquid.position.y = -0.07
	var liquid_mat := StandardMaterial3D.new()
	liquid_mat.albedo_color = Color(0.25, 0.15, 0.05)
	_liquid.material = liquid_mat
	_liquid.visible = false
	add_child(_liquid)

	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.035
	shape.height = 0.15
	col.shape = shape
	add_child(col)

func has_grounds() -> bool:
	return grounds != null

func add_grounds(g: Grounds) -> void:
	grounds = g

func set_liquid_level(ratio: float) -> void:
	if not _liquid:
		return
	ratio = clampf(ratio, 0.0, 1.0)
	if ratio > 0.01:
		_liquid.visible = true
		var max_height := 0.12
		_liquid.height = max_height * ratio
		_liquid.position.y = -0.07 + (_liquid.height / 2.0)
	else:
		_liquid.visible = false

func hide_liquid() -> void:
	if _liquid:
		_liquid.visible = false

func show_plunger() -> void:
	if _plunger:
		_plunger.visible = true
		_plunger.position.y = _plunger_top

func hide_plunger() -> void:
	if _plunger:
		_plunger.visible = false
		_plunger.position.y = _plunger_top

func set_plunger_progress(ratio: float) -> void:
	if _plunger:
		_plunger.position.y = lerpf(_plunger_top, _plunger_bottom, clampf(ratio, 0.0, 1.0))

func reset_device() -> void:
	grounds = null
	has_water = false
	is_stirred = false
	hide_plunger()
	hide_liquid()
