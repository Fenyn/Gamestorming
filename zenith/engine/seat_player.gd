class_name SeatPlayer
extends RefCounted
## One player's public standing plus their zones as lists of card uids. The cards themselves
## live in the SeatView's card table, masked for the seat that receives it.

var index: int = 0
var name: String = ""
var alignment: String = "knight"
var focus: String = ""
var has_focus: bool = false
var acclaim: int = 0
var highest_tier: int = 1
var fighter: int = -1
var mastery: int = -1
var master: int = -1
var controlling: int = -1
var armory: Array[int] = []
var life_deck: Array[int] = []   # top first
var hand: Array[int] = []
var discard: Array[int] = []     # last is the top
var removed: Array[int] = []
var allies: Array[int] = []
var drills: Array[int] = []
var non_combats: Array[int] = []
var tokens: Array[int] = []
var must_pass: bool = false
var skip_next_attack_phase: bool = false
var token_victory_pending: bool = false
var no_favor_win: bool = false


func to_dict() -> Dictionary:
	return {
		"index": index, "name": name, "alignment": alignment, "focus": focus, "has_focus": has_focus,
		"acclaim": acclaim, "highest_tier": highest_tier, "fighter": fighter, "mastery": mastery,
		"master": master, "controlling": controlling, "armory": armory, "life_deck": life_deck,
		"hand": hand, "discard": discard, "removed": removed, "allies": allies, "drills": drills,
		"non_combats": non_combats, "tokens": tokens, "must_pass": must_pass,
		"skip_next_attack_phase": skip_next_attack_phase, "token_victory_pending": token_victory_pending,
		"no_favor_win": no_favor_win,
	}


static func from_dict(d: Dictionary) -> SeatPlayer:
	var p: SeatPlayer = SeatPlayer.new()
	p.index = int(d.get("index", 0))
	p.name = str(d.get("name", ""))
	p.alignment = str(d.get("alignment", "knight"))
	p.focus = str(d.get("focus", ""))
	p.has_focus = bool(d.get("has_focus", false))
	p.acclaim = int(d.get("acclaim", 0))
	p.highest_tier = int(d.get("highest_tier", 1))
	p.fighter = int(d.get("fighter", -1))
	p.mastery = int(d.get("mastery", -1))
	p.master = int(d.get("master", -1))
	p.controlling = int(d.get("controlling", -1))
	p.armory = ints(d.get("armory", []))
	p.life_deck = ints(d.get("life_deck", []))
	p.hand = ints(d.get("hand", []))
	p.discard = ints(d.get("discard", []))
	p.removed = ints(d.get("removed", []))
	p.allies = ints(d.get("allies", []))
	p.drills = ints(d.get("drills", []))
	p.non_combats = ints(d.get("non_combats", []))
	p.tokens = ints(d.get("tokens", []))
	p.must_pass = bool(d.get("must_pass", false))
	p.skip_next_attack_phase = bool(d.get("skip_next_attack_phase", false))
	p.token_victory_pending = bool(d.get("token_victory_pending", false))
	p.no_favor_win = bool(d.get("no_favor_win", false))
	return p


static func ints(v: Variant) -> Array[int]:
	var out: Array[int] = []
	if v is Array:
		for x in v:
			out.append(int(x))
	return out


static func _uids(cards: Array[CardInstance]) -> Array[int]:
	var out: Array[int] = []
	for c in cards:
		out.append(c.uid)
	return out


static func of(p: PlayerState) -> SeatPlayer:
	var v: SeatPlayer = SeatPlayer.new()
	v.index = p.index
	v.name = p.name
	v.alignment = p.alignment
	v.focus = p.focus
	v.has_focus = p.has_focus()
	v.acclaim = p.acclaim
	v.highest_tier = p.highest_tier
	v.fighter = p.fighter.uid
	v.mastery = p.mastery.uid if p.mastery != null else -1
	v.master = p.master.uid if p.master != null else -1
	v.controlling = p.in_control().uid
	v.armory = _uids(p.armory)
	v.life_deck = _uids(p.life_deck)
	v.hand = _uids(p.hand)
	v.discard = _uids(p.discard)
	v.removed = _uids(p.removed)
	v.allies = _uids(p.allies())
	v.drills = _uids(p.drills())
	v.non_combats = _uids(p.non_combats())
	var tokens: Array[CardInstance] = p.tokens()
	tokens.sort_custom(func(a: CardInstance, b: CardInstance) -> bool: return a.def.token_number < b.def.token_number)
	v.tokens = _uids(tokens)
	v.must_pass = p.must_pass
	v.skip_next_attack_phase = p.skip_next_attack_phase
	v.token_victory_pending = p.token_victory_pending
	v.no_favor_win = p.no_favor_win
	return v
