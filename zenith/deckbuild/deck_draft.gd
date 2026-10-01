class_name DeckDraft
extends RefCounted
## A deck being built: every edit the builder screen makes, and why one is refused. The deck may be
## illegal while it is built; `problems()` is DeckValidator's list, and only a legal deck is offered
## for play. The copy limits mirror DeckValidator's.

var deck: DeckList
var library: CardLibrary


static func blank(lib: CardLibrary) -> DeckDraft:
	var draft: DeckDraft = DeckDraft.new()
	draft.library = lib
	draft.deck = DeckList.new()
	draft.deck.name = "New deck"
	draft.deck.style = "freestyle"
	draft.deck.custom = true
	return draft


## A draft over a copy of `source`, so an unsaved edit never reaches a loaded deck.
static func of(source: DeckList, lib: CardLibrary) -> DeckDraft:
	var draft: DeckDraft = DeckDraft.new()
	draft.library = lib
	draft.deck = DeckList.from_dict(source.to_dict())
	draft.deck.id = source.id if source.custom else ""
	draft.deck.custom = true
	draft.deck.mode = "tournament"
	draft.deck.ai_profile = ""
	draft.deck.cleared = 0.0
	# A precon's labels describe the precon; a player's copy is free to become something else.
	if not source.custom:
		draft.deck.archetype = ""
		draft.deck.subthemes.clear()
		draft.deck.difficulty = ""
		draft.deck.tagline = ""
		draft.deck.blurb = ""
	return draft


func problems() -> Array[String]:
	return DeckValidator.validate(deck, library)


## The validator's problems with each quoted card id swapped for the card's title.
func readable_problems() -> Array[String]:
	var out: Array[String] = []
	for problem in problems():
		var text: String = problem
		for found: RegExMatch in _quoted.search_all(problem):
			var def: CardDef = library.defs.get(found.get_string(1))
			if def != null:
				text = text.replace(found.get_string(0), def.title)
		out.append(text)
	return out


## Every card id a validator problem names, as a set, so the deck list can mark those cards.
func problem_ids() -> Dictionary:
	var out: Dictionary = {}
	for problem in problems():
		for found: RegExMatch in _quoted.search_all(problem):
			out[found.get_string(1)] = true
	return out


static var _quoted: RegEx = RegEx.create_from_string("'([a-z0-9_]+)'")


func legal() -> bool:
	return problems().is_empty()


func total() -> int:
	return deck.total_cards()


func max_cards() -> int:
	return DeckValidator.MAX_CARDS_ROOT if deck.style == "root" else DeckValidator.MAX_CARDS


func duelist() -> CardDef:
	return library.defs.get(deck.duelist_face_id())


## Copies of `id` anywhere in the deck: Life Deck, Reserve, the Duelist stack and the two frame slots.
func copies(id: String) -> int:
	var n: int = deck.cards.count(id) + deck.reserve.count(id) + deck.duelist_ids.count(id)
	if deck.mastery_id == id:
		n += 1
	if deck.relic_id == id:
		n += 1
	return n


func limit(id: String) -> int:
	var def: CardDef = library.defs.get(id)
	if def == null:
		return 0
	if def.type in [CardDef.Type.SEAL, CardDef.Type.PERSONALITY, CardDef.Type.MASTERY, CardDef.Type.RELIC]:
		return 1
	var head: CardDef = duelist()
	if head != null and def.character != "" and def.character == head.character \
			and def.limit_per_deck >= DeckValidator.DEFAULT_LIMIT:
		return DeckValidator.SIGNATURE_LIMIT
	return def.limit_per_deck


## Why `id` allows other than DeckValidator.DEFAULT_LIMIT copies, "" when it allows exactly that.
func limit_reason(id: String) -> String:
	var def: CardDef = library.defs.get(id)
	var n: int = limit(id)
	if def == null or n == DeckValidator.DEFAULT_LIMIT:
		return ""
	match def.type:
		CardDef.Type.PERSONALITY:
			return "Limit 1: one copy of each personality"
		CardDef.Type.SEAL:
			return "Limit 1: one of each Seal"
		CardDef.Type.MASTERY, CardDef.Type.RELIC:
			return "Limit 1"
	if n == DeckValidator.SIGNATURE_LIMIT:
		return "Limit %d: it names your Duelist" % n
	return "Limit %d, printed on the card" % n


## Whether the library should show `def` for this deck: legal outside adventure, in the deck's
## Style, on its side, in its Seal set, and, unless it is a Signature card, usable by somebody the
## deck fields (`use_block`).
## Cards already at their limit still show. Before a Duelist is picked only bans and schools
## narrow it.
func fits(def: CardDef) -> bool:
	return fit_block(def) == ""


## Why the library hides `def` for this deck, "" when it shows.
func fit_block(def: CardDef) -> String:
	var why: String = legal_block(def)
	if why != "":
		return why
	# A Signature card shows whenever the deck may legally run it, whoever it names (user ruling
	# 2026-10-01); the use gates narrow only the rest.
	if def.is_signature():
		return ""
	return use_block(def)


## Why this deck may not run `def` at all under its Duelist, Mastery, side and Seal set; "" when
## it may. Copy limits and deck size are `add_block`'s business.
func legal_block(def: CardDef) -> String:
	if bool(def.raw.get("banned", false)):
		return "Banned outside adventure mode."
	var head: CardDef = duelist()
	match def.type:
		CardDef.Type.RELIC:
			return ""
		CardDef.Type.MASTERY:
			var needs: String = str(def.raw.get("duelist_bloodline", ""))
			if head != null and needs != "" and head.bloodline != needs:
				return "This Mastery needs a %s Duelist." % CardText.bloodline_name(needs)
			return ""
		CardDef.Type.PERSONALITY:
			if head != null and def.character == head.character:
				return ""
			if head != null and not DeckValidator.ally_aspect_allowed(def.aspect):
				return "An Ally may be Aspect 1 to %d." % DeckValidator.MAX_ALLY_ASPECT
		CardDef.Type.SEAL:
			var held: String = seal_set()
			if held != "" and def.seal_set != held:
				return "A deck runs one Seal set."
	if def.school != "" and deck.mastery_id != "" and def.school != deck.style:
		return "A %s card, and this deck is %s." % [CardText.school_name(def.school), CardText.school_name(deck.style)]
	if head != null and not CardDef.side_allows(deck.alignment, def.alignment_only):
		return "For %s decks only." % def.alignment_only.capitalize()
	return ""


## Two or three words for a library tile on why the deck cannot run or use `def`, "" when it can.
func fit_tag(def: CardDef) -> String:
	if fit_block(def) == "":
		return ""
	if bool(def.raw.get("banned", false)):
		return "Banned"
	var head: CardDef = duelist()
	if def.type == CardDef.Type.MASTERY:
		return "Needs %s Duelist" % CardText.bloodline_name(str(def.raw.get("duelist_bloodline", "")))
	if def.type == CardDef.Type.PERSONALITY and head != null and def.aspect > DeckValidator.MAX_ALLY_ASPECT:
		return "Allies stop at %d" % DeckValidator.MAX_ALLY_ASPECT
	if def.type == CardDef.Type.SEAL and seal_set() != "" and def.seal_set != seal_set():
		return "One Seal set"
	if def.school != "" and deck.mastery_id != "" and def.school != deck.style:
		return "%s school" % CardText.school_name(def.school)
	if head != null and not CardDef.side_allows(deck.alignment, def.alignment_only):
		return "%s only" % def.alignment_only.capitalize()
	var gate: Dictionary = def.only
	if gate.has("bloodline"):
		return "%s only" % CardText.bloodline_name(str(gate["bloodline"]))
	if gate.has("tag"):
		return "%s only" % CardText.keyword_name(str(gate["tag"]))
	if gate.has("duelist_character") or gate.has("character"):
		return "%s only" % str(gate.get("duelist_character", gate.get("character", ""))).get_slice(" ", 0)
	return "Not usable"


## Takes out every Life Deck and Reserve card this deck may not run, and the copies over a card's
## limit. Returns how many cards left.
func remove_illegal() -> int:
	var before: int = deck.cards.size() + deck.reserve.size()
	var seen: Dictionary = {}   # copies kept so far, the Life Deck counted before the Reserve
	deck.cards.assign(_kept(deck.cards, seen))
	deck.reserve.assign(_kept(deck.reserve, seen))
	return before - deck.cards.size() - deck.reserve.size()


func _kept(pile: Array[String], seen: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for id in pile:
		var def: CardDef = library.defs.get(id)
		var count: int = int(seen.get(id, 0)) + 1
		if def == null or legal_block(def) != "" or count > limit(id):
			continue
		seen[id] = count
		out.append(id)
	return out


## How many Life Deck and Reserve cards a switch to Mastery `id` would leave illegal.
func illegal_after_mastery(id: String) -> int:
	var probe: DeckDraft = DeckDraft.new()
	probe.library = library
	probe.deck = DeckList.from_dict(deck.to_dict())
	probe.set_mastery(id)
	var n: int = 0
	for card in probe.deck.cards + probe.deck.reserve:
		var def: CardDef = library.defs.get(card)
		if def != null and probe.legal_block(def) != "":
			n += 1
	return n


## The Seal set the deck already runs, "" for none.
func seal_set() -> String:
	for id in deck.cards + deck.reserve:
		var def: CardDef = library.defs.get(id)
		if def != null and def.type == CardDef.Type.SEAL:
			return def.seal_set
	return ""


## The personalities the deck fields: the Duelist's Aspects and every Ally in the Life Deck and
## Reserve. A card gated to a bloodline, keyword or character is usable when one of them qualifies,
## since the gate reads whoever is in control.
func fielded() -> Array[CardDef]:
	var out: Array[CardDef] = []
	for id in deck.duelist_ids + deck.cards + deck.reserve:
		var def: CardDef = library.defs.get(id)
		if def != null and def.type == CardDef.Type.PERSONALITY and not out.has(def):
			out.append(def)
	return out


## Why nobody this deck fields could ever use `def`, "" when somebody can. Nothing is ruled out
## before a Duelist is picked.
func use_block(def: CardDef) -> String:
	if def.only.is_empty() or deck.duelist_ids.is_empty():
		return ""
	return _gate_block(def.only, fielded())


## The first part of a play gate nobody in `people` can meet, "" when the gate can open. Only the
## parts fixed by the deck are read; conditions on the state of a duel (`when`, `allies_min`,
## Energy) can always come true.
func _gate_block(gate: Dictionary, people: Array[CardDef]) -> String:
	if gate.has("any_of"):
		var first: String = ""
		for sub: Variant in gate["any_of"]:
			var why: String = _gate_block(sub as Dictionary, people)
			if why == "":
				return ""
			if first == "":
				first = why
		return first
	if gate.has("alignment") and not CardDef.side_allows(deck.alignment, str(gate["alignment"])):
		return "For %s decks only." % str(gate["alignment"]).capitalize()
	var head: CardDef = duelist()
	if gate.has("duelist_character") and (head == null or head.character != str(gate["duelist_character"])):
		return "Only %s can use this, as the Duelist." % str(gate["duelist_character"])
	if gate.has("character") and not people.any(func(p: CardDef) -> bool: return p.character == str(gate["character"])):
		return "Only %s can use this, and the deck does not field them." % str(gate["character"])
	if gate.has("bloodline") and not people.any(func(p: CardDef) -> bool: return p.bloodline == str(gate["bloodline"])):
		return "Only a %s personality can use this, and the deck fields none." % CardText.bloodline_name(str(gate["bloodline"]))
	if gate.has("tag") and not people.any(func(p: CardDef) -> bool: return (p.raw.get("tags", []) as Array).has(str(gate["tag"]))):
		return "Only a %s personality can use this, and the deck fields none." % CardText.keyword_name(str(gate["tag"]))
	return ""


# --- The Duelist and the Mastery ------------------------------------------------------------------

## Characters that can lead a deck: Aspects 1 to DeckValidator.MIN_ASPECTS all printed.
static func duelist_characters(lib: CardLibrary) -> Array[String]:
	var levels: Dictionary = {}
	for def: CardDef in lib.defs.values():
		if def.type == CardDef.Type.PERSONALITY and not bool(def.raw.get("banned", false)):
			if not levels.has(def.character):
				levels[def.character] = {}
			(levels[def.character] as Dictionary)[def.aspect] = true
	var out: Array[String] = []
	for character: String in levels.keys():
		var ok: bool = true
		for n in range(1, DeckValidator.MIN_ASPECTS + 1):
			ok = ok and (levels[character] as Dictionary).has(n)
		if ok:
			out.append(character)
	out.sort()
	return out


## The printed lines of a character ("" for cards that name none), each with at least one card.
static func lines_of(lib: CardLibrary, character: String) -> Array[String]:
	var out: Array[String] = []
	for def: CardDef in lib.defs.values():
		if def.type == CardDef.Type.PERSONALITY and def.character == character and def.variant != "" and not out.has(def.variant):
			out.append(def.variant)
	out.sort()
	return out


## The line that prints the most of its own Aspects, the first such by name; "" for none.
static func main_line(lib: CardLibrary, character: String) -> String:
	var best: String = ""
	var most: int = 0
	for line in lines_of(lib, character):
		var own: int = 0
		for id in stack_for(lib, character, line):
			if (lib.defs[id] as CardDef).variant == line:
				own += 1
		if own > most:
			best = line
			most = own
	return best


## Every card of `character` at Aspect `aspect`, the line's own first, then unlined, titled first.
static func aspect_options(lib: CardLibrary, character: String, aspect: int, line: String = "") -> Array[String]:
	var cards: Array[CardDef] = []
	for def: CardDef in lib.defs.values():
		if def.type == CardDef.Type.PERSONALITY and def.character == character and def.aspect == aspect \
				and not bool(def.raw.get("banned", false)):
			cards.append(def)
	var rank: Callable = func(d: CardDef) -> int:
		return (0 if d.variant == line else (1 if d.variant == "" else 2)) * 2 + (0 if d.aspect_title != "" else 1)
	cards.sort_custom(func(a: CardDef, b: CardDef) -> bool:
		return int(rank.call(a)) < int(rank.call(b)) if int(rank.call(a)) != int(rank.call(b)) else a.id < b.id)
	var out: Array[String] = []
	for def in cards:
		out.append(def.id)
	return out


## The tallest stack `line` of `character` prints from Aspect 1 up, one card per Aspect.
static func stack_for(lib: CardLibrary, character: String, line: String = "") -> Array[String]:
	var out: Array[String] = []
	for n in range(1, DeckValidator.MAX_ASPECTS + 1):
		var options: Array[String] = aspect_options(lib, character, n, line)
		if options.is_empty():
			break
		out.append(options[0])
	return out


## Makes `character` the Duelist on `line`'s stack. Allies of that character leave the deck, since
## an Ally may not share the Duelist's character.
func choose_duelist(character: String, line: String = "") -> void:
	deck.set_duelist(stack_for(library, character, line))
	for id in deck.cards.duplicate() + deck.reserve.duplicate():
		var def: CardDef = library.defs.get(id)
		if def != null and def.type == CardDef.Type.PERSONALITY and def.character == character:
			deck.cards.erase(id)
			deck.reserve.erase(id)
	_follow_duelist_side()


## Puts `id` in the stack at its Aspect, replacing the card there.
func set_aspect(id: String) -> bool:
	var def: CardDef = library.defs.get(id)
	var head: CardDef = duelist()
	if def == null or def.type != CardDef.Type.PERSONALITY or (head != null and def.character != head.character):
		return false
	var stack: Array[String] = []
	for held in deck.duelist_ids:
		if (library.defs[held] as CardDef).aspect != def.aspect:
			stack.append(held)
	stack.append(id)
	stack.sort_custom(func(a: String, b: String) -> bool:
		return (library.defs[a] as CardDef).aspect < (library.defs[b] as CardDef).aspect)
	deck.set_duelist(stack)
	_follow_duelist_side()
	return true


## Masteries this Duelist may take, by school (Freestyle last) then title.
func mastery_options() -> Array[String]:
	var out: Array[String] = []
	for def: CardDef in library.defs.values():
		if def.type == CardDef.Type.MASTERY and fits(def):
			out.append(def.id)
	out.sort_custom(func(a: String, b: String) -> bool:
		var da: CardDef = library.defs[a]
		var db: CardDef = library.defs[b]
		var sa: String = da.school if da.school != "" else "~"
		var sb: String = db.school if db.school != "" else "~"
		return sa < sb if sa != sb else da.title < db.title)
	return out


# --- Undo -----------------------------------------------------------------------------------------

func snapshot() -> Dictionary:
	return {"deck": deck.to_dict(), "id": deck.id}


func restore(snap: Dictionary) -> void:
	var back: DeckList = DeckList.from_dict(snap["deck"])
	back.id = str(snap["id"])
	back.custom = true
	deck = back


# --- Adding ---------------------------------------------------------------------------------------

## Why `id` cannot be added, "" when it can. `to_reserve` asks for the Reserve rather than the
## Life Deck; a frame card (Mastery, Relic, Duelist Aspect) goes to its slot either way.
func add_block(id: String, to_reserve: bool = false) -> String:
	var def: CardDef = library.defs.get(id)
	if def == null:
		return "That card is not in the library."
	if bool(def.raw.get("banned", false)):
		return "%s is banned outside adventure mode." % def.title
	match def.type:
		CardDef.Type.MASTERY, CardDef.Type.RELIC:
			return ""
		CardDef.Type.PERSONALITY:
			if _joins_stack(def):
				return _stack_block(def)
			if not DeckValidator.ally_aspect_allowed(def.aspect):
				return "An Ally may be Aspect 1 to %d." % DeckValidator.MAX_ALLY_ASPECT
	if copies(id) >= limit(id):
		return "The deck already runs %d, the most %s allows." % [limit(id), def.title]
	if def.school != "" and def.school != deck.style:
		if deck.style == "freestyle":
			return "A Freestyle deck takes no school cards. Pick a %s Mastery first." % CardText.school_name(def.school)
		return "%s is a %s card and this deck is %s." % [def.title, CardText.school_name(def.school), CardText.school_name(deck.style)]
	if not CardDef.side_allows(deck.alignment, def.alignment_only):
		return "%s is for %s decks only." % [def.title, def.alignment_only.capitalize()]
	var reserve: bool = to_reserve or bool(def.raw.get("reserve_only", false))
	if reserve:
		var relic: CardDef = library.defs.get(deck.relic_id)
		if relic == null:
			return "%s goes in the Reserve, and a Reserve needs a Relic." % def.title if not to_reserve else "A Reserve needs a Relic."
		if deck.reserve.size() >= relic.reserve_size:
			return "%s holds %d cards and the Reserve is full." % [relic.title, relic.reserve_size]
		return ""
	if total() >= max_cards():
		return "The deck is at its %d-card limit." % max_cards()
	return ""


func add(id: String, to_reserve: bool = false) -> bool:
	if add_block(id, to_reserve) != "":
		return false
	var def: CardDef = library.defs[id]
	match def.type:
		CardDef.Type.MASTERY:
			set_mastery(id)
		CardDef.Type.RELIC:
			deck.relic_id = id
		_:
			if def.type == CardDef.Type.PERSONALITY and _joins_stack(def):
				var stack: Array[String] = deck.duelist_ids.duplicate()
				stack.append(id)
				stack.sort_custom(func(a: String, b: String) -> bool:
					return (library.defs[a] as CardDef).aspect < (library.defs[b] as CardDef).aspect)
				deck.set_duelist(stack)
				_follow_duelist_side()
			elif to_reserve or bool(def.raw.get("reserve_only", false)):
				deck.reserve.append(id)
			else:
				deck.cards.append(id)
	return true


## The Mastery sets the Style. Cards of the old school stay, and the validator lists them.
func set_mastery(id: String) -> void:
	var mastery: CardDef = library.defs.get(id)
	if mastery == null or mastery.type != CardDef.Type.MASTERY:
		return
	deck.mastery_id = id
	deck.style = mastery.school if mastery.school != "" else "freestyle"


## A personality joins the Duelist stack when there is no Duelist yet or it is the Duelist's
## character; any other is an Ally.
func _joins_stack(def: CardDef) -> bool:
	var head: CardDef = duelist()
	return head == null or def.character == head.character


func _stack_block(def: CardDef) -> String:
	for id in deck.duelist_ids:
		if (library.defs[id] as CardDef).aspect == def.aspect:
			return "The Duelist already has an Aspect %d card. Remove it first." % def.aspect
	if deck.duelist_ids.size() >= DeckValidator.MAX_ASPECTS:
		return "The Duelist already runs %d Aspects." % DeckValidator.MAX_ASPECTS
	return ""


## A Duelist that serves one side only sets the deck's side.
func _follow_duelist_side() -> void:
	for id in deck.duelist_ids:
		var side: String = (library.defs[id] as CardDef).alignment_only
		if side != "":
			deck.alignment = side
			return


## True when the Duelist serves either side, so the player picks Vigil or Pact.
func side_is_open() -> bool:
	for id in deck.duelist_ids:
		if (library.defs[id] as CardDef).alignment_only != "":
			return false
	return true


func set_alignment(side: String) -> bool:
	if not CardDef.ALIGNMENTS.has(side) or not side_is_open():
		return false
	deck.alignment = side
	return true


# --- Removing -------------------------------------------------------------------------------------

## Takes one copy out of the Life Deck, or the card out of whichever slot holds it.
func remove(id: String) -> bool:
	var at: int = deck.cards.find(id)
	if at >= 0:
		deck.cards.remove_at(at)
		return true
	return remove_from_frame(id)


func remove_reserve(id: String) -> bool:
	var at: int = deck.reserve.find(id)
	if at < 0:
		return false
	deck.reserve.remove_at(at)
	return true


func remove_from_frame(id: String) -> bool:
	if deck.duelist_ids.has(id):
		var stack: Array[String] = deck.duelist_ids.duplicate()
		stack.erase(id)
		deck.set_duelist(stack)
		return true
	if deck.mastery_id == id:
		deck.mastery_id = ""
		return true
	if deck.relic_id == id:
		deck.relic_id = ""
		return true
	return false


## Every Life Deck copy of `id` at once.
func remove_all(id: String) -> int:
	var n: int = deck.cards.count(id)
	for i in range(n):
		deck.cards.erase(id)
	return n


# --- Import ---------------------------------------------------------------------------------------

## The player picked `id` for a line the importer could not settle alone.
func choose(line: ImportLine, id: String) -> bool:
	if line.status != ImportLine.CHOOSE or not line.options.has(id):
		return false
	var def: CardDef = library.defs.get(id)
	if def == null:
		return false
	if def.type == CardDef.Type.MASTERY:
		set_mastery(id)
	else:
		for i in range(line.qty):
			deck.cards.append(id)
	line.status = ImportLine.MATCHED
	line.id = id
	return true
