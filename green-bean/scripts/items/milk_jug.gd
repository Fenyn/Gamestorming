class_name MilkJug
extends RigidBody3D

func _ready() -> void:
	add_to_group("carriable")
	add_to_group("milk_jug")
	freeze = true

	var body := CSGCylinder3D.new()
	body.radius = 0.04
	body.height = 0.16
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.92, 0.95)
	body.material = mat
	add_child(body)

	var handle := CSGBox3D.new()
	handle.size = Vector3(0.01, 0.08, 0.02)
	handle.position = Vector3(0.045, 0.02, 0)
	var h_mat := StandardMaterial3D.new()
	h_mat.albedo_color = Color(0.9, 0.9, 0.93)
	handle.material = h_mat
	add_child(handle)

	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.04
	shape.height = 0.16
	col.shape = shape
	add_child(col)
