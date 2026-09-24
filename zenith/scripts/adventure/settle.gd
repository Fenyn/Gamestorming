extends Control
## The run-end settlement, shown while `Session.run.status` is "settle". Nothing banks for free:
## the cards the run put on the table are listed as faces with a per-copy price, and each Keep
## spends Motes through Session.keep_card(). Continue closes the run for good.

const ADVANCE_DELAY: float = 0.6
const ZOOM_SIZE: Vector2 = Vector2(560, 784)
## Small enough that a won run's whole deck reads as a grid at 1600 px, large enough to tell the
## cards apart without the hover zoom.
const FACE_SIZE: Vector2 = Vector2(150, 210)

@onready var faces: CardFaceCache = $CardFaceCache
@onready var outcome_label: Label = $Margin/Column/Header/HeaderCenter/HeaderInner/Outcome
@onready var reached_label: Label = $Margin/Column/Header/HeaderCenter/HeaderInner/Reached
@onready var duelist_label: Label = $Margin/Column/Header/HeaderCenter/HeaderInner/Duelist
@onready var motes_tile: StatTile = $Margin/Column/Header/HeaderCenter/HeaderInner/Stats/Motes
@onready var kept_tile: StatTile = $Margin/Column/Header/HeaderCenter/HeaderInner/Stats/Kept
@onready var discount_label: Label = $Margin/Column/Header/HeaderCenter/HeaderInner/DiscountRow/Discount
@onready var caption_label: Label = $Margin/Column/OfferSection/Caption
@onready var grid: HFlowContainer = $Margin/Column/OfferSection/Scroll/Grid
@onready var empty_label: Label = $Margin/Column/OfferSection/Empty
@onready var status_label: Label = $Margin/Column/Footer/Status
@onready var continue_button: Button = $Margin/Column/Footer/Continue
@onready var inspect: ColorRect = $Inspect
@onready var inspect_face: CardFace = $Inspect/Center/Column/Face

## The offer rows in the order they were first listed, so a card that is fully kept keeps its
## place in the grid instead of vanishing out from under the pointer.
var _ids: Array[String] = []
var _defs: Array[CardDef] = []
var _offered: Array[int] = []          # copies on offer when the screen opened, per id
var _keep_buttons: Array[Button] = []
var _kept_labels: Array[Label] = []
var _cap_labels: Array[Label] = []
var _count_labels: Array[Label] = []
var _zoom: TextureRect = null
var _reduced_motion: bool = false
var _busy: bool = false


func _ready() -> void:
	theme = SanctumUI.theme()
	_reduced_motion = AdventureDev.reduced_motion()
	_dev_setup()
	if Session.run == null:
		Session.go_to_adventure()
		return
	# The run's end still wears the run's school colour, as on the map.
	var run_deck: DeckList = Session.run.deck()
	MapArt.tint_for_school(run_deck.style if run_deck != null else "")
	theme = SanctumUI.themed(MapArt.tint)
	SanctumUI.dress(self, $Margin/Column/Header/TitleRow/Title as Label)
	continue_button.pressed.connect(_on_continue)
	($Margin/Column/Footer/Journal as Button).pressed.connect(Session.go_to_journal)
	inspect.gui_input.connect(_on_inspect_input)
	inspect.visible = false
	status_label.text = Session.take_dissolve_report()
	_fill_header()
	await _fill_offers()
	_refresh()
	_enter()
	_dev_after_layout()
	AdventureDev.screenshot(self)


# --- Header -------------------------------------------------------------------

func _fill_header() -> void:
	var run: AdventureRun = Session.run
	var won: bool = AdventureSettlement.won(run)
	var place: String = Session.map.place_of(run.node_id) if Session.map != null else "the start"
	outcome_label.text = "Run complete" if won else "Run over"
	reached_label.text = "Won all %d duels" % run.stage if won else "Fell at %s after %d duels won" % [
		place, run.stage]
	var deck: DeckList = run.deck()
	var duelist: CardDef = Session.library.defs.get(deck.duelist_face_id()) if deck != null else null
	duelist_label.text = "%s   ·   %s" % [
		deck.name if deck != null else run.starter_id,
		duelist.title if duelist != null else ""]
	discount_label.visible = won
	if won:
		var percent: int = int(round(float(AdventureEconomy.data().get("discount_fraction", 0.0)) * 100.0))
		discount_label.text = "Winner's price: %d%% off every card in your deck this once" % percent
		ZenithTheme.chip(discount_label, ZenithTheme.ACCENT)


## The Motes tile and the kept tally, both read back off the wallet's own ledger so the run's
## earnings and what the keeps have spent come from one place.
func _refresh_stats() -> void:
	var run_id: String = Session.run.run_id
	var earned: int = 0
	var spent: int = 0
	for entry in Session.wallet.recent(AdventureWallet.LEDGER_MAX):
		if str(entry.get("run_id", "")) != run_id:
			continue
		var amount: int = int(entry.get("amount", 0))
		if amount >= 0:
			earned += amount
		else:
			spent -= amount
	motes_tile.set_stat("Motes", str(Session.wallet.motes), "+%d this run" % earned, ZenithTheme.ACCENT)
	var copies: int = 0
	for id in Session.run.kept.keys():
		copies += int(Session.run.kept[id])
	kept_tile.set_stat("Kept", str(copies), "%d Motes spent" % spent, ZenithTheme.ENERGY)


# --- The card grid --------------------------------------------------------------

func _fill_offers() -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	_ids.clear()
	_defs.clear()
	_offered.clear()
	_keep_buttons.clear()
	_kept_labels.clear()
	_cap_labels.clear()
	_count_labels.clear()
	var rows: Array[Dictionary] = Session.settle_offers()
	empty_label.visible = rows.is_empty()
	for row in rows:
		var id: String = str(row["id"])
		var def: CardDef = Session.library.defs.get(id)
		if def == null:
			continue
		_ids.append(id)
		_defs.append(def)
		_offered.append(int(row["count"]))
		grid.add_child(await _build_cell(def, row))
	var total: int = AdventureSettlement.total_price(rows)
	caption_label.text = "%d cards on offer  ·  keeping every copy would cost %d Motes" % [
		rows.size(), total]


## One offered card: its face, an "xN" badge for a stack of copies, the unit price as a Mote chip
## with the full price struck through beside it on a won run, and the Keep control.
func _build_cell(def: CardDef, row: Dictionary) -> Control:
	var tint: Color = Palette.card_ui(def)
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ZenithTheme.edged(tint, Color(tint, 0.08), 12, 10, 10))

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.custom_minimum_size.x = FACE_SIZE.x

	var wrap: Control = Control.new()
	wrap.custom_minimum_size = FACE_SIZE
	var tex: Texture2D = await faces.render_face(def)
	var button: TextureButton = TextureButton.new()
	button.texture_normal = tex
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.mouse_entered.connect(func() -> void: _show_zoom(button))
	button.mouse_exited.connect(_hide_zoom)
	button.gui_input.connect(func(event: InputEvent) -> void:
		if _is_inspect_click(event):
			_open_inspect(def))
	wrap.add_child(button)

	var count: int = int(row["count"])
	var badge_label: Label = Label.new()
	badge_label.text = "x%d" % count
	badge_label.add_theme_font_size_override("font_size", 13)
	badge_label.add_theme_color_override("font_color", ZenithTheme.TEXT_DARK)
	badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge: PanelContainer = PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_stylebox_override("panel", ZenithTheme.box(ZenithTheme.ACCENT, Color(0, 0, 0, 0), 6, 0, 6, 2))
	badge.add_child(badge_label)
	badge.position = Vector2(FACE_SIZE.x - 40.0, 6.0)
	badge.visible = count > 1
	wrap.add_child(badge)
	_count_labels.append(badge_label)
	column.add_child(wrap)

	var title: Label = Label.new()
	title.text = def.title
	title.add_theme_font_size_override("font_size", 12)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size.x = FACE_SIZE.x
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title)

	column.add_child(_price_row(row))

	var keep: Button = Button.new()
	keep.custom_minimum_size = Vector2(FACE_SIZE.x, 30)
	keep.text = "Keep 1"
	keep.pressed.connect(func() -> void: _on_keep(def.id))
	column.add_child(keep)
	_keep_buttons.append(keep)

	var kept: Label = Label.new()
	kept.theme_type_variation = &"MutedLabel"
	kept.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kept.custom_minimum_size.x = FACE_SIZE.x
	kept.text = ""
	kept.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(kept)
	_kept_labels.append(kept)

	# The collection's copy cap, shown only once a row has reached it, so the greyed Keep has a
	# reason beside it rather than only in a tooltip.
	var cap: Label = Label.new()
	cap.theme_type_variation = &"WarnLabel"
	cap.add_theme_font_size_override("font_size", 12)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.custom_minimum_size.x = FACE_SIZE.x
	cap.text = ""
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(cap)
	_cap_labels.append(cap)

	panel.add_child(column)
	return panel


## The price line: the Mote chip a copy actually costs, plus the full price struck through when
## the winner's discount is what brought it down.
func _price_row(row: Dictionary) -> Control:
	var box: HBoxContainer = HBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var unit: int = int(row["unit"])
	var full: int = int(row["price"])
	var chip: Label = Label.new()
	chip.text = "%d Motes" % unit
	chip.add_theme_font_size_override("font_size", 12)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ZenithTheme.chip(chip, ZenithTheme.ACCENT)
	box.add_child(chip)

	if unit < full:
		# Label cannot strike text through; a small BBCode line can, and this is the only place
		# on the screen that needs it.
		var was: RichTextLabel = RichTextLabel.new()
		was.bbcode_enabled = true
		was.fit_content = true
		was.scroll_active = false
		was.autowrap_mode = TextServer.AUTOWRAP_OFF
		was.mouse_filter = Control.MOUSE_FILTER_IGNORE
		was.add_theme_font_size_override("normal_font_size", 12)
		was.add_theme_color_override("default_color", ZenithTheme.MUTED)
		was.text = "[s]%d[/s]" % full
		box.add_child(was)
	return box


# --- Keeping ---------------------------------------------------------------------

func _on_keep(id: String) -> void:
	if _busy:
		return
	status_label.text = ""
	if Session.keep_card(id, 1) <= 0:
		status_label.text = "That copy could not be kept."
	_refresh()


## Re-reads the offer rows and retunes every cell: the copies left, the Keep button's state and
## the "Kept N" line. The cells themselves are never rebuilt, so the grid holds still.
func _refresh() -> void:
	_refresh_stats()
	var by_id: Dictionary = {}
	for row in Session.settle_offers():
		by_id[str(row["id"])] = row
	for i in range(_ids.size()):
		var id: String = _ids[i]
		var kept_copies: int = int(Session.run.kept.get(id, 0))
		_kept_labels[i].text = "Kept %d" % kept_copies if kept_copies > 0 else ""
		var card_cap: int = AdventureCollection.cap(id, Session.library)
		var at_cap: bool = Session.collection.copies(id) >= card_cap
		_cap_labels[i].text = "%d max" % card_cap if at_cap else ""
		var button: Button = _keep_buttons[i]
		if not by_id.has(id):
			_count_labels[i].get_parent().visible = false
			button.disabled = true
			button.text = "Kept"
			button.tooltip_text = "Every copy this run offered is banked."
			continue
		var row: Dictionary = by_id[id]
		var left: int = int(row["count"])
		var unit: int = int(row["unit"])
		var room: int = int(row["cap_remaining"])
		_count_labels[i].text = "x%d" % left
		_count_labels[i].get_parent().visible = left > 1
		button.text = "Keep 1"
		if room == 0:
			button.disabled = true
			button.tooltip_text = "The collection already holds every copy it may."
		elif not Session.wallet.can_afford(unit):
			button.disabled = true
			button.tooltip_text = "%d Motes short." % (unit - Session.wallet.motes)
		else:
			button.disabled = false
			button.tooltip_text = ""


# --- Footer ------------------------------------------------------------------------

## The select screen's lock-in beat, then the hand-off. Dev mode stops at the beat: closing the
## settlement would clear a save and change scene, and a dev screen never does either for real.
func _on_continue() -> void:
	if _busy:
		return
	_busy = true
	continue_button.disabled = true
	for button in _keep_buttons:
		button.disabled = true
	if not _reduced_motion:
		await get_tree().create_timer(ADVANCE_DELAY).timeout
	Session.finish_settlement()


# --- Hover zoom and inspect, the reward screen's own ---------------------------------

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


func _open_inspect(def: CardDef) -> void:
	if def == null:
		return
	_hide_zoom()
	inspect_face.show_def(def)
	inspect.visible = true


func _is_inspect_click(event: InputEvent) -> bool:
	return event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT


func _on_inspect_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		inspect.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if inspect.visible and event.is_action_pressed("ui_cancel"):
		inspect.visible = false
		get_viewport().set_input_as_handled()


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


# --- Dev flags --------------------------------------------------------------------

## `--dev-settle=<starter_id>[:won|lost]` plays a whole run in memory against a scratch wallet and
## collection, then opens the settlement on it. "lost" falls at stage 4; anything else beats the
## ladder. The player's save is never read or written.
func _dev_setup() -> void:
	if Session.run != null:
		return
	var arg: String = AdventureDev.flag("--dev-settle=")
	if arg == "":
		return
	var starter_id: String = arg.get_slice(":", 0)
	var lose_at: int = 3 if arg.get_slice(":", 1) == "lost" else -1
	AdventureDev.use_scratch_saves()
	if not AdventureDev.simulate_run(starter_id, lose_at):
		return
	# `--dev-motes=N` tops the scratch wallet up so a shot can keep more than the run itself paid
	# for. Without the flag the run's own earnings stand.
	AdventureDev.give_motes(Session.wallet.motes)
	AdventureSettlement.open(Session.run)


## `--dev-keep=N` presses Keep on the first N cards, so a shot can show the kept state.
func _dev_after_layout() -> void:
	var keep_arg: String = AdventureDev.flag("--dev-keep=")
	if keep_arg == "":
		return
	for i in range(mini(int(keep_arg), _ids.size())):
		_on_keep(_ids[i])
