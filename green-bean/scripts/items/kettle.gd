class_name Kettle
extends RigidBody3D

var has_water := false

func _ready() -> void:
	add_to_group("carriable")
	add_to_group("kettle")
	freeze = true

	var body := CSGCylinder3D.new()
	body.radius = 0.035
	body.height = 0.12
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.3, 0.32)
	body.material = mat
	add_child(body)

	var spout := CSGBox3D.new()
	spout.size = Vector3(0.01, 0.01, 0.06)
	spout.position = Vector3(0.035, 0.04, -0.03)
	var spout_mat := StandardMaterial3D.new()
	spout_mat.albedo_color = Color(0.3, 0.3, 0.32)
	spout.material = spout_mat
	add_child(spout)

	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.035
	shape.height = 0.12
	col.shape = shape
	add_child(col)

func fill() -> void:
	has_water = true

func empty() -> void:
	has_water = false
