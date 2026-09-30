extends Control
## The Reserve screen: the Life Deck as strips on the left, the Reserve in the middle under its
## Relic, and the run library on the right. A Reserve card clicked goes to the library and a library
## card to the Reserve when there is room; a Life Deck strip clicked is picked, and the next Reserve
## or library card clicked trades places with it. Dragging a card onto a card in another pile trades
## the two, and onto an empty part of the Reserve or the library moves it there. Opened after taking
## a Relic, to set aside what the Reserve cannot hold, or from the map. The rules live in
## AdventureReserve; moves and saving go through Session.

const CARD_SCENE: PackedScene = preload("res://scenes/adventure/reserve_card.tscn")
const RESERVE_CARD: Vector2 = Vector2(149, 208)
const LIBRARY_CARD: Vector2 = Vector2(137, 191)
const STRIP_HEIGHT: int = 36
const STRIP_EDGE: int = 6
const STRIP_FONT: int = 20
const PREVIEW_GAP: float = 16.0

@onready var faces: CardFaceCache = $CardFaceCache
@onready var strip: PanelContainer = $Strip
@onready var run_name_label: Label = $Strip/Row/RunName
@onready var standing_label: Label = $Strip/Row/Standing
@onready var mana_icon: TextureRect = $Strip/Row/ManaBox/ManaIcon
@onready var mana_label: Label = $Strip/Row/ManaBox/ManaValue
@onready var mote_icon: TextureRect = $Strip/Row/MotesBox/MoteIcon
@onready var motes_label: Label = $Strip/Row/MotesBox/MotesValue
@onready var title: Label = $Title
@onready var life_panel: PanelContainer = $Body/LifePanel
@onready var life_count: Label = $Body/LifePanel/Column/Header/Count
@onready var life_list: VBoxContainer = $Body/LifePanel/Column/Scroll/List
@onready var reserve_panel: PanelContainer = $Body/ReservePanel
@onready var relic_face: TextureRect = $Body/ReservePanel/Column/Header/RelicFace
@onready var holds_label: Label = $Body/ReservePanel/Column/Header/Titles/Holds
@onready var reserve_count: Label = $Body/ReservePanel/Column/Header/Tally/Count
@onready var reserve_of: Label = $Body/ReservePanel/Column/Header/Tally/Of
@onready var reserve_scroll: ScrollContainer = $Body/ReservePanel/Column/Scroll
@onready var reserve_grid: GridContainer = $Body/ReservePanel/Column/Scroll/Grid
@onready var library_panel: PanelContainer = $Body/LibraryPanel
@onready var library_count: Label = $Body/LibraryPanel/Column/Header/Count
@onready var library_scroll: ScrollContainer = $Body/LibraryPanel/Column/Scroll
@onready var library_grid: GridContainer = $Body/LibraryPanel/Column/Scroll/Grid
@onready var back_button: Button = $Back
@onready var done_button: Button = $Done
@onready var warn_label: Label = $Warn
@onready var preview: Panel = $Preview
@onready var preview_face: TextureRect = $Preview/Face

## True when the screen was opened to set Reserve cards aside after taking a Relic.
var _trim: bool = false
## The Life Deck card picked for a swap, "" for none.
var _selected: String = ""
## Why the last move was refused, shown until the next one.
var _notice: String = ""
var _strips: Dictionary = {}
var _textures: Dictionary = {}
## What a drag in progress may be dropped on, worked out once per target.
var _drop_cache: Dictionary = {}
var _dev: bool = false
var _busy: bool = false


func _ready() -> void:
	theme = SanctumUI.theme()
	if Session.run == null or not AdventureReserve.is_editable(Session.run):
		Session.go_to_adventure()
		return
	_dev = _dev or AdventureDev.in_memory
	_trim = Session.run.status == AdventureRelic.STATUS_TRIM
	var run_deck: DeckList = Session.run.deck()
	MapArt.tint_for_school(run_deck.style if run_deck != null else "")
	SanctumUI.dress(self, title)
	var strip_box: StyleBoxFlat = ZenithTheme.box(ZenithTheme.BG, ZenithTheme.BORDER, 0, 0, ZenithTheme.GAP_L, ZenithTheme.GAP_XS)
	strip_box.border_width_bottom = 1
	strip.add_theme_stylebox_override("panel", strip_box)
	mana_icon.texture = MapArt.ui("mana")
	mote_icon.texture = MapArt.ui("mote")
	ZenithTheme.mana_label(mana_label)
	ZenithTheme.motes_label(motes_label)
	for panel: PanelContainer in [life_panel, reserve_panel, library_panel]:
		panel.add_theme_stylebox_override("panel", MapArt.panel_box(22))
		panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		(panel.get_child(0) as CanvasItem).texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	reserve_of.add_theme_color_override("font_color", ZenithTheme.MUTED)
	relic_face.mouse_filter = Control.MOUSE_FILTER_STOP
	relic_face.mouse_entered.connect(func() -> void:
		var relic: CardDef = Session.library.defs.get(Session.run.relic_id)
		if relic != null:
			_show_preview(relic, relic_face))
	relic_face.mouse_exited.connect(_hide_preview)
	back_button.visible = not _trim
	done_button.visible = _trim
	back_button.pressed.connect(_on_leave)
	done_button.pressed.connect(_on_leave)
	for area: Control in [reserve_scroll, reserve_grid]:
		area.set_drag_forwarding(Callable(), _can_drop.bind(AdventureReserve.RESERVE, ""), _drop.bind(AdventureReserve.RESERVE, ""))
	for area: Control in [library_scroll, library_grid]:
		area.set_drag_forwarding(Callable(), _can_drop.bind(AdventureReserve.LIBRARY, ""), _drop.bind(AdventureReserve.LIBRARY, ""))
	_busy = true
	await _refresh()
	_busy = false
	SanctumUI.wire_buttons(self)
	await _dev_after_layout()
	AdventureDev.screenshot(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_drop_cache.clear()


func _refresh() -> void:
	var run: AdventureRun = Session.run
	var deck: DeckList = run.deck()
	run_name_label.text = deck.name.trim_suffix(" (Starter)") if deck != null else ""
	standing_label.text = "Act %d   ·   %d won   ·   %d cards" % [
		MapRoute.act_to_show(run, Session.map), run.stage, AdventureForge.deck_size(run)]
	mana_label.text = str(run.mana)
	motes_label.text = str(Session.wallet.motes)
	life_count.text = str(run.cards.size())
	await _fill_life()
	await _fill_reserve_header()
	await _fill_grid(reserve_grid, AdventureReserve.RESERVE, run.reserve, RESERVE_CARD)
	library_count.text = str(run.library.size())
	await _fill_grid(library_grid, AdventureReserve.LIBRARY, run.library, LIBRARY_CARD)
	_refresh_footer()


func _refresh_footer() -> void:
	var block: String = AdventureReserve.done_block(Session.run, Session.library)
	done_button.disabled = block != "" or _busy
	if _notice != "":
		warn_label.text = _notice
		warn_label.add_theme_color_override("font_color", ZenithTheme.WARN)
	elif _trim and block != "":
		warn_label.text = block
		warn_label.add_theme_color_override("font_color", ZenithTheme.SHORT)
	else:
		warn_label.text = ""


func _fill_reserve_header() -> void:
	var run: AdventureRun = Session.run
	var relic: CardDef = Session.library.defs.get(run.relic_id) if run.relic_id != "" else null
	relic_face.visible = relic != null
	reserve_count.visible = relic != null
	reserve_of.visible = relic != null
	if relic == null:
		holds_label.text = "You hold no Relic, so you have no Reserve."
		return
	holds_label.text = "%s holds %d %s." % [relic.title, relic.reserve_size, "card" if relic.reserve_size == 1 else "cards"]
	reserve_count.text = str(run.reserve.size())
	reserve_count.add_theme_color_override("font_color",
		ZenithTheme.SHORT if run.reserve.size() > relic.reserve_size else ZenithTheme.TEXT)
	reserve_of.text = "of %d" % relic.reserve_size
	relic_face.texture = await faces.render_face(relic)


## Distinct ids in DeckInfo's type order, each type sorted by title.
func _order(ids: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for type: CardDef.Type in DeckInfo.TYPE_ORDER:
		var group: Array[String] = []
		for id in ids:
			var def: CardDef = Session.library.defs.get(id)
			if def != null and def.type == type and not group.has(id):
				group.append(id)
		group.sort_custom(func(a: String, b: String) -> bool:
			return (Session.library.defs[a] as CardDef).title < (Session.library.defs[b] as CardDef).title)
		out.append_array(group)
	return out


# --- The Life Deck --------------------------------------------------------------------------------

func _fill_life() -> void:
	for child in life_list.get_children():
		life_list.remove_child(child)
		child.queue_free()
	_strips.clear()
	var cards: Array[String] = Session.run.cards
	for id in _order(cards):
		var row: Button = _build_strip(Session.library.defs[id], cards.count(id))
		life_list.add_child(row)
		_strips[id] = row
	if not _strips.has(_selected):
		_selected = ""
	_paint_strips()


## One Life Deck strip: a type-coloured edge, the title and the copy count.
func _build_strip(def: CardDef, copies: int) -> Button:
	var row: Button = Button.new()
	row.custom_minimum_size = Vector2(0, STRIP_HEIGHT)
	row.focus_mode = Control.FOCUS_NONE
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.add_theme_stylebox_override("hover", ZenithTheme.box(ZenithTheme.HOVER, ZenithTheme.FRAME, ZenithTheme.RADIUS, 1, 0, 0))
	row.add_theme_stylebox_override("pressed", ZenithTheme.box(ZenithTheme.HOVER, ZenithTheme.FRAME, ZenithTheme.RADIUS, 1, 0, 0))
	var h: HBoxContainer = HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", ZenithTheme.GAP_S)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_right = -ZenithTheme.GAP_S
	row.add_child(h)
	var edge: ColorRect = ColorRect.new()
	edge.custom_minimum_size = Vector2(STRIP_EDGE, 0)
	edge.color = Palette.type_ui(def.type)
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(edge)
	var name_label: Label = Label.new()
	name_label.text = def.title
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_font_size_override("font_size", STRIP_FONT)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(name_label)
	var count: Label = Label.new()
	count.text = "x%d" % copies
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count.add_theme_font_size_override("font_size", STRIP_FONT)
	count.add_theme_color_override("font_color", ZenithTheme.MUTED)
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(count)
	var id: String = def.id
	row.pressed.connect(func() -> void: _on_strip(id))
	row.mouse_entered.connect(func() -> void: _show_preview(def, row))
	row.mouse_exited.connect(_hide_preview)
	row.set_drag_forwarding(_drag.bind(AdventureReserve.LIFE, id, def.title),
		_can_drop.bind(AdventureReserve.LIFE, id), _drop.bind(AdventureReserve.LIFE, id))
	return row


## The picked strip wears the bone ring; the rest a quiet tile.
func _paint_strips() -> void:
	for id in _strips.keys():
		var row: Button = _strips[id]
		var style: StyleBoxFlat = ZenithTheme.selected_box(0, 0) if id == _selected \
			else ZenithTheme.box(ZenithTheme.RAISED, Color(0, 0, 0, 0), ZenithTheme.RADIUS, 0, 0, 0)
		row.add_theme_stylebox_override("normal", style)
		row.add_theme_stylebox_override("hover", style if id == _selected
			else ZenithTheme.box(ZenithTheme.HOVER, ZenithTheme.FRAME, ZenithTheme.RADIUS, 1, 0, 0))


func _on_strip(id: String) -> void:
	if _busy:
		return
	_selected = "" if _selected == id else id
	_notice = ""
	_paint_strips()
	_refresh_footer()


# --- The Reserve and the library ------------------------------------------------------------------

func _fill_grid(grid: GridContainer, pile: String, ids: Array[String], size_value: Vector2) -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	var fresh: Array[String] = []
	if pile == AdventureReserve.RESERVE:
		fresh = Session.run.reserve_new
	for id in _order(ids):
		var def: CardDef = Session.library.defs[id]
		var card: ReserveCard = CARD_SCENE.instantiate() as ReserveCard
		grid.add_child(card)
		var texture: Texture2D = await faces.render_face(def)
		_textures[id] = texture
		card.show_card(pile, id, texture, ids.count(id), fresh.has(id), size_value)
		card.pressed.connect(func() -> void: _on_card(pile, id))
		card.hovered.connect(func(over: bool) -> void:
			if over:
				_show_preview(def, card)
			else:
				_hide_preview())
		card.face.set_drag_forwarding(_drag.bind(pile, id, def.title), _can_drop.bind(pile, id), _drop.bind(pile, id))


func _on_card(pile: String, id: String) -> void:
	if _busy:
		return
	if _selected != "":
		var picked: String = _selected
		_selected = ""
		await _swap(AdventureReserve.LIFE, picked, pile, id)
		return
	var to: String = AdventureReserve.LIBRARY if pile == AdventureReserve.RESERVE else AdventureReserve.RESERVE
	await _move(pile, id, to)


func _move(from: String, id: String, to: String) -> void:
	var block: String = AdventureReserve.move_block(Session.run, Session.library, from, id, to)
	await _apply(block, func() -> bool:
		if _dev:
			return AdventureReserve.move(Session.run, Session.library, from, id, to)
		return Session.reserve_move(from, id, to))


func _swap(a: String, id_a: String, b: String, id_b: String) -> void:
	var block: String = AdventureReserve.swap_block(Session.run, Session.library, a, id_a, b, id_b)
	await _apply(block, func() -> bool:
		if _dev:
			return AdventureReserve.swap(Session.run, Session.library, a, id_a, b, id_b)
		return Session.reserve_swap(a, id_a, b, id_b))


## Runs one move, or shows why it is refused, and redraws the piles.
func _apply(block: String, action: Callable) -> void:
	_hide_preview()
	if block != "":
		_notice = block
		_paint_strips()
		_refresh_footer()
		return
	_busy = true
	var done: bool = action.call()
	_notice = "" if done else AdventureReserve.BLOCK_RULE
	await _refresh()
	_busy = false
	_refresh_footer()


# --- Drag and drop --------------------------------------------------------------------------------

func _drag(_at: Vector2, pile: String, id: String, title_text: String) -> Variant:
	if _busy:
		return null
	_hide_preview()
	_drop_cache.clear()
	var texture: Texture2D = _textures.get(id)
	if texture != null:
		var ghost: TextureRect = TextureRect.new()
		ghost.texture = texture
		ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		ghost.size = RESERVE_CARD * 0.8
		ghost.rotation = deg_to_rad(-5.0)
		set_drag_preview(ghost)
	else:
		var tag: Label = Label.new()
		tag.text = title_text
		ZenithTheme.chip(tag, ZenithTheme.ACCENT, true)
		set_drag_preview(tag)
	return {"pile": pile, "id": id}


func _can_drop(_at: Vector2, data: Variant, pile: String, id: String) -> bool:
	if _busy or not (data is Dictionary):
		return false
	var from: String = str((data as Dictionary).get("pile", ""))
	var from_id: String = str((data as Dictionary).get("id", ""))
	if from == pile:
		return false
	var key: String = "%s|%s|%s|%s" % [from, from_id, pile, id]
	if not _drop_cache.has(key):
		if id != "":
			_drop_cache[key] = AdventureReserve.swap_block(Session.run, Session.library, from, from_id, pile, id) == ""
		else:
			_drop_cache[key] = AdventureReserve.move_block(Session.run, Session.library, from, from_id, pile) == ""
	return bool(_drop_cache[key])


func _drop(_at: Vector2, data: Variant, pile: String, id: String) -> void:
	var from: String = str((data as Dictionary).get("pile", ""))
	var from_id: String = str((data as Dictionary).get("id", ""))
	_selected = ""
	if id != "":
		await _swap(from, from_id, pile, id)
	else:
		await _move(from, from_id, pile)


# --- Hover preview --------------------------------------------------------------------------------

## The card large beside `anchor`: to its right when there is room, else to its left.
func _show_preview(def: CardDef, anchor: Control) -> void:
	var texture: Texture2D = _textures.get(def.id)
	if texture == null:
		texture = await faces.render_face(def)
		_textures[def.id] = texture
	if not is_instance_valid(anchor) or not anchor.is_visible_in_tree():
		return
	preview_face.texture = texture
	var rect: Rect2 = anchor.get_global_rect()
	var view: Vector2 = get_viewport_rect().size
	var at: Vector2 = Vector2(rect.end.x + PREVIEW_GAP, rect.get_center().y - preview.size.y * 0.5)
	if at.x + preview.size.x > view.x - PREVIEW_GAP:
		at.x = rect.position.x - PREVIEW_GAP - preview.size.x
	at.y = clampf(at.y, PREVIEW_GAP, view.y - preview.size.y - PREVIEW_GAP)
	preview.position = at
	preview.visible = true


func _hide_preview() -> void:
	preview.visible = false


# --- Leaving --------------------------------------------------------------------------------------

func _on_leave() -> void:
	if _busy or AdventureReserve.done_block(Session.run, Session.library) != "":
		return
	_busy = true
	if _dev:
		print("library: leave %s" % ("done" if AdventureReserve.finish(Session.run, Session.library) else "refused"))
		return
	if not Session.reserve_done():
		_busy = false


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _selected != "":
		_selected = ""
		_paint_strips()
	elif not _trim:
		_on_leave()
	else:
		return
	get_viewport().set_input_as_handled()


# --- Dev flags ----------------------------------------------------------------------------------

## `--dev-library-aside=N` sets the first N Reserve cards aside, `--dev-library-select=K` picks the
## Kth Life Deck strip, and `--dev-library-hover=K` previews the Kth Reserve card.
func _dev_after_layout() -> void:
	var aside: String = AdventureDev.flag("--dev-library-aside=")
	if aside != "":
		for i in range(int(aside)):
			if Session.run.reserve.is_empty():
				break
			await _move(AdventureReserve.RESERVE, _order(Session.run.reserve)[0], AdventureReserve.LIBRARY)
	var select: String = AdventureDev.flag("--dev-library-select=")
	if select != "":
		var ids: Array = _strips.keys()
		if int(select) < ids.size():
			_on_strip(str(ids[int(select)]))
	var hover: String = AdventureDev.flag("--dev-library-hover=")
	if hover != "" and int(hover) < reserve_grid.get_child_count():
		await get_tree().process_frame
		var card: ReserveCard = reserve_grid.get_child(int(hover)) as ReserveCard
		await _show_preview(Session.library.defs[card.card_id], card)
