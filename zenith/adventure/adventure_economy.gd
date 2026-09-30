class_name AdventureEconomy
extends RefCounted
## What a card costs in Motes and what a run pays out, in Motes and in Mana. Every number lives in
## data/adventure/economy.json, so a rarity system later changes that file and `band()` and
## nothing else. Data and arithmetic only: no file writing, no wallet, no run.

const PATH: String = "res://data/adventure/economy.json"

## The three price bands, cheapest first. A band is a printed tell, not a rarity: the game prints
## no rarity, so what a card allows in a deck stands in for it.
const BAND_BASE: String = "base"            # anything a deck may run three of
const BAND_LIMITED: String = "limited"      # printed at two copies, plus personalities and Grounds
const BAND_RESTRICTED: String = "restricted"  # lockouts, one-copy cards and every Seal
const BANDS: Array[String] = [BAND_BASE, BAND_LIMITED, BAND_RESTRICTED]

## Effect ops that turn off a whole card type instead of answering one card. Ported from
## `is_lockout` in tools/scale_deck.py, which is what keeps lockouts out of a starter.
const LOCKOUT_OPS: Array[String] = [
	"stop_all",
	"forbid",
	"choose_forbid_type",
	"choose_stop_all_kind",
	"cannot_declare_combat",
	"skip_next_attack_phase",
	"name_card",
]

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if not _data.is_empty():
		return _data
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not (parsed is Dictionary):
		push_error("AdventureEconomy: %s is not a JSON object" % PATH)
		return _data
	_data = parsed
	return _data


## The band a card is priced in. Personalities and Grounds sit in the middle band whatever else
## they print, because an Ally and a place are the same kind of purchase wherever they came from.
static func band(def: CardDef) -> String:
	if def == null:
		return BAND_BASE
	if def.type == CardDef.Type.SEAL:
		return BAND_RESTRICTED
	if def.type == CardDef.Type.PERSONALITY or def.type == CardDef.Type.GROUNDS:
		return BAND_LIMITED
	if def.limit_per_deck <= 1 or is_lockout(def):
		return BAND_RESTRICTED
	if def.limit_per_deck == 2:
		return BAND_LIMITED
	return BAND_BASE


## True when the card turns off a whole card type instead of answering one card. A Seal is exempt:
## a Seal is a win condition, not a combat trick, and it is priced in the top band anyway.
static func is_lockout(def: CardDef) -> bool:
	if def == null or def.type == CardDef.Type.SEAL:
		return false
	if def.defense.has("stop_all"):
		return true
	if not def.forbid.is_empty():
		return true
	return _any_lockout_op(def.effects)


## Every effect, including the ones nested inside a choice or a conditional.
static func _any_lockout_op(effects: Array) -> bool:
	for entry in effects:
		if not (entry is Dictionary):
			continue
		var e: Dictionary = entry
		if LOCKOUT_OPS.has(str(e.get("op", ""))):
			return true
		for key in ["effect", "then", "else"]:
			if e.get(key) is Dictionary and _any_lockout_op([e[key]]):
				return true
		for key in ["effects", "choices"]:
			if e.get(key) is Array and _any_lockout_op(e[key]):
				return true
	return false


static func band_price(band_name: String) -> int:
	var bands: Dictionary = data().get("bands", {})
	return int(bands.get(band_name, 0))


## What one copy costs to bank into the collection, and what the vendor sells it for.
static func price(def: CardDef) -> int:
	return band_price(band(def))


## The run-end price after beating the ladder. One-time: it is only on offer on that screen.
static func discount_price(def: CardDef) -> int:
	var full: int = price(def)
	return maxi(1, int(round(float(full) * (1.0 - float(data().get("discount_fraction", 0.0))))))


## What dissolving one collection copy pays back.
static func dissolve_value(def: CardDef) -> int:
	return int(floor(float(price(def)) * float(data().get("dissolve_fraction", 0.0))))


## Paid for winning a duel in `act` (1-based), from the per-act rows in economy.json: a later act
## pays more, and a boss more than any other fight in its act. An act past the rows pays the last.
static func duel_payout(act: int, boss: bool) -> int:
	var rows: Array = data().get("boss_payout_by_act" if boss else "duel_payout_by_act", [])
	if rows.is_empty() or act < 1:
		return 0
	return int(rows[mini(act, rows.size()) - 1])


## Paid once for beating the final boss, on top of that duel's payout.
static func completion_bonus() -> int:
	return int(data().get("completion_bonus", 0))


static func mana_start() -> int:
	return int(_mana().get("start", 0))


## Mana paid for winning a fight of `node_type` in `act` (1-based): the type's base from
## economy.json plus a step for every act after the first. A type with no row pays nothing.
static func mana_income(act: int, node_type: String) -> int:
	var income: Dictionary = _mana().get("income", {})
	if not income.has(node_type) or act < 1:
		return 0
	return int(income[node_type]) + int(_mana().get("income_per_act", 0)) * (act - 1)


## What one copy costs at a Shop, in Mana: the card's Motes band, priced from the Mana rows.
static func mana_price(def: CardDef) -> int:
	var prices: Dictionary = _mana().get("prices", {})
	return int(prices.get(band(def), 0))


static func shop_stock_size() -> int:
	return int(_mana().get("shop_stock", 0))


static func _mana() -> Dictionary:
	var block: Variant = data().get("mana", {})
	return block if block is Dictionary else {}


## The Relics a Relic node may offer, in file order.
static func relic_pool() -> Array[String]:
	return _strings(_relic().get("pool", []))


## Relics offered only to a run that holds an Ally.
static func relic_needs_ally() -> Array[String]:
	return _strings(_relic().get("needs_ally", []))


static func relic_offer_count() -> int:
	return int(_relic().get("offers", 0))


static func _relic() -> Dictionary:
	var block: Variant = data().get("relic", {})
	return block if block is Dictionary else {}


static func _strings(values: Variant) -> Array[String]:
	var out: Array[String] = []
	if values is Array:
		for value in values:
			out.append(str(value))
	return out


static func vendor_stock_size() -> int:
	return int(data().get("vendor_stock", 0))


static func vendor_reroll_fee() -> int:
	return int(data().get("vendor_reroll_fee", 0))


# --- Deck slots and Aspect tiers, bought per starter ------------------------

## What the `n`th extra deck slot costs, 1-based: a base price multiplied by a growth factor per
## slot already bought, rounded to keep the prices readable. A curve rather than a list because the
## track runs the whole way to DeckValidator's card maximum, which is a different length for every
## starter, and a list long enough for the longest one is a list nobody can read.
static func slot_cost(n: int) -> int:
	if n <= 0:
		return 0
	var base: float = float(data().get("slot_cost_base", 0))
	var growth: float = float(data().get("slot_cost_growth", 1.0))
	var step: int = maxi(1, int(data().get("slot_cost_round", 1)))
	var raw: float = base * pow(growth, float(n - 1))
	return int(round(raw / float(step))) * step


## What every slot from the 1st to the `n`th costs together, which is the number a screen shows as
## the whole track.
static func slot_cost_total(n: int) -> int:
	var sum: int = 0
	for i in range(1, n + 1):
		sum += slot_cost(i)
	return sum
