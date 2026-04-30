extends StaticBody3D

var _active := false
var _player: Player = null

var _viewport: SubViewport = null
var _screen_mesh: MeshInstance3D = null
var _screen_collision: StaticBody3D = null
var _screen_col_shape: CollisionShape3D = null

var _size_selected: DrinkData.CupSize = -1
var _drink_selected: DrinkData.DrinkType = -1
var _milk_selected := -1
var _current_tab := 0

var _size_buttons: Array[Button] = []
var _drink_buttons: Array[Button] = []
var _milk_buttons: Array[Button] = []
var _tab_buttons: Array[Button] = []
var _tab_panels: Array[PanelContainer] = []
var _order_label: Label = null
var _confirm_btn: Button = null
var _clear_btn: Button = null

const VIEWPORT_SIZE := Vector2i(480, 360)
const SCREEN_SIZE := Vector2(0.40, 0.30)

const TAB_NAMES := ["SIZE", "DRINK", "MILK"]
const SIZE_LABELS := ["Short", "Tall", "Grande", "Venti"]
const DRINK_LABELS := ["Pour Over", "Americano", "Latte"]
const MILK_LABELS := ["Whole"]

func _ready() -> void:
	add_to_group("station")
	_build_viewport()
	_build_screen_mesh()
	_build_pos_ui()

func _build_viewport() -> void:
	_viewport = SubViewport.new()
	_viewport.size = VIEWPORT_SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.transparent_bg = false
	_viewport.gui_disable_input = false
	add_child(_viewport)

func _build_screen_mesh() -> void:
	_screen_mesh = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = SCREEN_SIZE
	_screen_mesh.mesh = quad
	_screen_mesh.position = Vector3(0, 0.18, -0.13)
	_screen_mesh.rotation_degrees = Vector3(-15, 180, 0)
	add_child(_screen_mesh)

	_screen_collision = StaticBody3D.new()
	_screen_collision.name = "ScreenCollider"
	_screen_collision.position = _screen_mesh.position
	_screen_collision.rotation_degrees = _screen_mesh.rotation_degrees
	_screen_col_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(SCREEN_SIZE.x, SCREEN_SIZE.y, 0.01)
	_screen_col_shape.shape = box
	_screen_collision.add_child(_screen_col_shape)
	add_child(_screen_collision)

func _build_pos_ui() -> void:
	var root := Panel.new()
	root.size = Vector2(VIEWPORT_SIZE)
	var root_style := StyleBoxFlat.new()
	root_style.bg_color = Color(0.1, 0.12, 0.14)
	root.add_theme_stylebox_override("panel", root_style)
	_viewport.add_child(root)

	# Title
	var title := Label.new()
	title.text = "GREEN BEAN"
	title.position = Vector2(160, 4)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.4, 0.85, 0.4))
	root.add_child(title)

	# Tab bar
	var tab_bar := HBoxContainer.new()
	tab_bar.position = Vector2(10, 32)
	tab_bar.size = Vector2(460, 36)
	root.add_child(tab_bar)

	for i in range(TAB_NAMES.size()):
		var btn := Button.new()
		btn.text = TAB_NAMES[i]
		btn.custom_minimum_size = Vector2(140, 34)
		btn.add_theme_font_size_override("font_size", 16)
		var idx := i
		btn.pressed.connect(func(): _switch_tab(idx))
		_tab_buttons.append(btn)
		tab_bar.add_child(btn)

	# Tab panels container
	var panel_area := Control.new()
	panel_area.position = Vector2(10, 74)
	panel_area.size = Vector2(460, 170)
	root.add_child(panel_area)

	# SIZE tab
	var size_panel := _make_tab_panel()
	panel_area.add_child(size_panel)
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
	panel_area.add_child(drink_panel)
	_tab_panels.append(drink_panel)
	var drink_grid := _make_button_grid()
	drink_panel.add_child(drink_grid)
	for i in range(DRINK_LABELS.size()):
		var btn := _make_pos_button(DRINK_LABELS[i], Color(0.4, 0.25, 0.15))
		var idx := i
		btn.pressed.connect(func(): _select_drink(idx))
		_drink_buttons.append(btn)
		drink_grid.add_child(btn)

	# MILK tab
	var milk_panel := _make_tab_panel()
	milk_panel.visible = false
	panel_area.add_child(milk_panel)
	_tab_panels.append(milk_panel)
	var milk_grid := _make_button_grid()
	milk_panel.add_child(milk_grid)
	for i in range(MILK_LABELS.size()):
		var btn := _make_pos_button(MILK_LABELS[i], Color(0.5, 0.45, 0.3))
		var idx := i
		btn.pressed.connect(func(): _select_milk(idx))
		_milk_buttons.append(btn)
		milk_grid.add_child(btn)

	# Order summary
	_order_label = Label.new()
	_order_label.text = "Order: ---"
	_order_label.position = Vector2(15, 252)
	_order_label.size = Vector2(300, 30)
	_order_label.add_theme_font_size_override("font_size", 18)
	_order_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	root.add_child(_order_label)

	# Bottom buttons
	_clear_btn = Button.new()
	_clear_btn.text = "CLEAR"
	_clear_btn.position = Vector2(15, 290)
	_clear_btn.size = Vector2(140, 50)
	_clear_btn.add_theme_font_size_override("font_size", 18)
	_clear_btn.pressed.connect(_clear_order)
	root.add_child(_clear_btn)

	_confirm_btn = Button.new()
	_confirm_btn.text = "SEND ORDER"
	_confirm_btn.position = Vector2(240, 290)
	_confirm_btn.size = Vector2(220, 50)
	_confirm_btn.add_theme_font_size_override("font_size", 20)
	_confirm_btn.pressed.connect(_confirm_order)
	root.add_child(_confirm_btn)

	_switch_tab(0)
	_update_display()

func _make_tab_panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.position = Vector2.ZERO
	p.size = Vector2(460, 170)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.17, 0.2)
	style.set_corner_radius_all(4)
	p.add_theme_stylebox_override("panel", style)
	return p

func _make_button_grid() -> GridContainer:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 12)
	return g

func _make_pos_button(text: String, color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(200, 60)
	btn.add_theme_font_size_override("font_size", 18)
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", style)
	var hover := StyleBoxFlat.new()
	hover.bg_color = color.lightened(0.2)
	hover.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = color.lightened(0.4)
	pressed.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("pressed", pressed)
	return btn

func _switch_tab(idx: int) -> void:
	_current_tab = idx
	for i in range(_tab_panels.size()):
		_tab_panels[i].visible = (i == idx)
	for i in range(_tab_buttons.size()):
		_tab_buttons[i].modulate = Color(1, 1, 1) if i == idx else Color(0.6, 0.6, 0.6)

func _select_size(idx: int) -> void:
	_size_selected = idx
	_highlight_group(_size_buttons, idx)
	_update_display()
	_switch_tab(1)

func _select_drink(idx: int) -> void:
	_drink_selected = idx
	_highlight_group(_drink_buttons, idx)
	_update_display()
	if _drink_selected == DrinkData.DrinkType.LATTE:
		_switch_tab(2)

func _select_milk(idx: int) -> void:
	_milk_selected = idx
	_highlight_group(_milk_buttons, idx)
	_update_display()

func _highlight_group(buttons: Array[Button], selected: int) -> void:
	for i in range(buttons.size()):
		if i == selected:
			buttons[i].modulate = Color(1.3, 1.3, 1.3)
		else:
			buttons[i].modulate = Color(1, 1, 1)

func _clear_order() -> void:
	_size_selected = -1
	_drink_selected = -1
	_milk_selected = -1
	_highlight_group(_size_buttons, -1)
	_highlight_group(_drink_buttons, -1)
	_highlight_group(_milk_buttons, -1)
	_switch_tab(0)
	_update_display()

func _update_display() -> void:
	if not _order_label:
		return
	if _size_selected < 0 or _drink_selected < 0:
		_order_label.text = "Order: ---"
		return
	var size_enum: DrinkData.CupSize = _size_selected
	var drink_enum: DrinkData.DrinkType = _drink_selected
	var code := DrinkData.get_ticket_code(drink_enum, size_enum)
	var price := DrinkData.get_base_price(drink_enum, size_enum)
	_order_label.text = "Order: %s %s [%s] $%.2f" % [
		SIZE_LABELS[_size_selected], DRINK_LABELS[_drink_selected], code, price
	]

func _confirm_order() -> void:
	if _size_selected < 0 or _drink_selected < 0:
		return
	var size_enum: DrinkData.CupSize = _size_selected
	var drink_enum: DrinkData.DrinkType = _drink_selected
	var order := OrderData.new(drink_enum, size_enum)
	EventBus.order_submitted.emit({
		"order": order,
		"drink_type": drink_enum,
		"cup_size": size_enum,
		"ticket_code": order.ticket_code,
	})
	EventBus.ticket_printed.emit({
		"order": order,
		"ticket_code": order.ticket_code,
	})
	_clear_order()

# --- Interaction & Input Forwarding ---

func interact(player: Player) -> void:
	if _active:
		_deactivate()
		return
	_active = true
	_player = player
	_player.enter_screen_mode(_screen_mesh.global_position, global_position + Vector3(0, 0.30, -0.40))

func _deactivate() -> void:
	_active = false
	if _player:
		_player.exit_screen_mode()
		_player = null

func _input(event: InputEvent) -> void:
	if not _active:
		return

	if event.is_action_pressed("interact"):
		_deactivate()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion:
		_forward_mouse_to_viewport(null)

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_forward_mouse_to_viewport(event)

func _process(_delta: float) -> void:
	_update_screen_texture()
	if _active:
		_forward_mouse_to_viewport(null)

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

func _forward_mouse_to_viewport(click_event: InputEventMouseButton) -> void:
	if not _player or not _viewport:
		return

	var camera := _player.camera
	var screen_center := get_viewport().get_visible_rect().size / 2.0
	var ray_origin := camera.project_ray_origin(screen_center)
	var ray_dir := camera.project_ray_normal(screen_center)

	var screen_normal := _screen_mesh.global_transform.basis.z.normalized()
	var screen_pos := _screen_mesh.global_position
	var denom := screen_normal.dot(ray_dir)
	if absf(denom) < 0.0001:
		return
	var t := screen_normal.dot(screen_pos - ray_origin) / denom
	if t < 0:
		return
	var hit_point := ray_origin + ray_dir * t

	var screen_right := _screen_mesh.global_transform.basis.x.normalized()
	var screen_up := _screen_mesh.global_transform.basis.y.normalized()
	var offset := hit_point - screen_pos
	var u := offset.dot(screen_right)
	var v := offset.dot(screen_up)
	var uv_x := u / SCREEN_SIZE.x + 0.5
	var uv_y := 0.5 - v / SCREEN_SIZE.y

	if uv_x < 0 or uv_x > 1 or uv_y < 0 or uv_y > 1:
		return

	var pixel_pos := Vector2(uv_x * VIEWPORT_SIZE.x, uv_y * VIEWPORT_SIZE.y)

	var hover := InputEventMouseMotion.new()
	hover.position = pixel_pos
	hover.global_position = pixel_pos
	_viewport.push_input(hover, true)

	if click_event:
		var press := InputEventMouseButton.new()
		press.position = pixel_pos
		press.global_position = pixel_pos
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		_viewport.push_input(press, true)

		var release := InputEventMouseButton.new()
		release.position = pixel_pos
		release.global_position = pixel_pos
		release.button_index = MOUSE_BUTTON_LEFT
		release.pressed = false
		_viewport.push_input(release, true)
