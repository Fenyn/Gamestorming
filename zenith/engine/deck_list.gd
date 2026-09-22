class_name DeckList
extends RefCounted
## A deck as a player builds it. Card ids only; the engine instantiates them.

var name: String = "Deck"
## The Duelist's Aspect stack, one card id per tier, lowest first. Each Aspect is its own card
## since 2026-09-21, so a deck names a list and not a single personality.
var duelist_ids: Array[String] = []
## Derived from `duelist_ids`; kept as a field because it is read everywhere a deck's height is
## shown. Anything that sets the list should go through `set_duelist()`.
var aspects: int = 0
var style: String = ""             # "freestyle" or a school word; must match the Mastery
var alignment: String = "vigil"
var mastery_id: String = ""
var relic_id: String = ""
var reserve: Array[String] = []
var archetype: String = ""         # an Archetype id: what kind of deck this is, shown to both players
var subthemes: Array[String] = []  # Archetype subtheme ids
var difficulty: String = ""        # easy | medium | hard to pilot
var cleared: float = 0.0           # adventure starter: mean ladder stages cleared in the sim sweep, 0 for none
## Ease-of-play bonus folded into `run_score`: an easy deck is worth two stages, a medium one one.
const EASE_BONUS: Dictionary = {"easy": 2.0, "medium": 1.0, "hard": 0.0}
var ai_profile: String = ""      # playstyle file under data/ai/profiles for an AI playing this deck; "" plays the defaults
var tagline: String = ""         # one line under the duelist's name on the select screen
var blurb: String = ""           # two or three sentences on who they are and how the deck plays
var cards: Array[String] = []   # expanded, one entry per copy
## "tournament" is a multiplayer precon; "adventure" is a run deck, which DeckValidator holds to
## lower floors on size and aspect count. See designs/zenith_adventure.md section 9.
var mode: String = "tournament"


static func from_dict(d: Dictionary) -> DeckList:
	var deck: DeckList = DeckList.new()
	deck.name = str(d.get("name", "Deck"))
	var duelist: Variant = d.get("duelist", [])
	if duelist is String:
		# One release of tolerance, and it refuses rather than guessing: the old form named a
		# stack card plus a count, and which cards that meant is a migration's job, not a load's.
		push_error(("Deck '%s' still names a single Duelist card '%s' with \"aspects\": %s. " +
			"Each Aspect is its own card: \"duelist\" must be the list of its tier card ids. " +
			"See data/migrations/personality_split.json.")
			% [deck.name, duelist, str(d.get("aspects", "?"))])
	else:
		deck.set_duelist(DeckList._strings(duelist))
	deck.style = str(d.get("style", ""))
	deck.alignment = str(d.get("alignment", "vigil"))
	deck.mastery_id = str(d.get("mastery", ""))
	deck.relic_id = str(d.get("relic", ""))
	deck.reserve.assign(d.get("reserve", []))
	deck.archetype = str(d.get("archetype", ""))
	deck.subthemes.assign(d.get("subthemes", []))
	deck.difficulty = str(d.get("difficulty", ""))
	deck.cleared = float(d.get("cleared", 0.0))
	deck.ai_profile = str(d.get("ai_profile", ""))
	deck.tagline = str(d.get("tagline", ""))
	deck.blurb = str(d.get("blurb", ""))
	deck.mode = str(d.get("mode", "tournament"))
	var entries: Array = d.get("cards", [])
	for entry in entries:
		if entry is String:
			deck.cards.append(entry)
		elif entry is Dictionary:
			var id: String = str(entry.get("id", ""))
			var count: int = int(entry.get("count", 1))
			for i in range(count):
				deck.cards.append(id)
	return deck


static func _strings(v: Variant) -> Array[String]:
	var out: Array[String] = []
	if v is Array:
		for id in v:
			out.append(str(id))
	return out


## The one place `duelist_ids` and the derived `aspects` count are set together.
func set_duelist(ids: Array[String]) -> void:
	duelist_ids = ids.duplicate()
	aspects = duelist_ids.size()


## The card a screen shows as the deck's face: the Duelist's first Aspect.
## One number out of ten for the adventure roster: stages cleared plus the ease bonus. A strong
## deck that is hard to pilot and an easy deck that stalls mid-ladder land near each other.
func run_score() -> float:
	return cleared + float(EASE_BONUS.get(difficulty, 0.0)) if cleared > 0.0 else 0.0


func duelist_face_id() -> String:
	return duelist_ids[0] if not duelist_ids.is_empty() else ""


## The Duelist's Aspect stack, assembled from the library. Empty when the deck names nothing.
func duelist_stack(library: CardLibrary) -> PersonalityStack:
	return PersonalityStack.from_ids(library, duelist_ids)


## Deck ids live in two places: multiplayer precons and adventure starters. Anything that takes a
## deck id rather than a path should go through here so both are reachable.
const DIRS: Array[String] = [
	"res://data/decks",
	"res://data/adventure/starters",
	"res://data/adventure/opponents",
]


static func resolve(deck_id: String) -> DeckList:
	for dir in DIRS:
		var path: String = "%s/%s.json" % [dir, deck_id]
		if FileAccess.file_exists(path):
			return DeckList.load_from(path)
	push_error("No deck named '%s' in %s" % [deck_id, ", ".join(DIRS)])
	return null


static func load_from(path: String) -> DeckList:
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	assert(parsed is Dictionary, "Deck %s is not a JSON object" % path)
	return DeckList.from_dict(parsed)


## Cards that count toward deck size: Life Deck, Duelist aspects, Mastery, Relic.
func total_cards() -> int:
	var n: int = cards.size() + duelist_ids.size()
	if mastery_id != "":
		n += 1
	if relic_id != "":
		n += 1
	return n
