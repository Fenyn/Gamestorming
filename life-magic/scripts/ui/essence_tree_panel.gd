extends ScrollContainer

@onready var row_container: VBoxContainer = %RowContainer

const GRID_X := 100.0
const GRID_Y := 110.0
const NODE_SIZE := Vector2(90, 80)
const CANVAS_MARGIN := Vector2(60, 20)

const STATE_LOCKED := 0
const STATE_UNLOCKED := 1
const STATE_PURCHASED := 2

const BRANCH_ORDER := ["verdant", "pulse", "bloom", "vital", "arcane"]

var _tree_canvas: Control
var _line_drawer: Control
var _node_controls: Dictionary = {}
var _detail_popup: PanelContainer
var _essence_label: Label
var _prestige_btn: Button
var _preview_label: Label


func _ready() -> void:
	_build_ui()
	EventBus.blessing_purchased.connect(func(_id, _lvl): _rebuild())
	EventBus.seasonal_rebirth_executed.connect(func(_e): _rebuild())
	EventBus.mana_changed.connect(func(_a, _d): _update_header())


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	row_container.add_child(margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	margin.add_child(outer)

	_build_header(outer)
	_build_prestige_section(outer)
	_add_separator(outer)
	_build_tree_view(outer)


func _build_header(parent: VBoxContainer) -> void:
	var title := Label.new()
	title.text = "Essence Tree"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", ThemeBuilder.TEXT_GOLD)
	parent.add_child(title)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	parent.add_child(hbox)

	_essence_label = Label.new()
	_essence_label.add_theme_font_size_override("font_size", 14)
	_essence_label.add_theme_color_override("font_color", ThemeBuilder.TEXT_PRIMARY)
	hbox.add_child(_essence_label)

	_update_header()


func _build_prestige_section(parent: VBoxContainer) -> void:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)
	parent.add_child(section)

	if PrestigeManager.can_prestige():
		_preview_label = Label.new()
		_preview_label.add_theme_font_size_override("font_size", 11)
		_preview_label.add_theme_color_override("font_color", ThemeBuilder.TEXT_SECONDARY)
		var preview_essence: int = PrestigeManager.calculate_essence()
		_preview_label.text = "Prestige now for +%d Essence" % preview_essence
		section.add_child(_preview_label)

		_prestige_btn = Button.new()
		_prestige_btn.text = "Begin New Life Cycle"
		_prestige_btn.custom_minimum_size = Vector2(0, 36)
		_prestige_btn.pressed.connect(_on_prestige_pressed)
		section.add_child(_prestige_btn)
	else:
		var hint := Label.new()
		hint.text = "Purchase your first Familiar to unlock the Life Cycle."
		hint.add_theme_font_size_override("font_size", 10)
		hint.add_theme_color_override("font_color", ThemeBuilder.TEXT_MUTED)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD
		section.add_child(hint)


func _build_tree_view(parent: VBoxContainer) -> void:
	var canvas_size: Vector2 = _calculate_canvas_size()

	var tree_scroll := ScrollContainer.new()
	tree_scroll.custom_minimum_size = Vector2(0, 450)
	tree_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	tree_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	parent.add_child(tree_scroll)

	_tree_canvas = Control.new()
	_tree_canvas.custom_minimum_size = canvas_size
	tree_scroll.add_child(_tree_canvas)

	_line_drawer = Control.new()
	_line_drawer.custom_minimum_size = canvas_size
	_line_drawer.draw.connect(_draw_connections)
	_tree_canvas.add_child(_line_drawer)

	_place_nodes()


func _calculate_canvas_size() -> Vector2:
	var branch_count: int = BRANCH_ORDER.size()
	var max_depth: int = 0
	for data in PrestigeManager.node_data:
		var depth: int = int(data.position.y)
		if depth > max_depth:
			max_depth = depth
	var width: float = float(branch_count) * GRID_X * 3.0 + CANVAS_MARGIN.x * 2.0
	var height: float = float(max_depth + 1) * GRID_Y + CANVAS_MARGIN.y * 2.0 + 40.0
	return Vector2(width, height)


func _get_pixel_pos(data: EssenceNodeData) -> Vector2:
	var branch_idx: int = BRANCH_ORDER.find(data.branch)
	if branch_idx < 0:
		branch_idx = 0
	var branch_center_x: float = CANVAS_MARGIN.x + float(branch_idx) * GRID_X * 3.0 + GRID_X * 1.5
	var px: float = branch_center_x + data.position.x * GRID_X
	var py: float = CANVAS_MARGIN.y + 30.0 + data.position.y * GRID_Y
	return Vector2(px, py)


func _place_nodes() -> void:
	for branch in BRANCH_ORDER:
		var branch_idx: int = BRANCH_ORDER.find(branch)
		var branch_center_x: float = CANVAS_MARGIN.x + float(branch_idx) * GRID_X * 3.0 + GRID_X * 1.5
		var branch_color: Color = ThemeBuilder.BRANCH_COLORS.get(branch, ThemeBuilder.TEXT_PRIMARY)

		var branch_label := Label.new()
		branch_label.text = branch.capitalize()
		branch_label.add_theme_font_size_override("font_size", 11)
		branch_label.add_theme_color_override("font_color", branch_color)
		branch_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		branch_label.position = Vector2(branch_center_x - 40.0, CANVAS_MARGIN.y)
		branch_label.size = Vector2(80, 20)
		_tree_canvas.add_child(branch_label)

	for data in PrestigeManager.node_data:
		var node_ctrl: PanelContainer = _create_node_control(data)
		var pos: Vector2 = _get_pixel_pos(data)
		node_ctrl.position = pos - NODE_SIZE * 0.5
		_tree_canvas.add_child(node_ctrl)
		_node_controls[data.id] = node_ctrl


func _get_node_state(node_id: String) -> int:
	if PrestigeManager.is_node_purchased(node_id):
		return STATE_PURCHASED
	if PrestigeManager.is_node_unlocked(node_id):
		return STATE_UNLOCKED
	return STATE_LOCKED


func _create_node_control(data: EssenceNodeData) -> PanelContainer:
	var state: int = _get_node_state(data.id)
	var branch_color: Color = ThemeBuilder.BRANCH_COLORS.get(data.branch, ThemeBuilder.TEXT_PRIMARY)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = NODE_SIZE

	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4

	match state:
		STATE_LOCKED:
			style.bg_color = Color(0.06, 0.06, 0.06, 0.6)
			style.border_color = Color(0.2, 0.2, 0.2, 0.4)
			style.border_width_left = 3
		STATE_UNLOCKED:
			style.bg_color = Color(branch_color.r * 0.12, branch_color.g * 0.12, branch_color.b * 0.12, 0.85)
			style.border_color = branch_color.darkened(0.3)
			style.border_width_left = 3
		STATE_PURCHASED:
			style.bg_color = Color(branch_color.r * 0.18, branch_color.g * 0.18, branch_color.b * 0.18, 0.9)
			style.border_color = branch_color
			style.border_width_left = 4
			style.border_width_bottom = 1

	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	var name_label := Label.new()
	name_label.add_theme_font_size_override("font_size", 9)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_label.custom_minimum_size = Vector2(NODE_SIZE.x - 12, 0)

	match state:
		STATE_LOCKED:
			name_label.text = "???"
			name_label.add_theme_color_override("font_color", ThemeBuilder.TEXT_DISABLED)
		_:
			name_label.text = data.display_name
			name_label.add_theme_color_override("font_color", branch_color if state == STATE_PURCHASED else ThemeBuilder.TEXT_PRIMARY)

	vbox.add_child(name_label)

	var info_label := Label.new()
	info_label.add_theme_font_size_override("font_size", 8)

	match state:
		STATE_LOCKED:
			info_label.text = ""
			info_label.add_theme_color_override("font_color", ThemeBuilder.TEXT_DISABLED)
		STATE_UNLOCKED:
			var cost: int = PrestigeManager.get_node_cost(data.id)
			info_label.text = "%d Essence" % cost
			if GameState.essence >= cost:
				info_label.add_theme_color_override("font_color", ThemeBuilder.TEXT_GREEN)
			else:
				info_label.add_theme_color_override("font_color", ThemeBuilder.TEXT_MUTED)
		STATE_PURCHASED:
			var level: int = PrestigeManager.get_blessing_level(data.id)
			if data.max_level > 1:
				info_label.text = "Lv %d/%d" % [level, data.max_level]
				if level < data.max_level:
					var cost: int = PrestigeManager.get_node_cost(data.id)
					info_label.text += "  (%d)" % cost
			else:
				info_label.text = "Owned"
			info_label.add_theme_color_override("font_color", branch_color.lightened(0.2))

	vbox.add_child(info_label)

	if state != STATE_LOCKED:
		var node_id: String = data.id
		panel.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_show_node_detail(node_id)
		)

	return panel


func _draw_connections() -> void:
	for data in PrestigeManager.node_data:
		var child_pos: Vector2 = _get_pixel_pos(data)
		for prereq_id in data.prerequisite_ids:
			var prereq_data: EssenceNodeData = PrestigeManager.get_node_data(prereq_id)
			if not prereq_data:
				continue
			var parent_pos: Vector2 = _get_pixel_pos(prereq_data)

			var child_state: int = _get_node_state(data.id)
			var parent_state: int = _get_node_state(prereq_id)
			var branch_color: Color = ThemeBuilder.BRANCH_COLORS.get(data.branch, ThemeBuilder.TEXT_PRIMARY)

			var line_color: Color
			if child_state == STATE_PURCHASED and parent_state == STATE_PURCHASED:
				line_color = branch_color
			elif child_state != STATE_LOCKED:
				line_color = branch_color.darkened(0.5)
			else:
				line_color = Color(0.2, 0.2, 0.2, 0.3)

			_line_drawer.draw_line(parent_pos, child_pos, line_color, 2.0, true)


func _show_node_detail(node_id: String) -> void:
	if _detail_popup:
		_detail_popup.queue_free()
		_detail_popup = null

	var data: EssenceNodeData = PrestigeManager.get_node_data(node_id)
	if not data:
		return

	var state: int = _get_node_state(node_id)
	var branch_color: Color = ThemeBuilder.BRANCH_COLORS.get(data.branch, ThemeBuilder.TEXT_PRIMARY)

	_detail_popup = PanelContainer.new()
	var popup_style := StyleBoxFlat.new()
	popup_style.bg_color = Color(0.06, 0.08, 0.06, 0.95)
	popup_style.border_color = branch_color
	popup_style.border_width_left = 3
	popup_style.border_width_right = 1
	popup_style.border_width_top = 1
	popup_style.border_width_bottom = 1
	popup_style.corner_radius_top_left = 8
	popup_style.corner_radius_top_right = 8
	popup_style.corner_radius_bottom_left = 8
	popup_style.corner_radius_bottom_right = 8
	popup_style.content_margin_left = 14
	popup_style.content_margin_right = 14
	popup_style.content_margin_top = 10
	popup_style.content_margin_bottom = 10
	_detail_popup.add_theme_stylebox_override("panel", popup_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_detail_popup.add_child(vbox)

	var title := Label.new()
	title.text = data.display_name
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", branch_color)
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = data.description
	desc.add_theme_font_size_override("font_size", 10)
	desc.add_theme_color_override("font_color", ThemeBuilder.TEXT_SECONDARY)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.custom_minimum_size = Vector2(220, 0)
	vbox.add_child(desc)

	var level: int = PrestigeManager.get_blessing_level(node_id)
	if data.max_level > 1:
		var level_label := Label.new()
		level_label.text = "Level %d / %d" % [level, data.max_level]
		level_label.add_theme_font_size_override("font_size", 10)
		level_label.add_theme_color_override("font_color", ThemeBuilder.TEXT_PRIMARY)
		vbox.add_child(level_label)

	if level > 0 and data.effect_value != 0.0:
		var effect_label := Label.new()
		var total_effect: float = data.effect_value * level
		effect_label.text = "Effect: +%s" % GameFormulas.format_number(total_effect)
		effect_label.add_theme_font_size_override("font_size", 10)
		effect_label.add_theme_color_override("font_color", ThemeBuilder.TEXT_GREEN)
		vbox.add_child(effect_label)

	if not PrestigeManager.is_node_maxed(node_id):
		var cost: int = PrestigeManager.get_node_cost(node_id)
		var can_afford: bool = GameState.essence >= cost

		var buy_btn := Button.new()
		if state == STATE_UNLOCKED or state == STATE_PURCHASED:
			buy_btn.text = "Upgrade — %d Essence" % cost if level > 0 else "Unlock — %d Essence" % cost
			buy_btn.disabled = not can_afford
			var nid: String = node_id
			buy_btn.pressed.connect(func():
				PrestigeManager.purchase_node(nid)
				_show_node_detail(nid)
			)
		else:
			buy_btn.text = "Locked"
			buy_btn.disabled = true

		buy_btn.custom_minimum_size = Vector2(0, 32)
		vbox.add_child(buy_btn)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(0, 28)
	close_btn.pressed.connect(func():
		if _detail_popup:
			_detail_popup.queue_free()
			_detail_popup = null
	)
	vbox.add_child(close_btn)

	_detail_popup.position = Vector2(20, 80)
	add_child(_detail_popup)


func _update_header() -> void:
	if _essence_label:
		_essence_label.text = "Essence: %d" % GameState.essence
	if _preview_label and PrestigeManager.can_prestige():
		var preview: int = PrestigeManager.calculate_essence()
		_preview_label.text = "Prestige now for +%d Essence" % preview


func _on_prestige_pressed() -> void:
	PrestigeManager.execute_prestige()


func _add_separator(parent: VBoxContainer) -> void:
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	parent.add_child(sep)


func _rebuild() -> void:
	if _detail_popup:
		_detail_popup.queue_free()
		_detail_popup = null
	_node_controls.clear()
	for child in row_container.get_children():
		row_container.remove_child(child)
		child.queue_free()
	_build_ui()
