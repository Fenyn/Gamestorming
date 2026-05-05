extends PanelContainer
class_name VoidMarbleShop

signal shop_closed()

var prestige_manager: PrestigeManager
var _container: VBoxContainer
var _header_label: Label
var _unlock_buttons: Dictionary = {}
var _upgrade_buttons: Dictionary = {}

func _ready() -> void:
	custom_minimum_size = Vector2(320, 0)
	visible = false

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	_container = VBoxContainer.new()
	_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_container)

	_header_label = Label.new()
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_label.add_theme_font_size_override("font_size", 18)
	_header_label.add_theme_color_override("font_color", Color(0.6, 0.3, 0.8))
	_container.add_child(_header_label)

func bind_prestige(pm: PrestigeManager) -> void:
	prestige_manager = pm
	prestige_manager.void_marbles_changed.connect(_refresh_all)
	_build_shop()

func show_shop() -> void:
	visible = true
	_refresh_all(prestige_manager.void_marbles)

func hide_shop() -> void:
	visible = false
	shop_closed.emit()

func _build_shop() -> void:
	# --- Piece Unlocks Section ---
	var unlock_header: Label = Label.new()
	unlock_header.text = "UNLOCK PIECES"
	unlock_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	unlock_header.add_theme_font_size_override("font_size", 14)
	unlock_header.add_theme_color_override("font_color", Color(0.9, 0.75, 0.4))
	_container.add_child(unlock_header)

	var unlock_desc: Label = Label.new()
	unlock_desc.text = "New track piece categories"
	unlock_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	unlock_desc.add_theme_font_size_override("font_size", 11)
	unlock_desc.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_container.add_child(unlock_desc)

	var sorted_cats: Array = PrestigeManager.CATEGORY_UNLOCK_COSTS.keys()
	sorted_cats.sort_custom(func(a: String, b: String) -> bool:
		return (PrestigeManager.CATEGORY_UNLOCK_COSTS[a] as int) < (PrestigeManager.CATEGORY_UNLOCK_COSTS[b] as int)
	)

	for cat_name: String in sorted_cats:
		var cost: int = PrestigeManager.CATEGORY_UNLOCK_COSTS[cat_name] as int
		if cost == 0:
			continue

		var btn: Button = Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_unlock_pressed.bind(cat_name))
		_container.add_child(btn)
		_unlock_buttons[cat_name] = btn

	var sep: HSeparator = HSeparator.new()
	_container.add_child(sep)

	# --- Passive Upgrades Section ---
	var upgrade_header: Label = Label.new()
	upgrade_header.text = "UPGRADES"
	upgrade_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	upgrade_header.add_theme_font_size_override("font_size", 14)
	upgrade_header.add_theme_color_override("font_color", Color(0.9, 0.75, 0.4))
	_container.add_child(upgrade_header)

	for upgrade: Dictionary in prestige_manager.upgrades:
		var id: String = upgrade["id"] as String

		var vbox: VBoxContainer = VBoxContainer.new()
		_container.add_child(vbox)

		var btn: Button = Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_upgrade_pressed.bind(id))
		vbox.add_child(btn)

		var desc: Label = Label.new()
		desc.text = upgrade["description"] as String
		desc.add_theme_font_size_override("font_size", 11)
		desc.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
		vbox.add_child(desc)

		_upgrade_buttons[id] = btn

	var sep2: HSeparator = HSeparator.new()
	_container.add_child(sep2)

	var close_btn: Button = Button.new()
	close_btn.text = "Continue Building"
	close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_btn.custom_minimum_size.y = 40
	close_btn.pressed.connect(hide_shop)
	_container.add_child(close_btn)

func _on_unlock_pressed(cat_name: String) -> void:
	prestige_manager.unlock_category(cat_name)

func _on_upgrade_pressed(upgrade_id: String) -> void:
	prestige_manager.purchase_upgrade(upgrade_id)

func _refresh_all(_vm_total: int = 0) -> void:
	if prestige_manager == null:
		return

	_header_label.text = "VOID MARBLES: %d" % prestige_manager.void_marbles

	# Refresh unlock buttons
	for cat_name: String in _unlock_buttons:
		var btn: Button = _unlock_buttons[cat_name] as Button
		var cost: int = prestige_manager.get_category_cost(cat_name)
		var display_name: String = cat_name.replace("_", " ").capitalize()

		if prestige_manager.is_category_unlocked(cat_name):
			btn.text = "%s  [UNLOCKED]" % display_name
			btn.disabled = true
			btn.modulate = Color(0.4, 0.7, 0.4, 0.7)
		else:
			btn.text = "%s  [%d VM]" % [display_name, cost]
			var can_buy: bool = prestige_manager.void_marbles >= cost
			btn.disabled = not can_buy
			btn.modulate = Color.WHITE if can_buy else Color(0.5, 0.5, 0.5, 0.7)

	# Refresh upgrade buttons
	for upgrade: Dictionary in prestige_manager.upgrades:
		var id: String = upgrade["id"] as String
		var btn: Button = _upgrade_buttons.get(id) as Button
		if btn == null:
			continue

		var level: int = prestige_manager.get_level(id)
		var max_level: int = upgrade["max_level"] as int
		var cost: int = prestige_manager.get_upgrade_cost(id)
		var name: String = upgrade["name"] as String

		if level >= max_level:
			btn.text = "%s  [MAX]  Lv.%d" % [name, level]
			btn.disabled = true
			btn.modulate = Color(0.4, 0.7, 0.4, 0.7)
		else:
			btn.text = "%s  [%d VM]  Lv.%d/%d" % [name, cost, level, max_level]
			var can_buy: bool = prestige_manager.can_purchase_upgrade(id)
			btn.disabled = not can_buy
			btn.modulate = Color.WHITE if can_buy else Color(0.5, 0.5, 0.5, 0.7)
