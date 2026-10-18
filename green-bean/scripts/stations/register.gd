extends StaticBody3D

enum Screen { ORDER, CHARGED, WAITING_CASH, COMPLETE }

var _active := false
var _player: Player = null
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
var _status_box: VBoxContainer = null
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
## POS screen type sizes (the screen is 480 x 360 pixels).
## Index of the menu tab in the prep shop.
const MENU_TAB := 4
const POS_SMALL := 14
const POS_BODY := 17
const POS_LEAD := 20
const POS_BIG := 34
var _status_title: Label = null
var _status_amount: Label = null
var _status_note: Label = null
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
	_update_screen_texture()

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
	_day_root.add_theme_stylebox_override("panel", StyleFactory.flat_no_border(UiStyle.ROAST, 0, 0))
	_viewport.add_child(_day_root)

	var tab_bar := HBoxContainer.new()
	tab_bar.position = Vector2(10, 12)
	tab_bar.size = Vector2(460, 36)
	tab_bar.add_theme_constant_override("separation", 6)
	_day_root.add_child(tab_bar)
	var tab_names := ["Size", "Drink", "Syrup", "Sauce"]
	for i in range(tab_names.size()):
		var btn := _make_tab_button(tab_names[i])
		var idx := i
		btn.pressed.connect(func(): _switch_tab(idx))
		_tab_buttons.append(btn)
		tab_bar.add_child(btn)

	_panel_area = Control.new()
	_panel_area.position = Vector2(10, 58)
	_panel_area.size = Vector2(460, 150)
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

	_order_label = _pos_label("", POS_LEAD, UiStyle.W_BOLD, UiStyle.CREMA)
	_order_label.position = Vector2(14, 218)
	_order_label.size = Vector2(452, 64)
	_order_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_day_root.add_child(_order_label)

	# Charged / change / sent screens: what, how much, what to do next.
	var status_box := VBoxContainer.new()
	status_box.position = Vector2(14, 70)
	status_box.size = Vector2(452, 220)
	status_box.alignment = BoxContainer.ALIGNMENT_CENTER
	status_box.add_theme_constant_override("separation", 6)
	status_box.visible = false
	_day_root.add_child(status_box)
	_status_title = _pos_label("", POS_LEAD, UiStyle.W_BOLD, UiStyle.STEAM)
	_status_amount = _pos_label("", POS_BIG + 12, UiStyle.W_BLACK, UiStyle.CREMA)
	_status_note = _pos_label("", POS_BODY, UiStyle.W_BOLD, UiStyle.SAGE)
	for l in [_status_title, _status_amount, _status_note]:
		(l as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_box.add_child(l)
	_status_box = status_box

	_clear_btn = Button.new()
	_clear_btn.text = "Clear"
	_clear_btn.position = Vector2(14, 292)
	_clear_btn.size = Vector2(150, 54)
	_style_button(_clear_btn, UiStyle.ROAST_RAISED, POS_LEAD)
	_clear_btn.pressed.connect(_clear_order)
	_day_root.add_child(_clear_btn)

	_charge_btn = Button.new()
	_charge_btn.text = "Charge"
	_charge_btn.position = Vector2(176, 292)
	_charge_btn.size = Vector2(290, 54)
	_style_button(_charge_btn, UiStyle.OLIVE, POS_LEAD)
	_charge_btn.pressed.connect(_charge_order)
	_day_root.add_child(_charge_btn)

	_switch_tab(0)

func _rebuild_day_buttons() -> void:
	_clear_button_array(_size_buttons, _size_grid)
	_clear_button_array(_drink_buttons, _drink_grid)
	_clear_button_array(_syrup_buttons, _syrup_grid)
	_clear_button_array(_sauce_buttons, _sauce_grid)

	for size in UnlockManager.owned_sizes:
		var btn := _make_pos_button(DrinkData.get_size_name(size as DrinkData.CupSize))
		btn.set_meta("value", size)
		var s: int = size
		btn.pressed.connect(func(): _select_size(s))
		_size_buttons.append(btn)
		_size_grid.add_child(btn)

	for drink in UnlockManager.get_menu_drinks():
		var btn := _make_pos_button(DrinkData.get_drink_name(drink as DrinkData.DrinkType))
		btn.custom_minimum_size.y = 40
		btn.set_meta("value", drink)
		var d: int = drink
		btn.pressed.connect(func(): _select_drink(d))
		_drink_buttons.append(btn)
		_drink_grid.add_child(btn)

	var none_syrup := _make_pos_button("None")
	none_syrup.set_meta("value", -1)
	none_syrup.pressed.connect(func(): _select_syrup(-1))
	_syrup_buttons.append(none_syrup)
	_syrup_grid.add_child(none_syrup)
	for syrup in UnlockManager.owned_syrups:
		var btn := _make_pos_button(DrinkData.get_syrup_name(syrup as DrinkData.SyrupType))
		btn.set_meta("value", syrup)
		var sy: int = syrup
		btn.pressed.connect(func(): _select_syrup(sy))
		_syrup_buttons.append(btn)
		_syrup_grid.add_child(btn)

	var none_sauce := _make_pos_button("None")
	none_sauce.set_meta("value", -1)
	none_sauce.pressed.connect(func(): _select_sauce(-1))
	_sauce_buttons.append(none_sauce)
	_sauce_grid.add_child(none_sauce)
	for sauce in UnlockManager.owned_sauces:
		var btn := _make_pos_button(DrinkData.get_sauce_name(sauce as DrinkData.SauceType))
		btn.custom_minimum_size.y = 40
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
	_shop_root.add_theme_stylebox_override("panel", StyleFactory.flat_no_border(UiStyle.ROAST, 0, 0))
	_shop_root.visible = false
	_viewport.add_child(_shop_root)

	# Bank and stars on one line: money left, stars right.
	_shop_money_label = _pos_label("", POS_LEAD, UiStyle.W_BLACK, UiStyle.CREMA)
	_shop_money_label.position = Vector2(14, 8)
	_shop_money_label.size = Vector2(220, 28)
	_shop_root.add_child(_shop_money_label)
	var stars_row := HBoxContainer.new()
	stars_row.position = Vector2(250, 8)
	stars_row.size = Vector2(216, 28)
	stars_row.alignment = BoxContainer.ALIGNMENT_END
	stars_row.add_theme_constant_override("separation", 4)
	stars_row.add_child(UiIcon.make(UiIcon.Kind.STAR_FULL, UiStyle.AMBER, 20))
	_shop_stars_label = _pos_label("", POS_LEAD, UiStyle.W_BLACK, UiStyle.CREMA)
	stars_row.add_child(_shop_stars_label)
	_shop_root.add_child(stars_row)

	var tab_bar := HBoxContainer.new()
	tab_bar.position = Vector2(10, 44)
	tab_bar.size = Vector2(460, 32)
	tab_bar.add_theme_constant_override("separation", 6)
	_shop_root.add_child(tab_bar)
	var tab_names := ["Equipment", "Upgrades", "Cups, syrups", "Sauces", "Menu"]
	for i in range(tab_names.size()):
		var btn := _make_tab_button(tab_names[i], POS_SMALL + 1)
		var idx := i
		btn.pressed.connect(func(): _switch_shop_tab(idx))
		_shop_tab_buttons.append(btn)
		tab_bar.add_child(btn)

	var content_area := Control.new()
	content_area.position = Vector2(10, 84)
	content_area.size = Vector2(460, 246)
	_shop_root.add_child(content_area)

	_build_equip_tab(content_area)
	_build_upgrade_tab(content_area)
	_build_mods_tab(content_area)
	_build_sauce_tab(content_area)
	_build_menu_tab(content_area)

	_shop_status_label = _pos_label("", POS_SMALL, UiStyle.W_BOLD, UiStyle.STEAM)
	_shop_status_label.position = Vector2(10, 334)
	_shop_status_label.size = Vector2(460, 20)
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
		var btn := _make_shop_button(entry["name"], "%d stars" % entry["stars"])
		btn.custom_minimum_size.x = 224
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
		var btn := _make_shop_button("%s cups" % entry["name"], "$%.0f" % entry["price"])
		btn.set_meta("shop_type", "size")
		btn.set_meta("shop_id", size)
		var sid: int = size
		btn.pressed.connect(func(): _buy_size(sid))
		_shop_buttons.append(btn)
		vbox.add_child(btn)

	vbox.add_child(_shop_header("Syrups, for the syrup rack"))
	for syrup in UnlockManager.SYRUP_SHOP:
		var entry: Dictionary = UnlockManager.SYRUP_SHOP[syrup]
		var btn := _make_shop_button("%s syrup" % entry["name"], "$%.0f" % entry["price"])
		btn.set_meta("shop_type", "syrup")
		btn.set_meta("shop_id", syrup)
		var syid: int = syrup
		btn.pressed.connect(func(): _buy_syrup(syid))
		_shop_buttons.append(btn)
		vbox.add_child(btn)


func _build_sauce_tab(parent: Control) -> void:
	var panel := _make_shop_tab_panel()
	panel.visible = false
	parent.add_child(panel)
	_shop_tab_panels.append(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)
	vbox.add_child(_shop_header("For the drizzle station"))
	for sauce in UnlockManager.SAUCE_SHOP:
		var entry: Dictionary = UnlockManager.SAUCE_SHOP[sauce]
		var sauce_name: String = str(entry["name"])
		var label_text := "%s sauce" % sauce_name.trim_suffix(" Sauce")
		var cost_text: String = "$%.0f" % entry["price"] if entry["price"] > 0 else "Included"
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
	p.size = Vector2(460, 246)
	p.add_theme_stylebox_override("panel", StyleFactory.flat_no_border(Color.TRANSPARENT, 0, 0))
	return p

func _shop_header(text: String) -> Label:
	var l := _pos_label(text, POS_SMALL, UiStyle.W_BOLD, UiStyle.STEAM)
	l.custom_minimum_size.y = 22
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return l

## Shop row: the item on the left, its price (or Owned) on the right.
func _make_shop_button(item_name: String, cost_text: String) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(458, 28)
	_style_button(btn, UiStyle.ROAST_RAISED, POS_BODY)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_right = -10
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var n := _pos_label(item_name, POS_BODY, UiStyle.W_BOLD, UiStyle.CREMA)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var c := _pos_label(cost_text, POS_BODY, UiStyle.W_BLACK, UiStyle.SAGE)
	c.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(n)
	row.add_child(c)
	btn.add_child(row)
	btn.set_meta("cost_label", c)
	btn.set_meta("cost_text", cost_text)
	return btn

func _refresh_shop() -> void:
	if _shop_money_label:
		_shop_money_label.text = "$%.2f" % UnlockManager.money
	if _shop_stars_label:
		_shop_stars_label.text = str(UnlockManager.stars)

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
		var cost := btn.get_meta("cost_label") as Label
		btn.disabled = owned
		cost.text = "Owned" if owned else str(btn.get_meta("cost_text"))
		cost.add_theme_color_override("font_color", UiStyle.STEAM if owned else UiStyle.SAGE)
		btn.modulate = Color(1, 1, 1, 0.6) if owned else Color.WHITE

	_rebuild_menu_tab()

func _rebuild_menu_tab() -> void:
	if _shop_tab_panels.size() <= MENU_TAB:
		return
	var panel := _shop_tab_panels[MENU_TAB]
	for child in panel.get_children():
		child.queue_free()
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	panel.add_child(vbox)

	vbox.add_child(_shop_header("On the menu today"))

	for drink in UnlockManager.get_unlocked_drinks():
		var active := UnlockManager.is_drink_active(drink)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(458, 30)
		_style_button(btn, UiStyle.ROAST_RAISED, POS_BODY)
		var row := HBoxContainer.new()
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 10
		row.add_theme_constant_override("separation", 10)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var box := PanelContainer.new()
		box.custom_minimum_size = Vector2(20, 20)
		box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_theme_stylebox_override("panel", StyleFactory.flat(UiStyle.OLIVE if active else Color.TRANSPARENT, UiStyle.SAGE if active else UiStyle.STEAM, 2, 5, 0))
		if active:
			box.add_child(UiIcon.make(UiIcon.Kind.CHECK, UiStyle.CREMA, 16))
		row.add_child(box)
		var n := _pos_label(DrinkData.get_drink_name(drink as DrinkData.DrinkType), POS_BODY, UiStyle.W_BOLD, UiStyle.CREMA if active else UiStyle.STEAM)
		n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(n)
		btn.add_child(row)
		var did: int = drink
		btn.pressed.connect(func(): _toggle_menu(did))
		vbox.add_child(btn)

func _switch_shop_tab(idx: int) -> void:
	_shop_current_tab = idx
	for i in range(_shop_tab_panels.size()):
		_shop_tab_panels[i].visible = (i == idx)
	for i in range(_shop_tab_buttons.size()):
		_set_tab_active(_shop_tab_buttons[i], i == idx)

# ──────────────────────────────────────────────
# SHOP PURCHASE ACTIONS
# ──────────────────────────────────────────────

func _buy_equipment(id: String) -> void:
	if UnlockManager.buy_equipment(id):
		var entry: Dictionary = UnlockManager.EQUIPMENT_SHOP[id]
		_shop_status("Bought %s" % entry["name"])
	else:
		_shop_status("Not enough money")
	_refresh_shop()

func _buy_upgrade(id: String) -> void:
	if UnlockManager.buy_upgrade(id):
		var entry: Dictionary = UnlockManager.UPGRADE_SHOP[id]
		_shop_status("Upgraded to %s" % entry["name"])
	else:
		_shop_status("Not enough stars")
	_refresh_shop()

func _buy_size(size: int) -> void:
	if UnlockManager.buy_size(size):
		_shop_status("New cup size unlocked")
	else:
		_shop_status("Not enough money")
	_refresh_shop()

func _buy_syrup(syrup: int) -> void:
	if "syrup_rack" not in UnlockManager.owned_equipment:
		_shop_status("Buy the syrup rack first")
		return
	if UnlockManager.buy_syrup(syrup):
		var entry: Dictionary = UnlockManager.SYRUP_SHOP[syrup]
		_shop_status("%s syrup unlocked" % entry["name"])
	else:
		_shop_status("Not enough money")
	_refresh_shop()

func _buy_sauce(sauce: int) -> void:
	var entry: Dictionary = UnlockManager.SAUCE_SHOP[sauce]
	if entry.get("bundled", "") != "":
		_shop_status("Comes with the %s" % entry["bundled"].replace("_", " ").capitalize())
		return
	if "sauce_station" not in UnlockManager.owned_equipment:
		_shop_status("Buy the sauce station first")
		return
	if UnlockManager.buy_sauce(sauce):
		_shop_status("%s unlocked" % entry["name"])
	else:
		_shop_status("Not enough money")
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
		_set_tab_active(_tab_buttons[i], i == idx)

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
		var on: bool = btn.get_meta("value", -99) == selected_value
		btn.add_theme_stylebox_override("normal", _pos_box(UiStyle.OLIVE if on else UiStyle.ROAST_RAISED))
		btn.add_theme_stylebox_override("hover", _pos_box(UiStyle.OLIVE if on else UiStyle.ROAST_RAISED.lightened(0.08)))

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
		_order_label.text = ""
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
		text += "\n%s      $%.2f" % [code, price]
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
	_show_charged_screen()
	# The customer at the front takes the order and lays their cash down at
	# once, so the view goes straight to the drawer.
	EventBus.order_charged.emit({
		"order": _pending_order,
		"drink_type": drink_enum,
		"cup_size": size_enum,
	})
	if _screen_state == Screen.CHARGED:
		# Nobody at the counter took it: back to the order as it was.
		_pending_order = null
		_screen_state = Screen.ORDER
		_show_order_screen()
	elif _screen_state == Screen.WAITING_CASH and _active:
		var player := _player
		_deactivate()
		_open_drawer(player)

func _open_drawer(player: Player) -> void:
	var drawer := get_tree().get_first_node_in_group("cash_drawer")
	if drawer:
		drawer.interact(player)

func _show_order_screen() -> void:
	_panel_area.visible = true
	_order_label.visible = true
	_charge_btn.visible = true
	_clear_btn.visible = true
	_status_box.visible = false
	for btn in _tab_buttons:
		btn.visible = true

func _show_charged_screen() -> void:
	_panel_area.visible = false
	_order_label.visible = false
	_charge_btn.visible = false
	_clear_btn.visible = false
	_status_box.visible = true
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
	_set_status(drink_desc, "$%.2f" % price, "Customer pays with $%.0f" % bill)

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
	_set_status("Change from $%.2f" % _cash_tendered, "$%.2f" % change, "")

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
	_set_status("", "Ticket printed", "")
	Fx.float_text(global_position + Vector3(0, 0.55, 0), "+$%.2f" % _pending_order.base_price)
	var timer := get_tree().create_timer(1.5)
	timer.timeout.connect(_clear_order)

# ──────────────────────────────────────────────
# SHARED UI HELPERS
# ──────────────────────────────────────────────

func _make_tab_panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.position = Vector2.ZERO
	p.size = Vector2(460, 150)
	p.add_theme_stylebox_override("panel", StyleFactory.flat_no_border(Color.TRANSPARENT, 0, 0))
	return p

func _make_button_grid() -> GridContainer:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	return g

func _pos_label(text: String, size: int, weight: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UiStyle.font(weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _pos_box(bg: Color) -> StyleBoxFlat:
	return StyleFactory.flat_no_border(bg, 8, 8)

func _style_button(btn: Button, bg: Color, size: int) -> void:
	btn.add_theme_font_override("font", UiStyle.font(UiStyle.W_BOLD))
	btn.add_theme_font_size_override("font_size", size)
	btn.add_theme_stylebox_override("normal", _pos_box(bg))
	btn.add_theme_stylebox_override("hover", _pos_box(bg.lightened(0.08)))
	btn.add_theme_stylebox_override("pressed", _pos_box(UiStyle.OLIVE))
	btn.add_theme_stylebox_override("disabled", _pos_box(Color(bg, 0.6)))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _make_pos_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(225, 60)
	_style_button(btn, UiStyle.ROAST_RAISED, POS_LEAD)
	return btn

## Tabs are flat text; the open one is crema with a sage underline.
func _make_tab_button(text: String, font_size: int = POS_BODY) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 32)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_override("font", UiStyle.font(UiStyle.W_BOLD))
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_set_tab_active(btn, false)
	return btn

func _set_tab_active(btn: Button, on: bool) -> void:
	var box := StyleFactory.flat(Color.TRANSPARENT, UiStyle.SAGE if on else Color(UiStyle.STEAM, 0.25), 0, 0, 4)
	box.border_width_bottom = 3 if on else 1
	for state in ["normal", "hover", "pressed"]:
		btn.add_theme_stylebox_override(state, box)
	var color := UiStyle.CREMA if on else UiStyle.STEAM
	btn.add_theme_color_override("font_color", color)
	btn.add_theme_color_override("font_hover_color", UiStyle.CREMA)
	btn.add_theme_color_override("font_pressed_color", color)

func _set_status(title: String, amount: String, note: String) -> void:
	_status_title.text = title
	_status_title.visible = not title.is_empty()
	_status_amount.text = amount
	_status_note.text = note
	_status_note.visible = not note.is_empty()

# ──────────────────────────────────────────────
# INTERACTION & INPUT
# ──────────────────────────────────────────────

func get_controls_hint() -> String:
	if _shop_mode:
		return "[Click] Select   [E] Leave"
	return "[Click] Select   [Enter] Charge   [Backspace] Clear   [E] Leave"

func interact(player: Player) -> void:
	if _active:
		_deactivate()
		return
	# Change is still owed: the drawer is where the work is.
	if _screen_state == Screen.WAITING_CASH:
		_open_drawer(player)
		return
	_active = true
	_player = player
	# Shop mode has a taller screen of rows; the order screen needs Charge and
	# Clear along its bottom edge in reach.
	var yaw := Vector2(-0.55, 0.55) if _shop_mode else Vector2(-0.45, 0.45)
	var pitch := Vector2(-0.55, 0.35) if _shop_mode else Vector2(-0.42, 0.3)
	_player.enter_screen_mode(_screen_mesh.global_position, to_global(Vector3(0, 0.30, -0.40)), yaw, pitch, 0.0, self)

func leave() -> void:
	_deactivate()

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

	if event.is_action_pressed("use"):
		var pixel := _get_crosshair_pixel()
		if pixel.x >= 0:
			if _shop_mode:
				_click_at_shop(pixel)
			else:
				_click_at(pixel)
		get_viewport().set_input_as_handled()
	elif not _shop_mode and _screen_state == Screen.ORDER:
		if event.is_action_pressed("confirm"):
			_charge_order()
		elif event.is_action_pressed("clear"):
			_clear_order()

func _process(_delta: float) -> void:
	_update_screen_texture()

func _update_screen_texture() -> void:
	if _screen_mesh and _viewport:
		var mat := _screen_mesh.get_surface_override_material(0)
		if not mat:
			# A lit screen: shown at its own colours whatever the shop lighting.
			mat = StandardMaterial3D.new()
			mat.albedo_color = Color.WHITE
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_screen_mesh.set_surface_override_material(0, mat)
		if mat is StandardMaterial3D:
			mat.albedo_texture = _viewport.get_texture()

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

	# Through the quad's own transform, so its scale (the screen is stretched
	# taller in the model) maps to the right pixel.
	var local := _screen_mesh.global_transform.affine_inverse() * hit_point
	var uv_x := local.x / SCREEN_SIZE.x + 0.5
	var uv_y := 0.5 - local.y / SCREEN_SIZE.y

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
	if _shop_tab_panels.size() > MENU_TAB and _shop_current_tab == MENU_TAB:
		var menu_panel := _shop_tab_panels[MENU_TAB]
		for child in menu_panel.get_children():
			if child is VBoxContainer:
				for sub in child.get_children():
					if sub is Button and sub.get_global_rect().has_point(pixel):
						sub.emit_signal("pressed")
						return
