class_name PlayerState
extends RefCounted
## Everything one player owns or controls, plus per-turn and per-Combat flags.

var index: int = 0
var name: String = ""
var alignment: String = "knight"   # knight | knave
var focus: String = ""               # "" none, "freestyle", or a guild word
var fighter: CardInstance = null
var highest_tier: int = 1
var acclaim: int = 0
var acclaim_needed: int = DuelEngine.ACCLAIM_TO_TIER   # base; DuelEngine.acclaim_needed layers standing effects on top
var mastery: CardInstance = null
var master: CardInstance = null
var armory: Array[CardInstance] = []
var life_deck: Array[CardInstance] = []   # index 0 is the top
var hand: Array[CardInstance] = []
var discard: Array[CardInstance] = []     # last element is the top
var removed: Array[CardInstance] = []
var in_play: Array[CardInstance] = []     # allies, drills, non-combats, tokens (by controller)
var controlling: CardInstance = null      # personality in control of Combat

# Per-turn flags
var combat_declared: bool = false
var placed_grounds: bool = false
var cannot_declare_combat: bool = false
# Per-Combat flags
var final_strike_used: bool = false
var must_pass: bool = false
var skip_next_attack_phase: bool = false
# Cross-turn flags
var token_victory_pending: bool = false
var no_favor_win: bool = false          # a card effect forbade the Favor win for the game
var master_uses: int = 0                # how many times the Master's power has been used
var combat_cards_used_combat: int = -1  # last Combat in which this player used a Combat-type card
var attack_count_combat: int = 0        # attacks performed this Combat (for "first attack" powers)
var last_searched: int = -1             # uid of the last card a search put into hand or play
var pending_fight_back: Array[Dictionary] = []   # wound-triggered effects waiting for the next fight-back phase
var must_declare_combat: bool = false    # forced by an opponent's card this turn


## Focus (and everything that keys off it, like Endurance) needs a Mastery on the table.
func has_focus() -> bool:
	return focus != "" and mastery != null


func in_control() -> CardInstance:
	return controlling if controlling != null else fighter


func vigor() -> int:
	return fighter.vigor


func allies() -> Array[CardInstance]:
	return _of_type(CardDef.Type.ALLY)


func drills() -> Array[CardInstance]:
	return _of_type(CardDef.Type.DRILL)


func non_combats() -> Array[CardInstance]:
	return _of_type(CardDef.Type.NON_COMBAT)


func tokens() -> Array[CardInstance]:
	return _of_type(CardDef.Type.TOKEN)


func tokens_of_set(set_name: String) -> int:
	var n: int = 0
	for c in tokens():
		if c.def.token_set == set_name:
			n += 1
	return n


## Guild word of the styled Drills in play, or "" if none.
func drill_guild() -> String:
	for d in drills():
		if d.def.guild != "":
			return d.def.guild
	return ""


func reset_turn_flags() -> void:
	must_declare_combat = false
	combat_declared = false
	placed_grounds = false
	cannot_declare_combat = false


func reset_combat_flags() -> void:
	pending_fight_back.clear()
	final_strike_used = false
	must_pass = false
	skip_next_attack_phase = false
	controlling = fighter
	attack_count_combat = 0


## Cards attached to any of this player's personalities.
func attachments() -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for c in in_play:
		if c.attached_to != null:
			out.append(c)
	return out


## Remain cards sitting in play for this Combat.
func remain_cards() -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for c in in_play:
		if c.remain > 0:
			out.append(c)
	return out


func _of_type(t: CardDef.Type) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for c in in_play:
		if c.def.type == t and c.attached_to == null and c.remain == 0:
			out.append(c)
	return out
