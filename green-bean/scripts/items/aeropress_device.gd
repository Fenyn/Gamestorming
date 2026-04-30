class_name AeropressDevice
extends RigidBody3D

var grounds: Grounds = null
var has_water := false
var is_stirred := false

func _ready() -> void:
	add_to_group("carriable")
	add_to_group("aeropress_device")
	freeze = true

	var body := CSGCylinder3D.new()
	body.radius = 0.035
	body.height = 0.15
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.4, 0.42)
	body.material = mat
	add_child(body)

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

func reset_device() -> void:
	grounds = null
	has_water = false
	is_stirred = false
