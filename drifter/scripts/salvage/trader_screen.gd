class_name TraderScreen
extends Control

const MODULE_PRICE: int = 15
const IMPLANT_PRICE: int = 25

@onready var _scrap_label: Label = %ScrapLabel
@onready var _inventory_list: VBoxContainer = %InventoryList
@onready var _leave_button: Button = %LeaveButton

var _shop_items: Array[Dictionary] = []


func _ready() -> void:
	theme = ThemeBuilder.build()
	_leave_button.pressed.connect(_on_leave_pressed)
	if RunState.active_shop.is_empty():
		_generate_shop()
	else:
		_shop_items = RunState.active_shop
	_refresh_display()


func _generate_shop() -> void:
	_shop_items.clear()

	var module: ModuleData = RewardPool._pick_random_module()
	if module:
		_shop_items.append({"type": "module", "data": module, "price": MODULE_PRICE})

	var module2: ModuleData = RewardPool._pick_random_module()
	if module2 and (not module or module2.id != module.id):
		_shop_items.append({"type": "module", "data": module2, "price": MODULE_PRICE})

	var implant: ImplantData = RewardPool._pick_random_implant()
	if implant:
		_shop_items.append({"type": "implant", "data": implant, "price": IMPLANT_PRICE})

	if not RunState.loadout_grid.is_fully_unlocked():
		_shop_items.append({"type": "grid_cell", "data": null, "price": LoadoutGrid.CELL_UNLOCK_COST})

	_save_shop()


func _refresh_display() -> void:
	_scrap_label.text = "Scrap: " + str(RunState.scrap)

	for child: Node in _inventory_list.get_children():
		child.queue_free()

	for i: int in _shop_items.size():
		var item: Dictionary = _shop_items[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		var type_label := Label.new()
		var item_type: String = item["type"] as String
		match item_type:
			"module":
				type_label.text = "[MOD]"
				type_label.add_theme_color_override("font_color", ThemeBuilder.ACCENT_GLOW)
			"implant":
				type_label.text = "[IMP]"
				type_label.add_theme_color_override("font_color", Color(0.90, 0.70, 0.20))
			"grid_cell":
				type_label.text = "[GRID]"
				type_label.add_theme_color_override("font_color", Color(0.50, 0.90, 0.50))
		type_label.add_theme_font_size_override("font_size", 12)
		type_label.custom_minimum_size = Vector2(50, 0)
		row.add_child(type_label)

		var name_label := Label.new()
		var data: Resource = item["data"] as Resource
		if data is ModuleData:
			name_label.text = (data as ModuleData).display_name + " — " + (data as ModuleData).description
		elif data is ImplantData:
			name_label.text = (data as ImplantData).display_name + " — " + (data as ImplantData).description
		elif item_type == "grid_cell":
			var grid: LoadoutGrid = RunState.loadout_grid
			var expandable: int = grid.get_locked_expandable_cells().size()
			name_label.text = "Unlock Grid Cell — " + str(grid.get_unlocked_count()) + "/" + str(LoadoutGrid.COLS * LoadoutGrid.ROWS) + " (" + str(expandable) + " available)"
		name_label.add_theme_font_size_override("font_size", 13)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)

		var price: int = item["price"] as int
		var buy_btn := Button.new()
		buy_btn.custom_minimum_size = Vector2(120, 0)

		var can_afford: bool = RunState.scrap >= price
		var blocked: bool = false
		if item_type == "implant" and RunState.implants.size() >= RunState.MAX_IMPLANTS:
			blocked = true
			buy_btn.text = "Full (" + str(RunState.MAX_IMPLANTS) + "/" + str(RunState.MAX_IMPLANTS) + ")"
		else:
			buy_btn.text = str(price) + " scrap"

		buy_btn.disabled = not can_afford or blocked
		buy_btn.pressed.connect(_on_buy_pressed.bind(i))
		row.add_child(buy_btn)

		_inventory_list.add_child(row)

	if _shop_items.is_empty():
		var empty := Label.new()
		empty.text = "Nothing for sale today."
		empty.add_theme_font_size_override("font_size", 13)
		empty.add_theme_color_override("font_color", ThemeBuilder.TEXT_SECONDARY)
		_inventory_list.add_child(empty)


func _on_buy_pressed(index: int) -> void:
	var item: Dictionary = _shop_items[index]
	var price: int = item["price"] as int
	if RunState.scrap < price:
		return

	RunState.scrap -= price
	var item_type: String = item["type"] as String

	match item_type:
		"module":
			var module: ModuleData = item["data"] as ModuleData
			if module:
				RunState.collect_module(module)
		"implant":
			var implant: ImplantData = item["data"] as ImplantData
			if not RunState.add_implant(implant):
				RunState.scrap += price
				return
		"grid_cell":
			RunState.pending_cell_unlock = true
			EventBus.screen_transition_requested.emit("loadout")
			return

	_shop_items.remove_at(index)

	if item_type == "grid_cell" and not RunState.loadout_grid.is_fully_unlocked():
		_shop_items.append({"type": "grid_cell", "data": null, "price": LoadoutGrid.CELL_UNLOCK_COST})

	_save_shop()
	_refresh_display()


func _save_shop() -> void:
	RunState.active_shop = _shop_items.duplicate()


func _on_leave_pressed() -> void:
	RunState.active_shop.clear()
	EventBus.screen_transition_requested.emit("map")
