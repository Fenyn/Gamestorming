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
var _fill_visual: CSGCylinder3D = null
var _liquid_mat: ShaderMaterial = null
var _lid_visual: CSGCylinder3D = null
var _steam: SteamPuffs = null
var _slosh := Vector2.ZERO
var _slosh_velocity := Vector2.ZERO
var _last_position := Vector3.ZERO
var _last_velocity := Vector3.ZERO

func _ready() -> void:
	add_to_group("carriable")
	add_to_group("cup")
	freeze = true
	var radius := _get_radius()
	var height := _get_height()

	# Paper cup, hollowed out so the drink inside is visible.
	var body := CSGCylinder3D.new()
	body.radius = radius
	body.height = height
	body.sides = 16
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.95, 0.9)
	mat.roughness = 0.85
	body.material = mat
	add_child(body)
	var hollow := CSGCylinder3D.new()
	hollow.operation = CSGShape3D.OPERATION_SUBTRACTION
	hollow.radius = radius * 0.9
	hollow.height = height * 0.9 + 0.002
	hollow.position.y = height * 0.05 + 0.001
	hollow.sides = 16
	body.add_child(hollow)

	# Kraft sleeve band for a bit of colour.
	var sleeve := CSGCylinder3D.new()
	sleeve.radius = radius * 1.04
	sleeve.height = height * 0.35
	sleeve.position.y = -height * 0.05
	sleeve.sides = 16
	var sleeve_mat := StandardMaterial3D.new()
	sleeve_mat.albedo_color = Color(0.62, 0.45, 0.3)
	sleeve_mat.roughness = 0.95
	sleeve.material = sleeve_mat
	add_child(sleeve)

	_fill_visual = CSGCylinder3D.new()
	_fill_visual.radius = radius * 0.88
	_fill_visual.height = 0.001
	_fill_visual.position.y = -height * 0.4
	_fill_visual.sides = 16
	_liquid_mat = ShaderMaterial.new()
	_liquid_mat.shader = LIQUID_SHADER
	_liquid_mat.set_shader_parameter("liquid_color", Color(0.3, 0.2, 0.1))
	_fill_visual.material = _liquid_mat
	_fill_visual.visible = false
	add_child(_fill_visual)

	_lid_visual = CSGCylinder3D.new()
	_lid_visual.radius = radius * 1.06
	_lid_visual.height = 0.012
	_lid_visual.position.y = height * 0.5 + 0.005
	_lid_visual.sides = 16
	var lid_mat := StandardMaterial3D.new()
	lid_mat.albedo_color = Color(0.2, 0.15, 0.12)
	lid_mat.roughness = 0.4
	_lid_visual.material = lid_mat
	var sip := CSGBox3D.new()
	sip.size = Vector3(0.012, 0.01, 0.006)
	sip.position = Vector3(0, 0.006, radius * 0.7)
	sip.material = lid_mat
	_lid_visual.add_child(sip)
	_lid_visual.visible = has_lid
	add_child(_lid_visual)

	if order:
		_add_ticket_sticker(radius)

	_steam = SteamPuffs.new(10, 0.035, 0.06)
	_steam.position.y = height * 0.5
	add_child(_steam)

	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	col.shape = shape
	add_child(col)

	_last_position = global_position

func _add_ticket_sticker(radius: float) -> void:
	var sticker := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.05, 0.034)
	sticker.mesh = quad
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color(0.98, 0.97, 0.92)
	paper.roughness = 0.9
	sticker.material_override = paper
	sticker.position = Vector3(0, _get_height() * 0.3, radius * 0.98 + 0.002)
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
	match cup_size:
		DrinkData.CupSize.SMALL: return 0.035
		DrinkData.CupSize.MEDIUM: return 0.038
		DrinkData.CupSize.LARGE: return 0.042
		DrinkData.CupSize.EXTRA_LARGE: return 0.046
	return 0.038

func _get_height() -> float:
	match cup_size:
		DrinkData.CupSize.SMALL: return 0.1
		DrinkData.CupSize.MEDIUM: return 0.12
		DrinkData.CupSize.LARGE: return 0.14
		DrinkData.CupSize.EXTRA_LARGE: return 0.16
	return 0.12

func set_fill(amount: float, color: Color = Color(0.3, 0.2, 0.1)) -> void:
	_fill_level = clampf(amount, 0.0, 1.0)
	if _fill_level > 0.01:
		_fill_visual.visible = true
		_fill_visual.height = _get_height() * 0.8 * _fill_level
		_fill_visual.position.y = -_get_height() * 0.4 + (_fill_visual.height * 0.5)
		_liquid_mat.set_shader_parameter("liquid_color", color)
		_liquid_mat.set_shader_parameter("half_height", _fill_visual.height * 0.5)
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
