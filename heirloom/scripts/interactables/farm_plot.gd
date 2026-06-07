extends StaticBody3D

enum PlotState { EMPTY, TILLED, PLANTED, GROWING, HARVESTABLE }

@export var plot_id: String = ""
@export var harvest_scene: PackedScene = null

var _state: PlotState = PlotState.EMPTY
var _growth_days: int = 5
var _days_planted: int = 0
var _watered_today: bool = false

@onready var _crop_mesh: Node3D = $CropMesh


func _ready() -> void:
	_update_visuals()
	EventBus.day_started.connect(_on_day_started)


func get_interact_hint(player: Node3D) -> String:
	if not GameState.is_upgrade_complete("garden_beds"):
		return ""
	return "[E] %s" % get_plot_state_name()


func interact(player: Node3D) -> void:
	if not GameState.is_upgrade_complete("garden_beds"):
		return

	match _state:
		PlotState.EMPTY:
			_try_till(player)
		PlotState.TILLED:
			_try_plant(player)
		PlotState.PLANTED, PlotState.GROWING:
			_try_water(player)
		PlotState.HARVESTABLE:
			_harvest(player)


func _try_till(player: Node3D) -> void:
	var held: Node3D = player.get_held_item() as Node3D
	if not held:
		return
	if held.get("tool_type") != 2:  # SHOVEL
		return
	_state = PlotState.TILLED
	_update_visuals()


func _try_plant(_player: Node3D) -> void:
	# Seeds are a pocket item (abstract)
	var seed_count: int = GameState.inventory.get("seed_packet", 0) as int
	if seed_count <= 0:
		return
	GameState.inventory["seed_packet"] = seed_count - 1
	_state = PlotState.PLANTED
	_days_planted = 0
	_watered_today = false
	_update_visuals()


func _try_water(player: Node3D) -> void:
	if _watered_today:
		return
	var held: Node3D = player.get_held_item() as Node3D
	if not held:
		return
	if not held.has_method("use_water"):
		return
	if not held.use_water():
		return
	_watered_today = true
	_update_visuals()


func _harvest(player: Node3D) -> void:
	if player.has_held_item():
		return

	_state = PlotState.EMPTY
	_days_planted = 0

	if harvest_scene:
		var item: Node3D = harvest_scene.instantiate()
		get_parent().add_child(item)
		item.global_position = global_position + Vector3(0, 0.5, 0)
		player.pickup_item(item)
	else:
		# Fallback: spawn a generic food item
		var food_scene: PackedScene = load("res://scenes/items/food_item.tscn") as PackedScene
		if food_scene:
			var food: Node3D = food_scene.instantiate()
			get_parent().add_child(food)
			food.global_position = global_position + Vector3(0, 0.5, 0)
			food.set("display_name", "Fresh Vegetable")
			food.set("hunger_restore", 0.4)
			food.set("sell_price", 10.0)
			player.pickup_item(food)

	_update_visuals()


func _on_day_started(_day: int) -> void:
	if not GameState.is_upgrade_complete("garden_beds"):
		return

	if _state == PlotState.PLANTED or _state == PlotState.GROWING:
		if _watered_today:
			_days_planted += 1
			var growth_needed: int = _growth_days
			if GameState.is_upgrade_complete("irrigation"):
				growth_needed = int(float(_growth_days) * 0.75)
			if _days_planted >= growth_needed:
				_state = PlotState.HARVESTABLE
			else:
				_state = PlotState.GROWING

		# Auto-water if irrigation is installed
		_watered_today = GameState.is_upgrade_complete("irrigation")
		_update_visuals()


func _update_visuals() -> void:
	if not _crop_mesh:
		return

	match _state:
		PlotState.EMPTY:
			_crop_mesh.visible = false
		PlotState.TILLED:
			_crop_mesh.visible = false
		PlotState.PLANTED:
			_crop_mesh.visible = true
			_crop_mesh.scale = Vector3(0.3, 0.3, 0.3)
		PlotState.GROWING:
			_crop_mesh.visible = true
			var pct: float = float(_days_planted) / float(_growth_days)
			_crop_mesh.scale = Vector3.ONE * lerpf(0.3, 0.8, pct)
		PlotState.HARVESTABLE:
			_crop_mesh.visible = true
			_crop_mesh.scale = Vector3.ONE


func get_plot_state_name() -> String:
	match _state:
		PlotState.EMPTY: return "Till (hold shovel)"
		PlotState.TILLED:
			var seeds: int = GameState.inventory.get("seed_packet", 0) as int
			if seeds > 0: return "Plant (%d seeds)" % seeds
			return "Needs seeds (buy at store)"
		PlotState.PLANTED:
			if _watered_today: return "Planted (watered)"
			return "Water (hold filled watering can)"
		PlotState.GROWING:
			if _watered_today: return "Growing %d/%d (watered)" % [_days_planted, _growth_days]
			return "Growing %d/%d (hold filled can)" % [_days_planted, _growth_days]
		PlotState.HARVESTABLE: return "Harvest! (empty hands)"
	return ""
