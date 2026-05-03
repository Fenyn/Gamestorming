extends StaticBody3D

enum Screen { ORDER, CHARGED, WAITING_CASH, COMPLETE }

var _active := false
var _player: Player = null
var _activate_frame := -1
var _screen_state := Screen.ORDER
var _shop_mode := true

var _viewport: SubViewport = null
var _screen_mesh: MeshInstance3D = null

var _size_selected: int = -1
var _drink_selected: int = -1
var _syrup_selected: int = -1
var _sauce_selected: int = -1
var _current_tab := 0
var _pending_order: OrderData = null
var _cash_tendered := 0.0

var _day_root: Panel = null
var _size_buttons: Array[Button] = []
var _drink_buttons: Array[Button] = []
var _syrup_buttons: Array[Button] = []
var _sauce_buttons: Array[Button] = []
var _tab_buttons: Array[Button] = []
var _tab_panels: Array[PanelContainer] = []
var _order_label: Label = null
var _status_label_ui: Label = null
var _charge_btn: Button = null
var _clear_btn: Button = null
var _panel_area: Control = null
var _size_grid: GridContainer = null
var _drink_grid: GridContainer = null
var _syrup_grid: GridContainer = null
var _sauce_grid: GridContainer = null

var _shop_root: Panel = null
var _shop_tab_buttons: Array[Button] = []
var _shop_tab_panels: Array[PanelContainer] = []
var _shop_current_tab := 0
var _shop_money_label: Label = null
var _shop_stars_label: Label = null
var _shop_status_label: Label = null
var _shop_buttons: Array[Button] = []

const VIEWPORT_SIZE := Vector2i(480, 360)
const SCREEN_SIZE := Vector2(0.40, 0.30)

func _ready() -> void:
	add_to_group("station")
	_build_viewport()
	_build_screen_mesh()
	_build_day_ui()
	_build_shop_ui()
	EventBus.cash_collected.connect(_on_cash_collected)
	EventBus.change_made.connect(_on_change_made)
	EventBus.prep_started.connect(_on_prep_started)
	EventBus.day_started.connect(_on_day_started)
	_set_shop_mode(true)

func _on_prep_started() -> void:
	_set_shop_mode(true)

func _on_day_started() -> void:
	_set_shop_mode(false)
	_rebuild_day_buttons()

func _set_shop_mode(is_shop: bool) -> void:
	_shop_mode = is_shop
	if _day_root:
		_day_root.visible = not is_shop
	if _shop_root:
		_shop_root.visible = is_shop
		if is_shop:
			_refresh_shop()

# ──────────────────────────────────────────────
# VIEWPORT / SCREEN MESH
# ──────────────────────────────────────────────

func _build_viewport() -> void:
	_viewport = SubViewport.new()
	_viewport.size = VIEWPORT_SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.transparent_bg = false
	_viewport.gui_disable_input = true
	add_child(_viewport)

func _build_screen_mesh() -> void:
	_screen_mesh = $ScreenQuad as MeshInstance3D
	if not _screen_mesh:
		_screen_mesh = MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = SCREEN_SIZE
		_screen_mesh.mesh = quad
		_screen_mesh.position = Vector3(0, 0.36, -0.01)
		_screen_mesh.rotation_degrees = Vector3(-15, 180, 0)
		add_child(_screen_mesh)

# ──────────────────────────────────────────────
# DAY-MODE POS UI
# ──────────────────────────────────────────────

func _build_day_ui() -> void:
	_day_root = Panel.new()
	_day_root.size = Vector2(VIEWPORT_SIZE)
	var root_style := StyleBoxFlat.new()
	root_style.bg_color = Color(0.08, 0.1, 0.12)
	_day_root.add_theme_stylebox_override("panel", root_style)
	_viewport.add_child(_day_root)

	var title := Label.new()
	title.text = "GREEN BEAN POS"
	title.position = Vector2(140, 4)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.4, 0.85, 0.4))
	_day_root.add_child(title)

	var tab_bar := HBoxContainer.new()
	tab_bar.position = Vector2(10, 30)
	tab_bar.size = Vector2(460, 32)
	_day_root.add_child(tab_bar)
	var tab_names := ["SIZE", "DRINK", "SYRUP", "SAUCE"]
	for i in range(tab_names.size()):
		var btn := Button.new()
		btn.text = tab_names[i]
		btn.custom_minimum_size = Vector2(108, 30)
		btn.add_theme_font_size_override("font_size", 14)
		var idx := i
		btn.pressed.connect(func(): _switch_tab(idx))
		_tab_buttons.append(btn)
		tab_bar.add_child(btn)

	_panel_area = Control.new()
	_panel_area.position = Vector2(10, 68)
	_panel_area.size = Vector2(460, 140)
	_day_root.add_child(_panel_area)

	var size_panel := _make_tab_panel()
	_panel_area.add_child(size_panel)
	_tab_panels.append(size_panel)
	_size_grid = _make_button_grid()
	size_panel.add_child(_size_grid)

	var drink_panel := _make_tab_panel()
	drink_panel.visible = false
	_panel_area.add_child(drink_panel)
	_tab_panels.append(drink_panel)
	_drink_grid = _make_button_grid()
	_drink_grid.add_theme_constant_override("v_separation", 4)
	drink_panel.add_child(_drink_grid)

	var syrup_panel := _make_tab_panel()
	syrup_panel.visible = false
	_panel_area.add_child(syrup_panel)
	_tab_panels.append(syrup_panel)
	_syrup_grid = _make_button_grid()
	syrup_panel.add_child(_syrup_grid)

	var sauce_panel := _make_tab_panel()
	sauce_panel.visible = false
	_panel_area.add_child(sauce_panel)
	_tab_panels.append(sauce_panel)
	_sauce_grid = _make_button_grid()
	sauce_panel.add_child(_sauce_grid)

	_order_label = Label.new()
	_order_label.text = "Select size, then drink"
	_order_label.position = Vector2(15, 215)
	_order_label.size = Vector2(450, 60)
	_order_label.add_theme_font_size_override("font_size", 16)
	_order_label.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	_order_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_day_root.add_child(_order_label)

	_status_label_ui = Label.new()
	_status_label_ui.text = ""
	_status_label_ui.position = Vector2(15, 215)
	_status_label_ui.size = Vector2(450, 70)
	_status_label_ui.add_theme_font_size_override("font_size", 18)
	_status_label_ui.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	_status_label_ui.autowrap_mode = TextServer.AUTOWRAP_WORD
	_status_label_ui.visible = false
	_day_root.add_child(_status_label_ui)

	_clear_btn = Button.new()
	_clear_btn.text = "CLEAR"
	_clear_btn.position = Vector2(15, 295)
	_clear_btn.size = Vector2(140, 50)
	_clear_btn.add_theme_font_size_override("font_size", 16)
	_clear_btn.pressed.connect(_clear_order)
	_day_root.add_child(_clear_btn)

	_charge_btn = Button.new()
	_charge_btn.text = "CHARGE"
	_charge_btn.position = Vector2(240, 295)
	_charge_btn.size = Vector2(220, 50)
	_charge_btn.add_theme_font_size_override("font_size", 18)
	_charge_btn.pressed.connect(_charge_order)
	_day_root.add_child(_charge_btn)

	_switch_tab(0)

func _rebuild_day_buttons() -> void:
	_clear_button_array(_size_buttons, _size_grid)
	_clear_button_array(_drink_buttons, _drink_grid)
	_clear_button_array(_syrup_buttons, _syrup_grid)
	_clear_button_array(_sauce_buttons, _sauce_grid)

	for size in UnlockManager.owned_sizes:
		var btn := _make_pos_button(DrinkData.get_size_name(size as DrinkData.CupSize), Color(0.2, 0.35, 0.5))
		btn.set_meta("value", size)
		var s: int = size
		btn.pressed.connect(func(): _select_size(s))
		_size_buttons.append(btn)
		_size_grid.add_child(btn)

	for drink in UnlockManager.get_menu_drinks():
		var btn := _make_pos_button(DrinkData.get_drink_name(drink as DrinkData.DrinkType), Color(0.4, 0.25, 0.15))
		btn.custom_minimum_size.y = 38
		btn.set_meta("value", drink)
		var d: int = drink
		btn.pressed.connect(func(): _select_drink(d))
		_drink_buttons.append(btn)
		_drink_grid.add_child(btn)

	var none_syrup := _make_pos_button("None", Color(0.3, 0.3, 0.3))
	none_syrup.set_meta("value", -1)
	none_syrup.pressed.connect(func(): _select_syrup(-1))
	_syrup_buttons.append(none_syrup)
	_syrup_grid.add_child(none_syrup)
	for syrup in UnlockManager.owned_syrups:
		var btn := _make_pos_button(DrinkData.get_syrup_name(syrup as DrinkData.SyrupType), Color(0.35, 0.3, 0.15))
		btn.set_meta("value", syrup)
		var sy: int = syrup
		btn.pressed.connect(func(): _select_syrup(sy))
		_syrup_buttons.append(btn)
		_syrup_grid.add_child(btn)

	var none_sauce := _make_pos_button("None", Color(0.3, 0.3, 0.3))
	none_sauce.set_meta("value", -1)
	none_sauce.pressed.connect(func(): _select_sauce(-1))
	_sauce_buttons.append(none_sauce)
	_sauce_grid.add_child(none_sauce)
	for sauce in UnlockManager.owned_sauces:
		var btn := _make_pos_button(DrinkData.get_sauce_name(sauce as DrinkData.SauceType), Color(0.25, 0.15, 0.08))
		btn.custom_minimum_size.y = 38
		btn.set_meta("value", sauce)
		var sa: int = sauce
		btn.pressed.connect(func(): _select_sauce(sa))
		_sauce_buttons.append(btn)
		_sauce_grid.add_child(btn)

	_clear_order()

func _clear_button_array(arr: Array[Button], grid: GridContainer) -> void:
	for btn in arr:
		btn.queue_free()
	arr.clear()
	for child in grid.get_children():
		child.queue_free()

# ──────────────────────────────────────────────
# SHOP UI (prep phase)
# ──────────────────────────────────────────────

func _build_shop_ui() -> void:
	_shop_root = Panel.new()
	_shop_root.size = Vector2(VIEWPORT_SIZE)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.06)
	_shop_root.add_theme_stylebox_override("panel", style)
	_shop_root.visible = false
	_viewport.add_child(_shop_root)

	_shop_money_label = Label.new()
	_shop_money_label.position = Vector2(10, 4)
	_shop_money_label.size = Vector2(230, 24)
	_shop_money_label.add_theme_font_size_override("font_size", 16)
	_shop_money_label.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
	_shop_root.add_child(_shop_money_label)

	_shop_stars_label = Label.new()
	_shop_stars_label.position = Vector2(250, 4)
	_shop_stars_label.size = Vector2(220, 24)
	_shop_stars_label.add_theme_font_size_override("font_size", 16)
	_shop_stars_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	_shop_stars_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_shop_root.add_child(_shop_stars_label)

	var tab_bar := HBoxContainer.new()
	tab_bar.position = Vector2(10, 28)
	tab_bar.size = Vector2(460, 28)
	_shop_root.add_child(tab_bar)
	var tab_names := ["EQUIP", "UPGRADE", "MODS", "MENU"]
	for i in range(tab_names.size()):
		var btn := Button.new()
		btn.text = tab_names[i]
		btn.custom_minimum_size = Vector2(108, 26)
		btn.add_theme_font_size_override("font_size", 13)
		var idx := i
		btn.pressed.connect(func(): _switch_shop_tab(idx))
		_shop_tab_buttons.append(btn)
		tab_bar.add_child(btn)

	var content_area := Control.new()
	content_area.position = Vector2(10, 60)
	content_area.size = Vector2(460, 270)
	_shop_root.add_child(content_area)

	_build_equip_tab(content_area)
	_build_upgrade_tab(content_area)
	_build_mods_tab(content_area)
	_build_menu_tab(content_area)

	_shop_status_label = Label.new()
	_shop_status_label.position = Vector2(10, 336)
	_shop_status_label.size = Vector2(460, 20)
	_shop_status_label.add_theme_font_size_override("font_size", 13)
	_shop_status_label.add_theme_color_override("font_color", Color(0.8, 0.7, 0.5))
	_shop_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_root.add_child(_shop_status_label)

	_switch_shop_tab(0)

func _build_equip_tab(parent: Control) -> void:
	var panel := _make_shop_tab_panel()
	parent.add_child(panel)
	_shop_tab_panels.append(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)
	for id in UnlockManager.EQUIPMENT_SHOP:
		var entry: Dictionary = UnlockManager.EQUIPMENT_SHOP[id]
		var btn := _make_shop_button(entry["name"], "$%.0f" % entry["price"])
		btn.set_meta("shop_type", "equipment")
		btn.set_meta("shop_id", id)
		var eid: String = id
		btn.pressed.connect(func(): _buy_equipment(eid))
		_shop_buttons.append(btn)
		vbox.add_child(btn)

func _build_upgrade_tab(parent: Control) -> void:
	var panel := _make_shop_tab_panel()
	panel.visible = false
	parent.add_child(panel)
	_shop_tab_panels.append(panel)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 2)
	panel.add_child(grid)
	for id in UnlockManager.UPGRADE_SHOP:
		var entry: Dictionary = UnlockManager.UPGRADE_SHOP[id]
		var btn := _make_shop_button(entry["name"], "%d *" % entry["stars"])
		btn.custom_minimum_size.x = 220
		btn.set_meta("shop_type", "upgrade")
		btn.set_meta("shop_id", id)
		var uid: String = id
		btn.pressed.connect(func(): _buy_upgrade(uid))
		_shop_buttons.append(btn)
		grid.add_child(btn)

func _build_mods_tab(parent: Control) -> void:
	var panel := _make_shop_tab_panel()
	panel.visible = false
	parent.add_child(panel)
	_shop_tab_panels.append(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	for size in UnlockManager.SIZE_SHOP:
		var entry: Dictionary = UnlockManager.SIZE_SHOP[size]
		var btn := _make_shop_button(entry["name"] + " Size", "$%.0f" % entry["price"])
		btn.set_meta("shop_type", "size")
		btn.set_meta("shop_id", size)
		var sid: int = size
		btn.pressed.connect(func(): _buy_size(sid))
		_shop_buttons.append(btn)
		vbox.add_child(btn)

	var syrup_hdr := Label.new()
	syrup_hdr.text = "  Syrups (requires Syrup Rack)"
	syrup_hdr.add_theme_font_size_override("font_size", 11)
	syrup_hdr.add_theme_color_override("font_color", Color(0.6, 0.55, 0.3))
	vbox.add_child(syrup_hdr)
	for syrup in UnlockManager.SYRUP_SHOP:
		var entry: Dictionary = UnlockManager.SYRUP_SHOP[syrup]
		var btn := _make_shop_button(entry["name"] + " Syrup", "$%.0f" % entry["price"])
		btn.set_meta("shop_type", "syrup")
		btn.set_meta("shop_id", syrup)
		var syid: int = syrup
		btn.pressed.connect(func(): _buy_syrup(syid))
		_shop_buttons.append(btn)
		vbox.add_child(btn)

	var sauce_hdr := Label.new()
	sauce_hdr.text = "  Sauces (requires Sauce Station)"
	sauce_hdr.add_theme_font_size_override("font_size", 11)
	sauce_hdr.add_theme_color_override("font_color", Color(0.5, 0.35, 0.2))
	vbox.add_child(sauce_hdr)
	for sauce in UnlockManager.SAUCE_SHOP:
		var entry: Dictionary = UnlockManager.SAUCE_SHOP[sauce]
		var label_text: String = str(entry["name"]) + " Sauce"
		var cost_text: String = "$%.0f" % entry["price"] if entry["price"] > 0 else "bundled"
		var btn := _make_shop_button(label_text, cost_text)
		btn.set_meta("shop_type", "sauce")
		btn.set_meta("shop_id", sauce)
		var said: int = sauce
		btn.pressed.connect(func(): _buy_sauce(said))
		_shop_buttons.append(btn)
		vbox.add_child(btn)

func _build_menu_tab(parent: Control) -> void:
	var panel := _make_shop_tab_panel()
	panel.visible = false
	parent.add_child(panel)
	_shop_tab_panels.append(panel)

func _make_shop_tab_panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.position = Vector2.ZERO
	p.size = Vector2(460, 270)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.08)
	style.set_corner_radius_all(4)
	p.add_theme_stylebox_override("panel", style)
	return p

func _make_shop_button(item_name: String, cost_text: String) -> Button:
	var btn := Button.new()
	btn.text = "%s  [%s]" % [item_name, cost_text]
	btn.custom_minimum_size = Vector2(450, 24)
	btn.add_theme_font_size_override("font_size", 12)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.16, 0.14)
	style.set_corner_radius_all(3)
	btn.add_theme_stylebox_override("normal", style)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.2, 0.25, 0.2)
	hover.set_corner_radius_all(3)
	btn.add_theme_stylebox_override("hover", hover)
	return btn

func _refresh_shop() -> void:
	if _shop_money_label:
		_shop_money_label.text = "Money: $%.2f" % UnlockManager.money
	if _shop_stars_label:
		_shop_stars_label.text = "Stars: %d" % UnlockManager.stars

	for btn in _shop_buttons:
		var shop_type: String = btn.get_meta("shop_type", "")
		var shop_id = btn.get_meta("shop_id", "")
		var owned := false
		match shop_type:
			"equipment": owned = shop_id in UnlockManager.owned_equipment
			"upgrade": owned = shop_id in UnlockManager.owned_upgrades
			"size": owned = shop_id in UnlockManager.owned_sizes
			"syrup": owned = shop_id in UnlockManager.owned_syrups
			"sauce": owned = shop_id in UnlockManager.owned_sauces
		if owned:
			btn.text = btn.text.split("  [")[0] + "  [OWNED]"
			btn.disabled = true
			btn.modulate = Color(0.5, 0.6, 0.5)
		else:
			btn.disabled = false
			btn.modulate = Color(1, 1, 1)

	_rebuild_menu_tab()

func _rebuild_menu_tab() -> void:
	if _shop_tab_panels.size() < 4:
		return
	var panel := _shop_tab_panels[3]
	for child in panel.get_children():
		child.queue_free()
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	panel.add_child(vbox)

	var hdr := Label.new()
	hdr.text = "  Toggle drinks on your menu:"
	hdr.add_theme_font_size_override("font_size", 12)
	hdr.add_theme_color_override("font_color", Color(0.7, 0.7, 0.6))
	vbox.add_child(hdr)

	for drink in UnlockManager.get_unlocked_drinks():
		var active := UnlockManager.is_drink_active(drink)
		var check := "X" if active else " "
		var dname := DrinkData.get_drink_name(drink as DrinkData.DrinkType)
		var btn := Button.new()
		btn.text = " [%s] %s" % [check, dname]
		btn.custom_minimum_size = Vector2(450, 28)
		btn.add_theme_font_size_override("font_size", 13)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var color := Color(0.2, 0.3, 0.2) if active else Color(0.15, 0.15, 0.15)
		var style := StyleBoxFlat.new()
		style.bg_color = color
		style.set_corner_radius_all(3)
		btn.add_theme_stylebox_override("normal", style)
		var hover := StyleBoxFlat.new()
		hover.bg_color = color.lightened(0.15)
		hover.set_corner_radius_all(3)
		btn.add_theme_stylebox_override("hover", hover)
		var did: int = drink
		btn.pressed.connect(func(): _toggle_menu(did))
		vbox.add_child(btn)

func _switch_shop_tab(idx: int) -> void:
	_shop_current_tab = idx
	for i in range(_shop_tab_panels.size()):
		_shop_tab_panels[i].visible = (i == idx)
	for i in range(_shop_tab_buttons.size()):
		_shop_tab_buttons[i].modulate = Color(1, 1, 1) if i == idx else Color(0.6, 0.6, 0.6)

# ──────────────────────────────────────────────
# SHOP PURCHASE ACTIONS
# ──────────────────────────────────────────────

func _buy_equipment(id: String) -> void:
	if UnlockManager.buy_equipment(id):
		var entry: Dictionary = UnlockManager.EQUIPMENT_SHOP[id]
		_shop_status("Bought %s!" % entry["name"])
	else:
		_shop_status("Can't afford that.")
	_refresh_shop()

func _buy_upgrade(id: String) -> void:
	if UnlockManager.buy_upgrade(id):
		var entry: Dictionary = UnlockManager.UPGRADE_SHOP[id]
		_shop_status("Upgraded to %s!" % entry["name"])
	else:
		_shop_status("Not enough stars.")
	_refresh_shop()

func _buy_size(size: int) -> void:
	if UnlockManager.buy_size(size):
		_shop_status("Unlocked new size!")
	else:
		_shop_status("Can't afford that.")
	_refresh_shop()

func _buy_syrup(syrup: int) -> void:
	if "syrup_rack" not in UnlockManager.owned_equipment:
		_shop_status("Need Syrup Rack first!")
		return
	if UnlockManager.buy_syrup(syrup):
		var entry: Dictionary = UnlockManager.SYRUP_SHOP[syrup]
		_shop_status("Unlocked %s syrup!" % entry["name"])
	else:
		_shop_status("Can't afford that.")
	_refresh_shop()

func _buy_sauce(sauce: int) -> void:
	var entry: Dictionary = UnlockManager.SAUCE_SHOP[sauce]
	if entry.get("bundled", "") != "":
		_shop_status("Bundled with %s." % entry["bundled"].replace("_", " ").capitalize())
		return
	if "sauce_station" not in UnlockManager.owned_equipment:
		_shop_status("Need Sauce Station first!")
		return
	if UnlockManager.buy_sauce(sauce):
		_shop_status("Unlocked %s!" % entry["name"])
	else:
		_shop_status("Can't afford that.")
	_refresh_shop()

func _toggle_menu(drink: int) -> void:
	UnlockManager.toggle_menu_drink(drink)
	_rebuild_menu_tab()

func _shop_status(msg: String) -> void:
	if _shop_status_label:
		_shop_status_label.text = msg

# ──────────────────────────────────────────────
# DAY-MODE POS SELECTION LOGIC
# ──────────────────────────────────────────────

func _switch_tab(idx: int) -> void:
	_current_tab = idx
	for i in range(_tab_panels.size()):
		_tab_panels[i].visible = (i == idx)
	for i in range(_tab_buttons.size()):
		_tab_buttons[i].modulate = Color(1, 1, 1) if i == idx else Color(0.6, 0.6, 0.6)

func _select_size(size: int) -> void:
	_size_selected = size
	_highlight_selected(_size_buttons, size)
	SoundManager.play("register_beep")
	_update_display()
	_switch_tab(1)

func _select_drink(drink: int) -> void:
	_drink_selected = drink
	_highlight_selected(_drink_buttons, drink)
	SoundManager.play("register_beep")
	_update_display()
	_switch_tab(2)

func _select_syrup(syrup: int) -> void:
	_syrup_selected = syrup
	_highlight_selected(_syrup_buttons, syrup)
	SoundManager.play("register_beep")
	_update_display()

func _select_sauce(sauce: int) -> void:
	_sauce_selected = sauce
	_highlight_selected(_sauce_buttons, sauce)
	SoundManager.play("register_beep")
	_update_display()

func _highlight_selected(buttons: Array[Button], selected_value: int) -> void:
	for btn in buttons:
		if btn.get_meta("value", -99) == selected_value:
			btn.modulate = Color(1.3, 1.3, 1.3)
		else:
			btn.modulate = Color(1, 1, 1)

func _clear_order() -> void:
	_size_selected = -1
	_drink_selected = -1
	_syrup_selected = -1
	_sauce_selected = -1
	_pending_order = null
	_cash_tendered = 0.0
	_screen_state = Screen.ORDER
	_highlight_selected(_size_buttons, -1)
	_highlight_selected(_drink_buttons, -1)
	_highlight_selected(_syrup_buttons, -1)
	_highlight_selected(_sauce_buttons, -1)
	_switch_tab(0)
	_show_order_screen()
	_update_display()

func _update_display() -> void:
	if not _order_label:
		return
	if _size_selected < 0 and _drink_selected < 0:
		_order_label.text = "Select size, then drink"
		return
	var parts: Array[String] = []
	if _size_selected >= 0:
		parts.append(DrinkData.get_size_name(_size_selected as DrinkData.CupSize))
	if _syrup_selected >= 0:
		parts.append(DrinkData.get_syrup_name(_syrup_selected as DrinkData.SyrupType))
	if _sauce_selected >= 0:
		parts.append(DrinkData.get_sauce_name(_sauce_selected as DrinkData.SauceType))
	if _drink_selected >= 0:
		parts.append(DrinkData.get_drink_name(_drink_selected as DrinkData.DrinkType))
	var text := " ".join(parts)
	if _size_selected >= 0 and _drink_selected >= 0:
		var size_enum: DrinkData.CupSize = _size_selected
		var drink_enum: DrinkData.DrinkType = _drink_selected
		var price := DrinkData.get_base_price(drink_enum, size_enum)
		var code := DrinkData.get_ticket_code(drink_enum, size_enum)
		if _syrup_selected >= 0:
			price += DrinkData.SYRUP_UPCHARGE
			code += " " + DrinkData.get_syrup_code(_syrup_selected as DrinkData.SyrupType)
		if _sauce_selected >= 0 and not DrinkData.has_step(drink_enum, DrinkData.Step.ADD_SAUCE):
			price += DrinkData.SAUCE_UPCHARGE
		if _sauce_selected >= 0:
			code += " " + DrinkData.get_sauce_code(_sauce_selected as DrinkData.SauceType)
		text += "\n[%s]  Total: $%.2f" % [code, price]
	_order_label.text = text

func _charge_order() -> void:
	if _size_selected < 0 or _drink_selected < 0:
		return
	var size_enum: DrinkData.CupSize = _size_selected
	var drink_enum: DrinkData.DrinkType = _drink_selected
	_pending_order = OrderData.new(drink_enum, size_enum)
	if _syrup_selected >= 0:
		_pending_order.set_syrup(_syrup_selected as DrinkData.SyrupType)
	if _sauce_selected >= 0:
		_pending_order.set_sauce(_sauce_selected as DrinkData.SauceType)
	_screen_state = Screen.CHARGED
	SoundManager.play("register_charge")
	EventBus.order_charged.emit({
		"order": _pending_order,
		"drink_type": drink_enum,
		"cup_size": size_enum,
	})
	_show_charged_screen()

func _show_order_screen() -> void:
	_panel_area.visible = true
	_order_label.visible = true
	_charge_btn.visible = true
	_clear_btn.visible = true
	_status_label_ui.visible = false
	for btn in _tab_buttons:
		btn.visible = true

func _show_charged_screen() -> void:
	_panel_area.visible = false
	_order_label.visible = false
	_charge_btn.visible = false
	_clear_btn.visible = false
	_status_label_ui.visible = true
	for btn in _tab_buttons:
		btn.visible = false
	var price := _pending_order.base_price
	var bill := _get_bill_amount(price)
	var drink_desc: String = DrinkData.get_size_name(_size_selected as DrinkData.CupSize)
	if _syrup_selected >= 0:
		drink_desc += " " + DrinkData.get_syrup_name(_syrup_selected as DrinkData.SyrupType)
	if _sauce_selected >= 0:
		drink_desc += " " + DrinkData.get_sauce_name(_sauce_selected as DrinkData.SauceType)
	drink_desc += " " + DrinkData.get_drink_name(_drink_selected as DrinkData.DrinkType)
	_status_label_ui.text = "%s\nTotal: $%.2f\n\nCollect $%.2f from customer" % [
		drink_desc, price, bill
	]

func _get_bill_amount(price: float) -> float:
	if price <= 5.0: return 5.0
	if price <= 10.0: return 10.0
	return 20.0

func _on_cash_collected(_customer: Node3D, amount: float) -> void:
	if _screen_state != Screen.CHARGED or not _pending_order:
		return
	_cash_tendered = amount
	_screen_state = Screen.WAITING_CASH
	var change := _cash_tendered - _pending_order.base_price
	_status_label_ui.text = "Cash: $%.2f\nTotal: $%.2f\nChange: $%.2f\n\nUse cash drawer to make change" % [
		_cash_tendered, _pending_order.base_price, change
	]

func _on_change_made(_amount: float) -> void:
	if _screen_state != Screen.WAITING_CASH or not _pending_order:
		return
	_screen_state = Screen.COMPLETE
	EventBus.order_submitted.emit({
		"order": _pending_order,
		"drink_type": _pending_order.drink_type,
		"cup_size": _pending_order.cup_size,
		"ticket_code": _pending_order.ticket_code,
	})
	EventBus.ticket_printed.emit({
		"order": _pending_order,
		"ticket_code": _pending_order.ticket_code,
	})
	_status_label_ui.text = "ORDER SENT!\nTicket printed."
	var timer := get_tree().create_timer(1.5)
	timer.timeout.connect(_clear_order)

# ──────────────────────────────────────────────
# SHARED UI HELPERS
# ──────────────────────────────────────────────

func _make_tab_panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.position = Vector2.ZERO
	p.size = Vector2(460, 140)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.15, 0.18)
	style.set_corner_radius_all(4)
	p.add_theme_stylebox_override("panel", style)
	return p

func _make_button_grid() -> GridContainer:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	return g

func _make_pos_button(text: String, color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(210, 55)
	btn.add_theme_font_size_override("font_size", 16)
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", style)
	var hover := StyleBoxFlat.new()
	hover.bg_color = color.lightened(0.2)
	hover.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed_s := StyleBoxFlat.new()
	pressed_s.bg_color = color.lightened(0.4)
	pressed_s.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("pressed", pressed_s)
	return btn

# ──────────────────────────────────────────────
# INTERACTION & INPUT
# ──────────────────────────────────────────────

func interact(player: Player) -> void:
	if _active:
		_deactivate()
		return
	_active = true
	_activate_frame = Engine.get_process_frames()
	_player = player
	var look_range := 0.55 if _shop_mode else 0.35
	_player.enter_screen_mode(_screen_mesh.global_position, global_position + Vector3(0, 0.30, -0.40), look_range)

func _deactivate() -> void:
	if not _active:
		return
	_active = false
	if _player and is_instance_valid(_player):
		_player.exit_screen_mode()
		_player = null

func _input(event: InputEvent) -> void:
	if not _active:
		return

	if event.is_action_pressed("interact"):
		if Engine.get_process_frames() != _activate_frame:
			_deactivate()
			get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var pixel := _get_crosshair_pixel()
		if pixel.x >= 0:
			if _shop_mode:
				_click_at_shop(pixel)
			else:
				_click_at(pixel)
		get_viewport().set_input_as_handled()

	if not _shop_mode and event is InputEventKey and event.pressed and not event.echo:
		if _screen_state == Screen.ORDER:
			match event.keycode:
				KEY_ENTER: _charge_order()
				KEY_BACKSPACE: _clear_order()

func _process(_delta: float) -> void:
	_update_screen_texture()

func _update_screen_texture() -> void:
	if _screen_mesh and _viewport:
		var mat := _screen_mesh.get_surface_override_material(0)
		if not mat:
			mat = StandardMaterial3D.new()
			mat.albedo_color = Color.WHITE
			mat.emission_enabled = true
			mat.emission = Color(0.3, 0.3, 0.3)
			_screen_mesh.set_surface_override_material(0, mat)
		if mat is StandardMaterial3D:
			mat.albedo_texture = _viewport.get_texture()
			mat.emission_texture = _viewport.get_texture()

func _get_crosshair_pixel() -> Vector2:
	if not _player or not _screen_mesh:
		return Vector2(-1, -1)
	var camera := _player.camera
	var screen_center := get_viewport().get_visible_rect().size / 2.0
	var ray_origin := camera.project_ray_origin(screen_center)
	var ray_dir := camera.project_ray_normal(screen_center)

	var screen_normal := _screen_mesh.global_transform.basis.z.normalized()
	var screen_pos := _screen_mesh.global_position
	var denom := screen_normal.dot(ray_dir)
	if absf(denom) < 0.0001:
		return Vector2(-1, -1)
	var t := screen_normal.dot(screen_pos - ray_origin) / denom
	if t < 0:
		return Vector2(-1, -1)
	var hit_point := ray_origin + ray_dir * t

	var screen_right := _screen_mesh.global_transform.basis.x.normalized()
	var screen_up := _screen_mesh.global_transform.basis.y.normalized()
	var offset := hit_point - screen_pos
	var u := offset.dot(screen_right)
	var v := offset.dot(screen_up)
	var uv_x := u / SCREEN_SIZE.x + 0.5
	var uv_y := 0.5 - v / SCREEN_SIZE.y

	if uv_x < 0 or uv_x > 1 or uv_y < 0 or uv_y > 1:
		return Vector2(-1, -1)
	return Vector2(uv_x * VIEWPORT_SIZE.x, uv_y * VIEWPORT_SIZE.y)

func _click_at(pixel: Vector2) -> void:
	if _screen_state != Screen.ORDER:
		return
	if _charge_btn and _charge_btn.visible:
		if _charge_btn.get_global_rect().has_point(pixel):
			_charge_order()
			return
	if _clear_btn and _clear_btn.visible:
		if _clear_btn.get_global_rect().has_point(pixel):
			_clear_order()
			return
	for btn in _tab_buttons:
		if btn.visible and btn.get_global_rect().has_point(pixel):
			_switch_tab(_tab_buttons.find(btn))
			return
	for btn in _size_buttons:
		if btn.is_visible_in_tree() and btn.get_global_rect().has_point(pixel):
			_select_size(btn.get_meta("value"))
			return
	for btn in _drink_buttons:
		if btn.is_visible_in_tree() and btn.get_global_rect().has_point(pixel):
			_select_drink(btn.get_meta("value"))
			return
	for btn in _syrup_buttons:
		if btn.is_visible_in_tree() and btn.get_global_rect().has_point(pixel):
			_select_syrup(btn.get_meta("value"))
			return
	for btn in _sauce_buttons:
		if btn.is_visible_in_tree() and btn.get_global_rect().has_point(pixel):
			_select_sauce(btn.get_meta("value"))
			return

func _click_at_shop(pixel: Vector2) -> void:
	for btn in _shop_tab_buttons:
		if btn.visible and btn.get_global_rect().has_point(pixel):
			_switch_shop_tab(_shop_tab_buttons.find(btn))
			return
	for btn in _shop_buttons:
		if btn.is_visible_in_tree() and not btn.disabled and btn.get_global_rect().has_point(pixel):
			btn.emit_signal("pressed")
			return
	if _shop_tab_panels.size() >= 4 and _shop_current_tab == 3:
		var menu_panel := _shop_tab_panels[3]
		for child in menu_panel.get_children():
			if child is VBoxContainer:
				for sub in child.get_children():
					if sub is Button and sub.get_global_rect().has_point(pixel):
						sub.emit_signal("pressed")
						return
