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
		var duelist: CardDef = lib.defs.get(deck.duelist_id)
		print("")
		print("=== %s  style=%s  duelist=%s  candidates=%d" % [
			starter_id, deck.style, deck.duelist_id,
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
				stage_number, opponent, run.deck().total_cards(), run.aspects,
				", ".join(shown) if shown.size() > 0 else "(none)"])
			if not run.pending_offer.is_empty():
				AdventureRewards.apply_pick(run, lib, run.pending_offer[0])
			else:
				AdventureRewards.apply_skip(run)
			AdventureRewards.finish_reward(run, ladder)
		print("end: %s, %d cards, %d aspects" % [run.status, run.deck().total_cards(), run.aspects])
	quit(0)


static func _describe(lib: CardLibrary, duelist: CardDef, id: String) -> String:
	var def: CardDef = lib.defs.get(id)
	if def == null:
		return "%s [missing]" % id
	var school: String = def.school if def.school != "" else "freestyle"
	var signature: String = " SIG" if def.character != "" and def.character == duelist.character else ""
	return "%s (%s%s)" % [id, school, signature]
