extends SceneTree
## The Surge rail on a duelist card promises where the next Power Up lands. At every decision of
## seeded duels, the reach the card draws from the seat's own view must equal the Energy a Power Up
## leaves, measured on a copy of the engine, with every debuff that bends it: a smaller or
## zeroed Surge, "gain 1 less" Drills, Surge bonus Drills and a standing block on all gains.
##
##   godot --headless --path zenith -s tests/surge_rail_tests.gd

const DECKS: Array[String] = ["steel_beatdown", "root_seals", "storm_mentor", "storm_volley"]
const GAMES_PER_PAIR: int = 3
const MAX_STEPS: int = 900

var checks: int = 0
var failures: int = 0
var seen: Dictionary = {"less": 0, "zero": 0, "bonus": 0, "blocked": 0, "full": 0}


func _initialize() -> void:
	var library: CardLibrary = CardLibrary.new()
	library.load_dir("res://data/cards")
	var table: StrikeTable = StrikeTable.load_from("res://data/strike_table.json")
	_scenarios(library, table)
	var seed: int = 11
	for a in DECKS:
		for b in DECKS:
			for game in range(GAMES_PER_PAIR):
				_play(library, table, a, b, seed)
				seed += 1
	# The debuffs must have come up, or the test proves nothing about them.
	for key in ["less", "zero", "bonus", "blocked", "full"]:
		_check(int(seen[key]) > 0, "The duels reached a state with a %s Recover (%d decisions)" % [key, int(seen[key])])
	print("Surge rail: %d checks, %d failures, seen %s" % [checks, failures, str(seen)])
	quit(0 if failures == 0 else 1)


func _play(library: CardLibrary, table: StrikeTable, a: String, b: String, seed: int) -> void:
	var decks: Array[DeckList] = [DeckList.load_from("res://data/decks/%s.json" % a), DeckList.load_from("res://data/decks/%s.json" % b)]
	var referee: Referee = Referee.new()
	referee.setup(decks, library, table, seed, [], false)
	referee.start()
	var picker: RandomNumberGenerator = RandomNumberGenerator.new()
	picker.seed = seed * 7919
	var steps: int = 0
	while not referee.is_over() and steps < MAX_STEPS:
		var engine: DuelEngine = referee.engine
		engine.take_events()
		if engine.prompt == null or engine.prompt.options.is_empty():
			return
		for seat in range(2):
			_check_seat(engine, seat, "%s v %s seed %d step %d" % [a, b, seed, steps])
		var options: Array[Command] = engine.prompt.options
		var problem: String = referee.submit(engine.prompt.player, options[picker.randi_range(0, options.size() - 1)].to_dict())
		if not problem.is_empty():
			return
		steps += 1


## Random play rarely lands the debuff cards, so each one is also put into play by hand: the rival's
## "gain 1 less" Drill, the seat's own Surge bonus Drill, both at once, and a zeroed Surge.
func _scenarios(library: CardLibrary, table: StrikeTable) -> void:
	var cases: Array = [
		["less", [[1, "steel_drill_03"]], false],
		["bonus", [[0, "root_drill_06"]], false],
		["bonus and less", [[0, "root_drill_06"], [1, "steel_drill_03"], [1, "steel_drill_03"]], false],
		["zero", [], true],
		["zero and bonus", [[0, "root_drill_06"]], true],
	]
	for energy in [0, 3, 8, 9]:
		for case in cases:
			var decks: Array[DeckList] = [DeckList.load_from("res://data/decks/root_seals.json"), DeckList.load_from("res://data/decks/steel_beatdown.json")]
			var referee: Referee = Referee.new()
			referee.setup(decks, library, table, 5, [], false)
			referee.start()
			var engine: DuelEngine = referee.engine
			for put in case[1]:
				_put_in_play(engine, int(put[0]), str(put[1]))
			if bool(case[2]):
				engine.state.floating.append({"owner": 0, "op": "surge_zero", "duration": "next_turn_end"})
			engine.state.players[0].duelist.energy = energy
			_check_seat(engine, 0, "%s at Energy %d" % [case[0], energy])


## Puts a fresh copy of the card into the seat's play.
func _put_in_play(engine: DuelEngine, seat: int, id: String) -> void:
	var c: CardInstance = engine._instance(engine.library.get_def(id), seat, &"in_play")
	c.controller = seat
	engine.state.players[seat].in_play.append(c)


## The rail's reach from the seat's own view against a Power Up played on a copy.
func _check_seat(engine: DuelEngine, seat: int, where: String) -> void:
	var view: SeatView = SeatView.of(engine, seat, false)
	var standing: SeatPlayer = view.player(seat)
	var own: SeatCard = view.card(standing.duelist)
	if own == null:
		return
	var reach: int = CardFace.recover_reach(own.energy, standing)
	var copy: DuelEngine = engine.clone()
	var p: PlayerState = copy.state.players[seat]
	var before: int = p.duelist.energy
	copy._gain_energy(p, p.duelist, copy.recover_gain(p))
	var landed: int = p.duelist.energy
	var expected: int = landed if landed != before else -1
	# A rail only ever points up: at 10 or with nothing to gain there is none.
	if reach == own.energy:
		reach = -1
	var real: PlayerState = engine.state.players[seat]
	if engine.power_up_less(real) > 0:
		seen["less"] = int(seen["less"]) + 1
	if engine.surge_of(real) == 0 and real.duelist.surge() > 0:
		seen["zero"] = int(seen["zero"]) + 1
	if engine.surge_of(real) > real.duelist.surge():
		seen["bonus"] = int(seen["bonus"]) + 1
	if engine.energy_blocked(real):
		seen["blocked"] = int(seen["blocked"]) + 1
	if real.duelist.energy == CardInstance.MAX_STAGE:
		seen["full"] = int(seen["full"]) + 1
	if reach != expected:
		_check(false, "%s: seat %d at Energy %d, the rail reaches %d but a Power Up lands on %d" % [where, seat, own.energy, reach, landed])
	else:
		checks += 1


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
