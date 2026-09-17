class_name KeywordText
extends RefCounted
## Rules text to BBCode: keywords from CardText.KEYWORDS get a role colour and a hover hint.
## INK is for the cream card face, LIGHT for the dark UI.

const INK: Dictionary = {
	"energy": Color(0.12, 0.44, 0.30),
	"might": Color(0.30, 0.36, 0.50),
	"fervor": Color(0.58, 0.40, 0.04),
	"ascension": Color(0.58, 0.40, 0.04),
	"focus": Color(0.74, 0.36, 0.06),
	"attack": Color(0.66, 0.16, 0.10),
	"defense": Color(0.12, 0.34, 0.64),
	"removed": Color(0.42, 0.22, 0.22),
	"zone": Color(0.36, 0.30, 0.24),
	"plain": Color(0.10, 0.08, 0.06),
}
const LIGHT: Dictionary = {
	"energy": Color(0.36, 0.76, 0.58),
	"might": Color(0.78, 0.82, 0.90),
	"fervor": Color(0.95, 0.80, 0.40),
	"ascension": Color(0.95, 0.80, 0.40),
	"focus": Color(0.95, 0.60, 0.25),
	"attack": Color(0.90, 0.38, 0.30),
	"defense": Color(0.40, 0.62, 0.92),
	"removed": Color(0.80, 0.55, 0.55),
	"zone": Color(0.75, 0.70, 0.62),
	"plain": Color(0.93, 0.91, 0.87),
}
const TYPE_ROLES: Dictionary = {
	"strike": CardDef.Type.STRIKE, "art": CardDef.Type.ART, "combat": CardDef.Type.COMBAT,
	"non_combat": CardDef.Type.NON_COMBAT, "drill": CardDef.Type.DRILL, "ally": CardDef.Type.ALLY,
	"seal": CardDef.Type.SEAL, "grounds": CardDef.Type.GROUNDS, "mastery": CardDef.Type.MASTERY,
	"relic": CardDef.Type.RELIC,
}

static var _compiled: Array[RegEx] = []


static func color_for(role: String, on_dark: bool) -> Color:
	if TYPE_ROLES.has(role):
		var t: CardDef.Type = TYPE_ROLES[role]
		return Palette.type_ui(t) if on_dark else Palette.type_ink(t)
	var table: Dictionary = LIGHT if on_dark else INK
	return table.get(role, table["plain"])


static func _regexes() -> Array[RegEx]:
	if _compiled.is_empty():
		for k in CardText.KEYWORDS:
			var r: RegEx = RegEx.new()
			var err: Error = r.compile(str(k["pattern"]))
			assert(err == OK, "Bad keyword pattern for %s" % str(k["key"]))
			_compiled.append(r)
	return _compiled


## Overlapping matches go to the earliest start, then the longest.
static func bbcode(plain: String, on_dark: bool = false) -> String:
	var found: Array[Dictionary] = []
	var regexes: Array[RegEx] = _regexes()
	for i in range(regexes.size()):
		for m in regexes[i].search_all(plain):
			found.append({"start": m.get_start(), "end": m.get_end(), "index": i})
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["start"] != b["start"]:
			return a["start"] < b["start"]
		return a["end"] > b["end"])
	var out: String = ""
	var pos: int = 0
	for f in found:
		var start: int = int(f["start"])
		var end: int = int(f["end"])
		if start < pos:
			continue
		out += _escape(plain.substr(pos, start - pos))
		var k: Dictionary = CardText.KEYWORDS[int(f["index"])]
		var color: Color = color_for(str(k["role"]), on_dark)
		var word: String = _escape(plain.substr(start, end - start))
		out += "[color=#%s][hint=%s]%s[/hint][/color]" % [color.to_html(false), _hint(str(k["tip"])), word]
		pos = end
	out += _escape(plain.substr(pos))
	return out


static func tip_for(word: String) -> String:
	var regexes: Array[RegEx] = _regexes()
	for i in range(regexes.size()):
		var m: RegExMatch = regexes[i].search(word)
		if m != null and m.get_start() == 0 and m.get_end() == word.length():
			return str(CardText.KEYWORDS[i]["tip"])
	return ""


static func _escape(s: String) -> String:
	return s.replace("[", "[lb]").replace("]", "[rb]")


## Quoted: an unquoted hint with punctuation is printed raw by the tag parser.
static func _hint(s: String) -> String:
	return "\"%s\"" % s.replace("[", "(").replace("]", ")").replace("\"", "'")
