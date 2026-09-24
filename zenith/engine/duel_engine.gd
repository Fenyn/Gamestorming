class_name DuelEngine
extends RefCounted
## Zenith rules engine. Pure state machine with no Nodes.
## Commands in, GameEvents out. It runs until a player has to decide something,
## then exposes that decision as `prompt`. Answer it with `submit`.
## Same seed plus same commands replays the same game.
##
## Effects run through a queue that can pause for a choice prompt and resume afterwards,
## so a card's text can ask its owner (or the target) to pick cards mid-resolution.

const STARTING_ENERGY: int = 5
const DOUBLE_POWER_ENERGY: int = 2   # the stronger duelist's start under the Double Power Rule
const ALLY_STARTING_ENERGY: int = 3
const LOST_ASPECT_ENERGY: int = 5
const DRAW_COUNT: int = 3
const HAND_KEEP: int = 1
const FERVOR_TO_ASPECT: int = 5
const ART_COST: int = 2
const ART_BASE_LIFE: int = 4
const WILD_BASE_DAMAGE: int = 2
## `use_at` on a defense card that answers an attack only once it is already through.
const LATE_STOP: String = "successful_attack"
const CRITICAL_THRESHOLD: int = 5   # life cards from one attack that make it critical damage
const SEALS_PER_SET: int = 7
const ALLY_CONTROL_MAX_ENERGY: int = 1
const MAX_ADVANCE_ITERATIONS: int = 100000
## Every forbid `what` the rules consult; `restrictions` reports which are in force on a player.
const FORBID_KINDS: Array[String] = [
	"strike_attacks", "art_attacks", "strike_cards", "art_cards", "combat_cards", "non_combats",
	"drills", "seals", "mastery", "powers", "stop_all", "end_combat", "non_attack_actions", "skip_combat",
	"allies", "lower_aspect", "lower_own_aspect", "relic",
]

var state: GameState = GameState.new()
var library: CardLibrary = null
var strike_table: StrikeTable = null
var rng: ZenithRng = null
## Pending decisions, one per player at most. Almost always one; the Reserve swap at setup
## holds one for each player so both swap at once. `prompt` is the first of them, which is what
## every turn step, the AI playout and the tools read; `prompt_of` is the one for a given seat.
var prompts: Array[Prompt] = []
var prompt: Prompt:
	get:
		return prompts[0] if not prompts.is_empty() else null
	set(p):
		prompts.clear()
		if p != null:
			prompts.append(p)
var events: Array[GameEvent] = []
var shuffle_decks: bool = true
## Stamp every event with the table numbers as they stood when it fired, so a client can pace
## the beats. A Referee turns it on for its own engine; `clone()` leaves it off, so the AI's
## simulations never pay for it.
var record_display_state: bool = false
var _cards: Dictionary = {}   # uid -> CardInstance
var _next_uid: int = 1
var _combat_ending: bool = false
var _pending_attack: int = -1        # a card fetched to be performed in this same attack phase
var _reserve_swapped: Dictionary = {}
## The turn whose Discard Step has already fired its triggers, so re-entering does not repeat them.
var _discard_step_fired: int = -1
var _queue: Array[Dictionary] = []   # effect jobs: {effects, index, trigger, owner, ctx, source}
var _choice: Dictionary = {}         # how to finish the effect that raised the pending prompt
var _pending_then: Dictionary = {}   # "then" effects waiting on the prompt the current effect raised
var _effect_source: CardInstance = null   # the card whose effect is being applied, for log attribution


# --- Public API -----------------------------------------------------------

## `names` are the players' display names; a seat without one is named after its deck.
func setup(decks: Array[DeckList], p_library: CardLibrary, p_table: StrikeTable, seed_value: int, names: Array[String] = []) -> void:
	assert(decks.size() == 2, "Zenith is a two-player duel")
	library = p_library
	strike_table = p_table
	rng = ZenithRng.new(seed_value)
	state = GameState.new()
	state.seed_value = seed_value
	for i in range(2):
		state.players.append(_build_player(i, decks[i]))
		if i < names.size() and names[i] != "":
			state.players[i].name = names[i]
	_apply_first_player_rule()
	_emit(&"setup", {"first": state.active, "seed": seed_value})


## Call between `setup()` and `start()`. 1 is the printed game; adventure duels use 2 for both.
func set_points_to_win(n: int) -> void:
	assert(state.step == GameState.Step.SETUP and state.turn == 0, "set_points_to_win() after start()")
	state.points_to_win = [maxi(1, n), maxi(1, n)]


## Lives per seat: how many points the rival has to score against that seat. Adventure gives the
## player two and an ordinary opponent one, a boss two (2026-09-22). Call between `setup()` and
## `start()`.
func set_lives(lives: Array) -> void:
	assert(state.step == GameState.Step.SETUP and state.turn == 0, "set_lives() after start()")
	state.points_to_win = [maxi(1, int(lives[1])), maxi(1, int(lives[0]))]


## Two first-to-N options under trial, both off unless asked for: a full Seal set scores one point
## in place of winning outright, and a duelist's own "remove from the game after use" cards rejoin
## the Life Deck that is rebuilt when they lose a point.
func set_points_options(seal_scores_point: bool, second_life_returns_used: bool) -> void:
	assert(state.step == GameState.Step.SETUP and state.turn == 0, "set_points_options() after start()")
	state.seal_scores_point = seal_scores_point
	state.second_life_returns_used = second_life_returns_used


func start() -> void:
	assert(state.step == GameState.Step.SETUP and state.turn == 0, "start() called twice")
	state.reserve_index = 0
	state.reserve_finished = [false, false]
	_reserve_swapped = {}
	_run()


## Answer the pending prompt. Returns false and changes nothing if the command is not one of its options.
func submit(cmd: Command) -> bool:
	var p: Prompt = prompt_of(cmd.player)
	if p == null or state.is_over():
		push_warning("DuelEngine.submit: nothing pending for player %d" % cmd.player)
		return false
	var chosen: Command = p.accept(cmd)
	if chosen == null:
		push_warning("DuelEngine.submit: %s is not legal for %s" % [cmd.describe(), p.describe()])
		return false
	var kind: StringName = p.kind
	var context: Dictionary = p.context
	prompts.erase(p)
	_emit(&"command", {"player": chosen.player, "type": chosen.type, "card": chosen.card, "value": chosen.value})
	_handle(kind, chosen, context)
	_run()
	return true


## Card bookkeeping check, "" when sound. Every card may sit in one zone list only, and a card in
## the hand, discard, Life Deck, removed pile or Reserve must say so in its own `zone`. A card in
## two places is how a spent card came back for free use (2026-09-22, the Watchful Eye loop), so
## the Referee runs this after every command and the sim harness fails the match on it.
func integrity_problem() -> String:
	var seen: Dictionary = {}   # uid -> where it was first found
	for p in state.players:
		var lists: Dictionary = {&"hand": p.hand, &"discard": p.discard, &"life_deck": p.life_deck,
			&"removed": p.removed, &"reserve": p.reserve, &"in_play": p.in_play}
		for zone in lists.keys():
			for c in (lists[zone] as Array[CardInstance]):
				var where: String = "player %d %s" % [p.index, zone]
				if seen.has(c.uid):
					return "%s #%d is listed twice: %s and %s" % [c.def.id, c.uid, seen[c.uid], where]
				seen[c.uid] = where
				if zone != &"in_play" and c.zone != zone:
					return "%s #%d sits in %s but its zone says %s" % [c.def.id, c.uid, where, c.zone]
	return ""


func is_over() -> bool:
	return state.is_over()


## The pending prompt that is `player`'s, or null.
func prompt_of(player: int) -> Prompt:
	for p in prompts:
		if p.player == player:
			return p
	return null


## An independent engine in the same position: same cards, same pending prompt, same random
## stream. Card definitions, the library and the Strike Table are shared because nothing writes
## to them. The copy starts with no events. For simulation; a seat must get one through
## Referee.sim_for so it never learns what it may not see.
func clone() -> DuelEngine:
	return clone_into(DuelEngine.new())


## `clone()` over an engine that already exists, reusing its CardInstances rather than allocating
## fresh ones. `e` must be an engine no one is still reading; the AI search recycles its own.
func clone_into(e: DuelEngine) -> DuelEngine:
	e.library = library
	e.strike_table = strike_table
	e.rng = rng.copy()
	e.shuffle_decks = shuffle_decks
	e.record_display_state = false
	e.events.clear()
	var spare: Dictionary = e._cards
	e._cards = {}
	for uid in _cards:
		var source: CardInstance = _cards[uid]
		var target: CardInstance = spare.get(uid, null)
		if target == null:
			e._cards[uid] = source.copy()
		else:
			source.copy_into(target)
			e._cards[uid] = target
	# `copy()` leaves these pointing at the original's cards, so re-point them. Nearly every card
	# has neither, but each still needs its own array, since `cards_under` is mutated in place.
	for uid in e._cards:
		var c: CardInstance = e._cards[uid]
		if c.attached_to != null:
			c.attached_to = e._cards[c.attached_to.uid]
		if c.cards_under.is_empty():
			c.cards_under = [] as Array[CardInstance]
		else:
			c.cards_under = PlayerState._mapped_list(c.cards_under, e._cards)
	e.state = state.copy(e._cards)
	e.prompts.clear()
	for p in prompts:
		e.prompts.append(p.copy())
	e._next_uid = _next_uid
	e._combat_ending = _combat_ending
	e._pending_attack = _pending_attack
	e._reserve_swapped = _reserve_swapped.duplicate()
	e._discard_step_fired = _discard_step_fired
	e._queue.assign(_remap(_queue, e._cards))
	e._choice = _remap(_choice, e._cards)
	e._pending_then = _remap(_pending_then, e._cards)
	e._effect_source = PlayerState._mapped(_effect_source, e._cards)
	return e


## Forget what `seat` cannot see: every card hidden from it trades identities at random with the
## other hidden cards of the same owner, so the hands and Life Decks of this engine are one guess
## at the truth and nothing more. Zones, counts and uids stay put. Cards the pending prompt shows
## to `seat` keep their identity. The random stream is replaced too, since the real one decides
## future shuffles.
func determinize(seat: int, sample_seed: int) -> void:
	var dealer: ZenithRng = ZenithRng.new(sample_seed)
	var shown: Dictionary = {}
	var mine: Prompt = prompt_of(seat)
	if mine != null:
		for uid in mine.card_options():
			shown[uid] = true
		for uid in mine.context.get("library", []):
			shown[int(uid)] = true
	for owner in range(2):
		var hidden: Array[CardInstance] = []
		var defs: Array[CardDef] = []
		for uid in _cards:
			var c: CardInstance = _cards[uid]
			if c.owner == owner and not shown.has(c.uid) and not SeatCard.visible_to(c, seat):
				hidden.append(c)
				defs.append(c.def)
		dealer.shuffle(defs)
		for i in range(hidden.size()):
			hidden[i].def = defs[i]
			hidden[i].aspect = defs[i].aspect if defs[i].is_personality() else 1
	rng = dealer


## Deep copy of effect bookkeeping with every CardInstance swapped for the copy's own.
static func _remap(v: Variant, cards: Dictionary) -> Variant:
	if v is CardInstance:
		return cards[(v as CardInstance).uid]
	if v is Dictionary:
		var d: Dictionary = (v as Dictionary).duplicate()
		for k in d:
			d[k] = _remap(d[k], cards)
		return d
	if v is Array:
		var a: Array = (v as Array).duplicate()
		for i in range(a.size()):
			a[i] = _remap(a[i], cards)
		return a
	return v


## Prompts that the step machine re-issues unchanged when asked again, so a dev effect can run
## in front of them and the same decision comes back afterwards.
const DEV_SAFE_PROMPTS: Array[StringName] = [&"reserve", &"non_combat", &"declare", &"attack_action", &"defense", &"keep", &"recover", &"combat_end", &"start_play"]


## Dev tool: runs one effect for `owner` through the normal queue, triggers included, then
## re-prompts. "" when applied, else why not.
func dev_effect(owner: int, e: Dictionary) -> String:
	if state.is_over():
		return "The duel is over."
	if prompt == null or not DEV_SAFE_PROMPTS.has(prompt.kind) or not _queue.is_empty() or not _choice.is_empty():
		return "Not while a card effect is mid-resolution."
	var op: String = str(e.get("op", ""))
	if op == "end_combat" and state.step != GameState.Step.COMBAT:
		return "No Combat to end."
	prompt = null
	_emit(&"dev", {"player": owner, "op": op, "who": str(e.get("who", "self"))})
	match op:
		"end_combat":
			_end_combat()
		"end_turn":
			if state.step == GameState.Step.COMBAT:
				_end_combat()
			_end_turn()
		_:
			var list: Array[Dictionary] = [e]
			_queue.append({"effects": list, "index": 0, "trigger": "dev", "owner": owner, "ctx": {}, "source": null})
	_run()
	return ""


## Returns and clears the events accumulated since the last call.
func take_events() -> Array[GameEvent]:
	var out: Array[GameEvent] = events
	events = []
	return out


func card(uid: int) -> CardInstance:
	return _cards.get(uid)


func all_cards() -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	out.assign(_cards.values())
	return out


func player(i: int) -> PlayerState:
	return state.players[i]


## What the engine still has to resolve, first item first, in the order it actually works through
## them: the attack in the air, the card waiting on its counter window, every job in the effect
## queue (a `then` job reads first because `_flush_then` inserts it at the front), then the wounds
## the life-damage loop has left to flip. Exactly one item carries `current`, the one the engine is
## standing on now.
##
## Each item is {kind: StringName, uid: int, title: String, owner: int, target: int, note: String,
## current: bool}, with `target` -1 when the item has none. This is seat-blind, so it names a card
## a seat may not be allowed to see: `SeatView.of` masks it before a client ever reads it. Nothing
## outside `engine/` should call this directly.
func pending_items() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var a: Dictionary = state.attack
	var wounds: int = int(a.get("life_remaining", 0)) if not a.is_empty() else 0
	# Wounds are only a queue of their own once the damage is being dealt; before step 12 the
	# number is still a forecast the attack item already carries.
	var wounds_live: bool = wounds > 0 and state.battle_step >= 12
	var current: StringName = &""
	if not state.pending_play.is_empty():
		current = &"pending_card"
	elif not _queue.is_empty():
		current = &"trigger"
	elif wounds_live:
		current = &"wounds"
	elif not a.is_empty():
		current = &"attack"
	var defender_uid: int = -1
	if not a.is_empty():
		defender_uid = int(a.get("target", -1))
		if defender_uid < 0:
			defender_uid = state.players[int(a.get("defender", 1))].in_control().uid
		var src: CardInstance = card(int(a.get("source", -1)))
		var performer: CardInstance = _performer(a)
		var b: Dictionary = damage_breakdown(a)
		out.append({
			"kind": &"attack",
			"uid": src.uid if src != null else performer.uid,
			"title": src.def.title if src != null else performer.def.title,
			"owner": int(a.get("attacker", state.attacker)),
			"target": defender_uid,
			"note": CardText.short_damage(int(b.get("stages", 0)), int(b.get("life", 0))) if not b.is_empty() else "",
			"current": current == &"attack",
		})
	if not state.pending_play.is_empty():
		var pc: CardInstance = card(int(state.pending_play.get("card", -1)))
		out.append({
			"kind": &"pending_card",
			"uid": pc.uid if pc != null else -1,
			"title": pc.def.title if pc != null else "",
			"owner": pc.owner if pc != null else -1,
			"target": -1,
			"note": CardText.pending_mode_phrase(str(state.pending_play.get("mode", "use"))),
			"current": current == &"pending_card",
		})
	for i in range(_queue.size()):
		var job: Dictionary = _queue[i]
		var source: CardInstance = job.get("source")
		out.append({
			"kind": &"trigger",
			"uid": source.uid if source != null else -1,
			"title": source.def.title if source != null else "",
			"owner": int(job.get("owner", -1)),
			"target": -1,
			"note": CardText.trigger_phrase(str(job.get("trigger", "secondary"))),
			"current": current == &"trigger" and i == 0,
		})
	if wounds_live:
		out.append({
			"kind": &"wounds",
			"uid": int(a.get("source", -1)),
			"title": "",
			"owner": int(a.get("attacker", state.attacker)),
			"target": defender_uid,
			"note": "%d wound%s" % [wounds, "" if wounds == 1 else "s"],
			"current": current == &"wounds",
		})
	return out


## Legal commands in the pending prompt that name this card.
func options_for_card(uid: int) -> Array[Command]:
	var out: Array[Command] = []
	if prompt == null:
		return out
	for o in prompt.options:
		if o.card == uid:
			out.append(o)
	return out


# --- Setup ----------------------------------------------------------------

func _build_player(index: int, deck: DeckList) -> PlayerState:
	var p: PlayerState = PlayerState.new()
	p.index = index
	p.name = deck.name
	p.alignment = deck.alignment
	p.style = deck.style
	p.archetype = deck.archetype
	p.subthemes = deck.subthemes.duplicate()
	# The Duelist is a stack of personality cards, one per Aspect. It is assembled once, here, and
	# the engine then reads "the row for Aspect n" off it exactly as it used to read a ladder card.
	var stack: PersonalityStack = deck.duelist_stack(library)
	assert(not stack.is_empty(), "Deck %s has no duelist" % deck.name)
	p.duelist = _instance(stack.def_for(stack.lowest_aspect()), index, &"duelist")
	p.duelist.stack = stack
	p.duelist.aspect = stack.lowest_aspect()
	p.duelist.energy = STARTING_ENERGY
	p.highest_aspect = stack.highest_aspect()
	p.controlling = p.duelist
	if deck.mastery_id != "":
		p.mastery = _instance(library.get_def(deck.mastery_id), index, &"side")
		# "You cannot win by the Most Powerful Personality Victory", the Ascension win here.
		if bool(p.mastery.def.raw.get("no_ascension_win", false)):
			p.no_ascension_win = true
	if deck.relic_id != "":
		p.relic = _instance(library.get_def(deck.relic_id), index, &"side")
		if bool(p.relic.def.relic_flags.get("no_ascension_win", false)):
			p.no_ascension_win = true
	for id in deck.reserve:
		p.reserve.append(_instance(library.get_def(id), index, &"reserve"))
	# Shuffle the ids before instancing so a card's uid says nothing about its place in the deck
	# list. Instancing first and shuffling after would let a client map face-down uids back to
	# the deck list it ships with.
	var ids: Array[String] = deck.cards.duplicate()
	if shuffle_decks:
		rng.shuffle(ids)
	for id in ids:
		p.life_deck.append(_instance(library.get_def(id), index, &"life_deck"))
	return p


func _instance(def: CardDef, owner: int, zone: StringName) -> CardInstance:
	assert(def != null, "Cannot instance a missing card")
	var c: CardInstance = CardInstance.new(_next_uid, def, owner)
	_next_uid += 1
	c.zone = zone
	_cards[c.uid] = c
	return c


## Bracket rule from the later rulings: if only one duelist's starting Might sits in band D or
## above, the weaker duelist goes first. Otherwise the Vigil first, or a coin flip. No stage changes.
## Double Power Rule, from the printed starter rulebook: compare the two duelists' Might at the
## starting stage. If one is double the other or more, it starts at 2 Energy, the weaker starts
## at its highest stage and goes first. Wild Might never triggers it. Otherwise the Vigil goes
## first, and two duelists of the same side go first at random.
func _apply_first_player_rule() -> void:
	var a: PlayerState = state.players[0]
	var b: PlayerState = state.players[1]
	var wild: bool = a.duelist.is_wild() or b.duelist.is_wild()
	var a_might: int = a.duelist.might()
	var b_might: int = b.duelist.might()
	var stronger: int = -1
	if not wild and a_might > 0 and b_might > 0:
		if a_might >= 2 * b_might:
			stronger = 0
		elif b_might >= 2 * a_might:
			stronger = 1
	if stronger >= 0:
		var weaker: int = 1 - stronger
		state.players[stronger].duelist.energy = DOUBLE_POWER_ENERGY
		state.players[weaker].duelist.energy = CardInstance.MAX_STAGE
		state.active = weaker
		_emit(&"double_power", {"stronger": stronger, "weaker": weaker, "energy": DOUBLE_POWER_ENERGY})
	elif a.alignment != b.alignment:
		state.active = 0 if a.alignment == "vigil" else 1
	else:
		state.active = rng.randi_range(0, 1)


# --- Reserve swap (setup) --------------------------------------------------

## Both players swap at the same time: each unfinished player holds a reserve prompt, the
## active player's first. Nobody waits on the other.
func _advance_reserve() -> void:
	if state.reserve_index >= 2:
		if _prompt_start_in_play():
			return
		_begin_turn()
		return
	for index in [state.active, state.opposing()]:
		if not state.reserve_finished[index]:
			_prompt_reserve(state.players[index])


## Adds `p`'s reserve prompt beside any other, or finishes `p` when nothing is left to swap in.
func _prompt_reserve(p: PlayerState) -> void:
	var opts: Array[Command] = []
	for c in p.reserve:
		if not _reserve_swapped.has(c.uid):
			opts.append(Command.new(p.index, &"reserve_in", c.uid))
	if opts.is_empty():
		_finish_reserve(p)
		return
	var batch_max: int = opts.size()
	opts.append(Command.new(p.index, &"reserve_done"))
	var rp: Prompt = Prompt.new()
	rp.player = p.index
	rp.kind = &"reserve"
	rp.options = opts
	rp.set_batch(&"reserve_in", 1, batch_max)
	prompts.append(rp)
	_emit(&"prompt", {"player": p.index, "kind": &"reserve", "options": opts.size()})


## One card at a time re-opens the prompt with what is left; a batch swaps them all and finishes.
func _handle_reserve(cmd: Command) -> void:
	var p: PlayerState = state.players[cmd.player]
	if cmd.type == &"reserve_done":
		_finish_reserve(p)
		return
	for uid in Prompt.cards_of(cmd):
		_reserve_swap_in(p, card(uid))
	if cmd.value is Array:
		_finish_reserve(p)
	else:
		_prompt_reserve(p)


func _reserve_swap_in(p: PlayerState, c: CardInstance) -> void:
	_erase_from_zone(c)
	c.zone = &"life_deck"
	p.life_deck.append(c)
	if p.life_deck.size() > 1:
		var idx: int = rng.randi_range(0, p.life_deck.size() - 2)
		var out: CardInstance = p.life_deck[idx]
		_erase_from_zone(out)
		out.zone = &"reserve"
		p.reserve.append(out)
		_reserve_swapped[out.uid] = true
		_emit(&"reserve_swap", {"player": p.index, "in": c.uid, "out": out.uid})


func _finish_reserve(p: PlayerState) -> void:
	if shuffle_decks:
		rng.shuffle(p.life_deck)
	_emit(&"reserve_done", {"player": p.index})
	state.reserve_finished[p.index] = true
	state.reserve_index += 1
	_start_in_play(p)


## Cards that begin the game in play move out of the deck as soon as their owner's Reserve is
## settled. A card whose text reads "you may search your Life Deck for this and place it into play"
## is left for `_prompt_start_in_play` instead, because that one is a decision.
func _start_in_play(p: PlayerState) -> void:
	var seen: Dictionary = {}
	for c in _start_in_play_candidates(p):
		if str(c.def.raw.get("start_in_play", "")) == "may" or seen.has(c.def.id):
			continue
		seen[c.def.id] = true
		_place(p, c)


func _start_in_play_candidates(p: PlayerState, optional_only: bool = false) -> Array[CardInstance]:
	var pool: Array[CardInstance] = []
	pool.append_array(p.life_deck)
	pool.append_array(p.reserve)
	var out: Array[CardInstance] = []
	var seen: Dictionary = {}
	for c in pool:
		if not c.def.start_in_play or seen.has(c.def.id) or not _can_place(p, c):
			continue
		if optional_only and str(c.def.raw.get("start_in_play", "")) != "may":
			continue
		seen[c.def.id] = true
		out.append(c)
	return out


## "Before the first turn begins, you may search your Life Deck for this Drill and place it into
## play." Each player is asked in turn; true when a prompt is open.
func _prompt_start_in_play() -> bool:
	for index in [state.active, state.opposing()]:
		if state.start_play_done[index]:
			continue
		var p: PlayerState = state.players[index]
		var cands: Array[CardInstance] = _start_in_play_candidates(p, true)
		if cands.is_empty():
			state.start_play_done[index] = true
			continue
		var opts: Array[Command] = []
		for c in cands:
			opts.append(Command.new(index, &"place", c.uid))
		opts.append(Command.new(index, &"done"))
		_set_prompt(index, &"start_play", opts)
		return true
	return false


func _handle_start_play(cmd: Command) -> void:
	var p: PlayerState = state.players[cmd.player]
	if cmd.type == &"done":
		state.start_play_done[cmd.player] = true
		return
	_place(p, card(cmd.card))


# --- Main loop ------------------------------------------------------------

func _run() -> void:
	var guard: int = 0
	while prompt == null and not state.is_over():
		_sweep_full_energy_riders()
		if not _queue.is_empty():
			_drain()
		else:
			_advance()
		guard += 1
		assert(guard < MAX_ADVANCE_ITERATIONS, "DuelEngine is stuck in step %d phase %d" % [state.step, state.phase])


## "Discard this card when your opponent's Main Personality is at their highest power stage": a
## rider that watches its host, checked between every step so it goes the moment the host is full.
func _sweep_full_energy_riders() -> void:
	for p in state.players:
		for at in p.attachments():
			if bool(at.def.attachment.get("discard_at_full", false)) and at.attached_to != null \
					and at.attached_to.energy >= CardInstance.MAX_STAGE:
				at.attached_to = null
				_emit(&"in_play_discarded", {"player": at.controller, "card": at.uid, "removed": false, "to": "discard"})
				_move_to_discard(at)


func _advance() -> void:
	match state.step:
		GameState.Step.SETUP:
			_advance_reserve()
		GameState.Step.DRAW:
			_draw(state.active, DRAW_COUNT)
			if not state.is_over():
				state.step = GameState.Step.NON_COMBAT
		GameState.Step.NON_COMBAT:
			_prompt_non_combat()
		GameState.Step.POWER_UP:
			_power_up()
		GameState.Step.DECLARE:
			_declare()
		GameState.Step.COMBAT:
			_advance_combat()
		GameState.Step.DISCARD:
			_advance_discard()
		GameState.Step.RECOVER:
			_recover()
		GameState.Step.TURN_END:
			_turn_end_step()
		_:
			assert(false, "DuelEngine._advance in step %d" % state.step)


func _handle(kind: StringName, cmd: Command, context: Dictionary) -> void:
	match kind:
		&"reserve":
			_handle_reserve(cmd)
		&"non_combat":
			_handle_non_combat(cmd)
		&"combat_end":
			_handle_combat_end(cmd)
		&"start_play":
			_handle_start_play(cmd)
		&"declare":
			_handle_declare(cmd)
		&"attack_action":
			_handle_attack_action(cmd)
		&"respond":
			_handle_respond(cmd)
		&"defense":
			_handle_defense(cmd)
		&"control":
			_handle_control(cmd)
		&"redirect":
			_handle_redirect(cmd)
		&"endurance":
			_handle_endurance(cmd, context)
		&"critical":
			_handle_critical(cmd)
		&"capture_instead":
			_handle_capture_instead(cmd)
		&"trade_damage":
			_handle_trade_damage(cmd)
		&"follow_up":
			_handle_follow_up(cmd, context)
		&"keep":
			_handle_keep(cmd)
		&"recover":
			_handle_recover(cmd)
		&"pay":
			_handle_pay(cmd)
		&"discard_choice", &"pick_in_play", &"name_card", &"pick_option", &"pick_discard":
			_handle_choice(cmd)
		_:
			assert(false, "Unhandled prompt kind %s" % kind)
	if prompt == null:
		_flush_then()


func _set_prompt(player_index: int, kind: StringName, options: Array[Command], context: Dictionary = {}) -> void:
	var p: Prompt = Prompt.new()
	p.player = player_index
	p.kind = kind
	p.options = options
	p.context = context
	prompt = p
	_emit(&"prompt", {"player": player_index, "kind": kind, "options": options.size()})


# --- Turn steps -----------------------------------------------------------

func _begin_turn() -> void:
	state.turn += 1
	var p: PlayerState = state.active_player()
	p.reset_turn_flags()
	# "...until the beginning of his next turn": floats on the player whose turn this is end now.
	var lasting: Array[Dictionary] = []
	for f in state.floating:
		if str(f.get("duration", "")) == "own_turn_start" and int(f.get("owner", -1)) == p.index:
			continue
		lasting.append(f)
	state.floating = lasting
	state.skip_discard = false
	state.declare_window_done = false
	state.step = GameState.Step.DRAW
	state.phase = GameState.Phase.NONE
	_emit(&"turn_start", {"turn": state.turn, "player": p.index})
	# Bonds burn a life card each turn and come apart when the pile is full.
	for al in p.allies():
		var timer_max: int = int(al.def.raw.get("bond_timer_max", 0))
		if timer_max <= 0:
			continue
		var c: CardInstance = _flip_life_card(p)
		if c == null:
			return
		if c.def.type == CardDef.Type.SEAL:
			_bypass_seal(c)
		else:
			c.zone = &"under"
			al.cards_under.append(c)
		al.bond_timer += 1
		_emit(&"bond_tick", {"player": p.index, "card": al.uid, "count": al.bond_timer})
		if al.bond_timer >= timer_max:
			_unbond(p, al)
	if p.seal_victory_pending:
		p.seal_victory_pending = false
		if _controls_full_set(p):
			_win(p.index, "seal")
			# A Seal set that only scored a point leaves the turn to carry on.
			if state.is_over():
				return
	# Beginning-of-turn effects belong to both players, active first, the same order every other
	# shared window uses. Today only the active player's own cards say "your turn", but a card
	# that does not should still fire here rather than be silently skipped.
	for index in [p.index, 1 - p.index]:
		var side: PlayerState = state.players[index]
		var own_turn: bool = index == p.index
		var constant: Dictionary = _constant(side)
		if constant.has("turn_start"):
			_enqueue_keyed(_turn_start_lines(constant.get("turn_start", []), own_turn), "turn_start", index, {}, side.duelist)
		for c in side.in_play:
			if c.def.type == CardDef.Type.DRILL and _forbidden(side, "drills"):
				continue
			if c.def.has_trigger("turn_start"):
				_enqueue(_turn_start_lines(c.def.effects_for("turn_start"), own_turn), "turn_start", index, {}, c)


## "At the beginning of your turn" is the default and fires only for the turn's owner; a line
## marked `each_turn` reads "at the beginning of each turn" and fires on both.
func _turn_start_lines(lines: Array, own_turn: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in lines:
		# `on_turn: "opponent"` is "at the beginning of his turn", on a card riding the other side.
		if str((e as Dictionary).get("on_turn", "")) == "opponent":
			if not own_turn:
				out.append(e)
		elif own_turn or bool((e as Dictionary).get("each_turn", false)):
			out.append(e)
	return out


func _end_turn() -> void:
	var p: PlayerState = state.active_player()
	_emit(&"turn_end", {"turn": state.turn, "player": p.index})
	_expire_floating("turn")
	state.active = state.opposing()
	_begin_turn()


func _prompt_non_combat() -> void:
	var p: PlayerState = state.active_player()
	var opts: Array[Command] = []
	for c in p.hand:
		if _can_place(p, c):
			opts.append(Command.new(p.index, &"place", c.uid))
		elif _drill_locked_out(p, c.def):
			opts.append(Command.new(p.index, &"shuffle_back", c.uid))
	if _relic_usable_in(p, "non_combat"):
		opts.append(Command.new(p.index, &"relic", p.relic.uid))
	if opts.is_empty():
		state.step = GameState.Step.POWER_UP
		return
	opts.append(Command.new(p.index, &"done"))
	_set_prompt(p.index, &"non_combat", opts)


func _handle_non_combat(cmd: Command) -> void:
	var p: PlayerState = state.active_player()
	match cmd.type:
		&"done":
			state.step = GameState.Step.POWER_UP
		&"relic":
			_use_relic(p)
		&"shuffle_back":
			var c: CardInstance = card(cmd.card)
			_emit(&"drill_shuffled_back", {"player": p.index, "card": c.uid, "id": c.def.id})
			_move_to_deck_bottom(c)
			if shuffle_decks:
				rng.shuffle(p.life_deck)
		_:
			_place(p, card(cmd.card))


## A school Drill in hand that the school lock or a duplicate in play keeps off the table. Its
## owner may show it and shuffle it back into the Life Deck instead of holding it.
func _drill_locked_out(p: PlayerState, def: CardDef) -> bool:
	if def.type != CardDef.Type.DRILL or def.school == "":
		return false
	var locked: String = p.drill_school()
	if locked != "" and locked != def.school and not bool(def.raw.get("drill_lock_exempt", false)):
		return true
	for d in p.drills():
		if d.def.id == def.id:
			return true
	return false


func _relic_available(p: PlayerState) -> bool:
	if p.relic == null:
		return false
	var uses: int = int(p.relic.def.raw.get("uses_per_game", 0))
	return uses > 0 and p.relic_uses < uses and p.relic.def.has_trigger("relic_use")


## A Relic's `relic_step` says when its power is offered: "non_combat" (the default), "combat"
## (in place of an attack) or "any".
func _relic_usable_in(p: PlayerState, step: String) -> bool:
	# The Relic stands in for the reference game's Sensei card: "cannot use Sensei cards" is this.
	if not _relic_available(p) or _forbidden(p, "relic"):
		return false
	var when: String = str(p.relic.def.raw.get("relic_step", "non_combat"))
	return when == "any" or when == step


func _use_relic(p: PlayerState) -> void:
	p.relic_uses += 1
	_emit(&"relic_used", {"player": p.index, "card": p.relic.uid})
	_enqueue(p.relic.def.effects, "relic_use", p.index, {}, p.relic)


func _power_up() -> void:
	var p: PlayerState = state.active_player()
	var gain: int = recover_gain(p)
	var before: int = p.duelist.energy
	_gain_energy(p, p.duelist, gain)
	var ally_gain: int = maxi(0, 1 - power_up_less(p))
	for a in p.allies():
		_gain_energy(p, a, ally_gain)
	# What was actually gained, not what was asked for: a standing `no_gain` swallows it, and
	# the log and the table must not claim Energy that never arrived.
	gain = p.duelist.energy - before
	# `energies` is what every personality stands at afterwards, so a client can show the step
	# without knowing what an Ally gains.
	var energies: Dictionary = {p.duelist.uid: p.duelist.energy}
	for a in p.allies():
		energies[a.uid] = a.energy
	_emit(&"power_up", {"player": p.index, "gain": gain, "energy": p.duelist.energy, "energies": energies})
	state.step = GameState.Step.DECLARE


func _declare() -> void:
	var p: PlayerState = state.active_player()
	if p.placed_grounds or p.cannot_declare_combat:
		# Say which of the two it was, so the log can explain a turn that ended without a Combat
		# the player never got offered.
		_emit(&"combat_skipped", {"player": p.index, "forced": true,
			"reason": "grounds" if p.placed_grounds else "forbidden"})
		state.step = GameState.Step.DISCARD
		state.discard_index = 0
		return
	if not state.declare_window_done and _open_declare_window(p):
		return
	if p.must_declare_combat or _forbidden(p, "skip_combat"):
		p.combat_declared = true
		_emit(&"combat_declared", {"player": p.index, "forced": true})
		state.step = GameState.Step.COMBAT
		state.phase = GameState.Phase.PREPARE_ACTIVE
		return
	var opts: Array[Command] = [Command.new(p.index, &"declare"), Command.new(p.index, &"skip")]
	_set_prompt(p.index, &"declare", opts)


func _handle_declare(cmd: Command) -> void:
	var p: PlayerState = state.active_player()
	if cmd.type == &"declare":
		p.combat_declared = true
		_emit(&"combat_declared", {"player": p.index})
		state.step = GameState.Step.COMBAT
		state.phase = GameState.Phase.PREPARE_ACTIVE
	else:
		_emit(&"combat_skipped", {"player": p.index, "forced": false})
		state.step = GameState.Step.DISCARD
		state.discard_index = 0


## Both players choose what to keep at the same time, the active player's prompt first. Each
## hand is its own, so neither choice can depend on the other's.
func _advance_discard() -> void:
	if state.skip_discard:
		state.discard_index = 2
	if state.discard_index >= 2:
		state.step = GameState.Step.RECOVER
		return
	if state.discard_index == 0 and prompts.is_empty():
		state.discard_done = [false, false]
	# "At the beginning of each Discard Step, your Duelist may pay 1 Energy to make your opponent
	# discard his whole hand." Fires once a turn, before either player keeps anything. Whatever it
	# raises is drained by the caller, so this returns and the step is re-entered after.
	if _discard_step_fired != state.turn:
		_discard_step_fired = state.turn
		for index in [state.active, state.opposing()]:
			var side: PlayerState = state.players[index]
			for c in side.in_play:
				if c.def.type == CardDef.Type.DRILL and _forbidden(side, "drills"):
					continue
				if c.def.has_trigger("discard_step"):
					_enqueue(c.def.effects_for("discard_step"), "discard_step", index, {}, c)
		if not _queue.is_empty():
			return
	for index in [state.active, state.opposing()]:
		if state.discard_done[index]:
			continue
		var p: PlayerState = state.players[index]
		var keep: int = _hand_keep(p)
		if _has_floating(p.index, "keep_hand"):
			keep = 99
		if p.hand.size() <= keep:
			_finish_discard(p.index)
			continue
		var opts: Array[Command] = []
		for c in p.hand:
			opts.append(Command.new(p.index, &"keep", c.uid))
		opts.append(Command.new(p.index, &"discard_all"))
		var kp: Prompt = Prompt.new()
		kp.player = p.index
		kp.kind = &"keep"
		kp.options = opts
		prompts.append(kp)
		_emit(&"prompt", {"player": p.index, "kind": &"keep", "options": opts.size()})


func _finish_discard(index: int) -> void:
	state.discard_done[index] = true
	state.discard_index += 1


func _handle_keep(cmd: Command) -> void:
	var p: PlayerState = state.players[cmd.player]
	var keep: CardInstance = card(cmd.card) if cmd.type == &"keep" else null
	var to_discard: Array[CardInstance] = []
	for c in p.hand:
		if c != keep:
			to_discard.append(c)
	for c in to_discard:
		_move_to_discard(c)
	_emit(&"discard_step", {"player": p.index, "discarded": to_discard.size(), "kept": p.hand.size()})
	_finish_discard(p.index)


func _recover() -> void:
	var p: PlayerState = state.active_player()
	# The step always occurs; the card only returns when Combat was skipped.
	var eligible: bool = not p.combat_declared and not p.discard.is_empty()
	_emit(&"recover_step", {"player": p.index, "eligible": eligible})
	if not eligible:
		state.step = GameState.Step.TURN_END
		return
	var opts: Array[Command] = [Command.new(p.index, &"recover"), Command.new(p.index, &"no_recover")]
	_set_prompt(p.index, &"recover", opts)


func _handle_recover(cmd: Command) -> void:
	var p: PlayerState = state.active_player()
	state.step = GameState.Step.TURN_END
	if cmd.type == &"recover":
		var back: CardInstance = p.discard.back() if not p.discard.is_empty() else null
		_recover_top(p, 1)
		# "During the Rejuvenation Step, if you put any Saiyan Style cards back into your Life Deck,
		# raise your anger 2 levels and your Main Personality gains 4 power stages."
		if back != null and p.mastery != null and not _forbidden(p, "mastery"):
			var bonus: Dictionary = p.mastery.def.raw.get("recover_bonus", {})
			if not bonus.is_empty() and back.def.school == str(bonus.get("school", "")):
				_enqueue(bonus.get("effects", []), "secondary", p.index, {}, p.mastery)


## Cards that were flipped as damage this turn and say "at the end of the turn" get their say here,
## the active player's first, before the turn changes hands. Queued rather than run inline, so an
## effect that needs a prompt still resolves inside the turn it belongs to.
func _turn_end_step() -> void:
	for seat in [state.active, 1 - state.active]:
		var q: PlayerState = state.players[seat]
		if q.pending_turn_end.is_empty():
			continue
		for item in q.pending_turn_end:
			var list: Array[Dictionary] = [item["effect"]]
			_queue.append({"effects": list, "index": 0, "trigger": "on_wound", "owner": seat, "ctx": {}, "source": card(int(item.get("source", -1)))})
		q.pending_turn_end.clear()
		return
	_end_turn()


# --- Placement ------------------------------------------------------------

func _can_place(p: PlayerState, c: CardInstance) -> bool:
	var def: CardDef = c.def
	if def.alignment_only != "" and def.alignment_only != p.alignment:
		return false
	if (def.type == CardDef.Type.NON_COMBAT or def.type == CardDef.Type.DRILL) and _non_combat_cap_reached(p):
		return false
	match def.type:
		CardDef.Type.PERSONALITY:
			if not (def.raw.get("bond_of", []) as Array).is_empty():
				return false   # Bonds enter play through a Bonding card, never by placement
			if _forbidden(p, "allies"):
				return false
			# Every Ally rule is per player, and none of them reads the other side of the table.
			# "Not your own Duelist's character" is a deck rule and lives in DeckValidator alone:
			# a personality only reaches your side out of your own Life Deck or Reserve, and both
			# are validated. The rival's Duelist and the rival's Allies are never consulted.
			var aspect: int = def.aspect
			var own: CardInstance = _ally_of_character(p, def.character)
			if own == null:
				# Placed fresh: any Aspect up to the Duelist's current one, with no need for the
				# Aspects below it to have been played.
				if aspect > p.duelist.aspect:
					return false
			elif aspect != own.aspect + 1:
				# Climbing: exactly the next Aspect goes on top. An Ally that climbs may pass the
				# Duelist's current Aspect; only a fresh placement is capped.
				return false
			# Uniqueness is per player (2014 relaunch rule, adopted 2026-09-21): what the rival
			# has on their side of the table never blocks a placement, so both players may field
			# the same character, the same Aspect, even the same card, at the same time.
			return true
		CardDef.Type.SEAL:
			if _forbidden(p, "seals"):
				return false
			return _seal_in_play(def.id) == null
		CardDef.Type.GROUNDS:
			return state.grounds == null or state.grounds.def.id != def.id
		CardDef.Type.NON_COMBAT:
			return true
		CardDef.Type.DRILL:
			if def.school == "":
				return true
			var locked: String = p.drill_school()
			if locked != "" and locked != def.school and not bool(def.raw.get("drill_lock_exempt", false)):
				return false
			for d in p.drills():
				if d.def.id == def.id:
					return false
			return true
		_:
			return false


## "Your opponents may only place 1 Non-Combat card in play during their turn": a Drill of the
## other side's says so, and this player has already placed one this turn. Drills are Non-Combat
## cards; Seals and Grounds are not.
func _non_combat_cap_reached(p: PlayerState) -> bool:
	if state.active != p.index or p.non_combats_placed < 1:
		return false
	var opp: PlayerState = state.players[1 - p.index]
	if _forbidden(opp, "drills"):
		return false
	for d in _active(opp.drills()):
		if bool(d.def.raw.get("opponent_one_non_combat", false)):
			return true
	return false


func _place(p: PlayerState, c: CardInstance) -> void:
	if (c.def.type == CardDef.Type.NON_COMBAT or c.def.type == CardDef.Type.DRILL) and state.active == p.index:
		p.non_combats_placed += 1
	_erase_from_zone(c)
	c.controller = p.index
	match c.def.type:
		CardDef.Type.PERSONALITY:
			var existing: CardInstance = _ally_of_character(p, c.def.character)
			if existing != null:
				# Climbing: the new Aspect overlays the old one, which goes under it, and the
				# Ally's stack grows by that card. Entering the Aspect sets it to full Energy.
				# The pile is kept flat, lowest Aspect first, so whatever takes the Ally out of
				# play takes every Aspect under it with one pass.
				_erase_from_zone(existing)
				existing.zone = &"under"
				c.cards_under.append_array(existing.cards_under)
				existing.cards_under = [] as Array[CardInstance]
				c.cards_under.append(existing)
				c.energy = CardInstance.MAX_STAGE
				c.stack = existing.stack.plus(c.def) if existing.stack != null else PersonalityStack.single(c.def)
			else:
				c.energy = ALLY_STARTING_ENERGY
				c.stack = PersonalityStack.single(c.def)
			c.aspect = c.def.aspect
			c.zone = &"in_play"
			p.in_play.append(c)
		CardDef.Type.GROUNDS:
			if state.grounds != null:
				_remove_from_game(state.grounds)
			c.zone = &"grounds"
			state.grounds = c
			p.placed_grounds = true
		_:
			c.zone = &"in_play"
			p.in_play.append(c)
	_emit(&"card_placed", {"player": p.index, "card": c.uid, "id": c.def.id})
	_check_lonely_drills(p)
	if c.def.type == CardDef.Type.SEAL:
		# A Seal's power resolves as it enters play and must be used.
		_enqueue_keyed(_seal_power(c), "on_place", p.index, {}, c)
	elif c.def.has_trigger("on_place"):
		_enqueue(c.def.effects, "on_place", p.index, {}, c)
	if c.def.type == CardDef.Type.SEAL and _controls_full_set(p):
		_win(p.index, "seal")


## A Seal's text is its placement power: every line with no trigger of its own, or `on_place`.
func _seal_power(t: CardInstance) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in t.def.effects:
		var trigger: String = str(e.get("trigger", "on_place"))
		if trigger == "on_place" or trigger == "secondary":
			out.append(e)
	return out


# --- Combat ---------------------------------------------------------------

func _advance_combat() -> void:
	match state.phase:
		GameState.Phase.PREPARE_ACTIVE:
			if _prompt_entering_combat(state.active):
				return
			_resolve_entering(state.active)
			state.phase = GameState.Phase.PREPARE_OPPOSING
		GameState.Phase.PREPARE_OPPOSING:
			if _prompt_entering_combat(state.opposing()):
				return
			_resolve_entering(state.opposing())
			state.phase = GameState.Phase.OPPOSING_DRAW
		GameState.Phase.OPPOSING_DRAW:
			_draw(state.opposing(), DRAW_COUNT)
			if state.is_over():
				return
			state.combat_count += 1
			for p in state.players:
				p.reset_combat_flags()
			state.attacker = state.active
			state.consecutive_passes = 0
			_combat_ending = false
			_emit(&"combat_begin", {"combat": state.combat_count})
			state.phase = GameState.Phase.ATTACK
		GameState.Phase.ATTACK:
			var p: PlayerState = state.players[state.attacker]
			_phase_start_drain(p)
			if p.skip_next_attack_phase:
				p.skip_next_attack_phase = false
				# A skipped phase never happened, so the passes around it are not consecutive.
				state.consecutive_passes = 0
				_emit(&"attack_phase_skipped", {"player": p.index})
				state.phase = GameState.Phase.FIGHT_BACK
			elif p.pass_next_phase:
				p.pass_next_phase = false
				_pass(p, true)
			elif p.must_pass:
				_pass(p, true)
			elif not state.control_asked and _prompt_attacker_control(p):
				return
			else:
				_prompt_attack_action(p)
		GameState.Phase.DEFEND:
			_prompt_defense()
		GameState.Phase.BATTLE:
			_advance_battle()
		GameState.Phase.COMBAT_END:
			_prompt_combat_end()
		GameState.Phase.FIGHT_BACK:
			# A restriction aimed at one attack phase ends when that phase is over. Combat runs
			# many phases back and forth, so this is far shorter than "the rest of Combat".
			# The hand-over itself gets a beat, so a client can draw Combat as a series of
			# exchanges rather than one endless Attack. It carries no log line of its own.
			_emit(&"fight_back", {"player": state.attacker, "next": 1 - state.attacker})
			_expire_attack_phase_floats(state.attacker)
			for q in state.players:
				for item in q.pending_fight_back:
					var list: Array[Dictionary] = [item["effect"]]
					_queue.append({"effects": list, "index": 0, "trigger": "on_wound", "owner": q.index, "ctx": {}, "source": card(int(item.get("source", -1)))})
				q.pending_fight_back.clear()
			for q in state.players:
				q.stopped_last_phase = q.stopped_this_phase
				q.stopped_this_phase = false
			state.attacker = 1 - state.attacker
			state.control_asked = false
			state.attack_phase_count += 1
			state.phase = GameState.Phase.ATTACK
		_:
			assert(false, "Bad combat phase %d" % state.phase)


## "Their duelist loses 1 Energy at the beginning of each of their attack phases." The float sits
## on the player it drains and fires only on their own phases, once each, which the phase counter
## stamped into it guarantees even when the phase is re-entered for a control question.
func _phase_start_drain(p: PlayerState) -> void:
	var f: Dictionary = _floating_first(p.index, "phase_drain")
	if f.is_empty() or int(f.get("last", -1)) == state.attack_phase_count:
		return
	f["last"] = state.attack_phase_count
	var n: int = maxi(1, int(f.get("energy", 1)))
	var before: int = p.duelist.energy
	_lose_energy(p, p.duelist, n)
	if p.duelist.energy != before:
		_emit(&"energy_changed", {"player": p.index, "card": p.duelist.uid, "from": before,
				"to": p.duelist.energy, "source": int(f.get("source", -1))})


## "Use when entering Combat": a card played from hand as Combat is entered, before the triggers
## already on the table fire, so the player settles what they are adding before the rest resolves.
## The design doc gives the active player their whole preparation first and the opposing player
## theirs after, which is the order the two Prepare phases already run in; the opposing player is
## still on their old hand here, because their draw comes after both preparations. The window
## reopens after each card, so a player holding two may use both, and a decline closes it.
func _prompt_entering_combat(player_index: int) -> bool:
	var p: PlayerState = state.players[player_index]
	if p.entering_combat_done:
		return false
	var opts: Array[Command] = []
	for c in p.hand:
		if str(c.def.raw.get("use_at", "")) != "entering_combat":
			continue
		if not _can_play(p, c.def) or not _use_allowed(p, c.def) or _band_forbidden(p, c.def):
			continue
		opts.append(Command.new(player_index, &"use", c.uid))
	if opts.is_empty():
		p.entering_combat_done = true
		_emit(&"window_skipped", {"player": player_index, "window": "entering_combat"})
		return false
	opts.append(Command.new(player_index, &"decline"))
	_set_prompt(player_index, &"follow_up", opts,
		{"window": "entering_combat", "role": "active" if player_index == state.active else "opposing"})
	return true


## Whatever shuts a printed band off shuts off a card of that band, wherever it is used from.
func _band_forbidden(p: PlayerState, def: CardDef) -> bool:
	match def.type:
		CardDef.Type.STRIKE:
			return _forbidden(p, "strike_cards")
		CardDef.Type.ART:
			return _forbidden(p, "art_cards")
		CardDef.Type.COMBAT:
			return _forbidden(p, "combat_cards")
		CardDef.Type.NON_COMBAT:
			return _forbidden(p, "non_combats")
		CardDef.Type.DRILL:
			return _forbidden(p, "drills")
	return false


## Whether an attack that dealt `stages` Energy damage and `wounds` life cards opens this card's
## after-damage window. The printed wording is "after taking damage from an attack" without saying
## which kind, so `use_after_damage` is a data key and "either" is the default.
func _damage_window_matches(def: CardDef, stages: int, wounds: int) -> bool:
	match str(def.raw.get("use_after_damage", "either")):
		"stages":
			return stages > 0
		"life":
			return wounds > 0
		_:
			return stages > 0 or wounds > 0


## "Use immediately after you take damage from an attack." The window belongs to the player who was
## just hit. It opens once per attack, only when the attack actually landed something, and it is
## always declinable. A card used here comes straight out of hand: a Non-Combat answering this
## timing is never placed first, it resolves and goes to the discard pile like any card used from
## hand. One already on the table answers here too, through its `use` trigger.
func _prompt_after_damage(defender: PlayerState, a: Dictionary) -> bool:
	if bool(a.get("after_damage_done", false)):
		return false
	a["after_damage_done"] = true
	var stages: int = int(a.get("stages_dealt", 0))
	var wounds: int = int(a.get("life_dealt", 0))
	if stages <= 0 and wounds <= 0:
		return false
	var opts: Array[Command] = []
	for c in defender.hand:
		if str(c.def.raw.get("use_at", "")) != "after_damage" or not _has_trigger(c.def.effects, "secondary"):
			continue
		if not _damage_window_matches(c.def, stages, wounds):
			continue
		if not _can_play(defender, c.def) or not _use_allowed(defender, c.def) or _band_forbidden(defender, c.def):
			continue
		opts.append(Command.new(defender.index, &"use", c.uid))
	if not _forbidden(defender, "non_combats"):
		for c in _active(defender.non_combats()):
			if str(c.def.raw.get("use_at", "")) == "after_damage" and not c.def.effects_for("use").is_empty() \
					and _damage_window_matches(c.def, stages, wounds) and _can_play(defender, c.def):
				opts.append(Command.new(defender.index, &"use", c.uid))
	if not _forbidden(defender, "drills"):
		for c in _active(defender.drills()):
			if str(c.def.raw.get("use_at", "")) == "after_damage" and not c.def.effects_for("use").is_empty() \
					and _damage_window_matches(c.def, stages, wounds) and _drill_use_available(c):
				opts.append(Command.new(defender.index, &"use", c.uid))
	if opts.is_empty():
		_emit(&"window_skipped", {"player": defender.index, "window": "after_damage"})
		return false
	opts.append(Command.new(defender.index, &"decline"))
	_set_prompt(defender.index, &"follow_up", opts,
		{"window": "after_damage", "source": int(a.get("source", -1)), "stages": stages, "life": wounds})
	return true


## Card data names the side of the entering-Combat window as the printed cards do, "attacker" or
## "defender"; the window itself is keyed "active" / "opposing" (older data still says so).
static func role_matches(wanted: String, role: String) -> bool:
	if wanted == "":
		return true
	if wanted == "attacker":
		return role == "active"
	if wanted == "defender":
		return role == "opposing"
	return wanted == role


func _resolve_entering(player_index: int) -> void:
	var p: PlayerState = state.players[player_index]
	var role: String = "active" if player_index == state.active else "opposing"
	var ctx: Dictionary = {"role": role}
	for c in _in_play_sources(p, true):
		var effects: Array[Dictionary] = []
		for e in c.def.effects_for("entering_combat"):
			if role_matches(str(e.get("role", "")), role):
				effects.append(e)
		if c.attached_to != null:
			for e in c.def.attachment.get("effects", []):
				if str(e.get("trigger", "")) == "entering_combat":
					effects.append(e)
		if not effects.is_empty():
			if c.def.type == CardDef.Type.NON_COMBAT and c.attached_to == null:
				# A Non-Combat used on entry is spent.
				_enqueue(effects, "entering_combat", player_index, ctx, c)
				_enqueue([{"trigger": "entering_combat", "op": "spend_source"}], "entering_combat", player_index, ctx, c)
			else:
				_enqueue(effects, "entering_combat", player_index, ctx, c)
	# Duelist power or constant with an entering-Combat trigger.
	var ic: CardInstance = p.duelist
	var pw: Dictionary = ic.power()
	var pw_effects: Array[Dictionary] = []
	for e in pw.get("effects", []):
		if str(e.get("trigger", "")) == "entering_combat" and role_matches(str(e.get("role", "")), role):
			pw_effects.append(e)
	if not pw_effects.is_empty():
		_enqueue(pw_effects, "entering_combat", player_index, ctx, ic)
	var constant: Dictionary = _constant(p)
	if constant.has("entering_combat"):
		var ce: Array[Dictionary] = []
		for e in constant.get("entering_combat", []):
			if role_matches(str(e.get("role", "")), role):
				ce.append(e)
		_enqueue_keyed(ce, "entering_combat", player_index, ctx, ic)
	_emit(&"entering_combat", {"player": player_index, "role": role})


func _pass(p: PlayerState, forced: bool) -> void:
	state.consecutive_passes += 1
	_emit(&"pass", {"player": p.index, "forced": forced, "consecutive": state.consecutive_passes})
	if state.consecutive_passes >= 2:
		_begin_combat_end()
	else:
		state.phase = GameState.Phase.FIGHT_BACK


## Combat is over, but "at the end of Combat" effects and the cards that name that timing still get
## their window. The player whose turn it is takes theirs first, in any order, then the opponent.
func _begin_combat_end() -> void:
	state.end_combat_done = [false, false]
	state.attack = {}
	state.phase = GameState.Phase.COMBAT_END
	for seat in [state.active, 1 - state.active]:
		var p: PlayerState = state.players[seat]
		for c in _in_play_sources(p):
			var timed: Array[Dictionary] = c.def.effects_for("end_of_combat")
			if not timed.is_empty():
				_enqueue(timed, "end_of_combat", seat, {}, c)


## Whose end-of-Combat window is open, or -1 when both are finished.
func _end_combat_turn() -> int:
	if not state.end_combat_done[state.active]:
		return state.active
	if not state.end_combat_done[1 - state.active]:
		return 1 - state.active
	return -1


func _prompt_combat_end() -> void:
	var seat: int = _end_combat_turn()
	if seat < 0:
		_end_combat()
		return
	var p: PlayerState = state.players[seat]
	var opts: Array[Command] = []
	for c in p.hand:
		if str(c.def.raw.get("use_at", "")) == "end_of_combat" and _use_allowed(p, c.def) and _can_play(p, c.def):
			opts.append(Command.new(seat, &"use", c.uid))
	if opts.is_empty():
		state.end_combat_done[seat] = true
		_emit(&"window_skipped", {"player": seat, "window": "combat_end"})
		return
	opts.append(Command.new(seat, &"done"))
	_set_prompt(seat, &"combat_end", opts)


func _handle_combat_end(cmd: Command) -> void:
	var p: PlayerState = state.players[cmd.player]
	if cmd.type == &"done":
		state.end_combat_done[cmd.player] = true
		return
	_use_card(p, card(cmd.card), false)


## Everything of a player's that can carry a timed trigger: Drills, Non-Combats, attachments,
## their Mastery and the Grounds.
func _in_play_sources(p: PlayerState, any_mastery: bool = false) -> Array[CardInstance]:
	var sources: Array[CardInstance] = []
	if not _forbidden(p, "drills"):
		sources.append_array(_active(p.drills()))
	sources.append_array(_active(p.non_combats()))
	sources.append_array(p.attachments())
	if p.mastery != null and (any_mastery or not _forbidden(p, "mastery")):
		sources.append(p.mastery)
	if state.grounds != null:
		sources.append(state.grounds)
	return sources


func _end_combat() -> void:
	_emit(&"combat_end", {"combat": state.combat_count})
	_expire_floating("combat")
	for p in state.players:
		# "...for the remainder of Combat": a rider with a Combat's life on it comes off with the
		# Combat, the way a floating effect does, rather than riding its host into the next one.
		for at in p.attachments():
			if str(at.def.attachment.get("duration", "")) == "combat":
				at.attached_to = null
				_emit(&"in_play_discarded", {"player": at.controller, "card": at.uid, "removed": false, "to": "discard"})
				_move_to_discard(at)
		p.reset_combat_flags()
		# Kept apart from the Combat flags, which are also cleared after both players have
		# prepared: a card used as Combat is entered is still a card used during that Combat.
		p.used_card_combat = false
		for c in p.remain_cards():
			c.remain = 0
			if str(c.def.raw.get("unused_return", "")) == "shuffle":
				_move_to_deck_bottom(c)
				if shuffle_decks:
					rng.shuffle(p.life_deck)
			else:
				_finish_card(c, false)
	state.attack = {}
	state.last_attack = {}
	state.battle_step = 0
	state.pending_play = {}
	state.control_asked = false
	_combat_ending = false
	_pending_attack = -1
	state.phase = GameState.Phase.NONE
	state.step = GameState.Step.DISCARD
	state.discard_index = 0


# --- Attacker Attacks -----------------------------------------------------

## Whether `p` may put an Ally in control right now: the Duelist is spent (Energy 0 or 1) or a
## constant power allows it at any stage, an Ally is in play, and nothing forbids the takeover.
func may_ally_control(p: PlayerState) -> bool:
	if p.allies().is_empty() or _has_floating(p.index, "no_ally_control"):
		return false
	return p.duelist.energy <= ALLY_CONTROL_MAX_ENERGY or bool(_constant(p).get("ally_control_any_stage", false))


## Who can absorb one attack's damage, the one in control first. The whole attack lands on a single
## personality, and any of them may take it: an Ally can cover the Duelist, and an Ally holding
## Combat can push the hit back onto the Duelist.
func _damage_targets(p: PlayerState) -> Array[CardInstance]:
	var out: Array[CardInstance] = [p.in_control()]
	if p.duelist != p.in_control():
		out.append(p.duelist)
	for al in p.allies():
		if al != p.in_control():
			out.append(al)
	return out


## Options for the personality in control: the Duelist first, then each Ally.
func _control_options(p: PlayerState) -> Array[Command]:
	var opts: Array[Command] = [Command.new(p.index, &"control", p.duelist.uid)]
	for al in p.allies():
		opts.append(Command.new(p.index, &"control", al.uid))
	return opts


## At the start of an attack phase the attacker may hand Combat to an Ally when the Duelist is
## spent; when the Duelist is back above that, it resumes control. True when a prompt opened.
func _prompt_attacker_control(p: PlayerState) -> bool:
	state.control_asked = true
	if not may_ally_control(p):
		p.controlling = p.duelist
		return false
	_set_prompt(p.index, &"control", _control_options(p), {"role": "attacker"})
	return true

func _prompt_attack_action(p: PlayerState) -> void:
	var opts: Array[Command] = []
	var ic: CardInstance = p.in_control()
	for c in p.hand:
		if c.def.is_hand_combat_card() and _can_play(p, c.def):
			if c.def.is_attack() and _attack_allowed(p, c.def):
				if _can_pay(ic, p, c.def.attack, c):
					opts.append(Command.new(p.index, &"attack", c.uid))
					if c.def.empower > 0:
						opts.append(Command.new(p.index, &"attack", c.uid, "empower"))
			elif not c.def.is_attack() and str(c.def.raw.get("use_at", "")) == "" and _has_trigger(c.def.effects, "secondary") and (not c.def.is_defense() or bool(c.def.raw.get("use_in_attack", false)) or c.def.is_end_combat_card()) and _use_allowed(p, c.def) and not _forbidden(p, "non_attack_actions"):
				# Only a card with something to do when played: a pure counter ("use when needed")
				# waits for the response window instead of being an attack-phase action.
				opts.append(Command.new(p.index, &"use", c.uid))
		if not p.final_strike_used:
			opts.append(Command.new(p.index, &"final_strike", c.uid))
	for c in p.remain_cards():
		# `remain_by` names who the extra uses belong to, for a card that stays out "to be used one
		# more time by an Ally".
		if str(c.def.raw.get("remain_by", "")) == "ally" and ic == p.duelist:
			continue
		if c.def.is_attack() and _attack_allowed(p, c.def) and _can_pay(ic, p, c.def.attack, c):
			opts.append(Command.new(p.index, &"attack", c.uid))
	var only_attacks: bool = _forbidden(p, "non_attack_actions")
	if not _forbidden(p, "non_combats") and not only_attacks:
		for c in _active(p.non_combats()):
			if not c.def.effects_for("use").is_empty() and _can_play(p, c.def):
				opts.append(Command.new(p.index, &"use", c.uid))
	if not _forbidden(p, "drills") and not only_attacks:
		for c in _active(p.drills()):
			if not c.def.effects_for("use").is_empty() and _drill_use_available(c):
				opts.append(Command.new(p.index, &"use", c.uid))
	if p.mastery != null and not only_attacks and not _forbidden(p, "mastery") and not p.mastery.def.effects_for("use").is_empty() and _drill_use_available(p.mastery) and _can_play(p, p.mastery.def):
		opts.append(Command.new(p.index, &"use", p.mastery.uid))
	if not only_attacks and _relic_usable_in(p, "combat"):
		opts.append(Command.new(p.index, &"use", p.relic.uid))
	if _power_available(p, ic) and not _forbidden(p, "powers"):
		# An Aspect may print two Powers, and the duelist picks one of them; both arrive as their
		# own option so a client and the AI never have to know the shape.
		for choice in [["", ic.power()], ["alt", ic.power_alt()]]:
			var pw: Dictionary = choice[1]
			if pw.is_empty() or pw.has("defense"):
				continue
			if pw.has("attack"):
				if _attack_allowed(p, null, str(pw["attack"].get("kind", "strike"))) and _can_pay(ic, p, pw.get("attack", {})):
					opts.append(Command.new(p.index, &"power", ic.uid, choice[0] if choice[0] != "" else null))
			elif pw.has("effects") and not only_attacks and _has_trigger(pw["effects"], "secondary"):
				opts.append(Command.new(p.index, &"power", ic.uid, choice[0] if choice[0] != "" else null))
	if not _forbidden(p, "powers"):
		for al in p.allies():
			var apw: Dictionary = al.power()
			if al == ic or not bool(apw.get("no_control_needed", false)) or not apw.has("attack"):
				continue
			if _power_available(p, al) and _attack_allowed(p, null, str(apw["attack"].get("kind", "strike"))) and _can_pay(al, p, apw["attack"]):
				opts.append(Command.new(p.index, &"power", al.uid))
	var copied: Dictionary = _floating_first(p.index, "copied_attack")
	if not copied.is_empty():
		opts.append(Command.new(p.index, &"copied_attack"))
	# "For the remainder of Combat, during your attack phase you may remove any 2 cards in your
	# Reserve from the game to remove one of your opponent's Drills in play." Stays on offer as
	# long as the Reserve can pay and there is something left to take.
	if not _ransom_options(p).is_empty():
		opts.append(Command.new(p.index, &"ransom"))
	opts.append(Command.new(p.index, &"pass"))
	_set_prompt(p.index, &"attack_action", opts, {"fight_back": p.index != state.active})


func _handle_attack_action(cmd: Command) -> void:
	var p: PlayerState = state.players[cmd.player]
	match cmd.type:
		&"pass":
			_pass(p, false)
		&"ransom":
			_handle_ransom(cmd)
			if prompt == null:
				_prompt_attack_action(p)
		&"attack":
			var c: CardInstance = card(cmd.card)
			var empowered: bool = cmd.value != null and str(cmd.value) == "empower"
			if c.zone == &"hand":
				_erase_from_zone(c)
				c.zone = &"resolving"
			elif c.remain > 0:
				c.remain -= 1
				if c.remain == 0:
					_erase_from_zone(c)
					c.zone = &"resolving"
			_begin_attack(c, c.def.attack, c.def.effects, false, false, empowered)
		&"use":
			var c: CardInstance = card(cmd.card)
			state.consecutive_passes = 0
			if _open_counter_window(c, "use"):
				return
			# "You may discard a card during your Attacker Attacks phase to ...": done in the phase,
			# not in place of the attack, so the phase stays open afterwards.
			_use_card(p, c, not bool(c.def.raw.get("free_action", false)))
		&"power":
			var ic: CardInstance = card(cmd.card)
			_charge_extra_use(p, ic)
			_mark_power_used(ic)
			var pw: Dictionary = ic.power_alt() if cmd.value != null and str(cmd.value) == "alt" else ic.power()
			_emit(&"power_used", {"player": p.index, "card": ic.uid, "aspect": ic.aspect})
			var effects: Array[Dictionary] = []
			effects.assign(pw.get("effects", []))
			if pw.has("attack"):
				_begin_attack(ic, pw.get("attack", {}), effects, true, false, false, ic)
			else:
				state.consecutive_passes = 0
				_enqueue(effects, "secondary", p.index, {}, ic)
				_enqueue([{"trigger": "secondary", "op": "after_action"}], "secondary", p.index, {}, ic)
		&"copied_attack":
			var f: Dictionary = _floating_first(p.index, "copied_attack")
			state.floating.erase(f)
			var effects: Array[Dictionary] = []
			effects.assign(f.get("effects", []))
			_begin_attack(null, f.get("spec", {}), effects, false, false, false)
		&"final_strike":
			var c: CardInstance = card(cmd.card)
			_move_to_discard(c)
			p.final_strike_used = true
			_emit(&"final_strike", {"player": p.index, "discarded": c.uid})
			_begin_attack(null, {"kind": "strike"}, [], false, true, false)
		_:
			assert(false, "Bad attack action %s" % cmd.type)


## Uses a non-attack card (Combat card from hand, Non-Combat in play, activated Drill, Mastery,
## Relic). `advance` is false in the end-of-Combat window, where using a card does not take the
## place of an attack and so does not hand the phase over.
func _use_card(p: PlayerState, c: CardInstance, advance: bool = true) -> void:
	# A hand card whose zone says elsewhere would fall through to the in-play branch below, which
	# does nothing for a Combat card and never spends it: the free-reuse loop. Say so loudly.
	if p.hand.has(c) and c.zone != &"hand":
		push_error("DuelEngine._use_card: %s #%d is in the hand but its zone says %s" % [c.def.id, c.uid, c.zone])
	if state.step == GameState.Step.COMBAT:
		p.used_card_combat = true
	if c.def.type == CardDef.Type.RELIC:
		_use_relic(p)
	elif c.zone == &"hand":
		_erase_from_zone(c)
		c.zone = &"resolving"
		_emit(&"card_used", {"player": p.index, "card": c.uid, "id": c.def.id})
		if c.def.type == CardDef.Type.COMBAT:
			p.combat_cards_used_combat = state.combat_count
		var pays: int = int(c.def.only.get("duelist_pays", 0))
		if pays > 0:
			p.duelist.energy = maxi(0, p.duelist.energy - pays)
			_emit(&"cost_paid", {"player": p.index, "stages": pays, "life": 0, "energy": p.duelist.energy})
		_enqueue(c.def.effects, "secondary", p.index, {}, c)
		_enqueue([{"trigger": "secondary", "op": "finish_source"}], "secondary", p.index, {}, c)
	else:
		_emit(&"card_used", {"player": p.index, "card": c.uid, "id": c.def.id})
		if c.def.type == CardDef.Type.DRILL or c.def.type == CardDef.Type.MASTERY:
			c.power_used_combat = state.combat_count
		_enqueue(c.def.effects, "use", p.index, {}, c)
		if c.def.type == CardDef.Type.NON_COMBAT and c.attached_to == null:
			# Used from play, so it is in_play, not resolving: spend_source is the op that discards it.
			_enqueue([{"trigger": "use", "op": "spend_source"}], "use", p.index, {}, c)
	if advance:
		_enqueue([{"trigger": "secondary", "op": "after_action"}], "secondary", p.index, {}, c)


func _has_trigger(effects: Array, trigger: String) -> bool:
	for e in effects:
		if e is Dictionary and str(e.get("trigger", "secondary")) == trigger:
			return true
	return false


func _drill_use_available(c: CardInstance) -> bool:
	if bool(c.def.raw.get("once_per_combat", false)):
		return c.power_used_combat != state.combat_count
	return true


func _after_non_attack_action() -> void:
	if state.is_over():
		return
	if _combat_ending:
		_begin_combat_end()
	elif _pending_attack >= 0:
		# The card that fetched it said to play it this phase, so the phase stays open for it.
		var fetched: CardInstance = card(_pending_attack)
		_pending_attack = -1
		var p: PlayerState = state.players[state.attacker]
		if fetched != null and fetched.zone == &"hand" and _attack_allowed(p, fetched.def) and _can_pay(p.in_control(), p, fetched.def.attack, fetched):
			_erase_from_zone(fetched)
			fetched.zone = &"resolving"
			_begin_attack(fetched, fetched.def.attack, fetched.def.effects, false, false, false)
		else:
			state.phase = GameState.Phase.FIGHT_BACK
	else:
		state.phase = GameState.Phase.FIGHT_BACK


func _begin_attack(source: CardInstance, spec: Dictionary, effects: Array[Dictionary], is_power: bool, is_final: bool, empowered: bool, performer: CardInstance = null) -> void:
	var att: int = state.attacker
	var attacker: PlayerState = state.players[att]
	attacker.attack_count_combat += 1
	if source != null:
		source.attacked_combat = state.combat_count
		attacker.used_card_combat = true
	state.attack = _build_attack(att, source, spec, effects, is_power, is_final, empowered, performer, attacker.attack_count_combat == 1)
	# "Prevent 4 power stages of damage from the first attack performed against you": the first
	# attack after the rule goes up takes it, stopped or not, and it is gone after that.
	var shield_first: Dictionary = _floating_first(1 - att, "prevent_first_attack")
	if not shield_first.is_empty():
		state.floating.erase(shield_first)
		state.attack["prevent_first"] = {"stages": int(shield_first.get("stages", 0)), "life": int(shield_first.get("life", 0)),
			"source": int(shield_first.get("source", -1))}
	state.last_attack = {}
	state.consecutive_passes = 0
	# The declaration is the last beat of the attack phase, so it is stamped before the phase
	# moves on. Stamping it BATTLE made the client's tracker skip ATTACK entirely.
	# `id` names the card while it is public. The same update can send it somewhere hidden before a
	# client replays the declaration (a Life Deck bottom after use), and the view is read after that.
	_emit(&"attack_declared", {
		"player": att, "kind": state.attack["kind"], "source": state.attack["source"],
		"id": source.def.id if source != null else "",
		"is_power": is_power, "is_final": is_final, "focused": state.attack["focused"], "empowered": empowered,
	})
	state.battle_step = 2
	state.phase = GameState.Phase.BATTLE
	var constant: Dictionary = _constant(attacker)
	if constant.has("on_attack"):
		_enqueue_keyed(constant.get("on_attack", []), "on_attack", att, {"attack": state.attack}, attacker.in_control())
	if attacker.mastery != null and not _forbidden(attacker, "mastery"):
		_enqueue(attacker.mastery.def.effects, "on_attack", att, {"attack": state.attack}, attacker.mastery)
	# "All marked-only attacks discard an Ally in play when they are performed." The Grounds belong
	# to the table rather than to a player, so the line fires for whoever is attacking.
	if state.grounds != null:
		_enqueue(state.grounds.def.effects, "on_attack", att, {"attack": state.attack}, state.grounds)


## The attack record for `att` attacking with `spec`, with the card's conditional lines merged
## and every standing effect on the attacker folded in. Reads state and changes nothing, so a
## forecast can build the same record the battle sequence will.
func _build_attack(att: int, source: CardInstance, spec: Dictionary, effects: Array[Dictionary], is_power: bool, is_final: bool, empowered: bool, performer: CardInstance, first_attack: bool) -> Dictionary:
	var attacker: PlayerState = state.players[att]
	if performer == null:
		performer = attacker.in_control()
	var kind: String = str(spec.get("kind", "strike"))
	var used: Array[Dictionary] = []
	# "For the remainder of Combat, when you use Empower, you still use all of the effects after
	# the Empower."
	var keeps_text: bool = _has_floating(att, "empower_keeps_text")
	for e in effects:
		if empowered and bool(e.get("after_empower", false)) and not keeps_text:
			continue
		used.append(e)
	# Conditional lines on the card ("if X is in control, +3 stages and focused").
	if spec.has("variants"):
		var merged: Dictionary = spec.duplicate(true)
		merged.erase("variants")
		for v in spec["variants"]:
			if not _cond(v.get("when", {}), att, {}):
				continue
			# A conditional line printed after Empower goes with the rest of that text.
			if empowered and bool(v.get("after_empower", false)) and not keeps_text:
				continue
			for k in v.keys():
				if k == "when":
					continue
				if k == "effects":
					for ve in v["effects"]:
						used.append(ve)
				elif (k == "stages" or k == "life") and merged.has(k):
					merged[k] = int(merged[k]) + int(v[k])
				else:
					merged[k] = v[k]
		spec = merged
	# A Drill can promote "if successful" lines on matching cards to secondary effects.
	if source != null:
		for d in _active(attacker.drills()):
			var needle: String = str(d.def.raw.get("promote_if_successful", ""))
			if needle != "" and source.def.title.contains(needle):
				var promoted: Array[Dictionary] = []
				for e in used:
					if str(e.get("trigger", "secondary")) == "if_successful":
						var e2: Dictionary = e.duplicate(true)
						e2["trigger"] = "secondary"
						promoted.append(e2)
					else:
						promoted.append(e)
				used = promoted
				break
	# "All of your Saiyan Style attacks gain 'Raise your anger 1 level. Gain 3 power stages.'": the
	# Mastery writes the lines onto the attack, where they resolve as its own secondary effects.
	# `otherwise` is what every other attack gains ("All of your attacks gain X. All of your Black
	# Style attacks gain Y instead"), a Power's attack among them, since it belongs to no school.
	if attacker.mastery != null and not _forbidden(attacker, "mastery"):
		var grant: Dictionary = attacker.mastery.def.raw.get("grant_attack_lines", {})
		var kind_ok: bool = str(grant.get("kind", "")) == "" or str(grant["kind"]) == str(spec.get("kind", "strike"))
		if not grant.is_empty() and kind_ok:
			var school_ok: bool = str(grant.get("school", "")) == "" or (source != null and source.def.school == str(grant["school"]))
			var lines_given: Array = grant.get("effects", []) if school_ok else grant.get("otherwise", [])
			for g in lines_given:
				used.append(g)
	# "Any 'If successful' effects that raise your Fervor or lower your opponent's Fervor are
	# secondary effects for the remainder of Combat." Only those lines move; the rest of a Hit stays.
	if _has_floating(att, "fervor_hits_secondary"):
		var moved: Array[Dictionary] = []
		for e in used:
			if str(e.get("trigger", "secondary")) == "if_successful" and _is_fervor_swing(e):
				var e2: Dictionary = e.duplicate(true)
				e2["trigger"] = "secondary"
				moved.append(e2)
			else:
				moved.append(e)
		used = moved
	var focused: bool = bool(spec.get("focused", false))
	var constant: Dictionary = _constant(attacker)
	if bool(constant.get("attacks_focused", false)):
		focused = true
	# "All Strikes you perform that are marked are focused attacks": narrower than the flag above,
	# which focuses everything, and it reads the keyword on the card being played.
	var focus_tag: String = str(constant.get("focus_tag", ""))
	if focus_tag != "" and source != null and has_tag(source, focus_tag):
		var focus_kind: String = str(constant.get("focus_tag_kind", "any"))
		if focus_kind == "any" or focus_kind == kind:
			focused = true
	if source != null and _made_focused(att, source):
		focused = true
	var unstoppable: bool = bool(spec.get("unstoppable", false))
	if first_attack and bool(constant.get("first_styled_unstoppable", false)) and source != null and source.def.school != "":
		unstoppable = true
	return {
		"source": source.uid if source != null else -1,
		"attacker": att,
		"defender": 1 - att,
		"kind": kind,
		"is_power": is_power,
		"is_final": is_final,
		"empowered": empowered,
		"spec": spec,
		"effects": used,
		"focused": focused,
		"unstoppable": unstoppable,
		"stopped": false,
		"stop_count": 0,
		"stops_needed": maxi(1, int(spec.get("stops_needed", 1))),
		"performer": performer.uid,
		"stages": 0,
		"life": 0,
		"extra_life": 0,
		"extra_stages": 0,
		"life_remaining": 0,
		"stages_dealt": 0,
		"life_dealt": 0,
		"target": -1,
		"no_prevent": bool(spec.get("no_prevent", false)) or _has_floating(att, "no_prevent") or _attachment_no_prevent(state.players[att]),
		"no_prevent_by": str(spec.get("no_prevent_by", "")),
		"damage_removes": bool(spec.get("damage_removes", false)) or bool(constant.get("damage_removes", false)) or _has_floating(att, "damage_removes") or _attachment_removes(attacker, source),
	}


## A standing "your <school> attacks are Focused". `empower_only` narrows it to the attacks that
## have Empower ("any of your Saiyan Style attacks that have Empower are focused attacks").
func _made_focused(att: int, source: CardInstance) -> bool:
	for f in state.floating:
		if int(f.get("owner", -1)) != att or str(f.get("op", "")) != "make_focused" or not _phase_float_live(f):
			continue
		var school: String = str(f.get("school", ""))
		if school != "" and school != source.def.school:
			continue
		if bool(f.get("empower_only", false)) and source.def.empower <= 0:
			continue
		return true
	return false


## An effect line that raises its user's Fervor or lowers the opponent's.
static func _is_fervor_swing(e: Dictionary) -> bool:
	var who: String = str(e.get("who", "self"))
	match str(e.get("op", "")):
		"fervor":
			var n: int = int(e.get("amount", 0))
			return (who == "self" and n > 0) or (who == "opponent" and n < 0)
		"set_fervor":
			return who == "opponent"
	return false


## What each attack the pending prompt offers would deal if it landed now, keyed by the option's
## card uid: the same breakdown `damage_breakdown` gives for an attack in the air, worked out
## from a record built exactly as declaring it would. An "empower" option adds its own numbers
## under `empowered`. Empty unless the prompt is `seat`'s attack action.
func attack_forecasts(seat: int) -> Dictionary:
	var out: Dictionary = {}
	if prompt == null or prompt.player != seat or prompt.kind != &"attack_action":
		return out
	var first: bool = state.players[seat].attack_count_combat == 0
	for o in prompt.options:
		var c: CardInstance = card(o.card)
		var a: Dictionary = {}
		match o.type:
			&"attack":
				if c == null:
					continue
				var empowered: bool = o.value != null and str(o.value) == "empower"
				a = _build_attack(seat, c, c.def.attack, c.def.effects, false, false, empowered, null, first)
			&"power":
				var pw: Dictionary = c.power_alt() if c != null and o.value != null and str(o.value) == "alt" else (c.power() if c != null else {})
				if c == null or not pw.has("attack"):
					continue
				var effects: Array[Dictionary] = []
				effects.assign(pw.get("effects", []))
				a = _build_attack(seat, c, pw["attack"], effects, true, false, false, c, first)
			&"final_strike":
				if out.has(o.card):
					continue   # the card's own attack is the number that matters
				a = _build_attack(seat, null, {"kind": "strike"}, [], false, true, false, null, first)
			_:
				continue
			# Costs come off before the Strike Table is read, so the forecast pays them first.
		var performer: CardInstance = _performer(a)
		var cost: int = _cost_stages(a["spec"], state.players[seat], card(int(a.get("source", -1))))
		if state.grounds != null and bool(state.grounds.def.raw.get("double_costs", false)):
			cost *= 2
		var energy_before: int = performer.energy
		performer.energy = maxi(0, performer.energy - cost)
		var b: Dictionary = _damage_calc(a)
		performer.energy = energy_before
		b.erase("spent")
		b["is_final"] = bool(a["is_final"])
		b["cost_stages"] = cost
		b["energy_left"] = maxi(0, energy_before - cost)
		if o.type == &"attack" and str(o.value) == "empower" and out.has(o.card):
			(out[o.card] as Dictionary)["empowered"] = {"stages": int(b["stages"]), "life": int(b["life"])}
			continue
		# The second Power of an Aspect that prints two, forecast beside the first rather than
		# over the top of it.
		if o.type == &"power" and o.value != null and str(o.value) == "alt" and out.has(o.card):
			(out[o.card] as Dictionary)["alt"] = {"stages": int(b["stages"]), "life": int(b["life"])}
			continue
		out[o.card] = b
	return out


## The personality performing the current attack (an Ally may attack without control).
func _performer(a: Dictionary) -> CardInstance:
	var c: CardInstance = card(int(a.get("performer", -1)))
	if c != null:
		return c
	return state.players[int(a.get("attacker", state.attacker))].in_control()


## One defense, shield, or standing effect counts toward the stops an attack needs.
func _register_stop(a: Dictionary) -> void:
	if bool(a["unstoppable"]):
		return
	a["stop_count"] = int(a.get("stop_count", 0)) + 1
	if int(a["stop_count"]) >= int(a.get("stops_needed", 1)):
		a["stopped"] = true
		state.players[1 - int(a["attacker"])].stopped_this_phase = true


## Back to the defense prompt when the attack still needs another stop, else on to the shields.
func _after_defense(a: Dictionary) -> void:
	if not bool(a["stopped"]) and int(a.get("stop_count", 0)) > 0 and int(a.get("stop_count", 0)) < int(a.get("stops_needed", 1)):
		state.phase = GameState.Phase.DEFEND
	else:
		state.phase = GameState.Phase.BATTLE


## Records what stopped the attack, for the outcome the client shows and the log line.
func _note_stop(a: Dictionary, c: CardInstance, how: String) -> void:
	if bool(a["stopped"]) and not a.has("stopped_by"):
		a["stopped_by"] = {"card": c.uid if c != null else -1, "how": how}


## "Attach this card to your opponent's Duelist. While attached, and while the attached personality
## is in control of Combat, damage from your attacks cannot be prevented." The card rides on the
## other side of the table, so it is found among this player's own attachments by where it sits.
func _attachment_no_prevent(p: PlayerState) -> bool:
	var host: CardInstance = state.players[1 - p.index].in_control()
	if host == null:
		return false
	for at in p.attachments():
		if at.attached_to == host and bool(at.def.attachment.get("no_prevent", false)):
			return true
	return false


## An attached card can say "wounds from your Sword attacks are removed from the game".
func _attachment_removes(p: PlayerState, source: CardInstance) -> bool:
	for at in p.attachments():
		if at.attached_to != p.in_control() or not bool(at.def.attachment.get("damage_removes", false)):
			continue
		var needle: String = str(at.def.attachment.get("title_contains", ""))
		if needle == "" or _title_matches(p.index, source, needle):
			return true
	return false


## Does this card's title carry the word a matching effect is looking for? A card can lend its
## own attacks a word for the rest of Combat ("your Pyre attacks count as having Sword in the
## title"), so the question is asked here instead of reading the title directly.
func _title_matches(owner: int, src: CardInstance, needle: String) -> bool:
	if src == null:
		return false
	if src.def.title.contains(needle):
		return true
	var f: Dictionary = _floating_first(owner, "counts_as_title")
	if f.is_empty() or str(f.get("title", "")) != needle:
		return false
	# "...any Pyre attacks you perform with cards from your hand": a card still in hand (a forecast)
	# or performed out of it. A Remain card used again from the table has already been set to
	# remain this Combat, which is how its later uses are told apart from its first.
	if bool(f.get("from_hand", false)):
		var in_hand: bool = src.zone == &"hand" or src.zone == &"resolving"
		if not in_hand or src.remain_combat == state.combat_count:
			return false
	var school: String = str(f.get("school", ""))
	return school == "" or src.def.school == school


# --- Counter window ("stops the effects of any Combat card") ---------------

## Returns true when the opponent gets to respond before the card resolves. Two things can happen
## in this window: a counter card that stops a Combat card played from hand, and, for a card used in
## place of an attack, one Ally taking control of Combat before any effect occurs.
func _open_counter_window(c: CardInstance, mode: String, control_taken: bool = false) -> bool:
	var owner: PlayerState = state.players[c.owner]
	var opp: PlayerState = state.players[1 - owner.index]
	var opts: Array[Command] = []
	if c.zone == &"hand" and c.def.type == CardDef.Type.COMBAT:
		for k in opp.hand:
			if k.def.counter == "combat" and _can_play(opp, k.def) and not _forbidden(opp, "combat_cards"):
				opts.append(Command.new(opp.index, &"counter", k.uid))
	# "Whenever your opponent plays or uses a card outside of their Defender Defends phase, you may
	# have one Ally take control of Combat before any effects occur." One Ally, once per card.
	var counters: int = opts.size()
	if mode == "use" and not control_taken and may_ally_control(opp):
		for al in opp.allies():
			if al != opp.in_control():
				opts.append(Command.new(opp.index, &"control", al.uid))
	if opts.is_empty():
		# The rival held nothing that could answer, so the window opened and closed unseen. Say so,
		# the way any swallowed effect does, rather than letting the card resolve out of silence.
		_emit(&"window_skipped", {"player": opp.index, "window": "respond"})
		return false
	opts.append(Command.new(opp.index, &"decline"))
	state.pending_play = {"card": c.uid, "mode": mode, "control_taken": control_taken}
	_set_prompt(opp.index, &"respond", opts, {
		"card": c.uid, "mode": mode, "source": c.uid, "card_title": c.def.title,
		"can_counter": counters > 0, "ally_window": opts.size() - 1 > counters,
	})
	return true


func _handle_respond(cmd: Command) -> void:
	var pending: Dictionary = state.pending_play
	state.pending_play = {}
	var mode: String = str(pending.get("mode", "use"))
	if mode == "ascension":
		var winner: int = int(pending.get("winner", 0))
		if cmd.type != &"use":
			_emit(&"declined_counter", {"player": cmd.player})
			_win(winner, "ascension")
			return
		# The answer resolves first; the win is checked again once the queue is empty, which is
		# where it stands or falls on whether the card actually moved them off their top Aspect.
		state.pending_ascension = winner
		var answer: CardInstance = card(cmd.card)
		_use_card(state.players[answer.owner], answer, false)
		return
	if mode == "declare":
		# The opponent's Declare-step window (cards used "during your opponent's Declare step").
		state.declare_window_done = true
		if cmd.type == &"use":
			var used: CardInstance = card(cmd.card)
			var user: PlayerState = state.players[used.owner]
			_emit(&"card_used", {"player": user.index, "card": used.uid, "id": used.def.id})
			_enqueue(used.def.effects, "opponent_declare", user.index, {}, used)
			_enqueue([{"trigger": "opponent_declare", "op": "spend_source"}], "opponent_declare", user.index, {}, used)
		else:
			_emit(&"declined_counter", {"player": cmd.player})
		return
	var c: CardInstance = card(int(pending.get("card", -1)))
	var owner: PlayerState = state.players[c.owner]
	if cmd.type == &"control":
		# One Ally steps in front of the card. The window stays open for a counter, but no second
		# Ally may take control off the same card.
		var opp: PlayerState = state.players[1 - owner.index]
		opp.controlling = card(cmd.card)
		_emit(&"control", {"player": opp.index, "card": opp.controlling.uid})
		if _open_counter_window(c, mode, true):
			return
		_use_card(owner, c)
		return
	if cmd.type == &"counter":
		var k: CardInstance = card(cmd.card)
		_erase_from_zone(k)
		k.zone = &"resolving"
		_emit(&"countered", {"player": cmd.player, "card": k.uid, "target": c.uid})
		_finish_card(k, false)
		if c.zone == &"hand":
			_erase_from_zone(c)
		c.zone = &"resolving"
		_finish_card(c, false)
		if mode == "use":
			owner.combat_cards_used_combat = state.combat_count
			_after_non_attack_action()
		else:
			# Countered defense: the attack goes on as if nothing was played.
			_emit(&"no_defense", {"player": owner.index, "auto": true, "reason": "countered"})
			state.battle_step = 7
			state.phase = GameState.Phase.BATTLE
		return
	_emit(&"declined_counter", {"player": cmd.player})
	if mode == "use":
		_use_card(owner, c)
	else:
		_play_defense(owner, c)


# --- Battle sequence ------------------------------------------------------

func _advance_battle() -> void:
	var a: Dictionary = state.attack
	var attacker: PlayerState = state.players[int(a["attacker"])]
	var defender: PlayerState = state.players[int(a["defender"])]
	match state.battle_step:
		2:
			_pay_costs(attacker, a)
			if prompt != null:
				return
			state.battle_step = 3
		3:
			if _prompt_attack_boost(attacker, a):
				return
			_enqueue(a["effects"], "secondary", attacker.index, {"attack": a}, _attack_source())
			state.battle_step = 4
		4:
			if may_ally_control(defender):
				_set_prompt(defender.index, &"control", _control_options(defender), {"role": "defender", "source": int(a.get("source", -1))})
				state.battle_step = 5
				return
			defender.controlling = defender.duelist
			state.battle_step = 5
		5:
			state.phase = GameState.Phase.DEFEND
			state.battle_step = 7
		7:
			_apply_shields(defender, a)
			state.battle_step = 8
		8:
			if bool(a["stopped"]):
				_emit(&"attack_stopped", {"player": attacker.index})
				state.battle_step = 16
			else:
				# "Stops a successful attack" waits until here, after every ordinary defense has
				# failed. Declining leaves `late_stop_done` set, so this step falls through next time.
				if _prompt_late_stop():
					return
				# This step is re-entered after each of the windows below, so say it once.
				if not bool(a.get("success_announced", false)):
					a["success_announced"] = true
					_emit(&"attack_successful", {"player": attacker.index})
				# "Use when performing an attack." The attack has connected and nothing is dealt
				# yet: the card rides along with it, so it costs no attack phase of its own and is
				# never wasted on an attack that was stopped. Declining leaves `performing_done`
				# set, so this step falls through next time.
				if _prompt_performing_attack(attacker, a):
					return
				# "Use immediately after a Strike you perform becomes successful." The attacker's
				# own window, which is not the defender's late stop above: it opens only once the
				# attack is through, and only for cards that name this timing.
				if _prompt_follow_up(attacker, a):
					return
				_enqueue(a["effects"], "before_damage", attacker.index, {"attack": a}, _attack_source())
				state.battle_step = 9
		9:
			_base_damage(attacker, defender, a)
			state.battle_step = 10
		10:
			_modify_damage(attacker, defender, a)
			state.battle_step = 11
		11:
			# "You may reduce the damage this attack deals by any amount to a minimum of 0. For
			# every life card of damage reduced this way, discard one of your opponent's Drills in
			# play." The wounds are already worked out, so the trade is offered here, and how many
			# to give up is the attacker's decision, never assumed.
			if _prompt_damage_trade(attacker, defender, a):
				return
			# An in-control Ally with the capture trait may take a Seal instead of dealing the damage.
			var performer: CardInstance = _performer(a)
			var has_damage: bool = int(a["stages"]) > 0 or int(a["life"]) > 0
			if performer.def.type == CardDef.Type.PERSONALITY and performer.def.capture_trait and has_damage and not _capturable_seals(defender).is_empty():
				var opts: Array[Command] = []
				for t in _capturable_seals(defender):
					opts.append(Command.new(attacker.index, &"capture", t.uid))
				opts.append(Command.new(attacker.index, &"deal_damage"))
				_set_prompt(attacker.index, &"capture_instead", opts, {"source": performer.uid, "card_title": performer.def.title})
				state.battle_step = 12
				return
			state.battle_step = 12
		12:
			if int(a["target"]) < 0:
				if not defender.allies().is_empty() and (int(a["stages"]) > 0 or int(a["life"]) > 0) and not _has_floating(defender.index, "no_ally_control"):
					var opts: Array[Command] = []
					for t in _damage_targets(defender):
						opts.append(Command.new(defender.index, &"target", t.uid))
					# Only one personality can take it: nothing to redirect to, so no stop.
					if opts.size() > 1:
						_set_prompt(defender.index, &"redirect", opts, {"source": int(a.get("source", -1))})
						return
				a["target"] = defender.in_control().uid
			_deal_stage_damage(defender, a)
			state.battle_step = 13
		13:
			_deal_life_damage(defender, a)
		14:
			# "Use immediately after you take damage from an attack": the defender's own window. It
			# opens once the damage is on the table and before the attacker takes what critical
			# damage allows, because the card answers the hit and not its consequences.
			if _prompt_after_damage(defender, a):
				return
			# Critical damage: 5+ life cards let the attacker capture a Seal, discard an Ally, or lower Fervor.
			if int(a["life_dealt"]) >= CRITICAL_THRESHOLD:
				var opts: Array[Command] = []
				for t in _capturable_seals(defender):
					opts.append(Command.new(attacker.index, &"capture", t.uid))
				# "Your Allies cannot be discarded" is absolute, and card text beats the rulebook,
				# so a constant that guards them stops this too.
				for al in defender.allies():
					if not _ally_protected(defender, al) and not allies_undiscardable(defender):
						opts.append(Command.new(attacker.index, &"discard_ally", al.uid))
				if defender.fervor > 0 and not fervor_shielded(defender) and not fervor_locked(defender):
					opts.append(Command.new(attacker.index, &"lower_fervor"))
				if not opts.is_empty():
					opts.append(Command.new(attacker.index, &"no_critical"))
					_set_prompt(attacker.index, &"critical", opts, {"life_dealt": int(a["life_dealt"]), "source": int(a.get("source", -1))})
					state.battle_step = 15
					return
			state.battle_step = 15
		15:
			_enqueue(a["effects"], "if_successful", attacker.index, {"attack": a}, _attack_source())
			# "All your attacks gain 'If successful, your Main Personality gains N power stages'":
			# a standing grant, paid to the duelist whichever personality landed the attack.
			for f in state.floating:
				if int(f.get("owner", -1)) == attacker.index and str(f.get("op", "")) == "energy_on_hit" and _phase_float_live(f):
					var before: int = attacker.duelist.energy
					_gain_energy_from_card(attacker, attacker.duelist, maxi(1, int(f.get("energy", 2))))
					if attacker.duelist.energy != before:
						_emit(&"energy_changed", {"player": attacker.index, "card": attacker.duelist.uid, "from": before, "to": attacker.duelist.energy, "source": int(f.get("source", -1))})
			if attacker.mastery != null and not _forbidden(attacker, "mastery"):
				_enqueue(attacker.mastery.def.effects, "on_success", attacker.index, {"attack": a}, attacker.mastery)
			# A Non-Combat in play that answers a successful attack. It spends itself in its own text.
			if not _forbidden(attacker, "non_combats"):
				for nc in _active(attacker.non_combats()):
					if nc.attached_to == null:
						_enqueue(nc.def.effects, "on_success", attacker.index, {"attack": a}, nc)
			state.battle_step = 16
		16:
			_finish_attack(attacker, a)
		_:
			assert(false, "Bad battle step %d" % state.battle_step)


func _attack_source() -> CardInstance:
	var uid: int = int(state.attack.get("source", -1))
	return card(uid) if uid >= 0 else null


func _pay_costs(attacker: PlayerState, a: Dictionary) -> void:
	var spec: Dictionary = a["spec"]
	var ic: CardInstance = _performer(a)
	var cost_stages: int = _cost_stages(spec, attacker, card(int(a.get("source", -1))))
	var cost_life: int = int(spec.get("cost_life", 0))
	# "You may discard a card from your hand to perform this attack": a cost, so it is paid before
	# the attack and the attack is not offered at all with too few cards in hand.
	var cost_hand: int = int(spec.get("cost_hand", 0))
	if state.grounds != null and bool(state.grounds.def.raw.get("double_costs", false)):
		cost_stages *= 2
		cost_life *= 2
	if cost_stages > 0:
		ic.energy = maxi(0, ic.energy - cost_stages)
	if cost_life > 0:
		_discard_life(attacker, cost_life)
	if cost_stages > 0 or cost_life > 0:
		_emit(&"cost_paid", {"player": attacker.index, "stages": cost_stages, "life": cost_life, "energy": ic.energy})
	_expire_next_attack_tax(attacker)
	if cost_hand > 0:
		if attacker.hand.size() > cost_hand:
			# Which card goes is the attacker's call, so this opens a prompt. The battle sequence
			# resumes at the step after costs once the card is picked.
			assert(not spec.has("pay_stages"), "an attack cannot ask for both a hand cost and a stage payment")
			_prompt_discard_choice(attacker, cost_hand)
			_choice["battle_step"] = 3
			return
		_discard_hand(attacker, cost_hand, false)
	if spec.has("pay_stages"):
		# "Pay any number of stages, +1 wound per N paid." `from: "duelist"` is "from your Main
		# Personality", whoever is performing the attack.
		var per: int = maxi(1, int(spec["pay_stages"].get("per", 2)))
		var payer_card: CardInstance = attacker.duelist if str(spec["pay_stages"].get("from", "")) == "duelist" else ic
		var opts: Array[Command] = []
		var amount: int = 0
		while amount <= payer_card.energy:
			opts.append(Command.new(attacker.index, &"pay", -1, amount))
			amount += per
		if opts.size() > 1:
			var src: CardInstance = _attack_source()
			_set_prompt(attacker.index, &"pay", opts, {"per": per, "source": src.uid if src != null else -1, "card_title": src.def.title if src != null else ""})
	elif spec.has("pay_life") and not attacker.life_deck.is_empty():
		# "You may discard the top card of your Life Deck to do more damage": an optional cost, so
		# it asks yes or no and the answer is how many cards go.
		var life_src: CardInstance = _attack_source()
		var life_opts: Array[Command] = [Command.new(attacker.index, &"pay_life", -1, 0), Command.new(attacker.index, &"pay_life", -1, 1)]
		_choice["kind"] = "pay_life"
		_set_prompt(attacker.index, &"pay", life_opts, {"per": 1, "life_cost": true,
				"source": life_src.uid if life_src != null else -1,
				"card_title": life_src.def.title if life_src != null else ""})
	elif spec.has("pay_hand") and not attacker.hand.is_empty():
		# "You may discard a card from your hand when you perform this attack to do more damage":
		# yes or no first, and on a yes the attacker picks which card goes.
		var hand_src: CardInstance = _attack_source()
		var hand_opts: Array[Command] = [Command.new(attacker.index, &"pay_hand", -1, 0), Command.new(attacker.index, &"pay_hand", -1, 1)]
		_choice["kind"] = "pay_hand"
		_set_prompt(attacker.index, &"pay", hand_opts, {"per": 1, "hand_cost": true,
				"source": hand_src.uid if hand_src != null else -1,
				"card_title": hand_src.def.title if hand_src != null else ""})


func _handle_pay(cmd: Command) -> void:
	if str(_choice.get("kind", "")) == "pay_energy":
		_handle_pay_energy(cmd)
		return
	if str(_choice.get("kind", "")) == "pay_life":
		_handle_pay_life(cmd)
		return
	if str(_choice.get("kind", "")) == "pay_hand":
		_handle_pay_hand(cmd)
		return
	var a: Dictionary = state.attack
	var attacker: PlayerState = state.players[int(a["attacker"])]
	var spec: Dictionary = a["spec"]
	var paid: int = int(cmd.value)
	var per: int = maxi(1, int(spec["pay_stages"].get("per", 2)))
	var ic: CardInstance = attacker.duelist if str(spec["pay_stages"].get("from", "")) == "duelist" else _performer(a)
	ic.energy = maxi(0, ic.energy - paid)
	# A payment buys wounds, Energy damage, or both, whichever the card prints.
	a["extra_life"] = int(a["extra_life"]) + int(paid / per) * int(spec["pay_stages"].get("life", 0))
	a["extra_stages"] = int(a["extra_stages"]) + int(paid / per) * int(spec["pay_stages"].get("stages", 0))
	_emit(&"cost_paid", {"player": attacker.index, "stages": paid, "life": 0, "energy": ic.energy})
	state.battle_step = 3


## "Discard the top card of your Life Deck to do more damage." The answer is 0 or 1 cards.
func _handle_pay_life(cmd: Command) -> void:
	var a: Dictionary = state.attack
	var attacker: PlayerState = state.players[int(a["attacker"])]
	var spec: Dictionary = a["spec"]
	_choice = {}
	if int(cmd.value) > 0:
		_discard_life(attacker, 1)
		a["extra_life"] = int(a["extra_life"]) + int(spec["pay_life"].get("life", 0))
		a["extra_stages"] = int(a["extra_stages"]) + int(spec["pay_life"].get("stages", 0))
		a["extra_source"] = "Life card paid"
		_emit(&"cost_paid", {"player": attacker.index, "stages": 0, "life": 1, "energy": _performer(a).energy})
	state.battle_step = 3


## "Discard a card from your hand to do more damage." The answer is 0 or 1; on a 1 the bonus is
## booked and the card to discard is the attacker's own pick, which moves the battle on after.
func _handle_pay_hand(cmd: Command) -> void:
	var a: Dictionary = state.attack
	var attacker: PlayerState = state.players[int(a["attacker"])]
	var spec: Dictionary = a["spec"]
	_choice = {}
	state.battle_step = 3
	if int(cmd.value) <= 0 or attacker.hand.is_empty():
		return
	a["extra_life"] = int(a["extra_life"]) + int(spec["pay_hand"].get("life", 0))
	a["extra_stages"] = int(a["extra_stages"]) + int(spec["pay_hand"].get("stages", 0))
	a["extra_source"] = "Card discarded"
	if attacker.hand.size() == 1:
		_emit(&"hand_discarded", {"player": attacker.index, "card": attacker.hand[0].uid, "random": false})
		_move_to_discard(attacker.hand[0])
		return
	state.battle_step = 2
	_prompt_discard_choice(attacker, 1)
	_choice["battle_step"] = 3


## "Lose any number of Energy; for each N lost, do X."
func _handle_pay_energy(cmd: Command) -> void:
	var payer: CardInstance = card(int(_choice.get("payer", -1)))
	var per: int = maxi(1, int(_choice.get("per", 1)))
	var paid: int = int(cmd.value)
	if payer != null:
		payer.energy = maxi(0, payer.energy - paid)
		_emit(&"cost_paid", {"player": cmd.player, "stages": paid, "life": 0, "energy": payer.energy})
	var times: int = int(paid / per)
	var list: Array[Dictionary] = []
	for i in range(times):
		for e in _choice.get("then", []):
			list.append(e)
	var owner: int = int(_choice.get("owner", cmd.player))
	var ctx: Dictionary = _choice.get("ctx", {})
	var source: CardInstance = card(int(_choice.get("source", -1)))
	_choice = {}
	if not list.is_empty():
		_queue.insert(0, {"effects": list, "index": 0, "trigger": "then", "owner": owner, "ctx": ctx, "source": source})


## What an attack costs in Energy. `src` is the card being performed, so a discount can name a
## school or a keyword the way a damage modifier does.
func _cost_stages(spec: Dictionary, p: PlayerState, src: CardInstance = null) -> int:
	var base: int = 0
	if spec.has("cost_stages"):
		base = int(spec["cost_stages"])
	elif str(spec.get("kind", "")) == "art":
		base = ART_COST
	if str(spec.get("kind", "")) == "art":
		var delta: int = _art_cost_delta(p)
		base = maxi(1, base + delta) if (delta < 0 and base > 0) else base + delta
	# Grounds can tax one kind of attack on their own, so a place where swinging a blade costs
	# more than casting does. Stated per kind, as `strike_cost_delta` or `art_cost_delta`.
	if state.grounds != null:
		base += int(state.grounds.def.raw.get("%s_cost_delta" % str(spec.get("kind", "")), 0))
	var tax: Dictionary = _floating_first(p.index, "next_attack_tax")
	if not tax.is_empty():
		base += int(tax.get("stages", 0))
	# "Your opponent's attacks cost an additional +1 power stage to perform": a tax the other side
	# puts out, read with that side as the owner, and added before this side's own discounts.
	for entry in _modifiers_for(state.players[1 - p.index], "opponent_cost", str(spec.get("kind", "")), src, {}):
		base += int((entry["m"] as Dictionary).get("stages", 0))
	# `scope: "cost"` modifiers price attacks: `stages` shifts the price with an optional `min`
	# floor ("Arts cost 1 less, minimum 1"), `set` fixes it ("their attacks cost no Energy"). They
	# come last so a waiver beats a tax, which is what "cost no Energy" says.
	for entry in _modifiers_for(p, "cost", str(spec.get("kind", "")), src, {}):
		var m: Dictionary = entry["m"]
		if m.has("set"):
			base = int(m["set"])
		elif int(m.get("stages", 0)) < 0:
			# "Cost 1 less, to a minimum of 1" never raises a price already at or under the floor.
			var floor_at: int = int(m.get("min", 0))
			if base > floor_at:
				base = maxi(floor_at, base + int(m["stages"]))
		else:
			base += int(m.get("stages", 0))
	return maxi(0, base)


## Mastery-style discounts on Arts ("cost 1 less to a minimum of 1").
func _art_cost_delta(p: PlayerState) -> int:
	var delta: int = 0
	if p.mastery != null and not _forbidden(p, "mastery"):
		delta += int(p.mastery.def.raw.get("art_cost_delta", 0))
	return delta


func _expire_next_attack_tax(p: PlayerState) -> void:
	var tax: Dictionary = _floating_first(p.index, "next_attack_tax")
	if not tax.is_empty():
		state.floating.erase(tax)


func _can_pay(ic: CardInstance, p: PlayerState, spec: Dictionary, src: CardInstance = null) -> bool:
	var cost: int = _cost_stages(spec, p, src)
	if state.grounds != null and bool(state.grounds.def.raw.get("double_costs", false)):
		cost *= 2
	if ic.energy < cost:
		return false
	if p.hand.size() < int(spec.get("cost_hand", 0)):
		return false
	return p.life_deck.size() > int(spec.get("cost_life", 0))


func _prompt_defense() -> void:
	var a: Dictionary = state.attack
	var d: PlayerState = state.players[int(a["defender"])]
	var kind: String = str(a["kind"])
	var focused: bool = bool(a["focused"])
	if _standing_stop(d, a):
		# A stop-all or stop-next effect already covers this attack; no card needs spending.
		_emit(&"no_defense", {"player": d.index, "auto": true, "reason": "standing"})
		state.phase = GameState.Phase.BATTLE
		return
	if d.must_pass:
		# After a Final Strike the player neither attacks nor defends; Shields and standing effects still work.
		_emit(&"no_defense", {"player": d.index, "auto": true, "reason": "final_strike"})
		state.phase = GameState.Phase.BATTLE
		return
	if bool(a["unstoppable"]):
		# "Cannot be stopped": no card or Power is offered, since none of them could change
		# the attack. Endurance, if the attack allows it, still gets its own window later.
		_emit(&"no_defense", {"player": d.index, "auto": true, "reason": "unstoppable"})
		state.phase = GameState.Phase.BATTLE
		return
	var opts: Array[Command] = []
	for c in d.hand:
		if _defense_usable(d, c, kind, focused):
			opts.append(Command.new(d.index, &"defend", c.uid))
	for c in d.remain_cards():
		if _defense_usable(d, c, kind, focused):
			opts.append(Command.new(d.index, &"defend", c.uid))
	for c in _active(d.non_combats()):
		if _defense_usable(d, c, kind, focused):
			opts.append(Command.new(d.index, &"defend", c.uid))
	for c in _active(d.drills()):
		if _defense_usable(d, c, kind, focused):
			opts.append(Command.new(d.index, &"defend", c.uid))
	# A Mastery can itself be the block ("once per Combat, discard a card to stop an attack").
	if d.mastery != null and not _forbidden(d, "mastery") and _drill_use_available(d.mastery) and _defense_usable(d, d.mastery, kind, focused):
		opts.append(Command.new(d.index, &"defend", d.mastery.uid))
	# A Mastery that buys wounds off with the discard pile instead of a block. One option per
	# number of cards spent, capped at what would clear the attack, so the player never pays more
	# than the wounds are worth.
	var burn: Dictionary = d.mastery.def.raw.get("defense_burn", {}) if d.mastery != null else {}
	if not burn.is_empty() and not _forbidden(d, "mastery"):
		var per: int = maxi(1, int(burn.get("prevent_per", 2)))
		var fuel: int = _burn_fuel(d, str(burn.get("school", "")))
		var wounds: int = int(damage_breakdown(a).get("wounds", 0))
		var most: int = mini(fuel, int(ceil(float(wounds) / float(per))))
		for n in range(1, most + 1):
			opts.append(Command.new(d.index, &"burn_defense", d.mastery.uid, n))
	var ic: CardInstance = d.in_control()
	if _power_defends(d, ic, kind, focused):
		opts.append(Command.new(d.index, &"power_defend", ic.uid))
	# "She does not have to be in control to use this power": an Ally may answer from the side.
	for al in d.allies():
		if al != ic and bool(al.power().get("no_control_needed", false)) and _power_defends(d, al, kind, focused):
			opts.append(Command.new(d.index, &"power_defend", al.uid))
	if opts.is_empty():
		_emit(&"no_defense", {"player": d.index, "auto": true, "reason": "none"})
		state.phase = GameState.Phase.BATTLE
		return
	opts.append(Command.new(d.index, &"no_defense"))
	_set_prompt(d.index, &"defense", opts, {"kind": kind, "focused": focused, "source": int(a.get("source", -1))})


## A card in play on this side that turns the opponent's removals into plain discards.
func _removal_becomes_discard(p: PlayerState) -> bool:
	for c in p.in_play:
		if bool(c.def.raw.get("protect_from_removal", false)):
			return true
	return false


## Cards in this player's discard pile a burning Mastery could spend. An empty school means any card.
func _burn_fuel(p: PlayerState, school: String) -> int:
	var n: int = 0
	for c in p.discard:
		if school == "" or c.def.school == school:
			n += 1
	return n


## Removes up to `want` of them from the game, newest first, and says how many actually went.
func _burn_from_discard(p: PlayerState, school: String, want: int) -> int:
	var paid: int = 0
	for i in range(p.discard.size() - 1, -1, -1):
		if paid >= want:
			break
		var c: CardInstance = p.discard[i]
		if school == "" or c.def.school == school:
			_remove_from_game(c)
			paid += 1
	return paid


## Whether a personality's own Power can answer this attack. A Power's defense may carry a `when`,
## the way a card's does: "stops a Strike performed against Edric or Emrys".
func _power_defends(d: PlayerState, ic: CardInstance, kind: String, focused: bool) -> bool:
	if not _power_available(d, ic) or _forbidden(d, "powers"):
		return false
	var dd: Dictionary = ic.power().get("defense", {})
	if not CardDef.defense_stops(dd, kind, focused):
		return false
	return not dd.has("when") or _cond(dd["when"], d.index, {"attack": state.attack})


## The window a card that "stops a successful attack" is played in: after the attack is already
## through, and only then. Returns true when it is open and waiting on the defender.
func _prompt_late_stop() -> bool:
	var a: Dictionary = state.attack
	var d: PlayerState = state.players[int(a["defender"])]
	if bool(a.get("late_stop_done", false)) or d.must_pass:
		return false
	a["late_stop_done"] = true
	var kind: String = str(a["kind"])
	var focused: bool = bool(a["focused"])
	var opts: Array[Command] = []
	for c in d.hand:
		if _defense_usable(d, c, kind, focused, true):
			opts.append(Command.new(d.index, &"defend", c.uid))
	if opts.is_empty():
		_emit(&"window_skipped", {"player": d.index, "window": "late_stop"})
		return false
	opts.append(Command.new(d.index, &"no_defense"))
	state.phase = GameState.Phase.DEFEND
	_set_prompt(d.index, &"defense", opts, {"kind": kind, "focused": focused, "late": true, "source": int(a.get("source", -1))})
	return true


func _defense_usable(d: PlayerState, c: CardInstance, kind: String, focused: bool, late: bool = false) -> bool:
	var def: CardDef = c.def
	if not def.is_defense():
		return false
	if def.is_end_combat_card():
		return false   # cards that end Combat can only be played as an attack action
	var timing: String = str(def.raw.get("use_at", ""))
	if late:
		if timing != LATE_STOP:
			return false
	elif timing != "":
		return false   # and a card that names its own timing waits for that moment
	if not _can_play(d, def):
		return false
	if def.type == CardDef.Type.COMBAT and _forbidden(d, "combat_cards"):
		return false
	if def.type == CardDef.Type.STRIKE and _forbidden(d, "strike_cards"):
		return false
	if def.type == CardDef.Type.ART and _forbidden(d, "art_cards"):
		return false
	if def.is_stop_all_card() and _forbidden(d, "stop_all"):
		return false
	if def.defense.has("when") and not _cond(def.defense["when"], d.index, {"attack": state.attack}):
		return false
	# "Your Black Style Non-Drill cards that can stop attacks can also stop focused attacks."
	if focused and d.mastery != null and not _forbidden(d, "mastery") and def.type != CardDef.Type.DRILL \
			and def.school != "" and def.school == str(d.mastery.def.raw.get("stop_focused_school", "")):
		focused = false
	if not def.stops_kind(kind, focused):
		return false
	var blocked: String = str(state.attack.get("spec", {}).get("no_stop_by", ""))
	if blocked != "" and int(CardDef.TYPE_NAMES.get(blocked, -2)) == def.type:
		return false
	if focused and str(def.defense.get("stop_focused", "")) == "discard_hand" and d.hand.size() < 2:
		return false
	if d.hand.size() < int(def.defense.get("cost_hand", 0)):
		return false
	var ic: CardInstance = d.in_control()
	if int(def.defense.get("cost_stages", 0)) > ic.energy:
		return false
	if int(def.defense.get("cost_life", 0)) >= d.life_deck.size():
		return false
	return true


func _handle_defense(cmd: Command) -> void:
	var d: PlayerState = state.players[cmd.player]
	match cmd.type:
		&"defend":
			var c: CardInstance = card(cmd.card)
			if c.zone == &"hand" and c.def.type == CardDef.Type.COMBAT and _open_counter_window(c, "defend"):
				return
			_play_defense(d, c)
		&"power_defend":
			var a: Dictionary = state.attack
			var ic: CardInstance = card(cmd.card)
			_mark_power_used(ic)
			_register_stop(a)
			_note_stop(a, ic, "power")
			_emit(&"defense_power", {"player": d.index, "card": ic.uid, "stopped": a["stopped"]})
			var effects: Array[Dictionary] = []
			effects.assign(ic.power().get("effects", []))
			_enqueue(effects, "secondary", d.index, {"attack": a}, ic)
			_after_defense(a)
		&"burn_defense":
			# "Remove any amount of your school's cards in your discard pile instead of using a
			# Defense, preventing N wounds for each." The cards go from the top down; which ones
			# leave is not a choice the printed card offers.
			var burn: Dictionary = d.mastery.def.raw.get("defense_burn", {})
			var per: int = maxi(1, int(burn.get("prevent_per", 2)))
			var paid: int = _burn_from_discard(d, str(burn.get("school", "")), int(cmd.value))
			state.attack["prevent_life"] = int(state.attack.get("prevent_life", 0)) + paid * per
			_emit(&"defense_burned", {"player": d.index, "cards": paid, "prevented": paid * per})
			state.phase = GameState.Phase.BATTLE
		&"no_defense":
			_emit(&"no_defense", {"player": d.index, "auto": false})
			state.phase = GameState.Phase.BATTLE


func _play_defense(d: PlayerState, c: CardInstance) -> void:
	var a: Dictionary = state.attack
	var def: CardDef = c.def
	var from_hand: bool = c.zone == &"hand"
	d.used_card_combat = true
	if from_hand:
		_erase_from_zone(c)
		c.zone = &"resolving"
		if def.type == CardDef.Type.COMBAT:
			d.combat_cards_used_combat = state.combat_count
	elif c.remain > 0:
		c.remain -= 1
		if c.remain == 0:
			_erase_from_zone(c)
			c.zone = &"resolving"
	var ic: CardInstance = d.in_control()
	var cost_stages: int = int(def.defense.get("cost_stages", 0))
	if cost_stages > 0:
		ic.energy = maxi(0, ic.energy - cost_stages)
	if int(def.defense.get("cost_life", 0)) > 0:
		_discard_life(d, int(def.defense["cost_life"]))
	if str(def.defense.get("stops", "")) != "none":
		_register_stop(a)
		_note_stop(a, c, "card")
	_emit(&"defense_played", {"player": d.index, "card": c.uid, "id": def.id, "stopped": a["stopped"]})
	if def.defense.has("copy_attack") and bool(a["stopped"]):
		_float(d.index, "copied_attack", "combat", {"spec": a["spec"].duplicate(true), "effects": a["effects"].duplicate(true)})
	if def.defense.has("stop_all"):
		_float(d.index, "stop_all", "combat", {"kind": str(def.defense["stop_all"])})
	if def.type == CardDef.Type.MASTERY or def.type == CardDef.Type.DRILL:
		c.power_used_combat = state.combat_count
	if int(def.defense.get("cost_hand", 0)) > 0:
		# "Discard a card from your hand to stop an attack." The discard is queued ahead of the
		# card's own lines, so a line that asks what was discarded reads it off the discard pile.
		_enqueue([{"trigger": "secondary", "op": "discard_hand", "amount": int(def.defense["cost_hand"]), "random": false}], "secondary", d.index, {"attack": a}, c)
	if bool(a["focused"]) and str(def.defense.get("stop_focused", "")) == "discard_hand":
		# "Discard a card from your hand to have this card stop a Focused attack." Which card goes
		# is the defender's call, and every effect on a card used as a defence is a secondary
		# effect, so it is queued rather than taken off the top of the hand here.
		_enqueue([{"trigger": "secondary", "op": "discard_hand", "amount": 1, "random": false}], "secondary", d.index, {"attack": a}, c)
	_enqueue(def.effects, "secondary", d.index, {"attack": a}, c)
	if from_hand or c.zone == &"resolving":
		# A Mastery can send its own school's blocks under the Life Deck instead of the discard pile.
		var keeps: String = str(d.mastery.def.raw.get("blocks_to_bottom", "")) if d.mastery != null and not _forbidden(d, "mastery") else ""
		var to_bottom: bool = keeps != "" and def.school == keeps and bool(a["stopped"]) and not def.remove_after_use
		_enqueue([{"trigger": "secondary", "op": "finish_source", "bottom": to_bottom}], "secondary", d.index, {"attack": a}, c)
	elif def.type == CardDef.Type.NON_COMBAT and c.attached_to == null:
		# A Non-Combat in play is spent by defending with it, like any other use.
		_enqueue([{"trigger": "secondary", "op": "spend_source"}], "secondary", d.index, {"attack": a}, c)
	_after_defense(a)


func _handle_control(cmd: Command) -> void:
	var d: PlayerState = state.players[cmd.player]
	d.controlling = card(cmd.card)
	_emit(&"control", {"player": d.index, "card": d.controlling.uid})


func _handle_redirect(cmd: Command) -> void:
	state.attack["target"] = cmd.card
	_emit(&"redirect", {"player": cmd.player, "card": cmd.card})


## True when a floating stop-all or stop-next effect will stop this attack at the shield step.
func _standing_stop(defender: PlayerState, a: Dictionary) -> bool:
	if bool(a["unstoppable"]) or int(a.get("stops_needed", 1)) > 1:
		return false
	var kind: String = str(a["kind"])
	var focused: bool = bool(a["focused"])
	for f in state.floating:
		if int(f.get("owner", -1)) != defender.index or not _phase_float_live(f):
			continue
		var op: String = str(f.get("op", ""))
		if op == "stop_next":
			var nk: String = str(f.get("kind", "any"))
			if nk == "any" or nk == kind:
				return true
		if op == "stop_all":
			var fk: String = str(f.get("kind", "any"))
			if fk == kind or (fk == "any" and not focused):
				return true
	return false


func _apply_shields(defender: PlayerState, a: Dictionary) -> void:
	if bool(a["stopped"]):
		return
	var kind: String = str(a["kind"])
	var focused: bool = bool(a["focused"])
	var unstoppable: bool = bool(a["unstoppable"])
	for f in state.floating:
		if int(f.get("owner", -1)) != defender.index or str(f.get("op", "")) != "stop_all" or not _phase_float_live(f):
			continue
		var fk: String = str(f.get("kind", "any"))
		if (fk == kind or (fk == "any" and not focused)) and not unstoppable:
			_register_stop(a)
			_note_stop(a, null, "floating")
			_emit(&"floating_stop", {"player": defender.index, "kind": fk})
			if bool(a["stopped"]):
				return
	# A one-shot stop may name a kind ("stops an energy attack during their next attack phase"),
	# in which case it waits for that kind rather than spending itself on the first thing thrown.
	var next_stop: Dictionary = {}
	for f in state.floating:
		if int(f.get("owner", -1)) != defender.index or str(f.get("op", "")) != "stop_next" or not _phase_float_live(f):
			continue
		var nk: String = str(f.get("kind", "any"))
		if nk == "any" or nk == kind:
			next_stop = f
			break
	if not next_stop.is_empty() and not unstoppable:
		state.floating.erase(next_stop)
		_register_stop(a)
		_note_stop(a, null, "floating")
		_emit(&"floating_stop", {"player": defender.index, "kind": "next"})
		if bool(a["stopped"]):
			return
	for s in _available_shields(defender, kind, focused):
		s.shield_used_combat = state.combat_count
		_emit(&"shield", {"player": defender.index, "card": s.uid, "focused": focused})
		if not focused and not unstoppable:
			_register_stop(a)
			_note_stop(a, s, "shield")
			if bool(a["stopped"]):
				return


func _available_shields(defender: PlayerState, kind: String, focused: bool) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	var ic: CardInstance = defender.in_control()
	if ic.shield_used_combat != state.combat_count and _shield_matches(ic.aspect_shield(), kind, focused):
		out.append(ic)
	if _forbidden(defender, "drills"):
		return out
	for d in _active(defender.drills()):
		if d.shield_used_combat != state.combat_count and _shield_matches(d.def.shield, kind, focused):
			out.append(d)
	return out


func _shield_matches(shield: String, kind: String, focused: bool) -> bool:
	if shield == "":
		return false
	if shield == "any":
		return not focused
	return shield == kind


func _base_damage(attacker: PlayerState, defender: PlayerState, a: Dictionary) -> void:
	var b: Dictionary = _damage_calc(a)
	a["stages"] = int(b["base_stages"])
	a["life"] = int(b["base_life"])
	if bool(b["prevented"]):
		a["stages"] = 0
		a["life"] = 0
		a["prevented_all"] = true
	_emit(&"base_damage", {
		"player": attacker.index, "stages": a["stages"], "life": a["life"], "kind": b["kind"],
		"table": b["table"], "wild": b["wild"], "printed": b["printed"],
		"attacker_might": b["attacker_might"], "defender_might": b["defender_might"],
		"attacker_band": b["attacker_band"], "defender_band": b["defender_band"],
	})


func _modify_damage(attacker: PlayerState, defender: PlayerState, a: Dictionary) -> void:
	var b: Dictionary = _damage_calc(a)
	for m in b["spent"]:
		state.floating.erase(m)
	a["stages"] = int(b["stages"])
	a["life"] = int(b["life"])
	_emit(&"modified_damage", {"player": attacker.index, "stages": a["stages"], "life": a["life"], "adds": b["adds"]})


## The damage an attack in the air would do if it landed now, with every step shown: the Strike
## Table lookup (or the Art base, or printed numbers), then each addition and subtraction with
## the card it comes from. Views show it before the defense so the defender knows what is
## coming; the battle sequence applies the same numbers at steps 9 and 10. No side effects.
func damage_breakdown(a: Dictionary) -> Dictionary:
	if a.is_empty():
		return {}
	var b: Dictionary = _damage_calc(a)
	b.erase("spent")
	# Energy past what the target is standing on becomes wounds. `_deal_stage_damage` works that
	# out at deal time; a forecast has to say the same thing, or a 5-Energy Strike on a target at
	# 1 Energy reads as no wounds when it is really four.
	var target: CardInstance = card(int(a.get("target", -1)))
	if target == null:
		target = state.players[int(a["defender"])].in_control()
	var absorbs: int = target.energy if target != null else 0
	b["overflow"] = maxi(0, int(b["stages"]) - absorbs)
	b["wounds"] = int(b["life"]) + int(b["overflow"])
	return b


func _damage_calc(a: Dictionary) -> Dictionary:
	var attacker: PlayerState = state.players[int(a["attacker"])]
	var defender: PlayerState = state.players[int(a["defender"])]
	var spec: Dictionary = a["spec"]
	var kind: String = str(a["kind"])
	var ac: CardInstance = _performer(a)
	var dc: CardInstance = defender.in_control()
	var wild: bool = ac.is_wild() or dc.is_wild()
	var table: int = WILD_BASE_DAMAGE if wild else strike_table.base_damage(ac.might(), dc.might())
	# "For the remainder of Combat all of your physical attacks have a Base Damage of X when you use
	# the Physical Attack Table. X = 4 minus your opponent's current anger level."
	if not wild and kind == "strike" and _has_floating(attacker.index, "table_base_fervor"):
		table = maxi(0, 4 - defender.fervor)
	# "Strike Table Base Damage is reduced by 2 when performed against him and raised by 2 when
	# performed by him." Both sides are asked, because either personality may be the one who
	# carries the power, and the two cancel when they face each other.
	if not wild and kind == "strike":
		table += int(_constant(attacker).get("strike_table_self", 0))
		table -= int(_constant(defender).get("strike_table_against", 0))
		table = maxi(0, table)
	var printed: bool = spec.has("printed_stages") or spec.has("printed_life")
	var base_stages: int = 0
	var base_life: int = 0
	if printed:
		base_stages = int(spec.get("printed_stages", 0))
		base_life = int(spec.get("printed_life", 0))
	elif kind == "strike":
		base_stages = table
	else:
		base_life = ART_BASE_LIFE
	if bool(spec.get("stages_from_table", false)):
		base_stages += table
	# "If the personality performing this attack has a higher power rating than the personality
	# defending against it, double the Base Damage from the Physical Attack Table": the table
	# result alone is multiplied, not what the card adds, and the ratings are read as it lands.
	var table_times: Dictionary = spec.get("table_multiply", {})
	if not table_times.is_empty() and kind == "strike" and not printed and not wild:
		var wants_higher: bool = bool(table_times.get("higher_might", false))
		if not wants_higher or ac.might() > dc.might():
			base_stages = table * maxi(1, int(table_times.get("by", 2)))
	# A float put out by this very attack ("for the remainder of Combat, your damage cannot be
	# prevented") is read here, where the damage is, and not only off the record built at declaration.
	var no_prevent: bool = bool(a.get("no_prevent", false)) or _has_floating(int(a["attacker"]), "no_prevent")
	var prevented: bool = bool(a.get("prevented_all", false)) or (_prevention_float(defender.index, "prevent_all", a) and not no_prevent)
	var src: CardInstance = card(int(a.get("source", -1)))
	var src_title: String = src.def.title if src != null else ac.def.title
	var adds: Array[Dictionary] = []   # {source, stages, life}; against-modifiers carry negatives
	if int(spec.get("stages", 0)) != 0 or int(spec.get("life", 0)) != 0:
		adds.append({"source": src_title, "stages": int(spec.get("stages", 0)), "life": int(spec.get("life", 0))})
	if int(a.get("extra_life", 0)) > 0 or int(a.get("extra_stages", 0)) > 0:
		adds.append({"source": str(a.get("extra_source", "Energy paid")), "stages": int(a.get("extra_stages", 0)), "life": int(a.get("extra_life", 0))})
	if bool(a["empowered"]) and src != null and src.def.empower > 0:
		adds.append({"source": "Empower", "stages": 0, "life": src.def.empower})
	if int(spec.get("life_per_ally", 0)) > 0 and not attacker.allies().is_empty():
		adds.append({"source": "%d Allies" % attacker.allies().size(), "stages": 0, "life": int(spec["life_per_ally"]) * attacker.allies().size()})
	if str(spec.get("life_per_tag", "")) != "":
		# "for every Construct personality in play": the card does not say whose, so both sides count.
		var kin: int = tag_count(str(spec["life_per_tag"]))
		if kin > 0:
			adds.append({"source": "%d %s" % [kin, str(spec["life_per_tag"]).capitalize()], "stages": 0, "life": kin})
	# "+X wounds, X = your current Fervor": the attacker's Fervor as the attack is worked out.
	if int(spec.get("life_per_fervor", 0)) > 0 and attacker.fervor > 0:
		adds.append({"source": "Fervor %d" % attacker.fervor, "stages": 0, "life": int(spec["life_per_fervor"]) * attacker.fervor})
	if bool(spec.get("life_from_surge", false)) and surge_of(attacker) > 0:
		adds.append({"source": "Surge", "stages": 0, "life": surge_of(attacker)})
	if int(spec.get("life_per_opponent_seal", 0)) > 0 and not defender.seals().is_empty():
		adds.append({"source": "Rival Seals", "stages": 0, "life": int(spec["life_per_opponent_seal"]) * defender.seals().size()})
	if spec.has("life_per_set_seal") and _set_seals_in_play(str(spec["life_per_set_seal"])) > 0:
		adds.append({"source": "%s Seals in play" % str(spec["life_per_set_seal"]).capitalize(), "stages": 0, "life": _set_seals_in_play(str(spec["life_per_set_seal"]))})
	var ctx: Dictionary = {"attack": a}
	var spent: Array[Dictionary] = []
	# "Cannot be reduced": the defender's reductions and caps are ignored; prevention is separate.
	var no_reduce: bool = bool(spec.get("no_reduce", false)) or _has_floating(attacker.index, "no_reduce")
	# "Three times the Base Damage": the attack carries its own multiplier, and it competes with
	# any from a modifier on the same terms, biggest wins.
	var multiply: int = maxi(1, int(spec.get("multiply", 1)))
	var multiply_source: String = src_title if multiply > 1 else ""
	# "No modifiers are added to Strikes performed against her": read off the defending
	# personality's own card, because the text names that personality and not their side.
	var blind: String = str((dc.aspect_data().get("constant", {}) as Dictionary).get("no_modifiers_against", ""))
	var own_mods: Array[Dictionary] = []
	if blind != kind and blind != "any":
		own_mods = _modifiers_for(attacker, "own", kind, src, ctx)
	for entry in own_mods:
		var m: Dictionary = entry["m"]
		if m.has("multiply"):
			# One multiplier at most: the biggest one applies.
			if int(m["multiply"]) > multiply:
				multiply = int(m["multiply"])
				multiply_source = _modifier_source(entry, attacker)
			continue
		var ms: int = _modifier_amount(m, "stages", attacker)
		var ml: int = _modifier_amount(m, "life", attacker)
		if ms != 0 or ml != 0:
			adds.append({"source": _modifier_source(entry, attacker), "stages": ms, "life": ml})
		if bool(m.get("once", false)):
			spent.append(m)
	var cap_stages: int = -1
	var cap_life: int = -1
	var cap_sources: PackedStringArray = PackedStringArray()
	if not no_reduce:
		for entry in _modifiers_for(defender, "against", kind, src, ctx):
			var m: Dictionary = entry["m"]
			if m.has("cap_stages") or m.has("cap_life"):
				# Caps apply at deal time, after every add and the multiplier; the lowest wins.
				if m.has("cap_stages") and (cap_stages < 0 or int(m["cap_stages"]) < cap_stages):
					cap_stages = int(m["cap_stages"])
				if m.has("cap_life") and (cap_life < 0 or int(m["cap_life"]) < cap_life):
					cap_life = int(m["cap_life"])
				cap_sources.append(_modifier_source(entry, defender))
				continue
			var ms: int = _modifier_amount(m, "stages", defender)
			var ml: int = _modifier_amount(m, "life", defender)
			if ms != 0 or ml != 0:
				adds.append({"source": _modifier_source(entry, defender), "stages": -ms, "life": -ml})
	var stages: int = base_stages
	var life: int = base_life
	for add in adds:
		stages += int(add["stages"])
		life += int(add["life"])
	if multiply > 1:
		adds.append({"source": multiply_source, "stages": 0, "life": 0, "multiply": multiply})
		stages *= multiply
		life *= multiply
	if kind == "art" and _prevention_float(defender.index, "prevent_art_life", a) and not no_prevent:
		adds.append({"source": "Art wounds prevented", "stages": 0, "life": -life})
		life = 0
	# "Prevent all damage from any physical attack during your opponent's next attack phase":
	# both the Energy and the wounds, since a Strike can carry either.
	if kind == "strike" and _prevention_float(defender.index, "prevent_strike_damage", a) and not no_prevent:
		adds.append({"source": "Strike damage prevented", "stages": -stages, "life": -life})
		stages = 0
		life = 0
	# Wounds bought off for this one attack, by a Mastery that spends the discard pile instead of
	# a block. Lives on the attack, so it cannot leak into the next one.
	var first: Dictionary = a.get("prevent_first", {})
	if not first.is_empty() and not no_prevent:
		var off_stages: int = mini(maxi(0, stages), int(first.get("stages", 0)))
		var off_life: int = mini(maxi(0, life), int(first.get("life", 0)))
		if off_stages > 0 or off_life > 0:
			var from_card: CardInstance = card(int(first.get("source", -1)))
			adds.append({"source": from_card.def.title if from_card != null else "Prevented", "stages": -off_stages, "life": -off_life})
			stages -= off_stages
			life -= off_life
	var bought: int = int(a.get("prevent_life", 0))
	if bought > 0 and life > 0 and not no_prevent:
		var stopped_life: int = mini(life, bought)
		adds.append({"source": "Wounds prevented", "stages": 0, "life": -stopped_life})
		life -= stopped_life
	if cap_stages >= 0 and stages > cap_stages:
		adds.append({"source": ", ".join(cap_sources), "stages": 0, "life": 0, "cap_stages": cap_stages})
		stages = cap_stages
	if cap_life >= 0 and life > cap_life:
		adds.append({"source": ", ".join(cap_sources), "stages": 0, "life": 0, "cap_life": cap_life})
		life = cap_life
	if prevented:
		stages = 0
		life = 0
	return {
		"kind": kind, "wild": wild, "printed": printed, "table": table,
		"attacker_might": ac.might(), "defender_might": dc.might(),
		"attacker_band": strike_table.band(ac.might()), "defender_band": strike_table.band(dc.might()),
		"base_stages": base_stages, "base_life": base_life, "adds": adds, "prevented": prevented,
		"no_reduce": no_reduce, "stages": maxi(0, stages), "life": maxi(0, life), "spent": spent,
	}


## The card a modifier belongs to, for the breakdown. A floating modifier names the card whose
## effect set it up; failing that, its owner.
func _modifier_source(entry: Dictionary, p: PlayerState) -> String:
	var c: CardInstance = entry.get("source")
	if c == null:
		c = card(int((entry["m"] as Dictionary).get("source", -1)))
	if c != null:
		return c.def.title
	return "%s's effect" % p.name


func _modifier_amount(m: Dictionary, key: String, p: PlayerState) -> int:
	var n: int = int(m.get(key, 0))
	if bool(m.get("per_ally", false)):
		n *= p.allies().size()
	if bool(m.get("per_personality", false)):
		# "For each personality card you have in play": the duelist counts, so this is never 0.
		n *= p.allies().size() + 1
	if str(m.get("per_bloodline", "")) != "":
		n *= bloodline_count(p, str(m["per_bloodline"]))
	# "+X, X = your current Fervor": read as the attack is worked out, so it rises with the climb.
	if bool(m.get("per_fervor", false)):
		n *= p.fervor
	# "X = the times you have used Endurance since you played this card": the count is stamped on
	# the float when it goes up, so earlier uses do not count.
	if m.has("endurance_mark"):
		n *= maxi(0, p.endurance_uses - int(m["endurance_mark"]))
	return n


## Personalities in play on either side carrying a tag, the way a card that counts by what a
## personality *is* rather than by who owns it reads. Duelists and Allies both count.
func tag_count(tag: String) -> int:
	var n: int = 0
	for p in state.players:
		if has_tag(p.duelist, tag):
			n += 1
		for a in p.allies():
			if has_tag(a, tag):
				n += 1
	return n


## A keyword this personality carries right now: printed on their card, or lent to them by a card
## attached to them. The source's mark works the second way, so a personality can gain a keyword
## mid-duel and lose it again when the card leaves. Never read `tags` off the def to answer this.
func has_tag(c: CardInstance, tag: String) -> bool:
	if c == null:
		return false
	if (c.def.raw.get("tags", []) as Array).has(tag):
		return true
	for at in _attachments_on(c):
		if (at.def.attachment.get("grants_tags", []) as Array).has(tag):
			return true
	return false


## Every keyword the personality carries right now, printed and lent, for a seat view to show.
func tags_of(c: CardInstance) -> Array[String]:
	var out: Array[String] = []
	if c == null:
		return out
	for t in c.def.raw.get("tags", []):
		out.append(str(t))
	for at in _attachments_on(c):
		for t in at.def.attachment.get("grants_tags", []):
			if not out.has(str(t)):
				out.append(str(t))
	return out


## The line this personality counts as carrying right now. Printed unless a card attached to them
## says otherwise, the same way a keyword can be lent.
func bloodline_of(c: CardInstance) -> String:
	if c == null:
		return ""
	for at in _attachments_on(c):
		var lent: String = str(at.def.attachment.get("grants_bloodline", ""))
		if lent != "":
			return lent
	return c.def.bloodline


## Cards in play riding on this personality, from either side: an attachment is played by its
## owner but may sit on anybody.
func _attachments_on(c: CardInstance) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	if c == null:
		return out
	for p in state.players:
		for at in p.attachments():
			if at.attached_to == c:
				out.append(at)
	return out


## How many cards this player may hold through the discard step. One by default; a card in play
## that raises the limit replaces that number rather than adding to it, and the most generous wins.
func _hand_keep(p: PlayerState) -> int:
	var keep: int = HAND_KEEP
	var sources: Array[CardInstance] = []
	if not _forbidden(p, "drills"):
		sources.append_array(_active(p.drills()))
	sources.append_array(_active(p.non_combats()))
	if p.mastery != null and not _forbidden(p, "mastery"):
		sources.append(p.mastery)
	for c in sources:
		keep = maxi(keep, int(c.def.raw.get("hand_keep", 0)))
	return keep


## The first card with this title anywhere in play, on either side; null when nobody has one out.
## Matched by title because that is how the card names it, and how its own text reads it back.
func card_in_play_titled(title: String) -> CardInstance:
	for p in state.players:
		for c in p.in_play:
			if c.def.title == title:
				return c
	return null


## Personalities in play carrying a bloodline: the duelist when it is theirs, plus each Ally with
## it. A duelist can lead a following that does not share their blood, and often does.
func bloodline_count(p: PlayerState, bloodline: String) -> int:
	var n: int = 1 if bloodline_of(p.duelist) == bloodline else 0
	for a in p.allies():
		if bloodline_of(a) == bloodline:
			n += 1
	return n


## Modifiers from Drills, Mastery, Grounds, attachments, floating effects, and constant powers,
## each as {m: the modifier, source: the card it sits on, null for a floating effect}.
func _modifiers_for(p: PlayerState, scope: String, kind: String, src: CardInstance, ctx: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var pools: Array = []
	# "Your opponent cannot use his Mastery card and Drills": a forbidden Drill's standing text is
	# off as well as its uses, the way a forbidden Mastery's is.
	if not _forbidden(p, "drills"):
		for d in _active(p.drills()):
			pools.append([d.def.modifiers, d])
	if p.mastery != null and not _forbidden(p, "mastery"):
		pools.append([p.mastery.def.modifiers, p.mastery])
	if state.grounds != null:
		pools.append([state.grounds.def.modifiers, state.grounds])
	for at in p.attachments():
		# A rider only speaks for the personality it rides on, for damage and for price alike.
		if (scope == "own" or scope == "cost") and at.attached_to == p.in_control():
			pools.append([at.def.attachment.get("modifiers", []), at])
	# "While attached, all attacks performed by that personality do -2 power stages": a hex the
	# other side laid on this personality, read as this side's own modifier.
	if scope == "own":
		for at in state.players[1 - p.index].attachments():
			if at.attached_to == p.in_control() and at.def.attachment.has("host_modifiers"):
				pools.append([at.def.attachment.get("host_modifiers", []), at])
	var constant: Dictionary = _constant(p)
	if constant.has("modifiers"):
		pools.append([constant.get("modifiers", []), p.duelist])
	for f in state.floating:
		if int(f.get("owner", -1)) == p.index and str(f.get("op", "")) == "modifier":
			# A modifier that excluded the attack it came from stays out of that attack's sums.
			if f.has("from_phase") and int(f["from_phase"]) == state.attack_phase_count:
				continue
			pools.append([[f], null])
	for pool in pools:
		for m in pool[0]:
			var mk: String = str(m.get("kind", "any"))
			if str(m.get("scope", "own")) != scope:
				continue
			if not (mk == "any" or mk == kind):
				continue
			if m.has("school") and (src == null or src.def.school != str(m["school"])):
				continue
			if m.has("title_contains") and not _title_matches(p.index, src, str(m["title_contains"])):
				continue
			# "All of your marked attacks do +3 Energy": reads the keyword the card itself carries.
			if m.has("tag") and (src == null or not has_tag(src, str(m["tag"]))):
				continue
			# "All marked-only attacks do +1": reads the card's play gate instead, which is a
			# different set. A card can be gated on the mark without being one of its cards.
			if m.has("only_tag") and (src == null or str((src.def.only as Dictionary).get("tag", "")) != str(m["only_tag"])):
				continue
			if m.has("when") and not _cond(m["when"], p.index, ctx):
				continue
			out.append({"m": m, "source": pool[1]})
	return out


func _deal_stage_damage(defender: PlayerState, a: Dictionary) -> void:
	var target: CardInstance = card(int(a["target"]))
	var stages: int = int(a["stages"])
	var lost: int = mini(target.energy, stages)
	target.energy -= lost
	var overflow: int = stages - lost
	a["stages_dealt"] = lost
	a["life_remaining"] = int(a["life"]) + overflow
	if stages > 0:
		_emit(&"damage_stages", {"player": defender.index, "target": target.uid, "stages": lost, "overflow": overflow, "energy": target.energy})


## Step 13. Flips one life card at a time; pauses on an Endurance prompt and resumes here.
func _deal_life_damage(defender: PlayerState, a: Dictionary) -> void:
	while int(a["life_remaining"]) > 0:
		if defender.life_deck.is_empty() or _only_seals_left(defender):
			_lose(defender.index, "survival")
			if state.is_over():
				return
			# The hit that cost a point ends there; what it had left does not reach the new deck.
			a["life_remaining"] = 0
			break
		var c: CardInstance = _flip_life_card(defender)
		if c == null:
			return
		if c.def.type == CardDef.Type.SEAL:
			_bypass_seal(c)
			continue
		# The wound event below is the one the client animates; the move itself stays quiet so a
		# lost life card flies once, not twice.
		if bool(a["damage_removes"]) or _has_floating(int(a["attacker"]), "damage_removes"):
			_remove_from_game(c, true)
		else:
			_move_to_discard(c, true)
		_on_wound(defender, c)
		a["life_remaining"] = int(a["life_remaining"]) - 1
		a["life_dealt"] = int(a["life_dealt"]) + 1
		_emit(&"life_card_flipped", {"player": defender.index, "card": c.uid, "id": c.def.id, "remaining": a["life_remaining"]})
		var endurance: int = _endurance_value(c, defender)
		if endurance > 0 and int(a["life_remaining"]) > 0 and not bool(a["no_prevent"]) and not _has_floating(int(a["attacker"]), "no_prevent") and not _endurance_barred(defender, a) and not _endurance_banned_by_type(c, a):
			var opts: Array[Command] = [Command.new(defender.index, &"endure", c.uid), Command.new(defender.index, &"no_endure", c.uid)]
			_set_prompt(defender.index, &"endurance", opts, {"card": c.uid, "endurance": endurance, "remaining": a["life_remaining"]})
			return
	state.battle_step = 14


## A standing prevention on the defender that still applies to this attack. "Cannot be prevented by
## Physical Combat cards" (`no_prevent_by` on the attack) sets aside one put out by a card of that
## type, and leaves every other prevention alone.
func _prevention_float(defender_index: int, op: String, a: Dictionary) -> bool:
	var banned: int = int(CardDef.TYPE_NAMES.get(str(a.get("no_prevent_by", "")), -1))
	for f in state.floating:
		if int(f.get("owner", -1)) != defender_index or str(f.get("op", "")) != op or not _phase_float_live(f):
			continue
		var from_card: CardInstance = card(int(f.get("source", -1)))
		if banned >= 0 and from_card != null and from_card.def.type == banned:
			continue
		return true
	return false


## Whether Endurance on this life card may be used against this attack at all. `no_prevent_by`
## bars Endurance printed on a card of that type, since using it is that card preventing damage.
func _endurance_banned_by_type(c: CardInstance, a: Dictionary) -> bool:
	var banned: int = int(CardDef.TYPE_NAMES.get(str(a.get("no_prevent_by", "")), -1))
	return banned >= 0 and c.def.type == banned


## A standing "your opponent cannot use Endurance" sits on the defender. One that names a school
## ("against your Pyre attacks") only bars it when the attack comes off a card of that school.
func _endurance_barred(defender: PlayerState, a: Dictionary) -> bool:
	var src: CardInstance = card(int(a.get("source", -1)))
	return _has_floating_school(defender.index, "no_endurance", src.def.school if src != null else "")


func _endurance_value(c: CardInstance, p: PlayerState) -> int:
	# "Endurance X, X = your current Fervor": the owner's, read as the card is turned over.
	if str(c.def.raw.get("endurance_from", "")) == "fervor":
		return p.fervor
	if not c.def.endurance_when.is_empty():
		var ew: Dictionary = c.def.endurance_when
		if _cond(ew.get("value_if", {}), p.index, {}):
			return int(ew.get("then", c.def.endurance))
		return int(ew.get("else", c.def.endurance))
	return c.def.endurance


func _handle_endurance(cmd: Command, context: Dictionary) -> void:
	if cmd.type == &"endure":
		var c: CardInstance = card(cmd.card)
		var prevented: int = mini(int(context["endurance"]), int(state.attack["life_remaining"]))
		var boost: Dictionary = _floating_first(cmd.player, "endurance_boost")
		if not boost.is_empty():
			prevented = int(state.attack["life_remaining"])
			state.floating.erase(boost)
		state.attack["life_remaining"] = int(state.attack["life_remaining"]) - prevented
		state.attack["endurance_prevented"] = int(state.attack.get("endurance_prevented", 0)) + prevented
		_remove_from_game(c)
		_emit(&"endurance_used", {"player": cmd.player, "card": c.uid, "prevented": prevented})
		var user: PlayerState = state.players[cmd.player]
		user.endurance_uses += 1
		# "For the remainder of Combat, when you use Endurance, your Main Personality gains 1 power
		# stage": one per card that put the rule out.
		for f in state.floating:
			if int(f.get("owner", -1)) == cmd.player and str(f.get("op", "")) == "endurance_energy":
				var before: int = user.duelist.energy
				_gain_energy_from_card(user, user.duelist, maxi(1, int(f.get("energy", 1))))
				if user.duelist.energy != before:
					_emit(&"energy_changed", {"player": cmd.player, "card": user.duelist.uid, "from": before, "to": user.duelist.energy, "source": int(f.get("source", -1))})
	else:
		# Turning Endurance down is a decision both players watched being made, so it is an
		# outcome like any other rather than silence.
		_emit(&"endurance_declined", {
			"player": cmd.player, "card": cmd.card, "endurance": int(context.get("endurance", 0)),
			"remaining": int(state.attack.get("life_remaining", 0)),
		})
	# battle_step stays 13; the loop resumes.


func _handle_critical(cmd: Command) -> void:
	var opp: PlayerState = state.players[1 - cmd.player]
	match cmd.type:
		&"capture":
			state.attack["critical"] = "capture"
			_capture_seal(cmd.player, card(cmd.card))
		&"discard_ally":
			state.attack["critical"] = "ally"
			_emit(&"critical_ally", {"player": cmd.player, "card": cmd.card})
			_discard_or_remove_in_play(card(cmd.card), false)
		&"lower_fervor":
			state.attack["critical"] = "fervor"
			_emit(&"critical_fervor", {"player": cmd.player})
			# Passed as the rival's own change: a game rule, so the Relic's Fervor shield (card effects only) does not apply.
			_change_fervor(opp, -1, opp.index)


## Battle step 11: the capturing Ally takes a Seal and the attack deals nothing.
func _handle_capture_instead(cmd: Command) -> void:
	if cmd.type != &"capture":
		return
	var a: Dictionary = state.attack
	a["stages"] = 0
	a["life"] = 0
	a["life_remaining"] = 0
	a["captured_instead"] = true
	_emit(&"capture_instead", {"player": cmd.player, "card": cmd.card})
	_capture_seal(cmd.player, card(cmd.card))


## "Use immediately after a physical attack you perform becomes successful." Offered once per
## attack, to the attacker, for cards in hand that name this timing and match the attack's kind.
## The three optional "use one card now" windows answer here: the attacker's after a successful
## attack, the defender's after taking damage, and either player's as Combat is entered. The
## attacker's takes the place of an action and hands the phase over; the other two are asked in the
## middle of a step and must leave it where it was.
func _handle_follow_up(cmd: Command, context: Dictionary) -> void:
	var window: String = str(context.get("window", ""))
	if window == "attack_boost":
		if cmd.type != &"use":
			state.attack["boost_done"] = true
		else:
			_apply_attack_boost(state.players[cmd.player], card(cmd.card))
		return
	if cmd.type != &"use":
		if window == "entering_combat":
			state.players[cmd.player].entering_combat_done = true
		return
	_use_card(state.players[cmd.player], card(cmd.card), window == "")


## "When you perform a physical attack you may discard this card from your hand to have that attack
## do an additional +4 power stages of damage and raise your anger 1 level." Offered as the attack
## is performed, once its costs are paid and before its own text resolves, and again after each
## card spent, so two copies may both go. Declining closes it for this attack.
func _prompt_attack_boost(attacker: PlayerState, a: Dictionary) -> bool:
	if bool(a.get("boost_done", false)):
		return false
	var opts: Array[Command] = []
	for c in attacker.hand:
		var boost: Dictionary = c.def.raw.get("discard_boost", {})
		if boost.is_empty():
			continue
		var wants: String = str(boost.get("kind", ""))
		if wants == "" or wants == str(a["kind"]):
			opts.append(Command.new(attacker.index, &"use", c.uid))
	if opts.is_empty():
		a["boost_done"] = true
		return false
	opts.append(Command.new(attacker.index, &"decline"))
	_set_prompt(attacker.index, &"follow_up", opts, {"window": "attack_boost", "source": int(a.get("source", -1))})
	return true


func _apply_attack_boost(p: PlayerState, c: CardInstance) -> void:
	var a: Dictionary = state.attack
	var boost: Dictionary = c.def.raw.get("discard_boost", {})
	_move_to_discard(c)
	_emit(&"hand_discarded", {"player": p.index, "card": c.uid, "random": false})
	a["extra_stages"] = int(a.get("extra_stages", 0)) + int(boost.get("stages", 0))
	a["extra_life"] = int(a.get("extra_life", 0)) + int(boost.get("life", 0))
	a["extra_source"] = c.def.title
	_enqueue(boost.get("effects", []), "secondary", p.index, {"attack": a}, c)


## "Use when performing an attack": cards in the attacker's hand that name this timing, offered
## once per attack, after it has connected and before any of its damage is worked out. It reuses
## the `follow_up` prompt kind; the window name keeps the phase from advancing, because the attack
## itself is the action.
func _prompt_performing_attack(attacker: PlayerState, a: Dictionary) -> bool:
	if bool(a.get("performing_done", false)):
		return false
	a["performing_done"] = true
	var opts: Array[Command] = []
	for c in attacker.hand:
		if str(c.def.raw.get("use_at", "")) != "performing_attack" or not _can_play(attacker, c.def):
			continue
		if not _band_forbidden(attacker, c.def):
			opts.append(Command.new(attacker.index, &"use", c.uid))
	if opts.is_empty():
		return false
	opts.append(Command.new(attacker.index, &"decline"))
	_set_prompt(attacker.index, &"follow_up", opts, {"window": "performing_attack", "source": int(a.get("source", -1))})
	return true


func _prompt_follow_up(attacker: PlayerState, a: Dictionary) -> bool:
	if bool(a.get("follow_up_done", false)):
		return false
	a["follow_up_done"] = true
	var opts: Array[Command] = []
	for c in attacker.hand:
		if str(c.def.raw.get("use_at", "")) != "own_successful_attack":
			continue
		var wants: String = str(c.def.raw.get("use_after_kind", ""))
		if wants != "" and wants != str(a["kind"]):
			continue
		if not _can_play(attacker, c.def):
			continue
		# A follow-up is still a card of its printed band, so whatever shuts that band off
		# shuts this off too.
		var banned: String = "combat_cards"
		if c.def.type == CardDef.Type.STRIKE:
			banned = "strike_cards"
		elif c.def.type == CardDef.Type.ART:
			banned = "art_cards"
		if not _forbidden(attacker, banned):
			opts.append(Command.new(attacker.index, &"use", c.uid))
	if opts.is_empty():
		return false
	opts.append(Command.new(attacker.index, &"decline"))
	_set_prompt(attacker.index, &"follow_up", opts, {"source": int(a.get("source", -1))})
	return true


## The cards a standing ransom would spend, empty when it cannot be paid or there is nothing left
## to take with it. The Reserve is a real zone here: cards leave it for good.
func _ransom_options(p: PlayerState) -> Array[CardInstance]:
	var f: Dictionary = _floating_first(p.index, "reserve_ransom")
	if f.is_empty():
		return []
	var params: Dictionary = f.get("params", {})
	var cost: int = maxi(1, int(params.get("cost", 2)))
	if p.reserve.size() < cost:
		return []
	var opp: PlayerState = state.players[1 - p.index]
	if _in_play_candidates(opp, str(params.get("card_type", "drill"))).is_empty():
		return []
	return p.reserve.slice(0, cost)


func _handle_ransom(cmd: Command) -> void:
	var p: PlayerState = state.players[cmd.player]
	var f: Dictionary = _floating_first(p.index, "reserve_ransom")
	var params: Dictionary = f.get("params", {})
	var spent: Array[CardInstance] = _ransom_options(p)
	if spent.is_empty():
		return
	for c in spent:
		p.reserve.erase(c)
		c.zone = &"removed"
		p.removed.append(c)
		_emit(&"reserve_removed", {"player": p.index, "card": c.uid})
	_apply_effect({"op": "discard_in_play", "who": "opponent",
		"card_type": str(params.get("card_type", "drill")), "amount": 1, "choose": true,
		"remove": true}, p.index, {}, null)


## "You may reduce the damage this attack deals by any amount to a minimum of 0. For every life
## card of damage reduced this way, discard one of your opponent's Drills in play." Offered once
## per attack, capped by the wounds in hand and by how many of their cards there are to take.
func _prompt_damage_trade(attacker: PlayerState, defender: PlayerState, a: Dictionary) -> bool:
	var trade: Dictionary = (a["spec"] as Dictionary).get("damage_trade", {})
	if trade.is_empty() or bool(a.get("trade_done", false)):
		return false
	a["trade_done"] = true
	var per: int = maxi(1, int(trade.get("per", 1)))
	var cands: Array[CardInstance] = _in_play_candidates(defender, str(trade.get("card_type", "drill")))
	var most: int = mini(int(a["life"]) / per, cands.size())
	if most < 1:
		return false
	var opts: Array[Command] = []
	for n in range(most + 1):
		opts.append(Command.new(attacker.index, &"trade_damage", -1, n))
	_set_prompt(attacker.index, &"trade_damage", opts,
		{"per": per, "source": int(a.get("source", -1)), "card_type": str(trade.get("card_type", "drill"))})
	return true


func _handle_trade_damage(cmd: Command) -> void:
	var a: Dictionary = state.attack
	var trade: Dictionary = (a["spec"] as Dictionary).get("damage_trade", {})
	var n: int = int(cmd.value)
	if n <= 0:
		return
	var per: int = maxi(1, int(trade.get("per", 1)))
	a["life"] = maxi(0, int(a["life"]) - n * per)
	_emit(&"damage_traded", {"player": cmd.player, "life": n * per, "cards": n})
	var defender: PlayerState = state.players[1 - cmd.player]
	_apply_effect({"op": "discard_in_play", "who": "opponent",
		"card_type": str(trade.get("card_type", "drill")), "amount": n, "choose": true,
		"remove": bool(trade.get("remove", false))}, cmd.player, {"attack": a}, _attack_source())


func _finish_attack(attacker: PlayerState, a: Dictionary) -> void:
	if bool(a["stopped"]):
		_enqueue(a["effects"], "if_stopped", attacker.index, {"attack": a}, _attack_source())
		# "If your opponent stops one of your Pyre Arts, they discard the top 2 cards of their Life
		# Deck." The Mastery answers the stop, whichever card was blocked.
		if attacker.mastery != null and not _forbidden(attacker, "mastery"):
			_enqueue(attacker.mastery.def.effects, "on_stopped", attacker.index, {"attack": a}, attacker.mastery)
		# "Whenever you stop an attack, you may ...": the defender's Drills, whatever did the stopping.
		var stopper: PlayerState = state.players[1 - attacker.index]
		if not _forbidden(stopper, "drills"):
			for dr in _active(stopper.drills()):
				if dr.def.has_trigger("on_stop"):
					_enqueue(dr.def.effects, "on_stop", stopper.index, {"attack": a}, dr)
	var src: CardInstance = _attack_source()
	if src != null and not bool(a["is_power"]):
		# "Remove from the game after use" is text after Empower too, so a card whose Empower keeps
		# its text is removed like any other.
		var dropped_text: bool = bool(a["empowered"]) and not _has_floating(attacker.index, "empower_keeps_text")
		_enqueue([{"trigger": "secondary", "op": "finish_source", "empowered": dropped_text}], "secondary", attacker.index, {"attack": a}, src)
	# A Drill that answers "after performing a successful attack" waits for the attack to be over,
	# its card already gone wherever it goes after use, so that card can be what the Drill reaches
	# for. A `once_per_combat` one spends itself with a `mark_used` line in its own text, so
	# declining an optional answer does not cost it.
	if not bool(a["stopped"]) and not _forbidden(attacker, "drills"):
		for dr in _active(attacker.drills()):
			if dr.def.has_trigger("on_success") and _drill_use_available(dr):
				_enqueue(dr.def.effects, "on_success", attacker.index, {"attack": a}, dr)
	if bool(a["is_final"]):
		attacker.must_pass = true
	# The outcome outlives `state.attack`, which the after_attack op clears before the next prompt.
	var stopped_by: Dictionary = a.get("stopped_by", {})
	# The titles are taken now, while the cards are still on the table. Read later off the card they
	# would drift, because the source may be back in a hidden zone by then and a simulation gives a
	# hidden card a different identity.
	# "Use only after you have taken 5 or more wounds from a single attack this Combat": the biggest
	# single hit is kept on the side that took it, and cleared with the rest of the Combat flags.
	var wounded: PlayerState = state.players[int(a.get("defender", 1 - attacker.index))]
	wounded.worst_wound_combat = maxi(wounded.worst_wound_combat, int(a["life_dealt"]))
	var src_card: CardInstance = card(int(a.get("source", -1)))
	var perf_card: CardInstance = card(int(a.get("performer", -1)))
	var tgt_card: CardInstance = card(int(a.get("target", -1)))
	state.last_attack = {
		"attacker": attacker.index,
		"kind": str(a["kind"]),
		"source": int(a.get("source", -1)),
		"source_title": src_card.def.title if src_card != null else "",
		"performer_title": perf_card.def.title if perf_card != null else "",
		"target_title": tgt_card.def.title if tgt_card != null else "",
		"performer": int(a.get("performer", -1)),
		"is_power": bool(a["is_power"]),
		"is_final": bool(a["is_final"]),
		"stopped": bool(a["stopped"]),
		"stopped_by": stopped_by,
		# Taken now, like the other three titles: by the time a client reads this the defence may
		# be back in a hidden zone, where a simulation would have given it another identity.
		"stopped_by_title": SeatView.stopper_title(self, stopped_by),
		"stages_dealt": int(a["stages_dealt"]),
		"life_dealt": int(a["life_dealt"]),
		"target": int(a.get("target", -1)),
		"endurance_prevented": int(a.get("endurance_prevented", 0)),
		"critical": str(a.get("critical", "")),
	}
	_emit(&"attack_end", {
		"player": attacker.index, "kind": str(a["kind"]), "source": int(a.get("source", -1)),
		"is_power": bool(a["is_power"]), "is_final": bool(a["is_final"]),
		"stopped": a["stopped"], "stopped_by": stopped_by,
		"stages_dealt": a["stages_dealt"], "life_dealt": a["life_dealt"],
		"endurance_prevented": int(a.get("endurance_prevented", 0)),
	})
	_enqueue([{"trigger": "secondary", "op": "after_attack"}], "secondary", attacker.index, {}, null)
	state.battle_step = 0


# --- Effect queue ---------------------------------------------------------

## A constant power's keyed list (`on_attack`, `turn_start`, `entering_combat`) is all one
## trigger: the key says when, so each line is stamped with it before it is queued.
func _enqueue_keyed(effects: Array, trigger: String, owner: int, ctx: Dictionary, source: CardInstance) -> void:
	var stamped: Array[Dictionary] = []
	for e in effects:
		if e is Dictionary:
			var e2: Dictionary = (e as Dictionary).duplicate(true)
			e2["trigger"] = trigger
			stamped.append(e2)
	_enqueue(stamped, trigger, owner, ctx, source)


func _enqueue(effects: Array, trigger: String, owner: int, ctx: Dictionary, source: CardInstance) -> void:
	var list: Array[Dictionary] = []
	for e in effects:
		if e is Dictionary and str(e.get("trigger", "secondary")) == trigger:
			list.append(e)
	if list.is_empty():
		return
	_queue.append({"effects": list, "index": 0, "trigger": trigger, "owner": owner, "ctx": ctx, "source": source})


func _drain() -> void:
	while not _queue.is_empty() and prompt == null and not state.is_over():
		var job: Dictionary = _queue[0]
		var effects: Array[Dictionary] = job["effects"]
		while int(job["index"]) < effects.size():
			var e: Dictionary = effects[int(job["index"])]
			job["index"] = int(job["index"]) + 1
			if e.has("when") and not _cond(e["when"], int(job["owner"]), job["ctx"]):
				continue
			_announce(job)
			if bool(e.get("may", false)) and not bool(e.get("_confirmed", false)):
				_prompt_may(e, int(job["owner"]), job["ctx"], job["source"])
				return
			_pending_then = {}
			if e.has("then"):
				_pending_then = {"effects": e["then"], "owner": int(job["owner"]), "ctx": job["ctx"], "source": job["source"]}
			_apply_effect(e, int(job["owner"]), job["ctx"], job["source"])
			if prompt != null or state.is_over():
				return
			if _flush_then():
				break
		if not _queue.is_empty() and _queue[0] == job:
			_queue.pop_front()
	# An answered Ascension win: the answer has now resolved, so ask the question again.
	if _queue.is_empty() and prompt == null and not state.is_over() and state.pending_ascension >= 0:
		var waiting: int = state.pending_ascension
		state.pending_ascension = -1
		_check_aspect_up(state.players[waiting])


## "You may ..." lines ask their owner first; a yes re-queues the effect as confirmed.
func _prompt_may(e: Dictionary, owner: int, ctx: Dictionary, source: CardInstance) -> void:
	# A discard from a hand that holds nothing it could discard is not a choice anyone can make:
	# "unless your opponent discards a card from his hand" with an empty hand goes to the other half.
	if str(e.get("op", "")) == "discard_hand":
		var from_hand: PlayerState = state.players[_who_index(str(e.get("who", "self")), owner)]
		if _hand_filtered(from_hand, e.get("filter", "")).is_empty():
			if e.has("otherwise"):
				var other: Array[Dictionary] = []
				other.assign(e["otherwise"])
				_queue.insert(0, {"effects": other, "index": 0, "trigger": "then", "owner": owner, "ctx": ctx, "source": source, "announced": true})
			return
	# `asks` hands the decision across the table, for "unless your opponent discards a card, ...".
	# The effect still belongs to `owner`; only the question moves.
	var asked: int = 1 - owner if str(e.get("asks", "")) == "opponent" else owner
	var opts: Array[Command] = [Command.new(asked, &"pick_option", -1, "yes"), Command.new(asked, &"pick_option", -1, "no")]
	_choice = {"kind": "may", "effect": e, "owner": owner, "ctx": ctx, "source": source.uid if source != null else -1}
	# The prompt carries what a yes does and which card asks, so the client can show both.
	var context: Dictionary = {"may": true, "op": str(e.get("op", "")), "text": CardText.may_text(e),
		"yes_label": CardText.may_action(e), "no_label": CardText.may_decline(e)}
	if source != null:
		context["source"] = source.uid
		context["card_title"] = source.def.title
	_set_prompt(asked, &"pick_option", opts, context)


## The looked-at cards go back in the order their owner picks: each pick is the next one from
## the looked-at end of the deck (the top, or the bottom). The last card needs no choice.
## `deck_of` is the deck being put back in order, which is the opponent's for a card that looks
## across the table. The prompt still belongs to the looker, so only they learn the order.
func _prompt_rearrange(p: PlayerState, uids: Array[int], from: String, placed: int = 0, deck_of: PlayerState = null) -> void:
	var d: PlayerState = deck_of if deck_of != null else p
	var left: Array[int] = []
	for uid in uids:
		var c: CardInstance = card(uid)
		if c != null and c.zone == &"life_deck":
			left.append(uid)
	if left.size() <= 1:
		# The last card needs no choice, but it still takes the next place at that end: the cards
		# may be coming from the other end of the deck ("the rest go on top").
		if left.size() == 1:
			_place_rearranged(d, card(left[0]), from, placed)
		_emit(&"rearranged", {"player": p.index, "count": placed + left.size()})
		return
	var opts: Array[Command] = []
	for uid in left:
		opts.append(Command.new(p.index, &"pick_option", uid))
	_choice = {"kind": "rearrange", "player": p.index, "deck": d.index, "uids": left, "from": from, "placed": placed}
	_set_prompt(p.index, &"pick_option", opts, {"rearrange": true, "from": from, "remaining": left.size()})


func _place_rearranged(p: PlayerState, c: CardInstance, from: String, placed: int) -> void:
	p.life_deck.erase(c)
	if from == "top":
		p.life_deck.insert(placed, c)
	else:
		p.life_deck.insert(p.life_deck.size() - placed, c)


## Runs the "then" list of the effect that just finished, ahead of everything else queued.
## Triggers whose firing is already told by another line (the card was played or used), or that
## continue an effect already announced.
const SILENT_TRIGGERS: Array[String] = ["secondary", "use", "relic_use", "opponent_declare", "then", "dev"]


## Logs "<card> triggers <when>" once per job, at the first effect that actually applies, so a
## card whose condition fails stays quiet and one that fires reads as its own line.
func _announce(job: Dictionary) -> void:
	if bool(job.get("announced", false)):
		return
	job["announced"] = true
	var source: CardInstance = job.get("source")
	var trigger: String = str(job.get("trigger", "secondary"))
	if source == null or SILENT_TRIGGERS.has(trigger):
		return
	_emit(&"trigger_fired", {"player": int(job["owner"]), "card": source.uid, "trigger": trigger})


func _flush_then() -> bool:
	if _pending_then.is_empty():
		return false
	var list: Array[Dictionary] = []
	for e in _pending_then.get("effects", []):
		if e is Dictionary:
			list.append(e)
	var owner: int = int(_pending_then.get("owner", 0))
	var ctx: Dictionary = _pending_then.get("ctx", {})
	var source: CardInstance = _pending_then.get("source")
	_pending_then = {}
	if list.is_empty():
		return false
	_queue.insert(0, {"effects": list, "index": 0, "trigger": "then", "owner": owner, "ctx": ctx, "source": source})
	return true


## Who an effect lands on. "self" and "opponent" read from the card's owner; "attacker" and
## "defender" read from the current Combat role instead, so a card either player can use in Combat
## ("the attacker draws 2, the defender gains 5 Energy") lands the same way whoever played it.
func _who_index(who: String, owner: int) -> int:
	match who:
		"attacker":
			return state.attacker
		"defender":
			return 1 - state.attacker
		"self":
			return owner
		_:
			return 1 - owner


func _apply_effect(e: Dictionary, owner: int, ctx: Dictionary, source: CardInstance) -> void:
	var op: String = str(e.get("op", ""))
	var who_index: int = _who_index(str(e.get("who", "self")), owner)
	var who: PlayerState = state.players[who_index]
	var me: PlayerState = state.players[owner]
	var amount: Variant = e.get("amount", e.get("n", 0))
	_effect_source = source
	if op != "finish_source" and op != "after_action" and op != "after_attack" and op != "spend_source":
		_emit(&"effect", {"op": op, "owner": owner, "who": who_index, "amount": amount})
	if bool(e.get("skip_damage", false)) and not state.attack.is_empty():
		state.attack["prevented_all"] = true
	# "Raise your or your opponent's Fervor 1": the side is the user's to pick, so the pick comes
	# first and the effect runs again with `who` settled.
	if bool(e.get("choose_side", false)):
		var sides: Array[Command] = [Command.new(owner, &"pick_option", -1, "self"), Command.new(owner, &"pick_option", -1, "opponent")]
		var settled: Dictionary = e.duplicate(true)
		settled.erase("choose_side")
		_choice = {"kind": "discard_side", "effect": settled, "owner": owner, "ctx": ctx, "source": source.uid if source != null else -1}
		_set_prompt(owner, &"pick_option", sides, _choice_context(source, "choose_side"))
		return
	match op:
		"fervor":
			_change_fervor(who, int(amount), owner)
		"set_fervor":
			_set_fervor(who, int(amount), owner)
		"fervor_needed":
			_change_fervor_needed(who, who.fervor_needed + int(amount))
		"set_fervor_needed":
			_change_fervor_needed(who, int(amount))
		"energy":
			var target: CardInstance = who.in_control()
			var aim: String = str(e.get("target", ""))
			if aim == "duelist":
				target = who.duelist
			elif aim == "last_searched":
				target = card(who.last_searched)
				if target == null or target.zone != &"in_play":
					return
			elif aim == "any":
				# "Raise any personality to their highest Energy": the card does not say whose, so
				# every personality on the table is on the list and the player using it decides.
				var board: Array[CardInstance] = []
				for pl in state.players:
					board.append(pl.duelist)
					board.append_array(pl.allies())
				if board.size() == 1:
					_set_personality_energy(state.players[board[0].owner], board[0], e, amount, source)
					return
				_choice = {"kind": "energy_target", "player": who_index, "effect": e.duplicate(true), "owner": owner, "board": true}
				var board_opts: Array[Command] = []
				for c in board:
					board_opts.append(Command.new(owner, &"pick_option", c.uid))
				_set_prompt(owner, &"pick_option", board_opts, _choice_context(source, "energy_target"))
				return
			elif aim == "all" or aim == "choose":
				# "Raise all of your personalities" / "raise any one of them": the Duelist and every
				# Ally. A choice with only the Duelist to choose from is not worth a prompt.
				var crew: Array[CardInstance] = [who.duelist]
				crew.append_array(who.allies())
				if aim == "all" or crew.size() == 1:
					for c in crew:
						_set_personality_energy(who, c, e, amount, source)
					return
				_choice = {"kind": "energy_target", "player": who_index, "effect": e.duplicate(true), "owner": owner}
				var crew_opts: Array[Command] = []
				for c in crew:
					crew_opts.append(Command.new(who_index, &"pick_option", c.uid))
				_set_prompt(who_index, &"pick_option", crew_opts, _choice_context(source, "energy_target"))
				return
			var before: int = target.energy
			if amount is String and str(amount) == "max":
				if _has_floating(who_index, "no_gain"):
					_emit(&"gain_blocked", {"player": who_index, "card": target.uid, "amount": CardInstance.MAX_STAGE - before})
				else:
					target.energy = CardInstance.MAX_STAGE
			elif int(amount) >= 0:
				_gain_energy_from_card(who, target, int(amount))
			elif bool(e.get("no_overflow", false)):
				target.energy = maxi(0, target.energy + int(amount))
			else:
				_lose_energy(who, target, -int(amount))
			if target.energy != before:
				# Logged with its source, so two effects landing in one update read as two lines.
				_emit(&"energy_changed", {"player": who_index, "card": target.uid, "from": before, "to": target.energy, "source": source.uid if source != null else -1})
			# "Your next attack does +X power stages of damage, X = the power stages you gained by
			# this card, for a maximum of +5": banked for the next attack, not the one in the air.
			var bank: Dictionary = e.get("bank_gain", {})
			var gained: int = target.energy - before
			if not bank.is_empty() and gained > 0:
				var boost: Dictionary = {"scope": "own", "kind": "any", "once": true,
					"stages": mini(gained, int(bank.get("cap", gained))), "source": source.uid if source != null else -1}
				if not state.attack.is_empty():
					boost["from_phase"] = state.attack_phase_count
				_float(who_index, "modifier", "game", boost)
		"draw":
			# "You may draw up to 3 cards": which cards is settled by the deck, so only the count
			# is asked, and none is a legal answer.
			if bool(e.get("up_to", false)) and int(amount) > 1 and not who.life_deck.is_empty():
				var most: int = mini(int(amount), who.life_deck.size())
				var counts: Array[Command] = []
				for k in range(most, 0, -1):
					counts.append(Command.new(who_index, &"pick_option", -1, str(k)))
				counts.append(Command.new(who_index, &"pick_none"))
				_choice = {"kind": "draw_deck_count", "player": who_index}
				_set_prompt(who_index, &"pick_option", counts, _choice_context(source, "draw_count"))
				return
			if str(e.get("from", "top")) == "bottom":
				# "Draw the bottom card of your Life Deck." Nothing is revealed that the draw would not.
				for i in range(int(amount)):
					if who.life_deck.is_empty():
						_lose(who_index, "survival")
						if state.is_over():
							return
					var low: CardInstance = who.life_deck.pop_back()
					low.zone = &"hand"
					who.hand.append(low)
					_emit(&"draw", {"player": who_index, "card": low.uid, "from": "deck_bottom"})
				return
			_draw(who_index, int(amount))
		"draw_until":
			while who.hand.size() < int(amount) and not state.is_over():
				if who.life_deck.is_empty():
					_lose(who_index, "survival")
					if state.is_over():
						return
				_draw(who_index, 1)
		"draw_discard":
			# "Draw up to N cards from the bottom of your discard pile": which cards is settled by
			# the pile, so only the count is asked, and none is a legal answer.
			if bool(e.get("up_to", false)) and not who.discard.is_empty() and int(amount) > 1:
				var most: int = mini(int(amount), who.discard.size())
				var counts: Array[Command] = []
				for k in range(most, 0, -1):
					counts.append(Command.new(owner, &"pick_option", -1, str(k)))
				counts.append(Command.new(owner, &"pick_none"))
				_choice = {"kind": "draw_count", "player": who_index, "effect": e.duplicate(true), "owner": owner, "ctx": ctx, "source": source.uid if source != null else -1}
				_set_prompt(owner, &"pick_option", counts, _choice_context(source, "draw_count"))
				return
			var taken: CardInstance = _draw_discard(who, int(amount), str(e.get("from", "bottom")))
			# `if_school`: the follow-up `effects` run only when the last card drawn is of that school.
			if e.has("if_school") and taken != null and taken.def.school == str(e["if_school"]):
				_enqueue(e.get("effects", []), "secondary", owner, ctx, source)
		"discard_life":
			# A card effect taking cards off the top of a Life Deck, not damage. A card in the
			# loser's hand may answer it, so they get the offer before any card is turned over.
			# "X = 5 minus his anger level", read as the line resolves, never below 0.
			if amount is String and str(amount) == "five_minus_fervor":
				amount = maxi(0, 5 - who.fervor)
			# "Equal to your Main Personality's PUR" and "2 cards for each anger level he is at".
			elif amount is String and str(amount) == "owner_surge":
				amount = surge_of(me)
			elif amount is String and str(amount) == "twice_fervor":
				amount = 2 * who.fervor
			if int(amount) <= 0:
				return
			if _offer_deck_loss_guard(who, int(amount), owner):
				return
			_discard_life(who, int(amount), bool(e.get("remove", false)))
		"discard_hand":
			var chooser: int = owner if str(e.get("chooser", "")) == "owner" else who_index
			var to: String = str(e.get("to", "discard"))
			var filter: Variant = e.get("filter", "")
			var pool: Array[CardInstance] = _hand_filtered(who, filter)
			# "Look at your opponent's hand and discard any Non-Combat cards in it": the card is
			# shown before anything leaves, and nothing about which cards go is a choice.
			if bool(e.get("reveal", false)) and not who.hand.is_empty():
				var shown: Array[int] = []
				for c in who.hand:
					shown.append(c.uid)
				_emit(&"hand_revealed", {"player": who.index, "to": owner, "cards": shown})
			# "Discard until he has 2 or fewer cards in hand" counts what is held, not what is taken.
			var n: int = int(amount)
			if e.has("down_to"):
				n = maxi(0, who.hand.size() - int(e["down_to"]))
			elif bool(e.get("all", false)):
				n = pool.size()
			if pool.is_empty() or n <= 0:
				_pending_then = {}
				# "If your opponent has only Dragon Balls in his hand, he must show you his hand."
				if bool(e.get("reveal_if_none", false)) and not who.hand.is_empty() and not bool(e.get("reveal", false)):
					_show_hand_to(who, owner, source)
					return
			elif bool(e.get("random", true)) and to == "deck_shuffle":
				# "Choose 1 card at random from your opponent's hand and shuffle it into his Life Deck."
				for i in range(mini(n, pool.size())):
					var sent: CardInstance = pool[rng.randi_range(0, pool.size() - 1)]
					pool.erase(sent)
					_move_to_deck_bottom(sent)
					_emit(&"hand_discarded", {"player": who.index, "card": sent.uid, "random": true})
				if shuffle_decks:
					rng.shuffle(who.life_deck)
			elif bool(e.get("all", false)) and to == "discard":
				for c in pool:
					_move_to_discard(c)
					_emit(&"hand_discarded", {"player": who.index, "card": c.uid, "random": false})
			elif bool(e.get("random", true)) and to == "discard":
				for i in range(mini(n, pool.size())):
					var c: CardInstance = pool[rng.randi_range(0, pool.size() - 1)]
					pool.erase(c)
					_move_to_discard(c)
					_emit(&"hand_discarded", {"player": who.index, "card": c.uid, "random": true})
			elif pool.size() == 1 and to == "discard":
				_move_to_discard(pool[0])
				_emit(&"hand_discarded", {"player": who.index, "card": pool[0].uid, "random": false})
			else:
				_prompt_discard_choice(who, n, chooser, to, filter)
		"pay_energy":
			var per: int = maxi(1, int(e.get("per", 1)))
			# "You may choose to have your Main Personality lose any number of power stages."
			var payer: CardInstance = who.duelist if str(e.get("payer", "")) == "duelist" else who.in_control()
			var opts: Array[Command] = []
			var amt: int = 0
			while amt <= payer.energy:
				opts.append(Command.new(who_index, &"pay", -1, amt))
				amt += per
			_pending_then = {}
			if opts.size() <= 1:
				return
			_choice = {"kind": "pay_energy", "per": per, "payer": payer.uid, "then": e.get("then", []), "owner": owner, "ctx": ctx, "source": source.uid if source != null else -1}
			_set_prompt(who_index, &"pay", opts, {"per": per, "source": source.uid if source != null else -1, "card_title": source.def.title if source != null else "", "effect": true})
		"look_at":
			# `whose` names the deck; `who` is still whoever does the looking and deciding.
			_look_at(who, e, state.players[_who_index(str(e.get("whose", "self")), owner)])
		"choose_forbid_type":
			var opts: Array[Command] = []
			for t in ["strike_cards", "art_cards", "combat_cards"]:
				opts.append(Command.new(owner, &"pick_option", -1, t))
			_choice = {"kind": "forbid_type", "target": who_index, "unless_energy_min": int(e.get("unless_energy_min", 0)), "duration": str(e.get("duration", "combat"))}
			_set_prompt(owner, &"pick_option", opts, _choice_context(source, "forbid_type"))
		"focus_attack":
			if not state.attack.is_empty():
				state.attack["focused"] = true
		"end_turn":
			state.skip_discard = true
			_emit(&"flag_set", {"player": owner, "flag": "end_turn", "source": source.uid if source != null else -1})
		"force_declare":
			who.must_declare_combat = true
			_emit(&"flag_set", {"player": who_index, "flag": "must_declare_combat", "source": source.uid if source != null else -1})
		"bond":
			_bond(me, str(e.get("card", "")))
		"return_removed":
			var wanted: int = int(CardDef.TYPE_NAMES.get(str(e.get("card_type", "")), -1))
			var moved: Array[CardInstance] = []
			for c in who.removed:
				if wanted < 0 or c.def.type == wanted:
					moved.append(c)
			for c in moved:
				_move_to_deck_bottom(c)
			if not moved.is_empty() and shuffle_decks:
				rng.shuffle(who.life_deck)
		"set_energy":
			# "Set all of their personalities to N": the Duelist and every Ally, not just whoever
			# holds Combat.
			var crew: Array[CardInstance] = []
			match str(e.get("target", "duelist")):
				"all":
					crew.append(who.duelist)
					crew.append_array(who.allies())
				"duelist":
					crew.append(who.duelist)
				_:
					crew.append(who.in_control())
			# "If their personality in control has more Energy than yours, lower it to match":
			# never a raise, and nothing at all when the user is the one behind.
			var match_mine: bool = amount is String and str(amount) == "match_attacker"
			for target in crew:
				var before: int = target.energy
				if match_mine:
					target.energy = mini(before, me.in_control().energy)
				else:
					target.energy = clampi(int(amount), 0, CardInstance.MAX_STAGE)
				if target.energy != before:
					_emit(&"energy_changed", {"player": who_index, "card": target.uid, "from": before, "to": target.energy, "source": source.uid if source != null else -1})
		"advance_aspect":
			if who.duelist.aspect < who.highest_aspect:
				_aspect_up(who)
		"choose_card_type":
			# "Discard all their Allies or all their Drills": the card names the categories in
			# `choices`, the player picks one, and `effect` then runs with that `card_type`.
			var type_opts: Array[Command] = []
			for t in e.get("choices", []):
				type_opts.append(Command.new(owner, &"pick_option", -1, str(t)))
			_choice = {"kind": "card_type", "effect": e.get("effect", {}), "owner": owner, "ctx": ctx, "source": source.uid if source != null else -1}
			_set_prompt(owner, &"pick_option", type_opts, _choice_context(source, "card_type"))
		"choose_stop_all_kind":
			var opts: Array[Command] = [Command.new(owner, &"pick_option", -1, "strike"), Command.new(owner, &"pick_option", -1, "art")]
			_choice = {"kind": "stop_kind"}
			_set_prompt(owner, &"pick_option", opts, _choice_context(source, "stop_kind"))
		"draw_check":
			if who.life_deck.is_empty():
				_lose(who_index, "survival")
				if state.is_over():
					return
			# `discard: true` checks a life card thrown away instead of one drawn; `else_effects`
			# run when the check misses.
			var discards: bool = bool(e.get("discard", false))
			var drawn: CardInstance = who.life_deck[0]
			if discards:
				_discard_life(who, 1)
			else:
				_draw(who_index, 1)
			var matched: bool = _draw_check_matches(who, drawn, e)
			_emit(&"draw_check", {"player": who_index, "card": drawn.uid, "matched": matched, "discard": discards, "check": str(e.get("check", "school")), "school": str(e.get("school", "")), "source": source.uid if source != null else -1})
			if state.is_over():
				return
			# The follow-up lines may need the card that was checked ("you may show it").
			var checked_ctx: Dictionary = ctx.duplicate()
			checked_ctx["checked"] = drawn.uid
			if matched:
				_enqueue(e.get("effects", []), "secondary", owner, checked_ctx, source)
			elif e.has("else_effects"):
				_enqueue(e.get("else_effects", []), "secondary", owner, checked_ctx, source)
		"reveal_hand":
			# "Show your hand to your opponent": a public moment, not a lasting one. The other seat
			# sees the identities in this event; nothing about the hand stays open afterwards.
			var shown_hand: Array[int] = []
			for c in who.hand:
				shown_hand.append(c.uid)
			_emit(&"hand_revealed", {"player": who.index, "to": _who_index(str(e.get("to", "opponent")), who_index), "cards": shown_hand})
			# "Look at your opponent's hand": the looker is shown the cards, the way a look through a
			# deck is, through a prompt that carries them. There is nothing to choose.
			if bool(e.get("look", false)) and who_index != owner and not who.hand.is_empty():
				_show_hand_to(who, owner, source)
		"remove_hand":
			_discard_hand(who, int(amount), true, true)
		"search":
			_search(who, e)
		"discard_in_play":
			_discard_in_play_effect(who, e, owner)
		"remove_discard":
			# "Choose a player and remove his discard pile": either pile may be the one that goes.
			if bool(e.get("choose_player", false)):
				var sides: Array[Command] = [Command.new(owner, &"pick_option", -1, "opponent"), Command.new(owner, &"pick_option", -1, "self")]
				var without: Dictionary = e.duplicate(true)
				without.erase("choose_player")
				_choice = {"kind": "discard_side", "effect": without, "owner": owner, "ctx": ctx, "source": source.uid if source != null else -1}
				_set_prompt(owner, &"pick_option", sides, _choice_context(source, "discard_side"))
				return
			# "Remove up to N cards in your opponent's discard pile": `choose` puts the pile in
			# front of the chooser rather than taking the top N off the back. `amount: "any"` is
			# the uncapped form, "choose any cards in your discard pile": the whole pile is on
			# offer as one batch and choosing none is a legal answer.
			var unbounded: bool = amount is String and str(amount) == "any"
			var wanted: int = who.discard.size() if unbounded else int(amount)
			if (bool(e.get("choose", false)) or unbounded) and not who.discard.is_empty() and not bool(e.get("all", false)):
				_choice = {"kind": "pick_discard", "target": who_index, "remaining": wanted}
				_prompt_pick_discard(owner, who, wanted, unbounded or bool(e.get("up_to", false)))
				return
			# "Remove the top card of your discard pile to raise your Fervor 1, or 2 if it is a
			# Pyre card": the card that burns decides which branch runs, so it is read first.
			var burned: CardInstance = who.discard.back() if not who.discard.is_empty() else null
			_remove_discard(who, wanted, bool(e.get("all", false)), str(e.get("from", "top")))
			if burned != null and (e.has("effects") or e.has("else_effects")):
				if _draw_check_matches(who, burned, e):
					_enqueue(e.get("effects", []), "secondary", owner, ctx, source)
				else:
					_enqueue(e.get("else_effects", []), "secondary", owner, ctx, source)
		"recur_source":
			# "Remove a card from your discard pile to shuffle this card back into your Life Deck
			# after use." `cost` says which discarded card pays; nothing happens without one.
			var paid: CardInstance = null
			for c in who.discard:
				if c != source and _search_matches(who, c, e.get("cost", {}), "removed"):
					paid = c
					break
			if paid != null and source != null:
				_remove_from_game(paid)
				# The card can be mid-resolution from hand or still sitting in play, so it leaves
				# wherever it is before it joins the Life Deck.
				_erase_from_zone(source)
				source.zone = &"life_deck"
				who.life_deck.append(source)
				if shuffle_decks:
					rng.shuffle(who.life_deck)
				_emit(&"recur_source", {"player": who.index, "card": source.uid, "paid": paid.uid})
		"discard_grounds":
			# The Grounds is one card for the whole table rather than either player's, so it is
			# not reachable through discard_in_play.
			if state.grounds != null:
				var g: CardInstance = state.grounds
				state.grounds = null
				_emit(&"in_play_discarded", {"player": g.controller, "card": g.uid, "removed": false, "to": "discard"})
				_move_to_discard(g)
		"shuffle_discard":
			var count: int = int(amount)
			if str(e.get("per_bloodline", "")) != "":
				count *= bloodline_count(who, str(e["per_bloodline"]))
			elif bool(e.get("per_personality", false)):
				count *= who.allies().size() + 1
			# "Place the bottom 2 cards of your discard pile at the bottom of your Life Deck" puts
			# them where the player can count on them, so that one does not shuffle afterwards.
			_shuffle_discard_into_deck(who, count, bool(e.get("all", false)), str(e.get("from", "top")), str(e.get("school", "")), not bool(e.get("no_shuffle", false)))
		"recover":
			_recover_top(who, int(amount), str(e.get("from", "top")))
		"end_combat":
			if not _forbidden(me, "end_combat"):
				_combat_ending = true
				_emit(&"flag_set", {"player": owner, "flag": "end_combat", "source": source.uid if source != null else -1})
		"pass_next_phase":
			who.pass_next_phase = true
			_emit(&"flag_set", {"player": who_index, "flag": "pass_next_phase", "source": source.uid if source != null else -1})
		"skip_next_attack_phase":
			who.skip_next_attack_phase = true
			_emit(&"flag_set", {"player": who_index, "flag": "skip_next_attack_phase", "source": source.uid if source != null else -1})
		"cannot_declare_combat":
			who.cannot_declare_combat = true
			_emit(&"flag_set", {"player": who_index, "flag": "cannot_declare_combat", "source": source.uid if source != null else -1})
		"stop_all":
			# The float sits on the side it defends. `both` is the older wording "stops all energy
			# attacks for the rest of this Combat", which names no side: the user's own attacks of
			# that kind are stopped as well as the opponent's.
			var guarded: Array[int] = [owner]
			if bool(e.get("both", false)):
				guarded.append(1 - owner)
			for side in guarded:
				_float(side, "stop_all", str(e.get("duration", "combat")), {"kind": str(e.get("kind", "any")), "source": source.uid if source != null else -1})
		"float":
			var params: Dictionary = (e.get("params", {}) as Dictionary).duplicate()
			if source != null:
				params["source"] = source.uid   # so a floating modifier can say which card it came from
			# "All of your OTHER attacks do +N for the remainder of Combat": the attack that puts
			# the effect out is not one of them, and it is still in the air when this line runs,
			# so its attack phase is stamped on the float and skipped while that phase lasts.
			if bool(e.get("exclude_source", false)) and not state.attack.is_empty():
				params["from_phase"] = state.attack_phase_count
			if bool(params.get("per_endurance_since", false)):
				params["endurance_mark"] = who.endurance_uses
			_float(who_index, str(e.get("what", "")), str(e.get("duration", "combat")), params)
		"forbid":
			_float(who_index, "forbid", str(e.get("duration", "combat")), {"what": str(e.get("what", "")), "source": source.uid if source != null else -1})
		"lose_aspect":
			_lose_aspect(who, owner)
		"set_aspect":
			_set_aspect(who, e, owner)
		"no_ascension_win":
			who.no_ascension_win = true
			_emit(&"no_ascension_win", {"player": who_index})
		"attach":
			if source != null and str(e.get("to", "")) == "opponent_non_combat":
				# "Attach to one of your opponent's Non-Combat cards in play": a Drill is one; a card
				# already riding something is not a place to put another. None there, nothing rides.
				var hosts_nc: Array[Command] = []
				for c in state.players[1 - owner].in_play:
					if (c.def.type == CardDef.Type.NON_COMBAT or c.def.type == CardDef.Type.DRILL) and c.attached_to == null:
						hosts_nc.append(Command.new(owner, &"pick_option", c.uid))
				if hosts_nc.size() == 1:
					_attach_to_host(source, me, card(hosts_nc[0].card))
				elif hosts_nc.size() > 1:
					_choice = {"kind": "attach_host", "player": owner, "source": source.uid}
					_set_prompt(owner, &"pick_option", hosts_nc, _choice_context(source, "attach_host"))
				return
			if source != null:
				if str(e.get("to", "")) == "choose" and not me.allies().is_empty():
					# "Attach this card to one of your personalities": the Duelist or any Ally.
					var hosts: Array[Command] = [Command.new(owner, &"pick_option", me.duelist.uid)]
					for al in me.allies():
						hosts.append(Command.new(owner, &"pick_option", al.uid))
					_choice = {"kind": "attach_host", "player": owner, "source": source.uid}
					_set_prompt(owner, &"pick_option", hosts, _choice_context(source, "attach_host"))
					return
				_attach(source, me, str(e.get("to", "in_control")))
		"capture_seal":
			_capture_prompt(me)
		"name_card":
			_prompt_name_card(me, source, e)
		"next_attack_tax":
			_float(who_index, "next_attack_tax", "combat", {"stages": int(amount)})
		"copy_attack":
			pass
		"spend_source":
			if source != null and source.zone == &"in_play" and source.def.type == CardDef.Type.NON_COMBAT:
				_finish_card(source, false)
		"exile_source":
			# "If successful ... remove this card from the game": the card in the air goes now, so
			# the finish that follows finds it gone.
			if source != null and source.zone == &"resolving":
				_remove_from_game(source)
		"cycle_hand":
			# "Shuffle his hand into his Life Deck, and then draw the same number of cards."
			var held: int = who.hand.size()
			for c in who.hand.duplicate():
				_move_to_deck_bottom(c)
			if shuffle_decks:
				rng.shuffle(who.life_deck)
				_emit(&"deck_shuffled", {"player": who.index})
			_draw(who_index, held)
		"show_checked":
			# "You may show it to your opponent": the one card a draw check just turned up.
			var shown: CardInstance = card(int(ctx.get("checked", -1)))
			if shown != null:
				_emit(&"cards_revealed", {"player": owner, "cards": [shown.uid]})
		"reveal_pick":
			# "Reveal the top 3 cards of your Life Deck to all players. Your opponent chooses 1 of
			# those cards. The chosen card is placed into your hand and the other 2 are placed back
			# in any order. If your Main Personality's level is 3 or higher, you choose instead."
			var n_shown: int = mini(maxi(1, int(amount)), who.life_deck.size())
			if n_shown <= 0:
				return
			var laid: Array[int] = []
			for i in range(n_shown):
				laid.append(who.life_deck[i].uid)
			_emit(&"cards_revealed", {"player": who_index, "cards": laid})
			var picker: int = 1 - who_index
			if e.has("self_picks_when") and _cond(e["self_picks_when"], who_index, ctx):
				picker = who_index
			var pick_opts: Array[Command] = []
			for uid in laid:
				pick_opts.append(Command.new(picker, &"pick_option", uid))
			_choice = {"kind": "reveal_pick", "player": who_index, "uids": laid}
			var reveal_ctx: Dictionary = _choice_context(source, "reveal_pick")
			reveal_ctx["library"] = laid
			_set_prompt(picker, &"pick_option", pick_opts, reveal_ctx)
		"shuffle_source":
			# "If successful, shuffle this card into your Life Deck." Only a card still in the air
			# goes, so the finish that follows finds it gone and leaves it where it is.
			if source != null and source.zone == &"resolving":
				var home: PlayerState = state.players[source.owner]
				_move_to_deck_bottom(source)
				if shuffle_decks:
					rng.shuffle(home.life_deck)
					_emit(&"deck_shuffled", {"player": home.index})
		"mark_used":
			# A "once per Combat" that is spent by taking it, not by being offered it. Put this in
			# a `then` so a declined "may" leaves the card still available this Combat.
			if source != null:
				source.power_used_combat = state.combat_count
		"finish_source":
			if source != null and (source.zone == &"resolving"):
				if bool(e.get("bottom", false)) and source.def.remain == 0:
					_move_to_deck_bottom(source)
				else:
					_finish_card(source, bool(e.get("empowered", false)))
		"after_action":
			_after_non_attack_action()
		"after_attack":
			state.attack = {}
			if state.is_over():
				return
			if _combat_ending:
				_begin_combat_end()
			else:
				state.phase = GameState.Phase.FIGHT_BACK
		_:
			push_warning("DuelEngine: unknown effect op '%s'" % op)


# --- Conditions -----------------------------------------------------------

## Evaluates a `when` dictionary. Every key must hold.
func _cond(when: Dictionary, owner: int, ctx: Dictionary) -> bool:
	if when.is_empty():
		return true
	var me: PlayerState = state.players[owner]
	var opp: PlayerState = state.players[1 - owner]
	var a: Dictionary = ctx.get("attack", state.attack)
	for key in when.keys():
		var v: Variant = when[key]
		match str(key):
			"character":
				if me.in_control().def.character != str(v):
					return false
			"duelist_character":
				# A list is "X or Y", which is how a card that names two personalities reads.
				if v is Array:
					if not (v as Array).has(me.duelist.def.character):
						return false
				elif me.duelist.def.character != str(v):
					return false
			"alignment":
				if me.alignment != str(v):
					return false
			"defender_alignment":
				# "If performed against a Pact duelist": the side of the personality the attack is
				# aimed at. An Ally may only be fielded by its own side, so this matches the
				# defending player today; it is read off the personality because that is what the
				# card names.
				var aimed_side: CardInstance = _defender_personality(ctx)
				var side: String = opp.alignment
				if aimed_side != null and aimed_side.def.alignment_only != "":
					side = aimed_side.def.alignment_only
				if side != str(v):
					return false
			"performed_by":
				var by_ally: bool = me.in_control() != me.duelist
				if not a.is_empty() and int(a.get("attacker", -1)) == owner:
					by_ally = _performer(a) != me.duelist
				if (str(v) == "ally") != by_ally:
					return false
			"energy_min":
				if me.in_control().energy < int(v):
					return false
			"duelist_energy_min":
				# "Your Main Personality may pay 1 power stage": the duelist's, whoever holds Combat.
				if me.duelist.energy < int(v):
					return false
			"attack_only_tag":
				# "All marked-only attacks...": reads the gate on the card being performed, not
				# the keyword it carries, which is a different set.
				var performing: CardInstance = card(int(a.get("source", -1)))
				if performing == null or str((performing.def.only as Dictionary).get("tag", "")) != str(v):
					return false
			"aspect_min":
				if me.duelist.aspect < int(v):
					return false
			"opponent_fervor":
				if opp.fervor != int(v):
					return false
			"opponent_fervor_max":
				if opp.fervor > int(v):
					return false
			"fervor_min":
				if me.fervor < int(v):
					return false
			"allies_min":
				if me.allies().size() < int(v):
					return false
			"ally_present":
				if _ally_of_character(me, str(v)) == null:
					return false
			"allies_present":
				# "if Chi-Chi and Gohan are in play": every name on the list, not any of them.
				for name in (v as Array):
					if _ally_of_character(me, str(name)) == null:
						return false
			"defender_character":
				# Who the attack is aimed at, for a card that answers only on one personality's
				# behalf. A String names one; an Array names any of several.
				var aimed: CardInstance = _defender_personality(ctx)
				if aimed == null:
					return false
				var names: Array = v if v is Array else [v]
				if not names.has(aimed.def.character):
					return false
			"opponent_allies_min":
				if opp.allies().size() < int(v):
					return false
			"opponent_non_combats_min":
				if opp.non_combats().size() < int(v):
					return false
			"discard_top_school":
				if me.discard.is_empty() or me.discard.back().def.school != str(v):
					return false
			"discard_top_school_not":
				if not me.discard.is_empty() and me.discard.back().def.school == str(v):
					return false
			"opponent_discard_top_not_attack":
				# "If the top card of your opponent's discard pile is not a physical attack": a card
				# that performs an attack of that kind. An empty pile has no such card on top.
				if not opp.discard.is_empty():
					var top: CardDef = opp.discard.back().def
					if top.is_attack() and top.attack_kind() == str(v):
						return false
			"discard_bottom_school":
				# The oldest card in the pile, which is index 0 because the top is the back.
				if me.discard.is_empty() or me.discard[0].def.school != str(v):
					return false
			"discard_min":
				if me.discard.size() < int(v):
					return false
			"discard_top2_school":
				if me.discard.size() < 2 or me.discard.back().def.school != str(v) or me.discard[me.discard.size() - 2].def.school != str(v):
					return false
			"higher_might":
				if (me.in_control().might() > opp.in_control().might()) != bool(v):
					return false
			"duelist_higher_might":
				# "If your Main Personality has a higher power rating than your opponent's Main
				# Personality": the two duelists, whoever holds Combat on either side.
				if (me.duelist.might() > opp.duelist.might()) != bool(v):
					return false
			"opponent_style":
				# "If your opponent declared a Namekian Tokui-Waza": the school their deck declares.
				if opp.style != str(v):
					return false
			"opponent_used_combat_card":
				if (opp.combat_cards_used_combat == state.combat_count) != bool(v):
					return false
			"first_attack":
				if (me.attack_count_combat == 1) != bool(v):
					return false
			"role":
				if str(ctx.get("role", "")) != str(v):
					return false
			"seals_min":
				if me.seals().size() < int(v):
					return false
			"hand_min":
				if me.hand.size() < int(v):
					return false
			"hand_school_min":
				# "If 3 or more cards in your hand are Pyre cards": counted on the hand as it stands,
				# so a card asking about itself has already left for the resolving zone.
				var want: Dictionary = v
				var school: String = str(want.get("school", ""))
				var held: int = 0
				for c in me.hand:
					if c.def.school == school:
						held += 1
				if held < int(want.get("count", 1)):
					return false
			"took_wounds_min":
				# "...after you have taken 5 or more wounds from a single attack this Combat."
				if me.worst_wound_combat < int(v):
					return false
			"defender_tag":
				# The keyword on the personality the attack is aimed at, for "Focused against a
				# Marked duelist". Falls back to whoever is in control across the table, which is
				# what it is before a target has been picked.
				var aimed_at: CardInstance = _defender_personality(ctx)
				if aimed_at == null:
					aimed_at = opp.in_control()
				if not has_tag(aimed_at, str(v)):
					return false
			"stopped_last_phase":
				if me.stopped_last_phase != bool(v):
					return false
			"attack_focused":
				if bool(a.get("focused", false)) != bool(v):
					return false
			"source_school":
				var src: CardInstance = _attack_source()
				if src == null or src.def.school != str(v):
					return false
			"attack_kind":
				if str(a.get("kind", "")) != str(v):
					return false
			"opponent_seals_min":
				if opp.seals().size() < int(v):
					return false
			"performer_tag":
				# The personality swinging, which is the Ally when one holds Combat.
				if a.is_empty() or not has_tag(_performer(a), str(v)):
					return false
			"in_control_tag":
				if not has_tag(me.in_control(), str(v)):
					return false
			"duelist_tag":
				if not has_tag(me.duelist, str(v)):
					return false
			"card_in_play":
				# "while <card> is in play": the card does not say whose, so either side's counts.
				# A list is "either of these", which is how a card naming two Seals reads.
				var wanted: Array = v if v is Array else [v]
				var found: bool = false
				for title in wanted:
					if card_in_play_titled(str(title)) != null:
						found = true
						break
				if not found:
					return false
			_:
				push_warning("DuelEngine: unknown condition '%s'" % key)
	return true


# --- Floating effects, forbids, constants ---------------------------------

## Floats that answer attacks aimed at their owner. Every one of these is read off the defending
## side, so the attack phase a `next_attack_phase` duration waits for is the one the attacks come
## in, which is the opponent's phase and not the owner's own. A restriction like `forbid` is the
## other way round: it binds its owner during their own phase. `params.phase_of` ("self" or
## "opponent", read from the owner) overrides the guess where a card needs the other reading.
const DEFENSIVE_FLOATS: Array[String] = ["stop_next", "stop_all", "prevent_all", "prevent_art_life", "prevent_strike_damage", "no_endurance"]


func _float(owner: int, op: String, duration: String, params: Dictionary = {}) -> void:
	var f: Dictionary = {"owner": owner, "op": op, "duration": duration}
	for k in params.keys():
		f[k] = params[k]
	if duration == "next_turn_end":
		f["expires_turn"] = state.turn + (2 if state.active == owner else 1)
	if duration == "next_attack_phase":
		# Whose phase this waits for, and which phase it has to outlive. The phase running now
		# never counts: "their next attack phase" is the one after this one, which is what lets a
		# card played in defense reach the attack phase after the one it was played in.
		var acts_in: int = (1 - owner) if DEFENSIVE_FLOATS.has(op) else owner
		if params.has("phase_of"):
			acts_in = owner if str(params["phase_of"]) == "self" else 1 - owner
		f["phase_player"] = acts_in
		f["after_phase"] = state.attack_phase_count
	state.floating.append(f)
	_emit(&"floating", {"player": owner, "op": op, "duration": duration, "what": str(f.get("what", "")), "kind": str(f.get("kind", "")), "stages": int(f.get("stages", 0)), "source": int(f.get("source", -1))})


func _expire_floating(duration: String) -> void:
	var keep: Array[Dictionary] = []
	for f in state.floating:
		var d: String = str(f.get("duration", ""))
		if d == duration:
			continue
		if d == "next_turn_end" and duration == "turn" and int(f.get("expires_turn", 0)) <= state.turn:
			continue
		# A phase-long restriction never outlives the Combat it was set in, even if the phase it
		# was waiting for never came.
		if d == "next_attack_phase" and duration == "combat":
			continue
		keep.append(f)
	state.floating = keep


## Ends restrictions that were aimed at one player's next attack phase, now that it is over. Called
## as that phase closes, while `state.attacker` still names the player whose phase it was.
func _expire_attack_phase_floats(who: int) -> void:
	var keep: Array[Dictionary] = []
	for f in state.floating:
		if str(f.get("duration", "")) == "next_attack_phase" \
				and int(f.get("phase_player", f.get("owner", -1))) == who \
				and state.attack_phase_count > int(f.get("after_phase", -1)):
			continue
		keep.append(f)
	state.floating = keep


## A `next_attack_phase` float waits for a phase that has not started yet, so it does nothing for
## the rest of the phase it was created in. Without this a card played in defense would answer the
## very attack it was played against, and a restriction would bind the phase already running as
## well as the next one. Every other float is always live.
func _phase_float_live(f: Dictionary) -> bool:
	if str(f.get("duration", "")) != "next_attack_phase":
		return true
	return not (int(f.get("phase_player", f.get("owner", -1))) == state.attacker \
		and int(f.get("after_phase", -1)) == state.attack_phase_count)


func _has_floating(owner: int, op: String) -> bool:
	for f in state.floating:
		if int(f.get("owner", -1)) == owner and str(f.get("op", "")) == op and _phase_float_live(f):
			return true
	return false


func _has_floating_school(owner: int, op: String, school: String) -> bool:
	for f in state.floating:
		if int(f.get("owner", -1)) == owner and str(f.get("op", "")) == op and _phase_float_live(f) and (str(f.get("school", "")) == "" or str(f.get("school", "")) == school):
			return true
	return false


func _floating_first(owner: int, op: String) -> Dictionary:
	for f in state.floating:
		if int(f.get("owner", -1)) == owner and str(f.get("op", "")) == op and _phase_float_live(f):
			return f
	return {}


## Standing restrictions on a player from floating forbids, Grounds, Drills, and the opponent's constant power.
func _forbidden(p: PlayerState, what: String) -> bool:
	for f in state.floating:
		if int(f.get("owner", -1)) == p.index and str(f.get("op", "")) == "forbid" and str(f.get("what", "")) == what:
			if int(f.get("unless_energy_min", 0)) > 0 and p.duelist.energy >= int(f["unless_energy_min"]):
				continue
			if not _phase_float_live(f):
				continue
			return true
	var sources: Array[CardInstance] = []
	if state.grounds != null:
		sources.append(state.grounds)
	for q in state.players:
		sources.append_array(_active(q.drills()))
		sources.append_array(_active(q.non_combats()))
		# "While you control this Seal, your opponent cannot use his Mastery." A standing rule for
		# as long as it is on the table, so it ends the moment the Seal leaves or is captured.
		sources.append_array(q.seals())
	for c in sources:
		for rule in c.def.forbid:
			if str(rule.get("what", "")) != what:
				continue
			var who: String = str(rule.get("who", "all"))
			if who == "all" or (who == "owner" and c.controller == p.index) or (who == "opponent" and c.controller != p.index):
				return true
	# The opponent's constant power can forbid things too. Read it raw here: going through
	# _constant() would ask whether *their* powers are forbidden and recurse forever.
	if what != "powers":
		var opp_constant: Dictionary = _raw_constant(state.players[1 - p.index])
		for w in opp_constant.get("forbid_opponent", []):
			if str(w) == what:
				return true
	return false


func _attack_allowed(p: PlayerState, def: CardDef, kind_override: String = "") -> bool:
	var kind: String = kind_override if def == null else def.attack_kind()
	if _forbidden(p, kind + "_attacks"):
		return false
	if def != null:
		if bool(def.attack.get("only_first_attack", false)) and p.attack_count_combat > 0:
			return false
		# "This must be the first card you use during Combat": any card, not only an attack.
		if bool(def.attack.get("only_first_card", false)) and p.used_card_combat:
			return false
		if def.type == CardDef.Type.STRIKE and _forbidden(p, "strike_cards"):
			return false
		if def.type == CardDef.Type.ART and _forbidden(p, "art_cards"):
			return false
		if def.type == CardDef.Type.COMBAT and _forbidden(p, "combat_cards"):
			return false
		if _named_forbidden(def):
			return false
	return true


func _use_allowed(p: PlayerState, def: CardDef) -> bool:
	if def.type == CardDef.Type.COMBAT and _forbidden(p, "combat_cards"):
		return false
	if def.is_end_combat_card() and _forbidden(p, "end_combat"):
		return false
	if def.is_stop_all_card() and _forbidden(p, "stop_all"):
		return false
	if _named_forbidden(def):
		return false
	return true


## "Name a card" Drills lock that title out for both players.
func _named_forbidden(def: CardDef) -> bool:
	for q in state.players:
		for d in _active(q.drills()):
			if d.named_card != "" and d.named_card == def.title:
				return true
	return false


## The constant power in force for a player: the in-control personality's, or the duelist's
## when its constant says allies share it.
func _constant(p: PlayerState) -> Dictionary:
	if _forbidden(p, "powers"):
		return {}
	return _raw_constant(p)


## The constant powers in force for this player. The Duelist's own keeps working while an Ally holds
## Combat: the CRD is explicit that a Main Personality's Constant Combat Power "works even if [they
## are] no longer in control of Combat". A static effect like "your Allies cannot be discarded" must
## not switch itself off the moment an Ally steps up, which is exactly when the Allies are exposed.
## The personality in control adds its own on top and wins where the two name the same key.
func _raw_constant(p: PlayerState) -> Dictionary:
	var fc: Dictionary = p.duelist.aspect_data().get("constant", {})
	if p.in_control() == p.duelist:
		return fc
	var theirs: Dictionary = p.in_control().aspect_data().get("constant", {})
	if theirs.is_empty():
		return fc
	if fc.is_empty():
		return theirs
	var merged: Dictionary = fc.duplicate(true)
	for k in theirs.keys():
		merged[k] = theirs[k]
	return merged


func _can_play(p: PlayerState, def: CardDef) -> bool:
	if def.alignment_only != "" and def.alignment_only != p.alignment:
		return false
	# "Cards that can lower your Main Personality any amount of personality levels cannot be played
	# or used for the remainder of Combat": the other side's cards that lower this side's Aspect,
	# and this side's own cards that lower its own.
	if _forbidden(p, "lower_aspect") and (_def_has_effect(def, {"op": "lose_aspect", "who": "opponent"}) \
			or _def_has_effect(def, {"op": "set_aspect", "who": "opponent"})):
		return false
	if _forbidden(p, "lower_own_aspect") and (_def_has_effect(def, {"op": "lose_aspect", "who": "self"}) \
			or _def_has_effect(def, {"op": "set_aspect", "who": "self"})):
		return false
	if not def.only.is_empty() and not _gate_ok(p, def, def.only):
		return false
	# A card that attaches to a personality named in its text needs that personality on the table.
	if _attaches_to(def) == "named" and _attach_host(p, def) == null:
		return false
	# "X may have only 1 attached": a second copy stays in hand while one is on that personality.
	var attach_limit: int = int(def.attachment.get("limit_attached", 0))
	if attach_limit > 0:
		var host: CardInstance = _attach_host(p, def)
		var attached: int = 0
		for at in p.attachments():
			if at.def.id == def.id and at.attached_to == host:
				attached += 1
		if attached >= attach_limit:
			return false
	return true


## One "X only" gate. `any_of` holds a list of gates and passes when any one of them does, which
## is how a card reads that allows a side or either of two named personalities.
func _gate_ok(p: PlayerState, def: CardDef, gate: Dictionary) -> bool:
	if gate.has("any_of"):
		for sub in gate["any_of"]:
			if _gate_ok(p, def, sub):
				return true
		return false
	if gate.has("alignment") and p.alignment != str(gate["alignment"]):
		return false
	if gate.has("character") and p.in_control().def.character != str(gate["character"]):
		# The gated personality must be in control, except for a card that attaches to that
		# personality: it only needs them on the table.
		if not (_attaches_to_character(def) and _character_in_play(p, str(gate["character"])) != null):
			return false
	if gate.has("duelist_character") and p.duelist.def.character != str(gate["duelist_character"]):
		return false
	# "Your duelist pays 5 Energy to use this": the price is checked here and taken by the card's
	# own effects, so a card that cannot afford itself is never offered.
	if gate.has("energy_min") and p.in_control().energy < int(gate["energy_min"]):
		return false
	# "Your Main Personality pays 5 power stages to ...": the duelist pays, whoever holds Combat,
	# and pays as the card is used (`_use_card`).
	if gate.has("duelist_pays") and p.duelist.energy < int(gate["duelist_pays"]):
		return false
	# A keyword gate, "Marked only". Like the bloodline gate it reads the personality in control,
	# not the player, so a following can reach a card its duelist cannot.
	if gate.has("tag") and not has_tag(p.in_control(), str(gate["tag"])):
		return false
	# "Draconic only": the bloodline gates by who is in control, the way a named personality does.
	# A duelist and their Allies can differ, so it is read off the personality, not the player.
	if gate.has("bloodline") and bloodline_of(p.in_control()) != str(gate["bloodline"]):
		return false
	# "Use this card only after ...": any card-use condition may gate a play, so a card that waits
	# on the state of the duel goes through the same `_cond` every other clause does. It gates the
	# use, not the placement, because `_can_place` does not come this way.
	if gate.has("when") and not _cond(gate["when"], p.index, {}):
		return false
	# "You must have an Ally in play to use this card."
	if gate.has("allies_min") and p.allies().size() < int(gate["allies_min"]):
		return false
	return true


## The `to` of a card's attach effect, or "" when it does not attach.
func _attaches_to(def: CardDef) -> String:
	for e in def.effects:
		if str(e.get("op", "")) == "attach":
			return str(e.get("to", "in_control"))
	return ""


## The personality a card's attach effect would land on now, or null when there is none.
func _attach_host(p: PlayerState, def: CardDef) -> CardInstance:
	for e in def.effects:
		if str(e.get("op", "")) != "attach":
			continue
		match str(e.get("to", "in_control")):
			"in_control", "choose":
				return p.in_control()
			"character":
				var gated: CardInstance = _character_in_play(p, str(def.only.get("character", "")))
				return gated if gated != null else p.duelist
			"named":
				return _character_in_play(p, str(e.get("character", "")))
			"opponent_duelist":
				return state.players[1 - p.index].duelist
			"opponent_in_control":
				return state.players[1 - p.index].in_control()
			_:
				return p.duelist
	return null


# --- Choice prompts raised by effects -------------------------------------

func _prompt_discard_choice(target: PlayerState, amount: int, chooser: int = -1, to: String = "discard", filter: Variant = "") -> void:
	if chooser < 0:
		chooser = target.index
	var opts: Array[Command] = []
	for c in _hand_filtered(target, filter):
		opts.append(Command.new(chooser, &"discard_choice", c.uid))
	if opts.is_empty():
		return
	_choice = {"kind": "discard_choice", "remaining": amount, "target": target.index, "chooser": chooser, "to": to, "filter": filter}
	_set_prompt(chooser, &"discard_choice", opts, {"target": target.index, "amount": mini(amount, opts.size())})
	if amount > 1 and opts.size() > 1:
		var n: int = mini(amount, opts.size())
		prompt.set_batch(&"discard_choice", n, n)


## Offers cards in play to discard or remove. `amount` of them may go in one batch; "up to"
## effects also allow none.
func _prompt_pick_in_play(chooser: int, cands: Array[CardInstance], amount: int, up_to: bool) -> void:
	var opts: Array[Command] = []
	for c in cands:
		opts.append(Command.new(chooser, &"pick_in_play", c.uid))
	if up_to:
		opts.append(Command.new(chooser, &"pick_none"))
	var n: int = mini(amount, cands.size())
	_set_prompt(chooser, &"pick_in_play", opts, {"amount": n, "up_to": up_to})
	if n > 1:
		prompt.set_batch(&"pick_in_play", 1 if up_to else n, n)


## One personality's Energy moved by an `energy` effect, shared by the single, "all" and chosen
## forms so they cannot drift apart.
func _set_personality_energy(p: PlayerState, target: CardInstance, e: Dictionary, amount: Variant, source: CardInstance) -> void:
	var before: int = target.energy
	if amount is String and str(amount) == "max":
		if _has_floating(p.index, "no_gain"):
			_emit(&"gain_blocked", {"player": p.index, "card": target.uid, "amount": CardInstance.MAX_STAGE - before})
		else:
			target.energy = CardInstance.MAX_STAGE
	elif int(amount) >= 0:
		_gain_energy_from_card(p, target, int(amount))
	elif bool(e.get("no_overflow", false)):
		target.energy = maxi(0, target.energy + int(amount))
	else:
		_lose_energy(p, target, -int(amount))
	if target.energy != before:
		_emit(&"energy_changed", {"player": p.index, "card": target.uid, "from": before, "to": target.energy, "source": source.uid if source != null else -1})


## Cards picked out of a discard pile, which both players can read, so nothing is hidden by asking.
func _prompt_pick_discard(chooser: int, target: PlayerState, amount: int, up_to: bool) -> void:
	var opts: Array[Command] = []
	for c in target.discard:
		opts.append(Command.new(chooser, &"pick_option", c.uid))
	if up_to:
		opts.append(Command.new(chooser, &"pick_none"))
	var n: int = mini(amount, target.discard.size())
	_set_prompt(chooser, &"pick_discard", opts, {"amount": n, "up_to": up_to, "target": target.index})
	if n > 1:
		prompt.set_batch(&"pick_option", 0 if up_to else n, n)


## Hand cards an effect may pick from: all, only signature cards, or only non-Seals.
func _hand_filtered(p: PlayerState, filter: Variant) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	# A dictionary filter is a `_search_matches` spec, which is how a card names a band it is
	# after ("choose a Strike card in their hand") without inventing a second vocabulary for it.
	if filter is Dictionary:
		for c in p.hand:
			if _search_matches(p, c, filter, "hand"):
				out.append(c)
		return out
	var named: String = str(filter)
	for c in p.hand:
		match named:
			"signature":
				if c.def.character != "" and c.def.character == p.duelist.def.character:
					out.append(c)
			"non_seal":
				if c.def.type != CardDef.Type.SEAL:
					out.append(c)
			"non_combat":
				if c.def.type == CardDef.Type.NON_COMBAT or c.def.type == CardDef.Type.DRILL:
					out.append(c)
			_:
				# "tag:marked" narrows to cards carrying that keyword, for a cost the card pays
				# out of hand: "discard a marked card from your hand".
				if named.begins_with("tag:"):
					if has_tag(c, named.substr(4)):
						out.append(c)
				else:
					out.append(c)
	return out


## A Drill that reads "discard this if you have any other Non-Combat in play".
func _check_lonely_drills(p: PlayerState) -> void:
	if _drills_protected(p):
		return
	var others: int = p.non_combats().size() + p.drills().size() + p.attachments().size()
	for d in p.drills():
		if bool(d.def.raw.get("discard_if_other_non_combats", false)) and others > 1:
			_emit(&"in_play_discarded", {"player": p.index, "card": d.uid, "removed": false})
			_move_to_discard(d)


## Look at the top or bottom N cards; the looker may take one matching card into hand, play, or out
## of the game. `whose: "opponent"` reads the other player's deck instead of the looker's own: the
## cards are shown to the looker alone, through the prompt's `library`, and the owner is never told
## the order they go back in. `must` makes the pick mandatory when a legal card is there, which is
## how "Remove 1 of them" reads against "you may".
func _look_at(p: PlayerState, e: Dictionary, deck_of: PlayerState = null) -> void:
	var d: PlayerState = deck_of if deck_of != null else p
	var n: int = mini(int(e.get("amount", 1)), d.life_deck.size())
	var from: String = str(e.get("from", "top"))
	var to: String = str(e.get("to", "hand"))
	var pick: Dictionary = e.get("pick", {})
	var rearrange: bool = bool(e.get("rearrange", false))
	var opts: Array[Command] = []
	var looked: Array[int] = []
	for i in range(n):
		var c: CardInstance = d.life_deck[i] if from == "top" else d.life_deck[d.life_deck.size() - 1 - i]
		looked.append(c.uid)
		if (e.has("pick") or not rearrange) and _search_matches(p, c, pick, to):
			opts.append(Command.new(p.index, &"pick_option", c.uid))
	_emit(&"look_at", {"player": p.index, "count": n, "from": from, "deck": d.index})
	# "Place in play any Non-Combat cards revealed": every match goes, and there is nothing for the
	# player to decide, so nothing is asked.
	if bool(e.get("all_matches", false)):
		var every: Dictionary = pick.duplicate(true)
		every["to"] = to
		every["no_shuffle"] = true
		if e.has("stages"):
			every["stages"] = e["stages"]
		for o in opts:
			var hit: CardInstance = card(o.card)
			if hit != null and hit.zone == &"life_deck":
				_search_take(p, hit, every)
		if bool(e.get("shuffle_after", false)) and shuffle_decks:
			rng.shuffle(d.life_deck)
		return
	if opts.is_empty():
		if rearrange:
			# Nothing to take, and the rest still go where the card sends them.
			_prompt_place_or_rearrange(p, d, looked, str(e.get("rest", from)), str(e.get("place", "")))
		return
	if not bool(e.get("must", false)):
		opts.append(Command.new(p.index, &"pick_none"))
	var take: Dictionary = pick.duplicate(true)
	take["to"] = to
	take["no_shuffle"] = true
	if rearrange:
		take["rearrange"] = true
		take["looked"] = looked
		# `rest` sends the cards not taken to the other end, for a card that reads "look at the
		# bottom N, then put the rest on top in any order".
		take["from"] = str(e.get("rest", from))
		take["place"] = str(e.get("place", ""))
	if e.has("stages"):
		take["stages"] = e["stages"]
	if e.has("play_if"):
		take["play_if"] = e["play_if"]
	if bool(e.get("shuffle_after", false)):
		take["shuffle_after"] = true
	_choice = {"kind": "look_at", "player": p.index, "deck": d.index, "effect": take}
	var ctx: Dictionary = _choice_context(_effect_source, "look_at")
	ctx["to"] = to
	# Looking at N cards means seeing all N, not only the ones that may be taken.
	ctx["library"] = looked
	_set_prompt(p.index, &"pick_option", opts, ctx)


## "Put them all on top or all on the bottom, in any order": the end is one choice for the whole
## look, and the order inside it is the rearrange step that follows. Without `place: "choose"` the
## cards go straight back where they came from.
func _prompt_place_or_rearrange(p: PlayerState, d: PlayerState, looked: Array[int], from: String, place: String) -> void:
	if place != "choose" or looked.is_empty():
		_prompt_rearrange(p, looked, from, 0, d)
		return
	_choice = {"kind": "look_place", "player": p.index, "deck": d.index, "uids": looked, "from": from}
	var opts: Array[Command] = [Command.new(p.index, &"pick_option", -1, "top"), Command.new(p.index, &"pick_option", -1, "bottom")]
	var ctx: Dictionary = _choice_context(_effect_source, "look_place")
	ctx["library"] = looked
	_set_prompt(p.index, &"pick_option", opts, ctx)


func _draw_check_matches(p: PlayerState, drawn: CardInstance, e: Dictionary) -> bool:
	match str(e.get("check", "school")):
		"attack":
			# "if it is a Physical or Energy Combat card": a card that attacks, either kind.
			return drawn.def.type == CardDef.Type.STRIKE or drawn.def.type == CardDef.Type.ART
		"named":
			return drawn.def.character != ""
		"signature":
			return drawn.def.character != "" and drawn.def.character == p.duelist.def.character
		"title_contains":
			return drawn.def.title.contains(str(e.get("title_contains", "")))
		_:
			return drawn.def.school == str(e.get("school", ""))


func _discard_in_play_effect(target: PlayerState, e: Dictionary, owner: int) -> void:
	var type_name: String = str(e.get("card_type", "non_combat"))
	var amount: int = maxi(1, int(e.get("amount", 1)))
	if bool(e.get("all", false)):
		amount = 99
	var remove: bool = bool(e.get("remove", false))
	# "Discard any cards attached to your Main Personality": every rider on that duelist, whoever put
	# it there, so a hex the opponent laid on them goes too.
	if type_name == "attached_to_duelist":
		for q in state.players:
			for at in q.attachments():
				if at.attached_to == target.duelist:
					_take_off_table(at, remove, str(e.get("to", "discard")), owner)
		return
	# "...in play and in all Life Decks": the deck half runs first and on its own, because a card
	# that finds nothing on the table still has to empty the decks.
	if bool(e.get("life_decks", false)):
		var deck_remove: bool = remove
		if remove and owner != target.index and _removal_becomes_discard(target):
			deck_remove = false
		_purge_life_decks(type_name, deck_remove)
	var any_side: bool = str(e.get("who", "")) == "any"
	var candidates: Array[CardInstance] = _in_play_candidates(target, type_name, target.index == owner, remove)
	if any_side:
		# "Remove a Seal in play": either side's, so the pool is both and the chooser decides.
		candidates = _in_play_candidates(state.players[owner], type_name, true, remove)
		candidates.append_array(_in_play_candidates(state.players[1 - owner], type_name, false, remove))
	if candidates.is_empty():
		return
	var to: String = str(e.get("to", "discard"))
	var chooser: int = owner if str(e.get("chooser", "owner")) == "owner" else target.index
	# "Choose 1 or 2 of your opponent's Seals": an `up_to` always asks, even when there is nothing
	# to choose between, because taking fewer than the maximum is itself the choice.
	if bool(e.get("choose", false)) and (candidates.size() > amount or bool(e.get("up_to", false))):
		_choice = {"kind": "pick_in_play", "remaining": amount, "remove": remove, "to": to, "type": type_name,
			"target": target.index, "chooser": chooser, "up_to": bool(e.get("up_to", false)),
			"owner": owner, "any_side": any_side}
		_prompt_pick_in_play(chooser, candidates, amount, bool(e.get("up_to", false)))
		return
	var n: int = 0
	for i in range(candidates.size() - 1, -1, -1):
		if n >= amount:
			break
		_take_off_table(candidates[i], remove, to, owner)
		n += 1


## One card leaving the table to a card effect. "While you control this Seal, what your opponent
## would remove from the game is discarded instead" is read off the side losing that card, and
## only when the other side is taking it, so a card that reaches either side decides it per card.
func _take_off_table(c: CardInstance, remove: bool, to: String, owner: int) -> void:
	if remove and c.controller != owner and _removal_becomes_discard(state.players[c.controller]):
		remove = false
		_emit(&"removal_softened", {"player": c.controller})
	_discard_or_remove_in_play(c, remove, to)


## Takes every card of one type out of both Life Decks, for a card that reaches past the table.
## The decks are not shuffled afterwards: nothing is learned about the order by pulling a known
## type out of a deck the searcher never sees.
func _purge_life_decks(type_name: String, remove: bool) -> void:
	var wanted: int = int(CardDef.TYPE_NAMES.get(type_name, -1))
	if wanted < 0:
		return
	for p in state.players:
		for c in p.life_deck.duplicate():
			if c.def.type != wanted:
				continue
			if remove:
				_remove_from_game(c)
			else:
				_move_to_discard(c)


## `own_effect`: the cards are being taken by their own side's effect. "Your Allies cannot be
## discarded or removed by your opponent's card effects" does not guard them from their own side.
func _in_play_candidates(p: PlayerState, type_name: String, own_effect: bool = false, removing: bool = false) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for c in p.in_play:
		if c.remain > 0:
			continue
		var t: CardDef.Type = c.def.type
		var ok: bool = false
		var guarded: bool = t == CardDef.Type.PERSONALITY and ((not own_effect and _ally_protected(p, c)) \
			or (not removing and allies_undiscardable(p)))
		match type_name:
			"non_combat":
				ok = t == CardDef.Type.NON_COMBAT or (t == CardDef.Type.DRILL and not _drills_protected(p)) or c.attached_to != null
			"non_combat_card":
				# A Non-Combat card by its printed type, attached or not: a Drill is one, a Strike or
				# Combat card riding on a personality is not.
				ok = t == CardDef.Type.NON_COMBAT or (t == CardDef.Type.DRILL and not _drills_protected(p))
			"non_combat_only":
				ok = t == CardDef.Type.NON_COMBAT and c.attached_to == null
			"drill":
				ok = t == CardDef.Type.DRILL and not _drills_protected(p)
			"freestyle_drill":
				ok = t == CardDef.Type.DRILL and c.def.school == ""
			"ally":
				ok = t == CardDef.Type.PERSONALITY and not guarded
			"seal":
				ok = t == CardDef.Type.SEAL
			"non_combat_or_ally", "non_combat_ally_or_grounds":
				ok = t == CardDef.Type.NON_COMBAT or (t == CardDef.Type.DRILL and not _drills_protected(p)) or (t == CardDef.Type.PERSONALITY and not guarded)
			"drill_or_ally":
				ok = (t == CardDef.Type.DRILL and not _drills_protected(p)) or (t == CardDef.Type.PERSONALITY and not guarded)
			"attached":
				# "Discard any cards attached to your duelist": the riders, not what they ride on.
				ok = c.attached_to != null
			_:
				# Seals are immune to card effects unless named, and a card type this match has
				# not met yet still has to respect what guards the board, or the next one added
				# quietly walks past every protection.
				ok = t != CardDef.Type.SEAL \
					and not (t == CardDef.Type.DRILL and _drills_protected(p)) \
					and not guarded
		if ok:
			out.append(c)
	# The Grounds is one card for the whole table rather than a card in anyone's in-play zone, so
	# a card that reaches it has to name it and it joins the list here. Only the side that put it
	# out loses it, which is what "your opponent's Grounds" means when one Grounds is on the table.
	if type_name == "non_combat_ally_or_grounds" and state.grounds != null and state.grounds.owner == p.index:
		out.append(state.grounds)
	return out


## "Your Allies cannot be discarded or removed by your opponent's card effects." A constant that
## names a bloodline guards only the Allies carrying it, which is how the source card reads: the
## duelist shields her kin, not every hireling she happens to lead.
func _ally_protected(p: PlayerState, ally: CardInstance) -> bool:
	var guard: Variant = _constant(p).get("protect_allies", false)
	if guard is String:
		return str(guard) != "" and bloodline_of(ally) == str(guard)
	return bool(guard)


## Cards in play whose text is working: a card another has been attached to with "while attached,
## this Non-Combat card cannot be used" stays on the table but does nothing, its standing text
## included, the way a forbidden Drill does.
func _active(cards: Array[CardInstance]) -> Array[CardInstance]:
	var held: Dictionary = {}
	for p in state.players:
		for c in p.in_play:
			if c.attached_to != null and bool(c.def.attachment.get("disables_host", false)):
				held[c.attached_to.uid] = true
	if held.is_empty():
		return cards
	var out: Array[CardInstance] = []
	for c in cards:
		if not held.has(c.uid):
			out.append(c)
	return out


func _is_disabled(c: CardInstance) -> bool:
	for p in state.players:
		for at in p.attachments():
			if at.attached_to == c and bool(at.def.attachment.get("disables_host", false)):
				return true
	return false


## "Your Allies in play cannot be discarded": a Drill that says so guards them from any discard,
## the owner's own included, but not from being removed from the game.
func allies_undiscardable(p: PlayerState) -> bool:
	if _forbidden(p, "drills"):
		return false
	for d in _active(p.drills()):
		if bool(d.def.raw.get("allies_undiscardable", false)):
			return true
	return false


func _drills_protected(p: PlayerState) -> bool:
	return p.mastery != null and bool(p.mastery.def.raw.get("protect_drills", false)) and not _forbidden(p, "mastery")


## The Seals an opponent may capture from `p`: none while a Drill of theirs guards them.
func _capturable_seals(p: PlayerState) -> Array[CardInstance]:
	var none: Array[CardInstance] = []
	if not _forbidden(p, "drills"):
		for d in _active(p.drills()):
			if bool(d.def.raw.get("protect_seals", false)):
				return none
	return p.seals()


## "When your opponent uses a card effect besides damage that makes you discard the top cards of
## your Life Deck, you may discard this card from your hand to reduce the amount by N." The offer
## goes to the player losing the cards, and only for someone else's effect. True when it opened.
func _offer_deck_loss_guard(loser: PlayerState, amount: int, owner: int) -> bool:
	if loser.index == owner or amount <= 0:
		return false
	var guard: CardInstance = null
	for c in loser.hand:
		if c.def.raw.has("deck_loss_guard"):
			guard = c
			break
	if guard == null:
		return false
	var reduce: int = int((guard.def.raw["deck_loss_guard"] as Dictionary).get("amount", 0))
	_choice = {"kind": "deck_loss_guard", "guard": guard.uid, "loser": loser.index, "amount": amount, "reduce": reduce}
	var opts: Array[Command] = [
		Command.new(loser.index, &"pick_option", guard.uid, "guard"),
		Command.new(loser.index, &"pick_none"),
	]
	var context: Dictionary = _choice_context(guard, "deck_loss_guard")
	context["reduce"] = reduce
	context["amount"] = amount
	_set_prompt(loser.index, &"pick_option", opts, context)
	return true


## Takes a card off the table. `to` is "discard" unless the card says otherwise; "deck_shuffle"
## is the "shuffle them back into his Life Deck" wording, which is not a discard at all, and
## "deck_bottom" is "place them at the bottom of his Life Deck", which does not shuffle: the cards
## go under in the order they were chosen, so the first one picked is the first one drawn again.
func _discard_or_remove_in_play(c: CardInstance, remove: bool, to: String = "discard") -> void:
	_emit(&"in_play_discarded", {"player": c.controller, "card": c.uid, "removed": remove, "to": to})
	if to == "deck_bottom":
		_move_to_deck_bottom(c)
	elif to == "deck_shuffle":
		var owner: PlayerState = state.players[c.owner]
		_move_to_deck_bottom(c)
		if shuffle_decks:
			rng.shuffle(owner.life_deck)
	elif remove:
		_remove_from_game(c)
	else:
		_move_to_discard(c)


## "Name a card": the default pool is every card the opponent owns that either player could play.
## `pool: "opponent_deck"` narrows it to what is actually in their Life Deck, for a card that names
## a title and then goes looking for it; that is a search, so the deck is shown to the namer alone
## through `library` and a "name nothing" answer is allowed. `filter` is a `_search_matches` spec,
## which is how "name a card that can perform a Strike" is written.
func _prompt_name_card(p: PlayerState, source: CardInstance, e: Dictionary = {}) -> void:
	if source == null:
		return
	var opp: PlayerState = state.players[1 - p.index]
	var searches: bool = str(e.get("pool", "")) == "opponent_deck"
	var filter: Dictionary = e.get("filter", {})
	var titles: Dictionary = {}
	if str(e.get("pool", "")) == "library":
		# "Name any Combat card. All of your opponents must search their Life Decks": the namer
		# picks from every card there is and sees nothing of their deck.
		for def in library.defs.values():
			var d: CardDef = def
			var wanted_type: String = str(filter.get("card_type", ""))
			if wanted_type == "hand_combat" and not d.is_hand_combat_card():
				continue
			if str(filter.get("attack_kind", "")) != "" and (not d.is_attack() or d.attack_kind() != str(filter["attack_kind"])):
				continue
			if d.is_personality() or d.type == CardDef.Type.SEAL or d.type == CardDef.Type.MASTERY or d.type == CardDef.Type.RELIC:
				continue
			titles[d.title] = true
	var pool: Array = [] if str(e.get("pool", "")) == "library" else (opp.life_deck if searches else _cards.values())
	for c in pool:
		if not searches and (c.owner == p.index or c.def.is_personality() or c.def.type == CardDef.Type.SEAL or c.def.type == CardDef.Type.MASTERY or c.def.type == CardDef.Type.RELIC):
			continue
		if not filter.is_empty() and not _search_matches(opp, c, filter, "hand"):
			continue
		titles[c.def.title] = true
	var names: Array = titles.keys()
	names.sort()
	if names.is_empty():
		return
	var opts: Array[Command] = []
	for n in names:
		opts.append(Command.new(p.index, &"name_card", source.uid, n))
	_choice = {"kind": "name_card", "source": source.uid}
	var context: Dictionary = _choice_context(source, "name_card")
	if searches:
		opts.append(Command.new(p.index, &"pick_none"))
		var deck_shown: Array[int] = []
		for c in opp.life_deck:
			deck_shown.append(c.uid)
		context["library"] = deck_shown
	if e.has("strip"):
		_choice["strip"] = e.get("strip", {})
		_choice["target"] = opp.index
	_set_prompt(p.index, &"name_card", opts, context)


## "Search your opponent's Life Deck and remove every copy of the named card." The deck is shuffled
## once afterwards whether or not a copy was found, so what is left gives nothing away.
func _strip_named(target: PlayerState, title: String, strip: Dictionary) -> void:
	var to: String = str(strip.get("to", "discard"))
	var taken: int = 0
	# "Search your opponent's Life Deck for 1 copy of that card": `amount` caps it; none is every copy.
	var most: int = int(strip.get("amount", 0))
	for c in target.life_deck.duplicate():
		if c.def.title != title:
			continue
		if most > 0 and taken >= most:
			break
		taken += 1
		if to == "removed":
			_remove_from_game(c)
		else:
			_move_to_discard(c)
	_emit(&"stripped", {"player": target.index, "name": title, "count": taken, "to": to})
	if shuffle_decks:
		rng.shuffle(target.life_deck)
		_emit(&"deck_shuffled", {"player": target.index})


func _capture_prompt(p: PlayerState) -> void:
	var opp: PlayerState = state.players[1 - p.index]
	var seals: Array[CardInstance] = _capturable_seals(opp)
	if seals.is_empty():
		return
	if seals.size() == 1:
		_capture_seal(p.index, seals[0])
		return
	var opts: Array[Command] = []
	for t in seals:
		opts.append(Command.new(p.index, &"pick_option", t.uid))
	_choice = {"kind": "capture_choice"}
	_set_prompt(p.index, &"pick_option", opts, _choice_context(_effect_source, "capture"))


## Shows `shown`'s hand to `viewer` and nobody else: a prompt whose only answer is to be done
## looking, carrying the cards as its `library`, which is how a seat is shown hidden cards.
func _show_hand_to(shown: PlayerState, viewer: int, source: CardInstance) -> void:
	var cards: Array[int] = []
	for c in shown.hand:
		cards.append(c.uid)
	_emit(&"hand_revealed", {"player": shown.index, "to": viewer, "cards": cards})
	_choice = {"kind": "look_hand"}
	var ctx: Dictionary = _choice_context(source, "look_hand")
	ctx["library"] = cards
	var done: Array[Command] = [Command.new(viewer, &"pick_none")]
	_set_prompt(viewer, &"pick_option", done, ctx)


## Context for a choice raised mid-effect: the card asking and what the pick is for, so the
## prompt can be titled and the card shown without the client knowing the effect.
func _choice_context(source: CardInstance, purpose: String) -> Dictionary:
	return {"purpose": purpose, "source": source.uid if source != null else -1, "card_title": source.def.title if source != null else ""}


## What a "look at the top N" effect does once the card is taken: shuffle the rest back, or hand
## them to their owner to reorder. True when a prompt opened.
func _look_at_finish(looker: PlayerState, take: Dictionary, deck_of: PlayerState = null) -> bool:
	var d: PlayerState = deck_of if deck_of != null else looker
	if bool(take.get("shuffle_after", false)) and shuffle_decks:
		rng.shuffle(d.life_deck)
	elif bool(take.get("rearrange", false)):
		var looked: Array[int] = []
		looked.assign(take.get("looked", []))
		_choice = {}
		_prompt_place_or_rearrange(looker, d, looked, str(take.get("from", "top")), str(take.get("place", "")))
		return prompt != null
	return false


func _handle_choice(cmd: Command) -> void:
	var kind: String = str(_choice.get("kind", ""))
	match kind:
		"may":
			if str(cmd.value) == "yes":
				var e2: Dictionary = (_choice["effect"] as Dictionary).duplicate(true)
				e2["_confirmed"] = true
				var list: Array[Dictionary] = [e2]
				_queue.insert(0, {"effects": list, "index": 0, "trigger": str(e2.get("trigger", "secondary")), "owner": int(_choice["owner"]), "ctx": _choice["ctx"], "source": card(int(_choice.get("source", -1))), "announced": true})
			elif (_choice["effect"] as Dictionary).has("otherwise"):
				# "Do X or do Y": a no to the first half is a yes to the second.
				var other: Array[Dictionary] = []
				other.assign((_choice["effect"] as Dictionary)["otherwise"])
				_queue.insert(0, {"effects": other, "index": 0, "trigger": "then", "owner": int(_choice["owner"]), "ctx": _choice["ctx"], "source": card(int(_choice.get("source", -1))), "announced": true})
		"look_at":
			var looker: PlayerState = state.players[int(_choice["player"])]
			var looked_deck: PlayerState = state.players[int(_choice.get("deck", _choice["player"]))]
			var take: Dictionary = (_choice["effect"] as Dictionary).duplicate(true)
			if cmd.type != &"pick_none":
				var picked: CardInstance = card(cmd.card)
				if take.has("play_if") and _search_matches(looker, picked, take["play_if"], "play"):
					# "You may place it into play instead": worth asking, because a Drill already
					# in play can carry a clause that punishes a second one.
					_choice = {"kind": "play_or_hand", "player": looker.index, "deck": looked_deck.index, "card": picked.uid, "effect": take}
					var where: Array[Command] = [
						Command.new(looker.index, &"pick_option", picked.uid, "play"),
						Command.new(looker.index, &"pick_option", picked.uid, "hand"),
					]
					_set_prompt(looker.index, &"pick_option", where, _choice_context(picked, "play_or_hand"))
					return
				_search_take(looker, picked, take)
			if _look_at_finish(looker, take, looked_deck):
				return
		"play_or_hand":
			var seeker: PlayerState = state.players[int(_choice["player"])]
			var seeker_deck: PlayerState = state.players[int(_choice.get("deck", _choice["player"]))]
			var chosen: Dictionary = (_choice["effect"] as Dictionary).duplicate(true)
			chosen["to"] = "play" if str(cmd.value) == "play" else "hand"
			_search_take(seeker, card(int(_choice["card"])), chosen)
			if _look_at_finish(seeker, chosen, seeker_deck):
				return
		"look_place":
			# The whole look moves to the chosen end first; the order inside it is asked next.
			var mover: PlayerState = state.players[int(_choice["player"])]
			var moved_deck: PlayerState = state.players[int(_choice.get("deck", _choice["player"]))]
			var uids: Array[int] = []
			uids.assign(_choice["uids"])
			var end: String = str(cmd.value)
			if end != str(_choice.get("from", "top")):
				for uid in uids:
					var moving: CardInstance = card(uid)
					if moving != null and moving.zone == &"life_deck":
						moved_deck.life_deck.erase(moving)
						if end == "bottom":
							moved_deck.life_deck.append(moving)
						else:
							moved_deck.life_deck.insert(0, moving)
			_choice = {}
			_prompt_rearrange(mover, uids, end, 0, moved_deck)
			if prompt != null:
				return
		"rearrange":
			var p: PlayerState = state.players[int(_choice.get("deck", _choice["player"]))]
			var chooser: PlayerState = state.players[int(_choice["player"])]
			var placed: int = int(_choice["placed"])
			var from: String = str(_choice["from"])
			_place_rearranged(p, card(cmd.card), from, placed)
			var rest: Array[int] = []
			for uid in _choice["uids"]:
				if int(uid) != cmd.card:
					rest.append(int(uid))
			_choice = {}
			_prompt_rearrange(chooser, rest, from, placed + 1, p)
			if prompt != null:
				return
		"look_hand":
			pass
		"reveal_pick":
			var revealer: PlayerState = state.players[int(_choice["player"])]
			var chosen_card: CardInstance = card(cmd.card)
			var others: Array[int] = []
			for uid in _choice["uids"]:
				if int(uid) != cmd.card:
					others.append(int(uid))
			_erase_from_zone(chosen_card)
			chosen_card.zone = &"hand"
			revealer.hand.append(chosen_card)
			_emit(&"draw", {"player": revealer.index, "card": chosen_card.uid, "from": "revealed"})
			_choice = {}
			# The rest go back on top in the order their owner picks.
			_prompt_rearrange(revealer, others, "top", 0, revealer)
			if prompt != null:
				return
		"search_pick":
			var searcher: PlayerState = state.players[int(_choice["player"])]
			var search_effect: Dictionary = _choice["effect"]
			if cmd.type != &"pick_none":
				var picked: Array[int] = Prompt.cards_of(cmd)
				for uid in picked:
					_search_take(searcher, card(uid), search_effect)
				var remaining: int = int(_choice.get("remaining", 1)) - picked.size()
				if remaining > 0:
					var rest: Array[CardInstance] = _search_distinct(search_candidates(searcher, search_effect))
					if not rest.is_empty():
						_choice["remaining"] = remaining
						_prompt_search_pick(searcher, rest, remaining, search_effect)
						return
			_search_done(searcher, search_effect)
		"forbid_type":
			var params: Dictionary = {"what": str(cmd.value)}
			if int(_choice.get("unless_energy_min", 0)) > 0:
				params["unless_energy_min"] = int(_choice["unless_energy_min"])
			_float(int(_choice["target"]), "forbid", str(_choice.get("duration", "combat")), params)
		"discard_choice":
			var target: PlayerState = state.players[int(_choice.get("target", cmd.player))]
			var to: String = str(_choice.get("to", "discard"))
			var picked: Array[int] = Prompt.cards_of(cmd)
			for uid in picked:
				var c: CardInstance = card(uid)
				if to == "deck":
					_move_to_deck_bottom(c)
				elif to == "removed":
					_remove_from_game(c)
				else:
					_move_to_discard(c)
				_emit(&"hand_discarded", {"player": target.index, "card": c.uid, "random": false})
			if to == "deck" and shuffle_decks:
				rng.shuffle(target.life_deck)
			var remaining: int = int(_choice.get("remaining", 1)) - picked.size()
			if remaining > 0 and not target.hand.is_empty():
				_prompt_discard_choice(target, remaining, cmd.player, to, _choice.get("filter", ""))
				if prompt != null:
					return
		"stop_kind":
			# Stopping, not forbidding: the attack is still performed and still pays its cost.
			_float(cmd.player, "stop_all", "combat", {"kind": str(cmd.value)})
		"draw_count":
			if cmd.type != &"pick_none":
				var drawer: PlayerState = state.players[int(_choice["player"])]
				var want: Dictionary = _choice["effect"]
				var got: CardInstance = _draw_discard(drawer, int(str(cmd.value)), str(want.get("from", "bottom")))
				if want.has("if_school") and got != null and got.def.school == str(want["if_school"]):
					_enqueue(want.get("effects", []), "secondary", int(_choice["owner"]), _choice["ctx"], card(int(_choice.get("source", -1))))
		"draw_deck_count":
			if cmd.type != &"pick_none":
				_draw(int(_choice["player"]), int(str(cmd.value)))
		"discard_side":
			var side: Dictionary = (_choice["effect"] as Dictionary).duplicate(true)
			side["who"] = str(cmd.value)
			var one_side: Array[Dictionary] = [side]
			_queue.insert(0, {"effects": one_side, "index": 0, "trigger": "then", "owner": int(_choice["owner"]), "ctx": _choice["ctx"], "source": card(int(_choice.get("source", -1))), "announced": true})
		"attach_host":
			var attaching: CardInstance = card(int(_choice["source"]))
			if attaching != null:
				_attach_to_host(attaching, state.players[int(_choice["player"])], card(cmd.card))
		"energy_target":
			var picked: CardInstance = card(cmd.card)
			# A board-wide choice may land on the other side, so the pile it belongs to is the
			# card's own owner rather than whoever played the effect.
			var lifted: PlayerState = state.players[picked.owner] if bool(_choice.get("board", false)) else state.players[int(_choice["player"])]
			var e2: Dictionary = _choice["effect"]
			_set_personality_energy(lifted, picked, e2, e2.get("amount", 0), null)
		"pick_discard":
			if cmd.type != &"pick_none":
				for uid in Prompt.cards_of(cmd):
					_remove_from_game(card(uid))
		"card_type":
			var chosen: Dictionary = (_choice["effect"] as Dictionary).duplicate(true)
			chosen["card_type"] = str(cmd.value)
			var one: Array[Dictionary] = [chosen]
			_queue.insert(0, {"effects": one, "index": 0, "trigger": "then", "owner": int(_choice["owner"]), "ctx": _choice["ctx"], "source": card(int(_choice.get("source", -1))), "announced": true})
		"pick_in_play":
			if cmd.type == &"pick_none":
				_choice = {}
				return
			var picked: Array[int] = Prompt.cards_of(cmd)
			var taker: int = int(_choice.get("owner", cmd.player))
			for uid in picked:
				_take_off_table(card(uid), bool(_choice.get("remove", false)), str(_choice.get("to", "discard")), taker)
			var remaining: int = int(_choice.get("remaining", 1)) - picked.size()
			var target: PlayerState = state.players[int(_choice.get("target", 0))]
			var pick_type: String = str(_choice.get("type", "non_combat"))
			var rest: Array[CardInstance] = _in_play_candidates(target, pick_type, target.index == taker, bool(_choice.get("remove", false)))
			if bool(_choice.get("any_side", false)):
				rest = _in_play_candidates(state.players[taker], pick_type, true, bool(_choice.get("remove", false)))
				rest.append_array(_in_play_candidates(state.players[1 - taker], pick_type, false, bool(_choice.get("remove", false))))
			if remaining > 0 and not rest.is_empty():
				_choice["remaining"] = remaining
				_prompt_pick_in_play(cmd.player, rest, remaining, bool(_choice.get("up_to", false)))
				return
		"name_card":
			var src: CardInstance = card(cmd.card)
			var named: String = str(cmd.value) if cmd.type != &"pick_none" else ""
			if src != null and named != "":
				src.named_card = named
				_emit(&"card_named", {"player": cmd.player, "card": src.uid, "name": src.named_card})
			var strip: Dictionary = _choice.get("strip", {})
			if not strip.is_empty():
				# The deck was searched whatever was named, so it is shuffled even on a miss.
				_strip_named(state.players[int(_choice.get("target", 1 - cmd.player))], named, strip)
		"deck_loss_guard":
			var loser: PlayerState = state.players[int(_choice["loser"])]
			var losing: int = int(_choice["amount"])
			if cmd.type != &"pick_none":
				var guard: CardInstance = card(int(_choice["guard"]))
				_move_to_discard(guard)
				_emit(&"hand_discarded", {"player": loser.index, "card": guard.uid, "random": false})
				losing = maxi(0, losing - int(_choice["reduce"]))
			_choice = {}
			_discard_life(loser, losing)
		"capture_choice":
			_capture_seal(cmd.player, card(cmd.card))
	# A choice opened while paying an attack's costs holds the battle sequence where it was; the
	# answer moves it on, the way paying Energy does.
	if _choice.has("battle_step"):
		state.battle_step = int(_choice["battle_step"])
	_choice = {}


# --- Fervor and aspects ----------------------------------------------------

# Effective values. Every number a client shows about a player comes from one of these getters,
# so a card that changes the base or a standing effect changes the display in the same update.

## Fervor the duelist needs to rise an aspect: the player's base, or more if the opponent's
## Mastery demands it.
func fervor_needed(p: PlayerState) -> int:
	var opp: PlayerState = state.players[1 - p.index]
	if opp.mastery != null and opp.mastery.def.opponent_aspect_threshold > 0 and not _forbidden(opp, "mastery"):
		return maxi(p.fervor_needed, opp.mastery.def.opponent_aspect_threshold)
	return p.fervor_needed


## Each point of Fervor gained counts this many times.
func fervor_gain(p: PlayerState) -> int:
	return maxi(1, int(_constant(p).get("fervor_multiplier", 1)))


const STYLE_SURGE_BONUS: int = 1   # flat Power Up bonus every deck gets (kept from the old single-school rule)


## Energy the duelist regains at the Power Up step: Surge Rate plus the flat Style bonus.
func recover_gain(p: PlayerState) -> int:
	# "Their Main Personality's PUR is set to 0 until the end of their next turn and cannot be
	# modified by other effects": nothing is added to it, the flat Style bonus included.
	if _has_floating(p.index, "surge_zero"):
		return 0
	return maxi(0, surge_of(p) + STYLE_SURGE_BONUS - power_up_less(p))


## The duelist's Surge Rate as it stands: printed, or 0 while a card holds it there.
func surge_of(p: PlayerState) -> int:
	return 0 if _has_floating(p.index, "surge_zero") else p.duelist.surge()


## "All of your opponent's personalities gain 1 less power stage when they power up during the
## Power Up Step, to a minimum of 0": summed over the other side's Drills that say so.
func power_up_less(p: PlayerState) -> int:
	var opp: PlayerState = state.players[1 - p.index]
	if _forbidden(opp, "drills"):
		return 0
	var n: int = 0
	for d in _active(opp.drills()):
		n += int(d.def.raw.get("opponent_power_up_less", 0))
	return n


func aspect_shielded(p: PlayerState) -> bool:
	return p.relic != null and bool(p.relic.def.relic_flags.get("aspect_shield", false)) and not _forbidden(p, "relic")


## A standing effect is swallowing every Energy gain this player would make.
func energy_blocked(p: PlayerState) -> bool:
	return _has_floating(p.index, "no_gain")


## What taking this option would leave of the attack in the air: `life` is the life cards this
## player would still lose. Clients preview it against the current number while the player hovers
## a choice, so the maths is answered here once rather than guessed at on every seat. {} when the
## outcome is not something that can be promised ahead of the roll of the rest of the sequence.
## Defense also includes incoming `stages` (overflow already counted in `life`) and `stopped`.
func option_outcome(prompt: Prompt, cmd: Command) -> Dictionary:
	if state.attack.is_empty():
		return {}
	var a: Dictionary = state.attack
	match prompt.kind:
		&"endurance":
			var remaining: int = int(a.get("life_remaining", 0))
			if cmd.type != &"endure":
				return {"life": remaining}
			# The same sum `_handle_endurance` will do, including a card that boosts it to all.
			var boost: Dictionary = _floating_first(cmd.player, "endurance_boost")
			var prevented: int = remaining if not boost.is_empty() else mini(int(prompt.context.get("endurance", 0)), remaining)
			return {"life": remaining - prevented}
		&"defense":
			# Wounds, counting the Energy that would overflow into them.
			var damage: Dictionary = damage_breakdown(a)
			var life: int = int(damage.get("wounds", 0))
			var stages: int = int(damage.get("stages", 0))
			if cmd.type == &"no_defense":
				return {"life": life, "stages": stages, "stopped": false}
			if cmd.type == &"burn_defense":
				var d2: PlayerState = state.players[cmd.player]
				var burn: Dictionary = d2.mastery.def.raw.get("defense_burn", {}) if d2.mastery != null else {}
				var per: int = maxi(1, int(burn.get("prevent_per", 2)))
				return {"life": maxi(0, life - int(cmd.value) * per), "stages": stages, "stopped": false}
			# A stop only takes the attack to nothing when it is the one the attack still needs.
			var stops: int = int(a.get("stop_count", 0)) + 1
			var stopped: bool = stops >= int(a.get("stops_needed", 1)) and not bool(a.get("unstoppable", false))
			return {"life": 0 if stopped else life, "stages": 0 if stopped else stages, "stopped": stopped}
	return {}


## Standing forbids in force on the player right now, as forbid `what` words.
func restrictions(p: PlayerState) -> Array[String]:
	# One sweep of the sources for all fifteen kinds. Asking `_forbidden` per kind rebuilt the same
	# Drill and Non-Combat lists fifteen times, which the AI paid for on every position it scored.
	var hit: Dictionary = {}
	for f in state.floating:
		if int(f.get("owner", -1)) != p.index or str(f.get("op", "")) != "forbid":
			continue
		if int(f.get("unless_energy_min", 0)) > 0 and p.duelist.energy >= int(f["unless_energy_min"]):
			continue
		hit[str(f.get("what", ""))] = true
	var sources: Array[CardInstance] = []
	if state.grounds != null:
		sources.append(state.grounds)
	for q in state.players:
		sources.append_array(_active(q.drills()))
		sources.append_array(_active(q.non_combats()))
	for c in sources:
		for rule in c.def.forbid:
			var who: String = str(rule.get("who", "all"))
			if who == "all" or (who == "owner" and c.controller == p.index) or (who == "opponent" and c.controller != p.index):
				hit[str(rule.get("what", ""))] = true
	# As in `_forbidden`, the opponent's constant is read raw and may not forbid powers, or asking
	# whether their powers are forbidden would recurse.
	for w in _raw_constant(state.players[1 - p.index]).get("forbid_opponent", []):
		if str(w) != "powers":
			hit[str(w)] = true
	var out: Array[String] = []
	for what in FORBID_KINDS:
		if hit.has(what):
			out.append(what)
	return out


func _change_fervor_needed(p: PlayerState, value: int) -> void:
	var before: int = p.fervor_needed
	p.fervor_needed = maxi(1, value)
	_emit(&"fervor_needed_changed", {"player": p.index, "from": before, "to": p.fervor_needed})
	_check_aspect_up(p)


func _change_fervor(p: PlayerState, delta: int, source_owner: int) -> void:
	if delta < 0 and (fervor_locked(p) or (source_owner != p.index and fervor_shielded(p))):
		_emit(&"fervor_shielded", {"player": p.index})
		return
	if delta < 0 and source_owner != p.index:
		_mill_on_empty_fervor(p, -delta, source_owner)
	if delta > 0 and _has_floating(p.index, "no_fervor_gain"):
		# "Your opponent cannot gain any anger until the beginning of his next turn."
		_emit(&"fervor_shielded", {"player": p.index})
		return
	if delta > 0:
		delta *= fervor_gain(p)
		# "When you gain Fervor, increase that amount by 1": added after the multiplier, so a
		# duelist carrying both gets the doubling on the printed number and the bonus once.
		delta += int(_constant(p).get("fervor_gain_bonus", 0))
		# Grounds may cap what one card or effect can raise. The Fervor shield covers this too: it
		# reads "your opponent cannot reduce the amount of Fervor you would gain", not just "cannot
		# lower it", so a capping Grounds does not touch a shielded player.
		if state.grounds != null and state.grounds.def.raw.has("fervor_gain_cap") and not fervor_shielded(p):
			delta = mini(delta, int(state.grounds.def.raw["fervor_gain_cap"]))
	var before: int = p.fervor
	p.fervor = maxi(0, p.fervor + delta)
	_emit(&"fervor_changed", {"player": p.index, "from": before, "to": p.fervor, "source": _effect_source.uid if _effect_source != null else -1})
	_check_aspect_up(p)


func _set_fervor(p: PlayerState, value: int, source_owner: int) -> void:
	if value < p.fervor and (fervor_locked(p) or (source_owner != p.index and fervor_shielded(p))):
		_emit(&"fervor_shielded", {"player": p.index})
		return
	if value > p.fervor and _has_floating(p.index, "no_fervor_gain"):
		_emit(&"fervor_shielded", {"player": p.index})
		return
	var before: int = p.fervor
	p.fervor = maxi(0, value)
	_emit(&"fervor_changed", {"player": p.index, "from": before, "to": p.fervor, "source": _effect_source.uid if _effect_source != null else -1})
	_check_aspect_up(p)


## "When you lower your opponent's anger but his anger level is 0, your opponent discards the top
## card of his Life Deck for each anger level lowered." Read before the lowering, off the Drills of
## the side doing it.
func _mill_on_empty_fervor(p: PlayerState, levels: int, by: int) -> void:
	if p.fervor != 0 or by < 0 or by == p.index:
		return
	var lowerer: PlayerState = state.players[by]
	if _forbidden(lowerer, "drills"):
		return
	for d in _active(lowerer.drills()):
		if bool(d.def.raw.get("mill_on_empty_fervor", false)):
			_discard_life(p, levels)
			return


func fervor_shielded(p: PlayerState) -> bool:
	return p.relic != null and bool(p.relic.def.relic_flags.get("fervor_shield", false)) and not _forbidden(p, "relic")


## "Your Fervor may not be lowered while this Drill is in play." Wider than the Relic's shield: it
## names no opponent, so it holds against every lowering, a critical hit's and the player's own.
func fervor_locked(p: PlayerState) -> bool:
	if _forbidden(p, "drills"):
		return false
	for d in _active(p.drills()):
		if bool(d.def.raw.get("fervor_lock", false)):
			return true
	return false


## Full Fervor raises the duelist an aspect. At the duelist's own top aspect it is the Ascension win;
## a forbidden Ascension win falls back to the old peak (full Energy, Fervor to 0).
## The Aspect that wins outright by standing above everything the rival can field, or 0 when there
## is no such Aspect. A duelist whose ladder is taller than their rival's only has to reach the
## first rung above the rival's top one; when the two ladders are the same height nothing is above
## theirs and the Fervor route is the only one. Read off what each side may reach, not where they
## currently stand, so it does not move during the duel.
func mppv_aspect(p: PlayerState) -> int:
	var needed: int = state.players[1 - p.index].highest_aspect + 1
	return needed if needed <= p.highest_aspect else 0


## Both ways the climb ends the duel. True when the duel is over or the question is waiting on the
## rival's answer.
func _try_ascension_win(p: PlayerState) -> bool:
	if p.no_ascension_win or state.ascension_scored[p.index]:
		return false
	var mppv: int = mppv_aspect(p)
	var by_mppv: bool = mppv > 0 and p.duelist.aspect >= mppv
	var by_fervor: bool = p.duelist.aspect >= p.highest_aspect and p.fervor >= fervor_needed(p)
	if not by_mppv and not by_fervor:
		return false
	# A card may answer the win itself ("use this when your opponent would win by Ascension").
	if _open_ascension_window(p):
		return true
	_win(p.index, "ascension")
	return true


func _check_aspect_up(p: PlayerState) -> void:
	# Standing above the rival's whole ladder is the win on its own and does not wait for Fervor.
	if mppv_aspect(p) > 0 and p.duelist.aspect >= mppv_aspect(p) and _try_ascension_win(p):
		return
	if p.fervor < fervor_needed(p):
		return
	if p.duelist.aspect < p.highest_aspect:
		p.fervor = 0
		_aspect_up(p)
		return
	if _try_ascension_win(p):
		return
	p.fervor = 0
	p.duelist.energy = CardInstance.MAX_STAGE
	_emit(&"fervor_peak", {"player": p.index, "energy": p.duelist.energy})


func _aspect_up(p: PlayerState) -> void:
	p.duelist.go_to_aspect(p.duelist.aspect + 1)
	p.duelist.energy = CardInstance.MAX_STAGE
	_discard_drills(p, true)
	_emit(&"aspect_up", {"player": p.index, "aspect": p.duelist.aspect})
	# Entering the Aspect is itself the Most Powerful Personality win, however the climb was paid for.
	_try_ascension_win(p)


func _lose_aspect(p: PlayerState, source_owner: int) -> void:
	if p.duelist.aspect <= 1:
		return
	if source_owner != p.index and aspect_shielded(p):
		return
	# "Cards that lower your Aspect cannot be played or used for the remainder of Combat."
	if source_owner != p.index and _forbidden(state.players[source_owner], "lower_aspect"):
		return
	p.duelist.go_to_aspect(p.duelist.aspect - 1)
	p.duelist.energy = LOST_ASPECT_ENERGY
	_discard_drills(p)
	_emit(&"aspect_down", {"player": p.index, "aspect": p.duelist.aspect})


## Moves the duelist to an absolute aspect ("fervor" reads the current Fervor value).
func _set_aspect(p: PlayerState, e: Dictionary, source_owner: int) -> void:
	var raw: Variant = e.get("aspect", 1)
	var target: int = p.fervor if (raw is String and str(raw) == "fervor") else int(raw)
	target = clampi(target, 1, p.highest_aspect)
	if target == 0:
		target = 1
	while p.duelist.aspect < target:
		_aspect_up(p)
		# A climb can end the duel partway up, or stop for the rival's answer to it.
		if state.is_over() or prompt != null:
			return
	while p.duelist.aspect > target:
		var before: int = p.duelist.aspect
		_lose_aspect(p, source_owner)
		if p.duelist.aspect == before:
			break


## Changing aspect clears the Drills. A Mastery that guards Drills stops this too: the guard is
## "cannot be discarded for any reason", not "cannot be discarded by the opponent".
func _discard_drills(p: PlayerState, advancing: bool = false) -> void:
	if _drills_protected(p):
		return
	# "Whenever your duelist advances an Aspect, none of your other Drills are discarded. If your
	# opponent's Fervor is 0 when they advance, this Drill is not discarded either." A climb only;
	# losing an Aspect clears the Drills as it always did.
	var keeper: CardInstance = null
	if advancing and not _forbidden(p, "drills"):
		for d in _active(p.drills()):
			if d.def.raw.has("keeps_drills_on_advance"):
				keeper = d
				break
	for d in p.drills():
		if keeper != null and d != keeper:
			continue
		if d == keeper and _cond((keeper.def.raw["keeps_drills_on_advance"] as Dictionary).get("self_when", {}), p.index, {}):
			continue
		_move_to_discard(d)


## Energy a card effect hands a personality. A constant may double what the duelist gains this
## way, which is why the Power Up step calls _gain_energy directly and card effects come here.
func _gain_energy_from_card(p: PlayerState, c: CardInstance, n: int) -> void:
	var mult: int = maxi(1, int(_constant(p).get("energy_gain_multiplier", 1)))
	if mult > 1 and c == p.duelist:
		n *= mult
	_gain_energy(p, c, n)


func _gain_energy(p: PlayerState, c: CardInstance, n: int) -> void:
	if _has_floating(p.index, "no_gain"):
		# The gain is swallowed by a standing effect. Say so, or the card that asked for it looks
		# like it did nothing at all.
		if n > 0:
			_emit(&"gain_blocked", {"player": p.index, "card": c.uid, "amount": n})
		return
	c.energy = clampi(c.energy + n, 0, CardInstance.MAX_STAGE)


## Energy loss from card effects. Past 0 it costs life cards, one per stage.
func _lose_energy(p: PlayerState, c: CardInstance, n: int) -> void:
	var lost: int = mini(c.energy, n)
	c.energy -= lost
	var overflow: int = n - lost
	if overflow > 0:
		_discard_life(p, overflow)


func _power_available(p: PlayerState, ic: CardInstance) -> bool:
	var pw: Dictionary = ic.power()
	if pw.is_empty():
		return false
	if pw.has("attack") and pw["attack"].has("only_first_attack") and p.attack_count_combat > 0:
		return false
	var uses: int = maxi(1, int(pw.get("uses", 1)))
	# Ally and Duelist are one card type, so which one this is comes from the seat, not the type:
	# anyone who is not the Main Personality is an Ally, and an Ally's Power refreshes each Combat.
	if ic != p.duelist:
		if ic.power_used_combat != state.combat_count:
			return true
		return ic.power_uses_combat < uses
	# Duelist Powers are once per turn; an aspect change mid-Combat does not refresh them.
	if ic.power_used_turn != state.turn:
		return true
	if ic.power_used_combat == state.combat_count and ic.power_uses_combat < uses:
		return true
	# "You may discard a marked card from your hand. If you do, this power may be used a second
	# time this Combat." The extra use exists only while the cost can be paid.
	var extra: Dictionary = pw.get("extra_use", {})
	if extra.is_empty() or ic.power_used_combat != state.combat_count:
		return false
	return ic.power_uses_combat < uses + int(extra.get("uses", 1)) \
		and not _hand_filtered(p, str(extra.get("filter", ""))).is_empty()


## The price of a Power's extra use, charged before the Power resolves so the card being spent
## cannot be the one the Power goes on to fetch. Only the uses past the printed allowance cost
## anything; `_power_available` has already checked the cost can be paid.
func _charge_extra_use(p: PlayerState, ic: CardInstance) -> void:
	var pw: Dictionary = ic.power()
	var extra: Dictionary = pw.get("extra_use", {})
	if extra.is_empty() or ic != p.duelist:
		return
	if ic.power_used_combat != state.combat_count or ic.power_uses_combat < maxi(1, int(pw.get("uses", 1))):
		return
	_apply_effect({"op": "discard_hand", "amount": 1, "random": false,
		"filter": str(extra.get("filter", ""))}, p.index, {}, ic)


func _mark_power_used(ic: CardInstance) -> void:
	if ic.power_used_combat != state.combat_count or ic.power_used_turn != state.turn:
		ic.power_uses_combat = 0
	ic.power_used_turn = state.turn
	ic.power_used_combat = state.combat_count
	ic.power_uses_combat += 1


# --- Seals ---------------------------------------------------------------

func _seal_in_play(id: String) -> CardInstance:
	for p in state.players:
		for t in p.seals():
			if t.def.id == id:
				return t
	return null


func _controls_full_set(p: PlayerState) -> bool:
	var sets: Dictionary = {}
	for t in p.seals():
		sets[t.def.seal_set] = int(sets.get(t.def.seal_set, 0)) + 1
	for s in sets.keys():
		if int(sets[s]) >= SEALS_PER_SET:
			return true
	return false


## A Seal leaving a hand or Life Deck never reaches the discard pile.
func _bypass_seal(c: CardInstance) -> void:
	var owner: PlayerState = state.players[c.owner]
	_erase_from_zone(c)
	if _seal_in_play(c.def.id) != null:
		c.zone = &"removed"
		owner.removed.append(c)
		_emit(&"seal_bypassed", {"card": c.uid, "to": "removed"})
	else:
		c.zone = &"life_deck"
		owner.life_deck.append(c)
		_emit(&"seal_bypassed", {"card": c.uid, "to": "deck_bottom"})


func _capture_seal(by: int, t: CardInstance) -> void:
	var taker: PlayerState = state.players[by]
	_erase_from_zone(t)
	t.controller = by
	t.zone = &"in_play"
	taker.in_play.append(t)
	_emit(&"seal_captured", {"player": by, "card": t.uid, "id": t.def.id})
	if _controls_full_set(taker):
		taker.seal_victory_pending = true
		_emit(&"seal_victory_pending", {"player": by})
	# The captor may use the Seal's power on capture: one "may" question for the whole text.
	var power: Array[Dictionary] = _seal_power(t)
	if not power.is_empty():
		var offer: Dictionary = power[0].duplicate(true)
		offer["may"] = true
		if power.size() > 1:
			var rest: Array = offer.get("then", []).duplicate()
			rest.append_array(power.slice(1))
			offer["then"] = rest
		_enqueue_keyed([offer], "on_place", by, {}, t)


func _only_seals_left(p: PlayerState) -> bool:
	if p.life_deck.is_empty():
		return false
	for c in p.life_deck:
		if c.def.type != CardDef.Type.SEAL:
			return false
	return true


# --- Search, attach, draw variants ---------------------------------------

## Search the Life Deck (or discard, or Reserve) for a matching card and put it in hand or play.
## A search of the Life Deck is a look through it: the searcher is always asked, sees the whole
## deck, may take nothing, and the deck is shuffled once when the search is over unless the
## effect says `no_shuffle`. That holds with one match and with none. A search of the discard
## pile or the Reserve alone shows nothing new, so it is asked only when there is a real choice.
func _search(p: PlayerState, e: Dictionary) -> void:
	var n: int = maxi(1, int(e.get("amount", 1)))
	p.search_taken.clear()
	# "Shuffle 1 card in your discard pile into your Life Deck for each level of your anger."
	if str(e.get("amount_from", "")) == "fervor":
		n = p.fervor
		if n <= 0:
			return
	if e.has("amount_per_set_seal"):
		# One card for each Seal of the named set in play, on either side.
		n = _set_seals_in_play(str(e["amount_per_set_seal"]))
		if n <= 0:
			return
	var cands: Array[CardInstance] = search_candidates(p, e)
	var looks: bool = _search_looks_at_deck(e)
	if cands.is_empty() and not looks:
		return
	var distinct: Array[CardInstance] = _search_distinct(cands)
	if looks or (bool(e.get("choose", true)) and distinct.size() > 1):
		_choice = {"kind": "search_pick", "player": p.index, "effect": e, "remaining": n}
		_prompt_search_pick(p, distinct, n, e)
		return
	for i in range(n):
		cands = search_candidates(p, e)
		if cands.is_empty():
			break
		_search_take(p, cands[0], e)
	_search_done(p, e)


func _set_seals_in_play(set_name: String) -> int:
	var n: int = 0
	for pl in state.players:
		n += pl.seals_of_set(set_name)
	return n


## Whose Life Deck a search goes through: the searcher's own unless the card says the opponent's.
func _searched_deck_owner(p: PlayerState, e: Dictionary) -> PlayerState:
	return state.players[1 - p.index] if str(e.get("whose", "self")) == "opponent" else p


func _search_looks_at_deck(e: Dictionary) -> bool:
	var source: String = str(e.get("source", "deck"))
	return source == "deck" or source == "either"


## Offers the distinct hits of a search. Up to `n` may be taken at once as a batch. A deck search
## also lists the whole Life Deck under `library`, by title so the order gives nothing away.
func _prompt_search_pick(p: PlayerState, hits: Array[CardInstance], n: int, e: Dictionary = {}) -> void:
	var opts: Array[Command] = []
	for c in hits:
		opts.append(Command.new(p.index, &"pick_option", c.uid))
	# "Choose a card in your discard pile and put it into your hand" is not optional: `must` takes
	# away the empty answer. A Life Deck search is always a look, so it keeps it whatever it says.
	var must: bool = bool(e.get("must", false)) and not _search_looks_at_deck(e)
	if not must:
		opts.append(Command.new(p.index, &"pick_none"))
	var context: Dictionary = {"search": true, "amount": mini(n, hits.size()), "to": str(e.get("to", "hand"))}
	if _search_looks_at_deck(e):
		var deck: Array[CardInstance] = _searched_deck_owner(p, e).life_deck.duplicate()
		deck.sort_custom(func(a: CardInstance, b: CardInstance) -> bool: return a.def.title < b.def.title if a.def.title != b.def.title else a.uid < b.uid)
		var library: Array[int] = []
		for c in deck:
			library.append(c.uid)
		context["library"] = library
	if _effect_source != null:
		context["source"] = _effect_source.uid
		context["card_title"] = _effect_source.def.title
	_set_prompt(p.index, &"pick_option", opts, context)
	if n > 1 and hits.size() > 1:
		prompt.set_batch(&"pick_option", mini(n, hits.size()) if must else 1, mini(n, hits.size()))


## The end of a search: the deck that was looked through is shuffled.
func _search_done(p: PlayerState, e: Dictionary) -> void:
	var shuffled_in: bool = str(e.get("to", "hand")) == "deck_shuffle"
	var looked_deck: PlayerState = _searched_deck_owner(p, e)
	if (_search_looks_at_deck(e) or shuffled_in) and shuffle_decks and not bool(e.get("no_shuffle", false)):
		rng.shuffle(looked_deck.life_deck)
		_emit(&"deck_shuffled", {"player": looked_deck.index})
	# "If all the cards you shuffled in were Non-Combat cards, gain 3 power stages": read off what
	# this search actually took, and only when it took something.
	var if_all: Dictionary = e.get("if_all", {})
	if not if_all.is_empty() and not p.search_taken.is_empty():
		var every: bool = true
		for uid in p.search_taken:
			if not _search_matches(p, card(uid), if_all, "hand"):
				every = false
		if every:
			_enqueue(if_all.get("effects", []), "secondary", p.index, {}, _effect_source)


## Every card the search could take, in pool order (deck, then discard when "either").
## Every card this search could legally take. Public because a player knows the contents of their
## own Life Deck even before searching it, so an AI deciding whether a tutor is worth playing may
## ask the same question its owner could. It says nothing about order, and nothing about the
## opponent's hidden cards.
func search_candidates(p: PlayerState, e: Dictionary) -> Array[CardInstance]:
	var pools: Array = []
	# "Search your opponent's Life Deck": the searcher looks through the other side's deck.
	if str(e.get("whose", "self")) == "opponent":
		var opp_pool: Array[CardInstance] = []
		var out_opp: Array[CardInstance] = []
		opp_pool.assign(state.players[1 - p.index].life_deck)
		for c in opp_pool:
			if _search_matches(p, c, e, str(e.get("to", "hand"))):
				out_opp.append(c)
		return out_opp
	match str(e.get("source", "deck")):
		"discard":
			pools.append(p.discard)
		"either":
			pools.append(p.life_deck)
			pools.append(p.discard)
		"reserve":
			pools.append(p.reserve)
		"hand":
			pools.append(p.hand)
		_:
			pools.append(p.life_deck)
	var out: Array[CardInstance] = []
	var to: String = str(e.get("to", "hand"))
	for pool in pools:
		for c in pool:
			if _search_matches(p, c, e, to):
				out.append(c)
	return out


## One instance per distinct card definition, so the pick list has no duplicates.
func _search_distinct(cands: Array[CardInstance]) -> Array[CardInstance]:
	var seen: Dictionary = {}
	var out: Array[CardInstance] = []
	for c in cands:
		if not seen.has(c.def.id):
			seen[c.def.id] = true
			out.append(c)
	return out


func _search_matches(p: PlayerState, c: CardInstance, e: Dictionary, to: String) -> bool:
	var type_name: String = str(e.get("card_type", ""))
	var wanted: int = int(CardDef.TYPE_NAMES.get(type_name, -1))
	if type_name == "non_combat_any":
		# Everything that is placed in the Non-Combat step bar Grounds: Non-Combats, Drills, Seals.
		if c.def.type != CardDef.Type.NON_COMBAT and c.def.type != CardDef.Type.DRILL and c.def.type != CardDef.Type.SEAL:
			return false
	elif type_name == "non_combat_or_drill":
		# The source card's "Non-Combat, non-Seal" wording: a Drill is a Non-Combat card too.
		if c.def.type != CardDef.Type.NON_COMBAT and c.def.type != CardDef.Type.DRILL:
			return false
	elif c.def.type == CardDef.Type.SEAL and type_name != "seal":
		return false
	if wanted >= 0 and c.def.type != wanted:
		return false
	if type_name == "attack" and not c.def.is_attack():
		return false
	if type_name == "strike_or_art" and c.def.type != CardDef.Type.STRIKE and c.def.type != CardDef.Type.ART:
		# A Strike or Art card of any use, attack or block, which is how the source card reads.
		return false
	if e.has("aspect") and c.def.aspect != int(e["aspect"]):
		# "Search for a level 1 Ally": the aspect the personality would come into play at.
		return false
	if type_name == "hand_combat" and not c.def.is_hand_combat_card():
		return false
	# "A card that can perform a Strike": what the card does when played, not the band it is printed
	# in, so a Combat card carrying a Strike matches and a Strike card that only blocks does not.
	var performs: String = str(e.get("attack_kind", ""))
	if performs != "" and (not c.def.is_attack() or c.def.attack_kind() != performs):
		return false
	var tag: String = str(e.get("tag", ""))
	if tag != "" and not (c.def.raw.get("tags", []) as Array).has(tag):
		return false
	var school: String = str(e.get("school", "*"))
	if school != "*" and c.def.school != school:
		return false
	var title_contains: String = str(e.get("title_contains", ""))
	if title_contains != "" and not c.def.title.contains(title_contains):
		return false
	var exclude: String = str(e.get("exclude_title", ""))
	if exclude != "" and c.def.title == exclude:
		return false
	if str(e.get("signature_of", "")) == "duelist" and c.def.character != p.duelist.def.character:
		return false
	# "A <Name> named card": that character's Signature cards, whoever is searching.
	var named: String = str(e.get("character", ""))
	if named != "" and c.def.character != named:
		return false
	if e.has("has_effect") and not _def_has_effect(c.def, e["has_effect"]):
		return false
	# "A Drill that adds damage to your attacks": a standing modifier of its own that raises the
	# Energy or wounds its owner's attacks do.
	if bool(e.get("adds_damage", false)):
		var adds_any: bool = false
		for m in c.def.modifiers:
			if str(m.get("scope", "own")) == "own" and (int(m.get("stages", 0)) > 0 or int(m.get("life", 0)) > 0):
				adds_any = true
		if not adds_any:
			return false
	if to == "play" and not _can_place(p, c):
		return false
	return true


## "A card that discards a card from your opponent's hand": any effect line (including nested
## `then` lists and attack variants) with the given op and, when given, the same `who`.
func _def_has_effect(def: CardDef, spec: Dictionary) -> bool:
	var lists: Array = [def.effects]
	for v in def.attack.get("variants", []):
		lists.append(v.get("effects", []))
	while not lists.is_empty():
		var list: Array = lists.pop_back()
		for e in list:
			if not (e is Dictionary):
				continue
			if str(e.get("op", "")) == str(spec.get("op", "")) and (not spec.has("who") or str(e.get("who", "self")) == str(spec["who"])):
				return true
			if e.has("then"):
				lists.append(e["then"])
			if e.has("effects"):
				lists.append(e["effects"])
	return false


## A life card with "if this card is discarded from your Life Deck" text.
func _on_wound(p: PlayerState, c: CardInstance) -> void:
	for e in c.def.effects_for("on_wound"):
		var at: String = str(e.get("at", ""))
		if at == "fight_back":
			if state.step == GameState.Step.COMBAT:
				p.pending_fight_back.append({"effect": e, "source": c.uid})
		elif at == "turn_end":
			p.pending_turn_end.append({"effect": e, "source": c.uid})
		else:
			var list: Array[Dictionary] = [e]
			_queue.append({"effects": list, "index": 0, "trigger": "on_wound", "owner": p.index, "ctx": {}, "source": c})


## The rival may answer an Ascension win with a card that says so ("use this card when your
## opponent would win by Ascension"). Such a card carries its own timing, which beats the rule that
## a Non-Combat is only used in Combat, so this window opens wherever the Fervor was gained. It
## offers each answer once, and every one of them spends itself, so the win lands on the next pass.
func _open_ascension_window(p: PlayerState) -> bool:
	var opp: PlayerState = state.players[1 - p.index]
	var opts: Array[Command] = []
	for c in _active(opp.non_combats()):
		if str(c.def.raw.get("use_at", "")) == "ascension_win" and _can_play(opp, c.def) and not _forbidden(opp, "non_combats"):
			opts.append(Command.new(opp.index, &"use", c.uid))
	if opts.is_empty():
		return false
	opts.append(Command.new(opp.index, &"decline"))
	state.pending_play = {"mode": "ascension", "winner": p.index}
	_set_prompt(opp.index, &"respond", opts, {"mode": "ascension", "winner": p.index})
	return true


## The opponent may use a "during your opponent's Declare step" card before the active player decides.
func _open_declare_window(p: PlayerState) -> bool:
	var opp: PlayerState = state.players[1 - p.index]
	var opts: Array[Command] = []
	for c in _active(opp.non_combats()):
		if c.def.has_trigger("opponent_declare") and _can_play(opp, c.def) and not _forbidden(opp, "non_combats"):
			if _def_has_effect(c.def, {"op": "discard_hand", "who": "self"}) and opp.hand.is_empty():
				continue
			opts.append(Command.new(opp.index, &"use", c.uid))
	if opts.is_empty():
		return false
	opts.append(Command.new(opp.index, &"decline"))
	state.pending_play = {"mode": "declare"}
	_set_prompt(opp.index, &"respond", opts, {"mode": "declare"})
	return true


# --- Bonds: two Allies fight as one card until the bond burns out -------------

func _find_owned(p: PlayerState, id: String) -> CardInstance:
	for pool in [p.reserve, p.removed, p.discard, p.life_deck, p.hand]:
		for c in pool:
			if c.def.id == id:
				return c
	return null


func _bond(p: PlayerState, id: String) -> void:
	var bond: CardInstance = _find_owned(p, id)
	if bond == null:
		return
	var parts: Array[CardInstance] = []
	for name in bond.def.raw.get("bond_of", []):
		var al: CardInstance = _ally_of_character(p, str(name))
		if al == null:
			return
		parts.append(al)
	for al in parts:
		_drop_attachments(al)
		_erase_from_zone(al)
		al.zone = &"under"
	_erase_from_zone(bond)
	bond.zone = &"in_play"
	bond.controller = p.index
	bond.energy = CardInstance.MAX_STAGE
	bond.bond_timer = 0
	bond.cards_under.clear()
	for al in parts:
		bond.cards_under.append(al)
	p.in_play.append(bond)
	_emit(&"bonded", {"player": p.index, "card": bond.uid, "parts": parts.size()})


func _unbond(p: PlayerState, bond: CardInstance) -> void:
	var names: Array = bond.def.raw.get("bond_of", [])
	var fusees: Array[CardInstance] = []
	var rest: Array[CardInstance] = []
	for c in bond.cards_under:
		if c.def.type == CardDef.Type.PERSONALITY and names.has(c.def.character):
			fusees.append(c)
		else:
			rest.append(c)
	bond.cards_under.clear()
	_erase_from_zone(bond)
	bond.zone = &"reserve"
	bond.bond_timer = 0
	p.reserve.append(bond)
	for c in rest:
		_move_to_discard(c)
	for al in fusees:
		al.zone = &"in_play"
		al.controller = p.index
		al.energy = ALLY_STARTING_ENERGY
		p.in_play.append(al)
	if p.controlling == bond:
		p.controlling = p.duelist
	_emit(&"unbonded", {"player": p.index, "card": bond.uid})


## Moves a found card into hand or play. The shuffle comes once, in `_search_done`.
func _search_take(p: PlayerState, hit: CardInstance, e: Dictionary) -> void:
	var to: String = str(e.get("to", "hand"))
	if to == "play":
		_place(p, hit)
		if hit.def.type == CardDef.Type.PERSONALITY and e.has("stages"):
			# "at their highest Energy" comes through as the string, not a number.
			var at: Variant = e["stages"]
			hit.energy = CardInstance.MAX_STAGE if at is String and str(at) == "max" else clampi(int(at), 0, CardInstance.MAX_STAGE)
	elif to == "attack":
		# "Search for a card that performs an attack and play it during this attack phase." It
		# goes to hand first so it is performed from a legal place, and the phase does not hand
		# over until it has been performed.
		_erase_from_zone(hit)
		hit.zone = &"hand"
		p.hand.append(hit)
		_pending_attack = hit.uid
	elif to == "removed":
		# "Remove 1 of them from the game": the card leaves from wherever it sits, deck included.
		_remove_from_game(hit)
	elif to == "deck_bottom" or to == "deck_shuffle":
		_move_to_deck_bottom(hit)
	elif to == "deck_top":
		# "Place them on top of your Life Deck": each pick goes above the last, so the card taken
		# last is the one drawn first.
		_erase_from_zone(hit)
		hit.zone = &"life_deck"
		p.life_deck.insert(0, hit)
	else:
		_erase_from_zone(hit)
		hit.zone = &"hand"
		p.hand.append(hit)
	p.last_searched = hit.uid
	p.search_taken.append(hit.uid)
	_emit(&"search", {"player": p.index, "card": hit.uid, "type": str(e.get("card_type", "")), "to": to})


## `to`: "in_control", "duelist", "character" (the X of the card's "X only" gate, wherever X
## stands) or "named" (the personality the attach effect names, which may differ from the gate).
func _attach(c: CardInstance, p: PlayerState, to: String) -> void:
	var host: CardInstance = _attach_host(p, c.def)
	if host == null:
		match to:
			"opponent_duelist":
				host = state.players[1 - p.index].duelist
			"opponent_in_control":
				host = state.players[1 - p.index].in_control()
			"duelist":
				host = p.duelist
			_:
				host = p.in_control()
	_attach_to_host(c, p, host)


## The move itself, once the host is settled, whether the card named it or the player picked it.
func _attach_to_host(c: CardInstance, p: PlayerState, host: CardInstance) -> void:
	if host == null:
		host = p.in_control()
	if c.zone == &"resolving" or c.zone == &"hand" or c.zone == &"in_play":
		_erase_from_zone(c)
	c.zone = &"in_play"
	c.controller = p.index
	c.attached_to = host
	c.remain = 0
	p.in_play.append(c)
	_emit(&"attached", {"player": p.index, "card": c.uid, "host": host.uid})
	_check_lonely_drills(p)


## Returns the last card drawn, null when the pile was empty.
func _draw_discard(p: PlayerState, n: int, from: String) -> CardInstance:
	var last: CardInstance = null
	for i in range(n):
		if p.discard.is_empty():
			return last
		var c: CardInstance = p.discard.pop_front() if from == "bottom" else p.discard.pop_back()
		c.zone = &"hand"
		p.hand.append(c)
		last = c
		_emit(&"draw", {"player": p.index, "card": c.uid, "from": "discard"})
	return last


## `from` "top_and_bottom" alternates ends, top first; anything else takes from the top.
## `school` takes only cards of that school, for a card that recovers its own kind and nothing else.
func _shuffle_discard_into_deck(p: PlayerState, n: int, all: bool, from: String = "top", school: String = "", shuffle: bool = true) -> void:
	var pool: Array[CardInstance] = []
	for c in p.discard:
		if school == "" or c.def.school == school:
			pool.append(c)
	var count: int = pool.size() if all else mini(n, pool.size())
	# Two cursors walk in from the ends, so alternating top and bottom never takes one card twice.
	# (Indexing both ends by `i` did: with two cards in the pile, the top pick and the second
	# "bottom" pick were the same card, which then sat in the Life Deck twice.)
	var front: int = 0
	var back: int = pool.size() - 1
	for i in range(count):
		# The pile runs oldest first, so its top is the end of the array and its bottom is the front.
		var from_front: bool = from == "bottom" or (from == "top_and_bottom" and i % 2 == 1)
		var c: CardInstance = pool[front] if from_front else pool[back]
		if from_front:
			front += 1
		else:
			back -= 1
		p.discard.erase(c)
		c.zone = &"life_deck"
		p.life_deck.append(c)
		_emit(&"recover", {"player": p.index, "card": c.uid})
	if count > 0 and shuffle and shuffle_decks:
		rng.shuffle(p.life_deck)


# --- Card movement --------------------------------------------------------

func _draw(player_index: int, n: int) -> void:
	var p: PlayerState = state.players[player_index]
	for i in range(n):
		if p.life_deck.is_empty():
			_lose(player_index, "survival")
			if state.is_over():
				return
		var c: CardInstance = p.life_deck.pop_front()
		c.zone = &"hand"
		p.hand.append(c)
		_emit(&"draw", {"player": player_index, "card": c.uid})


## Takes the top life card off the deck for damage. Null (and a loss) if there is none.
func _flip_life_card(p: PlayerState) -> CardInstance:
	if p.life_deck.is_empty():
		_lose(p.index, "survival")
		if state.is_over():
			return null
	var c: CardInstance = p.life_deck.pop_front()
	c.zone = &"none"
	return c


## Life cards lost to a cost or effect, not to attack damage. Seals count but still bypass the
## discard pile. `remove` is the "remove the top N cards of your Life Deck from the game" wording:
## the cards are still lost off the top, they simply never reach the pile.
func _discard_life(p: PlayerState, n: int, remove: bool = false) -> void:
	for i in range(n):
		var c: CardInstance = _flip_life_card(p)
		if c == null:
			return
		if c.def.type == CardDef.Type.SEAL:
			_bypass_seal(c)
		elif remove:
			_remove_from_game(c, true)
			_on_wound(p, c)
		else:
			_move_to_discard(c, true)
			_on_wound(p, c)
		_emit(&"life_card_lost", {"player": p.index, "card": c.uid, "id": c.def.id})


## Cards leave the hand by the engine's seeded RNG when random, else from the front.
func _discard_hand(p: PlayerState, n: int, random: bool, remove: bool = false) -> void:
	for i in range(n):
		if p.hand.is_empty():
			return
		var idx: int = rng.randi_range(0, p.hand.size() - 1) if random else 0
		var c: CardInstance = p.hand[idx]
		if remove:
			_remove_from_game(c)
		else:
			_move_to_discard(c)
		_emit(&"hand_discarded", {"player": p.index, "card": c.uid, "random": random})


func _recover_top(p: PlayerState, n: int, from: String = "top") -> void:
	for i in range(n):
		if p.discard.is_empty():
			return
		var c: CardInstance = p.discard.pop_front() if from == "bottom" else p.discard.pop_back()
		c.zone = &"life_deck"
		p.life_deck.append(c)
		_emit(&"recover", {"player": p.index, "card": c.uid})


## Cards out of a discard pile and out of the duel. The pile runs oldest first, so its top is the
## end of the array and its bottom is the front, which is how "the bottom 2 cards" reads.
func _remove_discard(p: PlayerState, n: int, all: bool, from: String = "top") -> void:
	var count: int = p.discard.size() if all else mini(n, p.discard.size())
	for i in range(count):
		var c: CardInstance = p.discard[0] if from == "bottom" else p.discard.back()
		_remove_from_game(c)


func _move_to_discard(c: CardInstance, quiet: bool = false) -> void:
	if c.def.type == CardDef.Type.SEAL:
		_bypass_seal(c)
		return
	_erase_from_zone(c)
	var owner: PlayerState = state.players[c.owner]
	c.zone = &"discard"
	c.attached_to = null
	c.remain = 0
	# An overlaid Ally goes to the discard whole: every Aspect under it follows. They go in
	# lowest Aspect first, so the Aspect that was actually in play ends on top of the pile, which
	# is the invariant the rest of the engine reads ("the card just discarded is the top one").
	for under in c.cards_under:
		under.zone = &"discard"
		under.attached_to = null
		under.remain = 0
		owner.discard.append(under)
	c.cards_under.clear()
	owner.discard.append(c)
	_drop_attachments(c)
	if not quiet:
		_emit(&"card_moved", {"card": c.uid, "to": "discard", "owner": c.owner})


## `quiet` is for a life card lost to damage or a cost: the wound event that follows is the
## one clients show, so the move itself emits nothing.
func _remove_from_game(c: CardInstance, quiet: bool = false) -> void:
	_erase_from_zone(c)
	var owner: PlayerState = state.players[c.owner]
	c.zone = &"removed"
	c.attached_to = null
	c.remain = 0
	for under in c.cards_under:
		under.zone = &"removed"
		under.attached_to = null
		under.remain = 0
		owner.removed.append(under)
	c.cards_under.clear()
	owner.removed.append(c)
	_drop_attachments(c)
	if not quiet:
		_emit(&"card_moved", {"card": c.uid, "to": "removed", "owner": c.owner})


func _move_to_deck_bottom(c: CardInstance) -> void:
	_erase_from_zone(c)
	var owner: PlayerState = state.players[c.owner]
	c.zone = &"life_deck"
	c.attached_to = null
	c.remain = 0
	owner.life_deck.append(c)
	_emit(&"card_moved", {"card": c.uid, "to": "deck_bottom", "owner": c.owner})


## Attachments fall off when their host leaves play, a personality or a Non-Combat card.
func _drop_attachments(host: CardInstance) -> void:
	if host.def.type != CardDef.Type.PERSONALITY and host.def.type != CardDef.Type.NON_COMBAT and host.def.type != CardDef.Type.DRILL:
		return
	for p in state.players:
		for at in p.attachments():
			if at.attached_to == host:
				at.attached_to = null
				_move_to_discard(at)


## Where a used card goes: attach, Remain in play, deck bottom, removed, or discard.
func _finish_card(c: CardInstance, empowered: bool) -> void:
	var def: CardDef = c.def
	if def.type == CardDef.Type.DRILL or def.type == CardDef.Type.MASTERY:
		return
	if c.attached_to != null:
		return
	var owner: PlayerState = state.players[c.owner]
	var remain: int = def.remain
	if not def.remain_when.is_empty() and _cond(def.remain_when.get("when", {}), c.owner, {"attack": state.attack}):
		# "...to be used X more times this Combat, X = your duelist's current Aspect."
		var extra: Variant = def.remain_when.get("remain", 1)
		remain = maxi(remain, owner.duelist.aspect if extra is String and str(extra) == "aspect" else int(extra))
	if remain > 0 and c.remain_combat != state.combat_count and state.step == GameState.Step.COMBAT:
		_erase_from_zone(c)
		c.zone = &"in_play"
		c.controller = c.owner
		c.remain = remain
		c.remain_combat = state.combat_count
		owner.in_play.append(c)
		_emit(&"remain", {"player": c.owner, "card": c.uid, "uses": remain})
		return
	# "When you use a Saiyan Style card to perform an attack, it is placed on the bottom of your Life
	# Deck after use": a block or a Combat card of that school is not using it to attack.
	if _has_floating_school(c.owner, "after_use_bottom", def.school) and def.school != "" and c.attacked_combat == state.combat_count:
		_move_to_deck_bottom(c)
	elif def.bottom_after_use:
		_move_to_deck_bottom(c)
	elif def.raw.has("bottom_after_use_when") and _cond(def.raw["bottom_after_use_when"], c.owner, {"attack": state.attack}):
		# "If used by X, place this card at the bottom of your Life Deck after use."
		_move_to_deck_bottom(c)
	elif def.remove_after_use and not empowered and not _kept_by_seal(def) \
			and not (def.raw.has("discard_instead_when") and _cond(def.raw["discard_instead_when"], c.owner, {})):
		# "Remove from the game after use. If your Main Personality's current level is 3 or higher,
		# discard after use instead": the condition sends it to the pile below.
		_remove_from_game(c)
	else:
		_move_to_discard(c)


## `discard_if_seal`: the card is discarded, not removed, while the named Seal is in play.
func _kept_by_seal(def: CardDef) -> bool:
	var id: String = str(def.raw.get("discard_if_seal", ""))
	return id != "" and _seal_in_play(id) != null


func _erase_from_zone(c: CardInstance) -> void:
	var owner: PlayerState = state.players[c.owner]
	match c.zone:
		&"hand":
			owner.hand.erase(c)
		&"life_deck":
			owner.life_deck.erase(c)
		&"discard":
			owner.discard.erase(c)
		&"removed":
			owner.removed.erase(c)
		&"reserve":
			owner.reserve.erase(c)
		&"in_play":
			state.players[c.controller].in_play.erase(c)
		&"grounds":
			if state.grounds == c:
				state.grounds = null
		_:
			pass
	c.zone = &"none"


## The duelist or Ally in play with this character name, else null.
func _character_in_play(p: PlayerState, character: String) -> CardInstance:
	if character == "":
		return null
	if p.duelist.def.character == character:
		return p.duelist
	return _ally_of_character(p, character)


## True for a card whose text attaches it to the character named in its "X only" gate.
func _attaches_to_character(def: CardDef) -> bool:
	for e in def.effects:
		if str(e.get("op", "")) == "attach" and str(e.get("to", "")) == "character":
			return true
	return false


## The personality an attack is aimed at: the named target once one is chosen, otherwise whoever
## is in control on the defending side. Empty when there is no attack in the air.
func _defender_personality(ctx: Dictionary) -> CardInstance:
	var a: Dictionary = ctx.get("attack", state.attack)
	if a.is_empty():
		return null
	var aimed: CardInstance = card(int(a.get("target", -1)))
	if aimed != null:
		return aimed
	return state.players[int(a["defender"])].in_control()


func _ally_of_character(p: PlayerState, character: String) -> CardInstance:
	if character == "":
		return null
	for a in p.allies():
		if a.def.character == character:
			return a
	return null


# --- Outcome --------------------------------------------------------------

func _win(player_index: int, reason: String) -> void:
	if state.is_over():
		return
	if _scores_point_only(player_index, reason):
		return
	state.winner = player_index
	state.win_reason = reason
	state.step = GameState.Step.GAME_OVER
	prompt = null
	_queue.clear()
	_emit(&"game_over", {"winner": player_index, "reason": reason})


func _lose(player_index: int, reason: String) -> void:
	_win(1 - player_index, reason)


## Adventure house rule, 2026-09-21: a duel may run first to `points_to_win`, which is per seat
## (a seat with two lives takes two points to beat). A survival win and an Ascension each score
## one point; a full Seal set still wins outright. True when the point was
## scored and the duel goes on. The table persists: a duelist whose Life Deck ran out shuffles
## their discard pile into a new one, and cards removed from the game stay out, so the second
## deck is the weaker one. Nothing is reset for an Ascension beyond the Fervor peak the rules
## already give a top Aspect, and it scores once per duelist.
func _scores_point_only(winner: int, reason: String) -> bool:
	if reason == "seal":
		# On trial: the set is one point, once, and the Seals stay where they are. Without the
		# option a full set is still the whole duel.
		if not state.seal_scores_point:
			return false
		if state.seal_scored[winner]:
			return true
		state.seal_scored[winner] = true
	if reason == "ascension":
		state.ascension_scored[winner] = true
	var loser: PlayerState = state.players[1 - winner]
	state.points[winner] += 1
	if state.points[winner] >= state.points_to_win[winner]:
		return false
	# On trial: cards that removed themselves after use come back for the second Life Deck.
	var returning: Array[CardInstance] = []
	if reason == "survival" and state.second_life_returns_used:
		for c in loser.removed:
			if c.def.remove_after_use:
				returning.append(c)
	# Nothing to shuffle back means nothing left to fight with.
	if reason == "survival" and loser.discard.is_empty() and returning.is_empty():
		return false
	_emit(&"point_scored", {"player": winner, "reason": reason, "points": state.points[winner], "to_win": state.points_to_win[winner]})
	if reason == "survival":
		for c in returning:
			loser.removed.erase(c)
			c.zone = &"discard"
			loser.discard.append(c)
		_shuffle_discard_into_deck(loser, 0, true)
		_emit(&"second_wind", {"player": loser.index, "cards": loser.life_deck.size()})
	else:
		var p: PlayerState = state.players[winner]
		if p.duelist.aspect >= p.highest_aspect and p.fervor >= fervor_needed(p):
			p.fervor = 0
			p.duelist.energy = CardInstance.MAX_STAGE
			_emit(&"fervor_peak", {"player": p.index, "energy": p.duelist.energy})
	return true


func _emit(type: StringName, data: Dictionary = {}) -> void:
	var ev: GameEvent = GameEvent.new(type, data)
	if record_display_state:
		ev.state = _display_state()
	events.append(ev)


## The numbers a client shows on the table right now. See `GameEvent.state`.
func _display_state() -> Dictionary:
	var energy: Dictionary = {}
	var might: Dictionary = {}
	var aspect: Dictionary = {}
	var controlling: Array[int] = []
	var fervor: Array[int] = []
	var zones: Array = []
	for p in state.players:
		energy[p.duelist.uid] = p.duelist.energy
		might[p.duelist.uid] = p.duelist.might()
		aspect[p.duelist.uid] = p.duelist.aspect
		for a in p.allies():
			energy[a.uid] = a.energy
			might[a.uid] = a.might()
			aspect[a.uid] = a.aspect
		controlling.append(p.controlling.uid if p.controlling != null else p.duelist.uid)
		fervor.append(p.fervor)
		zones.append([p.life_deck.size(), p.hand.size(), p.discard.size(), p.removed.size()])
	# Where the turn stood, so the banner over the table never runs ahead of the beat under it.
	return {
		"energy": energy, "might": might, "aspect": aspect, "controlling": controlling,
		"fervor": fervor, "zones": zones,
		"turn": state.turn, "step": state.step, "phase": state.phase,
		"active": state.active, "attacker": state.attacker,
		# The Combat tracker needs both: how far the battle sequence has run inside this attack,
		# and which exchange of the Combat the beat belongs to.
		"battle_step": state.battle_step, "attack_phase_count": state.attack_phase_count,
	}
