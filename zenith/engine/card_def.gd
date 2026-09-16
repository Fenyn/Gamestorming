class_name CardDef
extends RefCounted
## Immutable card definition loaded from JSON. See zenith/README.md for the schema.

enum Type { FIGHTER, ALLY, STRIKE, ART, COMBAT, NON_COMBAT, DRILL, TOKEN, GROUNDS, MASTERY, MASTER }

const TYPE_NAMES: Dictionary = {
	"fighter": Type.FIGHTER,
	"ally": Type.ALLY,
	"strike": Type.STRIKE,
	"art": Type.ART,
	"combat": Type.COMBAT,
	"non_combat": Type.NON_COMBAT,
	"drill": Type.DRILL,
	"token": Type.TOKEN,
	"grounds": Type.GROUNDS,
	"mastery": Type.MASTERY,
	"master": Type.MASTER,
}

var id: String = ""
var title: String = ""
var type: Type = Type.COMBAT
var guild: String = ""          # "" is Freestyle
var text: String = ""
var character: String = ""      # personalities: which character this card belongs to
var alignment_only: String = "" # "", "knight", "knave"
var only: Dictionary = {}       # play/use gate, e.g. {"character": "Sir Edric Rooke"} or {"fighter_character": ...}
var limit_per_deck: int = 3
var endurance: int = 0
var endurance_when: Dictionary = {}   # Endurance X: {"value_if": {...cond}, "then": 6, "else": 3}
var remove_after_use: bool = false
var bottom_after_use: bool = false     # goes to the bottom of the Life Deck after use
var attack: Dictionary = {}     # kind, stages, life, printed_stages, printed_life, cost_stages, cost_life, focused, unstoppable, stages_from_table, no_prevent
var defense: Dictionary = {}    # stops: strike | art | any; when: cond; cost_stages; cost_life; stop_focused: true | "discard_hand"
var empower: int = 0            # Empower N: +N wounds, drops effects flagged after_empower
var remain: int = 0             # stays in play to be used N more times this Combat
var remain_when: Dictionary = {}   # conditional Remain: {"when": cond, "remain": N}
var counter: String = ""        # "combat": may be played in response to a Combat card to cancel it
var start_in_play: bool = false
var effects: Array[Dictionary] = []   # {trigger, op, who, amount, when, after_empower, ...}
var modifiers: Array[Dictionary] = [] # {scope: own | against, kind: strike | art | any, stages, life, guild, title_contains, when, per_ally}
var shield: String = ""         # Defense Shield on Drills: "", strike, art, any
var forbid: Array = []          # standing forbids while in play (Grounds, Drills): [{"who": "all"|"owner"|"opponent", "what": "..."}]
var attachment: Dictionary = {} # {"target": "in_control"|"fighter", "modifiers": [...], "effects": [...], "damage_removes": bool}
var tiers: Array[Dictionary] = []     # personalities: {tier, surge, might: [11 ints], wild, power, constant, shield}
var token_set: String = ""
var token_number: int = 0
var capture_trait: bool = false
var armory_size: int = 0
var master_flags: Dictionary = {}     # Master passives: {"no_favor_win": true, "acclaim_shield": true, "tier_shield": true}
var opponent_tier_threshold: int = 0  # Mastery: opponent needs this much Acclaim to rise a tier
var raw: Dictionary = {}


static func from_dict(d: Dictionary) -> CardDef:
	var c: CardDef = CardDef.new()
	c.raw = d
	c.id = str(d.get("id", ""))
	c.title = str(d.get("title", c.id))
	var type_name: String = str(d.get("type", "combat"))
	assert(TYPE_NAMES.has(type_name), "Unknown card type '%s' on %s" % [type_name, c.id])
	c.type = TYPE_NAMES[type_name] as Type
	c.guild = str(d.get("guild", ""))
	c.text = str(d.get("text", ""))
	c.character = str(d.get("character", ""))
	c.alignment_only = str(d.get("alignment_only", ""))
	c.only = d.get("only", {})
	c.limit_per_deck = int(d.get("limit_per_deck", 3))
	c.endurance = int(d.get("endurance", 0))
	c.endurance_when = d.get("endurance_when", {})
	c.remove_after_use = bool(d.get("remove_after_use", false))
	c.bottom_after_use = bool(d.get("bottom_after_use", false))
	c.attack = d.get("attack", {})
	c.defense = d.get("defense", {})
	c.empower = int(d.get("empower", 0))
	c.remain = int(d.get("remain", 0))
	c.remain_when = d.get("remain_when", {})
	c.counter = str(d.get("counter", ""))
	c.start_in_play = bool(d.get("start_in_play", false))
	c.effects.assign(d.get("effects", []))
	c.modifiers.assign(d.get("modifiers", []))
	c.shield = str(d.get("shield", ""))
	c.forbid = d.get("forbid", [])
	c.attachment = d.get("attachment", {})
	c.tiers.assign(d.get("tiers", []))
	c.token_set = str(d.get("token_set", ""))
	c.token_number = int(d.get("token_number", 0))
	c.capture_trait = bool(d.get("capture_trait", false))
	c.armory_size = int(d.get("armory_size", 0))
	c.master_flags = d.get("master_flags", {})
	c.opponent_tier_threshold = int(d.get("opponent_tier_threshold", 0))
	return c


func is_personality() -> bool:
	return type == Type.FIGHTER or type == Type.ALLY


func is_hand_combat_card() -> bool:
	return type == Type.STRIKE or type == Type.ART or type == Type.COMBAT


func is_attack() -> bool:
	return not attack.is_empty()


func attack_kind() -> String:
	return str(attack.get("kind", ""))


func is_defense() -> bool:
	return not defense.is_empty()


## True when this card's printed defense stops an attack of `kind`.
## Focused attacks get past anything that stops "any" unless the defense says stop_focused.
func stops_kind(kind: String, focused: bool) -> bool:
	return CardDef.defense_stops(defense, kind, focused)


static func defense_stops(defense_spec: Dictionary, kind: String, focused: bool) -> bool:
	if defense_spec.is_empty():
		return false
	var stops: String = str(defense_spec.get("stops", ""))
	if stops == "any":
		return not focused or defense_spec.has("stop_focused")
	return stops == kind


## True when any effect stops all attacks of a kind for the rest of Combat (a "stop-all" card).
func is_stop_all_card() -> bool:
	for e in effects:
		if str(e.get("op", "")) == "stop_all":
			return true
	if not defense.is_empty() and defense.has("stop_all"):
		return true
	return false


func is_end_combat_card() -> bool:
	for e in effects:
		if str(e.get("op", "")) == "end_combat":
			return true
	return false


func effects_for(trigger: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in effects:
		if str(e.get("trigger", "secondary")) == trigger:
			out.append(e)
	return out


func has_trigger(trigger: String) -> bool:
	for e in effects:
		if str(e.get("trigger", "secondary")) == trigger:
			return true
	return false


func tier_data(tier: int) -> Dictionary:
	for t in tiers:
		if int(t.get("tier", 0)) == tier:
			return t
	return {}


func highest_tier() -> int:
	var best: int = 0
	for t in tiers:
		best = maxi(best, int(t.get("tier", 0)))
	return best


func lowest_tier() -> int:
	var best: int = 99
	for t in tiers:
		best = mini(best, int(t.get("tier", 0)))
	return best if best != 99 else 0
