class_name Dripper
extends RigidBody3D

var has_filter := true
var grounds: Grounds = null

func _ready() -> void:
	add_to_group("carriable")
	add_to_group("dripper")
	freeze = true

	var body := CSGCylinder3D.new()
	body.radius = 0.05
	body.height = 0.08
	body.cone = true
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.5, 0.4)
	body.material = mat
	add_child(body)

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

func reset_device() -> void:
	has_filter = true
	grounds = null
