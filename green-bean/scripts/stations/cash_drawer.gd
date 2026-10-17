extends StaticBody3D

## Change-making at the cash drawer. The customer's bill lands on the change mat.
## The barista files it into its compartment and counts change out onto the mat,
## taking bills and coins from the open drawer with the crosshair:
## - click a compartment: one piece goes to the mat
## - hold on a compartment and drag: carry the piece and drop it on the mat
## - click or right-click a piece on the mat: it goes back (the customer's bill
##   goes into its compartment)
## Keys: 1-7 add $10 $5 $1 25¢ 10¢ 5¢ 1¢, Shift+key takes one back, F files the
## customer's bill, Backspace takes all change back.
## Money is in cents throughout.

const PIECES_SCENE := preload("res://scenes/props/cash_pieces.tscn")
const VALUES := {"b20": 2000, "b10": 1000, "b5": 500, "b1": 100, "c25": 25, "c10": 10, "c5": 5, "c1": 1}
const KEY_ORDER := ["b10", "b5", "b1", "c25", "c10", "c5", "c1"]
## A press shorter than this on the same target is a click, not a drag.
const CLICK_TIME := 0.22
const CLIP_OPEN_DEG := 50.0
const CARRY_HEIGHT := 0.035
const BILL_HALF := Vector2(0.033, 0.078)
const BILL_FAN_STEP := 0.012

var _due := 0
var _tender_key := ""
var _tender_piece: Node3D = null
var _tender_filed := false
var _mat_pieces: Array[Node3D] = []
var _has_transaction := false
var _completing := false
var _active := false
var _player: Player = null
var _activate_frame := -1
var _paying_customer: Node3D = null

var _drawer: Node3D = null
var _drawer_tween: Tween = null
var _housing_front_z := -0.15
var _mat: Node3D = null
var _mat_half := Vector2(0.13, 0.085)
var _templates: Node3D = null
var _slots := {}
var _clips := {}

var _held: Node3D = null
var _held_from := ""
var _press_time := 0.0
var _press_aim := {}
var _highlight: MeshInstance3D = null
var _hover_label: Label3D = null
var _readout: Label3D = null
var _hint: Label3D = null

func _ready() -> void:
	add_to_group("station")
	EventBus.cash_collected.connect(_on_cash_collected)
	_drawer = get_node_or_null("Model/Drawer") as Node3D
	var model := get_node_or_null("Model")
	if model:
		_housing_front_z = float(model.get_meta("housing_front_z", _housing_front_z))
	_mat = get_node_or_null("ChangeMat") as Node3D
	if _mat:
		_mat_half = (_mat.get_meta("size", _mat_half * 2.0) as Vector2) * 0.5
	if _drawer:
		for key in VALUES:
			var slot := _drawer.get_node_or_null("Slot_" + str(key)) as Marker3D
			if slot:
				_slots[key] = slot
			var clip := _drawer.get_node_or_null("Clip_" + str(key)) as Node3D
			if clip:
				_clips[key] = clip
	_templates = PIECES_SCENE.instantiate()
	_templates.name = "PieceTemplates"
	_templates.visible = false
	add_child(_templates)
	_build_feedback()

func _build_feedback() -> void:
	_highlight = MeshInstance3D.new()
	_highlight.name = "Highlight"
	_highlight.mesh = BoxMesh.new()
	var hl := StandardMaterial3D.new()
	hl.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hl.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hl.albedo_color = Color(1.0, 0.85, 0.4, 0.28)
	_highlight.material_override = hl
	_highlight.top_level = true
	_highlight.visible = false
	add_child(_highlight)

	_hover_label = _make_label(40, 0.0003)
	_hover_label.name = "HoverLabel"
	_hover_label.top_level = true

	_readout = _make_label(44, 0.00042)
	_readout.name = "Readout"
	_readout.position = Vector3(0, 0.15, 0.27)

	_hint = _make_label(28, 0.00036)
	_hint.name = "Hint"
	_hint.modulate = Color(0.9, 0.9, 0.85)
	_hint.text = "Click: hand over   Drag: place   Click on mat or right-click: take back   E: close"
	_hint.position = Vector3(0, 0.08, -0.15)

func _make_label(font_size: int, pixel: float) -> Label3D:
	var l := Label3D.new()
	l.font_size = font_size
	l.pixel_size = pixel
	l.outline_size = 8
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.visible = false
	add_child(l)
	return l

# ── Transaction ──────────────────────────────

func _on_cash_collected(customer: Node3D, amount: float) -> void:
	_clear_mat()
	_paying_customer = customer
	_has_transaction = true
	_completing = false
	var price := roundi(_get_order_price() * 100.0)
	var tendered := roundi(amount * 100.0)
	_due = tendered - price
	_tender_key = "b%d" % (tendered / 100)
	_tender_filed = not _templates.has_node(_tender_key)
	if not _tender_filed and _mat:
		# The customer lays their bill on the mat from their side.
		var spot := _mat.get_node("TenderSpot") as Node3D
		_tender_piece = _spawn_piece(_tender_key, spot.global_transform.translated(_mat.global_basis.z * 0.25 + Vector3(0, 0.1, 0)))
		_fly(_tender_piece, spot.global_transform, 0.35, 0.03)
	_update_readout()

func _get_order_price() -> float:
	if _paying_customer and _paying_customer is Customer:
		var c := _paying_customer as Customer
		if c.order_data:
			return c.order_data.base_price
	return 0.0

func _counted() -> int:
	var total := 0
	for p in _mat_pieces:
		total += int(VALUES[p.get_meta("key")])
	return total

func _check_complete() -> void:
	if _completing or not _has_transaction or _held:
		return
	if _tender_filed and _counted() == _due:
		_complete_change()

func _complete_change() -> void:
	_completing = true
	_has_transaction = false
	SoundManager.play("change_complete")
	EventBus.change_made.emit(_counted() / 100.0)
	if _paying_customer and is_instance_valid(_paying_customer) and _paying_customer is Customer:
		var c := _paying_customer as Customer
		if c.state == Customer.State.PAYING:
			c.order_taken(c.order_data)
	_paying_customer = null
	# The customer slides the change off the mat toward themselves.
	var away := _mat.global_basis.z * 0.2 if _mat else Vector3.ZERO
	for p in _mat_pieces:
		var tw := _fly(p, p.global_transform.translated(away), 0.4, 0.01)
		tw.tween_callback(p.queue_free)
	_mat_pieces.clear()
	_update_readout()
	get_tree().create_timer(0.9).timeout.connect(_finish_complete)

func _finish_complete() -> void:
	_completing = false
	_readout.visible = false
	_close_drawer()

func _clear_mat() -> void:
	for p in _mat_pieces:
		if is_instance_valid(p):
			p.queue_free()
	_mat_pieces.clear()
	if _tender_piece and is_instance_valid(_tender_piece):
		_tender_piece.queue_free()
	_tender_piece = null

# ── Drawer open / close ──────────────────────

func interact(player: Player) -> void:
	if _active:
		_close_drawer()
		return
	if not _has_transaction or _completing:
		return
	_active = true
	_activate_frame = Engine.get_process_frames()
	_player = player
	_slide_drawer(true)
	_hint.visible = true
	_player.enter_screen_mode(to_global(Vector3(0, -0.03, -0.17)), to_global(Vector3(0, 0.45, -0.34)), 0.6, 50.0)

func _slide_drawer(open: bool) -> void:
	if _drawer == null:
		return
	var target := StationUtils.model_marker(self, "DrawerOpen", Vector3(0, 0, -0.24)) if open else Vector3.ZERO
	if _drawer_tween and _drawer_tween.is_valid():
		_drawer_tween.kill()
	_drawer_tween = create_tween()
	_drawer_tween.tween_property(_drawer, "position", target, 0.3 if open else 0.2).set_trans(Tween.TRANS_BACK if open else Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## leave_screen is false when the player already left screen mode on their own.
func _close_drawer(leave_screen := true) -> void:
	if not _active:
		return
	_drop_held_safely()
	_active = false
	_highlight.visible = false
	_hover_label.visible = false
	_hint.visible = false
	_slide_drawer(false)
	if leave_screen and _player and is_instance_valid(_player):
		_player.exit_screen_mode()
	_player = null

# ── Input ────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed("interact"):
		if Engine.get_process_frames() != _activate_frame:
			_close_drawer()
			get_viewport().set_input_as_handled()
		return
	if _completing:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_on_press()
			else:
				_on_release()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_on_right_click()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		var idx := k.keycode - KEY_1
		if idx >= 0 and idx < KEY_ORDER.size():
			if k.shift_pressed:
				_take_back_one(KEY_ORDER[idx])
			else:
				_hand_over_from_slot(KEY_ORDER[idx])
		elif k.keycode == KEY_F:
			if _tender_piece:
				_file_tender()
		elif k.keycode == KEY_BACKSPACE:
			for p in _mat_pieces.duplicate():
				_return_to_slot(p)

func _on_press() -> void:
	if _held:
		return
	var aim := _aim()
	_press_aim = aim
	_press_time = Time.get_ticks_msec() / 1000.0
	if aim["kind"] == "slot":
		var key: String = aim["key"]
		_held = _spawn_piece(key, (_slots[key] as Node3D).global_transform)
		_held_from = "slot"
		_set_clip(key, true)
		_play_pick(key)
	elif aim["kind"] == "mat":
		var piece := _mat_piece_at(aim["point"])
		if piece:
			_held = piece
			_held_from = "mat"
			_mat_pieces.erase(piece)
			_kill_tween(piece)
			_play_pick(piece.get_meta("key"))

func _on_release() -> void:
	if not _held:
		return
	var piece := _held
	var key: String = piece.get_meta("key")
	var aim := _aim()
	var quick := Time.get_ticks_msec() / 1000.0 - _press_time < CLICK_TIME and _same_target(aim, _press_aim)
	_held = null
	if _held_from == "slot":
		_set_clip(key, false)
		if quick or aim["kind"] == "mat":
			_add_to_mat(piece)
		else:
			_return_to_slot(piece)
		return
	# Picked up off the mat.
	var dropped_on_own_slot: bool = aim["kind"] == "slot" and aim["key"] == key
	if quick or dropped_on_own_slot:
		_return_to_slot(piece)
	elif aim["kind"] == "slot":
		_flash_readout("That goes in the %s slot" % _name(key))
		_back_to_mat(piece)
	else:
		_back_to_mat(piece)

func _on_right_click() -> void:
	if _held:
		return
	var aim := _aim()
	if aim["kind"] == "mat":
		var piece := _mat_piece_at(aim["point"])
		if piece:
			_mat_pieces.erase(piece)
			_return_to_slot(piece)
	elif aim["kind"] == "slot":
		_take_back_one(aim["key"])

func _same_target(a: Dictionary, b: Dictionary) -> bool:
	return a["kind"] == b["kind"] and a.get("key", "") == b.get("key", "")

# ── Moving pieces ────────────────────────────

func _spawn_piece(key: String, xform: Transform3D) -> Node3D:
	var piece := _templates.get_node(key).duplicate() as Node3D
	piece.set_meta("key", key)
	piece.top_level = true
	add_child(piece)
	piece.global_transform = xform
	return piece

func _hand_over_from_slot(key: String) -> void:
	if not _slots.has(key) or _held:
		return
	var piece := _spawn_piece(key, (_slots[key] as Node3D).global_transform)
	_set_clip(key, true)
	_play_pick(key)
	get_tree().create_timer(0.12).timeout.connect(_set_clip.bind(key, false))
	_add_to_mat(piece)

func _take_back_one(key: String) -> void:
	for i in range(_mat_pieces.size() - 1, -1, -1):
		if _mat_pieces[i].get_meta("key") == key:
			var piece := _mat_pieces[i]
			_mat_pieces.remove_at(i)
			_return_to_slot(piece)
			return

func _add_to_mat(piece: Node3D) -> void:
	_mat_pieces.append(piece)
	_layout_mat(piece)
	_update_readout()
	_check_complete()

func _back_to_mat(piece: Node3D) -> void:
	if piece == _tender_piece:
		_fly(piece, (_mat.get_node("TenderSpot") as Node3D).global_transform, 0.2, 0.01)
		return
	_add_to_mat(piece)

func _file_tender() -> void:
	var piece := _tender_piece
	if piece == null:
		return
	_kill_tween(piece)
	_return_to_slot(piece)

## Flies a piece into its compartment and removes it. Filing the customer's
## bill is what marks the tender as taken.
func _return_to_slot(piece: Node3D) -> void:
	var key: String = piece.get_meta("key")
	_mat_pieces.erase(piece)
	if piece == _tender_piece:
		_tender_piece = null
		_tender_filed = true
	if not _slots.has(key):
		piece.queue_free()
	else:
		_set_clip(key, true)
		var tw := _fly(piece, (_slots[key] as Node3D).global_transform, 0.22, 0.04)
		tw.tween_callback(_set_clip.bind(key, false))
		tw.tween_callback(_play_drop.bind(key))
		tw.tween_callback(piece.queue_free)
	_layout_mat(null)
	_update_readout()
	_check_complete()

## Bills fan out from BillSpot; coins stack on their Coin_<key> spots.
func _layout_mat(new_piece: Node3D) -> void:
	if _mat == null:
		return
	var bills := 0
	var coins := {}
	for p in _mat_pieces:
		var key: String = p.get_meta("key")
		var local := Transform3D()
		if key.begins_with("b"):
			var spot := (_mat.get_node("BillSpot") as Node3D).position
			local = Transform3D(Basis(Vector3.UP, deg_to_rad(_jitter(bills, 3.0))), spot + Vector3(-BILL_FAN_STEP * bills, 0.0008 * bills, 0.004 * (bills % 2)))
			bills += 1
		else:
			var n: int = coins.get(key, 0)
			coins[key] = n + 1
			var spot := (_mat.get_node("Coin_" + key) as Node3D).position
			var t: float = (_templates.get_node(key).get_node("Disc").mesh as CylinderMesh).height
			local = Transform3D(Basis(Vector3.UP, deg_to_rad(_jitter(n, 180.0))), spot + Vector3(_jitter(n + 3, 0.0008), t * n, _jitter(n + 7, 0.0008)))
		var target := _mat.global_transform * local
		if p == new_piece:
			var tw := _fly(p, target, 0.25, 0.05)
			tw.tween_callback(_play_drop.bind(key))
		elif not p.global_transform.is_equal_approx(target):
			_fly(p, target, 0.12, 0.0)

## Repeatable small offset in [-amount, amount] so stacks look hand-placed.
func _jitter(i: int, amount: float) -> float:
	return sin(float(i) * 12.9898 + 4.1) * amount

func _fly(piece: Node3D, to: Transform3D, duration: float, lift: float) -> Tween:
	_kill_tween(piece)
	var from := piece.global_transform
	var tw := piece.create_tween()
	tw.tween_method(func(t: float) -> void:
		piece.global_transform = Transform3D(from.basis.slerp(to.basis, t), from.origin.lerp(to.origin, t) + Vector3(0, sin(t * PI) * lift, 0)),
		0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	piece.set_meta("tween", tw)
	return tw

func _kill_tween(piece: Node3D) -> void:
	if not piece.has_meta("tween"):
		return
	var tw = piece.get_meta("tween")
	if tw is Tween and (tw as Tween).is_valid():
		(tw as Tween).kill()

func _set_clip(key: String, open: bool) -> void:
	if not _clips.has(key):
		return
	var clip: Node3D = _clips[key]
	var tw := clip.create_tween()
	if open:
		tw.tween_property(clip, "rotation:x", deg_to_rad(CLIP_OPEN_DEG), 0.08).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_property(clip, "rotation:x", 0.0, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_callback(SoundManager.play.bind("bill_clip_snap", -6.0))

func _drop_held_safely() -> void:
	if _held == null:
		return
	var piece := _held
	_held = null
	if _held_from == "slot":
		_set_clip(piece.get_meta("key"), false)
		_return_to_slot(piece)
	else:
		_back_to_mat(piece)

func _play_pick(key: String) -> void:
	SoundManager.play("bill_pull" if key.begins_with("b") else "coin_pick", -4.0)

func _play_drop(key: String) -> void:
	SoundManager.play("bill_drop" if key.begins_with("b") else "coin_clink", -6.0)

# ── Aiming ───────────────────────────────────

## What the crosshair is on: {"kind": "mat" | "slot" | "none", "key", "point"}.
func _aim() -> Dictionary:
	var cam := _player.camera
	var center := get_viewport().get_visible_rect().size / 2.0
	var origin := cam.project_ray_origin(center)
	var dir := cam.project_ray_normal(center)
	# The mat sits higher and further back than the tray, so test it first.
	if _mat:
		var p = _ray_plane(origin, dir, _mat.global_position.y + 0.004)
		if p != null:
			var l := _mat.to_local(p)
			if absf(l.x) <= _mat_half.x and absf(l.z) <= _mat_half.y:
				return {"kind": "mat", "point": p}
	for key in _slots:
		var slot: Marker3D = _slots[key]
		var p = _ray_plane(origin, dir, slot.global_position.y)
		if p == null:
			continue
		var l := slot.to_local(p)
		var half: Vector2 = slot.get_meta("half", Vector2(0.03, 0.03))
		if absf(l.x) <= half.x and absf(l.z) <= half.y and to_local(p).z < _housing_front_z:
			return {"kind": "slot", "key": key, "point": p}
	var fallback = _ray_plane(origin, dir, to_global(Vector3.ZERO).y)
	return {"kind": "none", "point": fallback if fallback != null else origin + dir * 0.5}

func _ray_plane(origin: Vector3, dir: Vector3, y: float) -> Variant:
	if absf(dir.y) < 0.0001:
		return null
	var t := (y - origin.y) / dir.y
	if t < 0.0:
		return null
	return origin + dir * t

## Topmost mat piece under the point, the customer's bill included.
func _mat_piece_at(point: Vector3) -> Node3D:
	var candidates: Array[Node3D] = []
	if _tender_piece:
		candidates.append(_tender_piece)
	candidates.append_array(_mat_pieces)
	for i in range(candidates.size() - 1, -1, -1):
		var piece := candidates[i]
		var l := piece.to_local(point)
		var key: String = piece.get_meta("key")
		if key.begins_with("b"):
			if absf(l.x) <= BILL_HALF.x and absf(l.z) <= BILL_HALF.y:
				return piece
		else:
			var r: float = (_templates.get_node(key).get_node("Disc").mesh as CylinderMesh).top_radius + 0.004
			if Vector2(l.x, l.z).length() <= r:
				return piece
	return null

# ── Per-frame feedback ───────────────────────

func _process(_delta: float) -> void:
	if not _active:
		return
	if _player == null or not is_instance_valid(_player) or not _player.is_in_screen_mode():
		_close_drawer(false)
		return
	var aim := _aim()
	if _held:
		var carry: Vector3 = aim["point"] + Vector3(0, CARRY_HEIGHT, 0)
		_held.global_position = _held.global_position.lerp(carry, 0.45)
	_update_hover(aim)

func _update_hover(aim: Dictionary) -> void:
	_highlight.visible = false
	_hover_label.visible = false
	if _completing:
		return
	if aim["kind"] == "slot":
		var key: String = aim["key"]
		if _held and _held.get_meta("key") != key:
			return
		var slot: Marker3D = _slots[key]
		var half: Vector2 = slot.get_meta("half", Vector2(0.03, 0.03))
		_show_highlight(slot.global_transform, Vector2(half.x * 2.0, half.y * 2.0), 0.002)
		_show_hover_label(_name(key), slot.global_position + Vector3(0, 0.04, 0))
	elif aim["kind"] == "mat":
		if _held:
			_show_highlight(_mat.global_transform, _mat_half * 2.0, 0.006)
			return
		var piece := _mat_piece_at(aim["point"])
		if piece:
			var key: String = piece.get_meta("key")
			var size := BILL_HALF * 2.0
			if not key.begins_with("b"):
				var r: float = (_templates.get_node(key).get_node("Disc").mesh as CylinderMesh).top_radius
				size = Vector2(r, r) * 2.2
			_show_highlight(piece.global_transform, size, 0.004)
			_show_hover_label(_name(key) + (" (customer's)" if piece == _tender_piece else ""), piece.global_position + Vector3(0, 0.04, 0))

func _show_highlight(xform: Transform3D, size: Vector2, lift: float) -> void:
	var b := xform.basis.orthonormalized()
	_highlight.global_transform = Transform3D(Basis(b.x * size.x, b.y * 0.002, b.z * size.y), xform.origin + Vector3(0, lift, 0))
	_highlight.visible = true

func _show_hover_label(text: String, pos: Vector3) -> void:
	_hover_label.text = text
	_hover_label.global_position = pos
	_hover_label.visible = true

func _name(key: String) -> String:
	var cents: int = VALUES[key]
	return "$%d" % (cents / 100) if cents >= 100 else "%d¢" % cents

func _update_readout() -> void:
	if not _has_transaction:
		_readout.text = "Change given"
		_readout.modulate = Color(0.6, 1.0, 0.6)
		return
	var counted := _counted()
	var lines := ["Change due  $%.2f" % (_due / 100.0), "On the mat  $%.2f" % (counted / 100.0)]
	var color := Color(1.0, 0.92, 0.6)
	if counted > _due:
		lines.append("Too much: take some back")
		color = Color(1.0, 0.55, 0.5)
	elif not _tender_filed:
		lines.append("Put the customer's %s in the drawer" % _name(_tender_key))
	_readout.text = "\n".join(lines)
	_readout.modulate = color
	_readout.visible = true

func _flash_readout(message: String) -> void:
	_update_readout()
	_readout.text += "\n" + message
	get_tree().create_timer(1.5).timeout.connect(_update_readout)
