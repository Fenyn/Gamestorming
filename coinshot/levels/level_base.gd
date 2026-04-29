class_name LevelBase
extends Node3D

signal level_completed

var level_name: String = ""
var spawn_point: Vector3 = Vector3(0, 1.2, 0)

const COL_STONE := Color(0.35, 0.33, 0.30)
const COL_STONE_DARK := Color(0.28, 0.26, 0.24)
const COL_METAL := Color(0.62, 0.62, 0.66)
const COL_METAL_MOVING := Color(0.45, 0.68, 0.55)
const COL_METAL_FALLING := Color(0.72, 0.48, 0.35)
const COL_NOOK := Color(0.55, 0.42, 0.28)
const COL_OVERHANG := Color(0.30, 0.28, 0.26)
const COL_GOAL := Color(0.70, 0.60, 0.25)

func build() -> void:
	pass

# ── Builder helpers ──

func _place_platform(pos: Vector3, size: Vector3) -> void:
	var sb := StaticBody3D.new()
	sb.name = "Platform"
	sb.global_position = pos
	add_child(sb)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _mat(COL_STONE, 0.0, 0.9)
	sb.add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	sb.add_child(col)

func _place_wall(pos: Vector3, size: Vector3) -> void:
	var sb := StaticBody3D.new()
	sb.name = "Wall"
	sb.global_position = pos
	add_child(sb)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _mat(COL_STONE_DARK, 0.0, 0.95)
	sb.add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	sb.add_child(col)

func _place_overhang(pos: Vector3, size: Vector3) -> void:
	var sb := StaticBody3D.new()
	sb.name = "Overhang"
	sb.global_position = pos
	add_child(sb)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _mat(COL_OVERHANG, 0.0, 0.95)
	sb.add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	sb.add_child(col)

func _place_girder(pos: Vector3, size: Vector3, mass_kg: float) -> void:
	var holder := StaticBody3D.new()
	holder.name = "Girder"
	holder.global_position = pos
	add_child(holder)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _mat(COL_METAL, 0.8, 0.35)
	holder.add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	holder.add_child(col)
	var anchor := MetalAnchor.new()
	anchor.mass_kg = mass_kg
	anchor.is_anchored = true
	holder.add_child(anchor)

func _place_nook(pos: Vector3, size: Vector3) -> void:
	var sb := StaticBody3D.new()
	sb.name = "Nook"
	sb.global_position = pos
	add_child(sb)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _mat(COL_NOOK, 0.15, 0.8)
	sb.add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	sb.add_child(col)

func _place_sign(pos: Vector3, text: String, font_sz: int = 24) -> void:
	var lbl := Label3D.new()
	lbl.text = text
	lbl.global_position = pos
	lbl.font_size = font_sz
	lbl.modulate = Color(1, 1, 1, 1)
	lbl.outline_size = 8
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	add_child(lbl)

func _place_goal(pos: Vector3, size: Vector3) -> void:
	var sb := StaticBody3D.new()
	sb.name = "GoalPlatform"
	sb.global_position = pos
	add_child(sb)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _mat(COL_GOAL, 0.0, 0.9)
	sb.add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	sb.add_child(col)

	var area := Area3D.new()
	area.global_position = pos + Vector3(0, 2, 0)
	add_child(area)
	var acol := CollisionShape3D.new()
	var ashape := BoxShape3D.new()
	ashape.size = Vector3(size.x, 4.0, size.z)
	acol.shape = ashape
	area.add_child(acol)
	area.body_entered.connect(_on_goal_entered)

func _place_moving_anchor(pos: Vector3, size: Vector3, mass_kg: float,
		end_offset: Vector3, travel_time: float = 3.0) -> void:
	var ma := MovingAnchor.new()
	ma.global_position = pos
	ma.end_offset = end_offset
	ma.travel_time = travel_time
	ma.mass_kg = mass_kg
	add_child(ma)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _mat(COL_METAL_MOVING, 0.8, 0.35)
	ma.add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	ma.add_child(col)

func _place_falling_anchor(pos: Vector3, size: Vector3, mass_kg: float,
		fall_delay: float = 1.5) -> void:
	var fa := FallingAnchor.new()
	fa.global_position = pos
	fa.mass_kg = mass_kg
	fa.fall_delay = fall_delay
	add_child(fa)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _mat(COL_METAL_FALLING, 0.8, 0.35)
	fa.add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	fa.add_child(col)

func _place_box(pos: Vector3, size: Vector3, color: Color = COL_STONE_DARK) -> void:
	var sb := StaticBody3D.new()
	sb.name = "Block"
	sb.global_position = pos
	add_child(sb)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _mat(color, 0.0, 0.92)
	sb.add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	sb.add_child(col)

func _place_pyramid(pos: Vector3, base: float, height: float, color: Color = COL_STONE) -> void:
	var sb := StaticBody3D.new()
	sb.name = "Pyramid"
	sb.global_position = pos
	add_child(sb)
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.0
	cyl.bottom_radius = base * 0.5
	cyl.height = height
	cyl.radial_segments = 4
	mesh.mesh = cyl
	mesh.material_override = _mat(color, 0.15, 0.85)
	sb.add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = base * 0.35
	shape.height = height
	col.shape = shape
	sb.add_child(col)

func _mat(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	return m

func _build_boundary(center: Vector3, radius: float, height: float = 120.0) -> void:
	var sides := [
		Vector3(center.x, height * 0.5, center.z - radius),
		Vector3(center.x, height * 0.5, center.z + radius),
		Vector3(center.x - radius, height * 0.5, center.z),
		Vector3(center.x + radius, height * 0.5, center.z),
	]
	var sizes := [
		Vector3(radius * 2.0, height, 0.5),
		Vector3(radius * 2.0, height, 0.5),
		Vector3(0.5, height, radius * 2.0),
		Vector3(0.5, height, radius * 2.0),
	]
	for i in range(4):
		var sb := StaticBody3D.new()
		sb.name = "Boundary"
		sb.global_position = sides[i]
		add_child(sb)
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = sizes[i]
		col.shape = shape
		sb.add_child(col)

func _build_city_backdrop(center: Vector3, inner_r: float, outer_r: float,
		count: int, max_h: float = 20.0, spire_chance: float = 0.15) -> void:
	var bg := Color(0.30, 0.28, 0.26)
	var bg_dark := Color(0.25, 0.23, 0.21)
	var bg_spire := Color(0.33, 0.31, 0.35)
	for i in range(count):
		var angle := randf() * TAU
		var dist := inner_r + randf() * (outer_r - inner_r)
		var bx := center.x + cos(angle) * dist
		var bz := center.z + sin(angle) * dist

		var cluster := randi_range(1, 3)
		for j in range(cluster):
			var h := randf_range(3.0, max_h)
			var w := randf_range(2.5, 7.0)
			var d := randf_range(2.5, 7.0)
			var ox := randf_range(-2.0, 2.0)
			var oz := randf_range(-2.0, 2.0)
			var c := bg if randf() > 0.4 else bg_dark
			_place_box(Vector3(bx + ox, h * 0.5, bz + oz), Vector3(w, h, d), c)

		if randf() < spire_chance:
			var sh := randf_range(max_h * 0.8, max_h * 1.6)
			var sw := randf_range(1.0, 2.0)
			_place_box(Vector3(bx, sh * 0.5, bz), Vector3(sw, sh, sw), bg_spire)
			_place_pyramid(Vector3(bx, sh + 1.5, bz), sw * 1.3, 3.0, bg_spire)

func _on_goal_entered(body: Node3D) -> void:
	if body is Player:
		level_completed.emit()
