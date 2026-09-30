class_name AdventureShop
extends RefCounted
## The Shop node. It sells single cards for Mana, the run's own currency. The stock is rolled once
## per Shop from the run seed and the node id, from the cards a reward could give this run
## (`AdventureRewards.eligible_cards`), and saved with the run, so a reopened Shop shows the same
## cards and what was sold. There is no reroll. A bought card joins the run deck at once and counts
## as a run gain. The run stands on the node with status "shop" until the player leaves.

const KIND_BUY: String = "buy"

## Why one slot cannot be bought, as a short tag.
const BLOCK_SOLD: String = "Sold"
const BLOCK_MANA: String = "Not enough Mana"
const BLOCK_LIMIT: String = "At its limit"
const BLOCK_FULL: String = "Deck is full"
const BLOCK_ILLEGAL: String = "Does not fit the deck"
const BLOCK_CLOSED: String = "Not in a Shop"


static func is_open(run: AdventureRun) -> bool:
	return run != null and run.status == "shop"


## Rolls the stock of the Shop the run stands on, the first time only.
static func open(run: AdventureRun, library: CardLibrary) -> void:
	if not is_open(run) or run.shops.has(run.node_id):
		return
	var sold: Array[int] = []
	run.shops[run.node_id] = {"stock": roll(run, library, run.node_id), "sold": sold}


## The stock a Shop on node `id` would hold for the run as it stands: the first cards of a seeded
## shuffle of everything the run could gain.
static func roll(run: AdventureRun, library: CardLibrary, id: String) -> Array[String]:
	var pool: Array[String] = AdventureRewards.eligible_cards(run, library)
	var rng: ZenithRng = ZenithRng.new(run.shop_seed(id))
	rng.shuffle(pool)
	var out: Array[String] = []
	for card in pool:
		if out.size() >= AdventureEconomy.shop_stock_size():
			break
		out.append(card)
	return out


## The saved stock of the Shop the run stands on, one card id per slot. Empty before `open`.
static func stock(run: AdventureRun) -> Array[String]:
	var out: Array[String] = []
	var row: Dictionary = run.shops.get(run.node_id, {})
	for id in row.get("stock", []):
		out.append(str(id))
	return out


static func is_sold(run: AdventureRun, slot: int) -> bool:
	var row: Dictionary = run.shops.get(run.node_id, {})
	return (row.get("sold", []) as Array).has(slot)


static func price(library: CardLibrary, id: String) -> int:
	var def: CardDef = library.defs.get(id)
	return AdventureEconomy.mana_price(def) if def != null else 0


## Why the card in `slot` cannot be bought now, as a short tag, or "" when it can. A card is checked
## against the deck as it stands, since an earlier buy or a Forge copy can have filled its limit
## since the stock was rolled.
static func slot_block(run: AdventureRun, library: CardLibrary, slot: int) -> String:
	var cards: Array[String] = stock(run)
	if not is_open(run) or slot < 0 or slot >= cards.size():
		return BLOCK_CLOSED
	if is_sold(run, slot):
		return BLOCK_SOLD
	var id: String = cards[slot]
	var def: CardDef = library.defs.get(id)
	var trial: DeckList = run.deck()
	if def == null or trial == null:
		return BLOCK_ILLEGAL
	if trial.total_cards() + 1 > AdventureForge.max_size(run):
		return BLOCK_FULL
	trial.cards.append(id)
	if not DeckValidator.validate(trial, library).is_empty():
		return BLOCK_LIMIT if run.cards.count(id) >= def.limit_per_deck else BLOCK_ILLEGAL
	if run.mana < price(library, id):
		return BLOCK_MANA
	return ""


## Buys the card in `slot`: Mana drops by its price, the card joins the run deck, the buy is recorded
## as a pick and the slot is sold. The Shop stays open for more. False, and nothing moves, when the
## slot is blocked.
static func buy(run: AdventureRun, library: CardLibrary, slot: int) -> bool:
	if slot_block(run, library, slot) != "":
		return false
	var id: String = stock(run)[slot]
	if not run.spend_mana(price(library, id)):
		return false
	run.cards.append(id)
	AdventureRewards.record(run, KIND_BUY, id)
	var row: Dictionary = run.shops[run.node_id]
	var sold: Array[int] = []
	for s in row.get("sold", []):
		sold.append(int(s))
	sold.append(slot)
	row["sold"] = sold
	return true


## Ends the visit. What was bought stays bought.
static func leave(run: AdventureRun) -> void:
	if is_open(run):
		run.status = "map"
