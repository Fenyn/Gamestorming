extends SceneTree
## Prints the reward offers of an all-wins, always-pick-the-first run for every playable starter.
## godot --headless --path zenith -s tools/adventure_offers.gd

const RUN_SEED: int = 20260920


func _init() -> void:
	var lib: CardLibrary = CardLibrary.new()
	lib.load_dir("res://data/cards")
	for starter_id in AdventureLadder.playable_starters():
		var ladder: AdventureLadder = AdventureLadder.load_for(starter_id)
		var run: AdventureRun = AdventureRun.begin(starter_id, RUN_SEED)
		if ladder == null or run == null:
			print("skip %s: no ladder or no starter deck" % starter_id)
			continue
		var deck: DeckList = run.deck()
		var duelist: CardDef = lib.defs.get(deck.duelist_face_id())
		print("")
		print("=== %s  style=%s  duelist=%s  candidates=%d" % [
			starter_id, deck.style, ", ".join(deck.duelist_ids),
			AdventureRewards.candidates(run, lib).size()])
		print("%-5s %-22s %5s %7s  %s" % ["stage", "opponent", "cards", "aspects", "offer"])
		while run.status != "won" and run.status != "lost":
			var row: Dictionary = ladder.stage(run.stage)
			var stage_number: int = run.stage + 1
			var opponent: String = str(row.get("opponent", ""))
			AdventureRewards.finish_stage(run, ladder, lib, true)
			var shown: PackedStringArray = PackedStringArray()
			for id in run.pending_offer:
				shown.append(_describe(lib, duelist, id))
			print("%-5d %-22s %5d %7d  %s" % [
				stage_number, opponent, run.deck().total_cards(), run.aspects(),
				", ".join(shown) if shown.size() > 0 else "(none)"])
			if not run.pending_offer.is_empty():
				AdventureRewards.apply_pick(run, lib, run.pending_offer[0])
			else:
				AdventureRewards.apply_skip(run)
			AdventureRewards.finish_reward(run, ladder)
		print("end: %s, %d cards, %d aspects (%s)" % [run.status, run.deck().total_cards(), run.aspects(), ", ".join(run.duelist_ids)])
	quit(0)


static func _describe(lib: CardLibrary, duelist: CardDef, id: String) -> String:
	var def: CardDef = lib.defs.get(id)
	if def == null:
		return "%s [missing]" % id
	# The group is what the card is; "own" marks the run duelist's own Signature cards, which are
	# the ones the offer rules let in on top of the deck's Style.
	var group: String = def.card_group()
	var own: String = " own" if def.is_signature() and def.character == duelist.character else ""
	return "%s (%s%s)" % [id, group, own]
