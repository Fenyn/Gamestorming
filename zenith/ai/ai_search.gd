class_name AiSearch
extends RefCounted
## Sequence planning over shared hidden-card samples. Each observation group chooses one
## action. Iterative deepening publishes only balanced, completed comparisons. Intent is a
## revalidated ordering hint, never a command queue.

var last_report: Array[Dictionary] = []
var metrics: Dictionary = {}
var intent: Dictionary = {}
var goal_steps: Array = []
var _seat: int = 0
var _profile: AiProfile
var _policy_base: AiProfile
var _foe_base: AiProfile
var _deadline: int = 0
var _started: int = 0
var _nodes: int = 0
var _node_limit: int = 0
var _aborted: bool = false
var _last_turn: int = 0
var _policy_cache: Dictionary = {}
var _transpositions: Dictionary = {}
var _old_intent: Dictionary = {}
var _weights: Dictionary = {}
var _perspective: Referee = Referee.new()


func choose(referee: Referee, seat: int, profile: AiProfile, rng: RandomNumberGenerator, policy_base: AiProfile = null) -> Command:
	_started = Time.get_ticks_msec()
	_nodes = 0
	metrics = {"algorithm": "sequence", "nodes": 0, "completed_depth": 0, "cutoff": "", "elapsed_ms": 0,
		"state_pivots": 0, "cache_hits": 0, "intent_status": "new", "rejected": [],
		"unsettled_leaves": 0, "terminal_leaves": 0}
	if str((profile.data["think"] as Dictionary).get("algorithm", "sequence")) == "rollout":
		metrics["algorithm"] = "rollout"
		var legacy: Command = choose_rollout(referee, seat, profile, rng)
		metrics["elapsed_ms"] = Time.get_ticks_msec() - _started
		return legacy
	last_report.clear()
	_seat = seat
	_profile = profile
	_policy_base = policy_base if policy_base != null else profile
	_deadline = _started + profile.think_int("budget_ms") if profile.think_int("budget_ms") > 0 else 0
	_node_limit = maxi(1, profile.think_int("node_budget"))
	_aborted = false
	_policy_cache.clear()
	_transpositions.clear()
	_weights.clear()
	_old_intent = intent
	intent = {}
	var base: DuelEngine = referee.sim_for(seat, rng.randi())
	var prompt: Prompt = base.prompt_of(seat)
	if prompt == null:
		_finish()
		return null
	_last_turn = base.state.turn + maxi(1, profile.think_int("turns")) - 1
	_foe_base = AiProfile.default_profile().for_matchup(base.player(seat).archetype, base.player(seat).subthemes)
	var root_key: String = AiObservation.key(base, seat)
	var remembered: Dictionary = _old_intent.get(root_key, {})
	if remembered.is_empty():
		remembered = _goal_hint(base, prompt)
	metrics["intent_status"] = "matched" if not remembered.is_empty() else ("invalidated" if not _old_intent.is_empty() else "new")
	if prompt.options.size() == 1:
		intent = _old_intent
		_finish()
		return prompt.options[0]
	goal_steps = []
	var prior: Array[float] = AiScorer.scores(base, profile, seat)
	if _available():
		metrics["position"] = AiEvaluator.explain(base, seat, profile)
	var candidates: Array[int] = _candidates(base, prompt, prior, maxi(1, profile.think_int("top_k")))
	if not remembered.is_empty():
		for i in range(prompt.options.size()):
			if prompt.options[i].to_dict() == remembered and not candidates.has(i):
				candidates.append(i)
	_prefer(candidates, prompt, remembered)
	for i in range(prompt.options.size()):
		if not candidates.has(i):
			(metrics["rejected"] as Array).append({"option": prompt.options[i].describe(), "prior": prior[i], "role": _role(base, prompt.options[i])})
	var worlds: Array[DuelEngine] = [base]
	for n in range(1, maxi(1, profile.think_int("samples"))):
		if not _available():
			break
		worlds.append(referee.sim_for(seat, rng.randi()))
	var best_index: int = candidates[0]
	for i in candidates:
		if prior[i] > prior[best_index]:
			best_index = i
	var completed: Array[Dictionary] = []
	for depth in range(1, maxi(1, profile.think_int("sequence_depth")) + 1):
		var round_results: Array[Dictionary] = []
		for i in candidates:
			var next: Array[DuelEngine] = _advance(worlds, prompt.options[i].to_dict())
			if _aborted:
				break
			var result: Dictionary = _visit(next, depth - 1, 1)
			if _aborted:
				break
			result["index"] = i
			round_results.append(result)
		if _aborted:
			break
		completed = round_results
		metrics["completed_depth"] = depth
		var best: float = -INF
		for result in completed:
			var i: int = int(result["index"])
			var value: float = float(result["value"])
			if absf(value) < AiEvaluator.WIN:
				value += clampf(prior[i] * profile.w("think", "prior"), -2.0, 2.0)
			if value > best:
				best = value
				best_index = i
		for result in completed:
			var i: int = int(result["index"])
			var value: float = float(result["value"])
			if absf(best) < AiEvaluator.WIN - 2.0 and not remembered.is_empty() and prompt.options[i].to_dict() == remembered:
				value += clampf(prior[i] * profile.w("think", "prior"), -2.0, 2.0)
				if value >= best - profile.w("think", "intent_margin"):
					best_index = i
					metrics["intent_status"] = "retained"
		if best >= AiEvaluator.WIN:
			break
	if completed.is_empty():
		last_report.append({"option": prompt.options[best_index].describe(), "prior": prior[best_index],
			"value": prior[best_index], "samples": 0, "depth": 0, "line": []})
	else:
		var noise: float = profile.w("think", "noise")
		if noise > 0.0:
			var noisy_best: float = -INF
			for result in completed:
				var value: float = float(result["value"])
				if absf(value) < AiEvaluator.WIN:
					value += rng.randf_range(-noise, noise)
				if value > noisy_best:
					noisy_best = value
					best_index = int(result["index"])
		for result in completed:
			var i: int = int(result["index"])
			var line: Array = [prompt.options[i].describe()]
			line.append_array(result.get("line", []))
			last_report.append({"option": prompt.options[i].describe(), "prior": prior[i], "value": result["value"],
				"samples": worlds.size(), "depth": metrics["completed_depth"], "line": line})
			if i == best_index:
				intent = result["policy"]
				goal_steps = result.get("steps", [])
	intent[root_key] = prompt.options[best_index].to_dict()
	_finish()
	return prompt.options[best_index]


func _finish() -> void:
	metrics["nodes"] = _nodes
	metrics["elapsed_ms"] = Time.get_ticks_msec() - _started
	_transpositions.clear()
	_policy_cache.clear()
	_old_intent = {}
	_weights.clear()
	_perspective.engine = null


func _available() -> bool:
	if _aborted:
		return false
	if _nodes >= _node_limit:
		metrics["cutoff"] = "node_budget"
		_aborted = true
	elif _deadline > 0 and Time.get_ticks_msec() >= _deadline:
		metrics["cutoff"] = "time_budget"
		_aborted = true
	return not _aborted


func policy_for_sim(sim: DuelEngine, seat: int) -> AiProfile:
	var base: AiProfile = _policy_base if seat == _seat else _foe_base
	if (base.data.get("when", {}) as Dictionary).is_empty():
		return base
	var key: String = base.state_key(SeatView.of(sim, seat, false), seat)
	var cache_key: String = "%d|%s" % [seat, key]
	if not _policy_cache.has(cache_key):
		_policy_cache[cache_key] = base.for_state(key)
		if key != "":
			metrics["state_pivots"] = int(metrics.get("state_pivots", 0)) + 1
	return _policy_cache[cache_key]


func _advance(worlds: Array[DuelEngine], wire: Dictionary) -> Array[DuelEngine]:
	var next: Array[DuelEngine] = []
	for world in worlds:
		if not _available():
			return next
		var cmd: Command = AiObservation.find_command(world.prompt_of(int(wire.get("player", _seat))), wire)
		if cmd == null:
			_aborted = true
			metrics["cutoff"] = "inconsistent_options"
			return next
		var sim: DuelEngine = world.clone()
		_weights[sim.get_instance_id()] = _weight(world)
		_nodes += 1
		if not sim.submit(cmd):
			_aborted = true
			metrics["cutoff"] = "illegal_simulation"
			return next
		sim.take_events()
		next.append(sim)
	return next


func _visit(worlds: Array[DuelEngine], depth: int, steps: int) -> Dictionary:
	if not _available():
		return _result(0.0)
	if depth <= 0:
		return _rollout(worlds, mini(_profile.think_int("rollout_steps"), maxi(0, _profile.think_int("max_steps") - steps)))
	if steps >= maxi(1, _profile.think_int("max_steps")):
		return _evaluate(worlds)
	var groups: Dictionary = {}
	var total: float = 0.0
	var mass: float = 0.0
	var policy: Dictionary = {}
	var line: Array = []
	var planned: Array = []
	for sim in worlds:
		if not _available():
			return _result(0.0)
		mass += _weight(sim)
		if sim.is_over() or sim.state.turn > _last_turn or sim.prompt == null:
			total += _value(sim) * _weight(sim)
		else:
			var key: String = "opponent" if sim.prompt.player != _seat else (AiObservation.key(sim, _seat) if worlds.size() > 1 else "own")
			if not groups.has(key):
				groups[key] = [] as Array[DuelEngine]
			(groups[key] as Array[DuelEngine]).append(sim)
	for key in groups:
		var group: Array[DuelEngine] = groups[key]
		var result: Dictionary = _opponent(group, depth, steps) if key == "opponent" else _group(group, depth, steps, str(key))
		if _aborted:
			return _result(0.0)
		total += float(result["value"]) * _mass(group)
		policy.merge(result["policy"])
		if line.is_empty():
			line = result["line"]
			planned = result.get("steps", [])
	return {"value": total / maxf(0.000001, mass), "policy": policy, "line": line, "steps": planned}


## Opponent private observations must never split our future information sets. Expand their
## plausible replies into weighted particles, then regroup successors by what WE observe.
func _opponent(worlds: Array[DuelEngine], depth: int, steps: int) -> Dictionary:
	var successors: Array[DuelEngine] = []
	var forced: bool = true
	for world in worlds:
		var single: Array[DuelEngine] = [world]
		var scores: Array[float] = _scores(single)
		var choices: Array[int] = _shortlist(world.prompt, scores, maxi(1, _profile.think_int("response_width")))
		forced = forced and world.prompt.options.size() == 1
		var normalizer: float = 0.0
		for rank in range(choices.size()):
			normalizer += 1.0 / float(rank + 1)
		for rank in range(choices.size()):
			var next: Array[DuelEngine] = _advance(single, world.prompt.options[choices[rank]].to_dict())
			if _aborted:
				return _result(0.0)
			_weights[next[0].get_instance_id()] = _weight(world) / float(rank + 1) / normalizer
			successors.append(next[0])
	return _visit(successors, depth if forced else depth - 1, steps + 1)


func _group(worlds: Array[DuelEngine], depth: int, steps: int, observation: String) -> Dictionary:
	var sim: DuelEngine = worlds[0]
	var prompt: Prompt = sim.prompt
	if prompt.options.size() == 1:
		return _visit(_advance(worlds, prompt.options[0].to_dict()), depth, steps + 1)
	var cache_key: String = ""
	if bool((_profile.data["think"] as Dictionary).get("cache", false)):
		var keys: Array[String] = []
		for world in worlds:
			var key: String = AiObservation.state_key(world)
			if key == "":
				keys.clear()
				break
			keys.append(str(_weight(world)) + ":" + key)
		if not keys.is_empty():
			cache_key = "%d|%d|%s" % [depth, steps, "|".join(keys)]
			if _transpositions.has(cache_key):
				metrics["cache_hits"] = int(metrics["cache_hits"]) + 1
				return _transpositions[cache_key]
	var scores: Array[float] = _scores(worlds)
	var width: int = _profile.think_int("branch_width")
	var candidates: Array[int] = _candidates(sim, prompt, scores, maxi(1, width))
	if observation != "own":
		_prefer(candidates, prompt, _old_intent.get(observation, {}))
	var best: Dictionary = _result(-INF)
	for rank in range(candidates.size()):
		var i: int = candidates[rank]
		var result: Dictionary = _visit(_advance(worlds, prompt.options[i].to_dict()), depth - 1, steps + 1)
		if _aborted:
			return _result(0.0)
		if float(result["value"]) > float(best["value"]):
			best = result.duplicate()
			var continuation: Dictionary = (result["policy"] as Dictionary).duplicate()
			if observation != "own":
				continuation[observation] = prompt.options[i].to_dict()
			best["policy"] = continuation
			var line: Array = [prompt.options[i].describe()]
			line.append_array(result["line"])
			best["line"] = line
			var planned: Array = [_semantic(sim, prompt.options[i])]
			planned.append_array(result.get("steps", []))
			best["steps"] = planned
	if cache_key != "":
		_transpositions[cache_key] = best
	return best


func _scores(worlds: Array[DuelEngine]) -> Array[float]:
	var prompt: Prompt = worlds[0].prompt
	var totals: Array[float] = []
	totals.resize(prompt.options.size())
	totals.fill(0.0)
	for sim in worlds:
		if not _available():
			return totals
		var who: int = prompt.player
		var perceived: DuelEngine = sim
		if who != _seat:
			# Switch perspective through the same public-prior boundary. Shuffling alone
			# would retain our undisclosed deck composition in the opponent's model.
			_perspective.engine = sim
			perceived = _perspective.sim_for(who, 7919 + sim.state.turn)
		var playing: AiProfile = policy_for_sim(perceived, who)
		var values: Array[float] = AiScorer.scores(perceived, playing, who)
		var by_command: Dictionary = {}
		for i in range(values.size()):
			by_command[AiObservation.command_key(perceived.prompt_of(who).options[i])] = values[i]
		for i in range(totals.size()):
			totals[i] += float(by_command.get(AiObservation.command_key(prompt.options[i]), 0.0)) * _weight(sim) / _mass(worlds)
	return totals


func _rollout(worlds: Array[DuelEngine], remaining: int) -> Dictionary:
	if not _available():
		return _result(0.0)
	if remaining <= -maxi(0, _profile.think_int("settle_steps")):
		return _evaluate(worlds)
	var groups: Dictionary = {}
	var total: float = 0.0
	var mass: float = 0.0
	var policy: Dictionary = {}
	var line: Array = []
	var planned: Array = []
	for sim in worlds:
		if not _available():
			return _result(0.0)
		mass += _weight(sim)
		if sim.is_over() or sim.state.turn > _last_turn or sim.prompt == null or (remaining <= 0 and _settled(sim)):
			total += _value(sim) * _weight(sim)
		else:
			var key: String = "opponent" if sim.prompt.player != _seat else (AiObservation.key(sim, _seat) if worlds.size() > 1 else "own")
			if not groups.has(key):
				groups[key] = [] as Array[DuelEngine]
			(groups[key] as Array[DuelEngine]).append(sim)
	for key in groups:
		var group: Array[DuelEngine] = groups[key]
		if key == "opponent":
			var successors: Array[DuelEngine] = []
			for world in group:
				var single: Array[DuelEngine] = [world]
				var ranked: Array[float] = _scores(single)
				var choice: int = 0
				for i in range(ranked.size()):
					if ranked[i] > ranked[choice]:
						choice = i
				successors.append_array(_advance(single, world.prompt.options[choice].to_dict()))
				if _aborted:
					return _result(0.0)
			var reply: Dictionary = _rollout(successors, remaining - 1)
			if _aborted:
				return _result(0.0)
			total += float(reply["value"]) * _mass(group)
			policy.merge(reply["policy"])
			if line.is_empty():
				line = reply["line"]
				planned = reply.get("steps", [])
			continue
		var scores: Array[float] = _scores(group)
		var best: int = 0
		for i in range(scores.size()):
			if scores[i] > scores[best]:
				best = i
		var cmd: Command = group[0].prompt.options[best]
		var result: Dictionary = _rollout(_advance(group, cmd.to_dict()), remaining - 1)
		if _aborted:
			return _result(0.0)
		total += float(result["value"]) * _mass(group)
		policy.merge(result["policy"])
		if cmd.player == _seat and key != "own":
			policy[key] = cmd.to_dict()
		if line.is_empty():
			line = [cmd.describe()]
			line.append_array(result["line"])
			if cmd.player == _seat:
				planned.append(_semantic(group[0], cmd))
			planned.append_array(result.get("steps", []))
	return {"value": total / maxf(0.000001, mass), "policy": policy, "line": line, "steps": planned}


func _value(sim: DuelEngine) -> float:
	# All leaves use the same root scale. Changing policies must not manufacture value.
	if not _settled(sim) and not sim.is_over():
		metrics["unsettled_leaves"] = int(metrics["unsettled_leaves"]) + 1
	if sim.is_over():
		metrics["terminal_leaves"] = int(metrics["terminal_leaves"]) + 1
	var value: float = AiEvaluator.evaluate(sim, _seat, _profile)
	return value if sim.is_over() else clampf(value, -AiEvaluator.WIN + 10.0, AiEvaluator.WIN - 10.0)


static func _settled(sim: DuelEngine) -> bool:
	return sim.state.attack.is_empty() and sim.state.pending_play.is_empty() and sim._queue.is_empty() and sim._choice.is_empty() and sim._pending_then.is_empty()


func _evaluate(worlds: Array[DuelEngine]) -> Dictionary:
	var value: float = 0.0
	for sim in worlds:
		if not _available():
			return _result(0.0)
		value += _value(sim) * _weight(sim)
	return _result(value / maxf(0.000001, _mass(worlds)))


func _weight(sim: DuelEngine) -> float:
	return float(_weights.get(sim.get_instance_id(), 1.0))


func _mass(worlds: Array[DuelEngine]) -> float:
	var total: float = 0.0
	for world in worlds:
		total += _weight(world)
	return total


static func _result(value: float) -> Dictionary:
	return {"value": value, "policy": {}, "line": [], "steps": []}


## A tutor reveals new UID/identity associations, so exact sampled observations often change.
## Remember the intended kind of card as well; it is only an ordering/tie hint after revelation.
func _goal_hint(sim: DuelEngine, prompt: Prompt) -> Dictionary:
	for step in goal_steps.slice(0, 4):
		for option in prompt.options:
			if _semantic(sim, option) == step:
				return option.to_dict()
	return {}


static func _semantic(sim: DuelEngine, cmd: Command) -> Dictionary:
	var card: CardInstance = sim.card(cmd.card)
	return {"type": String(cmd.type), "card": card.def.id if card != null else "", "value": cmd.value}


static func _prefer(indices: Array[int], prompt: Prompt, wire: Dictionary) -> void:
	for i in indices:
		if not wire.is_empty() and prompt.options[i].to_dict() == wire:
			indices.erase(i)
			indices.push_front(i)
			return


static func _candidates(sim: DuelEngine, prompt: Prompt, prior: Array[float], width: int) -> Array[int]:
	var order: Array[int] = []
	for i in range(prior.size()):
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return prior[a] > prior[b] if prior[a] != prior[b] else a < b)
	var out: Array[int] = []
	var roles: Dictionary = {}
	for i in order:
		var role: String = _role(sim, prompt.options[i])
		if out.size() < width and not roles.has(role):
			out.append(i)
			roles[role] = true
	for i in order:
		if out.size() < width and not out.has(i):
			out.append(i)
	for i in order:
		if AiScorer.QUIET.has(prompt.options[i].type):
			if not out.has(i):
				out.append(i)
			break
	return out


static func _role(sim: DuelEngine, cmd: Command) -> String:
	if AiScorer.QUIET.has(cmd.type):
		return "quiet"
	var card: CardInstance = sim.card(cmd.card)
	if card != null:
		var pending: Array = card.def.effects.duplicate()
		if card.def.is_personality():
			pending.append_array(card.power().get("effects", []))
		while not pending.is_empty():
			var raw: Variant = pending.pop_back()
			if not raw is Dictionary:
				continue
			var effect: Dictionary = raw
			var op: String = str(effect.get("op", ""))
			if op == "search" or op == "bond":
				return op
			pending.append_array(effect.get("then", []))
		if card.def.is_defense():
			return "defense"
		if card.def.type == CardDef.Type.PERSONALITY:
			return "ally"
		if card.def.type == CardDef.Type.DRILL or card.def.type == CardDef.Type.NON_COMBAT:
			return "engine"
	return String(cmd.type)


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


## Historical rollout baseline for arena comparisons (think.algorithm = "rollout").
func choose_rollout(referee: Referee, seat: int, profile: AiProfile, rng: RandomNumberGenerator) -> Command:
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
	# The opponent is modelled generically, because how they weigh things is their own business and
	# not on the table. What is on the table is our declared archetype, so the model at least
	# assumes they know what they are facing and pivot against it the way we do.
	var foe_profile: AiProfile = AiProfile.default_profile().for_matchup(
		base.player(seat).archetype, base.player(seat).subthemes)
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
