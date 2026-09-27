class_name SimMatch
extends RefCounted
## One headless duel, played by two configured sides, with timing and the endgame state recorded.
## This is the only match loop in the harness; every report is built out of its results.

const REASONS: Array[String] = ["survival", "seal", "ascension"]

var library: CardLibrary = null
var table: StrikeTable = null
var max_steps: int = 6000
var points_to_win: int = 1   # the same for both seats; the adventure's per-seat rule is `lives`
## Lives per seat, seat-ordered (entry 0 is seat 0, whichever side sits there). Empty leaves the
## symmetric `points_to_win` alone; non-empty overrides it, since a ladder stage gives the player
## two lives and an ordinary opponent one. See AdventureRules.lives_for.
var lives: Array[int] = []
## When set, every finished game is written here as a `MatchRecord` line, so `--dev-replay` can
## play it back with both hands shown.
var records: FileAccess = null
## When set, one line per AI decision: the options the seat saw, what the scorer made of each, what
## the search found, and the choice, keyed to the record id and the command's index in it.
var decisions: FileAccess = null
## How many option scores a decision line keeps, best first.
const DECISION_OPTIONS: int = 8


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
	referee.setup(decks, library, table, seeds[0], [], false)
	referee.engine.set_points_to_win(points_to_win)
	var multi_point: bool = points_to_win > 1
	# Lives come second so they override the symmetric setting.
	if not lives.is_empty():
		referee.engine.set_lives(lives)
		for n in lives:
			multi_point = multi_point or n > 1
	# The adventure rule set: a first-to-N duel also scores a full Seal set as one point.
	referee.engine.set_points_options(multi_point, false)
	var record: MatchRecord = null
	if records != null or decisions != null:
		record = MatchRecord.begin(referee, decks, "vs_ai", "client")
		record.seats[a_seat]["ai"] = a_side.policy
		record.seats[1 - a_seat]["ai"] = b_side.policy
	var dealt: int = Time.get_ticks_msec()
	referee.start()
	referee.engine.take_events()

	# side 0 is a, side 1 is b; `seat_side[seat]` says which side sits there.
	var seat_side: Array[int] = [0, 0]
	seat_side[a_seat] = 0
	seat_side[1 - a_seat] = 1
	# The survival denominator, per side: the starters hold 78 to 84 life cards. Read off the
	# DeckList, not the table, where seat 1 has drawn its opening hand by now and seat 0 has not.
	var full_life: Array[int] = [a_deck.cards.size(), b_deck.cards.size()]
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
		if decisions != null and players[seat] != null and referee.engine.prompt.options.size() > 1:
			decisions.store_line(JSON.stringify(_decision_line(referee, record, seat, decks[seat].id, players[seat], wire)))
		steps += 1
		problem = referee.submit(seat, wire)
		if not problem.is_empty():
			problem = "Rejected %s: %s" % [str(wire), problem]
			break
		if record != null:
			record.add_command(referee.history[referee.history.size() - 1], Time.get_ticks_msec() - dealt)
		# A card in two places is a broken match, never a result: fail it and say where.
		if referee.integrity_fault != "":
			problem = "Card integrity: %s" % referee.integrity_fault
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
	if records != null and record != null and finished:
		record.finish(winner_seat, str(referee.engine.state.win_reason), referee.engine, Time.get_ticks_msec() - dealt)
		records.store_line(record.line())
	return {
		"ok": finished and problem.is_empty(),
		"error": problem,
		"a_seat": a_seat,
		"winner_seat": winner_seat,
		"a_won": finished and winner_seat == a_seat,
		"reason": str(referee.engine.state.win_reason) if finished else "",
		"turn": referee.engine.state.turn,
		"steps": steps,
		# Seat-ordered, unlike `timing` and `distance`: the points each seat scored.
		"points": [int(referee.engine.state.points[0]), int(referee.engine.state.points[1])],
		"timing": timing,
		"full_life": full_life,
		"distance": [
			distances(referee.engine, a_seat) if finished else {},
			distances(referee.engine, 1 - a_seat) if finished else {},
		],
	}


## One AI decision as a reviewable line: where the duel stood, every option with the scorer's score
## (best first, capped), the search's findings when it searched, and the option taken. `entry` is
## the index the command will have in the record, which is also the replay's `--dev-replay-to`.
func _decision_line(referee: Referee, record: MatchRecord, seat: int, deck_id: String, player: AiPlayer, wire: Dictionary) -> Dictionary:
	var engine: DuelEngine = referee.engine
	var prompt: Prompt = engine.prompt
	var scores: Array[float] = AiScorer.scores(referee.sim_for(seat, 1), player.profile_for(referee, seat), seat)
	var ranked: Array[Dictionary] = []
	for i in range(prompt.options.size()):
		ranked.append({"option": _label(engine, prompt.options[i]), "score": snappedf(scores[i] if i < scores.size() else 0.0, 0.01)})
	ranked.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["score"]) > float(y["score"]))
	var searched: Array[Dictionary] = []
	for r in player.search.last_report:
		searched.append({"option": str(r.get("option", "")), "value": snappedf(float(r.get("value", 0.0)), 0.01), "depth": int(r.get("depth", 0))})
	var me: PlayerState = engine.player(seat)
	var foe: PlayerState = engine.player(1 - seat)
	return {
		"record": record.id if record != null else "",
		"entry": referee.history.size(),
		"seat": seat,
		"deck": deck_id,
		"turn": engine.state.turn,
		"kind": String(prompt.kind),
		"about": _prompt_about(engine, prompt),
		"state": {"energy": me.duelist.energy, "fervor": me.fervor, "aspect": me.duelist.aspect, "hand": me.hand.size(),
			"life": me.life_deck.size(), "foe_energy": foe.duelist.energy, "foe_life": foe.life_deck.size()},
		"chose": _label(engine, Command.from_dict(wire)),
		"options": ranked.slice(0, DECISION_OPTIONS),
		"search": searched,
	}


## What a prompt is asking about, so "yes" and "no" can be read: its purpose, the card it comes
## from, and the effect line waiting on the answer.
static func _prompt_about(engine: DuelEngine, prompt: Prompt) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for key in ["purpose", "card_title"]:
		if str(prompt.context.get(key, "")) != "":
			parts.append(str(prompt.context[key]))
	var effect: Dictionary = engine._choice.get("effect", {})
	if not effect.is_empty():
		parts.append(str(effect.get("op", "")))
	return " / ".join(parts)


## "attack Storm Lash (#84)": a command with its card named, for a person reading the log.
static func _label(engine: DuelEngine, cmd: Command) -> String:
	var text: String = String(cmd.type)
	var c: CardInstance = engine.card(cmd.card)
	if c != null:
		text += " %s (#%d)" % [c.def.title, cmd.card]
	if cmd.value != null:
		text += " %s" % str(cmd.value)
	return text


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
## `full_life` is that seat's own starting Life Deck, not a fixed number: the starters run from the
## high seventies to the mid eighties, so a shared constant would flatter the larger decks.
static func closest_route(d: Dictionary, full_life: int) -> String:
	var scaled: Dictionary = {
		"survival": float(int(d["survival"])) / float(maxi(1, full_life)),
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
