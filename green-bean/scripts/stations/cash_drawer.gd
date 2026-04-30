extends StaticBody3D

var _pending_change := 0.0
var _selected_amount := 0.0
var _has_transaction := false
var _active := false
var _player: Player = null
var _activate_frame := -1
var _paying_customer: Node3D = null

var _status_label: Label3D = null

var _viewport: SubViewport = null
var _screen_mesh: MeshInstance3D = null
var _change_label: Label = null
var _selected_label: Label = null
var _message_label: Label = null

const VIEWPORT_SIZE := Vector2i(400, 300)
const SCREEN_SIZE := Vector2(0.30, 0.22)

const DENOMINATIONS := [
	{"name": "$1", "value": 1.00, "color": Color(0.3, 0.5, 0.3)},
	{"name": "25¢", "value": 0.25, "color": Color(0.6, 0.6, 0.65)},
	{"name": "10¢", "value": 0.10, "color": Color(0.6, 0.6, 0.65)},
	{"name": "5¢", "value": 0.05, "color": Color(0.55, 0.55, 0.58)},
	{"name": "1¢", "value": 0.01, "color": Color(0.6, 0.4, 0.3)},
]

var _denom_buttons: Array[Button] = []
var _putback_btn: Button = null

func _ready() -> void:
	add_to_group("station")
	EventBus.cash_collected.connect(_on_cash_collected)
	_build_viewport()
	_build_screen()
	_build_drawer_ui()

	_status_label = null

func _build_viewport() -> void:
	_viewport = SubViewport.new()
	_viewport.size = VIEWPORT_SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.transparent_bg = false
	_viewport.gui_disable_input = true
	add_child(_viewport)

func _build_screen() -> void:
	_screen_mesh = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = SCREEN_SIZE
	_screen_mesh.mesh = quad
	_screen_mesh.position = Vector3(0, 0.08, -0.10)
	_screen_mesh.rotation_degrees = Vector3(-60, 180, 0)
	_screen_mesh.visible = false
	add_child(_screen_mesh)

func _build_drawer_ui() -> void:
	var root := Panel.new()
	root.size = Vector2(VIEWPORT_SIZE)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.1)
	root.add_theme_stylebox_override("panel", style)
	_viewport.add_child(root)

	_change_label = Label.new()
	_change_label.text = "Change due: $0.00"
	_change_label.position = Vector2(15, 8)
	_change_label.add_theme_font_size_override("font_size", 20)
	_change_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	root.add_child(_change_label)

	_selected_label = Label.new()
	_selected_label.text = "Selected: $0.00"
	_selected_label.position = Vector2(15, 35)
	_selected_label.add_theme_font_size_override("font_size", 18)
	_selected_label.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
	root.add_child(_selected_label)

	_message_label = Label.new()
	_message_label.text = ""
	_message_label.position = Vector2(15, 60)
	_message_label.add_theme_font_size_override("font_size", 14)
	_message_label.add_theme_color_override("font_color", Color(1, 0.5, 0.5))
	root.add_child(_message_label)

	var tray_area := HBoxContainer.new()
	tray_area.position = Vector2(10, 90)
	tray_area.size = Vector2(380, 150)
	tray_area.add_theme_constant_override("separation", 6)
	root.add_child(tray_area)

	for d in DENOMINATIONS:
		var btn := Button.new()
		btn.text = d["name"]
		btn.custom_minimum_size = Vector2(70, 140)
		btn.add_theme_font_size_override("font_size", 18)
		var btn_style := StyleBoxFlat.new()
		btn_style.bg_color = d["color"]
		btn_style.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", btn_style)
		var hover_style := StyleBoxFlat.new()
		hover_style.bg_color = (d["color"] as Color).lightened(0.2)
		hover_style.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("hover", hover_style)
		_denom_buttons.append(btn)
		tray_area.add_child(btn)

	_putback_btn = Button.new()
	_putback_btn.text = "Put Back"
	_putback_btn.position = Vector2(15, 250)
	_putback_btn.size = Vector2(160, 40)
	_putback_btn.add_theme_font_size_override("font_size", 14)
	root.add_child(_putback_btn)

func _on_cash_collected(customer: Node3D, amount: float) -> void:
	_paying_customer = customer
	_has_transaction = true
	_pending_change = snapped(amount - _get_order_price(), 0.01)
	_selected_amount = 0.0
	_update_status_label()

func _get_order_price() -> float:
	if _paying_customer and _paying_customer is Customer:
		var c := _paying_customer as Customer
		if c.order_data:
			return c.order_data.base_price
	return 0.0

func interact(player: Player) -> void:
	if _active:
		_close_drawer()
		return
	if not _has_transaction:
		return
	_active = true
	_activate_frame = Engine.get_process_frames()
	_player = player
	_selected_amount = 0.0
	_screen_mesh.visible = true
	_update_drawer_display()
	var cam_pos := global_position + Vector3(0, 0.35, -0.30)
	_player.enter_screen_mode(_screen_mesh.global_position, cam_pos, 0.6)

func _close_drawer() -> void:
	if not _active:
		return
	_active = false
	_screen_mesh.visible = false
	if _player and is_instance_valid(_player):
		_player.exit_screen_mode()
		_player = null

func _input(event: InputEvent) -> void:
	if not _active:
		return

	if event.is_action_pressed("interact"):
		if Engine.get_process_frames() != _activate_frame:
			_close_drawer()
			get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.pressed:
		var pixel := _get_crosshair_pixel()
		if pixel.x >= 0:
			if event.button_index == MOUSE_BUTTON_LEFT:
				_click_at(pixel)
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				_right_click_at(pixel)
		get_viewport().set_input_as_handled()

	if event is InputEventKey and event.pressed and not event.echo:
		if event.shift_pressed:
			match event.keycode:
				KEY_1: _remove_denomination(0)
				KEY_2: _remove_denomination(1)
				KEY_3: _remove_denomination(2)
				KEY_4: _remove_denomination(3)
				KEY_5: _remove_denomination(4)
		else:
			match event.keycode:
				KEY_1: _add_denomination(0)
				KEY_2: _add_denomination(1)
				KEY_3: _add_denomination(2)
				KEY_4: _add_denomination(3)
				KEY_5: _add_denomination(4)
				KEY_BACKSPACE: _put_back()

func _add_denomination(idx: int) -> void:
	if idx < 0 or idx >= DENOMINATIONS.size():
		return
	var value: float = DENOMINATIONS[idx]["value"]
	_selected_amount = snapped(_selected_amount + value, 0.01)
	_message_label.text = ""
	_update_drawer_display()

	if absf(_selected_amount - _pending_change) < 0.005:
		_complete_change()
	elif _selected_amount > _pending_change:
		_message_label.text = "Too much! Press Backspace to put back"

func _remove_denomination(idx: int) -> void:
	if idx < 0 or idx >= DENOMINATIONS.size():
		return
	var value: float = DENOMINATIONS[idx]["value"]
	_selected_amount = maxf(snapped(_selected_amount - value, 0.01), 0.0)
	_message_label.text = ""
	_update_drawer_display()

func _put_back() -> void:
	_selected_amount = 0.0
	_message_label.text = ""
	_update_drawer_display()

func _right_click_at(pixel: Vector2) -> void:
	for i in range(_denom_buttons.size()):
		if _denom_buttons[i].is_visible_in_tree() and _denom_buttons[i].get_global_rect().has_point(pixel):
			_remove_denomination(i)
			return

func _complete_change() -> void:
	_has_transaction = false
	_message_label.text = ""
	EventBus.change_made.emit(_selected_amount)

	if _paying_customer and is_instance_valid(_paying_customer):
		if _paying_customer is Customer:
			var c := _paying_customer as Customer
			if c.state == Customer.State.PAYING:
				c.state = Customer.State.WALKING_TO_PICKUP
				c._target_pos = c._pickup_pos
				c._pickup_patience = Customer.PICKUP_PATIENCE

	_paying_customer = null
	_update_drawer_display()

	var timer := get_tree().create_timer(1.0)
	timer.timeout.connect(_close_drawer)
	_update_status_label()

func _update_drawer_display() -> void:
	if _change_label:
		_change_label.text = "Change due: $%.2f" % _pending_change
	if _selected_label:
		_selected_label.text = "Selected: $%.2f" % _selected_amount

func _update_status_label() -> void:
	if _status_label:
		if _has_transaction:
			_status_label.text = "[E] Open drawer\nChange: $%.2f" % _pending_change
		else:
			_status_label.text = "Cash Drawer"

func _process(_delta: float) -> void:
	if _screen_mesh and _viewport and _screen_mesh.visible:
		var mat := _screen_mesh.get_surface_override_material(0)
		if not mat:
			mat = StandardMaterial3D.new()
			mat.albedo_color = Color.WHITE
			mat.emission_enabled = true
			mat.emission = Color(0.2, 0.2, 0.2)
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
	for i in range(_denom_buttons.size()):
		if _denom_buttons[i].is_visible_in_tree() and _denom_buttons[i].get_global_rect().has_point(pixel):
			_add_denomination(i)
			return
	if _putback_btn and _putback_btn.is_visible_in_tree() and _putback_btn.get_global_rect().has_point(pixel):
		_put_back()
