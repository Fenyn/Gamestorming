class_name Dripper
extends RigidBody3D

## Visual model lives in scenes/props/cone_dripper.tscn so it can be edited in
## the editor. Its GroundsFloor marker and metadata size the grounds bed.
const MODEL := preload("res://scenes/props/cone_dripper.tscn")
const DRY_COLOR := Color(0.55, 0.38, 0.22)
const WET_COLOR := Color(0.2, 0.12, 0.06)

var has_filter := true
var grounds: Grounds = null

## Underside of the base plate (local y). This rests on a ring or a saucer.
var base_y := -0.05
## Top of the grounds bed (local y). The pour-over grid is drawn here.
var grounds_top_y := 0.008
var _slurry: MeshInstance3D = null
var _slurry_mesh: CylinderMesh = null
var _slurry_floor := 0.008
var _slurry_max := 0.038
var _cone_slope := 0.5774
var _cone_r_at_floor := 0.012
var _floor_y := -0.022
var _grounds_bed: MeshInstance3D = null
var _grounds_mat: StandardMaterial3D = null
var _saturation := 0.0

func _ready() -> void:
	add_to_group("carriable")
	add_to_group("dripper")
	freeze = true

	var model: Node3D = MODEL.instantiate()
	model.name = "Model"
	add_child(model)
	var col := model.get_node_or_null("Collision") as CollisionShape3D
	if col:
		var xform := col.transform
		model.remove_child(col)
		col.owner = null
		add_child(col)
		col.transform = model.transform * xform
	else:
		col = CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = 0.0585
		shape.height = 0.1
		col.shape = shape
		add_child(col)
	base_y = float(model.get_meta("base_y", base_y))

	# Grounds bed: a cone-shaped layer in the bottom of the filter.
	var bed := CylinderMesh.new()
	bed.height = float(model.get_meta("grounds_height", 0.026))
	bed.bottom_radius = float(model.get_meta("grounds_bottom_radius", 0.012))
	bed.top_radius = float(model.get_meta("grounds_top_radius", 0.03))
	bed.radial_segments = 24
	bed.rings = 1
	_grounds_bed = MeshInstance3D.new()
	_grounds_bed.name = "Grounds"
	_grounds_bed.mesh = bed
	var floor_marker := model.get_node_or_null("GroundsFloor") as Node3D
	if floor_marker:
		_floor_y = floor_marker.position.y
	_grounds_bed.position.y = _floor_y + bed.height * 0.5
	grounds_top_y = _floor_y + bed.height
	_grounds_mat = StandardMaterial3D.new()
	_grounds_mat.albedo_color = DRY_COLOR
	_grounds_mat.roughness = 1.0
	_grounds_bed.material_override = _grounds_mat
	_grounds_bed.visible = false
	add_child(_grounds_bed)

	# Water standing on the grounds while pouring and draining. It widens with
	# the cone as it rises.
	_cone_slope = float(model.get_meta("cone_slope", _cone_slope))
	_cone_r_at_floor = float(model.get_meta("cone_radius_at_floor", _cone_r_at_floor))
	_slurry_floor = grounds_top_y
	_slurry_max = float(model.get_meta("slurry_max_y", _slurry_max))
	_slurry_mesh = CylinderMesh.new()
	_slurry_mesh.radial_segments = 24
	_slurry_mesh.rings = 1
	_slurry = MeshInstance3D.new()
	_slurry.name = "Slurry"
	_slurry.mesh = _slurry_mesh
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.32, 0.19, 0.08, 0.85)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = 0.15
	_slurry.material_override = water
	_slurry.visible = false
	add_child(_slurry)

func has_grounds() -> bool:
	return grounds != null

func add_grounds(g: Grounds) -> void:
	grounds = g
	_saturation = 0.0
	_update_bed()
	if _grounds_bed:
		Fx.pop(_grounds_bed, 1.25, 0.25)

## 0 = dry grounds, 1 = fully wet. The bed darkens as water reaches it.
func set_saturation(ratio: float) -> void:
	_saturation = clampf(ratio, 0.0, 1.0)
	_update_bed()

func _update_bed() -> void:
	if not _grounds_bed:
		return
	_grounds_bed.visible = grounds != null
	_grounds_mat.albedo_color = DRY_COLOR.lerp(WET_COLOR, _saturation)
	_grounds_mat.roughness = lerpf(1.0, 0.45, _saturation)

## How much water stands on the grounds, 0 = none, 1 = up near the rim.
func set_water_level(ratio: float) -> void:
	if not _slurry:
		return
	ratio = clampf(ratio, 0.0, 1.0)
	if ratio < 0.02 or grounds == null:
		_slurry.visible = false
		return
	var top := lerpf(_slurry_floor, _slurry_max, ratio)
	var h := top - _slurry_floor + 0.002
	_slurry_mesh.height = h
	_slurry_mesh.bottom_radius = _radius_at(_slurry_floor - 0.002)
	_slurry_mesh.top_radius = _radius_at(top)
	_slurry.position.y = _slurry_floor - 0.002 + h * 0.5
	_slurry.visible = true

func _radius_at(y: float) -> float:
	return _cone_r_at_floor + (y - _floor_y) * _cone_slope

func reset_device() -> void:
	has_filter = true
	grounds = null
	_saturation = 0.0
	_update_bed()
	set_water_level(0.0)
