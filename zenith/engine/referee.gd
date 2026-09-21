class_name Referee
extends RefCounted
## Holds the one true DuelEngine and speaks to seats only in views. A seat submits a Command in
## wire form; the referee accepts it only if it is the pending prompt's and one of its options,
## then hands each seat a SeatUpdate with what happened and what it may see now.
##
## The same object serves hotseat (one process, both seats), a hosting client (seat 0 local,
## seat 1 over the wire) and later a headless server (both seats over the wire).

## Events a client animates, with the fields it may have. Everything named here is public once
## the event has happened (a card that reached a pile, a number both players watched land), so
## the same data goes to both seats. Any event not listed reaches clients as its line alone.
## A played card's id remains public for this replay beat even if its final zone is hidden.
const ANIMATED: Dictionary = {
	&"combat_begin": [], &"combat_end": [],
	&"attack_declared": ["kind", "source", "is_power", "is_final", "focused", "empowered"],
	&"defense_played": ["card", "id", "stopped"], &"defense_power": ["card"], &"shield": ["card"],
	&"attack_stopped": [], &"attack_successful": [],
	&"base_damage": ["stages", "life"], &"modified_damage": ["stages", "life"],
	&"damage_stages": ["target", "stages", "overflow", "energy"],
	&"life_card_flipped": ["card", "remaining"], &"life_card_lost": ["card"],
	&"endurance_used": ["card", "prevented"], &"endurance_declined": ["card", "endurance", "remaining"],
	&"seal_bypassed": ["card"], &"seal_captured": ["card"],
	&"attack_end": ["stopped", "stages_dealt", "life_dealt"],
	&"critical_ally": ["card"], &"critical_fervor": [],
	&"hand_discarded": ["card"], &"in_play_discarded": ["card", "removed"], &"card_moved": ["card", "to"],
	&"card_used": ["card", "id"], &"card_placed": ["card"], &"final_strike": ["discarded"],
	&"remain": ["card", "uses"],
	&"power_up": ["gain", "energy", "energies"], &"recover": ["card"],
	&"energy_changed": ["card", "from", "to", "source"], &"gain_blocked": ["card", "amount"],
	&"fervor_changed": ["from", "to", "source"], &"fervor_shielded": [], &"aspect_up": ["aspect"], &"aspect_down": ["aspect"],
	&"trigger_fired": ["card", "trigger"], &"draw": ["card", "from"],
	&"countered": ["card", "target"], &"game_over": ["winner", "reason"],
}

var engine: DuelEngine = DuelEngine.new()
var _pending_events: Array[GameEvent] = []
# Eligible definitions depend only on immutable rules and public setup declarations.
var _belief_candidate_cache: Dictionary = {}


## Headless drivers omit animation snapshots; live clients keep them by default.
func setup(decks: Array[DeckList], library: CardLibrary, table: StrikeTable, seed_value: int, names: Array[String] = [], capture_display: bool = true) -> void:
	_belief_candidate_cache.clear()
	engine.record_display_state = capture_display
	engine.setup(decks, library, table, seed_value, names)


func start() -> void:
	engine.start()


func is_over() -> bool:
	return engine.is_over()


func seed_value() -> int:
	return engine.state.seed_value


## "" when applied, otherwise the reason it was refused. Nothing changes on a refusal.
func submit(seat: int, wire: Dictionary) -> String:
	if engine.prompt == null or engine.is_over():
		return "Nothing is waiting on a decision."
	var p: Prompt = engine.prompt_of(seat)
	if p == null:
		return "It is not your decision."
	var cmd: Command = Command.from_dict(wire)
	if cmd.player != seat:
		return "That command belongs to another seat."
	var accepted: Command = p.accept(cmd)
	if accepted == null:
		return "That choice is not open right now."
	engine.submit(accepted)
	return ""


## Dev tool: {"player": seat, "effect": {...}}. Only the process holding the engine can call it.
func dev(wire: Dictionary) -> String:
	if engine.is_over():
		return "The duel is over."
	return engine.dev_effect(int(wire.get("player", 0)), wire.get("effect", {}))


## The updates owed to both seats since the last call, index by seat.
func take_updates() -> Array[SeatUpdate]:
	var events: Array[GameEvent] = engine.take_events()
	var out: Array[SeatUpdate] = []
	for seat in range(2):
		var u: SeatUpdate = SeatUpdate.new()
		# Lines are worded per seat: a card this seat may not see is never named in its log.
		for ev in events:
			var line: String = CardText.event_line(ev, engine, seat)
			var entry: Dictionary = {"type": String(ev.type), "player": int(ev.data.get("player", -1)), "line": line}
			if ANIMATED.has(ev.type):
				var data: Dictionary = {}
				for key in ANIMATED[ev.type]:
					if ev.data.has(key):
						data[key] = ev.data[key]
				entry["data"] = data
				# What the table read at that moment, so the beat draws the state it belongs to
				# instead of the state at the end of the whole update.
				if not ev.state.is_empty():
					entry["state"] = ev.state
			u.lines.append(entry)
		u.view = view_for(seat)
		u.prompt = prompt_for(seat)
		out.append(u)
	return out


## A simulation keeps the seat's own known composition, randomizes unknown placement, and
## replaces the rival's undisclosed composition with a public-information library prior.
## This is a broad belief, not knowledge of a custom decklist or a learned archetype model.
func sim_for(seat: int, sample_seed: int) -> DuelEngine:
	var sim: DuelEngine = engine.clone()
	sim.determinize(seat, sample_seed)
	_sample_opponent_pool(sim, seat, sample_seed, _belief_candidate_cache)
	return sim


## The same sample as `sim_for`, written into an engine the caller already owns. Identical result;
## it only skips the allocation. The search calls this once per world at every opponent node.
func sim_into(seat: int, sample_seed: int, spare: DuelEngine) -> DuelEngine:
	engine.clone_into(spare)
	spare.determinize(seat, sample_seed)
	_sample_opponent_pool(spare, seat, sample_seed, _belief_candidate_cache)
	return spare


func view_for(seat: int, include_forecasts: bool = true) -> SeatView:
	return SeatView.of(engine, seat, include_forecasts)


## Decision metadata without constructing labels and outcome previews for every option.
func prompt_kind_for(seat: int) -> StringName:
	var p: Prompt = engine.prompt_of(seat)
	return p.kind if p != null else &""


## The pending prompt when it is this seat's, else null.
func prompt_for(seat: int) -> PromptView:
	var p: Prompt = engine.prompt_of(seat)
	return PromptView.of(p, engine) if p != null else null


## Hidden slots keep their UIDs/zones. Only the acting seat's visible cards and explicitly
## revealed search/choice cards contribute counts; no authoritative unseen definition enters
## the prior. Opponent Reserve commands enumerate these same UIDs and remain valid.
static func _sample_opponent_pool(sim: DuelEngine, seat: int, sample_seed: int, candidate_cache: Dictionary) -> void:
	# Use the same SeatCard reveal policy without constructing unrelated attack forecasts.
	var rival: SeatPlayer = SeatPlayer.of(sim.player(1 - seat), sim)
	var duelist: CardDef = sim.card(rival.duelist).def
	var shown: Dictionary = {}
	var pending: Prompt = sim.prompt_of(seat)
	if pending != null:
		for uid in pending.card_options():
			shown[uid] = true
		for uid in pending.context.get("library", []):
			shown[int(uid)] = true
	var unknown: Array[int] = []
	var counts: Dictionary = {}
	var seal_set: String = ""
	# Read the same reveal policy without building a SeatCard per card. Only three facts are
	# wanted here (owner, hidden, def id) and `SeatCard.of` allocated a full view for each, which
	# measured at 758 us of the 1350 us this sample costs, once per opponent node.
	for card in sim.all_cards():
		if card.owner != rival.index:
			continue
		if not (shown.has(card.uid) or SeatCard.visible_to(card, seat)):
			unknown.append(card.uid)
			continue
		var def_id: String = card.def.id
		counts[def_id] = int(counts.get(def_id, 0)) + 1
		var def: CardDef = sim.library.defs.get(def_id)
		if def != null and def.type == CardDef.Type.SEAL:
			seal_set = def.seal_set
	if unknown.is_empty():
		return
	unknown.sort()
	# The library is immutable for the life of a duel, so its instance id identifies it. Hashing
	# `defs` here re-hashed every card definition on every sample, which the search pays per node.
	var cache_key: String = "%d|%s|%s|%d|%s" % [sim.library.get_instance_id(), rival.style,
		rival.alignment, rival.highest_aspect, duelist.character]
	var ids: Array = []
	var allowed: Array[CardDef] = []
	var sets: Array[String] = []
	if candidate_cache.has(cache_key):
		# Read the cached arrays in place. `assign` copied several hundred CardDefs per call.
		var cached: Dictionary = candidate_cache[cache_key]
		ids = cached["ids"]
		allowed = cached["allowed"]
		sets = cached["sets"]
	else:
		ids = sim.library.defs.keys()
		ids.sort()
		for id in ids:
			var def: CardDef = sim.library.defs[id]
			if not _belief_card_allowed(def, rival, duelist):
				continue
			allowed.append(def)
			if def.type == CardDef.Type.SEAL and not sets.has(def.seal_set):
				sets.append(def.seal_set)
		if candidate_cache.size() >= 16:
			candidate_cache.clear()
		candidate_cache[cache_key] = {"ids": ids, "allowed": allowed, "sets": sets}
	var dealer: ZenithRng = ZenithRng.new(sample_seed ^ 0x51A7BEEF)
	if seal_set == "" and not sets.is_empty():
		seal_set = sets[dealer.randi_range(0, sets.size() - 1)]
	var pool: Array[CardDef] = []
	var fallback: Array[CardDef] = []
	for def in allowed:
		if def.type == CardDef.Type.SEAL and def.seal_set != seal_set:
			continue
		fallback.append(def)
		var limit: int = def.limit_per_deck
		if def.type in [CardDef.Type.PERSONALITY, CardDef.Type.SEAL]:
			limit = 1
		elif duelist != null and def.character != "" and def.character == duelist.character and limit >= DeckValidator.DEFAULT_LIMIT:
			limit = DeckValidator.SIGNATURE_LIMIT
		for copy_index in range(maxi(0, limit - int(counts.get(def.id, 0)))):
			pool.append(def)
	# Small rule-test libraries may not contain enough legal copies for their intentionally
	# invalid fixture decks. Relax copy limits in that case, never consult the hidden truth.
	if fallback.is_empty():
		for id in ids:
			var def: CardDef = sim.library.defs[id]
			if def.type not in [CardDef.Type.MASTERY, CardDef.Type.RELIC]:
				fallback.append(def)
	if fallback.is_empty():
		# An invalid fixture may contain only setup definitions; keep even that fallback
		# independent of its authoritative hidden identities. Valid decks never use it.
		for id in ids:
			fallback.append(sim.library.defs[id])
	if fallback.is_empty():
		return  # A library with no definitions cannot contain a valid hidden card.
	for uid in unknown:
		var def: CardDef
		if pool.is_empty():
			def = fallback[dealer.randi_range(0, fallback.size() - 1)]
		else:
			var index: int = dealer.randi_range(0, pool.size() - 1)
			def = pool[index]
			pool.remove_at(index)
		var card: CardInstance = sim.card(uid)
		card.def = def
		card.aspect = def.aspect if def.is_personality() else 1


static func _belief_card_allowed(def: CardDef, player: SeatPlayer, duelist: CardDef) -> bool:
	if def.type in [CardDef.Type.MASTERY, CardDef.Type.RELIC]:
		return false
	if def.school != "" and def.school != player.style:
		return false
	if def.is_personality():
		if duelist != null and def.character == duelist.character:
			return false
		if def.alignment_only != "" and def.alignment_only != player.alignment:
			return false
		if not DeckValidator.ally_aspect_allowed(def.aspect, player.highest_aspect):
			return false
	return true
