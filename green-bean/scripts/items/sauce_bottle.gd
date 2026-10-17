class_name SauceBottle
extends RigidBody3D

const DRIZZLE_COST := 0.07
const MAX_FILL := 1.0

var sauce_type: int = -1
var fill_level := 0.0

const MODEL := preload("res://scenes/props/squeeze_bottle.tscn")
const EMPTY_CAP := Color(0.3, 0.3, 0.3)

var _fill: MeshInstance3D = null
var _fill_mesh: CylinderMesh = null
var _fill_mat: StandardMaterial3D = null
var _cap_mat: StandardMaterial3D = null
var _fill_floor := -0.097
var _fill_max := 0.13

func _ready() -> void:
	add_to_group("carriable")
	add_to_group("sauce_bottle")
	freeze = true

	var model: Node3D = MODEL.instantiate()
	model.name = "Model"
	add_child(model)
	var col := model.get_node_or_null("Collision") as CollisionShape3D
	if col:
		model.remove_child(col)
		col.owner = null
		add_child(col)
	var floor_marker := model.get_node_or_null("FillFloor") as Node3D
	if floor_marker:
		_fill_floor = floor_marker.position.y
	_fill_max = float(model.get_meta("fill_max_height", _fill_max))

	_fill_mesh = CylinderMesh.new()
	_fill_mesh.top_radius = float(model.get_meta("fill_radius", 0.026))
	_fill_mesh.bottom_radius = _fill_mesh.top_radius
	_fill_mesh.radial_segments = 20
	_fill_mesh.rings = 1
	_fill_mat = StandardMaterial3D.new()
	_fill_mat.roughness = 0.3
	_fill = MeshInstance3D.new()
	_fill.name = "Sauce"
	_fill.mesh = _fill_mesh
	_fill.material_override = _fill_mat
	add_child(_fill)

	# Each bottle tints its own cap, so the shared model material stays grey.
	_cap_mat = StandardMaterial3D.new()
	_cap_mat.roughness = 0.5
	for part in model.get_node("Cap").get_children():
		(part as MeshInstance3D).material_override = _cap_mat

	_update_fill_visual()

func is_empty() -> bool:
	return fill_level <= 0.01

func is_filled() -> bool:
	return fill_level > 0.01

func has_sauce_type(type: DrinkData.SauceType) -> bool:
	return sauce_type == type and is_filled()

func use_drizzle() -> bool:
	if is_empty():
		return false
	fill_level = maxf(fill_level - DRIZZLE_COST, 0.0)
	_update_fill_visual()
	return true

func fill_with(type: DrinkData.SauceType) -> void:
	sauce_type = type
	fill_level = MAX_FILL
	_update_fill_visual()

func empty_out() -> void:
	sauce_type = -1
	fill_level = 0.0
	_update_fill_visual()

func _update_fill_visual() -> void:
	if not _fill:
		return
	if is_empty():
		_fill.visible = false
		_cap_mat.albedo_color = EMPTY_CAP
		return
	var color := Color(0.4, 0.3, 0.2)
	if sauce_type >= 0:
		color = DrinkData.get_sauce_color(sauce_type as DrinkData.SauceType)
	var h := maxf(_fill_max * fill_level, 0.002)
	_fill_mesh.height = h
	_fill.position.y = _fill_floor + h * 0.5
	_fill.visible = true
	_fill_mat.albedo_color = color
	_cap_mat.albedo_color = color.darkened(0.3)

## Shows a level without changing the bottle's contents, while it is being
## filled. _update_fill_visual() puts the real level back.
func preview_level(type: int, ratio: float) -> void:
	if not _fill:
		return
	var h := maxf(_fill_max * clampf(ratio, 0.0, 1.0), 0.002)
	_fill_mesh.height = h
	_fill.position.y = _fill_floor + h * 0.5
	_fill.visible = ratio > 0.01
	_fill_mat.albedo_color = DrinkData.get_sauce_color(type as DrinkData.SauceType)

static func create_empty() -> SauceBottle:
	var b := SauceBottle.new()
	return b

static func create_filled(type: DrinkData.SauceType) -> SauceBottle:
	var b := SauceBottle.new()
	b.sauce_type = type
	b.fill_level = MAX_FILL
	return b
