class_name Pitcher
extends RigidBody3D

var has_milk := false
var is_steamed := false
var steam_quality := 0.0
var foam_level := 0.0

func _ready() -> void:
	add_to_group("carriable")
	add_to_group("pitcher")
	freeze = true

	var body := CSGCylinder3D.new()
	body.radius = 0.04
	body.height = 0.12
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.72, 0.72, 0.74)
	body.material = mat
	add_child(body)

	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.04
	shape.height = 0.12
	col.shape = shape
	add_child(col)

func fill_milk() -> void:
	has_milk = true

func set_steamed(quality: float) -> void:
	is_steamed = true
	steam_quality = quality

func reset_pitcher() -> void:
	has_milk = false
	is_steamed = false
	steam_quality = 0.0
	foam_level = 0.0
