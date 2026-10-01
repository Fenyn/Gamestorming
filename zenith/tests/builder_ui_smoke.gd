extends SceneTree
## Windowed check of the deck builder screen against the shipped cards: the Duelist and Mastery
## picks narrow the library, adds and removals reach the deck, undo and redo walk them back, drags
## move cards, and everything stays on screen. Saves go to a scratch folder.
## Run with --path zenith -s tests/builder_ui_smoke.gd --resolution 1600x900.

const SCRATCH: String = "user://builder_ui_smoke"

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	# A script error stops `_run` without quitting, which would leave the window open forever.
	create_timer(90.0).timeout.connect(func() -> void:
		push_error("Builder UI smoke timed out: a check stopped the run")
		quit(1))
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error(message)


func _shown(screen: Control) -> Array[String]:
	var out: Array[String] = []
	for tile: BuilderCard in screen.get("_tiles"):
		if tile.visible:
			out.append(tile.card_id)
	return out


func _run() -> void:
	CustomDecks.dir_override = SCRATCH
	for deck: DeckList in CustomDecks.load_all():
		CustomDecks.delete(deck.id)
	CustomDecks.clear_draft()
	var lib: CardLibrary = root.get_node("Session").get("library")
	var screen: Control = load("res://scenes/builder/deck_builder.tscn").instantiate()
	root.add_child(screen)
	await create_timer(0.4).timeout
	_check((screen.get("shelf") as Control).visible, "The builder opens on Your decks")
	await screen.call("_on_new")
	await process_frame
	var picker: Control = screen.get("duelist_picker")
	_check(picker.visible and (screen.get("editor") as Control).visible, "New deck opens the editor on the Duelist picker")
	var everything: int = _shown(screen).size()

	screen.call("_pick_character", "Caedan Vale")
	screen.call("_on_choose_duelist")
	await process_frame
	var draft: DeckDraft = screen.get("draft")
	_check(draft.duelist() != null and draft.duelist().character == "Caedan Vale" and draft.deck.duelist_ids.size() == 5,
		"Choosing a Duelist fills the stack")
	_check(screen.get("mastery_picker").visible, "and opens the Mastery picker while none is set")
	var shown: Array[String] = _shown(screen)
	_check(shown.size() < everything, "the library narrows once the Duelist is chosen")
	for id in shown:
		var def: CardDef = lib.defs[id]
		_check(str(def.only.get("bloodline", "")) != "verdant", "a Verdant-only card hides behind a Draconic Duelist: %s" % id)
		_check(def.alignment_only != "pact", "a Pact-only card hides from a Vigil deck: %s" % id)
		_check(not (def.type == CardDef.Type.PERSONALITY and def.character == "Caedan Vale"), "the Duelist's own cards stay in the slots")

	var mastery: String = ""
	for id in draft.mastery_options():
		if (lib.defs[id] as CardDef).school == "storm":
			mastery = id
	_check(mastery != "", "a Storm Mastery is on offer")
	draft.set_mastery(mastery)
	screen.call("_after_edit")
	screen.get("mastery_picker").visible = false
	for id in _shown(screen):
		var school: String = (lib.defs[id] as CardDef).school
		_check(school == "" or school == "storm", "a Storm Mastery hides the other schools: %s" % id)

	var strike: String = ""
	for id in _shown(screen):
		var def: CardDef = lib.defs[id]
		if def.type == CardDef.Type.STRIKE and def.school == "storm" and draft.limit(id) >= 3:
			strike = id
			break
	screen.call("_on_tile", MOUSE_BUTTON_LEFT, false, strike)
	screen.call("_on_tile", MOUSE_BUTTON_LEFT, false, strike)
	_check(draft.deck.cards.count(strike) == 2, "two clicks add two copies")
	screen.call("_on_tile", MOUSE_BUTTON_RIGHT, false, strike)
	_check(draft.deck.cards.count(strike) == 1, "a right-click takes one out")
	screen.call("_on_undo")
	draft = screen.get("draft")
	_check(draft.deck.cards.count(strike) == 2, "undo puts it back")
	screen.call("_on_redo")
	draft = screen.get("draft")
	_check(draft.deck.cards.count(strike) == 1, "redo takes it out again")
	screen.call("_drop", Vector2.ZERO, {"builder": true, "from": "pool", "id": strike}, "life")
	draft = screen.get("draft")
	_check(draft.deck.cards.count(strike) == 2, "a drag from the library adds a copy")
	screen.call("_drop", Vector2.ZERO, {"builder": true, "from": "life", "id": strike}, "pool")
	draft = screen.get("draft")
	_check(draft.deck.cards.count(strike) == 1, "a drag back to the library takes one out")
	var strips: Dictionary = screen.get("_strips")
	_check(strips.has("life:" + strike), "the deck list has a strip for the card")
	var tile: BuilderCard = (screen.get("_tile_of") as Dictionary)[strike]
	_check(tile.count_chip.visible and tile.count_chip.text == "1/%d" % draft.limit(strike), "the library tile counts the copy against its limit")

	screen.call("_open_aspect_popup", 5)
	await process_frame
	_check((screen.get("aspect_overlay") as Control).visible, "an Aspect slot opens its printings")
	screen.call("_on_aspect_remove")
	draft = screen.get("draft")
	_check(draft.deck.duelist_ids.size() == 4, "taking the top Aspect out shortens the stack")
	_check(not (screen.get("aspect_overlay") as Control).visible, "and closes once it acts")

	var body: Control = screen.get_node("Editor/Column/Body")
	_check(root.get_visible_rect().encloses(body.get_global_rect().grow(-1)), "the builder fits the screen")
	var deck_panel: Control = screen.get("deck_panel")
	_check(deck_panel.size.x <= 720, "the deck column keeps its width (%d)" % int(deck_panel.size.x))

	_check(CustomDecks.load_draft() != null and (screen.get("unsaved_chip") as Label).visible, "edits keep a draft and show the deck as unsaved")
	var code: String = CustomDecks.to_code(draft.deck)
	var round_trip: ImportResult = DeckImport.read(code, lib, SourceIndex.shipped())
	_check(round_trip.deck.cards == draft.deck.cards and round_trip.deck.duelist_ids == draft.deck.duelist_ids, "a deck code reads back as the same deck")
	screen.get("name_edit").text = "Smoke Test Deck"
	screen.get("name_edit").text_changed.emit("Smoke Test Deck")
	_check(screen.call("_on_save"), "saving succeeds")
	_check(CustomDecks.load_all().size() == 1, "saving writes the deck")
	_check(CustomDecks.load_draft() == null and not (screen.get("unsaved_chip") as Label).visible, "and clears the draft")
	screen.call("_show_shelf")
	var tiles: int = (screen.get("mine_grid") as GridContainer).get_child_count()
	_check(tiles == 2, "Your decks lists the New deck tile and the saved deck")
	for deck: DeckList in CustomDecks.load_all():
		CustomDecks.delete(deck.id)
	CustomDecks.dir_override = ""
	print("Builder UI smoke: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)
