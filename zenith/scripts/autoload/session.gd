extends Node
## Session: what the select screen chose, carried into the duel scene.
## Also owns the loaded card library, strike table, available decks, and the live adventure run
## with its node map; the adventure block at the bottom moves that run between screens and the save.

const CARDS_DIR: String = "res://data/cards"
const DECKS_DIR: String = "res://data/decks"
const TABLE_PATH: String = "res://data/strike_table.json"
const DUEL_SCENE: String = "res://scenes/duel/duel.tscn"
const SELECT_SCENE: String = "res://scenes/select/duelist_select.tscn"
const VERSUS_SCENE: String = "res://scenes/select/versus.tscn"
const TITLE_SCENE: String = "res://scenes/main.tscn"
const ADVENTURE_START_SCENE: String = "res://scenes/adventure/adventure_start.tscn"
const ADVENTURE_STAGE_SCENE: String = "res://scenes/adventure/stage.tscn"
const ADVENTURE_REWARD_SCENE: String = "res://scenes/adventure/reward.tscn"
const ADVENTURE_SETTLE_SCENE: String = "res://scenes/adventure/settle.tscn"
const ADVENTURE_VENDOR_SCENE: String = "res://scenes/adventure/vendor.tscn"
const ADVENTURE_LOADOUT_SCENE: String = "res://scenes/adventure/loadout.tscn"
const ADVENTURE_JOURNAL_SCENE: String = "res://scenes/adventure/journal.tscn"

var library: CardLibrary = CardLibrary.new()
var strike_table: StrikeTable = null
var decks: Array[DeckList] = []
var chosen: Array[DeckList] = [null, null]
var locked: Array[bool] = [false, false]   # each seat confirmed its pick on the select screen
var player_names: Array[String] = ["Player 1", "Player 2"]
var seed_value: int = 0   # 0 means pick one at random when the duel starts
var last_seed: int = 0
## Seed for cosmetics only (the per-battle seat colours). Derived from the duel seed so both
## sides of an online duel agree, but it does not hand a client the shuffle order.
var color_seed: int = 0
var ai_seat: int = -1               # the seat an AiPlayer drives, -1 for none. Offline only.
var ai_profile: String = "default"  # level file under AiProfile.DIR, without .json
var run: AdventureRun = null        # the live adventure run, null outside adventure mode
var map: AdventureMap = null        # the run's node map, rolled again from its seed on load
## Motes and the card collection. Both outlive a run, so they are loaded once here and saved by
## whichever call spends or earns.
var wallet: AdventureWallet = AdventureWallet.new()
var collection: AdventureCollection = AdventureCollection.new()
## Deck slots bought per starter. Outlives a run like the other two.
var upgrades: AdventureUpgrades = AdventureUpgrades.new()
## Open starters, achievement progress and deck abilities. Outlives a run.
var unlocks: AdventureUnlocks = AdventureUnlocks.new()
## School and personality XP. Outlives a run.
var progress: AdventureProgress = AdventureProgress.new()
## Who the mains have met and which lead-in lines were shown. Outlives a run.
var story_log: AdventureStoryLog = AdventureStoryLog.new()
## The lead-in the duel scene plays over its opening before the next duel, {} for none.
var lead_in: Dictionary = {}
## What the last won duel gave, as AdventureProgress.record_win entries. Kept until the reward
## screen is left, so both its Aspect step and its bundle step show them.
var win_results: Array[Dictionary] = []
## The scene the journal's Back returns to.
var journal_return: String = ADVENTURE_START_SCENE
## The referee of the duel in progress, read once it ends for what the achievements track.
var last_referee: Referee = null
## An adventure duel rebuilt from the run's saved history, held for the duel scene's
## `build_referee` call.
var _resumed_referee: Referee = null
## Offline: the record begun with the last referee built, until the duel scene's host takes it.
var _pending_record: MatchRecord = null
var _pending_record_for: int = 0
## Offline: the host of the duel on the table, which a concession ends.
var _record_host: DuelHost = null
## What the load-time trim dissolved, in AdventureCollection's report shape. The first screen that
## can show it calls `take_dissolve_report()`, which hands it over and clears it, so the line is
## shown once and not on every screen after.
var dissolve_report: Dictionary = {}


func _ready() -> void:
	library.load_dir(CARDS_DIR)
	strike_table = StrikeTable.load_from(TABLE_PATH)
	_load_decks()
	wallet = AdventureWallet.load_wallet()
	collection = AdventureCollection.load_collection()
	upgrades = AdventureUpgrades.load_upgrades()
	unlocks = AdventureUnlocks.load_unlocks()
	progress = AdventureProgress.load_progress()
	story_log = AdventureStoryLog.load_log()
	# A card whose cap dropped since the collection was saved can sit above it. Trimming pays the
	# overflow back as Motes rather than leaving copies that nothing can use.
	var trimmed: Dictionary = collection.trim_to_cap(library, wallet)
	if int(trimmed.get("copies", 0)) > 0:
		dissolve_report = trimmed
		wallet.save()
		collection.save()
	# A dev run with `--dev-scratch=<dir>` keeps its match records off the player's own too.
	var scratch: String = AdventureDev.flag("--dev-scratch=")
	if scratch != "":
		MatchRecord.dir_override = scratch.path_join("matches")


func _load_decks() -> void:
	decks.clear()
	# The select screen and the online lobby list the precons only; adventure starters are loaded
	# through AdventureRun and never enter this list.
	var dir: DirAccess = DirAccess.open(DECKS_DIR)
	if dir == null:
		push_error("Session: cannot open %s" % DECKS_DIR)
		return
	var names: Array[String] = []
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".json"):
			names.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	names.sort()
	for n in names:
		decks.append(DeckList.load_from(DECKS_DIR.path_join(n)))


func can_start() -> bool:
	return chosen[0] != null and chosen[1] != null


func both_locked() -> bool:
	return can_start() and locked[0] and locked[1]


func deck_problems(deck: DeckList) -> Array[String]:
	return DeckValidator.validate(deck, library)


## Builds a fresh referee (engine behind seat views) from the chosen decks. Rolls a seed when
## none is set. Only the process that runs the rules calls this; a joining client never does.
## An adventure duel that `begin_stage` resumed gets the referee it already replayed.
func build_referee() -> Referee:
	if _resumed_referee != null:
		var resumed: Referee = _resumed_referee
		_resumed_referee = null
		return resumed
	var referee: Referee = _new_referee()
	_watch_adventure_duel(referee)
	return referee


func _new_referee() -> Referee:
	var referee: Referee = Referee.new()
	last_seed = seed_value if seed_value != 0 else randi_range(1, 2147483646)
	if color_seed == 0:
		# A dev run that opens the duel scene directly never passed a select screen.
		roll_colors()
	var pair: Array[DeckList] = [chosen[0], chosen[1]]
	referee.setup(pair, library, strike_table, last_seed, seat_names())
	# Adventure duels run on lives: the player has two, an ordinary opponent one, a boss two
	# (2026-09-22). Every other mode is the printed game.
	if in_adventure():
		referee.engine.set_lives(stage_lives())
		# A full Seal set is one of the two points, not the whole duel (2026-09-21).
		referee.engine.set_points_options(true, false)
		var guest: String = str(map.duel_for(run.node_id).get("guest", "")) if map != null else ""
		if guest != "":
			referee.engine.set_guest_ally(0, guest)
		# A boss holds one banned card as a special power, outside its deck.
		var power: String = AdventureRules.boss_power_for(map.duel_for(run.node_id) if map != null else {}, run.run_seed, run.node_id, library)
		if power != "":
			referee.engine.set_boss_power(1, power)
	# `--dev-boss-power=<card id>` hands seat 2 a boss power in any duel, for a screenshot check.
	for arg in DevArgs.user_args():
		if arg.begins_with("--dev-boss-power="):
			referee.engine.set_boss_power(1, arg.substr("--dev-boss-power=".length()))
	last_referee = referee
	_pending_record = _begin_record(referee, pair) if Net.mode == "" else null
	_pending_record_for = referee.get_instance_id()
	return referee


## The record of an offline duel, read off its referee before the deal. Only the duel server
## signs; this one is the player's own and counts for nothing shared.
func _begin_record(referee: Referee, pair: Array[DeckList]) -> MatchRecord:
	var mode: String = "adventure" if in_adventure() else ("vs_ai" if ai_seat >= 0 else "hotseat")
	var record: MatchRecord = MatchRecord.begin(referee, pair, mode, "client")
	record.protocol = Net.PROTOCOL
	record.catalog = Net.catalog_fingerprint()
	record.color_seed = color_seed
	if ai_seat >= 0:
		record.seats[ai_seat]["ai"] = ai_profile
	if in_adventure():
		record.seats[0]["list"] = MatchRecord.deck_dict(pair[0])
	return record


## Offline: the duel scene's host keeps the record of the duel it was built for, and writes it to
## `local.jsonl` the moment the duel ends. Online the duel server keeps the record.
func keep_record(host: DuelHost) -> void:
	_record_host = null
	if _pending_record == null or host.referee.get_instance_id() != _pending_record_for:
		return
	host.record = _pending_record
	host.on_result = _store_local_record
	_pending_record = null
	_record_host = host


func _store_local_record(record: MatchRecord) -> void:
	var problem: String = MatchRecord.keep_line(MatchRecord.LOCAL_FILE, record.line())
	if problem != "":
		push_warning("record %s failed: %s" % [record.id, problem])


## The offline duel on the table ends in a concession by the seat at the table: the player against
## the AI or in an adventure, the seat deciding at a hotseat table.
func _record_concession() -> void:
	if _record_host == null or _record_host.record == null:
		return
	var seat: int = 1 - ai_seat if ai_seat >= 0 else maxi(0, _record_host.deciding())
	_record_host.end(1 - seat, "concede")


## Binds the referee's id rather than the referee, which would keep it alive through its own signal.
func _watch_adventure_duel(referee: Referee) -> void:
	if in_adventure():
		referee.command_applied.connect(_on_adventure_command.bind(referee.get_instance_id()))


## Saves the run with the duel's history after every command, so a closed game comes back to the
## same position, and records the result the moment the duel ends rather than on Continue.
func _on_adventure_command(_seat: int, _command: Dictionary, referee_id: int) -> void:
	if run == null or run.status != "stage" or last_referee == null or last_referee.get_instance_id() != referee_id:
		return
	run.duel_history.assign(last_referee.history)
	if last_referee.is_over():
		record_stage(last_referee.engine.state.winner == 1 - ai_seat)
	else:
		AdventureSave.store(run)


## The names the rules use for the two seats, in the log and on every panel. At a hotseat table the
## two people are "Player 1" and "Player 2". Against the AI, online or in an adventure the crests
## name the duelists, so a seat still on a stock name takes its duelist's instead; a name a player
## typed is kept, and a mirror match keeps the stock names so the two seats still read apart.
func seat_names() -> Array[String]:
	var names: Array[String] = [player_names[0], player_names[1]]
	if ai_seat < 0 and Net.mode == "" and not in_adventure():
		return names
	var duelists: Array[String] = [duelist_name(chosen[0]), duelist_name(chosen[1])]
	if duelists[0] == duelists[1]:
		return names
	for seat in range(2):
		if duelists[seat] != "" and is_stock_name(names[seat], seat):
			names[seat] = duelists[seat]
	return names


static func is_stock_name(value: String, seat: int) -> bool:
	return value == "Player %d" % (seat + 1) or value == "The AI"


func duelist_name(deck: DeckList) -> String:
	if deck == null:
		return ""
	var face: CardDef = library.defs.get(deck.duelist_face_id())
	return face.title if face != null else ""


## A fresh roll of the seat colours, for a new battle. Offline the select screen does it; online
## the authority does it and shares the number, since both sides have to draw the same pair.
func roll_colors() -> void:
	color_seed = randi_range(1, 2147483646)


## The player colour for a seat in the matchup being chosen or played. Every screen outside the
## duel calls this, so the colour a player sees in the lobby is the one on their side of the
## table.
func seat_color(index: int) -> Color:
	if color_seed == 0:
		# A dev run that opened a screen directly; roll once so the colours hold still.
		roll_colors()
	return SeatColors.of_styles(match_styles(), index, color_seed)


## The two styles the colours are rolled from: the locked-in decks online, the chosen decks
## otherwise. A seat that has not picked yet counts as Freestyle.
func match_styles() -> Array[String]:
	var out: Array[String] = ["", ""]
	for i in range(2):
		var d: DeckList = chosen[i]
		if Net.mode != "" and Net.lobby.size() > i:
			var index: int = int(Net.lobby[i]["deck"])
			d = decks[index] if index >= 0 and index < decks.size() else null
		if d != null:
			out[i] = d.style
	return out


## The driver for the AI seat, or null when both seats are people.
func build_ai() -> AiPlayer:
	if ai_seat < 0:
		return null
	# The deck says what the AI values, the chosen level says how hard it thinks.
	return AiPlayer.new(AiProfile.for_deck(chosen[ai_seat], ai_profile), last_seed)


func go_to_duel() -> void:
	get_tree().change_scene_to_file(DUEL_SCENE)


func go_to_select() -> void:
	# Online the authority owns the roll and has already shared it; rolling here would give the
	# two sides different colours.
	if Net.mode == "":
		roll_colors()
	get_tree().change_scene_to_file(SELECT_SCENE)


func go_to_versus() -> void:
	get_tree().change_scene_to_file(VERSUS_SCENE)


func go_to_title() -> void:
	get_tree().change_scene_to_file(TITLE_SCENE)


# --- Adventure --------------------------------------------------------------

## True whenever a run is live in memory.
func in_adventure() -> bool:
	return run != null


## Lives for the current duel, player first. `AdventureRules` owns the numbers, so the headless
## runners read the same rule the client does.
func stage_lives() -> Array[int]:
	var row: Dictionary = map.duel_for(run.node_id) if map != null else {}
	return AdventureRules.lives_for(row)


## Starts a fresh run for `starter_id` and saves it. `loadout_deck` is the starter after the
## loadout screen's swaps; null starts from the printed starter.
func start_run(starter_id: String, loadout_deck: DeckList = null) -> void:
	run = AdventureLoadout.begin_from(starter_id, loadout_deck, randi_range(1, 2147483646))
	AdventureProgress.prepare_run(run, library, collection, unlocks)
	map = AdventureMap.generate(starter_id, run.run_seed)
	AdventureSave.store(run)


## Loads the saved run into memory. False, and leaves `run` untouched, when there is no save or
## its map cannot be rolled.
func resume_run() -> bool:
	var loaded: AdventureRun = AdventureSave.load_run()
	if loaded == null:
		return false
	var loaded_map: AdventureMap = AdventureMap.generate(loaded.starter_id, loaded.run_seed)
	if loaded_map == null:
		return false
	run = loaded
	map = loaded_map
	return true


## Ends the run for good: clears the save, then resets the session as leaving adventure mode does.
func abandon_run() -> void:
	AdventureSave.clear()
	leave_adventure()


## Leaves adventure mode for a normal match, without touching the save. Everything the adventure
## flow set on the way into a duel goes back to its start value, so the select screen opens with
## no deck picked or locked.
func leave_adventure() -> void:
	run = null
	map = null
	chosen = [null, null]
	locked = [false, false]
	seed_value = 0
	last_seed = 0
	ai_seat = -1
	ai_profile = "default"
	player_names = ["Player 1", "Player 2"]
	lead_in = {}
	win_results = []
	last_referee = null
	_resumed_referee = null
	_pending_record = null
	_record_host = null


## Steps the run onto a map node and saves. A fight goes straight into its duel; any other node is
## passed through for now and the map screen reopens. A node that is not a choice does nothing.
func enter_node(id: String) -> void:
	if run == null or not run.enter(map, id):
		return
	AdventureSave.store(run)
	if run.status == "stage":
		begin_stage()
		return
	get_tree().change_scene_to_file(ADVENTURE_STAGE_SCENE)


## Sets up and starts the duel on the node the run stands on. The same duel always gets the same
## seed and every command is saved as it is played, so a duel left mid-way opens again where it
## stood, without the lead-in it already showed. A history that no longer replays is dropped and
## the duel starts over.
func begin_stage() -> void:
	var row: Dictionary = map.duel_for(run.node_id)
	var opponent_id: String = str(row.get("opponent", ""))
	var opponent: DeckList = DeckList.resolve(opponent_id)
	chosen = [run.deck(), opponent]
	locked = [true, true]
	ai_seat = 1
	ai_profile = str(row.get("ai_level", "default"))
	seed_value = run.stage_seed(run.stage)
	player_names = [player_names[0], AdventureDecks.opponent_name(opponent_id, library)]
	roll_colors()
	lead_in = {} if _resume_duel() else _lead_in_for_stage()
	go_to_duel()


## Replays the run's saved history into a referee for `build_referee` to hand over. False when
## there is none, or when it does not replay, which drops it.
func _resume_duel() -> bool:
	_resumed_referee = null
	if run.duel_history.is_empty():
		return false
	var referee: Referee = _new_referee()
	var problem: String = referee.replay(run.duel_history)
	if problem != "":
		push_warning("Adventure duel did not replay, starting it over: %s" % problem)
		run.duel_history.clear()
		AdventureSave.store(run)
		return false
	_watch_adventure_duel(referee)
	_resumed_referee = referee
	return true


## The lead-in before the duel on the run's node. A restarted duel shows the one it showed first.
func _lead_in_for_stage() -> Dictionary:
	story_log.begin_run(run.run_id)
	if str(story_log.current.get("node", "")) == run.node_id:
		return story_log.current.get("lead_in", {})
	var ctx: Dictionary = AdventureLeadIns.context_for(run, map, library, progress, story_log)
	var picked: Dictionary = AdventureLeadIns.pick(ctx)
	story_log.mark_shown(picked.get("keys", []))
	story_log.current = {"node": run.node_id, "lead_in": picked}
	story_log.save()
	return picked


## Applies the duel result to the run, credits the Motes a win pays, and saves. A loss ends the
## run and goes straight to the run-end settlement, which is where the run's cards are bought.
## The save is kept until the settlement closes, so quitting on that screen does not lose it.
## Only the first call for a duel does anything: the result is recorded at game over, and the
## Continue click and the autoplay path in duel_view.gd call this again.
func record_stage(won: bool) -> void:
	if run == null or run.status != "stage":
		return
	var engine: DuelEngine = last_referee.engine if last_referee != null else null
	var results: Array[Dictionary] = AdventureRewards.record_duel(run, map, library, won, engine,
		story_log, collection, unlocks, progress, wallet)
	story_log.save()
	if won:
		win_results = results
		unlocks.save()
		progress.save()
		collection.save()
	wallet.save()
	AdventureSave.store(run)


## Ends the duel for the current stage, recording it if game over has not already, then moves on.
func finish_stage(won: bool) -> void:
	record_stage(won)
	get_tree().change_scene_to_file(_reward_or_stage_scene())


## Gives up the duel in progress. In an adventure that is a loss like the duelist falling: recorded
## now, the saved history dropped, then on to the run-end settlement. At a hotseat or vs-AI table
## it returns to the title. An online duel concedes through Net instead.
func concede_duel() -> void:
	_record_concession()
	if not in_adventure():
		go_to_title()
		return
	finish_stage(false)


## The reward scene handles both halves of a win: the Aspect choice, then the bundle offer. A
## finished run goes to the settle screen instead of the stage screen's run-over panel.
func _reward_or_stage_scene() -> String:
	if run.status == "aspect" or run.status == "reward":
		return ADVENTURE_REWARD_SCENE
	if run.status == "settle":
		return _scene_or_start(ADVENTURE_SETTLE_SCENE)
	return ADVENTURE_STAGE_SCENE


## A scene that may not be built yet falls back to the adventure start screen rather than
## crashing. The settle, vendor and loadout screens are a later pass.
func _scene_or_start(path: String) -> String:
	return path if ResourceLoader.exists(path) else ADVENTURE_START_SCENE


## Takes the chosen Aspect card and moves the run on to its bundle offer, still on the reward
## screen. A card the run cannot legally take leaves the run where it is.
func finish_aspect(card_id: String) -> void:
	if run.status != "aspect":
		return
	if not AdventureRewards.apply_aspect(run, library, card_id):
		return
	AdventureRewards.finish_aspect(run, map, library)
	AdventureSave.store(run)
	get_tree().change_scene_to_file(ADVENTURE_REWARD_SCENE)


## Leaves the reward screen for the map, or the run's end. Beating the final boss pays the
## completion bonus and opens the settlement, where the run deck is on offer at a discount.
func finish_reward() -> void:
	win_results.clear()
	var bonus: int = AdventureRewards.finish_reward(run, map)
	if bonus > 0:
		wallet.earn(bonus, AdventureWallet.REASON_COMPLETION, run.run_id)
		wallet.save()
	if run.status == "won":
		AdventureSettlement.open(run)
	AdventureSave.store(run)
	get_tree().change_scene_to_file(_reward_or_stage_scene())


# --- Motes, the collection and the run-end settlement -----------------------

## Buys `count` copies of an offered card into the collection and saves both files. Returns how
## many landed; 0 when the settlement is closed, the wallet is short or the collection is full.
func keep_card(id: String, count: int = 1) -> int:
	var kept: int = AdventureSettlement.keep(run, id, count, wallet, collection, library)
	if kept > 0:
		wallet.save()
		collection.save()
	return kept


## The run-end offer rows, in the shape the settle screen lists them.
func settle_offers() -> Array[Dictionary]:
	if run == null:
		return []
	return AdventureSettlement.offers(run, library, AdventureSettlement.won(run), collection)


## Closes the run-end screen: the run is over, the vendor's shelf rolls over, and the save goes.
func finish_settlement() -> void:
	if run != null:
		AdventureSettlement.close(run)
	AdventureVendor.reroll(wallet, false)
	wallet.save()
	collection.save()
	AdventureSave.clear()
	run = null
	map = null
	get_tree().change_scene_to_file(ADVENTURE_START_SCENE)


## The vendor's shelf right now.
func vendor_stock() -> Array[String]:
	return AdventureVendor.stock(wallet, collection, library)


## Buys one copy off the shelf. False when it is not on sale, the wallet is short, or the
## collection already holds every copy it may.
func buy_card(id: String) -> bool:
	if not AdventureVendor.buy(id, wallet, collection, library):
		return false
	wallet.save()
	collection.save()
	return true


## The paid once-per-visit reroll. False when the wallet cannot cover the fee.
func reroll_vendor() -> bool:
	if not AdventureVendor.reroll(wallet, true):
		return false
	wallet.save()
	return true


## Dissolves one collection copy into Motes. Returns what it paid, 0 when there was no copy.
func dissolve_card(id: String) -> int:
	var paid: int = collection.dissolve(id, library, wallet)
	if paid > 0:
		wallet.save()
		collection.save()
	return paid


## The pending auto-dissolve line, handed over once. "" when there is nothing to show.
func take_dissolve_report() -> String:
	var line: String = AdventureCollection.report_line(dissolve_report)
	dissolve_report = {}
	return line


# --- Deck slots -------------------------------------------------------------

## Buys one more deck slot for `starter_id` and saves. False when it is maxed out or the wallet is
## short, and nothing moves.
func buy_slot(starter_id: String) -> bool:
	if not upgrades.buy_slot(starter_id, wallet, AdventureLoadout.max_slots_for(starter_id)):
		return false
	wallet.save()
	upgrades.save()
	return true


func go_to_vendor() -> void:
	get_tree().change_scene_to_file(_scene_or_start(ADVENTURE_VENDOR_SCENE))


func go_to_journal() -> void:
	journal_return = get_tree().current_scene.scene_file_path if get_tree().current_scene != null \
		else ADVENTURE_START_SCENE
	get_tree().change_scene_to_file(_scene_or_start(ADVENTURE_JOURNAL_SCENE))


func leave_journal() -> void:
	get_tree().change_scene_to_file(_scene_or_start(journal_return))


func go_to_loadout() -> void:
	get_tree().change_scene_to_file(_scene_or_start(ADVENTURE_LOADOUT_SCENE))


## Resumes a run in progress, or opens the start screen for a new one. A duel left mid-way opens
## again where it stood.
func go_to_adventure() -> void:
	if run == null and not resume_run():
		get_tree().change_scene_to_file(ADVENTURE_START_SCENE)
		return
	if run.status == "stage" and not run.duel_history.is_empty():
		begin_stage()
		return
	get_tree().change_scene_to_file(_reward_or_stage_scene())
