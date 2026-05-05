extends CanvasLayer

const SHOP_ITEMS: Array[Dictionary] = [
	{"id": "steam_loco_unlock", "name": "Unlock Steam Loco", "cost": 3, "type": "train_unlock", "target": "steam_loco"},
	{"id": "pathfinder_unlock", "name": "Unlock Pathfinder", "cost": 4, "type": "builder_unlock", "target": "pathfinder"},
	{"id": "starting_gold_1", "name": "Starting Gold +50", "cost": 2, "type": "starting_gold", "value": 50.0},
	{"id": "starting_gold_2", "name": "Starting Gold +100", "cost": 3, "type": "starting_gold", "value": 100.0},
]

var _panel: PanelContainer
var _items_container: VBoxContainer
var _tickets_label: Label
var _continue_button: Button
var _summary_label: Label

signal shop_closed


func _ready() -> void:
	visible = false
	_build_ui()


func show_shop(tickets_earned: int) -> void:
	visible = true
	_summary_label.text = "Loop %d complete! Earned %d Tickets" % [GameState.loop_count, tickets_earned]
	_tickets_label.text = "Tickets: %d" % GameState.tickets
	_refresh_items()


func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.7)
	add_child(bg)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(400, 500)
	_panel.position = Vector2(-200, -250)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18, 0.95)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 20.0
	style.content_margin_right = 20.0
	style.content_margin_top = 20.0
	style.content_margin_bottom = 20.0
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	_panel.add_child(vbox)

	var title: Label = Label.new()
	title.text = "TICKET SHOP"
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_summary_label = Label.new()
	_summary_label.add_theme_font_size_override("font_size", 18)
	_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_summary_label)

	_tickets_label = Label.new()
	_tickets_label.add_theme_font_size_override("font_size", 22)
	_tickets_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	_tickets_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_tickets_label)

	var sep: HSeparator = HSeparator.new()
	vbox.add_child(sep)

	_items_container = VBoxContainer.new()
	_items_container.add_theme_constant_override("separation", 8)
	vbox.add_child(_items_container)

	var sep2: HSeparator = HSeparator.new()
	vbox.add_child(sep2)

	_continue_button = Button.new()
	_continue_button.text = "Continue to Next Loop"
	_continue_button.custom_minimum_size.y = 40.0
	_continue_button.pressed.connect(_on_continue)
	vbox.add_child(_continue_button)


func _refresh_items() -> void:
	for child: Node in _items_container.get_children():
		child.queue_free()

	for item: Dictionary in SHOP_ITEMS:
		var btn: Button = Button.new()
		var cost: int = item["cost"] as int
		var already_owned: bool = _is_owned(item)

		if already_owned:
			btn.text = "%s — OWNED" % (item["name"] as String)
			btn.disabled = true
		else:
			btn.text = "%s — %dT" % [item["name"] as String, cost]
			btn.disabled = GameState.tickets < cost

		btn.custom_minimum_size.y = 36.0
		btn.pressed.connect(_on_item_purchased.bind(item))
		_items_container.add_child(btn)


func _is_owned(item: Dictionary) -> bool:
	match item["type"] as String:
		"train_unlock":
			return GameState.unlocked_train_types.has(item["target"] as String)
		"builder_unlock":
			return GameState.unlocked_builder_types.has(item["target"] as String)
	return false


func _on_item_purchased(item: Dictionary) -> void:
	var cost: int = item["cost"] as int
	if not GameState.spend_tickets(cost):
		return

	match item["type"] as String:
		"train_unlock":
			var target: String = item["target"] as String
			if not GameState.unlocked_train_types.has(target):
				GameState.unlocked_train_types.append(target)
		"builder_unlock":
			var target: String = item["target"] as String
			if not GameState.unlocked_builder_types.has(target):
				GameState.unlocked_builder_types.append(target)
		"starting_gold":
			GameState.starting_gold_bonus += item["value"] as float

	_tickets_label.text = "Tickets: %d" % GameState.tickets
	_refresh_items()


func _on_continue() -> void:
	visible = false
	shop_closed.emit()
