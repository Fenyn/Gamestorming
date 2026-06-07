class_name Hotbar
extends HBoxContainer

const SLOT_SIZE: Vector2 = Vector2(44, 44)
const SELECTED_BORDER: Color = Color(0.9, 0.8, 0.5, 0.9)
const UNSELECTED_BORDER: Color = Color(0.45, 0.35, 0.22, 0.6)

var _slots: Array[PanelContainer] = []
var _slot_labels: Array[Label] = []
var _slot_swatches: Array[ColorRect] = []
var _slot_counts: Array[Label] = []


func _ready() -> void:
	for i: int in range(GameState.TOOLBAR_SIZE):
		var slot: PanelContainer = _create_slot(i)
		add_child(slot)
		_slots.append(slot)

	EventBus.tool_switched.connect(_on_refresh)
	EventBus.inventory_changed.connect(_on_refresh)
	_refresh()


func _create_slot(index: int) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = SLOT_SIZE

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = FarmTheme.PANEL_BG
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = UNSELECTED_BORDER
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	panel.add_theme_stylebox_override("panel", style)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var swatch: ColorRect = ColorRect.new()
	swatch.custom_minimum_size = Vector2(20, 20)
	swatch.color = Color(0.2, 0.2, 0.2, 0.5)
	vbox.add_child(swatch)
	_slot_swatches.append(swatch)

	var name_label: Label = Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 7)
	vbox.add_child(name_label)
	_slot_labels.append(name_label)

	var count_label: Label = Label.new()
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.add_theme_font_size_override("font_size", 7)
	count_label.modulate = Color(0.7, 0.7, 0.7, 1)
	vbox.add_child(count_label)
	_slot_counts.append(count_label)

	panel.add_child(vbox)
	return panel


func _refresh() -> void:
	for i: int in range(_slots.size()):
		var item_id: String = GameState.toolbar[i] if i < GameState.toolbar.size() else ""
		var panel: PanelContainer = _slots[i]
		var style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat

		if i == GameState.active_slot:
			style.border_color = SELECTED_BORDER
			style.bg_color = FarmTheme.BUTTON_HOVER_BG
		else:
			style.border_color = UNSELECTED_BORDER
			style.bg_color = FarmTheme.PANEL_BG

		if item_id == "":
			_slot_swatches[i].color = Color(0.15, 0.15, 0.15, 0.3)
			_slot_labels[i].text = "[%d]" % (i + 1) if i < 9 else "[0]"
			_slot_counts[i].text = ""
		else:
			_slot_swatches[i].color = _get_item_color(item_id)
			_slot_labels[i].text = _get_item_short_name(item_id)
			var count: int = GameState.get_item_count(item_id)
			_slot_counts[i].text = "x%d" % count if count > 1 else ""


func _get_item_color(item_id: String) -> Color:
	var tool_data: ToolData = Database.get_tool_data(item_id)
	if tool_data:
		return tool_data.tool_color
	if item_id.ends_with("_seed"):
		var crop_id: String = item_id.substr(0, item_id.length() - 5)
		var crop: CropData = Database.get_crop(crop_id)
		if crop:
			return crop.seed_color
	var crop: CropData = Database.get_crop(item_id)
	if crop:
		return crop.crop_color
	match item_id:
		"growth_accelerant": return Color(0.2, 0.5, 0.35, 1)
		"yield_booster": return Color(0.5, 0.4, 0.15, 1)
		"quality_enhancer": return Color(0.45, 0.35, 0.15, 1)
	return Color(0.5, 0.5, 0.6, 1)


func _get_item_short_name(item_id: String) -> String:
	var tool_data: ToolData = Database.get_tool_data(item_id)
	if tool_data:
		return tool_data.display_name.substr(0, 5)
	if item_id.ends_with("_seed"):
		var crop_id: String = item_id.substr(0, item_id.length() - 5)
		var crop: CropData = Database.get_crop(crop_id)
		if crop:
			return crop.get_active_name().substr(0, 5)
		return item_id.substr(0, 5)
	return item_id.substr(0, 6)


func _on_refresh() -> void:
	_refresh()
	_pulse_active_slot()


func _pulse_active_slot() -> void:
	if GameState.active_slot < 0 or GameState.active_slot >= _slots.size():
		return
	var panel: PanelContainer = _slots[GameState.active_slot]
	var tw: Tween = create_tween()
	tw.tween_property(panel, "scale", Vector2(1.15, 1.15), 0.08)
	tw.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.12)
