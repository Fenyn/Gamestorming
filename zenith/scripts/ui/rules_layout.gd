class_name RulesLayout
extends RefCounted
## Splits a card's generated rules text into the parts a card face sets apart, so a long card
## reads as short blocks instead of one paragraph. The words are never changed, only placed:
##   gate:  sentences that say who may use the card ("Draconic duelists only.")
##   paras: the body, one entry per block. A block starts at each line of the source text, at a
##          lead-in ("When entering Combat," "Hit:" "Power:"), at a branch ("If you do,"
##          "Otherwise,") which is indented under the block before it, at a Fervor rider, and at
##          reminder text in brackets.
##   tags:  bookkeeping and Fervor sentences as short chips, {word, role}: "LIMIT 1" and
##          "REMOVED AFTER USE" have role "", "+1 FERVOR" and "RIVAL -2 FERVOR" role "fervor".

const _SENTENCE: String = "(?<=[.)\"])\\s+(?=[A-Z(\"])"
const _COLON_LEAD: String = "^([A-Z][A-Za-z' ]{0,40}):\\s+"
const _COMMA_LEAD: String = "^((?:When|Whenever|During|At the start of|After|If this card is) [^,:]{2,60}),\\s+"
const _BRANCHES: Array[String] = ["If you do not,", "If you do,", "Otherwise,"]
const _OWN_LINE: Array[String] = ["Raise your Fervor", "Lower your opponent's Fervor", "Raise your duelist's", "Empower "]
## Pattern, chip word, role. Fervor chips come first so they lead the row.
const _TAGS: Array = [
	["^Raise your Fervor (\\d+)\\.$", "+%s FERVOR", "fervor"],
	["^Lower your opponent's Fervor (\\d+)\\.$", "RIVAL -%s FERVOR", "fervor"],
	["^Limit (\\d+) per deck\\.$", "LIMIT %s", ""],
	["^Remove from the game after use\\.$", "REMOVED AFTER USE", ""],
	["^Place at the bottom of your Life Deck after use\\.$", "TO LIFE DECK AFTER USE", ""],
	["^Once per Combat\\.$", "ONCE PER COMBAT", ""],
	["^Remain (\\d+)\\.$", "REMAIN %s", ""],
	["^Endurance (\\d+|X)\\.$", "ENDURANCE %s", ""],
]
const _GATES: Array[String] = ["^[A-Z][A-Za-z']*(?: [A-Za-z']+){0,2} only\\.$", "^Use this card only if ", "^Adventure only:"]

static var _re: Dictionary = {}


static func _rx(pattern: String) -> RegEx:
	if not _re.has(pattern):
		var r: RegEx = RegEx.new()
		r.compile(pattern)
		_re[pattern] = r
	return _re[pattern]


## {gate: PackedStringArray, paras: Array of {lead, text, indent, aside}, tags: Array of {word, role}}
static func build(plain: String) -> Dictionary:
	var gate: PackedStringArray = PackedStringArray()
	var tags: Array[Dictionary] = []
	var paras: Array[Dictionary] = []
	for line in plain.split("\n", false):
		var open: Dictionary = {}
		for sentence in _split(line):
			var tag: Dictionary = _tag(sentence)
			if not tag.is_empty():
				tags.append(tag)
				continue
			if _is_gate(sentence):
				gate.append(sentence)
				continue
			var starts: bool = open.is_empty()
			var indent: bool = false
			var lead: String = ""
			var rest: String = sentence
			for b in _BRANCHES:
				if sentence.begins_with(b):
					starts = true
					indent = true
			for o in _OWN_LINE:
				if sentence.begins_with(o):
					starts = true
			var aside: bool = sentence.begins_with("(")
			if aside:
				starts = true
			if not indent and not aside:
				var m: RegExMatch = _rx(_COLON_LEAD).search(sentence)
				if m == null:
					m = _rx(_COMMA_LEAD).search(sentence)
				if m != null:
					starts = true
					lead = sentence.substr(0, m.get_end()).strip_edges()
					rest = sentence.substr(m.get_end())
			if starts:
				open = {"lead": lead, "text": rest, "indent": indent, "aside": aside}
				paras.append(open)
			else:
				open["text"] = str(open["text"]) + " " + sentence
	var ordered: Array[Dictionary] = []
	for t in tags:
		if str(t["role"]) != "":
			ordered.append(t)
	for t in tags:
		if str(t["role"]) == "":
			ordered.append(t)
	return {"gate": gate, "paras": paras, "tags": ordered}


static func _split(line: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var pos: int = 0
	for m in _rx(_SENTENCE).search_all(line):
		out.append(line.substr(pos, m.get_start() - pos).strip_edges())
		pos = m.get_end()
	out.append(line.substr(pos).strip_edges())
	return out


static func _tag(sentence: String) -> Dictionary:
	for t in _TAGS:
		var m: RegExMatch = _rx(str(t[0])).search(sentence)
		if m != null:
			var word: String = str(t[1])
			return {"word": word % m.get_string(1) if word.contains("%s") else word, "role": str(t[2])}
	return {}


static func _is_gate(sentence: String) -> bool:
	for g in _GATES:
		if _rx(g).search(sentence) != null:
			return true
	return false
