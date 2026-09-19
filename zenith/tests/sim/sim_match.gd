class_name SimMatch
extends RefCounted
## One headless duel, played by two configured sides, with timing and the endgame state recorded.
## This is the only match loop in the harness; every report is built out of its results.

const REASONS: Array[String] = ["survival", "seal", "ascension"]
## A full Life Deck, the denominator that puts a survival distance on the same scale as the others.
const FULL_LIFE: float = 40.0

var library: CardLibrary = null
var table: StrikeTable = null
var max_steps: int = 6000


static func make(lib: CardLibrary, strike_table: StrikeTable, p_max_steps: int) -> SimMatch:
	var out: SimMatch = SimMatch.new()
	out.library = lib
	out.table = strike_table
	out.max_steps = p_max_steps
	return out


## Plays `a_deck` in seat `a_seat` against `b_deck` in the other, and returns what happened.
##
## `seeds` is `[engine, a player, b player, random fallback]`. The result's `timing` is indexed by
## side (0 = a, 1 = b), not by seat; `distance` is indexed by side too.
func play(a_deck: DeckList, b_deck: DeckList, a_seat: int, a_side: SimSeat, b_side: SimSeat, seeds: Array[int]) -> Dictionary:
	var decks: Array[DeckList] = [null, null]
	decks[a_seat] = a_deck
	decks[1 - a_seat] = b_deck
	var referee: Referee = Referee.new()
	referee.setup(decks, library, table, seeds[0])
	referee.start()
	referee.engine.take_events()

	# side 0 is a, side 1 is b; `seat_side[seat]` says which side sits there.
	var seat_side: Array[int] = [0, 0]
	seat_side[a_seat] = 0
	seat_side[1 - a_seat] = 1
	var players: Array[AiPlayer] = [null, null]
	players[a_seat] = a_side.make_player(a_deck, seeds[1])
	players[1 - a_seat] = b_side.make_player(b_deck, seeds[2])
	var picker: RandomNumberGenerator = RandomNumberGenerator.new()
	picker.seed = seeds[3]

	var timing: Array[Dictionary] = [blank_timing(), blank_timing()]
	var steps: int = 0
	var problem: String = ""
	while not referee.is_over() and steps < max_steps:
		if referee.engine.prompt == null or referee.engine.prompt.options.is_empty():
			problem = "Missing or empty prompt"
			break
		var seat: int = referee.engine.prompt.player
		if seat < 0 or seat > 1:
			problem = "Prompt named seat %d" % seat
			break
		var side: int = seat_side[seat]
		var started: int = Time.get_ticks_usec()
		var wire: Dictionary = {}
		if players[seat] == null:
			var options: Array[Command] = referee.engine.prompt.options
			wire = options[picker.randi_range(0, options.size() - 1)].to_dict()
		else:
			wire = players[seat].choose(referee, seat)
		var spent: int = Time.get_ticks_usec() - started
		_record_timing(timing[side], spent, players[seat], referee)
		steps += 1
		problem = referee.submit(seat, wire)
		if not problem.is_empty():
			problem = "Rejected %s: %s" % [str(wire), problem]
			break
		referee.engine.take_events()

	var finished: bool = problem.is_empty() and referee.is_over()
	if problem.is_empty() and not finished:
		problem = "Unfinished after %d decisions at turn %d" % [max_steps, referee.engine.state.turn]
	var winner_seat: int = referee.engine.state.winner if finished else -1
	if finished and not winner_seat in [0, 1]:
		problem = "Finished with an invalid winner: %d" % winner_seat
		finished = false
	for side in range(2):
		_close_timing(timing[side])
	return {
		"ok": finished and problem.is_empty(),
		"error": problem,
		"a_seat": a_seat,
		"winner_seat": winner_seat,
		"a_won": finished and winner_seat == a_seat,
		"reason": str(referee.engine.state.win_reason) if finished else "",
		"turn": referee.engine.state.turn,
		"steps": steps,
		"timing": timing,
		"distance": [
			distances(referee.engine, a_seat) if finished else {},
			distances(referee.engine, 1 - a_seat) if finished else {},
		],
	}


## What one seat still needed on each route, at the moment the game ended. Lower is closer.
## `survival` is life cards left to lose, `seal` is Seals missing from its best set, `ascension`
## is the share of the Fervor-and-aspect climb still to go.
static func distances(engine: DuelEngine, seat: int) -> Dictionary:
	var p: PlayerState = engine.state.players[seat]
	var sets: Dictionary = {}
	for t in p.seals():
		sets[t.def.seal_set] = int(sets.get(t.def.seal_set, 0)) + 1
	var best: int = 0
	for s in sets.keys():
		best = maxi(best, int(sets[s]))
	var need: int = maxi(1, engine.fervor_needed(p))
	var target: int = p.highest_aspect * need
	var have: int = (p.duelist.aspect - 1) * need + p.fervor
	return {
		"survival": p.life_deck.size(),
		"seal": DuelEngine.SEALS_PER_SET - best,
		# A forbidden Ascension is as far away as it gets, not as near.
		"ascension": 1.0 if p.no_ascension_win else float(target - have) / float(target),
	}


## The route a seat was nearest to finishing, each distance taken as a share of a full run.
static func closest_route(d: Dictionary) -> String:
	var scaled: Dictionary = {
		"survival": float(int(d["survival"])) / FULL_LIFE,
		"seal": float(int(d["seal"])) / float(DuelEngine.SEALS_PER_SET),
		"ascension": float(d["ascension"]),
	}
	var best: String = "survival"
	for r in REASONS:
		if float(scaled[r]) < float(scaled[best]):
			best = r
	return best


static func blank_timing() -> Dictionary:
	return {
		"decisions": 0, "total_usec": 0, "max_usec": 0, "samples_ms": [],
		"search_decisions": 0, "branching_decisions": 0, "depth_total": 0, "max_depth": 0,
		"fallbacks": 0, "stops": {},
	}


func _record_timing(stats: Dictionary, usec: int, player: AiPlayer, referee: Referee) -> void:
	stats["decisions"] = int(stats["decisions"]) + 1
	stats["total_usec"] = int(stats["total_usec"]) + usec
	stats["max_usec"] = maxi(int(stats["max_usec"]), usec)
	(stats["samples_ms"] as Array).append(usec / 1000.0)
	if player == null:
		return
	var metrics: Dictionary = player.search.metrics
	if str(metrics.get("algorithm", "")) != "sequence":
		return
	var branching: bool = referee.engine.prompt.options.size() > 1
	var depth: int = int(metrics.get("completed_depth", 0))
	stats["search_decisions"] = int(stats["search_decisions"]) + 1
	stats["depth_total"] = int(stats["depth_total"]) + depth
	stats["max_depth"] = maxi(int(stats["max_depth"]), depth)
	if branching:
		stats["branching_decisions"] = int(stats["branching_decisions"]) + 1
		if depth == 0:
			stats["fallbacks"] = int(stats["fallbacks"]) + 1
	var stop: String = str(metrics.get("cutoff", ""))
	if stop.is_empty():
		stop = "completed"
	(stats["stops"] as Dictionary)[stop] = int((stats["stops"] as Dictionary).get(stop, 0)) + 1


func _close_timing(stats: Dictionary) -> void:
	var samples: Array = stats["samples_ms"]
	samples.sort()
