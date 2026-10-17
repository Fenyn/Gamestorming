class_name ShotPress
extends RigidBody3D

## Visual model lives in scenes/props/shot_press.tscn so it can be edited in the
## editor. Its markers place the coffee, the plunger travel and how it sits on
## a cup.
const MODEL := preload("res://scenes/props/shot_press.tscn")
const LIQUID_COLOR := Color(0.25, 0.15, 0.05)

var grounds: Grounds = null
var has_water := false
var is_stirred := false

## Flange underside in local space: this point sits on the cup rim.
var rim_rest_y := -0.05
var _plunger: Node3D = null
var _plunger_top := Vector3(0, 0.0445, 0)
var _plunger_bottom := Vector3(0, -0.046, 0)
var _liquid: MeshInstance3D = null
var _liquid_mesh: CylinderMesh = null
var _liquid_floor := -0.047
var _liquid_max := 0.082

func _ready() -> void:
	add_to_group("carriable")
	add_to_group("shot_press")
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
		shape.radius = 0.034
		shape.height = 0.121
		col.shape = shape
		add_child(col)

	var rim := model.get_node_or_null("RimRest") as Node3D
	if rim:
		rim_rest_y = rim.position.y
	_plunger = model.get_node_or_null("Plunger") as Node3D
	var top := model.get_node_or_null("PlungerTop") as Node3D
	if top:
		_plunger_top = top.position
	var bottom := model.get_node_or_null("PlungerBottom") as Node3D
	if bottom:
		_plunger_bottom = bottom.position
	var floor_marker := model.get_node_or_null("LiquidFloor") as Node3D
	if floor_marker:
		_liquid_floor = floor_marker.position.y
	_liquid_max = float(model.get_meta("liquid_max_height", 0.082))

	_liquid_mesh = CylinderMesh.new()
	var r := float(model.get_meta("liquid_radius", 0.0295))
	_liquid_mesh.top_radius = r
	_liquid_mesh.bottom_radius = r
	_liquid_mesh.radial_segments = 20
	_liquid_mesh.rings = 1
	_liquid_mesh.height = 0.001
	_liquid = MeshInstance3D.new()
	_liquid.name = "Coffee"
	_liquid.mesh = _liquid_mesh
	var liquid_mat := StandardMaterial3D.new()
	liquid_mat.albedo_color = LIQUID_COLOR
	liquid_mat.roughness = 0.3
	_liquid.material_override = liquid_mat
	_liquid.visible = false
	add_child(_liquid)
	hide_plunger()

func has_grounds() -> bool:
	return grounds != null

func add_grounds(g: Grounds) -> void:
	grounds = g

func set_liquid_level(ratio: float) -> void:
	if not _liquid:
		return
	ratio = clampf(ratio, 0.0, 1.0)
	if ratio > 0.01:
		_liquid.visible = true
		_liquid_mesh.height = _liquid_max * ratio
		_liquid.position.y = _liquid_floor + _liquid_mesh.height * 0.5
	else:
		_liquid.visible = false

func hide_liquid() -> void:
	if _liquid:
		_liquid.visible = false

func show_plunger() -> void:
	if _plunger:
		_plunger.visible = true
		_plunger.position = _plunger_top

func hide_plunger() -> void:
	if _plunger:
		_plunger.visible = false
		_plunger.position = _plunger_top

## Pressing pushes the plunger down and the coffee level with it.
func set_plunger_progress(ratio: float) -> void:
	ratio = clampf(ratio, 0.0, 1.0)
	if _plunger:
		_plunger.position = _plunger_top.lerp(_plunger_bottom, ratio)
	if _liquid and _liquid.visible and _plunger:
		var room := maxf(_plunger.position.y - _liquid_floor, 0.0)
		if room < _liquid_mesh.height:
			_liquid_mesh.height = maxf(room, 0.0005)
			_liquid.position.y = _liquid_floor + _liquid_mesh.height * 0.5

func reset_device() -> void:
	grounds = null
	has_water = false
	is_stirred = false
	hide_plunger()
	hide_liquid()
