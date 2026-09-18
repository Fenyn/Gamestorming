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
