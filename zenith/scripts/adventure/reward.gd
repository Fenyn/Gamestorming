extends Control
## The reward screen after a won adventure stage: pick one of the offered cards, skip, or cut a
## card from the run deck instead. Applies the choice through AdventureRewards, then hands off to
## Session.finish_reward().

const ADVANCE_DELAY: float = 0.6
const ZOOM_SIZE: Vector2 = Vector2(560, 784)
## Offer faces render large enough to read the printed rules text at a glance, since only three
## cards are ever on screen.
const CARD_FACE_SIZE: Vector2 = Vector2(310, 430)

@onready var faces: CardFaceCache = $CardFaceCache
@onready var stage_label: Label = $Margin/Column/Header/HeaderCenter/HeaderInner/Stage
@onready var opponent_label: Label = $Margin/Column/Header/HeaderCenter/HeaderInner/Opponent
@onready var aspect_line: Label = $Margin/Column/Header/HeaderCenter/HeaderInner/AspectRow/AspectLine
@onready var deck_tile: StatTile = $Margin/Column/Header/HeaderCenter/HeaderInner/Stats/Deck
@onready var aspects_tile: StatTile = $Margin/Column/Header/HeaderCenter/HeaderInner/Stats/Aspects
@onready var offer_row: HBoxContainer = $Margin/Column/OfferSection/OfferInner/OfferRow
@onready var empty_label: Label = $Margin/Column/OfferSection/OfferInner/Empty
@onready var skip_button: Button = $Margin/Column/Footer/Skip
@onready var cut_button: Button = $Margin/Column/Footer/Cut
@onready var status_label: Label = $Margin/Column/Footer/Status
@onready var take_button: Button = $Margin/Column/Footer/Take
@onready var cut_panel: ColorRect = $CutPanel
@onready var cut_dialog: PanelContainer = $CutPanel/Center/Panel
@onready var cut_deck_list: RunDeckList = $CutPanel/Center/Panel/Column/DeckList
@onready var cut_status_label: Label = $CutPanel/Center/Panel/Column/CutStatus
@onready var cut_cancel: Button = $CutPanel/Center/Panel/Column/Buttons/Cancel
@onready var cut_confirm: Button = $CutPanel/Center/Panel/Column/Buttons/Confirm
@onready var inspect: ColorRect = $Inspect
@onready var inspect_face: CardFace = $Inspect/Center/Column/Face

var _offer_defs: Array[CardDef] = []
var _card_panels: Array[PanelContainer] = []   # one per offer card, in offer order
var _card_school_colors: Array[Color] = []     # matching edge colour per offer card
var _selected_index: int = -1
var _cut_selected_id: String = ""
var _zoom: TextureRect = null
var _reduced_motion: bool = false
var _dev: bool = false
var _busy: bool = false


func _ready() -> void:
	theme = ZenithTheme.get_theme()
	_reduced_motion = AdventureDev.reduced_motion()
	_dev_setup()
	if Session.run == null:
		return
	skip_button.pressed.connect(_on_skip)
	cut_button.pressed.connect(_on_cut_open)
	take_button.pressed.connect(_on_take)
	cut_cancel.pressed.connect(_on_cut_cancel)
	cut_confirm.pressed.connect(_on_cut_confirm)
	cut_deck_list.card_selected.connect(_on_cut_row_selected)
	inspect.gui_input.connect(_on_inspect_input)
	cut_dialog.add_theme_stylebox_override("panel", ZenithTheme.modal_panel())
	status_label.text = ""
	cut_status_label.visible = false
	cut_panel.visible = false
	inspect.visible = false
	_fill_header()
	await _fill_offer()
	_refresh_footer()
	_enter()
	_dev_after_layout()
	AdventureDev.screenshot(self)


func _fill_header() -> void:
	var run: AdventureRun = Session.run
	var row: Dictionary = Session.ladder.stage(run.stage)
	stage_label.text = "Stage %d cleared" % (run.stage + 1)
	opponent_label.text = "Beat %s" % AdventureLadder.opponent_name(str(row.get("opponent", "")), Session.library)
	deck_tile.set_stat("Deck", "%d cards" % run.cards.size(), "", ZenithTheme.MUTED)
	aspects_tile.set_stat("Aspects", str(run.aspects()), "", ZenithTheme.MIGHT)
	var granted: bool = str(row.get("grant", "")) == "aspect"
	aspect_line.visible = granted
	if granted:
		aspect_line.text = "Aspect %d unlocked" % run.aspects()
		ZenithTheme.chip(aspect_line, ZenithTheme.ACCENT, true)


func _fill_offer() -> void:
	for child in offer_row.get_children():
		offer_row.remove_child(child)
		child.queue_free()
	_card_panels.clear()
	_card_school_colors.clear()
	_offer_defs.clear()
	for id in Session.run.pending_offer:
		var def: CardDef = Session.library.defs.get(id)
		if def != null:
			_offer_defs.append(def)
	empty_label.visible = _offer_defs.is_empty()
	offer_row.visible = not _offer_defs.is_empty()
	for i in range(_offer_defs.size()):
		var column: Control = await _build_offer_card(_offer_defs[i], i)
		offer_row.add_child(column)


## One offer card: a versus-seat-style panel (group-tinted edge) holding the face at a size big
## enough to read like the matchup screen's duelist card, its title, type and card group, and how
## many copies the run deck already holds. The face itself already prints the rules text.
func _build_offer_card(def: CardDef, index: int) -> Control:
	var school_color: Color = Palette.card_ui(def)
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _card_style(school_color, false, false))
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.custom_minimum_size.x = CARD_FACE_SIZE.x
	var tex: Texture2D = await faces.render_face(def)
	var button: TextureButton = TextureButton.new()
	button.texture_normal = tex
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.custom_minimum_size = CARD_FACE_SIZE
	button.pressed.connect(func() -> void: _select_card(index))
	button.mouse_entered.connect(func() -> void:
		_hover_card(index, true)
		_show_zoom(button))
	button.mouse_exited.connect(func() -> void:
		_hover_card(index, false)
		_hide_zoom())
	button.gui_input.connect(func(event: InputEvent) -> void:
		if _is_inspect_click(event):
			_open_inspect(def)
		elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and (event as InputEventMouseButton).double_click:
			_select_card(index)
			_on_take())
	column.add_child(button)

	var title: Label = Label.new()
	title.text = def.title
	title.theme_type_variation = "HeaderLabel"
	title.add_theme_font_size_override("font_size", 18)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size.x = CARD_FACE_SIZE.x
	column.add_child(title)

	var meta: HBoxContainer = HBoxContainer.new()
	meta.alignment = BoxContainer.ALIGNMENT_CENTER
	meta.add_theme_constant_override("separation", 6)
	var icon: TypeIcon = TypeIcon.new()
	icon.custom_minimum_size = Vector2(16, 16)
	icon.type = def.type
	icon.color = Palette.type_ui(def.type)
	meta.add_child(icon)
	var school: Label = Label.new()
	school.text = CardText.card_group_name(def)
	ZenithTheme.chip(school, school_color)
	meta.add_child(school)
	# A Signature card that also carries a school says so in a second chip: the group is what the
	# card is, the school is why deck construction treats it as that school's card.
	if def.is_signature() and def.school != "":
		var also: Label = Label.new()
		also.text = CardText.school_name(def.school)
		ZenithTheme.chip(also, Palette.school_ui(def.school))
		meta.add_child(also)
	column.add_child(meta)

	var copies: Label = Label.new()
	copies.text = "In deck: %d" % Session.run.cards.count(def.id)
	copies.theme_type_variation = "MutedLabel"
	copies.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(copies)

	panel.add_child(column)
	_card_panels.append(panel)
	_card_school_colors.append(school_color)
	return panel


## Unselected: an edged panel tinted by the card's school, like a versus seat panel. Hover
## brightens the tint. Selected: the accent border the tray and TileButton use everywhere else.
func _card_style(school_color: Color, hover: bool, selected: bool) -> StyleBoxFlat:
	if selected:
		return ZenithTheme.box(ZenithTheme.ACCENT_SOFT, ZenithTheme.ACCENT, 14, 2, 20, 18)
	var edge: Color = school_color.lightened(0.2) if hover else school_color
	var tint: float = 0.16 if hover else 0.08
	return ZenithTheme.edged(edge, Color(school_color, tint), 14, 20, 18)


func _select_card(index: int) -> void:
	if index < 0 or index >= _offer_defs.size():
		return
	_selected_index = index
	status_label.text = ""
	_refresh_card_styles()
	_refresh_footer()


func _move_selection(delta: int) -> void:
	if _offer_defs.is_empty():
		return
	var next: int = _selected_index + delta
	if next < 0:
		next = _offer_defs.size() - 1
	elif next >= _offer_defs.size():
		next = 0
	_select_card(next)


func _hover_card(index: int, over: bool) -> void:
	if index == _selected_index:
		return
	var panel: PanelContainer = _card_panels[index]
	panel.add_theme_stylebox_override("panel", _card_style(_card_school_colors[index], over, false))
	_lift(panel, over)


func _refresh_card_styles() -> void:
	for i in range(_card_panels.size()):
		var panel: PanelContainer = _card_panels[i]
		var on: bool = i == _selected_index
		panel.add_theme_stylebox_override("panel", _card_style(_card_school_colors[i], false, on))
		_lift(panel, on)


func _lift(frame: Control, up: bool) -> void:
	frame.pivot_offset = frame.size * 0.5
	var target: Vector2 = Vector2.ONE * (1.05 if up else 1.0)
	if _reduced_motion:
		frame.scale = target
		return
	var t: Tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(frame, "scale", target, 0.12)


func _refresh_footer() -> void:
	var has_pick: bool = _selected_index >= 0 and _selected_index < _offer_defs.size()
	take_button.disabled = not has_pick
	take_button.text = "Take %s" % _offer_defs[_selected_index].title if has_pick else "Take"
	var can_cut: bool = AdventureRewards.can_cut(Session.run)
	cut_button.disabled = not can_cut
	cut_button.tooltip_text = "" if can_cut else "The deck is already at its smallest legal size."


# --- Hover zoom, matching DeckInfo's key card zoom -------------------------

func _show_zoom(button: TextureButton) -> void:
	if inspect.visible:
		return
	if _zoom == null:
		_zoom = TextureRect.new()
		_zoom.top_level = true
		_zoom.z_index = 100
		_zoom.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_zoom.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_zoom.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_zoom.size = ZOOM_SIZE
		add_child(_zoom)
	_zoom.texture = button.texture_normal
	_zoom.visible = _zoom.texture != null
	_place_zoom(button)


func _place_zoom(button: TextureButton) -> void:
	var view: Vector2 = get_viewport_rect().size
	var origin: Vector2 = button.global_position
	var pos: Vector2 = Vector2(origin.x + button.size.x * 0.5 - ZOOM_SIZE.x * 0.5, origin.y - ZOOM_SIZE.y - 12.0)
	if pos.y < 8.0:
		pos.y = origin.y + button.size.y + 12.0
	pos.x = clampf(pos.x, 8.0, maxf(8.0, view.x - ZOOM_SIZE.x - 8.0))
	pos.y = clampf(pos.y, 8.0, maxf(8.0, view.y - ZOOM_SIZE.y - 8.0))
	_zoom.global_position = pos


func _hide_zoom() -> void:
	if _zoom != null:
		_zoom.visible = false


# --- Inspect, matching the duel HUD's overlay -------------------------------

func _open_inspect(def: CardDef) -> void:
	if def == null:
		return
	_hide_zoom()
	inspect_face.show_def(def)
	inspect.visible = true


func _hide_inspect() -> void:
	inspect.visible = false


func _is_inspect_click(event: InputEvent) -> bool:
	return event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT


func _on_inspect_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_hide_inspect()


func _unhandled_input(event: InputEvent) -> void:
	if inspect.visible and event.is_action_pressed("ui_cancel"):
		_hide_inspect()
		get_viewport().set_input_as_handled()
		return
	if cut_panel.visible:
		if event.is_action_pressed("ui_cancel"):
			_on_cut_cancel()
			get_viewport().set_input_as_handled()
		return
	if inspect.visible or _busy:
		return
	if event.is_action_pressed("ui_left"):
		_move_selection(-1)
	elif event.is_action_pressed("ui_right"):
		_move_selection(1)
	elif event.is_action_pressed("ui_accept") and _selected_index >= 0:
		_on_take()


# --- Cut panel ---------------------------------------------------------------

func _on_cut_open() -> void:
	if not AdventureRewards.can_cut(Session.run):
		return
	_cut_selected_id = ""
	cut_confirm.disabled = true
	cut_deck_list.show_cards(Session.run.cards, Session.library, faces)
	cut_status_label.visible = false
	cut_panel.visible = true


func _on_cut_cancel() -> void:
	cut_panel.visible = false
	_cut_selected_id = ""


func _on_cut_row_selected(id: String) -> void:
	_cut_selected_id = id
	cut_confirm.disabled = false
	cut_status_label.visible = false


func _on_cut_confirm() -> void:
	if _busy or _cut_selected_id == "":
		return
	_busy = true
	if not AdventureRewards.apply_cut(Session.run, Session.library, _cut_selected_id):
		_busy = false
		cut_status_label.text = "That card could not be cut."
		cut_status_label.visible = true
		return
	cut_panel.visible = false
	await _advance()


# --- Skip and take ------------------------------------------------------------

func _on_skip() -> void:
	if _busy:
		return
	_busy = true
	AdventureRewards.apply_skip(Session.run)
	await _advance()


func _on_take() -> void:
	if _busy or _selected_index < 0 or _selected_index >= _offer_defs.size():
		return
	_busy = true
	var id: String = _offer_defs[_selected_index].id
	if not AdventureRewards.apply_pick(Session.run, Session.library, id):
		_busy = false
		status_label.text = "That card is no longer available. Choose another, skip, or cut."
		return
	await _advance()


## The lock-in beat the select screen uses, skipped under --reduced-motion, then the hand-off to
## Session.finish_reward(). In dev mode the choice is applied in memory only; nothing is saved.
func _advance() -> void:
	skip_button.disabled = true
	cut_button.disabled = true
	take_button.disabled = true
	if not _reduced_motion:
		await get_tree().create_timer(ADVANCE_DELAY).timeout
	if _dev:
		_busy = false
		return
	Session.finish_reward()


func _enter() -> void:
	if _reduced_motion or not is_inside_tree():
		return
	var column: Control = $Margin/Column
	column.modulate.a = 0.0
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var t: Tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(column, "modulate:a", 1.0, 0.3)


# --- Dev flags -----------------------------------------------------------------

## Builds an in-memory run when the scene is opened directly, without touching the save.
## `--dev-reward=<starter_id>` begins the run, `--dev-stage=N` picks the stage just won (before
## the offer is drawn), and `--dev-empty` clears the offer to show the zero-offer state.
func _dev_setup() -> void:
	if Session.run != null:
		return
	var starter_id: String = AdventureDev.flag("--dev-reward=")
	if starter_id == "" or not AdventureDev.begin_run(starter_id):
		return
	_dev = true
	var stage_arg: String = AdventureDev.flag("--dev-stage=")
	if stage_arg != "":
		Session.run.stage = clampi(int(stage_arg), 0, Session.ladder.size() - 1)
	AdventureRewards.finish_stage(Session.run, Session.ladder, Session.library, true)
	if AdventureDev.args().has("--dev-empty"):
		Session.run.pending_offer.clear()


## `--dev-select=N` selects the Nth offered card, `--dev-cut` opens the cut panel, and
## `--dev-inspect=N` opens the inspect view on the Nth offered card.
func _dev_after_layout() -> void:
	var select_arg: String = AdventureDev.flag("--dev-select=")
	if select_arg != "":
		_select_card(int(select_arg))
	if AdventureDev.args().has("--dev-cut"):
		_on_cut_open()
	var inspect_arg: String = AdventureDev.flag("--dev-inspect=")
	if inspect_arg != "":
		var index: int = int(inspect_arg)
		if index >= 0 and index < _offer_defs.size():
			_open_inspect(_offer_defs[index])
