extends Control
## The Relic node's screen: the held Relic on the left with a Keep button, and three offers, each a
## Relic with its Reserve set. One click takes an offer. The rules live in AdventureRelic; taking,
## keeping and saving go through Session.

const PREVIEW_GAP: float = 14.0

@onready var faces: CardFaceCache = $CardFaceCache
@onready var strip: PanelContainer = $Strip
@onready var run_name_label: Label = $Strip/Row/RunName
@onready var standing_label: Label = $Strip/Row/Standing
@onready var mana_icon: TextureRect = $Strip/Row/ManaBox/ManaIcon
@onready var mana_label: Label = $Strip/Row/ManaBox/ManaValue
@onready var mote_icon: TextureRect = $Strip/Row/MotesBox/MoteIcon
@onready var motes_label: Label = $Strip/Row/MotesBox/MotesValue
@onready var title: Label = $Title
@onready var subtitle: Label = $Subtitle
@onready var held_panel: PanelContainer = $Row/Held
@onready var held_face: TextureRect = $Row/Held/Column/Face
@onready var held_reserve: Label = $Row/Held/Column/Reserve
@onready var held_note: Label = $Row/Held/Column/Note
@onready var keep_button: Button = $Row/Held/Column/Keep
@onready var offers: Array[RelicOffer] = [$Row/Offer0, $Row/Offer1, $Row/Offer2]
@onready var preview: Panel = $Preview
@onready var preview_face: TextureRect = $Preview/Face

## Per offer, the card ids its small faces show.
var _cards: Array = [[], [], []]
var _dev: bool = false
var _busy: bool = false


func _ready() -> void:
	theme = SanctumUI.theme()
	_dev_setup()
	if Session.run == null or not AdventureRelic.is_open(Session.run):
		Session.go_to_adventure()
		return
	_dev = _dev or AdventureDev.in_memory
	AdventureRelic.open(Session.run, Session.library)
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
	held_panel.add_theme_stylebox_override("panel", MapArt.panel_box(22))
	held_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	(held_panel.get_child(0) as CanvasItem).texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	(held_panel.get_node("Column/Heading") as Label).add_theme_font_override("font", ZenithTheme.TITLE_FONT)
	keep_button.pressed.connect(_on_keep)
	for i in range(offers.size()):
		var index: int = i
		offers[i].pressed.connect(func() -> void: _on_take(index))
		offers[i].hovered.connect(func(over: bool) -> void: _on_hover(index, over))
		offers[i].card_hovered.connect(func(slot: int, over: bool) -> void: _on_card_hover(index, slot, over))
	_busy = true
	await _refresh()
	_busy = false
	SanctumUI.wire_buttons(self)
	if await _dev_after_layout():
		return
	AdventureDev.screenshot(self)


func _refresh() -> void:
	var run: AdventureRun = Session.run
	var deck: DeckList = run.deck()
	run_name_label.text = deck.name.trim_suffix(" (Starter)") if deck != null else ""
	standing_label.text = "Act %d   ·   %d won   ·   %d cards" % [
		MapRoute.act_to_show(run, Session.map), run.stage, AdventureForge.deck_size(run)]
	mana_label.text = str(run.mana)
	motes_label.text = str(Session.wallet.motes)
	var held: CardDef = Session.library.defs.get(run.relic_id) if run.relic_id != "" else null
	subtitle.text = "Take one Relic and the Reserve cards that come with it, or keep your own." if held != null \
		else "Take one Relic and the Reserve cards that come with it."
	held_face.visible = held != null
	held_reserve.visible = held != null
	keep_button.visible = held != null
	if held != null:
		held_reserve.text = "Reserve %d of %d" % [run.reserve.size(), held.reserve_size]
		held_note.text = "Reserve cards swap into your Life Deck at the start of a duel."
		held_face.texture = await faces.render_face(held)
	else:
		held_note.text = "You have no Relic yet.\n\nA Relic holds a Reserve: cards that swap into your Life Deck at the start of a duel."
	for i in range(offers.size()):
		await _fill_offer(i)


func _fill_offer(index: int) -> void:
	var run: AdventureRun = Session.run
	var offer_panel: RelicOffer = offers[index]
	offer_panel.visible = index < run.relic_offers.size()
	if not offer_panel.visible:
		return
	var offer: Dictionary = run.relic_offers[index]
	var relic: CardDef = Session.library.defs.get(str(offer.get("relic", "")))
	var ids: Array[String] = []
	for id in offer.get("cards", []):
		ids.append(str(id))
	_cards[index] = ids
	var textures: Array[Texture2D] = []
	for id in ids:
		var def: CardDef = Session.library.defs.get(id)
		if def != null:
			textures.append(await faces.render_face(def))
	var bundle: Dictionary = AdventureReserveBundles.by_id(str(offer.get("bundle", "")))
	var set_name: String = "Reserve: %s" % str(bundle.get("name", "")) if not bundle.is_empty() else ""
	var relic_tex: Texture2D = await faces.render_face(relic) if relic != null else null
	offer_panel.show_offer(relic_tex, set_name, textures, consequence(run, relic, ids.size()))


## What taking the offer does to the Reserve, in one or two sentences.
static func consequence(run: AdventureRun, relic: CardDef, arriving: int) -> String:
	if relic == null:
		return ""
	var total: int = run.reserve.size() + arriving
	var over: int = maxi(0, total - relic.reserve_size)
	if relic.id == run.relic_id:
		var line: String = "You hold this Relic. Its %s join your Reserve." % _cards_text(arriving)
		if arriving == 1:
			line = "You hold this Relic. Its 1 card joins your Reserve."
		return line + (" You would set %d aside." % over if over > 0 else "")
	if arriving == 0:
		return "Holds %d. It brings no Reserve cards." % relic.reserve_size
	if run.reserve.is_empty() and over == 0:
		return "Holds %d. %s start your Reserve." % [relic.reserve_size,
			"Its 1 card would" if arriving == 1 else "Its %d cards would" % arriving]
	var have: String = "Holds %d. You would have %d Reserve %s" % [relic.reserve_size, total, "card" if total == 1 else "cards"]
	return have + (" and set %d aside." % over if over > 0 else ".")


static func _cards_text(count: int) -> String:
	return "1 card" if count == 1 else "%d cards" % count


func _on_take(index: int) -> void:
	if _busy or index >= Session.run.relic_offers.size():
		return
	_busy = true
	_hide_preview()
	if _dev:
		var done: bool = AdventureRelic.take(Session.run, Session.library, index)
		print("relic: take %d %s, status %s" % [index, "done" if done else "refused", Session.run.status])
		if done and Session.run.status == AdventureRelic.STATUS_TRIM and not AdventureDev.has_flag("--dev-relic-stay"):
			get_tree().change_scene_to_file(Session.ADVENTURE_LIBRARY_SCENE)
		return
	if not Session.relic_take(index):
		_busy = false


func _on_keep() -> void:
	if _busy:
		return
	_busy = true
	if _dev:
		print("relic: keep %s" % ("done" if AdventureRelic.keep(Session.run) else "refused"))
		return
	if not Session.relic_keep():
		_busy = false


# --- Hover and preview ----------------------------------------------------------------------------

func _on_hover(index: int, over: bool) -> void:
	offers[index].lift(over, AdventureDev.reduced_motion())


func _on_card_hover(index: int, slot: int, over: bool) -> void:
	var ids: Array = _cards[index]
	if not over or slot >= ids.size():
		_hide_preview()
		return
	var def: CardDef = Session.library.defs.get(str(ids[slot]))
	if def == null:
		return
	preview_face.texture = await faces.render_face(def)
	var anchor: Rect2 = offers[index].card_rect(slot)
	var view: Vector2 = get_viewport_rect().size
	var at: Vector2 = Vector2(anchor.get_center().x - preview.size.x * 0.5, anchor.position.y - preview.size.y - PREVIEW_GAP)
	at.x = clampf(at.x, PREVIEW_GAP, view.x - preview.size.x - PREVIEW_GAP)
	at.y = clampf(at.y, PREVIEW_GAP, view.y - preview.size.y - PREVIEW_GAP)
	preview.position = at
	preview.visible = true


func _hide_preview() -> void:
	preview.visible = false


# --- Dev flags ----------------------------------------------------------------------------------

## Builds an unsaved run standing on the Relic node when the scene is opened directly:
## `--dev-relic=<starter>` begins the run, `--dev-stage=N` wins N duels first, and
## `--dev-relic-held[=<relic id>]` hands it a Relic (the Blank Mask by default) with a legal Reserve
## set so the Keep panel shows.
func _dev_setup() -> void:
	if Session.run != null:
		return
	var starter_id: String = AdventureDev.flag("--dev-relic=")
	if starter_id == "" or not AdventureDev.begin_run(starter_id):
		return
	_dev = true
	var stage_arg: String = AdventureDev.flag("--dev-stage=")
	if stage_arg != "":
		AdventureDev.walk(maxi(0, int(stage_arg)))
	AdventureDev.stand_on_next(AdventureRelic.STATUS_OFFERS)
	var run: AdventureRun = Session.run
	var held: String = AdventureDev.flag("--dev-relic-held=")
	if held == "" and AdventureDev.has_flag("--dev-relic-held"):
		held = "relic_01"
	if held != "":
		run.relic_id = held
		run.reserve.clear()
		var sets: Array[Dictionary] = AdventureRelic.draw_sets(run, Session.library, AdventureDev.DEV_SEED, 1)
		if not sets.is_empty():
			run.reserve.assign(sets[0]["cards"])
		run.relic_offers.clear()


## `--dev-relic-hover=N` hovers the Nth offer, `--dev-relic-card=K` then previews its Kth small face,
## and `--dev-relic-take=N` takes the Nth offer. True when that opened the Reserve screen, which
## takes the screenshot instead.
func _dev_after_layout() -> bool:
	var hover_arg: String = AdventureDev.flag("--dev-relic-hover=")
	if hover_arg != "":
		await get_tree().process_frame
		_on_hover(int(hover_arg), true)
		var card_arg: String = AdventureDev.flag("--dev-relic-card=")
		if card_arg != "":
			await get_tree().create_timer(0.2).timeout
			await _on_card_hover(int(hover_arg), int(card_arg), true)
	var take_arg: String = AdventureDev.flag("--dev-relic-take=")
	if take_arg != "":
		_on_take(int(take_arg))
		return Session.run.status == AdventureRelic.STATUS_TRIM and not AdventureDev.has_flag("--dev-relic-stay")
	return false
