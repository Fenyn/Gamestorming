class_name MapRoute
extends Control
## The run's whole node map on the dark Kenney board: every act stacked bottom to top, act 1 at the
## foot, each act's boss at its crown, a Kenney double rule between acts and a small framed tag
## naming each. The board is the frame the map sits in; this control draws no ground of its own.
## Nodes are Kenney icons on dark tiles, joined by dashed roads: the road already walked is in the
## run's school colour (MapArt.school), the roads open next are bone-white, and the nodes the run may step to next
## glow and breathe. Clicking any node selects it for scouting; only the stage screen commits a
## step. Sits inside a ScrollContainer: `focus_y()` says where to scroll.

signal node_selected(id: String)

const LANE_MARGIN: float = 64.0
## The lanes never spread wider than this, so a wide screen keeps the map a readable column.
const MAX_CONTENT_WIDTH: float = 880.0
const TIER_GAP: float = 100.0
const ACT_HEADER: float = 100.0
## Room under each act's first tier; act 1's holds the player's token before the first step.
const ACT_FOOT: float = 140.0
## The player's token: the run's own Duelist portrait, beside the node the run stands on.
const TOKEN_SIZE: Vector2 = Vector2(56, 68)
const NODE_SIZE: float = 72.0
const BOSS_SIZE: float = 112.0
const FLAIR_SIZE: float = 30.0
## A wash over the acts the run is not in, fading out over WASH_FEATHER at the edge it shares
## with the current act.
const OTHER_ACT_WASH: Color = Color(0.0, 0.0, 0.0, 0.32)
const WASH_FEATHER: float = 160.0
## The Kenney double rule between acts.
const DIVIDER_HEIGHT: float = 22.0
## Under each road dash and round the token, so both stand off the board.
const INK: Color = Color(ZenithTheme.BG_SCREEN, 0.9)
## A road nobody has walked or may walk yet: a quiet grey on the dark board.
const ROAD: Color = Color(ZenithTheme.TEXT_SOFT, 0.42)
const OPEN_ROAD: Color = ZenithTheme.ACCENT
const ROMAN: Array[String] = ["", "I", "II", "III", "IV", "V"]

var act: int = 1
var _map: AdventureMap = null
var _path: Array[String] = []
var _here: String = ""
var _choices: Array[String] = []
var _selected: String = ""
var _buttons: Dictionary = {}   # id -> TextureButton
var _roads: Control = null
var _marks: Control = null
var _labels: Array[Label] = []
var _token: Control = null
var _portrait: Texture2D = null
var _clock: float = 0.0


func setup(run: AdventureRun, map: AdventureMap) -> void:
	_map = map
	_path = run.path.duplicate()
	_here = run.node_id
	_choices = run.choices(map)
	act = act_to_show(run, map)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = Vector2(360, _act_height() * float(map.acts))
	_roads = _overlay(_draw_roads)
	for id in map.nodes.keys():
		_buttons[id] = _make_button(str(id))
	_marks = _overlay(_draw_marks)
	# The Kenney tags, rules and brackets are pixel art; keep their edges hard. Text goes on a layer
	# of its own, since a font does not survive nearest filtering.
	_marks.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for a in range(1, map.acts + 1):
		var label: Label = Label.new()
		label.text = "ACT %s" % ROMAN[mini(a, ROMAN.size() - 1)]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", ZenithTheme.TEXT)
		label.add_theme_font_size_override("font_size", ZenithTheme.SIZE_BODY)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
		_labels.append(label)
	if not run.duelist_ids.is_empty():
		var duelist: CardDef = Session.library.defs.get(run.duelist_ids[run.duelist_ids.size() - 1])
		_portrait = CardFace.art_texture(duelist) if duelist != null else null
	_token = _overlay(_draw_token)
	_selected = _choices[0] if not _choices.is_empty() else _here
	resized.connect(_layout)
	_layout()


## The act a screen should show: the one holding the next choices while choosing, else the one the
## run stands in.
static func act_to_show(run: AdventureRun, map: AdventureMap) -> int:
	var choices: Array[String] = run.choices(map)
	var id: String = choices[0] if not choices.is_empty() else run.node_id
	var n: Dictionary = map.node(id)
	return int(n.get("act", 1)) if not n.is_empty() else 1


func select(id: String) -> void:
	_selected = id
	_marks.queue_redraw()
	node_selected.emit(id)


func selected() -> String:
	return _selected


func buttons() -> Dictionary:
	return _buttons


## Where a scroll container should centre: the node the run stands on, or its first choice.
func focus_y() -> float:
	var id: String = _choices[0] if not _choices.is_empty() else _here
	if id == "" or _map == null:
		return size.y
	return _point(id).y


func _overlay(painter: Callable) -> Control:
	var layer: Control = Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.draw.connect(painter)
	return layer


func _act_height() -> float:
	return ACT_HEADER + float(AdventureMap.PATH_TIERS) * TIER_GAP + ACT_FOOT


func _act_top(which: int) -> float:
	return float(_map.acts - which) * _act_height()


func _point(id: String) -> Vector2:
	var n: Dictionary = _map.node(id)
	var tier: int = int(n.get("tier", 1))
	var y: float = _act_top(int(n.get("act", 1))) + ACT_HEADER + float(AdventureMap.BOSS_TIER - tier) * TIER_GAP
	if tier == AdventureMap.BOSS_TIER:
		return Vector2(size.x * 0.5, y)
	var lanes: int = maxi(1, _map.lanes)
	var span: float = maxf(0.0, _content_width() - LANE_MARGIN * 2.0)
	return Vector2(_content_left() + LANE_MARGIN + span * (float(int(n.get("lane", 0))) + 0.5) / float(lanes), y)


func _content_width() -> float:
	return minf(size.x, MAX_CONTENT_WIDTH)


func _content_left() -> float:
	return (size.x - _content_width()) * 0.5


func _side(id: String) -> float:
	return BOSS_SIZE if str(_map.node(id).get("type", "")) == "boss" else NODE_SIZE


func _make_button(id: String) -> TextureButton:
	var n: Dictionary = _map.node(id)
	var type: String = str(n.get("type", ""))
	var button: TextureButton = TextureButton.new()
	button.texture_normal = MapArt.marker(type)
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var label: String = AdventureMap.type_name(type)
	var duel: Dictionary = _map.duel_for(id)
	if not duel.is_empty():
		label += "\n%s" % AdventureDecks.opponent_name(str(duel.get("opponent", "")), Session.library)
		if str(duel.get("grant", "")) == "aspect":
			label += "\nGrants an Aspect"
		for resonance in AdventureElite.resonances_of(duel):
			label += "\nHolds %s" % ResonanceData.name_of(resonance)
	button.tooltip_text = label
	button.modulate = _tint(id)
	button.pressed.connect(func() -> void: select(id))
	add_child(button)
	# The icon already says elite, key or boss; the one badge left marks an Aspect grant.
	if str(duel.get("grant", "")) == "aspect":
		_add_flair(button, "grant", true)
	return button


func _add_flair(button: TextureButton, badge: String, right: bool) -> void:
	var tex: Texture2D = MapArt.flair(badge)
	if tex == null:
		return
	var flair: TextureRect = TextureRect.new()
	flair.texture = tex
	flair.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flair.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	flair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flair.size = Vector2.ONE * FLAIR_SIZE
	flair.set_meta("right", right)
	button.add_child(flair)


## Past nodes the run did not take fade out; everything ahead stays readable.
func _tint(id: String) -> Color:
	if id == _here or _choices.has(id) or _path.has(id):
		return Color.WHITE
	if _is_behind(id):
		return Color(0.5, 0.5, 0.5, 0.8)
	return Color(0.9, 0.9, 0.9, 1.0)


func _is_behind(id: String) -> bool:
	if _here == "":
		return false
	var n: Dictionary = _map.node(id)
	var at: Dictionary = _map.node(_here)
	var node_act: int = int(n.get("act", 1))
	var here_act: int = int(at.get("act", 1))
	if node_act != here_act:
		return node_act < here_act
	return int(n.get("tier", 1)) <= int(at.get("tier", 1))


func _layout() -> void:
	if _map == null:
		return
	for id in _buttons.keys():
		var button: TextureButton = _buttons[id]
		var side: float = _side(str(id))
		button.size = Vector2.ONE * side
		button.pivot_offset = button.size * 0.5
		button.position = _point(str(id)) - button.size * 0.5
		for child in button.get_children():
			if child is TextureRect:
				var flair: TextureRect = child
				var right: bool = bool(flair.get_meta("right", true))
				flair.position = Vector2(side - FLAIR_SIZE * 0.6 if right else -FLAIR_SIZE * 0.4, -FLAIR_SIZE * 0.4)
	for i in range(_labels.size()):
		var rect: Rect2 = _banner_rect(i + 1)
		_labels[i].position = rect.position
		_labels[i].size = rect.size
	_roads.queue_redraw()
	_marks.queue_redraw()
	_token.queue_redraw()


func _process(delta: float) -> void:
	if _map == null or ArcaneBackdrop.motion_reduced():
		return
	_clock += delta
	var breath: float = 1.0 + 0.07 * sin(_clock * 3.0)
	for id in _choices:
		if _buttons.has(id):
			(_buttons[id] as TextureButton).scale = Vector2.ONE * breath
	_roads.queue_redraw()
	_token.queue_redraw()


## The wash over an act the run is not in, feathered over WASH_FEATHER where it meets the act the
## run is in, so there is no hard seam across the board.
func _draw_wash(a: int) -> void:
	var top: float = _act_top(a)
	var bottom: float = top + _act_height()
	var clear: Color = Color(OTHER_ACT_WASH, 0.0)
	var edge_at_bottom: bool = a > act   # later acts sit above the current one
	var solid_top: float = top if edge_at_bottom else top + WASH_FEATHER
	var solid_bottom: float = bottom - WASH_FEATHER if edge_at_bottom else bottom
	_roads.draw_rect(Rect2(0.0, solid_top, size.x, solid_bottom - solid_top), OTHER_ACT_WASH)
	var f0: float = solid_bottom if edge_at_bottom else top
	var f1: float = bottom if edge_at_bottom else solid_top
	var c0: Color = OTHER_ACT_WASH if edge_at_bottom else clear
	var c1: Color = clear if edge_at_bottom else OTHER_ACT_WASH
	_roads.draw_polygon(PackedVector2Array([Vector2(0, f0), Vector2(size.x, f0), Vector2(size.x, f1), Vector2(0, f1)]),
		PackedColorArray([c0, c0, c1, c1]))


func _draw_roads() -> void:
	for a in range(1, _map.acts + 1):
		if a != act:
			_draw_wash(a)
	for id in _buttons.keys():
		var from: String = str(id)
		for to in _map.next_of(from):
			if not _buttons.has(to):
				continue
			var walked: bool = _walked(from, to)
			var open: bool = from == _here and _choices.has(to)
			_dashed(_point(from), _point(to), _side(from) * 0.5, _side(to) * 0.5, walked, open)
	# A square glow under each node the run may step to, the shape of its tile.
	for id in _choices:
		if _buttons.has(id):
			var glow: float = 0.22 + 0.12 * sin(_clock * 3.0)
			var half: float = _side(id) * 0.5
			_roads.draw_rect(Rect2(_point(id) - Vector2.ONE * half, Vector2.ONE * half * 2.0).grow(10.0), Color(MapArt.tint_strong, glow))


## True when the run stepped from `from` straight to `to`.
func _walked(from: String, to: String) -> bool:
	for i in range(_path.size() - 1):
		if _path[i] == from and _path[i + 1] == to:
			return true
	return false


## A road: light dashes on a dark edge, in the run's school colour where the run has walked,
## bone-white where it may step next.
func _dashed(a: Vector2, b: Vector2, trim_a: float, trim_b: float, walked: bool, open: bool) -> void:
	var length: float = a.distance_to(b)
	if length <= trim_a + trim_b:
		return
	var dir: Vector2 = (b - a) / length
	var start: Vector2 = a + dir * trim_a
	var run: float = length - trim_a - trim_b
	var dash: float = 11.0
	var gap: float = 7.0
	var walked_colour: Color = MapArt.school if MapArt.school.a > 0.0 else MapArt.tint.lightened(0.15)
	var fill: Color = walked_colour if walked else (OPEN_ROAD if open else ROAD)
	var edge: Color = INK if walked or open else Color(0, 0, 0, 0)
	var width: float = 4.0 if walked or open else 3.0
	var t: float = 0.0
	while t < run:
		var p0: Vector2 = start + dir * t
		var p1: Vector2 = start + dir * minf(t + dash, run)
		_roads.draw_line(p0, p1, edge, width + 3.0, true)
		_roads.draw_line(p0, p1, fill, width, true)
		t += dash + gap


func _banner_rect(a: int) -> Rect2:
	return Rect2(Vector2(_content_left() + 14, _act_top(a) + 20), Vector2(128, 44))


func _draw_marks() -> void:
	# The Kenney double rule where one act meets the next, its two knots meeting in the middle.
	for a in range(1, _map.acts):
		var y: float = _act_top(a)
		var rule: Rect2 = Rect2(_content_left() + 16.0, y - DIVIDER_HEIGHT * 0.5, _content_width() - 32.0, DIVIDER_HEIGHT)
		MapArt.draw_divider(_marks, rule, MapArt.tint.darkened(0.15))
	# Each act's name on a small framed tag; the act on show is the brighter one.
	for a in range(1, _map.acts + 1):
		var shade: Color = MapArt.tint if a == act else MapArt.tint.darkened(0.45)
		_marks.draw_style_box(MapArt.panel_box(0, shade), _banner_rect(a))
	# The run's own node in bone; a node being scouted in iron.
	if _here != "" and _buttons.has(_here):
		_brackets(_here, 0.0, MapArt.tint_strong)
	if _selected != "" and _selected != _here and _buttons.has(_selected):
		_brackets(_selected, 4.0, MapArt.tint.lightened(0.3))


## Where the token stands: just left of the node the run is on, or under act 1's first tier before
## the first step.
func _token_center() -> Vector2:
	if _here == "" or not _buttons.has(_here):
		var first: float = _act_top(1) + ACT_HEADER + float(AdventureMap.PATH_TIERS) * TIER_GAP
		return Vector2(size.x * 0.5, first + TIER_GAP * 0.75)
	return _point(_here) - Vector2(_side(_here) * 0.5 + TOKEN_SIZE.x * 0.5 + 10.0, 0.0)


## The run's Duelist as a framed portrait, cropped to the top of the art where the face is.
func _draw_token() -> void:
	var bob: float = sin(_clock * 2.0) * 2.0
	var rect: Rect2 = Rect2(_token_center() - TOKEN_SIZE * 0.5 + Vector2(0, bob), TOKEN_SIZE)
	_token.draw_rect(rect.grow(4.0), INK)
	_token.draw_rect(rect.grow(2.0), MapArt.tint)
	if _portrait != null:
		var w: float = float(_portrait.get_width())
		var region: Rect2 = Rect2(0.0, 0.0, w, w * TOKEN_SIZE.y / TOKEN_SIZE.x)
		_token.draw_texture_rect_region(_portrait, rect, region)
	else:
		_token.draw_rect(rect, ZenithTheme.FRAME_DIM)


## Kenney's corner brackets around a node.
func _brackets(id: String, grow: float, tint: Color) -> void:
	var half: float = _side(id) * 0.5 + 10.0 + grow
	MapArt.draw_brackets(_marks, Rect2(_point(id) - Vector2.ONE * half, Vector2.ONE * half * 2.0), tint)
