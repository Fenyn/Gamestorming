class_name AdventureDev
extends RefCounted
## Dev-flag helpers shared by the adventure screens, so a screen opened straight from the command
## line can show any state. Everything here builds the run in memory only; the player's save is
## never read or written.

const DEV_SEED: int = 12345
const SHOT_DELAY: float = 0.5

## True once `begin_run` has put an unsaved run in Session, so a screen the dev run moves on to
## changes it in memory instead of saving it over the player's run.
static var in_memory: bool = false


static func args() -> PackedStringArray:
	return DevArgs.user_args()


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
	in_memory = true
	return true


## Wins `duels` duels of the Session run in memory, taking the first choice, the first Aspect and
## the first bundle every time and nothing at an Elite's claim, so a dev screen can open part way
## through a run. Stops early at the end of the run. Nothing is saved and no Motes move.
static func walk(duels: int) -> void:
	var run: AdventureRun = Session.run
	for i in range(duels):
		if not run.walk_to_next_duel(Session.map, Session.library):
			return
		AdventureRewards.finish_stage(run, Session.map, Session.library, true)
		_take_firsts(run)
		AdventureRewards.finish_reward(run, Session.map)
		AdventureShrine.leave(run)
		if run.status != "map":
			return


## Walks the Session run along the map to the next stop of `type` and leaves it waiting there, so a
## dev screen opens on a run whose act, duels won and deck agree. At a fork it takes that stop when
## offered, else a road that still reaches one; fights on the way are won with the first Aspect and
## bundle, and other stops are left untouched. A fighting type stops on the fight with its duel
## still to play. With no such stop ahead it waits on the node it stands on.
static func stand_on_next(type: String) -> void:
	var run: AdventureRun = Session.run
	var map: AdventureMap = Session.map
	var guard: int = 0
	while not _arrived(run, map, type) and guard < 200:
		guard += 1
		if run.status == "map":
			var next: Array[String] = run.choices(map)
			if next.is_empty():
				break
			run.enter(map, _step_towards(map, next, type))
		elif not _settle(run, map):
			break
	if run.status == "map" and not AdventureMap.is_fight(type):
		run.status = type


## Walks the Session run until a node of `type` is one of its choices, fights and stops on the way
## settled as `stand_on_next` settles them, so the map opens with that node to pick. Returns its id,
## "" when none lies ahead.
static func choose_next(type: String) -> String:
	var run: AdventureRun = Session.run
	var map: AdventureMap = Session.map
	for _step in range(200):
		if run.status != "map":
			if not _settle(run, map):
				return ""
			continue
		var next: Array[String] = run.choices(map)
		for id in next:
			if str(map.node(id).get("type", "")) == type:
				return id
		if next.is_empty():
			return ""
		run.enter(map, _step_towards(map, next, type))
	return ""


## Ends whatever the run stands on the way the walks do: leaves a stop untouched, passes the Relic
## node, wins a fight with the first Aspect and bundle. False for a status it cannot end.
static func _settle(run: AdventureRun, map: AdventureMap) -> bool:
	match run.status:
		"forge":
			AdventureForge.leave(run)
		"shop":
			AdventureShop.leave(run)
		AdventureShrine.STATUS, AdventureShrine.CLAIM_STATUS:
			AdventureShrine.leave(run)
		AdventureRelic.STATUS_OFFERS, AdventureRelic.STATUS_TRIM:
			AdventureRelic.pass_through(run, Session.library)
		"stage":
			AdventureRewards.finish_stage(run, map, Session.library, true)
			_take_firsts(run)
			AdventureRewards.finish_reward(run, map)
		_:
			return false
	return true


## Wins the next Elite in memory, its Aspect and bundle taken as `walk` takes them, and leaves the
## run on the Resonance claim that follows. False when no Elite lies ahead or the claim had nothing
## to offer.
static func claim_next_elite() -> bool:
	var run: AdventureRun = Session.run
	stand_on_next("elite")
	if run.status != "stage" or str(Session.map.node(run.node_id).get("type", "")) != "elite":
		return false
	AdventureRewards.finish_stage(run, Session.map, Session.library, true)
	_take_firsts(run)
	AdventureRewards.finish_reward(run, Session.map)
	return AdventureShrine.is_claim(run)


static func _arrived(run: AdventureRun, map: AdventureMap, type: String) -> bool:
	if AdventureMap.is_fight(type):
		return run.status == "stage" and str(map.node(run.node_id).get("type", "")) == type
	return run.status == type


static func _step_towards(map: AdventureMap, next: Array[String], type: String) -> String:
	for id in next:
		if str(map.node(id).get("type", "")) == type:
			return id
	for id in next:
		if _reaches(map, id, type):
			return id
	return next[0]


static func _reaches(map: AdventureMap, from: String, type: String) -> bool:
	var seen: Dictionary = {}
	var queue: Array[String] = [from]
	while not queue.is_empty():
		var id: String = queue.pop_front()
		if seen.has(id):
			continue
		seen[id] = true
		if str(map.node(id).get("type", "")) == type:
			return true
		queue.append_array(map.next_of(id))
	return false


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
	AdventureStoryLog.path_override = dir.path_join("story_log.json")
	Session.story_log = AdventureStoryLog.new()
	Session.unlocks = AdventureUnlocks.new()
	Session.progress = AdventureProgress.new()
	Session.wallet = AdventureWallet.new()
	Session.collection = AdventureCollection.new()
	Session.upgrades = AdventureUpgrades.new()
	Session.dissolve_report = {}


## Fills the in-memory unlocks and XP with a mid-game spread, for journal and reward screenshots:
## some achievements done, a hidden one revealed, XP across several characters and schools.
static func sample_meta() -> void:
	var u: AdventureUnlocks = Session.unlocks
	AdventureAchievements.apply(u, [
		{"event": "duel_won", "starter": "tide_deepwater_start", "node": "boss", "act": 2},
		{"event": "duel_won", "main": "Sir Edric Rooke", "opponent": "Bram Ashmark", "act": 1},
		{"event": "run_won", "main": "Gideon Mourne"},
		{"event": "duel_won", "main": "Bram Ashmark", "opponent": "Siphon", "node": "boss", "act": 1, "blocks": 0},
	] as Array[Dictionary])
	var p: AdventureProgress = Session.progress
	p.personality_xp = {"Sir Edric Rooke": 520, "Emrys Rooke": 130, "Dame Alder Rooke": 45,
		"Gideon Mourne": 260, "Bram Ashmark": 90, "Caedan Vale": 20, "Siphon": 15}
	p.school_xp = {"tide": 610, "shade": 230, "pyre": 95}
	for a in AdventureAchievements.all():
		if u.is_complete(str(a.get("id", ""))) and str(a.get("starter", "")) != "":
			u.unlock(str(a["starter"]))
	for key in p.personality_xp.keys():
		p.paid["personality:%s" % key] = p.personality_level(str(key))
		for m in p.milestones(str(key)):
			if bool(m["reached"]) and str((m["reward"] as Dictionary).get("starter", "")) != "":
				u.unlock(str(m["reward"]["starter"]))
	for key in p.school_xp.keys():
		p.paid["school:%s" % key] = p.school_level(str(key))
	Session.win_results = [
		{"kind": "join", "tag": "JOINED", "title": "Emrys Rooke",
			"details": ["In your deck for the rest of this run"]},
		{"kind": "xp", "tag": "XP", "title": "Sir Edric Rooke +25 XP",
			"details": ["155 XP to level 5", "Tide +25 XP, 165 XP to level 6", "Emrys Rooke +15 XP, 105 XP to level 3"],
			"bars": [_sample_bar(p, "personality", "Sir Edric Rooke", ""),
				_sample_bar(p, "school", "Tide", "tide"), _sample_bar(p, "personality", "Emrys Rooke", "")]},
		{"kind": "level", "tag": "LEVEL 4", "title": "Sir Edric Rooke",
			"details": ["Signature card: Edric's Vow", "Signature card: Edric's Training"]},
		{"kind": "achievement", "tag": "ACHIEVEMENT", "title": "The Vale test",
			"details": ["Opens deck: Blade Legacy"]},
	] as Array[Dictionary]


## One XP bar for the sample results: a 25 XP gain that ends where the track stands now, so the
## first track (Edric, just past a level) shows the roll-over.
static func _sample_bar(p: AdventureProgress, kind: String, name: String, school: String) -> Dictionary:
	var now: int = int((p.school_xp if kind == "school" else p.personality_xp).get(school if kind == "school" else name, 0))
	return {"name": name, "school": school, "gained": 25, "segments": p.xp_segments(kind, now - 25, now)}


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
		if not run.walk_to_next_duel(Session.map, Session.library):
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
	var wait: String = flag("--dev-shot-delay=")
	await node.get_tree().create_timer(float(wait) if wait != "" else SHOT_DELAY).timeout
	await RenderingServer.frame_post_draw
	node.get_viewport().get_texture().get_image().save_png(path)
	print("screenshot saved to %s" % path)
	node.get_tree().quit()
