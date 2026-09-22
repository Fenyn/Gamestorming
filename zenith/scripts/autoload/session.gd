extends Node
## Session: what the select screen chose, carried into the duel scene.
## Also owns the loaded card library, strike table, available decks, and the live adventure run
## with its ladder; the adventure block at the bottom moves that run between screens and the save.

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
var ladder: AdventureLadder = null  # the run's ladder, loaded alongside it
## Motes and the card collection. Both outlive a run, so they are loaded once here and saved by
## whichever call spends or earns.
var wallet: AdventureWallet = AdventureWallet.new()
var collection: AdventureCollection = AdventureCollection.new()
## Deck slots and Aspect tiers bought per starter. Outlives a run like the other two.
var upgrades: AdventureUpgrades = AdventureUpgrades.new()
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
	# A collection saved under the old caps can hold rows the new ones do not. Trimming pays the
	# overflow back as Motes rather than leaving copies that nothing can use.
	var trimmed: Dictionary = collection.trim_to_cap(library, wallet)
	if int(trimmed.get("copies", 0)) > 0:
		dissolve_report = trimmed
		wallet.save()
		collection.save()


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
func build_referee() -> Referee:
	var referee: Referee = Referee.new()
	last_seed = seed_value if seed_value != 0 else randi_range(1, 2147483646)
	if color_seed == 0:
		# A dev run that opens the duel scene directly never passed a select screen.
		roll_colors()
	var pair: Array[DeckList] = [chosen[0], chosen[1]]
	var names: Array[String] = [player_names[0], player_names[1]]
	referee.setup(pair, library, strike_table, last_seed, names)
	# Adventure duels run first to two points; every other mode is the printed game.
	if in_adventure():
		referee.engine.set_points_to_win(2)
		# A full Seal set is one of the two points, not the whole duel (2026-09-21).
		referee.engine.set_points_options(true, false)
	return referee


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


## Starts a fresh run for `starter_id` and saves it. `loadout_deck` is the starter after the
## loadout screen's swaps; null starts from the printed starter.
func start_run(starter_id: String, loadout_deck: DeckList = null) -> void:
	run = AdventureLoadout.begin_from(starter_id, loadout_deck, randi_range(1, 2147483646))
	ladder = AdventureLadder.load_for(starter_id, run.run_seed)
	AdventureSave.store(run)


## Loads the saved run into memory. False, and leaves `run` untouched, when there is no save or
## its ladder is missing.
func resume_run() -> bool:
	var loaded: AdventureRun = AdventureSave.load_run()
	if loaded == null:
		return false
	var loaded_ladder: AdventureLadder = AdventureLadder.load_for(loaded.starter_id, loaded.run_seed)
	if loaded_ladder == null:
		return false
	run = loaded
	ladder = loaded_ladder
	return true


## Ends the run for good: clears the save and drops it from memory.
func abandon_run() -> void:
	AdventureSave.clear()
	run = null
	ladder = null


## Leaves adventure mode for a normal match, without touching the save.
func leave_adventure() -> void:
	run = null
	ladder = null
	seed_value = 0
	ai_seat = -1
	ai_profile = "default"
	player_names = ["Player 1", "Player 2"]


## Sets up and starts the duel for the run's current stage. Same stage always gives the same
## seed, so quitting mid-duel restarts it unchanged.
func begin_stage() -> void:
	var row: Dictionary = ladder.stage(run.stage)
	var opponent_id: String = str(row.get("opponent", ""))
	var opponent: DeckList = DeckList.resolve(opponent_id)
	chosen = [run.deck(), opponent]
	locked = [true, true]
	ai_seat = 1
	ai_profile = str(row.get("ai_level", "default"))
	seed_value = run.stage_seed(run.stage)
	player_names = [player_names[0], AdventureLadder.opponent_name(opponent_id, library)]
	roll_colors()
	go_to_duel()


## Applies the stage result to the run, credits the Motes a win pays, and saves. A loss ends the
## run and goes straight to the run-end settlement, which is where the run's cards are bought.
## The save is kept until the settlement closes, so quitting on that screen does not lose it.
func record_stage(won: bool) -> void:
	var payout: int = AdventureRewards.finish_stage(run, ladder, library, won)
	if payout > 0:
		wallet.earn(payout, AdventureWallet.REASON_STAGE, run.run_id, run.stage)
		wallet.save()
	if not won:
		AdventureSettlement.open(run)
	AdventureSave.store(run)


## Ends the duel for the current stage: records the result once, then moves on. Guarded so the
## autoplay path in duel_view.gd, which records before this ever runs, cannot record twice.
func finish_stage(won: bool) -> void:
	if run.status == "stage":
		record_stage(won)
	get_tree().change_scene_to_file(_reward_or_stage_scene())


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
	AdventureRewards.finish_aspect(run, ladder, library)
	AdventureSave.store(run)
	get_tree().change_scene_to_file(ADVENTURE_REWARD_SCENE)


## Leaves the reward screen for the next stage, or the run's end. Beating the ladder pays the
## completion bonus and opens the settlement, where the run deck is on offer at a discount.
func finish_reward() -> void:
	var bonus: int = AdventureRewards.finish_reward(run, ladder)
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
	ladder = null
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


# --- Deck slots and Aspect tiers --------------------------------------------

## The Aspect stack height `starter_id` prints, which is the floor its unlocked tier is measured
## against. 0 when the starter cannot be resolved.
func starter_aspects(starter_id: String) -> int:
	var deck: DeckList = DeckList.resolve(starter_id)
	return deck.duelist_ids.size() if deck != null else 0


## Buys one more deck slot for `starter_id` and saves. False when it is maxed out or the wallet is
## short, and nothing moves.
func buy_slot(starter_id: String) -> bool:
	if not upgrades.buy_slot(starter_id, wallet):
		return false
	wallet.save()
	upgrades.save()
	return true


## Unlocks the next Aspect tier for `starter_id` and saves. False when there is no tier left to buy
## or the wallet is short, and nothing moves.
func buy_aspect_tier(starter_id: String) -> bool:
	if not upgrades.buy_aspect_tier(starter_id, starter_aspects(starter_id), wallet):
		return false
	wallet.save()
	upgrades.save()
	return true


func go_to_vendor() -> void:
	get_tree().change_scene_to_file(_scene_or_start(ADVENTURE_VENDOR_SCENE))


func go_to_loadout() -> void:
	get_tree().change_scene_to_file(_scene_or_start(ADVENTURE_LOADOUT_SCENE))


## Resumes a run in progress, or opens the start screen for a new one.
func go_to_adventure() -> void:
	if run == null and not resume_run():
		get_tree().change_scene_to_file(ADVENTURE_START_SCENE)
		return
	get_tree().change_scene_to_file(_reward_or_stage_scene())
