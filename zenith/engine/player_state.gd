class_name PlayerState
extends RefCounted
## Everything one player owns or controls, plus per-turn and per-Combat flags.

var index: int = 0
var name: String = ""
var alignment: String = "vigil"   # vigil | pact
var style: String = ""               # "freestyle" or a school word, set by the Mastery
var archetype: String = ""           # Archetype id the deck declares; public
var subthemes: Array[String] = []    # Archetype subtheme ids; public
var duelist: CardInstance = null
var highest_aspect: int = 1
var fervor: int = 0
var fervor_needed: int = DuelEngine.FERVOR_TO_ASPECT   # base; DuelEngine.fervor_needed layers standing effects on top
var mastery: CardInstance = null
var relic: CardInstance = null
var reserve: Array[CardInstance] = []
var life_deck: Array[CardInstance] = []   # index 0 is the top
var hand: Array[CardInstance] = []
var discard: Array[CardInstance] = []     # last element is the top
var removed: Array[CardInstance] = []
var in_play: Array[CardInstance] = []     # allies, drills, non-combats, seals (by controller)
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
var seal_victory_pending: bool = false
var no_ascension_win: bool = false          # a card effect forbade the Ascension win for the game
var relic_uses: int = 0                # how many times the Relic's power has been used
var combat_cards_used_combat: int = -1  # last Combat in which this player used a Combat-type card
var attack_count_combat: int = 0        # attacks performed this Combat (for "first attack" powers)
var last_searched: int = -1             # uid of the last card a search put into hand or play
var pending_fight_back: Array[Dictionary] = []   # wound-triggered effects waiting for the next fight-back phase
var must_declare_combat: bool = false    # forced by an opponent's card this turn


## A copy for a simulated engine. `cards` maps uid to that engine's own CardInstance.
func copy(cards: Dictionary) -> PlayerState:
	var p: PlayerState = PlayerState.new()
	p.index = index
	p.name = name
	p.alignment = alignment
	p.style = style
	p.archetype = archetype
	p.subthemes = subthemes.duplicate()
	p.duelist = _mapped(duelist, cards)
	p.highest_aspect = highest_aspect
	p.fervor = fervor
	p.fervor_needed = fervor_needed
	p.mastery = _mapped(mastery, cards)
	p.relic = _mapped(relic, cards)
	p.reserve = _mapped_list(reserve, cards)
	p.life_deck = _mapped_list(life_deck, cards)
	p.hand = _mapped_list(hand, cards)
	p.discard = _mapped_list(discard, cards)
	p.removed = _mapped_list(removed, cards)
	p.in_play = _mapped_list(in_play, cards)
	p.controlling = _mapped(controlling, cards)
	p.combat_declared = combat_declared
	p.placed_grounds = placed_grounds
	p.cannot_declare_combat = cannot_declare_combat
	p.final_strike_used = final_strike_used
	p.must_pass = must_pass
	p.skip_next_attack_phase = skip_next_attack_phase
	p.seal_victory_pending = seal_victory_pending
	p.no_ascension_win = no_ascension_win
	p.relic_uses = relic_uses
	p.combat_cards_used_combat = combat_cards_used_combat
	p.attack_count_combat = attack_count_combat
	p.last_searched = last_searched
	p.pending_fight_back = pending_fight_back.duplicate(true)
	p.must_declare_combat = must_declare_combat
	return p


static func _mapped(c: CardInstance, cards: Dictionary) -> CardInstance:
	return cards[c.uid] if c != null else null


static func _mapped_list(list: Array[CardInstance], cards: Dictionary) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for c in list:
		out.append(cards[c.uid])
	return out


func in_control() -> CardInstance:
	return controlling if controlling != null else duelist


func energy() -> int:
	return duelist.energy


func allies() -> Array[CardInstance]:
	return _of_type(CardDef.Type.ALLY)


func drills() -> Array[CardInstance]:
	return _of_type(CardDef.Type.DRILL)


func non_combats() -> Array[CardInstance]:
	return _of_type(CardDef.Type.NON_COMBAT)


func seals() -> Array[CardInstance]:
	return _of_type(CardDef.Type.SEAL)


func seals_of_set(set_name: String) -> int:
	var n: int = 0
	for c in seals():
		if c.def.seal_set == set_name:
			n += 1
	return n


## School word of the styled Drills in play, or "" if none.
func drill_school() -> String:
	for d in drills():
		if d.def.school != "":
			return d.def.school
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
	controlling = duelist
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
