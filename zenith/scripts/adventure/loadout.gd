class_name Loadout
extends Control
## Loadout: build a starter into the deck a run begins from. Collection cards swap into the Life
## Deck or the Duelist stack, Motes buy deck slots and Aspect tiers for this starter, and a bought
## slot is filled with any legal pick from the collection. Reached from the adventure start screen
## with a starter already picked. The assembled deck is only real once Begin hands it to
## Session.start_run(); the upgrades bought here are saved on the spot, because they are paid for.
##
## Carries a class_name, unlike its sibling screens under scripts/adventure/, only so the starter
## pick below can be written from outside: assigning a static var through a preloaded Script
## resource (no class_name) parses but is rejected at load ("Cannot assign a new value to a
## constant"), where the class name is not.

const ADVANCE_DELAY: float = 0.6
const FACE_SIZE: Vector2 = Vector2(150, 210)
## How far a collection card is dimmed while nothing in this deck can take it.
const UNUSABLE_ALPHA: float = 0.4

## Set by the start screen right before it calls Session.go_to_loadout(), since no other channel
## carries a starter pick to this scene. A dev launch fills it from a flag instead.
static var starter_id: String = ""

@onready var faces: CardFaceCache = $CardFaceCache
@onready var deck_name_label: Label = $Margin/Column/TitleRow/DeckName
@onready var motes_tile: StatTile = $Margin/Column/Upgrades/UpgradeRow/Motes
@onready var slot_label: Label = $Margin/Column/Upgrades/UpgradeRow/SlotBox/SlotLabel
@onready var buy_slot_button: Button = $Margin/Column/Upgrades/UpgradeRow/SlotBox/BuySlot
@onready var aspect_label: Label = $Margin/Column/Upgrades/UpgradeRow/AspectBox/AspectLabel
@onready var buy_aspect_button: Button = $Margin/Column/Upgrades/UpgradeRow/AspectBox/BuyAspect
@onready var upgrade_status_label: Label = $Margin/Column/Upgrades/UpgradeRow/UpgradeStatus
@onready var rung_row: HFlowContainer = $Margin/Column/Body/Left/RungRow
@onready var deck_list: RunDeckList = $Margin/Column/Body/Left/DeckList
@onready var deck_size_label: Label = $Margin/Column/Body/Left/DeckStatus/DeckSize
@onready var swap_hint_label: Label = $Margin/Column/Body/Right/SwapHint
@onready var swap_scroll: ScrollContainer = $Margin/Column/Body/Right/SwapScroll
@onready var swap_grid: HFlowContainer = $Margin/Column/Body/Right/SwapScroll/SwapGrid
@onready var swap_empty_label: Label = $Margin/Column/Body/Right/SwapEmpty
@onready var swap_status_label: Label = $Margin/Column/Body/Right/Controls/SwapStatus
@onready var reset_button: Button = $Margin/Column/Body/Right/Controls/Reset
@onready var add_button: Button = $Margin/Column/Body/Right/Controls/Add
@onready var add_aspect_button: Button = $Margin/Column/Body/Right/Controls/AddAspect
@onready var swap_button: Button = $Margin/Column/Body/Right/Controls/Swap
@onready var back_button: Button = $Margin/Column/Footer/Back
@onready var problems_label: Label = $Margin/Column/Footer/Problems
@onready var begin_button: Button = $Margin/Column/Footer/Begin

var _deck: DeckList = null
## "" (nothing picked, the whole collection is on show), "card" (a Life Deck slot), "rung" (a
## Duelist tier), "add" (an empty deck slot) or "aspect" (the next Aspect card).
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
	add_button.pressed.connect(_on_add)
	add_aspect_button.pressed.connect(_on_add_aspect)
	buy_slot_button.pressed.connect(_on_buy_slot)
	buy_aspect_button.pressed.connect(_on_buy_aspect)
	back_button.pressed.connect(_on_back)
	begin_button.pressed.connect(_on_begin)
	swap_status_label.text = ""
	upgrade_status_label.text = Session.take_dissolve_report()
	_refresh_left()
	_refresh_upgrades()
	await _refresh_swap_panel()
	_refresh_footer()
	await _dev_after_layout()
	AdventureDev.screenshot(self)


# --- The upgrades strip -----------------------------------------------------

## "Deck slots: 50 + 2 (buy next: 200 Motes)" and the Aspect tiers beside it, both with a Buy that
## goes quiet when the wallet is short or the starter has bought everything there is.
func _refresh_upgrades() -> void:
	motes_tile.set_stat("Motes", str(Session.wallet.motes), "", ZenithTheme.ACCENT)
	var bought: int = Session.upgrades.slots(starter_id)
	var base_size: int = AdventureLoadout.size_cap(_deck)
	var slot_cost: int = Session.upgrades.next_slot_cost(starter_id)
	slot_label.text = "Deck slots: %d%s" % [base_size, " + %d" % bought if bought > 0 else ""]
	if slot_cost <= 0:
		buy_slot_button.text = "Deck slots maxed"
		buy_slot_button.disabled = true
		buy_slot_button.tooltip_text = "This starter has bought every deck slot there is."
	else:
		buy_slot_button.text = "Buy next slot: %d Motes" % slot_cost
		buy_slot_button.disabled = not Session.wallet.can_afford(slot_cost)
		buy_slot_button.tooltip_text = "" if not buy_slot_button.disabled else "%d Motes short." % (
			slot_cost - Session.wallet.motes)

	var base_aspects: int = int(_deck.get_meta(AdventureLoadout.META_BASE_ASPECTS, _deck.duelist_ids.size()))
	var unlocked: int = Session.upgrades.aspect_tier(starter_id, base_aspects)
	var aspect_cost: int = Session.upgrades.next_aspect_cost(starter_id, base_aspects)
	aspect_label.text = "Aspect tiers: 1-%d" % unlocked
	if aspect_cost <= 0:
		buy_aspect_button.text = "Aspect tiers maxed"
		buy_aspect_button.disabled = true
		buy_aspect_button.tooltip_text = "The stack is already at the highest Aspect a deck may run."
	else:
		buy_aspect_button.text = "Unlock tier %d: %d Motes" % [unlocked + 1, aspect_cost]
		buy_aspect_button.disabled = not Session.wallet.can_afford(aspect_cost)
		buy_aspect_button.tooltip_text = "" if not buy_aspect_button.disabled else "%d Motes short." % (
			aspect_cost - Session.wallet.motes)


func _on_buy_slot() -> void:
	if _busy:
		return
	upgrade_status_label.text = ""
	if not Session.buy_slot(starter_id):
		upgrade_status_label.text = "That slot could not be bought."
		return
	_refresh_left()
	_refresh_upgrades()
	await _refresh_swap_panel()
	_refresh_footer()


func _on_buy_aspect() -> void:
	if _busy:
		return
	upgrade_status_label.text = ""
	if not Session.buy_aspect_tier(starter_id):
		upgrade_status_label.text = "That Aspect tier could not be unlocked."
		return
	_refresh_left()
	_refresh_upgrades()
	await _refresh_swap_panel()
	_refresh_footer()


# --- Left: the deck and the Duelist stack -----------------------------------

func _refresh_left() -> void:
	deck_name_label.text = _deck.name
	var cap: int = AdventureLoadout.size_cap(_deck, Session.upgrades)
	var size: int = _deck.cards.size()
	var caption: String = "%d life cards" % size if cap <= size else "%d of %d life cards" % [size, cap]
	deck_list.set_caption(caption)
	deck_list.show_cards(_deck.cards, Session.library, faces)
	deck_size_label.text = caption
	_build_rung_row()


## One chip per Duelist tier, lowest first. Picking one arms a tier swap the way picking a deck
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


# --- Right: the collection's legal picks for whatever is armed --------------

func _refresh_swap_panel() -> void:
	for child in swap_grid.get_children():
		swap_grid.remove_child(child)
		child.queue_free()
	_swap_ids.clear()
	_swap_buttons.clear()
	_selected_in_id = ""
	var browsing: bool = _mode == ""
	match _mode:
		"card":
			swap_hint_label.text = "Collection cards that could take this card's place"
			_swap_ids = AdventureLoadout.swappable_in(_deck, Session.library, Session.collection, _slot_id)
		"rung":
			swap_hint_label.text = "Collection cards that could stand at this Aspect tier"
			_swap_ids = AdventureLoadout.swappable_rungs(_deck, Session.library, Session.collection, _slot_tier)
		"add":
			swap_hint_label.text = "Collection cards that could fill an empty deck slot"
			_swap_ids = AdventureLoadout.swappable_add(_deck, Session.library, Session.collection, Session.upgrades)
		"aspect":
			swap_hint_label.text = "Collection Aspect cards that could go on top of the stack"
			_swap_ids = AdventureLoadout.swappable_aspect(_deck, Session.library, Session.collection, Session.upgrades)
		_:
			swap_hint_label.text = ("Your whole collection. Pick a deck card or an Aspect tier to " +
				"swap, or Add to fill an empty deck slot. Greyed cards do not fit this deck.")
			_swap_ids = Session.collection.all_ids()
	swap_empty_label.visible = _swap_ids.is_empty()
	swap_empty_label.text = ("Nothing in the collection yet. The vendor and the run-end screen are " +
		"where cards come from.") if browsing else "Nothing in the collection can legally go here."
	swap_scroll.visible = not _swap_ids.is_empty()
	await _build_swap_cells(browsing)
	_refresh_actions()


func _build_swap_cells(browsing: bool) -> void:
	for id in _swap_ids:
		var def: CardDef = Session.library.defs.get(id)
		if def == null:
			continue
		swap_grid.add_child(await _build_swap_cell(def, browsing and not _usable(id)))


func _build_swap_cell(def: CardDef, greyed: bool) -> Control:
	var tint: Color = Palette.card_ui(def)
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ZenithTheme.edged(tint, Color(tint, 0.08), 12, 10, 10))
	if greyed:
		panel.modulate = Color(1, 1, 1, UNUSABLE_ALPHA)

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
	button.disabled = greyed
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
	owned.text = _owned_line(def.id)
	owned.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(owned)

	panel.add_child(column)
	button.set_meta("panel", panel)
	button.set_meta("tint", tint)
	button.set_meta("id", def.id)
	_swap_buttons.append(button)
	_style_swap_cell(panel, tint, false)
	if greyed:
		panel.modulate = Color(1, 1, 1, UNUSABLE_ALPHA)
	return panel


## How many copies the collection holds, and how many of them this deck has already taken. The
## loadout may take at most what is owned, so the two numbers together are the limit.
func _owned_line(id: String) -> String:
	var owned: int = Session.collection.copies(id)
	var in_deck: int = AdventureLoadout.from_collection(_deck, id)
	if in_deck <= 0:
		return "Owned %d" % owned
	return "Owned %d, %d in deck" % [owned, in_deck]


## True when this deck could take the card somewhere: an empty slot, the top of the Aspect stack,
## or in place of something it already runs. Stops at the first place that works.
func _usable(id: String) -> bool:
	if (AdventureLoadout.add_card(_deck, id, Session.library, Session.collection,
			Session.upgrades)["problems"] as Array[String]).is_empty():
		return true
	if (AdventureLoadout.add_aspect(_deck, id, Session.library, Session.collection,
			Session.upgrades)["problems"] as Array[String]).is_empty():
		return true
	for tier in range(1, _deck.duelist_ids.size() + 1):
		if (AdventureLoadout.swap_rung(_deck, tier, id, Session.library,
				Session.collection)["problems"] as Array[String]).is_empty():
			return true
	for out_id in AdventureLoadout.swappable_out(_deck):
		if out_id == id:
			continue
		if (AdventureLoadout.swap(_deck, out_id, id, Session.library,
				Session.collection)["problems"] as Array[String]).is_empty():
			return true
	return false


func _style_swap_cell(panel: PanelContainer, tint: Color, selected: bool) -> void:
	if selected:
		panel.add_theme_stylebox_override("panel", ZenithTheme.box(ZenithTheme.ACCENT_SOFT, ZenithTheme.ACCENT, 12, 2, 10, 10))
	else:
		panel.add_theme_stylebox_override("panel", ZenithTheme.edged(tint, Color(tint, 0.08), 12, 10, 10))


func _on_swap_target_picked(id: String) -> void:
	_selected_in_id = id
	swap_status_label.text = ""
	for button in _swap_buttons:
		var panel: PanelContainer = button.get_meta("panel")
		var tint: Color = button.get_meta("tint")
		_style_swap_cell(panel, tint, str(button.get_meta("id", "")) == id)
	_refresh_actions()


## The three action buttons. Swap confirms a picked slot; Add and Add Aspect arm their own mode
## first, then confirm once a card is picked.
func _refresh_actions() -> void:
	swap_button.disabled = not ((_mode == "card" or _mode == "rung") and _selected_in_id != "")
	var room: int = AdventureLoadout.room_left(_deck, Session.upgrades)
	if _mode == "add":
		add_button.text = "Add card"
		add_button.disabled = _selected_in_id == ""
	else:
		add_button.text = "Add (%d free)" % room if room > 0 else "Add"
		add_button.disabled = room <= 0
	add_button.tooltip_text = "" if room > 0 else "Every deck slot is filled. Buy one to add a card."

	var aspect_room: bool = _deck.duelist_ids.size() < AdventureLoadout.aspect_cap(_deck, Session.upgrades)
	if _mode == "aspect":
		add_aspect_button.text = "Add Aspect card"
		add_aspect_button.disabled = _selected_in_id == ""
	else:
		add_aspect_button.text = "Add Aspect"
		add_aspect_button.disabled = not aspect_room or AdventureLoadout.swappable_aspect(
			_deck, Session.library, Session.collection, Session.upgrades).is_empty()
	add_aspect_button.tooltip_text = "" if aspect_room else "Unlock the next Aspect tier to add one."


func _on_swap() -> void:
	if _busy or _selected_in_id == "":
		return
	var result: Dictionary
	if _mode == "card":
		result = AdventureLoadout.swap(_deck, _slot_id, _selected_in_id, Session.library, Session.collection)
	elif _mode == "rung":
		result = AdventureLoadout.swap_rung(_deck, _slot_tier, _selected_in_id, Session.library, Session.collection)
	else:
		return
	await _apply(result, "That swap is not legal.")


func _on_add() -> void:
	if _busy:
		return
	if _mode != "add":
		_mode = "add"
		_slot_id = ""
		_slot_tier = -1
		swap_status_label.text = ""
		for chip in _rung_buttons:
			chip.button_pressed = false
		await _refresh_swap_panel()
		return
	if _selected_in_id == "":
		return
	await _apply(AdventureLoadout.add_card(_deck, _selected_in_id, Session.library,
		Session.collection, Session.upgrades), "That card cannot be added.")


func _on_add_aspect() -> void:
	if _busy:
		return
	if _mode != "aspect":
		_mode = "aspect"
		_slot_id = ""
		_slot_tier = -1
		swap_status_label.text = ""
		for chip in _rung_buttons:
			chip.button_pressed = false
		await _refresh_swap_panel()
		return
	if _selected_in_id == "":
		return
	await _apply(AdventureLoadout.add_aspect(_deck, _selected_in_id, Session.library,
		Session.collection, Session.upgrades), "That Aspect card cannot be added.")


## Takes the deck a swap or an add handed back, or shows why it was refused and changes nothing.
func _apply(result: Dictionary, fallback: String) -> void:
	var problems: Array[String] = result.get("problems", [])
	if result.get("deck") == null:
		swap_status_label.text = "\n".join(problems) if not problems.is_empty() else fallback
		return
	_deck = result["deck"]
	_mode = ""
	_slot_id = ""
	_slot_tier = -1
	swap_status_label.text = ""
	_refresh_left()
	_refresh_upgrades()
	await _refresh_swap_panel()
	_refresh_footer()


func _on_reset() -> void:
	if _busy:
		return
	_deck = AdventureLoadout.base_deck(starter_id)
	_mode = ""
	_slot_id = ""
	_slot_tier = -1
	swap_status_label.text = ""
	_refresh_left()
	_refresh_upgrades()
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
	add_button.disabled = true
	add_aspect_button.disabled = true
	if not _reduced_motion:
		await get_tree().create_timer(ADVANCE_DELAY).timeout
	Session.start_run(starter_id, _deck)
	Session.go_to_adventure()


# --- Dev flags -----------------------------------------------------------------

## `--dev-loadout=<starter_id>` opens the loadout against a scratch collection stocked with a few
## legal Life Deck swaps in the starter's own style, a Freestyle card, and (for pyre_beatdown_start)
## the personality cards its Duelist would grow into next, so the roster is never empty.
## `--dev-motes=N` sets the scratch balance and `--dev-upgrades=<slots>,<tier>` presets what this
## starter has bought, neither of them spending anything.
func _dev_setup() -> void:
	var arg: String = AdventureDev.flag("--dev-loadout=")
	if arg == "":
		return
	AdventureDev.use_scratch_saves()
	starter_id = arg
	AdventureDev.give_motes(600)
	AdventureDev.preset_upgrades(arg)
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
		# The cards its own Duelist line grows into. Neither can stand in the Life Deck as an Ally
		# of its own Duelist's character, and neither fits a tier the stack already has, so they
		# show up only once an Aspect tier is unlocked and Add Aspect is armed.
		ids.append("personality_bram_ashmark_3_unstoppable")
		ids.append("personality_bram_ashmark_3_gorging")
		ids.append("personality_bram_ashmark_2_gnawing")
	AdventureDev.stock_collection(ids, 2)


## `--dev-swap=<out>,<in>` performs one Life Deck swap before the screenshot; `--dev-rung=<tier>,<in>`
## performs one Aspect-tier swap; `--dev-add=<id>` fills an empty deck slot and `--dev-add-aspect=<id>`
## puts the next Aspect card on the stack. `--dev-pick-card=<id>` or `--dev-pick-rung=<tier>` arms a
## slot without swapping it, so a shot can show the collection's legal picks for it.
func _dev_after_layout() -> void:
	var swap_arg: String = AdventureDev.flag("--dev-swap=")
	if swap_arg != "":
		var parts: PackedStringArray = swap_arg.split(",")
		if parts.size() == 2:
			_take(AdventureLoadout.swap(_deck, parts[0], parts[1], Session.library, Session.collection))
	var rung_arg: String = AdventureDev.flag("--dev-rung=")
	if rung_arg != "":
		var rparts: PackedStringArray = rung_arg.split(",")
		if rparts.size() == 2:
			_take(AdventureLoadout.swap_rung(_deck, int(rparts[0]), rparts[1], Session.library, Session.collection))
	var add_arg: String = AdventureDev.flag("--dev-add=")
	if add_arg != "":
		_take(AdventureLoadout.add_card(_deck, add_arg, Session.library, Session.collection, Session.upgrades))
	var add_aspect_arg: String = AdventureDev.flag("--dev-add-aspect=")
	if add_aspect_arg != "":
		_take(AdventureLoadout.add_aspect(_deck, add_aspect_arg, Session.library, Session.collection, Session.upgrades))
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


## A dev flag's result, applied when it was legal and reported on the strip when it was not.
func _take(result: Dictionary) -> void:
	if result.get("deck") == null:
		var problems: Array[String] = result.get("problems", [])
		upgrade_status_label.text = "\n".join(problems)
		return
	_deck = result["deck"]
	_refresh_left()
	_refresh_upgrades()
	_refresh_footer()
