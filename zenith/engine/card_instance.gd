class_name CardInstance
extends RefCounted
## One physical card in a game. Mutable state lives here; the definition never changes.

const MAX_STAGE: int = 10

var uid: int = 0
var def: CardDef = null
var owner: int = 0
var controller: int = 0
var zone: StringName = &"none"   # life_deck, hand, discard, removed, in_play, fighter, grounds, side, armory, resolving, under
var tier: int = 1
var vigor: int = 0
var power_used_turn: int = -1
var power_used_tier: int = -1
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
		tier = def.lowest_tier()


func tier_data() -> Dictionary:
	return def.tier_data(tier)


func surge() -> int:
	return int(tier_data().get("surge", 0))


func is_wild() -> bool:
	return bool(tier_data().get("wild", false))


## Might at the current Vigor stage.
func might() -> int:
	var arr: Array = tier_data().get("might", [])
	if arr.is_empty():
		return 0
	var idx: int = clampi(vigor, 0, arr.size() - 1)
	return int(arr[idx])


func power() -> Dictionary:
	return tier_data().get("power", {})


func tier_shield() -> String:
	return str(tier_data().get("shield", ""))


func describe() -> String:
	if def == null:
		return "#%d" % uid
	return "%s#%d" % [def.title, uid]
