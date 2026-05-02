extends ScrollContainer

signal tile_pressed(panel_id: String)

@onready var row_container: VBoxContainer = %RowContainer

const TILES := [
	{"id": "upgrades", "name": "Upgrades", "desc": "Enhance your spells with raw mana", "color": Color(0.4, 0.8, 0.3)},
	{"id": "sanctums", "name": "Sanctums", "desc": "Plant sigils, tend growth, and bloom", "color": Color(0.5, 0.4, 0.9)},
	{"id": "chronicle", "name": "Chronicle", "desc": "Feats of power earned forever", "color": Color(0.9, 0.72, 0.15)},
	{"id": "blessings", "name": "Essence Tree", "desc": "Spend essence to grow permanent power", "color": Color(0.9, 0.6, 0.2)},
	{"id": "research", "name": "Arcanum", "desc": "Invest mana in arcane knowledge", "color": Color(0.3, 0.7, 0.9)},
]


func _ready() -> void:
	_build_ui()
	EventBus.milestone_earned.connect(func(_id): _rebuild())
	EventBus.loop_completed.connect(func(_c): _rebuild())
	EventBus.blessing_purchased.connect(func(_id, _lvl): _rebuild())


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	row_container.add_child(margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	margin.add_child(outer)

	var header := Label.new()
	header.text = "Grimoire"
	header.add_theme_font_size_override("font_size", 18)
	outer.add_child(header)

	var desc := Label.new()
	desc.text = "Your collected knowledge and power."
	desc.add_theme_font_size_override("font_size", 10)
	desc.add_theme_color_override("font_color", ThemeBuilder.TEXT_SECONDARY)
	outer.add_child(desc)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	outer.add_child(grid)

	for tile_data in TILES:
		if _is_visible(tile_data["id"]):
			_add_tile(grid, tile_data, true)
		elif _is_next_tease(tile_data["id"]):
			_add_tile(grid, tile_data, false)


func _is_visible(id: String) -> bool:
	match id:
		"upgrades":
			return true
		"sanctums":
			var seedbed_state: Dictionary = GameState.plots.get("seedbed", {})
			return seedbed_state.get("unlocked", false)
		"chronicle":
			return MilestoneManager.get_earned_count() > 0
		"blessings":
			return GameState.life_cycles > 0 or PrestigeManager.can_prestige()
		"research":
			return PrestigeManager.get_blessing_level("arcanum_key") > 0
	return false


func _is_next_tease(id: String) -> bool:
	match id:
		"sanctums":
			var seedbed_state: Dictionary = GameState.plots.get("seedbed", {})
			return not seedbed_state.get("unlocked", false) and PrestigeManager.is_node_purchased("sanctum_mastery")
		"chronicle":
			return MilestoneManager.get_earned_count() == 0
		"blessings":
			return MilestoneManager.get_earned_count() > 0 and not (GameState.life_cycles > 0 or PrestigeManager.can_prestige())
		"research":
			return (GameState.life_cycles > 0 or PrestigeManager.can_prestige()) and PrestigeManager.get_blessing_level("arcanum_key") == 0
	return false


func _add_tile(grid: GridContainer, data: Dictionary, unlocked: bool) -> void:
	var tile := PanelContainer.new()
	tile.custom_minimum_size = Vector2(0, 90)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var color: Color = data["color"]
	var style := StyleBoxFlat.new()
	if unlocked:
		style.bg_color = Color(color.r * 0.15, color.g * 0.15, color.b * 0.15, 0.85)
		style.border_color = color.darkened(0.3)
	else:
		style.bg_color = Color(0.06, 0.06, 0.06, 0.6)
		style.border_color = Color(0.2, 0.2, 0.2, 0.4)
	style.border_width_left = 4
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 14
	style.content_margin_right = 10
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	tile.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	tile.add_child(vbox)

	var name_label := Label.new()
	name_label.add_theme_font_size_override("font_size", 14)
	if unlocked:
		name_label.text = data["name"]
		name_label.add_theme_color_override("font_color", color)
	else:
		name_label.text = "???"
		name_label.add_theme_color_override("font_color", ThemeBuilder.TEXT_DISABLED)
	vbox.add_child(name_label)

	var desc_label := Label.new()
	desc_label.add_theme_font_size_override("font_size", 9)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	if unlocked:
		desc_label.text = data["desc"]
		desc_label.add_theme_color_override("font_color", ThemeBuilder.TEXT_SECONDARY)
	else:
		desc_label.text = _get_unlock_hint(data["id"])
		desc_label.add_theme_color_override("font_color", ThemeBuilder.TEXT_DISABLED)
	vbox.add_child(desc_label)

	if unlocked:
		var tile_id: String = data["id"]
		tile.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed:
				tile_pressed.emit(tile_id)
		)

	grid.add_child(tile)


func _get_unlock_hint(id: String) -> String:
	match id:
		"sanctums": return "Unlock in the Essence Tree"
		"chronicle": return "Earn your first milestone"
		"blessings": return "Purchase your first Familiar"
		"research": return "Unlock in the Essence Tree"
	return "Keep exploring"


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for child in row_container.get_children():
		row_container.remove_child(child)
		child.queue_free()
	_build_ui()
