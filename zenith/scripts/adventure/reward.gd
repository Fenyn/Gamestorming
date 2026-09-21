extends Control
## The reward screen after a won adventure stage, in whichever order `Session.run.status` visits:
## an Aspect card choice on a grant stage, then a pick-one-of-three theme bundle offer. Applies the
## choice through AdventureRewards, then hands off to Session.finish_reward() (or, mid-stage,
## Session.finish_aspect()).

const ADVANCE_DELAY: float = 0.6
const ZOOM_SIZE: Vector2 = Vector2(560, 784)
## The Aspect step shows one card at a time, sized to read like the versus screen's duelist card.
const CARD_FACE_SIZE: Vector2 = Vector2(310, 430)
## Bundle faces share one size across the whole offer, picked by the widest bundle shown: three
## panels of three faces still have to fit 1600 px with the header and footer intact.
const BUNDLE_FACE_SIZE_3: Vector2 = Vector2(180, 252)
const BUNDLE_FACE_SIZE_2: Vector2 = Vector2(230, 322)

@onready var faces: CardFaceCache = $CardFaceCache
@onready var stage_label: Label = $Margin/Column/Header/HeaderCenter/HeaderInner/Stage
@onready var opponent_label: Label = $Margin/Column/Header/HeaderCenter/HeaderInner/Opponent
@onready var step_line: Label = $Margin/Column/Header/HeaderCenter/HeaderInner/StepLine
@onready var stack_row: HFlowContainer = $Margin/Column/Header/HeaderCenter/HeaderInner/StackRow
@onready var stats_row: HBoxContainer = $Margin/Column/Header/HeaderCenter/HeaderInner/Stats
@onready var aspect_row: HBoxContainer = $Margin/Column/Header/HeaderCenter/HeaderInner/AspectRow
@onready var deck_tile: StatTile = $Margin/Column/Header/HeaderCenter/HeaderInner/Stats/Deck
@onready var aspects_tile: StatTile = $Margin/Column/Header/HeaderCenter/HeaderInner/Stats/Aspects
@onready var aspect_line: Label = $Margin/Column/Header/HeaderCenter/HeaderInner/AspectRow/AspectLine
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

## What `Take` applies for the selected panel: an Aspect card id while the run is on "aspect", a
## bundle id while it is on "reward". Index-aligned with `_card_panels`.
var _offer_ids: Array[String] = []
var _offer_defs: Array[CardDef] = []       # Aspect step only, index-aligned with `_offer_ids`
var _offer_bundles: Array[Dictionary] = [] # reward step only, index-aligned with `_offer_ids`
var _all_faces: Array[CardDef] = []        # every face on screen in render order, for dev-inspect
var _card_panels: Array[PanelContainer] = []   # one per offer entry, in offer order
var _card_tints: Array[Color] = []             # matching edge colour per offer entry
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
	var is_aspect_step: bool = run.status == "aspect"
	stage_label.text = "Stage %d cleared" % (run.stage + 1)
	opponent_label.text = "Beat %s" % AdventureLadder.opponent_name(str(row.get("opponent", "")), Session.library)
	step_line.visible = is_aspect_step
	stack_row.visible = is_aspect_step
	stats_row.visible = not is_aspect_step
	aspect_row.visible = false
	if is_aspect_step:
		step_line.text = "Choose your next Aspect"
		_fill_stack_chips()
		return
	deck_tile.set_stat("Deck", "%d cards" % run.cards.size(), "", ZenithTheme.MUTED)
	aspects_tile.set_stat("Aspects", str(run.aspects()), "", ZenithTheme.MIGHT)
	var taken: CardDef = _aspect_taken_this_stage()
	if taken != null:
		aspect_row.visible = true
		var word: String = taken.aspect_title if taken.aspect_title != "" else "Tier %d" % taken.aspect
		aspect_line.text = "Aspect %d: %s" % [taken.aspect, word]
		ZenithTheme.chip(aspect_line, ZenithTheme.ACCENT, true)


## Small muted chips for the Duelist's current stack, lowest tier first: "Aspect 1: Starved".
func _fill_stack_chips() -> void:
	for child in stack_row.get_children():
		stack_row.remove_child(child)
		child.queue_free()
	for id in Session.run.duelist_ids:
		var def: CardDef = Session.library.defs.get(id)
		if def == null:
			continue
		var chip: Label = Label.new()
		var word: String = def.aspect_title if def.aspect_title != "" else "Tier %d" % def.aspect
		chip.text = "Aspect %d: %s" % [def.aspect, word]
		ZenithTheme.chip(chip, ZenithTheme.MUTED)
		stack_row.add_child(chip)


## The Aspect card the run took this stage, read off the last "aspect" pick recorded for it, or
## null when the stage granted none (or the grant was skipped at the top of the ladder).
func _aspect_taken_this_stage() -> CardDef:
	var run: AdventureRun = Session.run
	for i in range(run.picks.size() - 1, -1, -1):
		var pick: Dictionary = run.picks[i]
		if int(pick.get("stage", -1)) != run.stage:
			continue
		if str(pick.get("kind", "")) == "aspect":
			return Session.library.defs.get(str(pick.get("id", "")))
	return null


func _fill_offer() -> void:
	for child in offer_row.get_children():
		offer_row.remove_child(child)
		child.queue_free()
	_card_panels.clear()
	_card_tints.clear()
	_offer_defs.clear()
	_offer_bundles.clear()
	_offer_ids.clear()
	_all_faces.clear()
	if Session.run.status == "aspect":
		await _fill_aspect_offer()
	else:
		await _fill_bundle_offer()


func _fill_aspect_offer() -> void:
	for id in Session.run.pending_aspects:
		var def: CardDef = Session.library.defs.get(id)
		if def != null:
			_offer_ids.append(id)
			_offer_defs.append(def)
	empty_label.visible = false
	offer_row.visible = true
	for i in range(_offer_defs.size()):
		var column: Control = await _build_aspect_card(_offer_defs[i], i)
		offer_row.add_child(column)


func _fill_bundle_offer() -> void:
	for id in Session.run.pending_offer:
		var bundle: Dictionary = AdventureBundles.by_id(id)
		if bundle.is_empty():
			continue
		_offer_ids.append(id)
		_offer_bundles.append(bundle)
	empty_label.visible = _offer_bundles.is_empty()
	offer_row.visible = not _offer_bundles.is_empty()
	var face_size: Vector2 = _bundle_face_size(_offer_bundles)
	for i in range(_offer_bundles.size()):
		var column: Control = await _build_bundle_panel(_offer_bundles[i], i, face_size)
		offer_row.add_child(column)


## The widest bundle in the offer sets the face size for every panel, so the row reads evenly.
func _bundle_face_size(bundles: Array[Dictionary]) -> Vector2:
	var max_cards: int = 1
	for bundle in bundles:
		max_cards = maxi(max_cards, (bundle.get("cards", []) as Array).size())
	return BUNDLE_FACE_SIZE_3 if max_cards >= 3 else BUNDLE_FACE_SIZE_2


## `Palette.school_ui` only knows the schools plus Freestyle and Signature. Grounds and Ally
## bundles borrow the closest existing role rather than add a colour: Root's green is the plainest
## "ground" association on the wheel, and Steel's neutral silver reads as a roster rather than a
## school, and neither is one of the four playable starters' own school, so it never sits beside
## the real thing.
func _group_tint(group: String) -> Color:
	match group:
		AdventureBundles.GROUP_GROUNDS:
			return Palette.school_ui("root")
		AdventureBundles.GROUP_ALLY:
			return Palette.school_ui("steel")
		_:
			return Palette.school_ui(group)


func _bundle_counts(bundle: Dictionary) -> Dictionary:
	var counts: Dictionary = {}
	for entry in bundle.get("cards", []):
		if entry is Dictionary:
			var row: Dictionary = entry
			counts[str(row.get("id", ""))] = int(row.get("count", 1))
	return counts


## Card ids in bundle order, except an Ally bundle's personality card is moved to the front so it
## leads the panel.
func _ordered_bundle_ids(bundle: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for entry in bundle.get("cards", []):
		if entry is Dictionary:
			ids.append(str((entry as Dictionary).get("id", "")))
	for i in range(ids.size()):
		var def: CardDef = Session.library.defs.get(ids[i])
		if def != null and def.is_personality():
			if i > 0:
				var id: String = ids[i]
				ids.remove_at(i)
				ids.insert(0, id)
			break
	return ids


## One offer entry during the Aspect step: a versus-size face in a school-tinted panel, its
## title, type and school, and nothing else — an Aspect joins the Duelist stack, not the Life
## Deck, so there is no "in deck" count to show.
func _build_aspect_card(def: CardDef, index: int) -> Control:
	var tint: Color = Palette.card_ui(def)
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _card_style(tint, false, false))
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
	var group_chip: Label = Label.new()
	group_chip.text = CardText.card_group_name(def)
	ZenithTheme.chip(group_chip, tint)
	meta.add_child(group_chip)
	column.add_child(meta)

	panel.add_child(column)
	_card_panels.append(panel)
	_card_tints.append(tint)
	_all_faces.append(def)
	return panel


## One bundle panel: a working-name heading, a group chip, and its cards as real faces in a row
## sized to fit three panels across the screen. Clicking anywhere in the panel selects the whole
## bundle; only a face's own hover zoom and right-click inspect stay per-card.
func _build_bundle_panel(bundle: Dictionary, index: int, face_size: Vector2) -> Control:
	var group: String = str(bundle.get("group", ""))
	var tint: Color = _group_tint(group)
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _card_style(tint, false, false))
	panel.mouse_entered.connect(func() -> void: _hover_card(index, true))
	panel.mouse_exited.connect(func() -> void: _hover_card(index, false))

	var ordered_ids: Array[String] = _ordered_bundle_ids(bundle)
	var counts: Dictionary = _bundle_counts(bundle)
	var lead_def: CardDef = Session.library.defs.get(ordered_ids[0]) if not ordered_ids.is_empty() else null
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			var mb: InputEventMouseButton = event
			if mb.button_index == MOUSE_BUTTON_LEFT:
				_select_card(index)
				if mb.double_click:
					_on_take()
			elif mb.button_index == MOUSE_BUTTON_RIGHT:
				_open_inspect(lead_def))

	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 10)

	var heading: Label = Label.new()
	heading.text = str(bundle.get("name", ""))
	heading.theme_type_variation = "HeaderLabel"
	heading.add_theme_font_size_override("font_size", 18)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(heading)

	var chip_row: HBoxContainer = HBoxContainer.new()
	chip_row.alignment = BoxContainer.ALIGNMENT_CENTER
	chip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chip: Label = Label.new()
	chip.text = CardText.group_name(group)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ZenithTheme.chip(chip, tint)
	chip_row.add_child(chip)
	column.add_child(chip_row)

	var faces_row: HBoxContainer = HBoxContainer.new()
	faces_row.alignment = BoxContainer.ALIGNMENT_CENTER
	faces_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	faces_row.add_theme_constant_override("separation", 10)
	for id in ordered_ids:
		var def: CardDef = Session.library.defs.get(id)
		if def == null:
			continue
		var face_col: Control = await _build_bundle_face(def, int(counts.get(id, 1)), face_size, index)
		faces_row.add_child(face_col)
	column.add_child(faces_row)

	panel.add_child(column)
	_card_panels.append(panel)
	_card_tints.append(tint)
	return panel


## One face inside a bundle panel: the card, an "xN" badge when the bundle carries more than one
## copy, its title, and how many the run deck already holds.
func _build_bundle_face(def: CardDef, count: int, face_size: Vector2, bundle_index: int) -> Control:
	var col: VBoxContainer = VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 4)
	col.custom_minimum_size.x = face_size.x

	var wrap: Control = Control.new()
	wrap.custom_minimum_size = face_size
	var tex: Texture2D = await faces.render_face(def)
	var button: TextureButton = TextureButton.new()
	button.texture_normal = tex
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.pressed.connect(func() -> void: _select_card(bundle_index))
	button.mouse_entered.connect(func() -> void: _show_zoom(button))
	button.mouse_exited.connect(func() -> void: _hide_zoom())
	button.gui_input.connect(func(event: InputEvent) -> void:
		if _is_inspect_click(event):
			_open_inspect(def)
		elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and (event as InputEventMouseButton).double_click:
			_select_card(bundle_index)
			_on_take())
	wrap.add_child(button)

	if count > 1:
		var badge: PanelContainer = PanelContainer.new()
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_theme_stylebox_override("panel", ZenithTheme.box(ZenithTheme.ACCENT, Color(0, 0, 0, 0), 6, 0, 6, 2))
		var badge_label: Label = Label.new()
		badge_label.text = "x%d" % count
		badge_label.add_theme_font_size_override("font_size", 13)
		badge_label.add_theme_color_override("font_color", ZenithTheme.TEXT_DARK)
		badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(badge_label)
		badge.position = Vector2(face_size.x - 40.0, 6.0)
		wrap.add_child(badge)

	col.add_child(wrap)

	var title: Label = Label.new()
	title.text = def.title
	title.add_theme_font_size_override("font_size", 13)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size.x = face_size.x
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(title)

	var copies: Label = Label.new()
	copies.text = "In deck: %d" % Session.run.cards.count(def.id)
	copies.theme_type_variation = "MutedLabel"
	copies.add_theme_font_size_override("font_size", 11)
	copies.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	copies.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(copies)

	_all_faces.append(def)
	return col


## Unselected: an edged panel tinted by the card's or bundle's group, like a versus seat panel.
## Hover brightens the tint. Selected: the accent border the tray and TileButton use everywhere.
func _card_style(tint: Color, hover: bool, selected: bool) -> StyleBoxFlat:
	if selected:
		return ZenithTheme.box(ZenithTheme.ACCENT_SOFT, ZenithTheme.ACCENT, 14, 2, 20, 18)
	var edge: Color = tint.lightened(0.2) if hover else tint
	var tint_alpha: float = 0.16 if hover else 0.08
	return ZenithTheme.edged(edge, Color(tint, tint_alpha), 14, 20, 18)


func _select_card(index: int) -> void:
	if index < 0 or index >= _offer_ids.size():
		return
	_selected_index = index
	status_label.text = ""
	_refresh_card_styles()
	_refresh_footer()


func _move_selection(delta: int) -> void:
	if _offer_ids.is_empty():
		return
	var next: int = _selected_index + delta
	if next < 0:
		next = _offer_ids.size() - 1
	elif next >= _offer_ids.size():
		next = 0
	_select_card(next)


func _hover_card(index: int, over: bool) -> void:
	if index == _selected_index:
		return
	var panel: PanelContainer = _card_panels[index]
	panel.add_theme_stylebox_override("panel", _card_style(_card_tints[index], over, false))
	_lift(panel, over)


func _refresh_card_styles() -> void:
	for i in range(_card_panels.size()):
		var panel: PanelContainer = _card_panels[i]
		var on: bool = i == _selected_index
		panel.add_theme_stylebox_override("panel", _card_style(_card_tints[i], false, on))
		_lift(panel, on)


func _lift(frame: Control, up: bool) -> void:
	frame.pivot_offset = frame.size * 0.5
	var target: Vector2 = Vector2.ONE * (1.05 if up else 1.0)
	if _reduced_motion:
		frame.scale = target
		return
	var t: Tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(frame, "scale", target, 0.12)


## The name shown on the Take button and in status text: an Aspect card's title, or a bundle's
## working name.
func _offer_label(index: int) -> String:
	if Session.run.status == "aspect":
		var def: CardDef = _offer_defs[index]
		return def.aspect_title if def.aspect_title != "" else "Aspect %d" % def.aspect
	return str(_offer_bundles[index].get("name", ""))


func _refresh_footer() -> void:
	var is_aspect_step: bool = Session.run.status == "aspect"
	skip_button.visible = not is_aspect_step
	cut_button.visible = not is_aspect_step
	var has_pick: bool = _selected_index >= 0 and _selected_index < _offer_ids.size()
	take_button.disabled = not has_pick
	take_button.text = "Take %s" % _offer_label(_selected_index) if has_pick else "Take"
	if is_aspect_step:
		return
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
	if Session.run.status == "aspect" or not AdventureRewards.can_cut(Session.run):
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
	if _busy or Session.run.status == "aspect":
		return
	_busy = true
	AdventureRewards.apply_skip(Session.run)
	await _advance()


func _on_take() -> void:
	if _busy or _selected_index < 0 or _selected_index >= _offer_ids.size():
		return
	var id: String = _offer_ids[_selected_index]
	if Session.run.status == "aspect":
		await _take_aspect(id)
		return
	_busy = true
	if not AdventureRewards.apply_bundle(Session.run, Session.library, id):
		_busy = false
		status_label.text = "That bundle is no longer available. Choose another, skip, or cut."
		return
	await _advance()


## The Aspect step: taking one moves the run on to its bundle offer, still on this screen. Real
## play routes through Session.finish_aspect, which saves and reloads the scene; dev mode applies
## the same steps in memory and rebuilds the offer in place, since it must never save.
func _take_aspect(card_id: String) -> void:
	if not _dev:
		_busy = true
		Session.finish_aspect(card_id)
		return
	if not AdventureRewards.apply_aspect(Session.run, Session.library, card_id):
		status_label.text = "That Aspect is no longer available."
		return
	AdventureRewards.finish_aspect(Session.run, Session.ladder, Session.library)
	_selected_index = -1
	_fill_header()
	await _fill_offer()
	if not _offer_ids.is_empty():
		_select_card(0)
	_refresh_footer()


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
## the offer is drawn), `--dev-after-aspect` takes the first Aspect option so an Aspect-granting
## stage still lands on its bundle offer, `--dev-offer=a,b,c` forces specific bundle ids into that
## offer, and `--dev-empty` clears it to show the zero-offer state.
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
	if AdventureDev.args().has("--dev-after-aspect") and Session.run.status == "aspect":
		var first: String = Session.run.pending_aspects[0] if not Session.run.pending_aspects.is_empty() else ""
		if first != "" and AdventureRewards.apply_aspect(Session.run, Session.library, first):
			AdventureRewards.finish_aspect(Session.run, Session.ladder, Session.library)
	if Session.run.status != "reward":
		return
	var offer_arg: String = AdventureDev.flag("--dev-offer=")
	if offer_arg != "":
		var ids: Array[String] = []
		for part in offer_arg.split(","):
			var id: String = part.strip_edges()
			if id != "":
				ids.append(id)
		Session.run.pending_offer = ids
	if AdventureDev.args().has("--dev-empty"):
		Session.run.pending_offer.clear()


## `--dev-select=N` selects the Nth panel (a bundle or an Aspect card), `--dev-cut` opens the cut
## panel, and `--dev-inspect=N` opens the inspect view on the Nth face on screen, counting every
## face across every panel in render order.
func _dev_after_layout() -> void:
	var select_arg: String = AdventureDev.flag("--dev-select=")
	if select_arg != "":
		_select_card(int(select_arg))
	if AdventureDev.args().has("--dev-cut"):
		_on_cut_open()
	var inspect_arg: String = AdventureDev.flag("--dev-inspect=")
	if inspect_arg != "":
		var index: int = int(inspect_arg)
		if index >= 0 and index < _all_faces.size():
			_open_inspect(_all_faces[index])
