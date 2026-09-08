class_name UpgradeCatalog
extends StaticBody3D
## Catalog sign by the cabin. Aim at it and press E (CarrySystem routes
## interact() to any aimed collider that offers it) to open the upgrade
## panel: one row per GameManager.CATALOG entry with a buy button.
## Closing: the Close button, pressing E again, or clicking back into
## the world (which recaptures the mouse).

var _rows: Dictionary[String, Button] = {}

@onready var _ui: CanvasLayer = $CatalogUI
@onready var _items: VBoxContainer = $CatalogUI/Panel/Margin/VBox/Items
@onready var _close_button: Button = $CatalogUI/Panel/Margin/VBox/CloseButton


func _ready() -> void:
	_ui.visible = false
	_style_button(_close_button)
	_close_button.pressed.connect(_close)
	EventBus.money_changed.connect(func(_amount: int) -> void: _refresh())
	EventBus.upgrade_purchased.connect(func(_id: String) -> void: _refresh())
	_build_rows()
	_refresh()


func _process(_delta: float) -> void:
	# Clicking back into the world recaptures the mouse; treat that as
	# closing the panel.
	if _ui.visible and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_ui.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if _ui.visible and event.is_action_pressed("interact"):
		_close()
		get_viewport().set_input_as_handled()


func interact_hint() -> String:
	return "E  browse catalog"


func interact() -> void:
	_ui.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()


func _close() -> void:
	_ui.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _build_rows() -> void:
	for def in GameManager.CATALOG:
		var upgrade_id: String = String(def["id"])
		var card: PanelContainer = PanelContainer.new()
		card.add_theme_stylebox_override("panel", _card_style())
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		card.add_child(row)

		var text_box: VBoxContainer = VBoxContainer.new()
		text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var title: Label = Label.new()
		title.text = String(def["title"])
		title.add_theme_font_size_override("font_size", 18)
		title.add_theme_color_override("font_color", Color(1.0, 0.96, 0.88))
		text_box.add_child(title)
		var desc: Label = Label.new()
		desc.text = String(def["desc"])
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", 13)
		desc.modulate = Color(1.0, 1.0, 1.0, 0.65)
		text_box.add_child(desc)
		row.add_child(text_box)

		var buy: Button = Button.new()
		buy.custom_minimum_size = Vector2(116.0, 0.0)
		buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_style_button(buy)
		buy.pressed.connect(func() -> void: GameManager.purchase_upgrade(upgrade_id))
		row.add_child(buy)

		_items.add_child(card)
		_rows[upgrade_id] = buy


## Subtle raised card behind each catalog entry.
func _card_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(1.0, 1.0, 1.0, 0.04)
	style.border_color = Color(1.0, 1.0, 1.0, 0.06)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 14.0
	style.content_margin_right = 12.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style


## Wood-toned button states; the flat default reads as a mockup.
func _style_button(button: Button) -> void:
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = Color(0.42, 0.29, 0.15)
	normal.border_color = Color(0.72, 0.53, 0.29, 0.6)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(6)
	normal.content_margin_left = 14.0
	normal.content_margin_right = 14.0
	normal.content_margin_top = 7.0
	normal.content_margin_bottom = 7.0
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(0.52, 0.37, 0.2)
	hover.border_color = Color(0.85, 0.65, 0.38, 0.8)
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color(0.33, 0.22, 0.11)
	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = Color(0.22, 0.2, 0.17)
	disabled.border_color = Color(1.0, 1.0, 1.0, 0.08)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", Color(1.0, 0.93, 0.8))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.98, 0.92))
	button.add_theme_color_override("font_pressed_color", Color(0.9, 0.82, 0.68))
	button.add_theme_color_override("font_disabled_color", Color(1.0, 1.0, 1.0, 0.35))


func _refresh() -> void:
	if not _ui.visible:
		return
	for upgrade_id: String in _rows:
		var buy: Button = _rows[upgrade_id]
		if GameManager.has_upgrade(upgrade_id):
			buy.text = "Owned"
			buy.disabled = true
			buy.add_theme_color_override("font_disabled_color", Color(0.55, 0.85, 0.5, 0.9))
		else:
			var cost: int = int(GameManager.upgrade_def(upgrade_id)["cost"])
			buy.text = "Buy  $%d" % cost
			buy.disabled = GameManager.money < cost
			buy.add_theme_color_override("font_disabled_color", Color(1.0, 1.0, 1.0, 0.35))
