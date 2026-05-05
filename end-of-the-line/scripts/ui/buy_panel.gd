extends Control

var _container: VBoxContainer


func _ready() -> void:
	_build_ui()
	EventBus.gold_changed.connect(_refresh_buttons)
	EventBus.loop_reset.connect(_on_loop_reset)


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	custom_minimum_size = Vector2(220, 0)
	position = Vector2(-240, -200)

	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.85)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	_container = VBoxContainer.new()
	_container.add_theme_constant_override("separation", 8)
	panel.add_child(_container)

	var title: Label = Label.new()
	title.text = "— PURCHASE —"
	title.add_theme_font_size_override("font_size", 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_container.add_child(title)

	_add_section_label("Trains")
	_add_buy_button("handcar", "Handcar", true)
	_add_buy_button("steam_loco", "Steam Loco", true)

	_add_section_label("Builders")
	_add_buy_button("track_layer", "Track Layer", false)
	_add_buy_button("pathfinder", "Pathfinder", false)


func _add_section_label(text: String) -> void:
	var sep: HSeparator = HSeparator.new()
	_container.add_child(sep)
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_container.add_child(label)


func _add_buy_button(type_id: String, display_name: String, is_train: bool) -> void:
	var btn: Button = Button.new()
	btn.name = "Btn_" + type_id
	btn.custom_minimum_size.y = 36.0
	btn.pressed.connect(_on_buy_pressed.bind(type_id, is_train))
	_container.add_child(btn)
	_update_button(btn, type_id, is_train)


func _update_button(btn: Button, type_id: String, is_train: bool) -> void:
	var unlocked: bool
	var owned: int
	var base_cost: float = 0.0
	var cost_mult: float = 1.0

	if is_train:
		unlocked = GameState.unlocked_train_types.has(type_id)
		owned = GameState.owned_trains.get(type_id, 0) as int
		var train_data: TrainTypeData = TrainManager.train_types.get(type_id) as TrainTypeData
		if train_data:
			base_cost = train_data.base_cost
			cost_mult = train_data.cost_multiplier
	else:
		unlocked = GameState.unlocked_builder_types.has(type_id)
		owned = GameState.owned_builders.get(type_id, 0) as int
		var builder_data: BuilderTypeData = BuilderManager.builder_types.get(type_id) as BuilderTypeData
		if builder_data:
			base_cost = builder_data.base_cost
			cost_mult = builder_data.cost_multiplier

	if not unlocked:
		btn.text = "LOCKED"
		btn.disabled = true
		return

	var cost: float = GameFormulas.purchase_cost(base_cost, cost_mult, owned)
	var display_name: String = btn.name.replace("Btn_", "").replace("_", " ").capitalize()

	if cost <= 0.0:
		btn.text = "%s (FREE) [%d]" % [display_name, owned]
		btn.disabled = false
	else:
		btn.text = "%s (%s) [%d]" % [display_name, GameFormulas.format_gold(cost), owned]
		btn.disabled = GameState.gold < cost


func _on_buy_pressed(type_id: String, is_train: bool) -> void:
	if is_train:
		TrainManager.purchase_train(type_id)
	else:
		BuilderManager.purchase_builder(type_id)
	_refresh_buttons(GameState.gold)


func _refresh_buttons(_gold: float) -> void:
	for child: Node in _container.get_children():
		if child is Button:
			var btn: Button = child as Button
			var type_id: String = btn.name.replace("Btn_", "")
			var is_train: bool = TrainManager.train_types.has(type_id)
			_update_button(btn, type_id, is_train)


func _on_loop_reset(_tickets: int) -> void:
	_refresh_buttons(GameState.gold)
