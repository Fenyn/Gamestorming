extends StaticBody3D

enum Screen { ORDER, CHARGED, WAITING_CASH, COMPLETE }

var _active := false
var _player: Player = null
var _activate_frame := -1
var _screen_state := Screen.ORDER

var _viewport: SubViewport = null
var _screen_mesh: MeshInstance3D = null

var _size_selected: DrinkData.CupSize = -1
var _drink_selected: DrinkData.DrinkType = -1
var _syrup_selected: int = -1
var _sauce_selected: int = -1
var _current_tab := 0
var _pending_order: OrderData = null
var _cash_tendered := 0.0

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

const VIEWPORT_SIZE := Vector2i(480, 360)
const SCREEN_SIZE := Vector2(0.40, 0.30)

const SIZE_LABELS := ["Small", "Medium", "Large", "Extra Large"]
const DRINK_LABELS := ["Pour Over", "Americano", "Latte", "Cappuccino", "Red Eye", "Macchiato", "Mocha"]
const SYRUP_LABELS := ["None", "Vanilla"]
const SAUCE_LABELS := ["None", "Mocha", "Caramel", "White Mocha"]

func _ready() -> void:
	add_to_group("station")
	_build_viewport()
	_build_screen_mesh()
	_build_pos_ui()
	EventBus.cash_collected.connect(_on_cash_collected)
	EventBus.change_made.connect(_on_change_made)

func _build_viewport() -> void:
	_viewport = SubViewport.new()
	_viewport.size = VIEWPORT_SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.transparent_bg = false
	_viewport.gui_disable_input = true
	add_child(_viewport)

func _build_screen_mesh() -> void:
	_screen_mesh = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = SCREEN_SIZE
	_screen_mesh.mesh = quad
	_screen_mesh.position = Vector3(0, 0.18, -0.13)
	_screen_mesh.rotation_degrees = Vector3(-15, 180, 0)
	add_child(_screen_mesh)

func _build_pos_ui() -> void:
	var root := Panel.new()
	root.size = Vector2(VIEWPORT_SIZE)
	var root_style := StyleBoxFlat.new()
	root_style.bg_color = Color(0.08, 0.1, 0.12)
	root.add_theme_stylebox_override("panel", root_style)
	_viewport.add_child(root)

	var title := Label.new()
	title.text = "GREEN BEAN POS"
	title.position = Vector2(140, 4)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.4, 0.85, 0.4))
	root.add_child(title)

	# Tab bar
	var tab_bar := HBoxContainer.new()
	tab_bar.position = Vector2(10, 30)
	tab_bar.size = Vector2(460, 32)
	root.add_child(tab_bar)

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
	root.add_child(_panel_area)

	# SIZE tab
	var size_panel := _make_tab_panel()
	_panel_area.add_child(size_panel)
	_tab_panels.append(size_panel)
	var size_grid := _make_button_grid()
	size_panel.add_child(size_grid)
	for i in range(SIZE_LABELS.size()):
		var btn := _make_pos_button(SIZE_LABELS[i], Color(0.2, 0.35, 0.5))
		var idx := i
		btn.pressed.connect(func(): _select_size(idx))
		_size_buttons.append(btn)
		size_grid.add_child(btn)

	# DRINK tab
	var drink_panel := _make_tab_panel()
	drink_panel.visible = false
	_panel_area.add_child(drink_panel)
	_tab_panels.append(drink_panel)
	var drink_grid := _make_button_grid()
	drink_grid.add_theme_constant_override("v_separation", 4)
	drink_panel.add_child(drink_grid)
	for i in range(DRINK_LABELS.size()):
		var btn := _make_pos_button(DRINK_LABELS[i], Color(0.4, 0.25, 0.15))
		btn.custom_minimum_size.y = 38
		var idx := i
		btn.pressed.connect(func(): _select_drink(idx))
		_drink_buttons.append(btn)
		drink_grid.add_child(btn)

	# SYRUP tab
	var syrup_panel := _make_tab_panel()
	syrup_panel.visible = false
	_panel_area.add_child(syrup_panel)
	_tab_panels.append(syrup_panel)
	var syrup_grid := _make_button_grid()
	syrup_panel.add_child(syrup_grid)
	for i in range(SYRUP_LABELS.size()):
		var color := Color(0.35, 0.3, 0.15) if i > 0 else Color(0.3, 0.3, 0.3)
		var btn := _make_pos_button(SYRUP_LABELS[i], color)
		var idx := i
		btn.pressed.connect(func(): _select_syrup(idx))
		_syrup_buttons.append(btn)
		syrup_grid.add_child(btn)

	# SAUCE tab
	var sauce_panel := _make_tab_panel()
	sauce_panel.visible = false
	_panel_area.add_child(sauce_panel)
	_tab_panels.append(sauce_panel)
	var sauce_grid := _make_button_grid()
	sauce_panel.add_child(sauce_grid)
	for i in range(SAUCE_LABELS.size()):
		var color := Color(0.25, 0.15, 0.08) if i > 0 else Color(0.3, 0.3, 0.3)
		var btn := _make_pos_button(SAUCE_LABELS[i], color)
		btn.custom_minimum_size.y = 38
		var idx := i
		btn.pressed.connect(func(): _select_sauce(idx))
		_sauce_buttons.append(btn)
		sauce_grid.add_child(btn)

	# Order summary
	_order_label = Label.new()
	_order_label.text = "Select size, then drink"
	_order_label.position = Vector2(15, 215)
	_order_label.size = Vector2(450, 60)
	_order_label.add_theme_font_size_override("font_size", 16)
	_order_label.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	_order_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	root.add_child(_order_label)

	# Status label (for payment flow)
	_status_label_ui = Label.new()
	_status_label_ui.text = ""
	_status_label_ui.position = Vector2(15, 215)
	_status_label_ui.size = Vector2(450, 70)
	_status_label_ui.add_theme_font_size_override("font_size", 18)
	_status_label_ui.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	_status_label_ui.autowrap_mode = TextServer.AUTOWRAP_WORD
	_status_label_ui.visible = false
	root.add_child(_status_label_ui)

	# Bottom buttons
	_clear_btn = Button.new()
	_clear_btn.text = "CLEAR"
	_clear_btn.position = Vector2(15, 295)
	_clear_btn.size = Vector2(140, 50)
	_clear_btn.add_theme_font_size_override("font_size", 16)
	_clear_btn.pressed.connect(_clear_order)
	root.add_child(_clear_btn)

	_charge_btn = Button.new()
	_charge_btn.text = "CHARGE"
	_charge_btn.position = Vector2(240, 295)
	_charge_btn.size = Vector2(220, 50)
	_charge_btn.add_theme_font_size_override("font_size", 18)
	_charge_btn.pressed.connect(_charge_order)
	root.add_child(_charge_btn)

	_switch_tab(0)
	_update_display()

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

# --- Selection Logic ---

func _switch_tab(idx: int) -> void:
	_current_tab = idx
	for i in range(_tab_panels.size()):
		_tab_panels[i].visible = (i == idx)
	for i in range(_tab_buttons.size()):
		_tab_buttons[i].modulate = Color(1, 1, 1) if i == idx else Color(0.6, 0.6, 0.6)

func _select_size(idx: int) -> void:
	_size_selected = idx
	_highlight_group(_size_buttons, idx)
	SoundManager.play("register_beep")
	_update_display()
	_switch_tab(1)

func _select_drink(idx: int) -> void:
	_drink_selected = idx
	_highlight_group(_drink_buttons, idx)
	SoundManager.play("register_beep")
	_update_display()
	_switch_tab(2)

func _select_syrup(idx: int) -> void:
	_syrup_selected = idx - 1
	_highlight_group(_syrup_buttons, idx)
	SoundManager.play("register_beep")
	_update_display()

func _select_sauce(idx: int) -> void:
	_sauce_selected = idx - 1
	_highlight_group(_sauce_buttons, idx)
	SoundManager.play("register_beep")
	_update_display()

func _highlight_group(buttons: Array[Button], selected: int) -> void:
	for i in range(buttons.size()):
		buttons[i].modulate = Color(1.3, 1.3, 1.3) if i == selected else Color(1, 1, 1)

func _clear_order() -> void:
	_size_selected = -1
	_drink_selected = -1
	_syrup_selected = -1
	_sauce_selected = -1
	_pending_order = null
	_cash_tendered = 0.0
	_screen_state = Screen.ORDER
	_highlight_group(_size_buttons, -1)
	_highlight_group(_drink_buttons, -1)
	_highlight_group(_syrup_buttons, -1)
	_highlight_group(_sauce_buttons, -1)
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
		parts.append(SIZE_LABELS[_size_selected])
	if _syrup_selected >= 0:
		parts.append(DrinkData.get_syrup_name(_syrup_selected as DrinkData.SyrupType))
	if _sauce_selected >= 0:
		parts.append(DrinkData.get_sauce_name(_sauce_selected as DrinkData.SauceType))
	if _drink_selected >= 0:
		parts.append(DRINK_LABELS[_drink_selected])
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

# --- Charge / Payment Flow ---

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
	var drink_desc: String = SIZE_LABELS[_size_selected]
	if _syrup_selected >= 0:
		drink_desc += " " + DrinkData.get_syrup_name(_syrup_selected as DrinkData.SyrupType)
	if _sauce_selected >= 0:
		drink_desc += " " + DrinkData.get_sauce_name(_sauce_selected as DrinkData.SauceType)
	drink_desc += " " + DRINK_LABELS[_drink_selected]
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

# --- Interaction & Input ---

func interact(player: Player) -> void:
	if _active:
		_deactivate()
		return
	_active = true
	_activate_frame = Engine.get_process_frames()
	_player = player
	_player.enter_screen_mode(_screen_mesh.global_position, global_position + Vector3(0, 0.30, -0.40))

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
			_click_at(pixel)
		get_viewport().set_input_as_handled()

	if event is InputEventKey and event.pressed and not event.echo:
		if _screen_state == Screen.ORDER:
			match event.keycode:
				KEY_1: _select_size(0)
				KEY_2: _select_size(1)
				KEY_3: _select_size(2)
				KEY_4: _select_size(3)
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
			_select_size(_size_buttons.find(btn))
			return
	for btn in _drink_buttons:
		if btn.is_visible_in_tree() and btn.get_global_rect().has_point(pixel):
			_select_drink(_drink_buttons.find(btn))
			return
	for btn in _syrup_buttons:
		if btn.is_visible_in_tree() and btn.get_global_rect().has_point(pixel):
			_select_syrup(_syrup_buttons.find(btn))
			return
	for btn in _sauce_buttons:
		if btn.is_visible_in_tree() and btn.get_global_rect().has_point(pixel):
			_select_sauce(_sauce_buttons.find(btn))
			return
