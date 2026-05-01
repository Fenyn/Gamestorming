class_name Cup
extends RigidBody3D

var order: OrderData = null
var cup_size: DrinkData.CupSize = DrinkData.CupSize.MEDIUM
var has_shot := false
var has_hot_water := false
var has_steamed_milk := false
var has_pour_over_coffee := false
var has_lid := false
var syrup_pumps := 0.0
var syrup_type: int = -1
var has_sauce := false
var sauce_type: int = -1

var _fill_level := 0.0
var _fill_visual: CSGCylinder3D = null

func _ready() -> void:
	add_to_group("carriable")
	add_to_group("cup")
	freeze = true

	var body := CSGCylinder3D.new()
	body.radius = _get_radius()
	body.height = _get_height()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.95, 0.9)
	body.material = mat
	add_child(body)

	_fill_visual = CSGCylinder3D.new()
	_fill_visual.radius = _get_radius() * 0.85
	_fill_visual.height = 0.001
	_fill_visual.position.y = -_get_height() * 0.4
	var fill_mat := StandardMaterial3D.new()
	fill_mat.albedo_color = Color(0.3, 0.2, 0.1)
	_fill_visual.material = fill_mat
	_fill_visual.visible = false
	add_child(_fill_visual)

	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = _get_radius()
	shape.height = _get_height()
	col.shape = shape
	add_child(col)

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
		(_fill_visual.material as StandardMaterial3D).albedo_color = color
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
	set_fill(minf(current_fill + 0.6, 1.0), Color(0.85, 0.8, 0.7))
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
			DrinkData.Step.AEROPRESS_BREW:
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
