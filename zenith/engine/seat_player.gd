class_name SeatPlayer
extends RefCounted
## One player's public standing plus their zones as lists of card uids. The cards themselves
## live in the SeatView's card table, masked for the seat that receives it.

var index: int = 0
var name: String = ""
var alignment: String = "vigil"
var style: String = ""
var archetype: String = ""           # Archetype id, public like the style
var subthemes: Array[String] = []
var fervor: int = 0
var highest_aspect: int = 1
# Effective values, computed by the engine from base state plus standing effects. Clients show
# these and never a rules constant, so a card that changes one changes the display.
var fervor_needed: int = DuelEngine.FERVOR_TO_ASPECT
var fervor_gain: int = 1
var recover_gain: int = 0
var fervor_shield: bool = false
var aspect_shield: bool = false
var restrictions: Array[String] = []   # forbid `what` words in force; CardText.restriction_name reads them
var duelist: int = -1
var mastery: int = -1
var grimoire: int = -1
var controlling: int = -1
var pages: Array[int] = []
var life_deck: Array[int] = []   # top first
var hand: Array[int] = []
var discard: Array[int] = []     # last is the top
var removed: Array[int] = []
var allies: Array[int] = []
var drills: Array[int] = []
var non_combats: Array[int] = []
var seals: Array[int] = []
var must_pass: bool = false
var skip_next_attack_phase: bool = false
var seal_victory_pending: bool = false
var no_ascension_win: bool = false


func to_dict() -> Dictionary:
	return {
		"index": index, "name": name, "alignment": alignment, "style": style,
		"archetype": archetype, "subthemes": subthemes,
		"fervor": fervor, "highest_aspect": highest_aspect, "fervor_needed": fervor_needed,
		"fervor_gain": fervor_gain, "recover_gain": recover_gain, "fervor_shield": fervor_shield,
		"aspect_shield": aspect_shield, "restrictions": restrictions, "duelist": duelist, "mastery": mastery,
		"grimoire": grimoire, "controlling": controlling, "pages": pages, "life_deck": life_deck,
		"hand": hand, "discard": discard, "removed": removed, "allies": allies, "drills": drills,
		"non_combats": non_combats, "seals": seals, "must_pass": must_pass,
		"skip_next_attack_phase": skip_next_attack_phase, "seal_victory_pending": seal_victory_pending,
		"no_ascension_win": no_ascension_win,
	}


static func from_dict(d: Dictionary) -> SeatPlayer:
	var p: SeatPlayer = SeatPlayer.new()
	p.index = int(d.get("index", 0))
	p.name = str(d.get("name", ""))
	p.alignment = str(d.get("alignment", "vigil"))
	p.style = str(d.get("style", ""))
	p.archetype = str(d.get("archetype", ""))
	p.subthemes.assign(d.get("subthemes", []))
	p.fervor = int(d.get("fervor", 0))
	p.highest_aspect = int(d.get("highest_aspect", 1))
	p.fervor_needed = int(d.get("fervor_needed", DuelEngine.FERVOR_TO_ASPECT))
	p.fervor_gain = int(d.get("fervor_gain", 1))
	p.recover_gain = int(d.get("recover_gain", 0))
	p.fervor_shield = bool(d.get("fervor_shield", false))
	p.aspect_shield = bool(d.get("aspect_shield", false))
	p.restrictions = strings(d.get("restrictions", []))
	p.duelist = int(d.get("duelist", -1))
	p.mastery = int(d.get("mastery", -1))
	p.grimoire = int(d.get("grimoire", -1))
	p.controlling = int(d.get("controlling", -1))
	p.pages = ints(d.get("pages", []))
	p.life_deck = ints(d.get("life_deck", []))
	p.hand = ints(d.get("hand", []))
	p.discard = ints(d.get("discard", []))
	p.removed = ints(d.get("removed", []))
	p.allies = ints(d.get("allies", []))
	p.drills = ints(d.get("drills", []))
	p.non_combats = ints(d.get("non_combats", []))
	p.seals = ints(d.get("seals", []))
	p.must_pass = bool(d.get("must_pass", false))
	p.skip_next_attack_phase = bool(d.get("skip_next_attack_phase", false))
	p.seal_victory_pending = bool(d.get("seal_victory_pending", false))
	p.no_ascension_win = bool(d.get("no_ascension_win", false))
	return p


static func ints(v: Variant) -> Array[int]:
	var out: Array[int] = []
	if v is Array:
		for x in v:
			out.append(int(x))
	return out


static func strings(v: Variant) -> Array[String]:
	var out: Array[String] = []
	if v is Array:
		for x in v:
			out.append(str(x))
	return out


static func _uids(cards: Array[CardInstance]) -> Array[int]:
	var out: Array[int] = []
	for c in cards:
		out.append(c.uid)
	return out


static func of(p: PlayerState, engine: DuelEngine) -> SeatPlayer:
	var v: SeatPlayer = SeatPlayer.new()
	v.index = p.index
	v.name = p.name
	v.alignment = p.alignment
	v.style = p.style
	v.archetype = p.archetype
	v.subthemes = p.subthemes.duplicate()
	v.fervor = p.fervor
	v.highest_aspect = p.highest_aspect
	v.fervor_needed = engine.fervor_needed(p)
	v.fervor_gain = engine.fervor_gain(p)
	v.recover_gain = engine.recover_gain(p)
	v.fervor_shield = engine.fervor_shielded(p)
	v.aspect_shield = engine.aspect_shielded(p)
	v.restrictions = engine.restrictions(p)
	v.duelist = p.duelist.uid
	v.mastery = p.mastery.uid if p.mastery != null else -1
	v.grimoire = p.grimoire.uid if p.grimoire != null else -1
	v.controlling = p.in_control().uid
	v.pages = _uids(p.pages)
	v.life_deck = _uids(p.life_deck)
	v.hand = _uids(p.hand)
	v.discard = _uids(p.discard)
	v.removed = _uids(p.removed)
	v.allies = _uids(p.allies())
	v.drills = _uids(p.drills())
	v.non_combats = _uids(p.non_combats())
	var seals: Array[CardInstance] = p.seals()
	seals.sort_custom(func(a: CardInstance, b: CardInstance) -> bool: return a.def.seal_number < b.def.seal_number)
	v.seals = _uids(seals)
	v.must_pass = p.must_pass
	v.skip_next_attack_phase = p.skip_next_attack_phase
	v.seal_victory_pending = p.seal_victory_pending
	v.no_ascension_win = p.no_ascension_win
	return v
