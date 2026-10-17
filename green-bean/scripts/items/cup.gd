class_name Cup
extends RigidBody3D

const LIQUID_SHADER := preload("res://assets/shaders/liquid.gdshader")
const COOL_TIME := 60.0
const SLOSH_STIFFNESS := 120.0
const SLOSH_DAMPING := 9.0

var order: OrderData = null
var cup_size: DrinkData.CupSize = DrinkData.CupSize.MEDIUM
var has_shot := false
var has_hot_water := false
var has_steamed_milk := false
var has_pour_over_coffee := false
var has_lid := false:
	set(value):
		var changed: bool = value != has_lid
		has_lid = value
		if changed:
			_update_lid_visual()
var syrup_pumps := 0.0
var syrup_type: int = -1
var has_sauce := false
var sauce_type: int = -1

## 1 = just brewed, 0 = cold. Drives the steam wisps; stations may set it directly.
var heat := 0.0

var _fill_level := 0.0
const MODEL_PATHS := {
	DrinkData.CupSize.SMALL: "res://scenes/props/paper_cup_small.tscn",
	DrinkData.CupSize.MEDIUM: "res://scenes/props/paper_cup_medium.tscn",
	DrinkData.CupSize.LARGE: "res://scenes/props/paper_cup_large.tscn",
	DrinkData.CupSize.EXTRA_LARGE: "res://scenes/props/paper_cup_extra_large.tscn",
}

var _fill_visual: MeshInstance3D = null
var _fill_mesh: CylinderMesh = null
var _liquid_mat: ShaderMaterial = null
var _lid_visual: Node3D = null
var _radius := 0.045
var _height := 0.112
var _liquid_floor := -0.048
## Inside wall as (radius, y), bottom to rim.
var _inner_profile := PackedVector2Array([Vector2(0.029, -0.048), Vector2(0.044, 0.054)])
var _steam: SteamPuffs = null
var _slosh := Vector2.ZERO
var _slosh_velocity := Vector2.ZERO
var _last_position := Vector3.ZERO
var _last_velocity := Vector3.ZERO

func _ready() -> void:
	add_to_group("carriable")
	add_to_group("cup")
	freeze = true
	var model: Node3D = (load(MODEL_PATHS[cup_size]) as PackedScene).instantiate()
	model.name = "Model"
	add_child(model)
	var col := model.get_node_or_null("Collision") as CollisionShape3D
	if col:
		# A body needs its collider as a direct child.
		var xform := col.transform
		model.remove_child(col)
		col.owner = null
		add_child(col)
		col.transform = model.transform * xform
		var shape := col.shape as CylinderShape3D
		_radius = shape.radius
		_height = shape.height
	_lid_visual = model.get_node_or_null("Lid") as Node3D
	if _lid_visual:
		_lid_visual.visible = has_lid
	var floor_marker := model.get_node_or_null("LiquidFloor") as Node3D
	if floor_marker:
		_liquid_floor = floor_marker.position.y
	if model.has_meta("inner_profile"):
		_inner_profile = model.get_meta("inner_profile")

	_fill_mesh = CylinderMesh.new()
	_fill_mesh.radial_segments = 20
	_fill_mesh.rings = 1
	_fill_visual = MeshInstance3D.new()
	_fill_visual.name = "Drink"
	_fill_visual.mesh = _fill_mesh
	_liquid_mat = ShaderMaterial.new()
	_liquid_mat.shader = LIQUID_SHADER
	_liquid_mat.set_shader_parameter("liquid_color", Color(0.3, 0.2, 0.1))
	_fill_visual.material_override = _liquid_mat
	_fill_visual.visible = false
	add_child(_fill_visual)

	if order:
		_add_ticket_sticker(model.get_node_or_null("StickerSpot") as Node3D)

	_steam = SteamPuffs.new(10, 0.035, 0.06)
	_steam.position.y = _height * 0.5
	add_child(_steam)

	_last_position = global_position

func _add_ticket_sticker(spot: Node3D) -> void:
	var sticker := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.05, 0.034)
	sticker.mesh = quad
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color(0.98, 0.97, 0.92)
	paper.roughness = 0.9
	sticker.material_override = paper
	if spot:
		sticker.transform = spot.transform
	else:
		sticker.position = Vector3(0, _height * 0.3, _radius + 0.001)
	sticker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sticker)
	var code := Label3D.new()
	code.text = order.ticket_code if order.customer_name.is_empty() else "%s\n%s" % [order.customer_name, order.ticket_code]
	code.font_size = 32
	code.pixel_size = 0.0005
	code.modulate = Color(0.15, 0.1, 0.08)
	code.outline_size = 0
	code.position = Vector3(0, 0, 0.001)
	sticker.add_child(code)

func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	# Cool down slowly unless a station is setting heat directly.
	heat = maxf(heat - delta / COOL_TIME, 0.0)
	if _steam:
		var level := heat if _fill_level > 0.01 else 0.0
		if has_lid:
			level *= 0.35
		_steam.set_level(level)

func _physics_process(delta: float) -> void:
	if delta <= 0.0:
		return
	# Liquid slosh: a damped spring pushed by the cup's acceleration. Runs on physics
	# frames because that is when held items move.
	var velocity_now := (global_position - _last_position) / delta
	var accel := (velocity_now - _last_velocity) / delta
	_last_position = global_position
	_last_velocity = velocity_now
	var local_accel := global_transform.basis.inverse() * accel
	var push := Vector2(local_accel.x, local_accel.z) * -0.0006
	push = push.limit_length(0.6)
	_slosh_velocity += (push - _slosh) * SLOSH_STIFFNESS * delta - _slosh_velocity * SLOSH_DAMPING * delta
	_slosh += _slosh_velocity * delta
	_slosh = _slosh.limit_length(0.5)
	if _liquid_mat and _fill_visual.visible:
		_liquid_mat.set_shader_parameter("wobble", _slosh)

func _update_lid_visual() -> void:
	if _lid_visual == null:
		return
	_lid_visual.visible = has_lid
	if has_lid:
		Fx.pop(_lid_visual, 1.4, 0.3)

func _get_radius() -> float:
	return _radius

func _get_height() -> float:
	return _height

## Inside radius at local height y, from the model's inner_profile.
func _inner_radius(y: float) -> float:
	var a := _inner_profile[0]
	var b := _inner_profile[_inner_profile.size() - 1]
	return lerpf(a.x, b.x, clampf((y - a.y) / (b.y - a.y), 0.0, 1.0))

func set_fill(amount: float, color: Color = Color(0.3, 0.2, 0.1)) -> void:
	_fill_level = clampf(amount, 0.0, 1.0)
	if _fill_level > 0.01:
		_fill_visual.visible = true
		var rim := _inner_profile[_inner_profile.size() - 1].y
		var h := (rim - 0.008 - _liquid_floor) * _fill_level
		_fill_mesh.height = h
		_fill_mesh.bottom_radius = _inner_radius(_liquid_floor) - 0.0005
		_fill_mesh.top_radius = _inner_radius(_liquid_floor + h) - 0.0005
		_fill_visual.position.y = _liquid_floor + h * 0.5
		_liquid_mat.set_shader_parameter("liquid_color", color)
		_liquid_mat.set_shader_parameter("half_height", h * 0.5)
		heat = 1.0
	else:
		_fill_visual.visible = false

func get_fill() -> float:
	return _fill_level

func pour_milk_from(pitcher: Pitcher) -> bool:
	if not pitcher.is_steamed or not pitcher.has_milk:
		return false
	has_steamed_milk = true
	if order:
		order.steam_quality = pitcher.steam_quality
	var current_fill := get_fill()
	set_fill(minf(current_fill + 0.6, 1.0), Color(0.78, 0.62, 0.45))
	_liquid_mat.set_shader_parameter("foam_fraction", clampf(pitcher.foam_level * 0.6, 0.05, 0.6))
	pitcher.reset_pitcher()
	return true

func is_complete() -> bool:
	if not order:
		return false
	if order.has_syrup() and syrup_pumps <= 0.0:
		return false
	if not has_lid:
		return false
	var steps: Array = DrinkData.get_recipe(order.drink_type)["steps"]
	for step in steps:
		match step:
			DrinkData.Step.POUR_OVER_BREW:
				if not has_pour_over_coffee: return false
			DrinkData.Step.SHOT_PRESS_BREW:
				if not has_shot: return false
			DrinkData.Step.HOT_WATER:
				if not has_hot_water: return false
			DrinkData.Step.STEAM_MILK:
				if not has_steamed_milk: return false
			DrinkData.Step.ADD_SAUCE:
				if not has_sauce: return false
	return true

static func create(size: DrinkData.CupSize, order_data: OrderData = null) -> Cup:
	var cup := Cup.new()
	cup.cup_size = size
	cup.order = order_data
	return cup
