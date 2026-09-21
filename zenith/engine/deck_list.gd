class_name DeckList
extends RefCounted
## A deck as a player builds it. Card ids only; the engine instantiates them.

var name: String = "Deck"
var duelist_id: String = ""
var aspects: int = 3
var style: String = ""             # "freestyle" or a school word; must match the Mastery
var alignment: String = "vigil"
var mastery_id: String = ""
var relic_id: String = ""
var reserve: Array[String] = []
var archetype: String = ""         # an Archetype id: what kind of deck this is, shown to both players
var subthemes: Array[String] = []  # Archetype subtheme ids
var difficulty: String = ""        # easy | medium | hard to pilot
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
	deck.duelist_id = str(d.get("duelist", ""))
	deck.aspects = int(d.get("aspects", 3))
	deck.style = str(d.get("style", ""))
	deck.alignment = str(d.get("alignment", "vigil"))
	deck.mastery_id = str(d.get("mastery", ""))
	deck.relic_id = str(d.get("relic", ""))
	deck.reserve.assign(d.get("reserve", []))
	deck.archetype = str(d.get("archetype", ""))
	deck.subthemes.assign(d.get("subthemes", []))
	deck.difficulty = str(d.get("difficulty", ""))
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
	var n: int = cards.size() + aspects
	if mastery_id != "":
		n += 1
	if relic_id != "":
		n += 1
	return n
