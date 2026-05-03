class_name CardPanel
extends PanelContainer

var card_data: CardData
var card_index: int = -1
var selected: bool = false

var _name_label: Label
var _cost_label: Label
var _stats_label: Label
var _type_label: Label
var _keywords_label: Label
var _desc_label: Label

func _ready() -> void:
	custom_minimum_size = Vector2(145, 200)
	_build_ui()
	gui_input.connect(_on_gui_input)

func setup(data: CardData, index: int) -> void:
	card_data = data
	card_index = index
	_update_display()

var playable: bool = true

func set_playable(value: bool) -> void:
	playable = value
	modulate = Color.WHITE if value else Color(0.5, 0.5, 0.5, 0.7)

func set_selected(value: bool) -> void:
	selected = value
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	if selected:
		style.bg_color = Color(0.15, 0.45, 0.15, 0.95)
		style.border_color = Color(0.3, 1.0, 0.3)
		style.border_width_bottom = 3
		style.border_width_top = 3
		style.border_width_left = 3
		style.border_width_right = 3
	else:
		style.bg_color = Color(0.22, 0.22, 0.3, 0.95)
		style.border_color = Color(0.5, 0.5, 0.6)
		style.border_width_bottom = 2
		style.border_width_top = 2
		style.border_width_left = 2
		style.border_width_right = 2
	add_theme_stylebox_override("panel", style)

func _build_ui() -> void:
	var vbox: VBoxContainer = VBoxContainer.new()
	add_child(vbox)

	var top_row: HBoxContainer = HBoxContainer.new()
	vbox.add_child(top_row)

	_type_label = Label.new()
	_type_label.add_theme_font_size_override("font_size", 11)
	_type_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	top_row.add_child(_type_label)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer)

	_cost_label = Label.new()
	_cost_label.add_theme_font_size_override("font_size", 16)
	_cost_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	top_row.add_child(_cost_label)

	var sep1: HSeparator = HSeparator.new()
	vbox.add_child(sep1)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 14)
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_name_label)

	_stats_label = Label.new()
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_label.add_theme_font_size_override("font_size", 18)
	_stats_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	vbox.add_child(_stats_label)

	_keywords_label = Label.new()
	_keywords_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_keywords_label.add_theme_font_size_override("font_size", 11)
	_keywords_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	_keywords_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_keywords_label)

	var sep2: HSeparator = HSeparator.new()
	vbox.add_child(sep2)

	_desc_label = Label.new()
	_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc_label.add_theme_font_size_override("font_size", 10)
	_desc_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_desc_label)

	set_selected(false)

func _update_display() -> void:
	if card_data == null:
		return
	_name_label.text = card_data.display_name
	_cost_label.text = str(card_data.cost)

	if card_data is UnitData:
		var unit: UnitData = card_data as UnitData
		_type_label.text = "UNIT"
		_stats_label.text = "ATK " + str(unit.attack) + "  HP " + str(unit.health)
		_keywords_label.text = _format_keywords(unit.keywords)
		_desc_label.text = unit.description if _keywords_label.text.is_empty() else ""
	elif card_data is BuildingData:
		var building: BuildingData = card_data as BuildingData
		_type_label.text = "BUILDING"
		_stats_label.text = "HP " + str(building.health)
		_keywords_label.text = ""
		var desc: String = building.effect_text
		if not building.adjacency_text.is_empty():
			desc += "\n" + building.adjacency_text
		_desc_label.text = desc
	elif card_data is SpellData:
		var spell: SpellData = card_data as SpellData
		_type_label.text = "SPELL"
		_stats_label.text = "Track: " + str(spell.start_position)
		_keywords_label.text = ""
		_desc_label.text = spell.description

func _format_keywords(keywords: Array[KeywordData]) -> String:
	if keywords.is_empty():
		return ""
	var parts: Array[String] = []
	for kw: KeywordData in keywords:
		match kw.keyword:
			KeywordData.Keyword.HASTE:
				parts.append("Haste")
			KeywordData.Keyword.ARMOR:
				parts.append("Armor " + str(kw.value))
			KeywordData.Keyword.SIEGE:
				parts.append("Siege " + str(kw.value))
			KeywordData.Keyword.ELUSIVE:
				parts.append("Elusive")
			KeywordData.Keyword.MOBILITY:
				parts.append("Mobility " + str(kw.value))
			KeywordData.Keyword.RANGE:
				parts.append("Range " + str(kw.value))
			KeywordData.Keyword.TRIUMPH:
				parts.append("Triumph")
			KeywordData.Keyword.IMMUNE:
				parts.append("Immune")
	return ", ".join(parts)

func _on_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("click"):
		if selected:
			EventBus.card_deselected.emit()
		else:
			EventBus.card_selected.emit(card_index)
