extends SceneTree
## Prints the bundle offers of an all-wins, always-take-the-first run for every playable starter.
## godot --headless --path zenith -s tools/adventure_offers.gd

const RUN_SEED: int = 20260920
## How far through the run the eligibility summary reports on: the start, each tier gate, the end.
const SAMPLE_PROGRESS: Array[float] = [0.0, 0.25, 0.5, 1.0]


## How many cards the settlement's "what would five cost" line prices.
const KEEP_SAMPLE: int = 5


func _init() -> void:
	var lib: CardLibrary = CardLibrary.new()
	lib.load_dir("res://data/cards")
	_print_pool()
	_print_economy(lib)
	for starter_id in AdventureDecks.playable_starters():
		_run_one(starter_id, lib)
	quit(0)


## The Motes side of the file as it stands: what each act pays per duel and per boss, what a band
## costs, and how much of the library sits in each band.
func _print_economy(lib: CardLibrary) -> void:
	var payouts: PackedStringArray = PackedStringArray()
	for act in range(1, 4):
		payouts.append("act %d: %d a duel, %d the boss" % [
			act, AdventureEconomy.duel_payout(act, false), AdventureEconomy.duel_payout(act, true)])
	print("")
	print("economy: %s; completion bonus %d" % ["; ".join(payouts), AdventureEconomy.completion_bonus()])
	var counts: Dictionary = {}
	for id in lib.all_ids():
		var band: String = AdventureEconomy.band(lib.defs[id])
		counts[band] = int(counts.get(band, 0)) + 1
	var band_parts: PackedStringArray = PackedStringArray()
	for band in AdventureEconomy.BANDS:
		band_parts.append("%s %d Motes (%d cards)" % [
			band, AdventureEconomy.band_price(band), int(counts.get(band, 0))])
	print("  bands: %s" % ", ".join(band_parts))
	print("  vendor: %d cards on the shelf, reroll %d Motes" % [
		AdventureEconomy.vendor_stock_size(), AdventureEconomy.vendor_reroll_fee()])


## The data file as it stands, by group and by tier.
func _print_pool() -> void:
	var by_group: Dictionary = {}
	var by_tier: Dictionary = {}
	for bundle in AdventureBundles.all():
		var group: String = str(bundle.get("group", ""))
		var tier: String = str(bundle.get("tier", ""))
		by_group[group] = int(by_group.get(group, 0)) + 1
		by_tier[tier] = int(by_tier.get(tier, 0)) + 1
	var groups: Array = by_group.keys()
	groups.sort()
	var group_parts: PackedStringArray = PackedStringArray()
	for g in groups:
		group_parts.append("%s %d" % [g, by_group[g]])
	print("bundles: %d total" % AdventureBundles.all().size())
	print("  by group: %s" % ", ".join(group_parts))
	print("  by tier: early %d, mid %d, late %d" % [
		int(by_tier.get("early", 0)), int(by_tier.get("mid", 0)), int(by_tier.get("late", 0))])


func _run_one(starter_id: String, lib: CardLibrary) -> void:
	var map: AdventureMap = AdventureMap.generate(starter_id, RUN_SEED)
	var run: AdventureRun = AdventureRun.begin(starter_id, RUN_SEED)
	if map == null or run == null:
		print("skip %s: no map or no starter deck" % starter_id)
		return
	var deck: DeckList = run.deck()
	print("")
	print("=== %s  style=%s  alignment=%s  duelist=%s" % [
		starter_id, deck.style, deck.alignment, ", ".join(deck.duelist_ids)])
	# Eligibility on the starting deck, before any bundle has been taken.
	var fresh: AdventureRun = AdventureRun.begin(starter_id, RUN_SEED)
	var sample_parts: PackedStringArray = PackedStringArray()
	for progress in SAMPLE_PROGRESS:
		sample_parts.append("%.2f: %d" % [progress, AdventureRewards.eligible(fresh, lib, progress).size()])
	print("eligible on the starting deck, by progress  %s" % ", ".join(sample_parts))

	var earned: int = 0
	while run.status != "won" and run.status != "lost":
		if not run.walk_to_next_duel(map):
			print("no fight left to reach from %s" % run.node_id)
			break
		var row: Dictionary = map.duel_for(run.node_id)
		var stage_number: int = run.stage + 1
		var opponent: String = str(row.get("opponent", ""))
		var eligible_now: int = AdventureRewards.eligible(run, lib, map.progress_of(run.node_id)).size()
		earned += AdventureRewards.finish_stage(run, map, lib, true)
		var aspect_taken: String = "-"
		if run.status == "aspect":
			var options: Array[String] = run.pending_aspects.duplicate()
			aspect_taken = "%s (of %d)" % [options[0], options.size()]
			AdventureRewards.apply_aspect(run, lib, options[0])
			AdventureRewards.finish_aspect(run, map, lib)
		print("")
		print("duel %d, %s  %-22s  deck %d  aspects %d (%s)  aspect taken: %s  eligible %d" % [
			stage_number, map.place_of(run.node_id), opponent, run.deck().total_cards(), run.aspects(),
			", ".join(run.duelist_ids), aspect_taken, eligible_now])
		if run.pending_offer.is_empty():
			print("    (no bundle offered)")
			AdventureRewards.apply_skip(run)
		else:
			for id in run.pending_offer:
				print("    %s" % _describe(lib, id))
			AdventureRewards.apply_bundle(run, lib, run.pending_offer[0])
		earned += AdventureRewards.finish_reward(run, map)
	print("end: %s, %d cards, %d aspects (%s)" % [
		run.status, run.deck().total_cards(), run.aspects(), ", ".join(run.duelist_ids)])
	_print_settlement(run, lib, earned)


## What the run-end screen would show: the Motes the run paid, how much is on offer, and what
## keeping the five cheapest of the cards the run added would cost.
func _print_settlement(run: AdventureRun, lib: CardLibrary, earned: int) -> void:
	AdventureSettlement.open(run)
	var won: bool = AdventureSettlement.won(run)
	var rows: Array[Dictionary] = AdventureSettlement.offers(run, lib, won)
	# What the run added, priced the way this run-end screen would charge for it.
	var prices: Array[int] = []
	var added: Array[String] = run.added_cards()
	added.append_array(run.added_duelist_cards())
	for id in added:
		var def: CardDef = lib.defs.get(id)
		if def == null:
			continue
		prices.append(AdventureEconomy.discount_price(def) if won else AdventureEconomy.price(def))
	var whole: int = 0
	for p in prices:
		whole += p
	prices.sort()
	var five: int = 0
	for i in range(mini(KEEP_SAMPLE, prices.size())):
		five += prices[i]
	var average: int = whole / maxi(1, prices.size())
	print("motes: earned %d, added %d cards costing %d (%d each on average), keeping the %d cheapest costs %d; the offer lists %d rows" % [
		earned, prices.size(), whole, average, KEEP_SAMPLE, five, rows.size()])


## `name [group/tier]: card x2, card`, the line the reward screen will show as a bundle.
static func _describe(lib: CardLibrary, bundle_id: String) -> String:
	var bundle: Dictionary = AdventureBundles.by_id(bundle_id)
	if bundle.is_empty():
		return "%s [missing]" % bundle_id
	var parts: PackedStringArray = PackedStringArray()
	for entry in bundle.get("cards", []):
		var card: Dictionary = entry
		var id: String = str(card.get("id", ""))
		var count: int = int(card.get("count", 1))
		var def: CardDef = lib.defs.get(id)
		var title: String = def.title if def != null else "%s?" % id
		parts.append(title if count == 1 else "%s x%d" % [title, count])
	return "%s [%s/%s]: %s" % [
		str(bundle.get("name", "")), str(bundle.get("group", "")), str(bundle.get("tier", "")),
		", ".join(parts)]
