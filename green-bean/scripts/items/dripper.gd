class_name Dripper
extends RigidBody3D

## Visual model lives in scenes/props/cone_dripper.tscn so it can be edited in
## the editor. Its GroundsFloor marker and metadata size the grounds bed.
const MODEL := preload("res://scenes/props/cone_dripper.tscn")
const DRY_COLOR := Color(0.55, 0.38, 0.22)
const WET_COLOR := Color(0.2, 0.12, 0.06)

var has_filter := true
var grounds: Grounds = null

## Where on the outside of the cone a stand's ring grips it (local y).
var ring_contact_y := -0.016
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
		shape.radius = 0.058
		shape.height = 0.08
		col.shape = shape
		add_child(col)
	ring_contact_y = float(model.get_meta("ring_contact_y", ring_contact_y))

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
	var floor_y := -0.022
	var floor_marker := model.get_node_or_null("GroundsFloor") as Node3D
	if floor_marker:
		floor_y = floor_marker.position.y
	_grounds_bed.position.y = floor_y + bed.height * 0.5
	_grounds_mat = StandardMaterial3D.new()
	_grounds_mat.albedo_color = DRY_COLOR
	_grounds_mat.roughness = 1.0
	_grounds_bed.material_override = _grounds_mat
	_grounds_bed.visible = false
	add_child(_grounds_bed)

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

func reset_device() -> void:
	has_filter = true
	grounds = null
	_saturation = 0.0
	_update_bed()
