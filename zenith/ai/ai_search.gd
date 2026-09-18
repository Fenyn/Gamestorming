class_name AiSearch
extends RefCounted
## Short lookahead for one decision. For each shortlisted option it asks the referee for a fresh
## guess at the hidden cards, plays the option there, lets AiScorer play both seats to the end of
## the turn, and scores where that leaves the table with AiEvaluator. Averages over several
## guesses decide. Every option meets the same guesses, so luck in the deal cancels out.

## What the last `choose` weighed, for logs and tests: [{"option", "prior", "value", "samples"}].
var last_report: Array[Dictionary] = []


func choose(referee: Referee, seat: int, profile: AiProfile, rng: RandomNumberGenerator) -> Command:
	last_report = []
	var base: DuelEngine = referee.sim_for(seat, rng.randi())
	var prompt: Prompt = base.prompt_of(seat)
	if prompt == null:
		return null
	if prompt.options.size() == 1:
		return prompt.options[0]
	var prior: Array[float] = AiScorer.scores(base, profile, seat)
	var shortlist: Array[int] = _shortlist(prompt, prior, profile.think_int("top_k"))
	if shortlist.size() == 1:
		return prompt.options[shortlist[0]]
	var totals: Array[float] = []
	totals.resize(shortlist.size())
	totals.fill(0.0)
	var samples: int = 0
	var deadline: int = Time.get_ticks_msec() + profile.think_int("budget_ms")
	var foe_profile: AiProfile = AiProfile.default_profile()
	for n in range(profile.think_int("samples")):
		var deal: int = rng.randi()
		for k in range(shortlist.size()):
			var sim: DuelEngine = referee.sim_for(seat, deal)
			totals[k] += _playout(sim, sim.prompt_of(seat).options[shortlist[k]], seat, profile, foe_profile)
		samples += 1
		if Time.get_ticks_msec() >= deadline:
			break
	var best: int = 0
	var best_value: float = -INF
	var noise: float = profile.w("think", "noise")
	for k in range(shortlist.size()):
		var value: float = totals[k] / float(samples) + prior[shortlist[k]] * profile.w("think", "prior")
		if noise > 0.0:
			value += rng.randf_range(-noise, noise)
		last_report.append({"option": prompt.options[shortlist[k]].describe(), "prior": prior[shortlist[k]], "value": value, "samples": samples})
		if value > best_value:
			best_value = value
			best = k
	return prompt.options[shortlist[best]]


## Indexes of the `top_k` best options by score, plus one "do nothing" option if there is one.
static func _shortlist(prompt: Prompt, prior: Array[float], top_k: int) -> Array[int]:
	var order: Array[int] = []
	for i in range(prior.size()):
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return prior[a] > prior[b] if prior[a] != prior[b] else a < b)
	var out: Array[int] = []
	for i in order:
		if out.size() < maxi(1, top_k):
			out.append(i)
	for i in order:
		if AiScorer.QUIET.has(prompt.options[i].type):
			if not out.has(i):
				out.append(i)
			break
	return out


## Plays `first`, then the scorer for both seats to the end of the turn, and scores where that
## leaves the table. `think.turns` above 1 plays on through that many further turns, which is what
## it takes to see a plan that builds across turns, such as a Seal the opponent answers next turn.
static func _playout(sim: DuelEngine, first: Command, seat: int, profile: AiProfile, foe_profile: AiProfile) -> float:
	var turn: int = sim.state.turn
	var last: int = turn + maxi(1, profile.think_int("turns")) - 1
	sim.submit(first)
	var steps: int = 0
	var limit: int = profile.think_int("max_steps")
	while not sim.is_over() and sim.state.turn <= last and steps < limit:
		steps += 1
		var who: AiProfile = profile if sim.prompt.player == seat else foe_profile
		sim.submit(AiScorer.pick(sim, who))
	return AiEvaluator.evaluate(sim, seat, profile)
