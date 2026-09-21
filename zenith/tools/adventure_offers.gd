extends SceneTree
## Prints the bundle offers of an all-wins, always-take-the-first run for every playable starter.
## godot --headless --path zenith -s tools/adventure_offers.gd

const RUN_SEED: int = 20260920
## The stages the per-stage eligibility summary reports on; the ladder end is added to these.
const SAMPLE_STAGES: Array[int] = [0, 2, 4]


func _init() -> void:
	var lib: CardLibrary = CardLibrary.new()
	lib.load_dir("res://data/cards")
	_print_pool()
	for starter_id in AdventureLadder.playable_starters():
		_run_one(starter_id, lib)
	quit(0)


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
	var ladder: AdventureLadder = AdventureLadder.load_for(starter_id)
	var run: AdventureRun = AdventureRun.begin(starter_id, RUN_SEED)
	if ladder == null or run == null:
		print("skip %s: no ladder or no starter deck" % starter_id)
		return
	var deck: DeckList = run.deck()
	print("")
	print("=== %s  style=%s  alignment=%s  duelist=%s" % [
		starter_id, deck.style, deck.alignment, ", ".join(deck.duelist_ids)])
	# Eligibility on the starting deck, before any bundle has been taken.
	var fresh: AdventureRun = AdventureRun.begin(starter_id, RUN_SEED)
	var sample_parts: PackedStringArray = PackedStringArray()
	var stages: Array[int] = SAMPLE_STAGES.duplicate()
	stages.append(ladder.size() - 1)
	for n in stages:
		fresh.stage = n
		sample_parts.append("stage %d: %d" % [n, AdventureRewards.eligible(fresh, lib, n).size()])
	print("eligible on the starting deck  %s" % ", ".join(sample_parts))

	while run.status != "won" and run.status != "lost":
		var row: Dictionary = ladder.stage(run.stage)
		var stage_number: int = run.stage + 1
		var opponent: String = str(row.get("opponent", ""))
		var eligible_now: int = AdventureRewards.eligible(run, lib, run.stage).size()
		AdventureRewards.finish_stage(run, ladder, lib, true)
		var aspect_taken: String = "-"
		if run.status == "aspect":
			var options: Array[String] = run.pending_aspects.duplicate()
			aspect_taken = "%s (of %d)" % [options[0], options.size()]
			AdventureRewards.apply_aspect(run, lib, options[0])
			AdventureRewards.finish_aspect(run, ladder, lib)
		print("")
		print("stage %d  %-22s  deck %d  aspects %d (%s)  aspect taken: %s  eligible %d" % [
			stage_number, opponent, run.deck().total_cards(), run.aspects(),
			", ".join(run.duelist_ids), aspect_taken, eligible_now])
		if run.pending_offer.is_empty():
			print("    (no bundle offered)")
			AdventureRewards.apply_skip(run)
		else:
			for id in run.pending_offer:
				print("    %s" % _describe(lib, id))
			AdventureRewards.apply_bundle(run, lib, run.pending_offer[0])
		AdventureRewards.finish_reward(run, ladder)
	print("end: %s, %d cards, %d aspects (%s)" % [
		run.status, run.deck().total_cards(), run.aspects(), ", ".join(run.duelist_ids)])


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
