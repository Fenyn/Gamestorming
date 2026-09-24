class_name AdventureDev
extends RefCounted
## Dev-flag helpers shared by the adventure screens, so a screen opened straight from the command
## line can show any state. Everything here builds the run in memory only; the player's save is
## never read or written.

const DEV_SEED: int = 12345
const SHOT_DELAY: float = 0.5


static func args() -> PackedStringArray:
	return OS.get_cmdline_user_args()


## The value after `prefix`, taking the last match, or "" when no argument carries it.
static func flag(prefix: String) -> String:
	var out: String = ""
	for arg in args():
		if arg.begins_with(prefix):
			out = arg.get_slice("=", 1)
	return out


static func has_flag(name: String) -> bool:
	return args().has(name)


static func reduced_motion() -> bool:
	return ArcaneBackdrop.motion_reduced()


## Puts an unsaved run for `starter_id` into Session. False when the starter or its map is
## missing, leaving Session as it was.
static func begin_run(starter_id: String) -> bool:
	var run: AdventureRun = AdventureRun.begin(starter_id, DEV_SEED)
	var map: AdventureMap = AdventureMap.generate(starter_id, DEV_SEED)
	if run == null or map == null:
		return false
	AdventureProgress.prepare_run(run, Session.library, Session.collection, Session.unlocks)
	Session.run = run
	Session.map = map
	return true


## Wins `duels` duels of the Session run in memory, taking the first choice, the first Aspect and
## the first bundle every time, so a dev screen can open part way through a run. Stops early at the
## end of the run. Nothing is saved and no Motes move.
static func walk(duels: int) -> void:
	var run: AdventureRun = Session.run
	for i in range(duels):
		if not run.walk_to_next_duel(Session.map):
			return
		AdventureRewards.finish_stage(run, Session.map, Session.library, true)
		_take_firsts(run)
		AdventureRewards.finish_reward(run, Session.map)
		if run.status != "map":
			return


static func _take_firsts(run: AdventureRun) -> void:
	if run.status == "aspect" and not run.pending_aspects.is_empty():
		AdventureRewards.apply_aspect(run, Session.library, run.pending_aspects[0])
		AdventureRewards.finish_aspect(run, Session.map, Session.library)
	if run.pending_offer.is_empty():
		AdventureRewards.apply_skip(run)
	else:
		AdventureRewards.apply_bundle(run, Session.library, run.pending_offer[0])


## Where a dev screen's wallet, collection and run are written. `--dev-scratch=<dir>` names it;
## the fallback is the engine's cache folder, which is not the game's own user:// save folder.
static func scratch_dir() -> String:
	var dir: String = flag("--dev-scratch=")
	return dir if dir != "" else OS.get_cache_dir().path_join("adventure_dev")


## Points the wallet, collection, upgrades and run saves at the scratch folder and empties them in
## memory, so a dev screen can spend, buy and settle without the player's save being touched.
static func use_scratch_saves() -> void:
	var dir: String = scratch_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	AdventureWallet.path_override = dir.path_join("wallet.json")
	AdventureCollection.path_override = dir.path_join("collection.json")
	AdventureUpgrades.path_override = dir.path_join("upgrades.json")
	AdventureSave.path_override = dir.path_join("run.json")
	AdventureUnlocks.path_override = dir.path_join("unlocks.json")
	AdventureProgress.path_override = dir.path_join("progress.json")
	Session.unlocks = AdventureUnlocks.new()
	Session.progress = AdventureProgress.new()
	Session.wallet = AdventureWallet.new()
	Session.collection = AdventureCollection.new()
	Session.upgrades = AdventureUpgrades.new()
	Session.dissolve_report = {}


## Sets the scratch wallet's balance outright, with no ledger line: a starting balance is not
## something the run earned. `--dev-motes=N` names the amount; the caller's own default stands
## when the flag is absent.
static func give_motes(amount: int) -> void:
	var flagged: String = flag("--dev-motes=")
	Session.wallet.motes = maxi(0, int(flagged) if flagged != "" else amount)


## `--dev-upgrades=<slots>` presets the scratch upgrades for one starter outright, with no Motes
## spent: a preset is not something the player bought.
static func preset_upgrades(starter_id: String) -> void:
	var arg: String = flag("--dev-upgrades=")
	if arg == "" or arg.get_slice(",", 0) == "":
		return
	Session.upgrades.rows[starter_id] = {"extra_slots": maxi(0, int(arg.get_slice(",", 0)))}


## Puts `each` copies of every id into the scratch collection, capped the way the collection caps
## anything. Ids the library does not know are skipped.
static func stock_collection(ids: Array[String], each: int = 1) -> void:
	for id in ids:
		if Session.library.defs.has(id):
			Session.collection.add(id, each, Session.library)


## Plays a whole run in memory, taking the first choice, the first Aspect and the first bundle at
## every step, and credits the payouts to the scratch wallet. `lose_at` is the 0-based duel the run
## falls at, or -1 to beat the final boss. False when the starter has no map.
static func simulate_run(starter_id: String, lose_at: int = -1) -> bool:
	if not begin_run(starter_id):
		return false
	var run: AdventureRun = Session.run
	while run.status != "won" and run.status != "lost":
		if not run.walk_to_next_duel(Session.map):
			return false
		var won: bool = lose_at < 0 or run.stage < lose_at
		var payout: int = AdventureRewards.finish_stage(run, Session.map, Session.library, won)
		if payout > 0:
			Session.wallet.earn(payout, AdventureWallet.REASON_STAGE, run.run_id, run.stage)
		if not won:
			break
		_take_firsts(run)
		var bonus: int = AdventureRewards.finish_reward(run, Session.map)
		if bonus > 0:
			Session.wallet.earn(bonus, AdventureWallet.REASON_COMPLETION, run.run_id)
	return true


## `--dev-screenshot=<png>` saves the screen once it has settled, then quits.
static func screenshot(node: Node) -> void:
	var path: String = flag("--dev-screenshot=")
	if path == "":
		return
	await node.get_tree().create_timer(SHOT_DELAY).timeout
	await RenderingServer.frame_post_draw
	node.get_viewport().get_texture().get_image().save_png(path)
	print("screenshot saved to %s" % path)
	node.get_tree().quit()
