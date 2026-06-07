extends CanvasLayer

signal shop_closed

enum Tab { BUY, SELL }

var _current_tab: Tab = Tab.BUY
var _store_position: Vector3 = Vector3.ZERO

# Physical items spawn near the store when bought
# Pocket items (seeds, abstract) go to GameState
var _buy_items: Array[Dictionary] = [
	{"id": "food", "name": "Canned Food", "price": 5.0, "scene": "res://scenes/items/food_item.tscn", "physical": true},
	{"id": "water_bottle", "name": "Water Bottle", "price": 2.0, "scene": "", "physical": false},
	{"id": "seed_packet", "name": "Seed Packet", "price": 3.0, "scene": "", "physical": false},
	{"id": "wood_plank", "name": "Wood Plank", "price": 5.0, "scene": "res://scenes/items/material_plank.tscn", "physical": true},
	{"id": "salvage_part", "name": "Salvage Part", "price": 8.0, "scene": "res://scenes/items/material_salvage.tscn", "physical": true},
	{"id": "wire_pipe", "name": "Wire/Pipe", "price": 10.0, "scene": "", "physical": false},
	{"id": "sapling", "name": "Tree Sapling", "price": 5.0, "scene": "", "physical": false},
	{"id": "chicken_purchase", "name": "Live Chicken", "price": 15.0, "scene": "res://scenes/items/chicken_purchase.tscn", "physical": true},
	{"id": "jerrycan", "name": "Jerry Can (fuel)", "price": 8.0, "scene": "res://scenes/items/jerrycan.tscn", "physical": true},
]

@onready var _panel: PanelContainer = $Panel
@onready var _item_list: VBoxContainer = $Panel/Margin/VBox/Scroll/ItemList
@onready var _tab_buy: Button = $Panel/Margin/VBox/Tabs/BuyTab
@onready var _tab_sell: Button = $Panel/Margin/VBox/Tabs/SellTab
@onready var _close_btn: Button = $Panel/Margin/VBox/CloseBtn
@onready var _money_label: Label = $Panel/Margin/VBox/MoneyLabel


func _ready() -> void:
	_tab_buy.pressed.connect(func() -> void: _switch_tab(Tab.BUY))
	_tab_sell.pressed.connect(func() -> void: _switch_tab(Tab.SELL))
	_close_btn.pressed.connect(_close)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_populate_buy()
	_update_money()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") or (event is InputEventKey and (event as InputEventKey).keycode == KEY_ESCAPE):
		_close()
		get_viewport().set_input_as_handled()


func _switch_tab(tab: Tab) -> void:
	_current_tab = tab
	if tab == Tab.BUY:
		_populate_buy()
	else:
		_populate_sell()


func _populate_buy() -> void:
	_clear_list()

	for item: Dictionary in _buy_items:
		var price: float = item["price"] as float
		var btn := Button.new()
		btn.text = "%s  -  $%.2f" % [item["name"], price]
		btn.disabled = GameState.money < price
		var item_data: Dictionary = item
		btn.pressed.connect(_on_buy_pressed.bind(item_data))
		_item_list.add_child(btn)

	# Camaro parts
	var parts: Array[Dictionary] = _get_available_camaro_parts()
	for part: Dictionary in parts:
		var price: float = part["price"] as float
		var btn := Button.new()
		btn.text = "%s  -  $%.2f" % [part["name"], price]
		btn.disabled = GameState.money < price
		btn.pressed.connect(_on_buy_camaro_part.bind(part))
		_item_list.add_child(btn)


func _populate_sell() -> void:
	_clear_list()
	var lbl := Label.new()
	lbl.text = "Hold an item and press [E] at the counter to sell it."
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_item_list.add_child(lbl)


func _on_buy_pressed(item: Dictionary) -> void:
	var price: float = item["price"] as float
	if not GameState.spend_money(price):
		return

	var is_physical: bool = item["physical"] as bool
	var scene_path: String = item["scene"] as String
	var item_id: String = item["id"] as String

	if is_physical and not scene_path.is_empty():
		_spawn_item(scene_path, item)
	elif item_id == "water_bottle":
		GameState.thirst = clampf(GameState.thirst + 0.5, 0.0, 1.0)
	elif item_id == "seed_packet" or item_id == "sapling":
		GameState.inventory[item_id] = (GameState.inventory.get(item_id, 0) as int) + 1
	elif item_id == "wire_pipe":
		GameState.add_material("wire_pipe")

	EventBus.item_purchased.emit(item_id, price)
	_update_money()
	_switch_tab(_current_tab)


func _on_buy_camaro_part(part: Dictionary) -> void:
	var price: float = part["price"] as float
	if not GameState.spend_money(price):
		return

	var part_scene: PackedScene = load("res://scenes/items/camaro_part.tscn") as PackedScene
	if part_scene:
		var item: Node3D = part_scene.instantiate()
		item.set("part_id", part["id"])
		item.set("item_id", part["id"])
		item.set("display_name", part["name"])
		get_tree().root.add_child(item)
		item.global_position = _get_spawn_pos()

	EventBus.item_purchased.emit(part["id"] as String, price)
	_update_money()
	_switch_tab(_current_tab)


func _spawn_item(scene_path: String, item_data: Dictionary) -> void:
	var scene: PackedScene = load(scene_path) as PackedScene
	if not scene:
		return
	var item: Node3D = scene.instantiate()
	get_tree().root.add_child(item)
	item.global_position = _get_spawn_pos()


func _get_spawn_pos() -> Vector3:
	if _store_position != Vector3.ZERO:
		return _store_position + Vector3(randf_range(-1.0, 1.0), 1.0, randf_range(-1.0, 1.0))
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if player:
		return player.global_position + Vector3(0, 1.0, -1.5)
	return Vector3.ZERO


func _get_available_camaro_parts() -> Array[Dictionary]:
	var parts: Array[Dictionary] = []
	var part_list: Array[Dictionary] = [
		{"id": "camaro_suspension", "name": "Suspension", "price": 100.0, "prereqs": []},
		{"id": "camaro_body_panels", "name": "Body Panels", "price": 150.0, "prereqs": []},
		{"id": "camaro_engine_block", "name": "Engine Block", "price": 200.0, "prereqs": []},
		{"id": "camaro_heads", "name": "Cylinder Heads", "price": 175.0, "prereqs": ["camaro_engine_block"]},
		{"id": "camaro_transmission", "name": "Transmission", "price": 250.0, "prereqs": ["camaro_engine_block"]},
		{"id": "camaro_intake", "name": "Intake Manifold", "price": 125.0, "prereqs": ["camaro_heads"]},
		{"id": "camaro_exhaust", "name": "Exhaust System", "price": 150.0, "prereqs": ["camaro_heads"]},
		{"id": "camaro_interior", "name": "Interior", "price": 200.0, "prereqs": ["camaro_body_panels"]},
		{"id": "camaro_carburetor", "name": "Carburetor", "price": 175.0, "prereqs": ["camaro_intake"]},
		{"id": "camaro_electrical", "name": "Electrical System", "price": 300.0, "prereqs": ["camaro_engine_block", "camaro_interior"]},
		{"id": "camaro_paint", "name": "Paint Job", "price": 400.0, "prereqs": ["camaro_body_panels", "camaro_interior"]},
	]

	for part: Dictionary in part_list:
		if GameState.is_part_installed(part["id"] as String):
			continue
		var prereqs_met := true
		var prereqs: Array = part["prereqs"] as Array
		for prereq: String in prereqs:
			if not GameState.is_part_installed(prereq):
				prereqs_met = false
				break
		if prereqs_met:
			parts.append(part)

	return parts


func _update_money() -> void:
	_money_label.text = "Money: $%.2f" % GameState.money


func _clear_list() -> void:
	for child: Node in _item_list.get_children():
		child.queue_free()


func _close() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	shop_closed.emit()
