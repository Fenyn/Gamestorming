extends ScrollContainer

@onready var row_container: VBoxContainer = %RowContainer

var _rows: Dictionary = {}
var _essence_label: Label
var _prestige_section: VBoxContainer


func _ready() -> void:
	EventBus.blessing_purchased.connect(func(_id, _lvl): _rebuild())
	EventBus.mana_changed.connect(func(_a, _d): _update_prestige_section())
	EventBus.seasonal_rebirth_executed.connect(func(_e): _rebuild())
	_build_ui()


func _build_ui() -> void:
	var title := Label.new()
	title.text = "Blessings"
	title.add_theme_font_size_override("font_size", 16)
	row_container.add_child(title)

	_essence_label = Label.new()
	_essence_label.add_theme_font_size_override("font_size", 13)
	_essence_label.add_theme_color_override("font_color", ThemeBuilder.TEXT_GOLD)
	row_container.add_child(_essence_label)
	_update_essence_label()

	var desc := Label.new()
	desc.text = "Permanent upgrades purchased with Essence. These persist across Life Cycles."
	desc.add_theme_font_size_override("font_size", 10)
	desc.add_theme_color_override("font_color", ThemeBuilder.TEXT_MUTED)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	row_container.add_child(desc)

	_add_separator()
	_build_prestige_section()
	_add_separator()

	var categories := ["starting", "production", "sanctum", "wellness", "meta", "qol", "unlock"]
	var cat_labels := {
		"starting": "Starting Bonuses",
		"production": "Production",
		"sanctum": "Sanctum",
		"wellness": "Wellness",
		"meta": "Meta",
		"qol": "Quality of Life",
		"unlock": "Unlocks",
	}

	for category in categories:
		var blessings := _get_blessings_for_category(category)
		if blessings.is_empty():
			continue

		var cat_label := Label.new()
		cat_label.text = cat_labels.get(category, category)
		cat_label.add_theme_font_size_override("font_size", 13)
		cat_label.add_theme_color_override("font_color", ThemeBuilder.TEXT_GREEN)
		row_container.add_child(cat_label)

		for data in blessings:
			_add_blessing_row(data)

		_add_separator()


func _build_prestige_section() -> void:
	_prestige_section = VBoxContainer.new()
	_prestige_section.add_theme_constant_override("separation", 4)

	var header := Label.new()
	header.text = "Life Cycle"
	header.add_theme_font_size_override("font_size", 14)
	_prestige_section.add_child(header)

	var prestige_desc := Label.new()
	prestige_desc.name = "PrestigeDesc"
	prestige_desc.add_theme_font_size_override("font_size", 10)
	prestige_desc.add_theme_color_override("font_color", ThemeBuilder.TEXT_SECONDARY)
	prestige_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	_prestige_section.add_child(prestige_desc)

	var prestige_btn := Button.new()
	prestige_btn.name = "PrestigeBtn"
	prestige_btn.text = "Begin Life Cycle"
	prestige_btn.custom_minimum_size.y = 40
	prestige_btn.pressed.connect(_on_prestige_pressed)
	_prestige_section.add_child(prestige_btn)

	row_container.add_child(_prestige_section)
	_update_prestige_section()


func _update_prestige_section() -> void:
	if not _prestige_section:
		return
	var desc_node := _prestige_section.get_node_or_null("PrestigeDesc") as Label
	var btn_node := _prestige_section.get_node_or_null("PrestigeBtn") as Button

	if PrestigeManager.can_prestige():
		var essence_gain := PrestigeManager.calculate_essence()
		desc_node.text = "Sacrifice all progress to earn %d Essence. Your mana, generators, upgrades, and sanctum progress will reset. Milestones, Essence, and Blessings persist." % essence_gain
		btn_node.disabled = false
		btn_node.text = "Begin Life Cycle (+%d Essence)" % essence_gain
	else:
		desc_node.text = "Awaken all five tiers of magic to unlock the Life Cycle."
		btn_node.disabled = true
		btn_node.text = "Not Yet Available"


func _on_prestige_pressed() -> void:
	if not PrestigeManager.can_prestige():
		return
	PrestigeManager.execute_prestige()
	_rebuild()


func _add_blessing_row(data: BlessingData) -> void:
	var is_maxed := PrestigeManager.is_blessing_maxed(data.id)
	var level := PrestigeManager.get_blessing_level(data.id)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label := Label.new()
	name_label.add_theme_font_size_override("font_size", 12)
	if is_maxed:
		name_label.text = "%s (MAX)" % data.display_name
		name_label.add_theme_color_override("font_color", ThemeBuilder.TEXT_GOLD)
	else:
		name_label.text = "%s (Lv %d/%d)" % [data.display_name, level, data.max_level]
		name_label.add_theme_color_override("font_color", ThemeBuilder.TEXT_PRIMARY)
	info.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = data.description
	desc_label.add_theme_font_size_override("font_size", 9)
	desc_label.add_theme_color_override("font_color", ThemeBuilder.TEXT_MUTED)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	info.add_child(desc_label)

	row.add_child(info)

	if not is_maxed:
		var buy_btn := Button.new()
		buy_btn.text = "%d Ess" % data.essence_cost
		buy_btn.custom_minimum_size = Vector2(60, 32)
		buy_btn.disabled = GameState.essence < data.essence_cost
		var blessing_id: String = data.id
		buy_btn.pressed.connect(func(): PrestigeManager.purchase_blessing(blessing_id))
		row.add_child(buy_btn)

	row_container.add_child(row)
	_rows[data.id] = row


func _get_blessings_for_category(category: String) -> Array[BlessingData]:
	var result: Array[BlessingData] = []
	for data in PrestigeManager.blessing_data:
		if data.category == category:
			result.append(data)
	return result


func _update_essence_label() -> void:
	if _essence_label:
		_essence_label.text = "Essence: %d (Lifetime: %d) | Life Cycles: %d" % [
			GameState.essence, GameState.lifetime_essence, GameState.life_cycles
		]


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for child in row_container.get_children():
		row_container.remove_child(child)
		child.queue_free()
	_rows.clear()
	_prestige_section = null
	_essence_label = null
	_build_ui()


func _add_separator() -> void:
	var sep := HSeparator.new()
	row_container.add_child(sep)
