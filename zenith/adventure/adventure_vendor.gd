class_name AdventureVendor
extends RefCounted
## The card vendor: a short rotating shelf of cards sold outright into the collection for Motes.
## The shelf is a function of the wallet's `stock_seed` and what the collection already holds, so
## it is not stored as a list and cannot drift out of step with the save.
##
## Masteries and Relics are out because a deck names one of each and neither is bought a copy at a
## time. Seals are out because they are held for a reward route of their own (design 12.1). A card
## that an XP milestone or an achievement gives is never sold (design 8).

## What the shelf is drawn from. A card of any other type is on sale.
const EXCLUDED_TYPES: Array[int] = [
	CardDef.Type.MASTERY, CardDef.Type.RELIC, CardDef.Type.SEAL,
]

## Used when the wallet has never rolled a seed. Never zero, so a shelf is never "unseeded".
const DEFAULT_SEED: int = 1


## Every card the vendor would ever stock, sorted, before the collection is consulted.
static func pool(library: CardLibrary) -> Array[String]:
	var out: Array[String] = []
	var exclusive: Array[String] = AdventureProgress.exclusive_ids()
	for id in library.all_ids():
		var def: CardDef = library.defs[id]
		if EXCLUDED_TYPES.has(int(def.type)) or exclusive.has(id):
			continue
		out.append(id)
	return out


static func seed_of(wallet: AdventureWallet) -> int:
	if wallet == null or wallet.stock_seed == 0:
		return DEFAULT_SEED
	return wallet.stock_seed


## Today's shelf: the first cards of a seeded shuffle of the pool that the collection still has
## room for. Walking a fixed shuffle rather than shuffling what is left means buying one card
## slides the next one in and leaves the rest of the shelf where it was.
static func stock(wallet: AdventureWallet, collection: AdventureCollection,
		library: CardLibrary) -> Array[String]:
	var shuffled: Array[String] = pool(library)
	var rng: ZenithRng = ZenithRng.new(seed_of(wallet))
	rng.shuffle(shuffled)
	var want: int = AdventureEconomy.vendor_stock_size()
	var out: Array[String] = []
	for id in shuffled:
		if out.size() >= want:
			break
		if collection != null and collection.is_full(id, library):
			continue
		out.append(id)
	return out


## What one copy costs off the shelf. The same price the collection pays anywhere else.
static func price(id: String, library: CardLibrary) -> int:
	var def: CardDef = library.defs.get(id)
	return AdventureEconomy.price(def) if def != null else 0


## Rolls a new shelf. `paid` charges the reroll fee first and refuses when the wallet is short,
## which is the once-per-visit reroll; the free call is the automatic roll at the end of a run.
static func reroll(wallet: AdventureWallet, paid: bool) -> bool:
	if wallet == null:
		return false
	if paid and not wallet.spend(AdventureEconomy.vendor_reroll_fee(), AdventureWallet.REASON_REROLL):
		return false
	wallet.stock_seed = _next_seed(seed_of(wallet))
	return true


## Buys one copy of a card on the shelf into the collection. False, and nothing moves, when it is
## not on the shelf, the wallet is short, or the collection is already full of it.
static func buy(id: String, wallet: AdventureWallet, collection: AdventureCollection,
		library: CardLibrary) -> bool:
	if wallet == null or collection == null:
		return false
	if not stock(wallet, collection, library).has(id):
		return false
	if collection.is_full(id, library):
		return false
	var cost: int = price(id, library)
	if not wallet.spend(cost, AdventureWallet.REASON_BUY, id):
		return false
	collection.add(id, 1, library)
	return true


## The next seed in the chain. Deterministic and never the one it came from, so a reroll always
## moves and a test can predict it. Same mix as AdventureRun.
static func _next_seed(seed_value: int) -> int:
	var h: int = seed_value * 0x9E3779B1 + 0x85EBCA77
	h = (h ^ (h >> 33)) * 0xFF51AFD7
	h = (h ^ (h >> 29)) * 0xC2B2AE35
	h = h ^ (h >> 32)
	return (h & 0x3FFFFFFF) + 1
