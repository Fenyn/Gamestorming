class_name ShotPress
extends RigidBody3D

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
var _liquid_max := 0.09
## Liquid level (as a fraction of the FILL line) at which water reaches the rim.
var rim_ratio := 1.17
var _liquid_mat: StandardMaterial3D = null
## Grounds floating on top until stirred in; spun by the paddle.
var _crust: MeshInstance3D = null
var _crust_mat: StandardMaterial3D = null
static var _crust_texture: NoiseTexture2D = null

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
	_liquid_max = float(model.get_meta("liquid_max_height", _liquid_max))
	rim_ratio = float(model.get_meta("rim_height", _liquid_max * rim_ratio)) / _liquid_max

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
	_liquid_mat = StandardMaterial3D.new()
	_liquid_mat.albedo_color = LIQUID_COLOR
	_liquid_mat.roughness = 0.3
	_liquid.material_override = _liquid_mat
	_liquid.visible = false
	add_child(_liquid)
	_build_crust(r)
	hide_plunger()

func _build_crust(r: float) -> void:
	if _crust_texture == null:
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_CELLULAR
		noise.frequency = 0.09
		noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_ADD
		_crust_texture = NoiseTexture2D.new()
		_crust_texture.width = 128
		_crust_texture.height = 128
		_crust_texture.seamless = true
		_crust_texture.noise = noise
		var ramp := Gradient.new()
		ramp.set_color(0, Color(0.58, 0.42, 0.27))
		ramp.set_color(1, Color(0.3, 0.19, 0.1))
		_crust_texture.color_ramp = ramp
	var mesh := CylinderMesh.new()
	mesh.top_radius = r - 0.0005
	mesh.bottom_radius = r - 0.0005
	mesh.height = 0.002
	mesh.radial_segments = 24
	mesh.rings = 1
	_crust = MeshInstance3D.new()
	_crust.name = "Crust"
	_crust.mesh = mesh
	_crust_mat = StandardMaterial3D.new()
	_crust_mat.albedo_texture = _crust_texture
	_crust_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_crust_mat.roughness = 1.0
	_crust_mat.uv1_scale = Vector3(1.5, 1.5, 1.5)
	_crust.material_override = _crust_mat
	_crust.visible = false
	add_child(_crust)

## Floating grounds: amount 1 is a full dry crust, 0 is stirred in. spin turns
## it (radians) so stirring visibly swirls it.
func set_crust(amount: float, spin: float = 0.0) -> void:
	if not _crust:
		return
	_crust.visible = amount > 0.02 and _liquid.visible
	_crust_mat.albedo_color = Color(1, 1, 1, clampf(amount, 0.0, 1.0))
	_crust.rotation.y = spin
	_crust.position.y = _liquid.position.y + _liquid_mesh.height * 0.5 + 0.0012

## Coffee colour in the chamber, darkened as it over-extracts.
func set_liquid_color(color: Color) -> void:
	if _liquid_mat:
		_liquid_mat.albedo_color = color

## Local height of the liquid surface (the FILL line when level is 1).
func liquid_surface_y(level: float = 1.0) -> float:
	return _liquid_floor + _liquid_max * level

## The bubble level on the plunger cap, or null.
func get_level() -> Node3D:
	return _plunger.get_node_or_null("Level") as Node3D if _plunger else null

func has_grounds() -> bool:
	return grounds != null

func add_grounds(g: Grounds) -> void:
	grounds = g

func set_liquid_level(ratio: float) -> void:
	if not _liquid:
		return
	ratio = clampf(ratio, 0.0, rim_ratio)
	if ratio > 0.01:
		_liquid.visible = true
		_liquid_mesh.height = _liquid_max * ratio
		_liquid.position.y = _liquid_floor + _liquid_mesh.height * 0.5
		if _crust and _crust.visible:
			_crust.position.y = _liquid.position.y + _liquid_mesh.height * 0.5 + 0.0012
	else:
		_liquid.visible = false

func hide_liquid() -> void:
	if _liquid:
		_liquid.visible = false
	if _crust:
		_crust.visible = false
	set_liquid_color(LIQUID_COLOR)

func show_plunger() -> void:
	if _plunger:
		_plunger.visible = true
		_plunger.position = _plunger_top

func hide_plunger() -> void:
	if _plunger:
		_plunger.visible = false
		_plunger.position = _plunger_top

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
