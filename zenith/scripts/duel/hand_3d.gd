class_name Hand3D
extends Node3D
## Camera-relative physical cards. Screen rectangles are used only for stable picking; the
## faces, captions, depth, fan and hover lift are all rendered by the 3D scene.

signal clicked(uid: int)
signal hovered(uid: int, over: bool)
signal inspected(uid: int)

const DEPTH: float = 2.4
const FACE_SIZE: Vector2 = Vector2(512, 716)
const CARD_WIDTH: float = 192.0
const EXPANDED_WIDTH: float = 390.0
const REVEAL_FRACTION: float = 0.15
const RESTING_VISIBLE_FRACTION: float = 0.15
const AURA: Shader = preload("res://scripts/duel/card_aura.gdshader")

@export var reduced_motion: bool = false
var enabled: bool = true
var keyboard_active: bool = false
var revealed: bool = false
var _camera: Camera3D
var _items: Array[Dictionary] = []
var _hovered: int = -1
var _size: Vector2 = Vector2.ZERO
var _pointer: Vector2 = Vector2.ZERO
var _expanded_rect: Rect2
var _page: int = 0
var _per_page: int = 7
var _hint: Label3D


func _ready() -> void:
	_camera = get_parent() as Camera3D
	_hint = _label(21, ZenithTheme.MUTED)
	add_child(_hint)


func set_hand(cards: Array[SeatCard], cache: CardFaceCache, legal: Dictionary, view: SeatView, prompt: PromptView = null) -> void:
	var old_uid: int = int(_items[_hovered]["uid"]) if _hovered >= 0 and _hovered < _items.size() else -1
	_set_hover(-1)
	for item in _items:
		(item["node"] as Node3D).hide()
		(item["node"] as Node3D).queue_free()
	_items.clear()
	for card in cards:
		if card.hidden():
			continue
		var def: CardDef = Session.library.defs.get(card.def_id)
		if def == null:
			continue
		var holder: Node3D = Node3D.new()
		add_child(holder)
		var face: Sprite3D = Sprite3D.new()
		face.texture = cache.face(def, card.aspect)
		face.shaded = false
		face.no_depth_test = true
		face.double_sided = false
		face.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		holder.add_child(face)
		var edge: MeshInstance3D = MeshInstance3D.new()
		edge.mesh = QuadMesh.new()
		var aura: ShaderMaterial = ShaderMaterial.new()
		aura.shader = AURA
		aura.set_shader_parameter("tint", Color(ZenithTheme.ACCENT, 0.95) if legal.has(card.uid) else Color(0.15, 0.20, 0.26, 0.22))
		edge.material_override = aura
		edge.position.z = -0.003
		holder.add_child(edge)
		# The edge is a slightly enlarged silhouette behind the actual face.
		var title: Label3D = _label(22, ZenithTheme.TEXT)
		title.text = card.title
		title.width = CARD_WIDTH * 2.0 - 12.0
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		holder.add_child(title)
		var forecast: Dictionary = view.forecast(card.uid)
		var summary: Label3D = _label(23, ZenithTheme.ATTACK if legal.has(card.uid) else ZenithTheme.MUTED)
		if not forecast.is_empty():
			summary.text = ("Final: " if bool(forecast.get("is_final", false)) else "") + CardText.short_damage(int(forecast.get("stages", 0)), int(forecast.get("life", 0)))
		else:
			summary.text = CardText.TYPE_LABELS[def.type]
			if prompt != null:
				for option in prompt.options_for_card(card.uid):
					if option.type == &"defend" or option.type == &"power_defend":
						summary.text = "Defend"
						break
					elif option.type == &"counter":
						summary.text = "Counter"
						break
		if int(forecast.get("cost_stages", 0)) > 0:
			summary.text += " · Cost %d" % int(forecast["cost_stages"])
		holder.add_child(summary)
		_items.append({"uid": card.uid, "node": holder, "face": face, "edge": edge,
			"title": title, "summary": summary, "legal": legal.has(card.uid), "rect": Rect2(),
			"target": Vector3.ZERO, "scale": 1.0, "angle": 0.0})
	_page = clampi(_page, 0, maxi(0, ceili(float(_items.size()) / _per_page) - 1))
	_layout(true)
	if keyboard_active:
		for i in range(_items.size()):
			if int(_items[i]["uid"]) == old_uid:
				_set_hover(i)
				return


func set_available(on: bool) -> void:
	if visible == on:
		return
	visible = on
	if not on:
		keyboard_active = false
		_set_revealed(false)
		_layout(true)
		_pointer = Vector2(-1, -1)


func preview_index(index: int) -> void:
	if not _items.is_empty():
		keyboard_active = true
		_pointer = get_viewport().get_mouse_position()
		_set_revealed(true)
		var i: int = clampi(index, 0, _items.size() - 1)
		_page = i / _per_page
		_set_hover(i)


func remove_uid(uid: int) -> void:
	for i in range(_items.size()):
		if int(_items[i]["uid"]) == uid:
			_set_hover(-1)
			(_items[i]["node"] as Node3D).queue_free()
			_items.remove_at(i)
			_layout()
			return


func world_card_transform(uid: int) -> Variant:
	for item in _items:
		if int(item["uid"]) == uid:
			var node: Node3D = item["node"]
			var face: Sprite3D = item["face"]
			var factor: float = face.pixel_size * FACE_SIZE.x * node.scale.x / TableLayout.CARD_SIZE.x
			return Transform3D((_camera.global_basis * Basis(Vector3.RIGHT, PI * 0.5)).scaled(Vector3.ONE * factor), node.global_position)
	return null


## Only a publicly visible draw for this viewer reaches this method. Existing cards retain
## their positions while the new face travels from its source into the hand.
func receive_card(card: SeatCard, cache: CardFaceCache, view: SeatView, from: Vector3) -> void:
	if card == null or card.hidden():
		return
	var cards: Array[SeatCard] = []
	var poses: Dictionary = {}
	for item in _items:
		var uid: int = int(item["uid"])
		if uid == card.uid:
			return
		var existing: SeatCard = view.card(uid)
		if existing != null and not existing.hidden():
			cards.append(existing)
			poses[uid] = (item["node"] as Node3D).transform
	cards.append(card)
	set_hand(cards, cache, {}, view)
	for item in _items:
		var node: Node3D = item["node"]
		var uid: int = int(item["uid"])
		if poses.has(uid):
			node.transform = poses[uid]
		elif not reduced_motion:
			node.position = _camera.to_local(from)
			node.scale = Vector3.ONE * 0.35


func _label(font_size: int, color: Color) -> Label3D:
	var label: Label3D = Label3D.new()
	label.font_size = font_size * 2
	label.modulate = color
	label.outline_size = 12
	label.outline_modulate = Color(0.025, 0.03, 0.045, 0.95)
	label.shaded = false
	label.no_depth_test = true
	label.double_sided = false
	return label


func _process(delta: float) -> void:
	if not visible:
		return
	if _size != get_viewport().get_visible_rect().size:
		_layout(true)
	# Poll movement too: GUI panels may consume motion before unhandled input sees it.
	var pointer: Vector2 = get_viewport().get_mouse_position()
	if pointer != _pointer:
		_update_pointer(pointer)
	var speed: float = 1.0 if reduced_motion else 1.0 - exp(-22.0 * delta)
	for item in _items:
		var node: Node3D = item["node"]
		node.position = node.position.lerp(item["target"], speed)
		node.rotation.z = lerp_angle(node.rotation.z, float(item["angle"]), speed)
		var target_scale: Vector3 = Vector3.ONE * float(item["scale"])
		node.scale = node.scale.lerp(target_scale, speed)


func _layout(snap: bool = false) -> void:
	if _camera == null:
		return
	_size = get_viewport().get_visible_rect().size
	_expanded_rect = Rect2()
	var width: float = minf(CARD_WIDTH, _size.x * 0.105)
	var height: float = width * FACE_SIZE.y / FACE_SIZE.x
	var band: float = minf(_size.x * 0.53, 1040.0)
	var old_first: int = _page * _per_page
	_per_page = maxi(3, int(band / (width * 0.64)))
	_page = clampi((_hovered if _hovered >= 0 else old_first) / _per_page, 0, maxi(0, ceili(float(_items.size()) / _per_page) - 1))
	var first: int = _page * _per_page
	var count: int = mini(_per_page, _items.size() - first)
	var step: float = minf(width + 14.0, (band - width) / maxf(1.0, count - 1))
	var units: float = _units_per_pixel()
	for i in range(_items.size()):
		var item: Dictionary = _items[i]
		var node: Node3D = item["node"]
		node.visible = i >= first and i < first + count
		if not node.visible:
			item["rect"] = Rect2()
			continue
		var offset: float = i - first - (count - 1) * 0.5
		var center: Vector2 = Vector2(_size.x * 0.52 + offset * step, _size.y - height * 0.5 - 64.0 + absf(offset) * 5.0)
		item["rect"] = Rect2(center - Vector2(width, height) * 0.5, Vector2(width, height)) if revealed else Rect2()
		var over: bool = revealed and i == _hovered
		var scale_factor: float = minf(EXPANDED_WIDTH / width, (_size.y * 0.58) / height) if over else 1.0
		if over:
			center.y = _size.y - height * scale_factor * 0.5 - 58.0
			center.x = clampf(center.x, 280.0, _size.x - 455.0)
			_expanded_rect = Rect2(center - Vector2(width, height) * scale_factor * 0.5, Vector2(width, height) * scale_factor)
		if not revealed:
			# A shallow strip of real card tops advertises the tucked hand.
			center.y = _size.y + height * (0.5 - RESTING_VISIBLE_FRACTION)
		var depth: float = DEPTH - (0.2 if over else 0.001 * i)
		item["target"] = _camera.to_local(_camera.project_position(center, depth))
		item["scale"] = scale_factor * depth / DEPTH
		item["angle"] = 0.0 if over else deg_to_rad(-offset * 2.0)
		var face: Sprite3D = item["face"]
		face.pixel_size = width / FACE_SIZE.x * units
		face.render_priority = 30 if over else 10 + i % _per_page
		face.modulate = Color.WHITE if bool(item["legal"]) or over else Color(0.84, 0.85, 0.89)
		var edge: MeshInstance3D = item["edge"]
		(edge.mesh as QuadMesh).size = Vector2(width, height) * units * 1.10
		var title: Label3D = item["title"]
		title.render_priority = face.render_priority
		title.pixel_size = units * 0.5
		title.width = width * 2.0 - 12.0
		title.position = Vector3(0, height * units * 0.5 + 24.0 * units, 0.004)
		title.visible = revealed and not over
		var summary: Label3D = item["summary"]
		summary.render_priority = face.render_priority + 1
		summary.visible = revealed
		summary.pixel_size = units * 0.5 / scale_factor
		summary.position = Vector3(0, -height * units * 0.5 - 19.0 * units / scale_factor, 0.005)
		if snap:
			node.position = item["target"]
			node.rotation.z = float(item["angle"])
			node.scale = Vector3.ONE * float(item["scale"])
	var pages: int = maxi(1, ceili(float(_items.size()) / _per_page))
	_hint.text = "H · browse hand   Right-click · inspect" if pages == 1 else "Hand %d / %d   Wheel · browse   H · select" % [_page + 1, pages]
	if not revealed:
		_hint.text = "Hand %d  |  H" % _items.size()
	_hint.pixel_size = units * 0.5
	_hint.position = _camera.to_local(_camera.project_position(Vector2(_size.x * 0.52, _size.y - 15.0), DEPTH - 0.25))
	_hint.visible = revealed and not _items.is_empty() and _hovered < 0


func _units_per_pixel() -> float:
	var a: Vector3 = _camera.project_position(Vector2.ZERO, DEPTH)
	var b: Vector3 = _camera.project_position(Vector2(1, 0), DEPTH)
	return a.distance_to(b)


func _set_hover(index: int) -> void:
	if _hovered == index:
		return
	if _hovered >= 0 and _hovered < _items.size():
		hovered.emit(int(_items[_hovered]["uid"]), false)
	_hovered = index
	_layout()
	if _hovered >= 0:
		hovered.emit(int(_items[_hovered]["uid"]), true)


func _hit(point: Vector2, clicking: bool = false) -> int:
	if not visible or not revealed:
		return -1
	if clicking and _hovered >= 0 and _expanded_rect.has_point(point):
		return _hovered
	# Resting slots take precedence so enlarging a card never prevents selecting its neighbour.
	for i in range(_items.size() - 1, -1, -1):
		if (_items[i]["rect"] as Rect2).has_point(point):
			return i
	if _hovered >= 0 and _expanded_rect.has_point(point):
		return _hovered
	return -1


func _set_revealed(on: bool) -> void:
	on = on and not _items.is_empty()
	if revealed == on:
		return
	revealed = on
	if not on:
		_set_hover(-1)
	_layout(reduced_motion)


func _update_pointer(point: Vector2) -> void:
	_pointer = point
	keyboard_active = false
	if not visible or _items.is_empty():
		return
	var bottom: bool = point.y >= _size.y * (1.0 - REVEAL_FRACTION) and Rect2(Vector2.ZERO, _size).has_point(point)
	if bottom:
		_set_revealed(true)
	elif not revealed or _hit(point) < 0:
		_set_revealed(false)
	_set_hover(_hit(point))


## The table uses this same footprint to suppress ray picking and background tooltips.
func blocks_pointer(point: Vector2) -> bool:
	if not visible or _items.is_empty():
		return false
	var bottom: bool = point.y >= _size.y * (1.0 - REVEAL_FRACTION) and Rect2(Vector2.ZERO, _size).has_point(point)
	return bottom or (revealed and _hit(point, true) >= 0)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseMotion:
		var point: Vector2 = (event as InputEventMouseMotion).position
		_update_pointer(point)
		if blocks_pointer(point):
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		var hit: int = _hit(mb.position, true)
		if hit < 0 or not mb.pressed:
			return
		_set_hover(hit)
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			inspected.emit(int(_items[hit]["uid"]))
		elif mb.button_index == MOUSE_BUTTON_LEFT and enabled:
			clicked.emit(int(_items[hit]["uid"]))
		elif mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var pages: int = maxi(1, ceili(float(_items.size()) / _per_page))
			_page = posmod(_page + (1 if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1), pages)
			_set_hover(-1)
			_layout()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		var key: InputEventKey = event
		if not key.pressed or key.echo or _items.is_empty():
			return
		if key.keycode == KEY_ESCAPE and revealed:
			keyboard_active = false
			_set_revealed(false)
		elif key.keycode == KEY_H:
			keyboard_active = true
			preview_index(_page * _per_page)
		elif keyboard_active:
			match key.keycode:
				KEY_LEFT, KEY_RIGHT:
					preview_index(posmod(_hovered + (1 if key.keycode == KEY_RIGHT else -1), _items.size()))
				KEY_ENTER, KEY_KP_ENTER:
					if enabled and _hovered >= 0:
						clicked.emit(int(_items[_hovered]["uid"]))
				KEY_SPACE:
					if _hovered >= 0:
						inspected.emit(int(_items[_hovered]["uid"]))
				_:
					return
		else:
			return
		get_viewport().set_input_as_handled()
