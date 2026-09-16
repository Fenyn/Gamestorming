class_name DeckList
extends RefCounted
## A deck as a player builds it. Card ids only; the engine instantiates them.

var name: String = "Deck"
var fighter_id: String = ""
var tiers: int = 3
var focus: String = ""
var alignment: String = "knight"
var mastery_id: String = ""
var master_id: String = ""
var armory: Array[String] = []
var cards: Array[String] = []   # expanded, one entry per copy


static func from_dict(d: Dictionary) -> DeckList:
	var deck: DeckList = DeckList.new()
	deck.name = str(d.get("name", "Deck"))
	deck.fighter_id = str(d.get("fighter", ""))
	deck.tiers = int(d.get("tiers", 3))
	deck.focus = str(d.get("focus", ""))
	deck.alignment = str(d.get("alignment", "knight"))
	deck.mastery_id = str(d.get("mastery", ""))
	deck.master_id = str(d.get("master", ""))
	deck.armory.assign(d.get("armory", []))
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


## Cards that count toward deck size: Life Deck, Fighter tiers, Mastery, Master.
func total_cards() -> int:
	var n: int = cards.size() + tiers
	if mastery_id != "":
		n += 1
	if master_id != "":
		n += 1
	return n
