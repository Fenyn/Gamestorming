class_name MilkJug
extends RigidBody3D

const CARTON_SCENE := preload("res://assets/models/kenney/carton.glb")

func _ready() -> void:
	add_to_group("carriable")
	add_to_group("milk_jug")
	freeze = true

	# Kenney carton: 0.236 m tall at import scale, fitted to the 0.16 m jug collider.
	var carton: Node3D = CARTON_SCENE.instantiate()
	carton.scale = Vector3.ONE * 0.68
	carton.position = Vector3(0, -0.08, 0)
	add_child(carton)

	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.04
	shape.height = 0.16
	col.shape = shape
	add_child(col)
