extends SceneTree
## Deck builder and importer: the name index, both list formats, the draft's rules and saving.
##   godot --headless --path zenith -s tests/deckbuild_tests.gd

const FIXTURE_INDEX: String = "res://tests/fixtures/source_index.json"
const SCRATCH: String = "user://deckbuild_test"

## The community decklist form's layout, with fixture names.
const FORM_CSV: String = """,Decklist Form,,,,,,,,,
,Player Name:,Tester,,,Deck Total,61,,,,
,Deck Code:,none,,,Card Name,Qty,Card Name,Qty,Card Name,Qty
,,,,,--- Battleground ---,,--- Event ---,,,
,Mastery,Test Ember Style Mastery,,,Test Jab,3,Test Heavy Jab,2,,
,MP Level 1,"Test Hero, the Brave",,,Test Orb 1,1,,,,
,MP Level 2,"Test Hero, the Bold",,,Test Orb 2,1,,,,
,MP Level 3,"Test Hero, the Bold",,,Test Nowhere Card,2,,,,
,Sensei,Test Old Teacher,,,"Test Page, the Squire",1,,,,
,Subtotal:,,,5,Test Ember Kick,3,,,,
,Sensei Deck,Sensei Total:,,1,,,,,,
,,Test Ransom,,1,,,,,,
"""

const O8D: String = """<?xml version="1.0" encoding="utf-8" standalone="yes"?>
<deck game="fixture">
  <section name="Starting" shared="False">
    <card qty="1" id="a">Test Ember Style Mastery (Test Set B)</card>
    <card qty="1" id="b">Test Hero, the Brave</card>
    <card qty="1" id="c">Test Hero, the Bold - Lv 3</card>
    <card qty="1" id="d">Test Hero, the Bold - Lv 2</card>
    <card qty="1" id="e">Test Old Teacher</card>
  </section>
  <section name="Sensei Deck" shared="False">
    <card qty="1" id="f" name="Test Ransom" />
  </section>
  <section name="Life Deck" shared="False">
    <card qty="3" id="g">Test Jab</card>
    <card qty="2" id="h">Test Wave Parry</card>
    <card qty="1" id="i">Test Page &amp; Co</card>
  </section>
</deck>
"""

var checks: int = 0
var failures: int = 0
var library: CardLibrary = CardLibrary.new()
var index: SourceIndex


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	library.load_dir("res://tests/fixtures/cards")
	index = SourceIndex.load_from(FIXTURE_INDEX)
	_test_normalise_matches_the_generator()
	_test_csv_rows()
	_test_form_csv()
	_test_set_hint_and_plain_lists()
	_test_o8d()
	_test_own_format()
	_test_draft_rules()
	_test_usable_filter()
	_test_duelist_lines()
	_test_save_and_load()
	_test_shipped_index()
	_test_wire_decks()
	_test_online_custom_picks()
	print("Deck builder: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _eq(got: Variant, want: Variant, message: String) -> void:
	_check(got == want, "%s: got %s, want %s" % [message, str(got), str(want)])


func _line(result: ImportResult, text: String) -> ImportLine:
	for line in result.lines:
		if line.text == text:
			return line
	return null


## Digests computed by tools/gen_source_index.py; the two normalisers must agree.
func _test_normalise_matches_the_generator() -> void:
	_eq(SourceIndex.digest("Test Bolt"), "ac789390ff3dd05df930395e96f49478b3982c194e7003535c60cc77634adc2f", "digest of a plain name")
	_eq(SourceIndex.digest("TEST bolt"), SourceIndex.digest("Test Bolt"), "case does not count")
	_eq(SourceIndex.digest("Tester's  Grand-Bolt!"), "81e2440af7a71826fec2a08c6ba56a6a40dc63800fdcb14fc7bb15e254d908c5", "apostrophes drop, punctuation is a space")
	_eq(SourceIndex.set_hint("Lv 2, Test Set 140"), "test set", "a set hint loses its level and print number")
	_eq(SourceIndex.set_hint("Lv 2, Test Set 140").sha256_text(), "0604209f3e77679a0cf41bf35ce6371ef4d1e56f487d30e974a694de0803e9bb", "set hint digest")
	_eq(SourceIndex.level_in("Lv 3"), 3, "level from a bracket")
	_eq(SourceIndex.level_in("Level 2"), 2, "level spelled out")


func _test_csv_rows() -> void:
	var rows: Array[PackedStringArray] = DeckImport.csv_rows("a,\"b, c\",\"say \"\"hi\"\"\"\r\n1,2\n")
	_eq(rows.size(), 2, "two rows across CRLF and LF")
	_eq(rows[0][1], "b, c", "a quoted cell keeps its comma")
	_eq(rows[0][2], "say \"hi\"", "doubled quotes read as one")


func _test_form_csv() -> void:
	var result: ImportResult = DeckImport.read(FORM_CSV, library, index)
	var deck: DeckList = result.deck
	_eq(result.error, "", "the form reads as a deck list")
	_eq(deck.duelist_ids, ["tf_vigil_1", "tf_vigil_2", "tf_vigil_3"] as Array[String], "MP Level rows fill the stack, level settling a shared name")
	_eq(deck.relic_id, "t_relic", "the Sensei row is the Relic")
	_eq(deck.reserve, ["t_ransom"] as Array[String], "the Sensei Deck block is the Reserve")
	_eq(deck.cards.count("t_strike"), 3, "a name and quantity pair")
	_eq(deck.cards.count("t_pyre_jab"), 3, "a pair after a label keeps its own count")
	_eq(deck.cards.count("t_seal_2"), 1, "a shared Seal name follows the set the other Seals agree on")
	_eq(deck.cards.count("t_seal_guard"), 0, "the other set's Seal stays out")
	_eq(deck.cards.count("t_ally_squire"), 1, "a personality among the cards is an Ally")
	_eq(deck.cards.size(), 11, "no label value is read as a card")
	var mastery: ImportLine = _line(result, "Test Ember Style Mastery")
	_check(mastery != null and mastery.status == ImportLine.CHOOSE and mastery.options.size() == 3,
		"a Mastery name with three printings asks the player")
	_eq(deck.mastery_id, "", "the Mastery is not guessed")
	_eq(deck.style, "pyre", "the printings' shared school sets the Style")
	var missing: Array[ImportLine] = result.missing()
	_check(missing.size() == 1 and missing[0].text == "Test Nowhere Card" and missing[0].qty == 2 and missing[0].row == 8,
		"an unmatched line comes back with its quantity and row")
	var draft: DeckDraft = DeckDraft.new()
	draft.library = library
	draft.deck = deck
	_check(draft.choose(mastery, "t_mastery_flare"), "the player settles the Mastery")
	_eq(deck.mastery_id, "t_mastery_flare", "the picked printing is the Mastery")
	_eq(result.choices().size(), 0, "nothing is left to choose")
	var tabbed: ImportResult = DeckImport.read(FORM_CSV.replace(",", "\t"), library, index)
	_eq(tabbed.deck.cards.size(), 11, "a tab-separated paste reads the same")


func _test_set_hint_and_plain_lists() -> void:
	var result: ImportResult = DeckImport.read("Test Ember Style Mastery (Test Set B 140)\n3x Test Jab\nTest Heavy Jab,2\n2,Test Ember Kick\nTest Hero, the Brave\n", library, index)
	_eq(result.deck.mastery_id, "t_mastery_flare", "a set hint picks the printing")
	_eq(result.deck.cards.count("t_strike"), 3, "3x Name")
	_eq(result.deck.cards.count("t_strike_plus2"), 2, "Name,qty")
	_eq(result.deck.cards.count("t_pyre_jab"), 2, "qty,Name")
	_eq(result.deck.duelist_ids, ["tf_vigil_1"] as Array[String], "a plain list's personality becomes the Duelist")


func _test_o8d() -> void:
	var result: ImportResult = DeckImport.read(O8D, library, index)
	var deck: DeckList = result.deck
	_eq(deck.mastery_id, "t_mastery_flare", "the Starting section's Mastery, settled by its set")
	_eq(deck.duelist_ids, ["tf_vigil_1", "tf_vigil_2", "tf_vigil_3"] as Array[String], "levels from name suffixes, sorted")
	_eq(deck.relic_id, "t_relic", "the Starting section's Relic")
	_eq(deck.reserve, ["t_ransom"] as Array[String], "a self-closing card with a name attribute")
	_eq(deck.cards.count("t_strike"), 3, "Life Deck section quantities")
	_eq(deck.cards.count("t_copy_parry"), 2, "an off-school card still comes in")
	var off_school: bool = false
	for problem in DeckValidator.validate(deck, library):
		off_school = off_school or problem.contains("t_copy_parry")
	_check(off_school, "and the validator names it")
	var missing: ImportLine = _line(result, "Test Page & Co")
	_check(missing != null and missing.status == ImportLine.MISSING, "entities are decoded before matching")


func _test_draft_rules() -> void:
	var draft: DeckDraft = DeckDraft.blank(library)
	_check(draft.add("tf_vigil_1"), "the first personality starts the Duelist")
	_check(draft.add("tf_vigil_2"), "the Duelist's character joins the stack")
	_check(draft.add_block("tf_vigil_2") != "", "one card per Aspect")
	_check(draft.add("t_ally_squire"), "another character is an Ally")
	_check(draft.add_block("t_ally_squire_4") != "", "an Ally of Aspect 4 is refused")
	_eq(draft.deck.cards.count("t_ally_squire"), 1, "the Ally is in the Life Deck")
	_check(draft.add_block("t_pyre_jab") != "", "a school card needs that school's Mastery")
	_check(draft.add("t_mastery_pyre"), "a Mastery fills its slot")
	_eq(draft.deck.style, "pyre", "and sets the Style")
	for i in range(3):
		draft.add("t_pyre_jab")
	_eq(draft.copies("t_pyre_jab"), 3, "three copies")
	_check(draft.add_block("t_pyre_jab") != "", "a fourth is over the limit")
	_check(draft.add_block("t_copy_parry") != "", "another school's card is refused")
	_check(not draft.fits(library.defs["t_copy_parry"]), "and hidden from the library")
	_check(draft.add_block("t_strike", true) != "", "a Reserve needs a Relic")
	_check(draft.add("t_relic"), "a Relic fills its slot")
	_check(draft.add("t_strike", true), "then the Reserve takes cards")
	_check(draft.add("t_ransom"), "a Reserve-only card")
	_eq(draft.deck.reserve, ["t_strike", "t_ransom"] as Array[String], "goes to the Reserve by itself")
	_eq(draft.deck.mastery_id, "t_mastery_pyre", "")
	_check(draft.add("t_mastery_tide"), "a second Mastery replaces the first")
	_eq(draft.deck.style, "tide", "and the Style follows it")
	_check(draft.side_is_open() and draft.set_alignment("pact"), "a Duelist that serves either side lets the player pick")
	_check(draft.remove("t_ally_squire"), "removing a Life Deck card")
	_check(draft.remove("tf_vigil_2"), "removing a stack card")
	_eq(draft.deck.duelist_ids, ["tf_vigil_1"] as Array[String], "the stack shrinks")
	var pinned: DeckDraft = DeckDraft.blank(library)
	pinned.add("t_climber_1")
	pinned.add("t_climber_2_ashen")
	pinned.add("t_climber_3_cinder")
	_check(not pinned.side_is_open() and pinned.deck.alignment == "pact", "a one-sided Duelist sets the side")
	_check(not pinned.set_alignment("vigil"), "and the player cannot change it")


## The library narrows as the Duelist, Mastery, Allies and Seals are chosen.
func _test_usable_filter() -> void:
	var draft: DeckDraft = DeckDraft.blank(library)
	for id in ["t_kin_rite", "t_gated_blow", "t_oath", "t_pyre_jab", "t_copy_parry"]:
		_check(draft.fits(library.defs[id]), "before any choice %s shows" % id)
	draft.choose_duelist("Test Vigil")
	_check(not draft.fits(library.defs["t_kin_rite"]), "a Draconic-only card hides behind a Duelist who is not Draconic")
	_check(draft.use_block(library.defs["t_kin_rite"]).contains("Draconic"), "and says why")
	_check(not draft.fits(library.defs["t_gated_blow"]), "a Marked-only card hides too")
	_check(not draft.fits(library.defs["t_oath"]), "and a card only one character can use")
	draft.add("t_ally_kin")
	_check(draft.fits(library.defs["t_kin_rite"]), "a Draconic Ally brings the Draconic-only card back")
	draft.add("t_ally_squire")
	_check(draft.fits(library.defs["t_oath"]), "fielding the named character brings its card back")
	_check(draft.fits(library.defs["t_pyre_jab"]) and draft.fits(library.defs["t_copy_parry"]), "every school shows until a Mastery is picked")
	draft.add("t_mastery_pyre")
	_check(draft.fits(library.defs["t_pyre_jab"]) and not draft.fits(library.defs["t_copy_parry"]), "a Mastery hides the other schools")
	draft.add("t_seal_1")
	_check(draft.fits(library.defs["t_seal_2"]) and not draft.fits(library.defs["t_seal_guard"]), "one Seal hides the other sets")
	_check(draft.fits(library.defs["t_sided_ward"]) == false, "an any-of gate stays shut when no branch can open")
	draft.choose_duelist("Test Dragonblood")
	_check(draft.fits(library.defs["t_sided_ward"]), "and opens when one branch can")
	var signed: CardDef = CardDef.from_dict({"id": "t_signed_gate", "title": "Test Signed Gate", "type": "combat",
		"character": "Test Squire", "only": {"character": "Test Squire", "bloodline": "verdant"}})
	_check(draft.use_block(signed) != "" and draft.fits(signed), "a Signature card shows while legal, whoever it names")


func _test_duelist_lines() -> void:
	var characters: Array[String] = DeckDraft.duelist_characters(library)
	_check(characters.has("Test Two-Faced") and characters.has("Test Vigil") and not characters.has("Test Kin"),
		"characters with Aspects 1 to 3 can lead; an Ally line with gaps cannot")
	_eq(DeckDraft.lines_of(library, "Test Two-Faced"), ["the Long Road", "the Short Road"] as Array[String], "a character's printed lines")
	_eq(DeckDraft.stack_for(library, "Test Two-Faced", "the Long Road").size(), 5, "the long line stacks to Aspect 5")
	_eq(DeckDraft.stack_for(library, "Test Two-Faced", "the Short Road"),
		["tf_marked_short_1", "tf_marked_short_2", "tf_marked_short_3", "tf_marked_long_4", "tf_marked_long_5"] as Array[String],
		"a short line borrows the other line's higher Aspects")
	var draft: DeckDraft = DeckDraft.blank(library)
	draft.choose_duelist("Test Vigil")
	draft.add("t_ally_squire")
	var before: Dictionary = draft.snapshot()
	draft.choose_duelist("Test Squire")
	_check(draft.deck.cards.count("t_ally_squire") == 0, "an Ally of the new Duelist's character leaves the deck")
	draft.restore(before)
	_check(draft.deck.cards.has("t_ally_squire") and draft.duelist().character == "Test Vigil", "undo puts the deck back")
	draft.choose_duelist("Test Two-Faced", "the Long Road")
	_check(draft.set_aspect("tf_marked_short_2") and draft.deck.duelist_ids[1] == "tf_marked_short_2", "one Aspect swaps for another printing")
	_check(not draft.set_aspect("tf_vigil_2"), "another character's card does not")
	var picks: Array[String] = draft.mastery_options()
	_check(picks.has("t_mastery_pyre") and picks.has("t_mastery_drills"), "every school's Masteries are offered")


func _test_save_and_load() -> void:
	CustomDecks.dir_override = SCRATCH
	for deck: DeckList in CustomDecks.load_all():
		CustomDecks.delete(deck.id)
	var source: DeckList = DeckList.load_from("res://tests/fixtures/test_deck.json")
	var draft: DeckDraft = DeckDraft.of(source, library)
	_eq(draft.deck.id, "", "a copy of a precon is a new deck")
	draft.deck.name = "My Test Deck"
	var id: String = CustomDecks.save(draft.deck)
	_eq(id, "my_test_deck", "the file stem comes from the name")
	_eq(CustomDecks.save(DeckDraft.of(source, library).deck), "fixture_deck", "a second deck takes its own stem")
	var loaded: Array[DeckList] = CustomDecks.load_all()
	_eq(loaded.size(), 2, "both decks load back")
	var back: DeckList = null
	for deck in loaded:
		if deck.id == id:
			back = deck
	_check(back != null and back.custom and back.cards == source.cards and back.duelist_ids == source.duelist_ids
		and back.mastery_id == source.mastery_id, "a saved deck reads back card for card")
	_check(CustomDecks.delete(id) and CustomDecks.delete("fixture_deck"), "decks delete")
	_eq(CustomDecks.load_all().size(), 0, "and are gone")
	CustomDecks.dir_override = ""


func _test_own_format() -> void:
	var source: DeckList = DeckList.load_from("res://tests/fixtures/test_deck.json")
	var dict: Dictionary = source.to_dict()
	(dict["cards"] as Array).append({"id": "t_no_such_card", "count": 2})
	var result: ImportResult = DeckImport.read(JSON.stringify(dict), library, index)
	_eq(result.deck.cards, source.cards, "our own list reads back card for card, unknown ids left out")
	var missing: Array[ImportLine] = result.missing()
	_check(missing.size() == 1 and missing[0].text == "t_no_such_card" and missing[0].qty == 2, "and the unknown id is reported")


## Another player's list is rebuilt strictly and must be legal.
func _test_wire_decks() -> void:
	var legal: Dictionary = DeckList.load_from("res://tests/fixtures/test_deck.json").to_dict()
	_check(DeckValidator.validate(DeckList.from_dict(legal), library).is_empty(), "the fixture deck is legal")
	var back: DeckList = CustomDecks.from_wire(legal, library)
	_check(back != null and back.custom, "a legal list comes through as a custom deck")
	var bad: Array[Dictionary] = []
	for change: Array in [["cards", "x"], ["cards", [{"id": "t_strike", "count": 9}]], ["name", "x".repeat(80)],
			["duelist", [1, 2, 3]], ["cards", [{"id": "t_strike", "count": 1.5}]], ["cards", []]]:
		var d: Dictionary = legal.duplicate(true)
		d[change[0]] = change[1]
		bad.append(d)
	var refused: int = 0
	for d in bad:
		if CustomDecks.from_wire(d, library) == null:
			refused += 1
	_eq(refused, bad.size(), "malformed, oversized or illegal lists are refused")
	_check(CustomDecks.from_wire("not a deck", library) == null, "a non-dictionary is refused")


## Through the real Net and Session: a custom pick travels as its list, is checked, stays hidden
## from the other seat until both lock, and a custom deck's local index never passes as a pick.
func _test_online_custom_picks() -> void:
	var net: Node = root.get_node_or_null("Net")
	var session: Node = root.get_node_or_null("Session")
	if net == null or session == null:
		_check(false, "the Net and Session autoloads are present")
		return
	var decks: Array[DeckList] = session.get("decks")
	var lib: CardLibrary = session.get("library")
	var custom: DeckList = DeckDraft.of(decks[0], lib).deck
	custom.name = "Wire Test"
	var list: Dictionary = custom.to_dict()
	net.set("mode", "host")
	net.set("peer_id", 42)
	net.call("reset_lobby")
	net.call("_apply_pick", 0, 0, decks[0].name, "Host", true, {})
	net.call("_apply_pick", 1, DuelRoom.CUSTOM_PICK, "Other name", "Remote", true, list)
	_check(not bool(net.call("both_locked")), "a custom list under another name is refused")
	var short: Dictionary = list.duplicate(true)
	short["cards"] = []
	net.call("_apply_pick", 1, DuelRoom.CUSTOM_PICK, "Wire Test", "Remote", true, short)
	_check(not bool(net.call("both_locked")), "an illegal custom list is refused")
	net.call("_apply_pick", 1, DuelRoom.CUSTOM_PICK, "Wire Test", "Remote", true, list)
	_check(bool(net.call("both_locked")), "a legal custom list locks the seat")
	var lobby: Array[Dictionary] = net.get("lobby")
	var picked: DeckList = net.call("pick_deck", lobby[1])
	_check(picked != null and picked.custom and picked.cards == custom.cards, "the seat plays the list it sent")
	var hidden: Array[Dictionary] = net.call("lobby_for", lobby, 0, false)
	_check(int(hidden[1]["deck"]) == -1 and (hidden[1]["list"] as Dictionary).is_empty(), "the other seat's list stays hidden until both lock")
	var shown: Array[Dictionary] = net.call("lobby_for", lobby, 0, true)
	_eq(shown[1]["list"], list, "and is shown once both have")
	decks.append(custom)
	var at: int = decks.size() - 1
	_check(not bool(net.call("valid_deck_pick", at, custom.name)), "a custom deck's local index is never a catalog pick")
	net.set("local_player", 0)
	net.call("set_local_pick", at, "Host", true)
	lobby = net.get("lobby")
	_check(int(lobby[0]["deck"]) == DuelRoom.CUSTOM_PICK and int(net.call("local_deck_index")) == at,
		"the local seat sends its custom deck as a list and remembers its own index")
	decks.remove_at(at)
	net.call("reset_lobby")
	net.set("mode", "")
	net.set("peer_id", 0)


## The shipped index points only at shipped cards, and holds no readable names.
func _test_shipped_index() -> void:
	var shipped_cards: CardLibrary = CardLibrary.new()
	shipped_cards.load_dir("res://data/cards")
	var shipped: SourceIndex = SourceIndex.shipped()
	_check(shipped.names.size() > 500, "the shipped index loads")
	var hex: RegEx = RegEx.create_from_string("^[0-9a-f]{64}$")
	var bad: Array[String] = []
	for key: String in shipped.names.keys():
		if hex.search(key) == null:
			bad.append(key)
		for entry: Dictionary in shipped.names[key]:
			if not shipped_cards.defs.has(str(entry.get("id", ""))):
				bad.append(str(entry.get("id", "")))
	_eq(bad, [] as Array[String], "every key is a digest and every id a shipped card")
