extends CanvasLayer

signal shop_closed

enum Tab { BUY, SELL }

var _current_tab: Tab = Tab.BUY

var _buy_items: Array[Dictionary] = [
	{"id": "food_cold", "name": "Store Food", "price": 5.0, "category": "food"},
	{"id": "food_ingredients", "name": "Cooking Ingredients", "price": 2.0, "category": "food"},
	{"id": "water_bottle", "name": "Water Bottle", "price": 2.0, "category": "water"},
	{"id": "seed_packet", "name": "Seed Packet", "price": 3.0, "category": "farming"},
	{"id": "wood_plank", "name": "Wood Plank", "price": 5.0, "category": "material"},
	{"id": "salvage_part", "name": "Salvage Part", "price": 8.0, "category": "material"},
	{"id": "wire_pipe", "name": "Wire/Pipe", "price": 10.0, "category": "material"},
]

@onready var _panel: PanelContainer = $Panel
@onready var _item_list: VBoxContainer = $Panel/Margin/VBox/ItemList
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
	if event.is_action_pressed("interact") or event is InputEventKey and (event as InputEventKey).keycode == KEY_ESCAPE:
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

	var camaro_parts: Array[Dictionary] = _get_available_camaro_parts()
	var all_items: Array[Dictionary] = _buy_items.duplicate()
	all_items.append_array(camaro_parts)

	for item: Dictionary in all_items:
		var price: float = item["price"] as float
		var btn := Button.new()
		btn.text = "%s  -  $%.2f" % [item["name"], price]
		btn.disabled = GameState.money < price
		var item_id: String = item["id"] as String
		btn.pressed.connect(_on_buy_pressed.bind(item_id, price))
		_item_list.add_child(btn)


func _populate_sell() -> void:
	_clear_list()
	for item_id: String in GameState.inventory:
		var count: int = GameState.inventory[item_id] as int
		if count <= 0:
			continue
		var price: float = Economy.get_sell_price(item_id)
		if price <= 0.0:
			continue
		var btn := Button.new()
		btn.text = "%s (x%d)  -  $%.2f each" % [item_id, count, price]
		btn.pressed.connect(_on_sell_pressed.bind(item_id, price))
		_item_list.add_child(btn)

	if _item_list.get_child_count() == 0:
		var lbl := Label.new()
		lbl.text = "Nothing to sell."
		_item_list.add_child(lbl)


func _on_buy_pressed(item_id: String, price: float) -> void:
	if not GameState.spend_money(price):
		return

	if item_id.begins_with("camaro_"):
		var part_scene: PackedScene = load("res://scenes/items/camaro_part.tscn") as PackedScene
		if part_scene:
			var part: Node3D = part_scene.instantiate()
			part.set("part_id", item_id)
			part.set("item_id", item_id)
			part.set("display_name", _get_part_display_name(item_id))
			get_tree().root.add_child(part)
			var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
			if player:
				part.global_position = player.global_position + Vector3(0, 1.0, -1.5)
	elif item_id == "food_cold" or item_id == "food_ingredients":
		GameState.inventory["food"] = (GameState.inventory.get("food", 0) as int) + 1
		if item_id == "food_cold":
			GameState.hunger = clampf(GameState.hunger + 0.3, 0.0, 1.0)
		else:
			GameState.hunger = clampf(GameState.hunger + 0.15, 0.0, 1.0)
	elif item_id == "water_bottle":
		GameState.thirst = clampf(GameState.thirst + 0.5, 0.0, 1.0)
	elif item_id == "wood_plank" or item_id == "salvage_part" or item_id == "wire_pipe":
		GameState.add_material(item_id)
	else:
		GameState.inventory[item_id] = (GameState.inventory.get(item_id, 0) as int) + 1

	EventBus.item_purchased.emit(item_id, price)
	_update_money()
	_switch_tab(_current_tab)


func _on_sell_pressed(item_id: String, price: float) -> void:
	var count: int = GameState.inventory.get(item_id, 0) as int
	if count <= 0:
		return
	GameState.inventory[item_id] = count - 1
	var discount: float = Economy.get_friendship_discount("earl")
	GameState.add_money(price * (1.0 + discount))
	EventBus.item_sold.emit(item_id, price)
	_update_money()
	_switch_tab(_current_tab)


func _get_available_camaro_parts() -> Array[Dictionary]:
	var parts: Array[Dictionary] = []
	var catalog: Dictionary = HomesteadManager.get_all_upgrades()

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
		if GameState.inventory.get(part["id"], 0) as int > 0:
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


func _get_part_display_name(part_id: String) -> String:
	var names: Dictionary = {
		"camaro_suspension": "Suspension",
		"camaro_body_panels": "Body Panels",
		"camaro_engine_block": "Engine Block",
		"camaro_heads": "Cylinder Heads",
		"camaro_transmission": "Transmission",
		"camaro_intake": "Intake Manifold",
		"camaro_exhaust": "Exhaust System",
		"camaro_interior": "Interior",
		"camaro_carburetor": "Carburetor",
		"camaro_electrical": "Electrical System",
		"camaro_paint": "Paint Job",
	}
	return names.get(part_id, part_id) as String


func _close() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	shop_closed.emit()
