class_name CardInstance
extends RefCounted
## One physical card in a game. Mutable state lives here; the definition never changes.

const MAX_STAGE: int = 10

var uid: int = 0
var def: CardDef = null
var owner: int = 0
var controller: int = 0
var zone: StringName = &"none"   # life_deck, hand, discard, removed, in_play, duelist, grounds, side, reserve, resolving, under
var aspect: int = 1
## personalities in play: the whole Aspect stack this card belongs to. `def` is always the card
## for the current `aspect`, so character, tags, bloodline, alignment and the Aspect's own numbers
## are read off `def` and follow the climb. Shared by reference between clones and never mutated.
var stack: PersonalityStack = null
var energy: int = 0
var power_used_turn: int = -1
var power_used_combat: int = -1
var shield_used_combat: int = -1
var power_uses_combat: int = 0    # how many times the Power fired this Combat (for uses > 1)
var remain: int = 0               # uses left while sitting in play as a Remain card
var remain_combat: int = -1       # the Combat the Remain card belongs to
var attacked_combat: int = -1     # the Combat this card last performed an attack in
var silenced: bool = false        # "cannot use the power of that Drill for the remainder of the game"
var cards_under: Array[CardInstance] = []
var attached_to: CardInstance = null
var named_card: String = ""       # for "name a card" drills
var bond_timer: int = 0           # life cards placed under a Bond so far


func _init(p_uid: int, p_def: CardDef, p_owner: int) -> void:
	uid = p_uid
	def = p_def
	owner = p_owner
	controller = p_owner
	if def != null and def.is_personality():
		aspect = def.aspect


## A copy for a simulated engine. `cards_under` and `attached_to` still point at the original's
## cards; DuelEngine.clone re-points them.
func copy() -> CardInstance:
	var c: CardInstance = CardInstance.new(uid, def, owner)
	copy_into(c)
	return c


## The same, over a card that already exists. `DuelEngine.clone_into` recycles cards this way;
## allocating them was two thirds of a clone.
func copy_into(c: CardInstance) -> void:
	c.uid = uid
	c.def = def
	c.owner = owner
	c.controller = controller
	c.zone = zone
	c.aspect = aspect
	c.stack = stack
	c.energy = energy
	c.power_used_turn = power_used_turn
	c.power_used_combat = power_used_combat
	c.shield_used_combat = shield_used_combat
	c.power_uses_combat = power_uses_combat
	c.remain = remain
	c.remain_combat = remain_combat
	c.attacked_combat = attacked_combat
	c.silenced = silenced
	c.cards_under = cards_under
	c.attached_to = attached_to
	c.named_card = named_card
	c.bond_timer = bond_timer


## Moves a personality to another Aspect of its own stack, which swaps the card it is showing.
## Everything the engine reads off `def` — the Aspect's Might and Power, the keywords the
## personality carries, their bloodline and alignment gate — changes with it.
func go_to_aspect(n: int) -> void:
	aspect = n
	if stack == null:
		return
	var d: CardDef = stack.def_for(n)
	if d != null:
		def = d


## The stack's public card ids, lowest Aspect first. Empty for a card with no stack.
func ladder() -> Array[String]:
	return stack.card_ids() if stack != null else ([] as Array[String])


func aspect_data() -> Dictionary:
	return def.aspect_data(aspect)


func surge() -> int:
	return int(aspect_data().get("surge", 0))


func is_wild() -> bool:
	return bool(aspect_data().get("wild", false))


## Might at the current Energy stage.
func might() -> int:
	return might_at(energy)


## Might this Aspect prints at a given Energy stage. Nothing in the rules modifies a printed Might,
## so this is the whole of it: the number moves only with the Aspect and the Energy stage.
func might_at(stage: int) -> int:
	var arr: Array = aspect_data().get("might", [])
	if arr.is_empty():
		return 0
	var idx: int = clampi(stage, 0, arr.size() - 1)
	return int(arr[idx])


func power() -> Dictionary:
	return aspect_data().get("power", {})


## The second Power on an Aspect that prints two. It is used instead of the first, never as well
## as it: the Power itself is still once per turn.
func power_alt() -> Dictionary:
	return aspect_data().get("power_alt", {})


func aspect_shield() -> String:
	return str(aspect_data().get("shield", ""))


func describe() -> String:
	if def == null:
		return "#%d" % uid
	return "%s#%d" % [def.title, uid]
