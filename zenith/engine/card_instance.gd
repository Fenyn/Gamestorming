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
var energy: int = 0
var power_used_turn: int = -1
var power_used_combat: int = -1
var shield_used_combat: int = -1
var power_uses_combat: int = 0    # how many times the Power fired this Combat (for uses > 1)
var remain: int = 0               # uses left while sitting in play as a Remain card
var remain_combat: int = -1       # the Combat the Remain card belongs to
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
		aspect = def.lowest_aspect()


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
	c.energy = energy
	c.power_used_turn = power_used_turn
	c.power_used_combat = power_used_combat
	c.shield_used_combat = shield_used_combat
	c.power_uses_combat = power_uses_combat
	c.remain = remain
	c.remain_combat = remain_combat
	c.cards_under = cards_under
	c.attached_to = attached_to
	c.named_card = named_card
	c.bond_timer = bond_timer


func aspect_data() -> Dictionary:
	return def.aspect_data(aspect)


func surge() -> int:
	return int(aspect_data().get("surge", 0))


func is_wild() -> bool:
	return bool(aspect_data().get("wild", false))


## Might at the current Energy stage.
func might() -> int:
	var arr: Array = aspect_data().get("might", [])
	if arr.is_empty():
		return 0
	var idx: int = clampi(energy, 0, arr.size() - 1)
	return int(arr[idx])


func power() -> Dictionary:
	return aspect_data().get("power", {})


func aspect_shield() -> String:
	return str(aspect_data().get("shield", ""))


func describe() -> String:
	if def == null:
		return "#%d" % uid
	return "%s#%d" % [def.title, uid]
