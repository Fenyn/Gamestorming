class_name ShippingPanel
extends PanelContainer

var _pod: CargoPod = null
var _ship_crops: Dictionary = {}
var _ship_goods: Dictionary = {}

@onready var _inventory_list: VBoxContainer = %InventoryList
@onready var _cargo_list: VBoxContainer = %CargoList
@onready var _directive_label: Label = %DirectiveLabel
@onready var _launch_button: Button = %LaunchButton
@onready var _cargo_summary: Label = %CargoSummary


func _ready() -> void:
	visible = false
	_launch_button.pressed.connect(_on_launch)


func set_pod(pod: CargoPod) -> void:
	_pod = pod


func on_opened() -> void:
	_ship_crops.clear()
	_ship_goods.clear()
	_refresh()


func on_closed() -> void:
	_pod = null


func _refresh() -> void:
	_rebuild_inventory_list()
	_rebuild_cargo_list()
	_update_directive_label()
	_update_cargo_summary()


func _rebuild_inventory_list() -> void:
	_clear_list(_inventory_list)

	var shippable: Dictionary = {}
	shippable.merge(GameState.get_all_harvested())
	shippable.merge(GameState.get_all_processed())

	if shippable.is_empty():
		var label: Label = Label.new()
		label.text = "Inventory empty"
		label.add_theme_font_size_override("font_size", 11)
		label.modulate = Color(0.5, 0.5, 0.5, 1)
		_inventory_list.add_child(label)
		return

	for item_id: String in shippable:
		var count: int = shippable[item_id]
		var btn: Button = Button.new()
		btn.text = "%s x%d  [+1 →]" % [_display_name(item_id), count]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_load_item.bind(item_id))
		_inventory_list.add_child(btn)


func _rebuild_cargo_list() -> void:
	_clear_list(_cargo_list)

	if _pod == null or _pod.get_cargo().is_empty():
		var label: Label = Label.new()
		label.text = "Supply station empty"
		label.add_theme_font_size_override("font_size", 11)
		label.modulate = Color(0.5, 0.5, 0.5, 1)
		_cargo_list.add_child(label)
		return

	for item_id: String in _pod.get_cargo():
		var count: int = _pod.get_cargo()[item_id]
		var btn: Button = Button.new()
		btn.text = "%s x%d  [← -1]" % [_display_name(item_id), count]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_unload_item.bind(item_id))
		_cargo_list.add_child(btn)


func _on_load_item(item_id: String) -> void:
	if _pod == null:
		return
	if not GameState.remove_item(item_id, 1):
		return
	_pod.add_to_cargo(item_id, 1)
	_refresh()


func _on_unload_item(item_id: String) -> void:
	if _pod == null:
		return
	if not _pod.remove_from_cargo(item_id, 1):
		return
	GameState.add_item(item_id, 1)
	_refresh()


func _on_launch() -> void:
	if _pod == null or _pod.get_cargo().is_empty():
		return

	var shipped: Dictionary = _pod.launch()

	var food_total: int = 0
	for item_id: String in shipped:
		var count: int = shipped[item_id]
		var crop: CropData = Database.get_crop(item_id)
		if crop:
			food_total += crop.food_units * count
		GameState.items_shipped[item_id] = GameState.items_shipped.get(item_id, 0) + count

	GameState.food_shipped_total += food_total
	EventBus.cargo_shipped.emit(shipped)
	if food_total > 0:
		EventBus.food_added.emit(food_total)
	EventBus.notification_requested.emit("Supplies distributed to crew.")
	visible = false


func _update_directive_label() -> void:
	var directive: MilestoneData = Database.get_milestone(GameState.active_directive_id) as MilestoneData
	if directive == null:
		_directive_label.text = "All directives complete"
		return
	if directive.required_food_units > 0:
		_directive_label.text = "Directive: %d / %d food units" % [
			GameState.food_shipped_total, directive.required_food_units
		]
	elif not directive.required_items.is_empty():
		var parts: Array[String] = []
		for item_id: String in directive.required_items:
			var needed: int = directive.required_items[item_id]
			var shipped_count: int = GameState.items_shipped.get(item_id, 0)
			parts.append("%s: %d/%d" % [_display_name(item_id), shipped_count, needed])
		_directive_label.text = ", ".join(parts)


func _update_cargo_summary() -> void:
	if _pod == null or _pod.get_cargo().is_empty():
		_cargo_summary.text = "Nothing loaded"
		_launch_button.disabled = true
		return
	var food: int = _pod.get_cargo_food_total()
	var item_count: int = 0
	for item_id: String in _pod.get_cargo():
		item_count += _pod.get_cargo()[item_id]
	_cargo_summary.text = "%d items | %d food units" % [item_count, food]
	_launch_button.disabled = false


func _display_name(item_id: String) -> String:
	var crop: CropData = Database.get_crop(item_id)
	if crop:
		return crop.get_active_name()
	return item_id.replace("_", " ").capitalize()


func _clear_list(container: VBoxContainer) -> void:
	for child: Node in container.get_children():
		child.queue_free()
