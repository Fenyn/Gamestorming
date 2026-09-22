class_name Loadout
extends Control
## Loadout: swap collection cards into a starter's Life Deck or Duelist stack before a run begins.
## Reached from the adventure start screen with a starter already picked. Nothing here is saved;
## the assembled deck is only real once Begin hands it to Session.start_run().
##
## Carries a class_name, unlike its sibling screens under scripts/adventure/, only so the starter
## pick below can be written from outside: assigning a static var through a preloaded Script
## resource (no class_name) parses but is rejected at load ("Cannot assign a new value to a
## constant"), where the class name is not.

const ADVANCE_DELAY: float = 0.6
const FACE_SIZE: Vector2 = Vector2(150, 210)

## Set by the start screen right before it calls Session.go_to_loadout(), since no other channel
## carries a starter pick to this scene. A dev launch fills it from a flag instead.
static var starter_id: String = ""

@onready var faces: CardFaceCache = $CardFaceCache
@onready var deck_name_label: Label = $Margin/Column/TitleRow/DeckName
@onready var rung_row: HFlowContainer = $Margin/Column/Body/Left/RungRow
@onready var deck_list: RunDeckList = $Margin/Column/Body/Left/DeckList
@onready var deck_size_label: Label = $Margin/Column/Body/Left/DeckStatus/DeckSize
@onready var swap_hint_label: Label = $Margin/Column/Body/Right/SwapHint
@onready var swap_scroll: ScrollContainer = $Margin/Column/Body/Right/SwapScroll
@onready var swap_grid: HFlowContainer = $Margin/Column/Body/Right/SwapScroll/SwapGrid
@onready var swap_empty_label: Label = $Margin/Column/Body/Right/SwapEmpty
@onready var swap_status_label: Label = $Margin/Column/Body/Right/Controls/SwapStatus
@onready var reset_button: Button = $Margin/Column/Body/Right/Controls/Reset
@onready var swap_button: Button = $Margin/Column/Body/Right/Controls/Swap
@onready var back_button: Button = $Margin/Column/Footer/Back
@onready var problems_label: Label = $Margin/Column/Footer/Problems
@onready var begin_button: Button = $Margin/Column/Footer/Begin

var _deck: DeckList = null
## "" (nothing picked yet), "card" (a Life Deck slot) or "rung" (a Duelist tier).
var _mode: String = ""
var _slot_id: String = ""
var _slot_tier: int = -1
var _swap_ids: Array[String] = []
var _swap_buttons: Array[TextureButton] = []
var _selected_in_id: String = ""
var _rung_buttons: Array[Button] = []
var _rung_group: ButtonGroup = ButtonGroup.new()
var _reduced_motion: bool = false
var _busy: bool = false


func _ready() -> void:
	theme = ZenithTheme.get_theme()
	_reduced_motion = AdventureDev.reduced_motion()
	_dev_setup()
	if starter_id == "":
		Session.go_to_adventure()
		return
	_deck = AdventureLoadout.base_deck(starter_id)
	if _deck == null:
		Session.go_to_adventure()
		return
	deck_list.card_selected.connect(_on_deck_card_picked)
	reset_button.pressed.connect(_on_reset)
	swap_button.pressed.connect(_on_swap)
	back_button.pressed.connect(_on_back)
	begin_button.pressed.connect(_on_begin)
	swap_status_label.text = ""
	_refresh_left()
	_refresh_swap_panel()
	_refresh_footer()
	await _dev_after_layout()
	AdventureDev.screenshot(self)


# --- Left: the deck and the Duelist stack -----------------------------------

func _refresh_left() -> void:
	deck_name_label.text = _deck.name
	deck_list.set_caption("%d life cards" % _deck.cards.size())
	deck_list.show_cards(_deck.cards, Session.library, faces)
	deck_size_label.text = "%d life cards" % _deck.cards.size()
	_build_rung_row()


## One chip per Duelist tier, lowest first. Picking one arms a rung swap the way picking a deck
## card arms a Life Deck swap; the two are mutually exclusive, so picking either drops the other.
func _build_rung_row() -> void:
	for child in rung_row.get_children():
		rung_row.remove_child(child)
		child.queue_free()
	_rung_buttons.clear()
	var stack: PersonalityStack = _deck.duelist_stack(Session.library)
	var labels: Array[String] = CardText.stack_rungs(stack)
	for i in range(labels.size()):
		var tier: int = i + 1
		var chip: Button = Button.new()
		chip.text = labels[i]
		chip.theme_type_variation = &"TileButton"
		chip.toggle_mode = true
		chip.button_group = _rung_group
		chip.button_pressed = _mode == "rung" and _slot_tier == tier
		chip.pressed.connect(func() -> void: _on_rung_picked(tier))
		rung_row.add_child(chip)
		_rung_buttons.append(chip)


func _on_deck_card_picked(id: String) -> void:
	_mode = "card"
	_slot_id = id
	_slot_tier = -1
	_selected_in_id = ""
	swap_status_label.text = ""
	for chip in _rung_buttons:
		chip.button_pressed = false
	await _refresh_swap_panel()


func _on_rung_picked(tier: int) -> void:
	_mode = "rung"
	_slot_tier = tier
	_slot_id = ""
	_selected_in_id = ""
	swap_status_label.text = ""
	await _refresh_swap_panel()


# --- Right: the collection's legal swaps for whatever is picked -------------

func _refresh_swap_panel() -> void:
	for child in swap_grid.get_children():
		swap_grid.remove_child(child)
		child.queue_free()
	_swap_ids.clear()
	_swap_buttons.clear()
	_selected_in_id = ""
	swap_button.disabled = true
	if _mode == "card":
		swap_hint_label.text = "Collection cards that could take this card's place"
		_swap_ids = AdventureLoadout.swappable_in(_deck, Session.library, Session.collection, _slot_id)
	elif _mode == "rung":
		swap_hint_label.text = "Collection cards that could stand on this rung"
		_swap_ids = AdventureLoadout.swappable_rungs(_deck, Session.library, Session.collection, _slot_tier)
	else:
		swap_hint_label.text = "Pick a deck card or a Duelist rung to see what could swap in"
	swap_empty_label.visible = _mode != "" and _swap_ids.is_empty()
	swap_scroll.visible = not _swap_ids.is_empty()
	await _build_swap_cells()


func _build_swap_cells() -> void:
	for id in _swap_ids:
		var def: CardDef = Session.library.defs.get(id)
		if def == null:
			continue
		swap_grid.add_child(await _build_swap_cell(def))


func _build_swap_cell(def: CardDef) -> Control:
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
	button.pressed.connect(func() -> void: _on_swap_target_picked(def.id))
	wrap.add_child(button)
	column.add_child(wrap)

	var title: Label = Label.new()
	title.text = def.title
	title.add_theme_font_size_override("font_size", 12)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size.x = FACE_SIZE.x
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title)

	var owned: Label = Label.new()
	owned.theme_type_variation = &"MutedLabel"
	owned.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	owned.custom_minimum_size.x = FACE_SIZE.x
	owned.text = "Owned %d" % Session.collection.copies(def.id)
	owned.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(owned)

	panel.add_child(column)
	button.set_meta("panel", panel)
	button.set_meta("tint", tint)
	button.set_meta("id", def.id)
	_swap_buttons.append(button)
	_style_swap_cell(panel, tint, false)
	return panel


func _style_swap_cell(panel: PanelContainer, tint: Color, selected: bool) -> void:
	if selected:
		panel.add_theme_stylebox_override("panel", ZenithTheme.box(ZenithTheme.ACCENT_SOFT, ZenithTheme.ACCENT, 12, 2, 10, 10))
	else:
		panel.add_theme_stylebox_override("panel", ZenithTheme.edged(tint, Color(tint, 0.08), 12, 10, 10))


func _on_swap_target_picked(id: String) -> void:
	_selected_in_id = id
	swap_status_label.text = ""
	swap_button.disabled = false
	for button in _swap_buttons:
		var panel: PanelContainer = button.get_meta("panel")
		var tint: Color = button.get_meta("tint")
		_style_swap_cell(panel, tint, str(button.get_meta("id", "")) == id)


func _on_swap() -> void:
	if _busy or _mode == "" or _selected_in_id == "":
		return
	var result: Dictionary
	if _mode == "card":
		result = AdventureLoadout.swap(_deck, _slot_id, _selected_in_id, Session.library, Session.collection)
	else:
		result = AdventureLoadout.swap_rung(_deck, _slot_tier, _selected_in_id, Session.library, Session.collection)
	var problems: Array[String] = result.get("problems", [])
	if result.get("deck") == null:
		swap_status_label.text = "\n".join(problems) if not problems.is_empty() else "That swap is not legal."
		return
	_deck = result["deck"]
	_mode = ""
	_slot_id = ""
	_slot_tier = -1
	_selected_in_id = ""
	swap_status_label.text = ""
	_refresh_left()
	await _refresh_swap_panel()
	_refresh_footer()


func _on_reset() -> void:
	if _busy:
		return
	_deck = AdventureLoadout.base_deck(starter_id)
	_mode = ""
	_slot_id = ""
	_slot_tier = -1
	_selected_in_id = ""
	swap_status_label.text = ""
	_refresh_left()
	await _refresh_swap_panel()
	_refresh_footer()


# --- Footer -------------------------------------------------------------------

func _refresh_footer() -> void:
	var problems: Array[String] = Session.deck_problems(_deck)
	problems_label.text = "\n".join(problems)
	begin_button.disabled = not problems.is_empty()


func _on_back() -> void:
	Session.get_tree().change_scene_to_file(Session.ADVENTURE_START_SCENE)


func _on_begin() -> void:
	if _busy or begin_button.disabled:
		return
	_busy = true
	begin_button.disabled = true
	back_button.disabled = true
	reset_button.disabled = true
	swap_button.disabled = true
	if not _reduced_motion:
		await get_tree().create_timer(ADVANCE_DELAY).timeout
	Session.start_run(starter_id, _deck)
	Session.go_to_adventure()


# --- Dev flags -----------------------------------------------------------------

## `--dev-loadout=<starter_id>` opens the loadout against a scratch collection stocked with a few
## legal Life Deck swaps in the starter's own style, a Freestyle card, and (for pyre_beatdown_start)
## the personality card its Duelist would grow into next, so the roster is never empty.
func _dev_setup() -> void:
	var arg: String = AdventureDev.flag("--dev-loadout=")
	if arg == "":
		return
	AdventureDev.use_scratch_saves()
	starter_id = arg
	_stock_dev_collection(arg)


func _stock_dev_collection(sid: String) -> void:
	var base: DeckList = AdventureLoadout.base_deck(sid)
	if base == null:
		return
	var ids: Array[String] = []
	var skip_types: Array[int] = [CardDef.Type.PERSONALITY, CardDef.Type.MASTERY, CardDef.Type.RELIC, CardDef.Type.SEAL]
	for id in Session.library.all_ids():
		if ids.size() >= 3:
			break
		var def: CardDef = Session.library.defs[id]
		if def.school == base.style and not skip_types.has(int(def.type)) and not base.cards.has(id):
			ids.append(id)
	for id in Session.library.all_ids():
		var def: CardDef = Session.library.defs[id]
		if def.school == "" and not skip_types.has(int(def.type)):
			ids.append(id)
			break
	if sid == "pyre_beatdown_start":
		# The card its own Duelist line would grow into at the next Aspect. It cannot swap into a
		# rung this deck has not grown to yet, or stand in the Life Deck as an Ally of its own
		# Duelist's character, so it never appears in the swap panel; stocked anyway since the
		# request names it by id, and the alternate at the deck's own tier 2 covers the rung-swap
		# screenshot instead.
		ids.append("personality_bram_ashmark_3_unstoppable")
		ids.append("personality_bram_ashmark_2_gnawing")
	AdventureDev.stock_collection(ids, 2)


## `--dev-swap=<out>,<in>` performs one Life Deck swap before the screenshot; `--dev-rung=<tier>,<in>`
## performs one rung swap. Either can follow the other; only one is expected per launch.
## `--dev-pick-card=<id>` or `--dev-pick-rung=<tier>` arms a slot without swapping it, so a shot
## can show the collection's legal swaps for it, the way a click on the card or the chip would.
func _dev_after_layout() -> void:
	var swap_arg: String = AdventureDev.flag("--dev-swap=")
	if swap_arg != "":
		var parts: PackedStringArray = swap_arg.split(",")
		if parts.size() == 2:
			var result: Dictionary = AdventureLoadout.swap(_deck, parts[0], parts[1], Session.library, Session.collection)
			if result.get("deck") != null:
				_deck = result["deck"]
				_refresh_left()
				_refresh_footer()
	var rung_arg: String = AdventureDev.flag("--dev-rung=")
	if rung_arg != "":
		var rparts: PackedStringArray = rung_arg.split(",")
		if rparts.size() == 2:
			var result: Dictionary = AdventureLoadout.swap_rung(_deck, int(rparts[0]), rparts[1], Session.library, Session.collection)
			if result.get("deck") != null:
				_deck = result["deck"]
				_refresh_left()
				_refresh_footer()
	var pick_card_arg: String = AdventureDev.flag("--dev-pick-card=")
	var pick_rung_arg: String = AdventureDev.flag("--dev-pick-rung=")
	if pick_card_arg != "":
		await _on_deck_card_picked(pick_card_arg)
	elif pick_rung_arg != "":
		await _on_rung_picked(int(pick_rung_arg))
	else:
		await _refresh_swap_panel()
	var pick_target_arg: String = AdventureDev.flag("--dev-pick-target=")
	if pick_target_arg != "" and _swap_ids.has(pick_target_arg):
		_on_swap_target_picked(pick_target_arg)
