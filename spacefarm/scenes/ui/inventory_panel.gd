class_name InventoryPanel
extends PanelContainer

@onready var _seeds_list: VBoxContainer = %SeedsList
@onready var _crops_list: VBoxContainer = %CropsList
@onready var _goods_list: VBoxContainer = %GoodsList


func _ready() -> void:
	visible = false
	EventBus.inventory_changed.connect(_on_inventory_changed)


func on_opened() -> void:
	_refresh()


func on_closed() -> void:
	pass


func _refresh() -> void:
	_clear_list(_seeds_list)
	_clear_list(_crops_list)
	_clear_list(_goods_list)

	var all_seeds: Dictionary = GameState.get_all_seeds()
	for seed_id: String in all_seeds:
		var count: int = all_seeds[seed_id]
		var crop_id: String = seed_id.substr(0, seed_id.length() - 5)
		var crop: CropData = Database.get_crop(crop_id)
		var label_text: String = "%s x%d" % [crop.get_active_name() if crop else crop_id, count]
		_add_item(_seeds_list, label_text, crop.seed_color if crop else Color.WHITE)

	var all_harvested: Dictionary = GameState.get_all_harvested()
	for crop_id: String in all_harvested:
		var count: int = all_harvested[crop_id]
		var crop: CropData = Database.get_crop(crop_id)
		var label_text: String = "%s x%d  [%d food]" % [
			crop.get_active_name() if crop else crop_id,
			count,
			crop.food_units * count if crop else 0
		]
		_add_item(_crops_list, label_text, crop.crop_color if crop else Color.WHITE)

	var all_processed: Dictionary = GameState.get_all_processed()
	for item_id: String in all_processed:
		var count: int = all_processed[item_id]
		_add_item(_goods_list, "%s x%d" % [item_id.replace("_", " "), count], Color(0.7, 0.7, 0.8))

	if _seeds_list.get_child_count() == 0:
		_add_item(_seeds_list, "(none)", Color(0.4, 0.4, 0.4))
	if _crops_list.get_child_count() == 0:
		_add_item(_crops_list, "(none)", Color(0.4, 0.4, 0.4))
	if _goods_list.get_child_count() == 0:
		_add_item(_goods_list, "(none)", Color(0.4, 0.4, 0.4))


func _add_item(container: VBoxContainer, text: String, color: Color) -> void:
	var hbox: HBoxContainer = HBoxContainer.new()
	var swatch: ColorRect = ColorRect.new()
	swatch.custom_minimum_size = Vector2(12, 12)
	swatch.color = color
	hbox.add_child(swatch)
	var label: Label = Label.new()
	label.text = "  " + text
	label.add_theme_font_size_override("font_size", 12)
	hbox.add_child(label)
	container.add_child(hbox)


func _clear_list(container: VBoxContainer) -> void:
	for child: Node in container.get_children():
		child.queue_free()


func _on_inventory_changed() -> void:
	if visible:
		_refresh()
