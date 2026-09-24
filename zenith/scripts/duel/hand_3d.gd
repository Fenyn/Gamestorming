class_name Hand3D
extends Node3D
## Camera-relative physical cards. Screen rectangles are used only for stable picking; the
## faces, captions, depth, fan and reading preview are all rendered by the 3D scene.

signal clicked(uid: int)
signal hovered(uid: int, over: bool)
signal inspected(uid: int)

const DEPTH: float = 2.4
const FACE_SIZE: Vector2 = Vector2(512, 716)
const CARD_WIDTH: float = 240.0
const WIDTH_FRACTION: float = 0.125                 # of the viewport width, on narrow screens
const FAN_CENTRE: float = 0.5                       # share of the viewport width, under the table's centre
const EXPANDED_WIDTH: float = 390.0
const REVEAL_FRACTION: float = 0.15
## The tucked hand shows each card's title band and the top of its art.
const RESTING_VISIBLE_FRACTION: float = 0.28
const AURA: Shader = preload("res://scripts/duel/card_aura.gdshader")
const BORDER_FX: PackedScene = preload("res://scenes/duel/card_border_fx.tscn")
const HOVER_TINT: Color = Color(0.48, 0.88, 1.0, 1.0)
const DULL_FACE: Color = Color(0.42, 0.43, 0.47)   # clearly out of play, still readable up close
const LEFT_CLEAR: float = 24.0                     # margin the preview keeps from the left screen edge
const PREVIEW_MARGIN: float = 18.0

@export var reduced_motion: bool = false:
	set(value):
		if reduced_motion == value:
			return
		reduced_motion = value
		_layout(value)
var enabled: bool = true:
	set(value):
		if enabled == value:
			return
		enabled = value
		_layout()
var keyboard_active: bool = false
var revealed: bool = false
var _camera: Camera3D
var _items: Array[Dictionary] = []
var _hovered: int = -1
var _viewer: int = -2
var _size: Vector2 = Vector2.ZERO
var _pointer: Vector2 = Vector2.ZERO
var _expanded_rect: Rect2
var _page: int = 0
var _per_page: int = 7
var _hint: Label3D
var _preview: Node3D
var _preview_face: Sprite3D
var _preview_edge: MeshInstance3D
var _preview_border: Node3D
var _preview_title: Label3D
var _preview_summary: Label3D
var _handoff_rect: Rect2 = Rect2()
var _hero_left: float = -1.0
var _hero_right: float = -1.0
var _hero_bottom: float = -1.0
var _decision_rect: Rect2 = Rect2()


func _ready() -> void:
	_camera = get_parent() as Camera3D
	_hint = _label(21, ZenithTheme.MUTED)
	add_child(_hint)
	_preview = Node3D.new()
	add_child(_preview)
	_preview_face = Sprite3D.new()
	_preview_face.shaded = false
	_preview_face.no_depth_test = true
	_preview_face.double_sided = false
	_preview_face.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_preview_face.render_priority = 30
	_preview.add_child(_preview_face)
	_preview_edge = MeshInstance3D.new()
	_preview_edge.mesh = QuadMesh.new()
	var preview_aura: ShaderMaterial = ShaderMaterial.new()
	preview_aura.shader = AURA
	_preview_edge.material_override = preview_aura
	_preview_edge.position.z = -0.003
	_preview.add_child(_preview_edge)
	_preview_border = BORDER_FX.instantiate()
	_preview.add_child(_preview_border)
	_preview_title = _label(24, ZenithTheme.TEXT)
	_preview_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_title.render_priority = 31
	_preview.add_child(_preview_title)
	_preview_summary = _label(23, ZenithTheme.MUTED)
	_preview_summary.render_priority = 31
	_preview.add_child(_preview_summary)
	_preview.hide()


## The duel scene supplies the player's projected Life-and-fighter span. The reading face
## uses it; the physical cards keep their fan positions along the bottom edge.
func set_hero_bounds(left: float, right: float, bottom: float) -> void:
	if absf(_hero_left - left) < 1.0 and absf(_hero_right - right) < 1.0 and absf(_hero_bottom - bottom) < 1.0:
		return
	_hero_left = left
	_hero_right = right
	_hero_bottom = bottom
	if revealed:
		_layout()


func set_decision_rect(rect: Rect2) -> void:
	if _decision_rect.position.distance_to(rect.position) < 1.0 and _decision_rect.size.distance_to(rect.size) < 1.0:
		return
	_decision_rect = rect
	if revealed:
		_layout()


func set_hand(cards: Array[SeatCard], cache: CardFaceCache, legal: Dictionary, view: SeatView, prompt: PromptView = null) -> void:
	var old_uid: int = int(_items[_hovered]["uid"]) if _hovered >= 0 and _hovered < _items.size() else -1
	var viewer_changed: bool = _viewer != view.seat
	var retained: Dictionary = {}
	for item in _items:
		retained[int(item["uid"])] = item
	var next_items: Array[Dictionary] = []
	var created: Array[Dictionary] = []
	for card in cards:
		if card.hidden():
			continue
		var def: CardDef = Session.library.defs.get(card.def_id)
		if def == null:
			continue
		var item: Dictionary
		if not viewer_changed and retained.has(card.uid):
			item = retained[card.uid]
			retained.erase(card.uid)
		else:
			item = _create_item(card, def, cache, legal)
			created.append(item)
		_refresh_item(item, card, def, cache, legal, view, prompt)
		next_items.append(item)
	var next_hover: int = -1
	if not viewer_changed:
		for i in range(next_items.size()):
			if int(next_items[i]["uid"]) == old_uid:
				next_hover = i
	if old_uid >= 0 and next_hover < 0:
		hovered.emit(old_uid, false)
	for item in retained.values():
		# Remove private faces synchronously, before deferred deletion can render a frame.
		(item["node"] as Node3D).hide()
		(item["node"] as Node3D).queue_free()
	_items = next_items
	_hovered = next_hover
	_viewer = view.seat
	if viewer_changed or _items.is_empty():
		keyboard_active = false
		revealed = false
		_page = 0
	_page = clampi(_page, 0, maxi(0, ceili(float(_items.size()) / _per_page) - 1))
	_layout(viewer_changed or reduced_motion)
	for item in created:
		var node: Node3D = item["node"]
		node.position = item["target"]
		node.scale = Vector3.ONE * float(item["scale"])
		node.rotation.z = float(item["angle"])
	if _hovered >= 0:
		# Revalidate the same inspected card against the new prompt/forecast.
		hovered.emit(old_uid, true)


func _create_item(card: SeatCard, def: CardDef, cache: CardFaceCache, legal: Dictionary) -> Dictionary:
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
	var border_fx: Node3D = BORDER_FX.instantiate()
	holder.add_child(border_fx)
	# The edge is a slightly enlarged silhouette behind the actual face.
	var title: Label3D = _label(24, ZenithTheme.TEXT)
	title.text = card.title
	title.width = CARD_WIDTH * 2.0 - 12.0
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	holder.add_child(title)
	var summary: Label3D = _label(23, ZenithTheme.MUTED)
	holder.add_child(summary)
	return {"uid": card.uid, "node": holder, "face": face, "edge": edge, "border_fx": border_fx, "effect_tint": ZenithTheme.ACCENT,
		"title": title, "summary": summary, "legal": legal.has(card.uid), "rect": Rect2(),
		"target": Vector3.ZERO, "scale": 1.0, "angle": 0.0}


func _refresh_item(item: Dictionary, card: SeatCard, def: CardDef, cache: CardFaceCache, legal: Dictionary, view: SeatView, prompt: PromptView) -> void:
	var playable: bool = legal.has(card.uid)
	item["legal"] = playable
	item["effect_tint"] = ZenithTheme.ACCENT
	if prompt != null:
		for option in prompt.options_for_card(card.uid):
			if option.type in [&"defend", &"power_defend", &"counter"]:
				item["effect_tint"] = ZenithTheme.DEFEND
				break
			if option.type in [&"attack", &"final_strike"]:
				item["effect_tint"] = ZenithTheme.ATTACK
	(item["face"] as Sprite3D).texture = cache.face(def, card.aspect)
	(item["title"] as Label3D).text = card.title
	item["title_text"] = card.title
	item["hover_title"] = "%s · %s" % [CardText.TYPE_LABELS[def.type], card.title]
	var aura: ShaderMaterial = (item["edge"] as MeshInstance3D).material_override
	aura.set_shader_parameter("tint", Color(ZenithTheme.ACCENT, 0.95) if playable else Color(0.15, 0.20, 0.26, 0.22))
	var summary: Label3D = item["summary"]
	summary.modulate = ZenithTheme.ATTACK if playable else ZenithTheme.MUTED
	var forecast: Dictionary = view.forecast(card.uid)
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
		summary.text += " | Cost %d" % int(forecast["cost_stages"])


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
			if _hovered == i:
				_set_hover(-1)
			elif _hovered > i:
				_hovered -= 1
			(_items[i]["node"] as Node3D).hide()
			(_items[i]["node"] as Node3D).queue_free()
			_items.remove_at(i)
			if _items.is_empty():
				keyboard_active = false
				revealed = false
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
	_handoff_rect = Rect2()
	_preview.hide()
	# The open fan rises over the lower table, the player's readout included, while it is held
	# open. The tucked hand uses the same size so tucking is a pure drop.
	var width: float = minf(CARD_WIDTH, _size.x * WIDTH_FRACTION)
	var height: float = width * FACE_SIZE.y / FACE_SIZE.x
	var band: float = minf(_size.x * 0.53, 1040.0)
	var old_first: int = _page * _per_page
	# Each card keeps a little over half its width clear, so seven fit on one page at any size.
	_per_page = maxi(3, int(band / (width * 0.55)))
	_page = clampi((_hovered if _hovered >= 0 else old_first) / _per_page, 0, maxi(0, ceili(float(_items.size()) / _per_page) - 1))
	var first: int = _page * _per_page
	var count: int = mini(_per_page, _items.size() - first)
	var step: float = minf(width + 14.0, (band - width) / maxf(1.0, count - 1))
	var fan_shift: float = 0.0
	var fan_top: float = _size.y - height - 64.0
	var fan_right: float = _size.x * FAN_CENTRE +(count - 1) * 0.5 * step + width * 0.5
	if _decision_rect.has_area() and _decision_rect.position.y < _size.y - 58.0 and _decision_rect.end.y > fan_top:
		fan_shift = minf(0.0, _decision_rect.position.x - PREVIEW_MARGIN - fan_right)
	var units: float = _units_per_pixel()
	for i in range(_items.size()):
		var item: Dictionary = _items[i]
		var node: Node3D = item["node"]
		node.visible = i >= first and i < first + count
		var over: bool = revealed and i == _hovered
		# Tucked or open, it is the same fan: playable cards keep their rim and sparks, only the
		# hover highlight needs the hand open.
		var lit: bool = visible and node.visible and (over or (enabled and bool(item["legal"])))
		var effect_tint: Color = HOVER_TINT if over else (item["effect_tint"] as Color)
		var border_fx: Node3D = item["border_fx"]
		border_fx.scale = Vector3(width * units / 0.63, height * units / 0.88, 1.0)
		border_fx.set_effect(effect_tint, lit, reduced_motion)
		var aura: ShaderMaterial = (item["edge"] as MeshInstance3D).material_override
		aura.set_shader_parameter("motion", 0.0 if reduced_motion else 1.0)
		aura.set_shader_parameter("selected", 1.0 if over else 0.0)
		aura.set_shader_parameter("tint", Color(effect_tint, 1.0) if lit else Color(0.15, 0.20, 0.26, 0.16))
		aura.set_shader_parameter("highlight", 1.0 if enabled and bool(item["legal"]) else 0.0)
		if not node.visible:
			item["rect"] = Rect2()
			continue
		var offset: float = i - first - (count - 1) * 0.5
		var center: Vector2 = Vector2(_size.x * FAN_CENTRE + fan_shift + offset * step, _size.y - height * 0.5 - 64.0 + absf(offset) * 5.0)
		item["rect"] = Rect2(center - Vector2(width, height) * 0.5, Vector2(width, height)) if revealed else Rect2()
		if not revealed:
			# A shallow strip of real card tops advertises the tucked hand.
			center.y = _size.y + height * (0.5 - RESTING_VISIBLE_FRACTION) + absf(offset) * 5.0
		var depth: float = DEPTH - (0.2 if over else 0.001 * i)
		item["target"] = _camera.to_local(_camera.project_position(center, depth))
		item["scale"] = depth / DEPTH
		item["angle"] = deg_to_rad(-offset * 2.0)
		var face: Sprite3D = item["face"]
		face.pixel_size = width / FACE_SIZE.x * units
		face.render_priority = 30 if over else 10 + i % _per_page
		# A card the pending prompt has no option for greys out, so the hand says what this phase
		# will take without being read card by card. While the decision is not ours there is no
		# option list to judge against, so the whole hand stays in colour.
		var dulled: bool = enabled and not over and not bool(item["legal"])
		face.modulate = DULL_FACE if dulled else Color.WHITE
		var edge: MeshInstance3D = item["edge"]
		# The rim sits on the card's own edge, which follows the hand's actual size rather than
		# the shader's nominal card, so a narrow viewport keeps the filament on the border.
		var world: Vector2 = Vector2(width, height) * units
		(edge.mesh as QuadMesh).size = world * 1.10
		aura.set_shader_parameter("plane_size", world * 1.10)
		aura.set_shader_parameter("border_extent", world * 0.504)
		var title: Label3D = item["title"]
		title.modulate = ZenithTheme.MUTED if dulled else ZenithTheme.TEXT
		title.render_priority = face.render_priority
		title.pixel_size = units * 0.5
		title.width = width * 2.0 - 12.0
		title.position = Vector3(0, height * units * 0.5 + 24.0 * units, 0.004)
		title.text = item["title_text"]
		title.visible = revealed
		var summary: Label3D = item["summary"]
		summary.render_priority = face.render_priority + 1
		summary.visible = revealed
		summary.pixel_size = units * 0.5
		summary.position = Vector3(0, -height * units * 0.5 - 19.0 * units, 0.005)
		if over:
			_layout_preview(item, width, height, units)
		if snap:
			node.position = item["target"]
			node.rotation.z = float(item["angle"])
			node.scale = Vector3.ONE * float(item["scale"])
	var pages: int = maxi(1, ceili(float(_items.size()) / _per_page))
	_hint.text = "H · browse hand   Right-click · inspect" if pages == 1 else "Hand %d / %d   Wheel · browse   H · select" % [_page + 1, pages]
	if not revealed:
		_hint.text = "Hand %d  |  H" % _items.size()
	_hint.pixel_size = units * 0.5
	_hint.position = _camera.to_local(_camera.project_position(Vector2(_size.x * FAN_CENTRE, _size.y - 15.0), DEPTH - 0.25))
	_hint.visible = revealed and not _items.is_empty() and _hovered < 0


## The source card stays in its fan slot for direct pointer tracking. A separate face occupies
## the safe reading lane, so moving the pointer does not leave an invisible card-shaped target.
func _layout_preview(item: Dictionary, width: float, height: float, units: float) -> void:
	var source: Rect2 = item["rect"]
	var hero_left: float = _hero_left if _hero_left >= 0.0 else _size.x * 0.40
	var hero_right: float = _hero_right if _hero_right >= 0.0 else _size.x * 0.58
	var preview_top: float = _size.y - minf(EXPANDED_WIDTH / width, (_size.y * 0.50) / height) * height - 58.0
	var right_end: float = _size.x - 48.0
	if _decision_rect.has_area() and _decision_rect.position.y < _size.y - 58.0 and _decision_rect.end.y > preview_top:
		right_end = minf(right_end, _decision_rect.position.x - PREVIEW_MARGIN)
	var left_end: float = minf(hero_left - PREVIEW_MARGIN, source.position.x - PREVIEW_MARGIN)
	var right_start: float = maxf(hero_right + PREVIEW_MARGIN, source.end.x + PREVIEW_MARGIN)
	var left_width: float = maxf(0.0, left_end - LEFT_CLEAR)
	var right_width: float = maxf(0.0, right_end - right_start)
	var left_lane: bool = source.get_center().x < (hero_left + hero_right) * 0.5
	if left_lane and left_width < width and right_width > left_width:
		left_lane = false
	elif not left_lane and right_width < width and left_width > right_width:
		left_lane = true
	var lane_start: float = LEFT_CLEAR if left_lane else right_start
	var lane_end: float = left_end if left_lane else right_end
	var scale_factor: float = minf(EXPANDED_WIDTH / width, (_size.y * 0.50) / height)
	scale_factor = minf(scale_factor, maxf(0.2, (lane_end - lane_start) / width))
	var center: Vector2 = source.get_center()
	center.y = _size.y - height * scale_factor * 0.5 - 58.0
	center.x = clampf(center.x, lane_start + width * scale_factor * 0.5, lane_end - width * scale_factor * 0.5)
	_expanded_rect = Rect2(center - Vector2(width, height) * scale_factor * 0.5, Vector2(width, height) * scale_factor)
	var overlap_top: float = maxf(source.position.y, _expanded_rect.position.y)
	var overlap_bottom: float = minf(source.end.y, _expanded_rect.end.y)
	if overlap_bottom > overlap_top:
		if _expanded_rect.end.x < source.position.x:
			_handoff_rect = Rect2(Vector2(_expanded_rect.end.x, overlap_top), Vector2(source.position.x - _expanded_rect.end.x, overlap_bottom - overlap_top))
		elif source.end.x < _expanded_rect.position.x:
			_handoff_rect = Rect2(Vector2(source.end.x, overlap_top), Vector2(_expanded_rect.position.x - source.end.x, overlap_bottom - overlap_top))
	var depth: float = DEPTH - 0.2
	_preview.position = _camera.to_local(_camera.project_position(center, depth))
	_preview.scale = Vector3.ONE * scale_factor * depth / DEPTH
	_preview_face.texture = (item["face"] as Sprite3D).texture
	_preview_face.pixel_size = width / FACE_SIZE.x * units
	var world: Vector2 = Vector2(width, height) * units
	(_preview_edge.mesh as QuadMesh).size = world * 1.10
	var aura: ShaderMaterial = _preview_edge.material_override
	aura.set_shader_parameter("motion", 0.0 if reduced_motion else 1.0)
	aura.set_shader_parameter("selected", 1.0)
	aura.set_shader_parameter("tint", Color(HOVER_TINT, 1.0))
	aura.set_shader_parameter("highlight", 1.0)
	aura.set_shader_parameter("plane_size", world * 1.10)
	aura.set_shader_parameter("border_extent", world * 0.504)
	_preview_border.scale = Vector3(width * units / 0.63, height * units / 0.88, 1.0)
	_preview_border.set_effect(HOVER_TINT, true, reduced_motion)
	_preview_title.text = item["hover_title"]
	_preview_title.pixel_size = units * 0.5 / scale_factor
	_preview_title.width = width * 2.0 * scale_factor - 12.0
	_preview_title.position = Vector3(0, height * units * 0.5 + 24.0 * units / scale_factor, 0.004)
	var source_summary: Label3D = item["summary"]
	_preview_summary.text = source_summary.text
	_preview_summary.modulate = source_summary.modulate
	_preview_summary.pixel_size = units * 0.5 / scale_factor
	_preview_summary.position = Vector3(0, -height * units * 0.5 - 19.0 * units / scale_factor, 0.005)
	_preview.show()


func _units_per_pixel() -> float:
	var a: Vector3 = _camera.project_position(Vector2.ZERO, DEPTH)
	var b: Vector3 = _camera.project_position(Vector2(1, 0), DEPTH)
	return a.distance_to(b)


## The uid of the hand card the pointer or keyboard is on, -1 for none.
func hovered_uid() -> int:
	return int(_items[_hovered]["uid"]) if _hovered >= 0 and _hovered < _items.size() else -1


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
	if _hovered >= 0 and _expanded_rect.has_point(point):
		return _hovered
	# The reading face is drawn in front. Elsewhere the card under the pointer owns the hover.
	for i in range(_items.size() - 1, -1, -1):
		if (_items[i]["rect"] as Rect2).has_point(point):
			return i
	if not clicking and _hovered >= 0 and _handoff_rect.has_point(point):
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
	return bottom or (revealed and (_hit(point, true) >= 0 or _handoff_rect.has_point(point)))


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
		if mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and revealed and _items.size() > _per_page:
			var hand_band: Rect2 = Rect2(Vector2(0.0, _size.y * (1.0 - REVEAL_FRACTION)), Vector2(_size.x, _size.y * REVEAL_FRACTION))
			if hand_band.has_point(mb.position) or _hit(mb.position, true) >= 0:
				var pages: int = ceili(float(_items.size()) / _per_page)
				_page = posmod(_page + (1 if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1), pages)
				_set_hover(-1)
				_layout()
				get_viewport().set_input_as_handled()
				return
		var hit: int = _hit(mb.position, true)
		if hit < 0 or not mb.pressed:
			return
		_set_hover(hit)
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			inspected.emit(int(_items[hit]["uid"]))
		elif mb.button_index == MOUSE_BUTTON_LEFT and enabled:
			clicked.emit(int(_items[hit]["uid"]))
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
