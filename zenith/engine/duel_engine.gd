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
const STRONG_BAND: int = 3   # band D of the Strike Table; see _apply_first_player_rule
const ALLY_STARTING_ENERGY: int = 3
const LOST_ASPECT_ENERGY: int = 5
const DRAW_COUNT: int = 3
const HAND_KEEP: int = 1
const FERVOR_TO_ASPECT: int = 5
const ART_COST: int = 2
const ART_BASE_LIFE: int = 4
const WILD_BASE_DAMAGE: int = 2
const CRITICAL_THRESHOLD: int = 5   # life cards from one attack that make it critical damage
const SEALS_PER_SET: int = 7
const ALLY_CONTROL_MAX_ENERGY: int = 1
const MAX_ADVANCE_ITERATIONS: int = 100000
## Every forbid `what` the rules consult; `restrictions` reports which are in force on a player.
const FORBID_KINDS: Array[String] = [
	"strike_attacks", "art_attacks", "strike_cards", "art_cards", "combat_cards", "non_combats",
	"drills", "seals", "mastery", "powers", "stop_all", "end_combat", "non_attack_actions", "skip_combat",
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
	var e: DuelEngine = DuelEngine.new()
	e.library = library
	e.strike_table = strike_table
	e.rng = rng.copy()
	e.shuffle_decks = shuffle_decks
	for uid in _cards:
		e._cards[uid] = (_cards[uid] as CardInstance).copy()
	for uid in e._cards:
		var c: CardInstance = e._cards[uid]
		c.cards_under = PlayerState._mapped_list(c.cards_under, e._cards)
		c.attached_to = PlayerState._mapped(c.attached_to, e._cards)
	e.state = state.copy(e._cards)
	for p in prompts:
		e.prompts.append(p.copy())
	e._next_uid = _next_uid
	e._combat_ending = _combat_ending
	e._pending_attack = _pending_attack
	e._reserve_swapped = _reserve_swapped.duplicate()
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
			hidden[i].aspect = defs[i].lowest_aspect() if defs[i].is_personality() else 1
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
	var fdef: CardDef = library.get_def(deck.duelist_id)
	assert(fdef != null and fdef.type == CardDef.Type.DUELIST, "Deck %s has no duelist" % deck.name)
	p.duelist = _instance(fdef, index, &"duelist")
	p.duelist.energy = STARTING_ENERGY
	p.highest_aspect = clampi(deck.aspects, 1, fdef.highest_aspect())
	p.controlling = p.duelist
	if deck.mastery_id != "":
		p.mastery = _instance(library.get_def(deck.mastery_id), index, &"side")
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
func _apply_first_player_rule() -> void:
	var a: PlayerState = state.players[0]
	var b: PlayerState = state.players[1]
	var wild: bool = a.duelist.is_wild() or b.duelist.is_wild()
	var a_high: bool = strike_table.band(a.duelist.might()) >= STRONG_BAND
	var b_high: bool = strike_table.band(b.duelist.might()) >= STRONG_BAND
	if not wild and a_high != b_high:
		state.active = 1 if a_high else 0
		_emit(&"bracket_rule", {"stronger": 0 if a_high else 1})
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
		if not _queue.is_empty():
			_drain()
		else:
			_advance()
		guard += 1
		assert(guard < MAX_ADVANCE_ITERATIONS, "DuelEngine is stuck in step %d phase %d" % [state.step, state.phase])


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
			return
	var constant: Dictionary = _constant(p)
	if constant.has("turn_start"):
		_enqueue_keyed(constant.get("turn_start", []), "turn_start", p.index, {}, p.duelist)


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
	if locked != "" and locked != def.school:
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
	if not _relic_available(p):
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
	for a in p.allies():
		_gain_energy(p, a, 1)
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
		_emit(&"combat_skipped", {"player": p.index, "forced": true})
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
	for index in [state.active, state.opposing()]:
		if state.discard_done[index]:
			continue
		var p: PlayerState = state.players[index]
		var keep: int = HAND_KEEP
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
		_end_turn()
		return
	var opts: Array[Command] = [Command.new(p.index, &"recover"), Command.new(p.index, &"no_recover")]
	_set_prompt(p.index, &"recover", opts)


func _handle_recover(cmd: Command) -> void:
	var p: PlayerState = state.active_player()
	if cmd.type == &"recover":
		_recover_top(p, 1)
	_end_turn()


# --- Placement ------------------------------------------------------------

func _can_place(p: PlayerState, c: CardInstance) -> bool:
	var def: CardDef = c.def
	if def.alignment_only != "" and def.alignment_only != p.alignment:
		return false
	match def.type:
		CardDef.Type.ALLY:
			if not (def.raw.get("bond_of", []) as Array).is_empty():
				return false   # Bonds enter play through a Bonding card, never by placement
			if def.character == p.duelist.def.character or def.character == state.players[1 - p.index].duelist.def.character:
				return false
			var aspect: int = def.lowest_aspect()
			if aspect > p.duelist.aspect:
				return false
			var own: CardInstance = _ally_of_character(p, def.character)
			if own != null and own.aspect != aspect - 1:
				return false
			var theirs: CardInstance = _ally_of_character(state.players[1 - p.index], def.character)
			if theirs != null and theirs.aspect == aspect:
				return false
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
			if locked != "" and locked != def.school:
				return false
			for d in p.drills():
				if d.def.id == def.id:
					return false
			return true
		_:
			return false


func _place(p: PlayerState, c: CardInstance) -> void:
	_erase_from_zone(c)
	c.controller = p.index
	match c.def.type:
		CardDef.Type.ALLY:
			var existing: CardInstance = _ally_of_character(p, c.def.character)
			if existing != null:
				_erase_from_zone(existing)
				existing.zone = &"under"
				c.cards_under.append(existing)
				c.energy = CardInstance.MAX_STAGE
			else:
				c.energy = ALLY_STARTING_ENERGY
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
			_resolve_entering(state.active)
			state.phase = GameState.Phase.PREPARE_OPPOSING
		GameState.Phase.PREPARE_OPPOSING:
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
			if p.skip_next_attack_phase:
				p.skip_next_attack_phase = false
				# A skipped phase never happened, so the passes around it are not consecutive.
				state.consecutive_passes = 0
				_emit(&"attack_phase_skipped", {"player": p.index})
				state.phase = GameState.Phase.FIGHT_BACK
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
			for q in state.players:
				for item in q.pending_fight_back:
					var list: Array[Dictionary] = [item["effect"]]
					_queue.append({"effects": list, "index": 0, "trigger": "on_wound", "owner": q.index, "ctx": {}, "source": card(int(item.get("source", -1)))})
				q.pending_fight_back.clear()
			state.attacker = 1 - state.attacker
			state.control_asked = false
			state.phase = GameState.Phase.ATTACK
		_:
			assert(false, "Bad combat phase %d" % state.phase)


func _resolve_entering(player_index: int) -> void:
	var p: PlayerState = state.players[player_index]
	var role: String = "active" if player_index == state.active else "opposing"
	var ctx: Dictionary = {"role": role}
	for c in _in_play_sources(p, true):
		var effects: Array[Dictionary] = []
		for e in c.def.effects_for("entering_combat"):
			var wanted: String = str(e.get("role", ""))
			if wanted == "" or wanted == role:
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
		if str(e.get("trigger", "")) == "entering_combat" and (str(e.get("role", "")) == "" or str(e.get("role", "")) == role):
			pw_effects.append(e)
	if not pw_effects.is_empty():
		_enqueue(pw_effects, "entering_combat", player_index, ctx, ic)
	var constant: Dictionary = _constant(p)
	if constant.has("entering_combat"):
		var ce: Array[Dictionary] = []
		for e in constant.get("entering_combat", []):
			if str(e.get("role", "")) == "" or str(e.get("role", "")) == role:
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
	sources.append_array(p.drills())
	sources.append_array(p.non_combats())
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
		p.reset_combat_flags()
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
func _may_ally_control(p: PlayerState) -> bool:
	if p.allies().is_empty() or _has_floating(p.index, "no_ally_control"):
		return false
	return p.duelist.energy <= ALLY_CONTROL_MAX_ENERGY or bool(_constant(p).get("ally_control_any_stage", false))


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
	if not _may_ally_control(p):
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
				if _can_pay(ic, p, c.def.attack):
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
		if str(c.def.raw.get("remain_by", "")) == "ally" and ic.def.type != CardDef.Type.ALLY:
			continue
		if c.def.is_attack() and _attack_allowed(p, c.def) and _can_pay(ic, p, c.def.attack):
			opts.append(Command.new(p.index, &"attack", c.uid))
	var only_attacks: bool = _forbidden(p, "non_attack_actions")
	if not _forbidden(p, "non_combats") and not only_attacks:
		for c in p.non_combats():
			if not c.def.effects_for("use").is_empty() and _can_play(p, c.def):
				opts.append(Command.new(p.index, &"use", c.uid))
	if not _forbidden(p, "drills") and not only_attacks:
		for c in p.drills():
			if not c.def.effects_for("use").is_empty() and _drill_use_available(c):
				opts.append(Command.new(p.index, &"use", c.uid))
	if p.mastery != null and not only_attacks and not _forbidden(p, "mastery") and not p.mastery.def.effects_for("use").is_empty() and _drill_use_available(p.mastery):
		opts.append(Command.new(p.index, &"use", p.mastery.uid))
	if not only_attacks and _relic_usable_in(p, "combat"):
		opts.append(Command.new(p.index, &"use", p.relic.uid))
	var pw: Dictionary = ic.power()
	if _power_available(p, ic) and not pw.has("defense") and not _forbidden(p, "powers"):
		if pw.has("attack"):
			if _attack_allowed(p, null, str(pw["attack"].get("kind", "strike"))) and _can_pay(ic, p, pw.get("attack", {})):
				opts.append(Command.new(p.index, &"power", ic.uid))
		elif pw.has("effects") and not only_attacks and _has_trigger(pw["effects"], "secondary"):
			opts.append(Command.new(p.index, &"power", ic.uid))
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
	opts.append(Command.new(p.index, &"pass"))
	_set_prompt(p.index, &"attack_action", opts, {"fight_back": p.index != state.active})


func _handle_attack_action(cmd: Command) -> void:
	var p: PlayerState = state.players[cmd.player]
	match cmd.type:
		&"pass":
			_pass(p, false)
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
			if c.zone == &"hand" and c.def.type == CardDef.Type.COMBAT and _open_counter_window(c, "use"):
				return
			_use_card(p, c)
		&"power":
			var ic: CardInstance = card(cmd.card)
			_mark_power_used(ic)
			var pw: Dictionary = ic.power()
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
	if c.def.type == CardDef.Type.RELIC:
		_use_relic(p)
	elif c.zone == &"hand":
		_erase_from_zone(c)
		c.zone = &"resolving"
		_emit(&"card_used", {"player": p.index, "card": c.uid, "id": c.def.id})
		if c.def.type == CardDef.Type.COMBAT:
			p.combat_cards_used_combat = state.combat_count
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
		if fetched != null and fetched.zone == &"hand" and _attack_allowed(p, fetched.def) and _can_pay(p.in_control(), p, fetched.def.attack):
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
	state.attack = _build_attack(att, source, spec, effects, is_power, is_final, empowered, performer, attacker.attack_count_combat == 1)
	state.last_attack = {}
	state.consecutive_passes = 0
	state.battle_step = 2
	state.phase = GameState.Phase.BATTLE
	_emit(&"attack_declared", {
		"player": att, "kind": state.attack["kind"], "source": state.attack["source"],
		"is_power": is_power, "is_final": is_final, "focused": state.attack["focused"], "empowered": empowered,
	})
	var constant: Dictionary = _constant(attacker)
	if constant.has("on_attack"):
		_enqueue_keyed(constant.get("on_attack", []), "on_attack", att, {"attack": state.attack}, attacker.in_control())
	if attacker.mastery != null and not _forbidden(attacker, "mastery"):
		_enqueue(attacker.mastery.def.effects, "on_attack", att, {"attack": state.attack}, attacker.mastery)


## The attack record for `att` attacking with `spec`, with the card's conditional lines merged
## and every standing effect on the attacker folded in. Reads state and changes nothing, so a
## forecast can build the same record the battle sequence will.
func _build_attack(att: int, source: CardInstance, spec: Dictionary, effects: Array[Dictionary], is_power: bool, is_final: bool, empowered: bool, performer: CardInstance, first_attack: bool) -> Dictionary:
	var attacker: PlayerState = state.players[att]
	if performer == null:
		performer = attacker.in_control()
	var kind: String = str(spec.get("kind", "strike"))
	var used: Array[Dictionary] = []
	for e in effects:
		if empowered and bool(e.get("after_empower", false)):
			continue
		used.append(e)
	# Conditional lines on the card ("if X is in control, +3 stages and focused").
	if spec.has("variants"):
		var merged: Dictionary = spec.duplicate(true)
		merged.erase("variants")
		for v in spec["variants"]:
			if not _cond(v.get("when", {}), att, {}):
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
		for d in attacker.drills():
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
	var focused: bool = bool(spec.get("focused", false))
	var constant: Dictionary = _constant(attacker)
	if bool(constant.get("attacks_focused", false)):
		focused = true
	if source != null and _has_floating_school(att, "make_focused", source.def.school):
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
		"life_remaining": 0,
		"stages_dealt": 0,
		"life_dealt": 0,
		"target": -1,
		"no_prevent": bool(spec.get("no_prevent", false)) or _has_floating(att, "no_prevent"),
		"damage_removes": bool(constant.get("damage_removes", false)) or _has_floating(att, "damage_removes") or _attachment_removes(attacker, source),
	}


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
				if c == null or not c.power().has("attack"):
					continue
				var effects: Array[Dictionary] = []
				effects.assign(c.power().get("effects", []))
				a = _build_attack(seat, c, c.power()["attack"], effects, true, false, false, c, first)
			&"final_strike":
				if out.has(o.card):
					continue   # the card's own attack is the number that matters
				a = _build_attack(seat, null, {"kind": "strike"}, [], false, true, false, null, first)
			_:
				continue
			# Costs come off before the Strike Table is read, so the forecast pays them first.
		var performer: CardInstance = _performer(a)
		var cost: int = _cost_stages(a["spec"], state.players[seat])
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


## An attached card can say "wounds from your Sword attacks are removed from the game".
func _attachment_removes(p: PlayerState, source: CardInstance) -> bool:
	for at in p.attachments():
		if at.attached_to != p.in_control() or not bool(at.def.attachment.get("damage_removes", false)):
			continue
		var needle: String = str(at.def.attachment.get("title_contains", ""))
		if needle == "" or (source != null and source.def.title.contains(needle)):
			return true
	return false


# --- Counter window ("stops the effects of any Combat card") ---------------

## Returns true when the opponent gets to respond before the Combat card resolves.
func _open_counter_window(c: CardInstance, mode: String) -> bool:
	var owner: PlayerState = state.players[c.owner]
	var opp: PlayerState = state.players[1 - owner.index]
	var opts: Array[Command] = []
	for k in opp.hand:
		if k.def.counter == "combat" and _can_play(opp, k.def) and not _forbidden(opp, "combat_cards"):
			opts.append(Command.new(opp.index, &"counter", k.uid))
	if opts.is_empty():
		return false
	opts.append(Command.new(opp.index, &"decline"))
	state.pending_play = {"card": c.uid, "mode": mode}
	_set_prompt(opp.index, &"respond", opts, {"card": c.uid, "mode": mode, "source": c.uid, "card_title": c.def.title})
	return true


func _handle_respond(cmd: Command) -> void:
	var pending: Dictionary = state.pending_play
	state.pending_play = {}
	var mode: String = str(pending.get("mode", "use"))
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
			_enqueue(a["effects"], "secondary", attacker.index, {"attack": a}, _attack_source())
			state.battle_step = 4
		4:
			if _may_ally_control(defender):
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
				_emit(&"attack_successful", {"player": attacker.index})
				_enqueue(a["effects"], "before_damage", attacker.index, {"attack": a}, _attack_source())
				state.battle_step = 9
		9:
			_base_damage(attacker, defender, a)
			state.battle_step = 10
		10:
			_modify_damage(attacker, defender, a)
			state.battle_step = 11
		11:
			# An in-control Ally with the capture trait may take a Seal instead of dealing the damage.
			var performer: CardInstance = _performer(a)
			var has_damage: bool = int(a["stages"]) > 0 or int(a["life"]) > 0
			if performer.def.type == CardDef.Type.ALLY and performer.def.capture_trait and has_damage and not _capturable_seals(defender).is_empty():
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
				var allies: Array[CardInstance] = defender.allies()
				if not allies.is_empty() and (int(a["stages"]) > 0 or int(a["life"]) > 0) and not _has_floating(defender.index, "no_ally_control"):
					var opts: Array[Command] = [Command.new(defender.index, &"target", defender.in_control().uid)]
					for al in allies:
						if al != defender.in_control():
							opts.append(Command.new(defender.index, &"target", al.uid))
					# The only Ally is the one in control: nothing to redirect to, so no stop.
					if opts.size() > 1:
						_set_prompt(defender.index, &"redirect", opts, {"source": int(a.get("source", -1))})
						return
				a["target"] = defender.in_control().uid
			_deal_stage_damage(defender, a)
			state.battle_step = 13
		13:
			_deal_life_damage(defender, a)
		14:
			# Critical damage: 5+ life cards let the attacker capture a Seal, discard an Ally, or lower Fervor.
			if int(a["life_dealt"]) >= CRITICAL_THRESHOLD:
				var opts: Array[Command] = []
				for t in _capturable_seals(defender):
					opts.append(Command.new(attacker.index, &"capture", t.uid))
				# A game rule, not a card effect: Ally protection constants do not apply.
				for al in defender.allies():
					opts.append(Command.new(attacker.index, &"discard_ally", al.uid))
				if defender.fervor > 0:
					opts.append(Command.new(attacker.index, &"lower_fervor"))
				if not opts.is_empty():
					opts.append(Command.new(attacker.index, &"no_critical"))
					_set_prompt(attacker.index, &"critical", opts, {"life_dealt": int(a["life_dealt"]), "source": int(a.get("source", -1))})
					state.battle_step = 15
					return
			state.battle_step = 15
		15:
			_enqueue(a["effects"], "if_successful", attacker.index, {"attack": a}, _attack_source())
			if attacker.mastery != null and not _forbidden(attacker, "mastery"):
				_enqueue(attacker.mastery.def.effects, "on_success", attacker.index, {"attack": a}, attacker.mastery)
			# A Non-Combat in play that answers a successful attack. It spends itself in its own text.
			if not _forbidden(attacker, "non_combats"):
				for nc in attacker.non_combats():
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
	var cost_stages: int = _cost_stages(spec, attacker)
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
		# "Pay any number of stages, +1 wound per N paid."
		var per: int = maxi(1, int(spec["pay_stages"].get("per", 2)))
		var opts: Array[Command] = []
		var amount: int = 0
		while amount <= ic.energy:
			opts.append(Command.new(attacker.index, &"pay", -1, amount))
			amount += per
		if opts.size() > 1:
			var src: CardInstance = _attack_source()
			_set_prompt(attacker.index, &"pay", opts, {"per": per, "source": src.uid if src != null else -1, "card_title": src.def.title if src != null else ""})


func _handle_pay(cmd: Command) -> void:
	if str(_choice.get("kind", "")) == "pay_energy":
		_handle_pay_energy(cmd)
		return
	var a: Dictionary = state.attack
	var attacker: PlayerState = state.players[int(a["attacker"])]
	var spec: Dictionary = a["spec"]
	var paid: int = int(cmd.value)
	var per: int = maxi(1, int(spec["pay_stages"].get("per", 2)))
	var ic: CardInstance = _performer(a)
	ic.energy = maxi(0, ic.energy - paid)
	a["extra_life"] = int(a["extra_life"]) + int(paid / per) * int(spec["pay_stages"].get("life", 1))
	_emit(&"cost_paid", {"player": attacker.index, "stages": paid, "life": 0, "energy": ic.energy})
	state.battle_step = 3


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


func _cost_stages(spec: Dictionary, p: PlayerState) -> int:
	var base: int = 0
	if spec.has("cost_stages"):
		base = int(spec["cost_stages"])
	elif str(spec.get("kind", "")) == "art":
		base = ART_COST
	if str(spec.get("kind", "")) == "art":
		var delta: int = _art_cost_delta(p)
		base = maxi(1, base + delta) if (delta < 0 and base > 0) else base + delta
	var tax: Dictionary = _floating_first(p.index, "next_attack_tax")
	if not tax.is_empty():
		base += int(tax.get("stages", 0))
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


func _can_pay(ic: CardInstance, p: PlayerState, spec: Dictionary) -> bool:
	var cost: int = _cost_stages(spec, p)
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
	var opts: Array[Command] = []
	for c in d.hand:
		if _defense_usable(d, c, kind, focused):
			opts.append(Command.new(d.index, &"defend", c.uid))
	for c in d.remain_cards():
		if _defense_usable(d, c, kind, focused):
			opts.append(Command.new(d.index, &"defend", c.uid))
	for c in d.non_combats():
		if _defense_usable(d, c, kind, focused):
			opts.append(Command.new(d.index, &"defend", c.uid))
	for c in d.drills():
		if _defense_usable(d, c, kind, focused):
			opts.append(Command.new(d.index, &"defend", c.uid))
	var ic: CardInstance = d.in_control()
	var pw: Dictionary = ic.power()
	if _power_available(d, ic) and not _forbidden(d, "powers") and CardDef.defense_stops(pw.get("defense", {}), kind, focused):
		opts.append(Command.new(d.index, &"power_defend", ic.uid))
	if opts.is_empty():
		_emit(&"no_defense", {"player": d.index, "auto": true, "reason": "none"})
		state.phase = GameState.Phase.BATTLE
		return
	opts.append(Command.new(d.index, &"no_defense"))
	_set_prompt(d.index, &"defense", opts, {"kind": kind, "focused": focused, "source": int(a.get("source", -1))})


func _defense_usable(d: PlayerState, c: CardInstance, kind: String, focused: bool) -> bool:
	var def: CardDef = c.def
	if not def.is_defense():
		return false
	if def.is_end_combat_card():
		return false   # cards that end Combat can only be played as an attack action
	if str(def.raw.get("use_at", "")) != "":
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
	if not def.stops_kind(kind, focused):
		return false
	var blocked: String = str(state.attack.get("spec", {}).get("no_stop_by", ""))
	if blocked != "" and int(CardDef.TYPE_NAMES.get(blocked, -2)) == def.type:
		return false
	if focused and str(def.defense.get("stop_focused", "")) == "discard_hand" and d.hand.size() < 2:
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
		&"no_defense":
			_emit(&"no_defense", {"player": d.index, "auto": false})
			state.phase = GameState.Phase.BATTLE


func _play_defense(d: PlayerState, c: CardInstance) -> void:
	var a: Dictionary = state.attack
	var def: CardDef = c.def
	var from_hand: bool = c.zone == &"hand"
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
		if int(f.get("owner", -1)) != defender.index:
			continue
		var op: String = str(f.get("op", ""))
		if op == "stop_next":
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
		if int(f.get("owner", -1)) != defender.index or str(f.get("op", "")) != "stop_all":
			continue
		var fk: String = str(f.get("kind", "any"))
		if (fk == kind or (fk == "any" and not focused)) and not unstoppable:
			_register_stop(a)
			_note_stop(a, null, "floating")
			_emit(&"floating_stop", {"player": defender.index, "kind": fk})
			if bool(a["stopped"]):
				return
	var next_stop: Dictionary = _floating_first(defender.index, "stop_next")
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
	for d in defender.drills():
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
	var no_prevent: bool = bool(a.get("no_prevent", false))
	var prevented: bool = bool(a.get("prevented_all", false)) or (_has_floating(defender.index, "prevent_all") and not no_prevent)
	var src: CardInstance = card(int(a.get("source", -1)))
	var src_title: String = src.def.title if src != null else ac.def.title
	var adds: Array[Dictionary] = []   # {source, stages, life}; against-modifiers carry negatives
	if int(spec.get("stages", 0)) != 0 or int(spec.get("life", 0)) != 0:
		adds.append({"source": src_title, "stages": int(spec.get("stages", 0)), "life": int(spec.get("life", 0))})
	if int(a.get("extra_life", 0)) > 0:
		adds.append({"source": "Energy paid", "stages": 0, "life": int(a["extra_life"])})
	if bool(a["empowered"]) and src != null and src.def.empower > 0:
		adds.append({"source": "Empower", "stages": 0, "life": src.def.empower})
	if int(spec.get("life_per_ally", 0)) > 0 and not attacker.allies().is_empty():
		adds.append({"source": "%d Allies" % attacker.allies().size(), "stages": 0, "life": int(spec["life_per_ally"]) * attacker.allies().size()})
	if bool(spec.get("life_from_surge", false)) and attacker.duelist.surge() > 0:
		adds.append({"source": "Surge", "stages": 0, "life": attacker.duelist.surge()})
	if int(spec.get("life_per_opponent_seal", 0)) > 0 and not defender.seals().is_empty():
		adds.append({"source": "Rival Seals", "stages": 0, "life": int(spec["life_per_opponent_seal"]) * defender.seals().size()})
	if spec.has("life_per_set_seal") and _set_seals_in_play(str(spec["life_per_set_seal"])) > 0:
		adds.append({"source": "%s Seals in play" % str(spec["life_per_set_seal"]).capitalize(), "stages": 0, "life": _set_seals_in_play(str(spec["life_per_set_seal"]))})
	var ctx: Dictionary = {"attack": a}
	var spent: Array[Dictionary] = []
	# "Cannot be reduced": the defender's reductions and caps are ignored; prevention is separate.
	var no_reduce: bool = bool(spec.get("no_reduce", false)) or _has_floating(attacker.index, "no_reduce")
	var multiply: int = 1
	var multiply_source: String = ""
	for entry in _modifiers_for(attacker, "own", kind, src, ctx):
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
	if kind == "art" and _has_floating(defender.index, "prevent_art_life") and not no_prevent:
		adds.append({"source": "Art wounds prevented", "stages": 0, "life": -life})
		life = 0
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
	return n


## Modifiers from Drills, Mastery, Grounds, attachments, floating effects, and constant powers,
## each as {m: the modifier, source: the card it sits on, null for a floating effect}.
func _modifiers_for(p: PlayerState, scope: String, kind: String, src: CardInstance, ctx: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var pools: Array = []
	for d in p.drills():
		pools.append([d.def.modifiers, d])
	if p.mastery != null and not _forbidden(p, "mastery"):
		pools.append([p.mastery.def.modifiers, p.mastery])
	if state.grounds != null:
		pools.append([state.grounds.def.modifiers, state.grounds])
	for at in p.attachments():
		if scope == "own" and at.attached_to == p.in_control():
			pools.append([at.def.attachment.get("modifiers", []), at])
	var constant: Dictionary = _constant(p)
	if constant.has("modifiers"):
		pools.append([constant.get("modifiers", []), p.duelist])
	for f in state.floating:
		if int(f.get("owner", -1)) == p.index and str(f.get("op", "")) == "modifier":
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
			if m.has("title_contains") and (src == null or not src.def.title.contains(str(m["title_contains"]))):
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
		if _only_seals_left(defender):
			_lose(defender.index, "survival")
			return
		var c: CardInstance = _flip_life_card(defender)
		if c == null:
			return
		if c.def.type == CardDef.Type.SEAL:
			_bypass_seal(c)
			continue
		if bool(a["damage_removes"]):
			_remove_from_game(c)
		else:
			_move_to_discard(c)
		_on_wound(defender, c)
		a["life_remaining"] = int(a["life_remaining"]) - 1
		a["life_dealt"] = int(a["life_dealt"]) + 1
		_emit(&"life_card_flipped", {"player": defender.index, "card": c.uid, "id": c.def.id, "remaining": a["life_remaining"]})
		var endurance: int = _endurance_value(c, defender)
		if endurance > 0 and int(a["life_remaining"]) > 0 and not bool(a["no_prevent"]) and not _has_floating(defender.index, "no_endurance"):
			var opts: Array[Command] = [Command.new(defender.index, &"endure", c.uid), Command.new(defender.index, &"no_endure", c.uid)]
			_set_prompt(defender.index, &"endurance", opts, {"card": c.uid, "endurance": endurance, "remaining": a["life_remaining"]})
			return
	state.battle_step = 14


func _endurance_value(c: CardInstance, p: PlayerState) -> int:
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


func _finish_attack(attacker: PlayerState, a: Dictionary) -> void:
	if bool(a["stopped"]):
		_enqueue(a["effects"], "if_stopped", attacker.index, {"attack": a}, _attack_source())
	var src: CardInstance = _attack_source()
	if src != null and not bool(a["is_power"]):
		_enqueue([{"trigger": "secondary", "op": "finish_source", "empowered": bool(a["empowered"])}], "secondary", attacker.index, {"attack": a}, src)
	if bool(a["is_final"]):
		attacker.must_pass = true
	# The outcome outlives `state.attack`, which the after_attack op clears before the next prompt.
	var stopped_by: Dictionary = a.get("stopped_by", {})
	# The titles are taken now, while the cards are still on the table. Read later off the card they
	# would drift, because the source may be back in a hidden zone by then and a simulation gives a
	# hidden card a different identity.
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


## "You may ..." lines ask their owner first; a yes re-queues the effect as confirmed.
func _prompt_may(e: Dictionary, owner: int, ctx: Dictionary, source: CardInstance) -> void:
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
func _prompt_rearrange(p: PlayerState, uids: Array[int], from: String, placed: int = 0) -> void:
	var left: Array[int] = []
	for uid in uids:
		var c: CardInstance = card(uid)
		if c != null and c.zone == &"life_deck":
			left.append(uid)
	if left.size() <= 1:
		_emit(&"rearranged", {"player": p.index, "count": placed + left.size()})
		return
	var opts: Array[Command] = []
	for uid in left:
		opts.append(Command.new(p.index, &"pick_option", uid))
	_choice = {"kind": "rearrange", "player": p.index, "uids": left, "from": from, "placed": placed}
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
				_gain_energy(who, target, int(amount))
			elif bool(e.get("no_overflow", false)):
				target.energy = maxi(0, target.energy + int(amount))
			else:
				_lose_energy(who, target, -int(amount))
			if target.energy != before:
				# Logged with its source, so two effects landing in one update read as two lines.
				_emit(&"energy_changed", {"player": who_index, "card": target.uid, "from": before, "to": target.energy, "source": source.uid if source != null else -1})
		"draw":
			_draw(who_index, int(amount))
		"draw_until":
			while who.hand.size() < int(amount) and not state.is_over():
				if who.life_deck.is_empty():
					_lose(who_index, "survival")
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
			_discard_life(who, int(amount))
		"discard_hand":
			var chooser: int = owner if str(e.get("chooser", "")) == "owner" else who_index
			var to: String = str(e.get("to", "discard"))
			var filter: String = str(e.get("filter", ""))
			var pool: Array[CardInstance] = _hand_filtered(who, filter)
			if pool.is_empty():
				_pending_then = {}
			elif bool(e.get("random", true)) and to == "discard":
				for i in range(mini(int(amount), pool.size())):
					var c: CardInstance = pool[rng.randi_range(0, pool.size() - 1)]
					pool.erase(c)
					_move_to_discard(c)
					_emit(&"hand_discarded", {"player": who.index, "card": c.uid, "random": true})
			elif pool.size() == 1 and to == "discard":
				_move_to_discard(pool[0])
				_emit(&"hand_discarded", {"player": who.index, "card": pool[0].uid, "random": false})
			else:
				_prompt_discard_choice(who, int(amount), chooser, to, filter)
		"pay_energy":
			var per: int = maxi(1, int(e.get("per", 1)))
			var payer: CardInstance = who.in_control()
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
			_look_at(who, e)
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
			var target: CardInstance = who.duelist if str(e.get("target", "duelist")) == "duelist" else who.in_control()
			var before: int = target.energy
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
			if matched:
				_enqueue(e.get("effects", []), "secondary", owner, ctx, source)
			elif e.has("else_effects"):
				_enqueue(e.get("else_effects", []), "secondary", owner, ctx, source)
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
			# front of the chooser rather than taking the top N off the back.
			if bool(e.get("choose", false)) and not who.discard.is_empty() and not bool(e.get("all", false)):
				_choice = {"kind": "pick_discard", "target": who_index, "remaining": int(amount)}
				_prompt_pick_discard(owner, who, int(amount), bool(e.get("up_to", false)))
				return
			_remove_discard(who, int(amount), bool(e.get("all", false)))
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
		"shuffle_discard":
			var count: int = int(amount) * (who.allies().size() + 1 if bool(e.get("per_personality", false)) else 1)
			_shuffle_discard_into_deck(who, count, bool(e.get("all", false)), str(e.get("from", "top")), str(e.get("school", "")))
		"recover":
			_recover_top(who, int(amount), str(e.get("from", "top")))
		"end_combat":
			if not _forbidden(me, "end_combat"):
				_combat_ending = true
				_emit(&"flag_set", {"player": owner, "flag": "end_combat", "source": source.uid if source != null else -1})
		"skip_next_attack_phase":
			who.skip_next_attack_phase = true
			_emit(&"flag_set", {"player": who_index, "flag": "skip_next_attack_phase", "source": source.uid if source != null else -1})
		"cannot_declare_combat":
			who.cannot_declare_combat = true
			_emit(&"flag_set", {"player": who_index, "flag": "cannot_declare_combat", "source": source.uid if source != null else -1})
		"stop_all":
			_float(owner, "stop_all", str(e.get("duration", "combat")), {"kind": str(e.get("kind", "any")), "source": source.uid if source != null else -1})
		"float":
			var params: Dictionary = (e.get("params", {}) as Dictionary).duplicate()
			if source != null:
				params["source"] = source.uid   # so a floating modifier can say which card it came from
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
			_prompt_name_card(me, source)
		"next_attack_tax":
			_float(who_index, "next_attack_tax", "combat", {"stages": int(amount)})
		"copy_attack":
			pass
		"spend_source":
			if source != null and source.zone == &"in_play" and source.def.type == CardDef.Type.NON_COMBAT:
				_finish_card(source, false)
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
				if me.duelist.def.character != str(v):
					return false
			"alignment":
				if me.alignment != str(v):
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
			"aspect_min":
				if me.duelist.aspect < int(v):
					return false
			"opponent_fervor":
				if opp.fervor != int(v):
					return false
			"allies_min":
				if me.allies().size() < int(v):
					return false
			"ally_present":
				if _ally_of_character(me, str(v)) == null:
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
			"discard_min":
				if me.discard.size() < int(v):
					return false
			"discard_top2_school":
				if me.discard.size() < 2 or me.discard.back().def.school != str(v) or me.discard[me.discard.size() - 2].def.school != str(v):
					return false
			"higher_might":
				if (me.in_control().might() > opp.in_control().might()) != bool(v):
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
			"stopped_last_phase":
				if _has_floating(owner, "stopped_last") != bool(v):
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
			_:
				push_warning("DuelEngine: unknown condition '%s'" % key)
	return true


# --- Floating effects, forbids, constants ---------------------------------

func _float(owner: int, op: String, duration: String, params: Dictionary = {}) -> void:
	var f: Dictionary = {"owner": owner, "op": op, "duration": duration}
	for k in params.keys():
		f[k] = params[k]
	if duration == "next_turn_end":
		f["expires_turn"] = state.turn + (2 if state.active == owner else 1)
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
		keep.append(f)
	state.floating = keep


func _has_floating(owner: int, op: String) -> bool:
	for f in state.floating:
		if int(f.get("owner", -1)) == owner and str(f.get("op", "")) == op:
			return true
	return false


func _has_floating_school(owner: int, op: String, school: String) -> bool:
	for f in state.floating:
		if int(f.get("owner", -1)) == owner and str(f.get("op", "")) == op and (str(f.get("school", "")) == "" or str(f.get("school", "")) == school):
			return true
	return false


func _floating_first(owner: int, op: String) -> Dictionary:
	for f in state.floating:
		if int(f.get("owner", -1)) == owner and str(f.get("op", "")) == op:
			return f
	return {}


## Standing restrictions on a player from floating forbids, Grounds, Drills, and the opponent's constant power.
func _forbidden(p: PlayerState, what: String) -> bool:
	for f in state.floating:
		if int(f.get("owner", -1)) == p.index and str(f.get("op", "")) == "forbid" and str(f.get("what", "")) == what:
			if int(f.get("unless_energy_min", 0)) > 0 and p.duelist.energy >= int(f["unless_energy_min"]):
				continue
			return true
	var sources: Array[CardInstance] = []
	if state.grounds != null:
		sources.append(state.grounds)
	for q in state.players:
		sources.append_array(q.drills())
		sources.append_array(q.non_combats())
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
		for d in q.drills():
			if d.named_card != "" and d.named_card == def.title:
				return true
	return false


## The constant power in force for a player: the in-control personality's, or the duelist's
## when its constant says allies share it.
func _constant(p: PlayerState) -> Dictionary:
	if _forbidden(p, "powers"):
		return {}
	return _raw_constant(p)


func _raw_constant(p: PlayerState) -> Dictionary:
	var fc: Dictionary = p.duelist.aspect_data().get("constant", {})
	if p.in_control() == p.duelist or bool(fc.get("allies_share", false)):
		return fc
	return p.in_control().aspect_data().get("constant", {})


func _can_play(p: PlayerState, def: CardDef) -> bool:
	if def.alignment_only != "" and def.alignment_only != p.alignment:
		return false
	if not def.only.is_empty():
		if def.only.has("character") and p.in_control().def.character != str(def.only["character"]):
			# The gated personality must be in control, except for a card that attaches to that
			# personality: it only needs them on the table.
			if not (_attaches_to_character(def) and _character_in_play(p, str(def.only["character"])) != null):
				return false
		if def.only.has("duelist_character") and p.duelist.def.character != str(def.only["duelist_character"]):
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
			_:
				return p.duelist
	return null


# --- Choice prompts raised by effects -------------------------------------

func _prompt_discard_choice(target: PlayerState, amount: int, chooser: int = -1, to: String = "discard", filter: String = "") -> void:
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
		_gain_energy(p, target, int(amount))
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
func _hand_filtered(p: PlayerState, filter: String) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for c in p.hand:
		match filter:
			"signature":
				if c.def.character != "" and c.def.character == p.duelist.def.character:
					out.append(c)
			"non_seal":
				if c.def.type != CardDef.Type.SEAL:
					out.append(c)
			_:
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


## Look at the top or bottom N cards; the owner may take one matching card into hand or play.
func _look_at(p: PlayerState, e: Dictionary) -> void:
	var n: int = mini(int(e.get("amount", 1)), p.life_deck.size())
	var from: String = str(e.get("from", "top"))
	var to: String = str(e.get("to", "hand"))
	var pick: Dictionary = e.get("pick", {})
	var rearrange: bool = bool(e.get("rearrange", false))
	var opts: Array[Command] = []
	var looked: Array[int] = []
	for i in range(n):
		var c: CardInstance = p.life_deck[i] if from == "top" else p.life_deck[p.life_deck.size() - 1 - i]
		looked.append(c.uid)
		if (e.has("pick") or not rearrange) and _search_matches(p, c, pick, to):
			opts.append(Command.new(p.index, &"pick_option", c.uid))
	_emit(&"look_at", {"player": p.index, "count": n, "from": from})
	if opts.is_empty():
		if rearrange:
			_prompt_rearrange(p, looked, from)
		return
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
	if e.has("stages"):
		take["stages"] = e["stages"]
	if e.has("play_if"):
		take["play_if"] = e["play_if"]
	if bool(e.get("shuffle_after", false)):
		take["shuffle_after"] = true
	_choice = {"kind": "look_at", "player": p.index, "effect": take}
	var ctx: Dictionary = _choice_context(_effect_source, "look_at")
	ctx["to"] = to
	_set_prompt(p.index, &"pick_option", opts, ctx)


func _draw_check_matches(p: PlayerState, drawn: CardInstance, e: Dictionary) -> bool:
	match str(e.get("check", "school")):
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
	var candidates: Array[CardInstance] = _in_play_candidates(target, type_name)
	if str(e.get("who", "")) == "any":
		# "Remove a Seal in play": either side's, so the pool is both and the chooser decides.
		candidates = _in_play_candidates(state.players[owner], type_name)
		candidates.append_array(_in_play_candidates(state.players[1 - owner], type_name))
	if candidates.is_empty():
		return
	var chooser: int = owner if str(e.get("chooser", "owner")) == "owner" else target.index
	if bool(e.get("choose", false)) and candidates.size() > amount:
		_choice = {"kind": "pick_in_play", "remaining": amount, "remove": remove, "type": type_name, "target": target.index, "chooser": chooser, "up_to": bool(e.get("up_to", false))}
		_prompt_pick_in_play(chooser, candidates, amount, bool(e.get("up_to", false)))
		return
	var n: int = 0
	for i in range(candidates.size() - 1, -1, -1):
		if n >= amount:
			break
		_discard_or_remove_in_play(candidates[i], remove)
		n += 1


func _in_play_candidates(p: PlayerState, type_name: String) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for c in p.in_play:
		if c.remain > 0:
			continue
		var t: CardDef.Type = c.def.type
		var ok: bool = false
		match type_name:
			"non_combat":
				ok = t == CardDef.Type.NON_COMBAT or (t == CardDef.Type.DRILL and not _drills_protected(p)) or c.attached_to != null
			"non_combat_only":
				ok = t == CardDef.Type.NON_COMBAT and c.attached_to == null
			"drill":
				ok = t == CardDef.Type.DRILL and not _drills_protected(p)
			"freestyle_drill":
				ok = t == CardDef.Type.DRILL and c.def.school == ""
			"ally":
				ok = t == CardDef.Type.ALLY and not _ally_protected(p)
			"seal":
				ok = t == CardDef.Type.SEAL
			"non_combat_or_ally":
				ok = t == CardDef.Type.NON_COMBAT or (t == CardDef.Type.DRILL and not _drills_protected(p)) or (t == CardDef.Type.ALLY and not _ally_protected(p))
			"drill_or_ally":
				ok = (t == CardDef.Type.DRILL and not _drills_protected(p)) or (t == CardDef.Type.ALLY and not _ally_protected(p))
			_:
				ok = t != CardDef.Type.SEAL   # Seals are immune to card effects unless named
		if ok:
			out.append(c)
	return out


func _ally_protected(p: PlayerState) -> bool:
	return bool(_constant(p).get("protect_allies", false))


func _drills_protected(p: PlayerState) -> bool:
	return p.mastery != null and bool(p.mastery.def.raw.get("protect_drills", false)) and not _forbidden(p, "mastery")


## The Seals an opponent may capture from `p`: none while a Drill of theirs guards them.
func _capturable_seals(p: PlayerState) -> Array[CardInstance]:
	var none: Array[CardInstance] = []
	if not _forbidden(p, "drills"):
		for d in p.drills():
			if bool(d.def.raw.get("protect_seals", false)):
				return none
	return p.seals()


func _discard_or_remove_in_play(c: CardInstance, remove: bool) -> void:
	_emit(&"in_play_discarded", {"player": c.controller, "card": c.uid, "removed": remove})
	if remove:
		_remove_from_game(c)
	else:
		_move_to_discard(c)


func _prompt_name_card(p: PlayerState, source: CardInstance) -> void:
	var titles: Dictionary = {}
	for c in _cards.values():
		if c.owner != p.index and not c.def.is_personality() and c.def.type != CardDef.Type.SEAL and c.def.type != CardDef.Type.MASTERY and c.def.type != CardDef.Type.RELIC:
			titles[c.def.title] = true
	var names: Array = titles.keys()
	names.sort()
	if names.is_empty() or source == null:
		return
	var opts: Array[Command] = []
	for n in names:
		opts.append(Command.new(p.index, &"name_card", source.uid, n))
	_choice = {"kind": "name_card", "source": source.uid}
	_set_prompt(p.index, &"name_card", opts)


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


## Context for a choice raised mid-effect: the card asking and what the pick is for, so the
## prompt can be titled and the card shown without the client knowing the effect.
func _choice_context(source: CardInstance, purpose: String) -> Dictionary:
	return {"purpose": purpose, "source": source.uid if source != null else -1, "card_title": source.def.title if source != null else ""}


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
			var take: Dictionary = (_choice["effect"] as Dictionary).duplicate(true)
			if cmd.type != &"pick_none":
				var picked: CardInstance = card(cmd.card)
				if take.has("play_if") and _search_matches(looker, picked, take["play_if"], "play"):
					take["to"] = "play"
				_search_take(looker, picked, take)
			if bool(take.get("shuffle_after", false)) and shuffle_decks:
				rng.shuffle(looker.life_deck)
			elif bool(take.get("rearrange", false)):
				var looked: Array[int] = []
				looked.assign(take.get("looked", []))
				_choice = {}
				_prompt_rearrange(looker, looked, str(take.get("from", "top")))
				if prompt != null:
					return
		"rearrange":
			var p: PlayerState = state.players[int(_choice["player"])]
			var placed: int = int(_choice["placed"])
			var from: String = str(_choice["from"])
			_place_rearranged(p, card(cmd.card), from, placed)
			var rest: Array[int] = []
			for uid in _choice["uids"]:
				if int(uid) != cmd.card:
					rest.append(int(uid))
			_choice = {}
			_prompt_rearrange(p, rest, from, placed + 1)
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
					var rest: Array[CardInstance] = _search_distinct(_search_candidates(searcher, search_effect))
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
				_prompt_discard_choice(target, remaining, cmd.player, to, str(_choice.get("filter", "")))
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
			var lifted: PlayerState = state.players[int(_choice["player"])]
			var e2: Dictionary = _choice["effect"]
			_set_personality_energy(lifted, card(cmd.card), e2, e2.get("amount", 0), null)
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
			for uid in picked:
				_discard_or_remove_in_play(card(uid), bool(_choice.get("remove", false)))
			var remaining: int = int(_choice.get("remaining", 1)) - picked.size()
			var target: PlayerState = state.players[int(_choice.get("target", 0))]
			var rest: Array[CardInstance] = _in_play_candidates(target, str(_choice.get("type", "non_combat")))
			if remaining > 0 and not rest.is_empty():
				_choice["remaining"] = remaining
				_prompt_pick_in_play(cmd.player, rest, remaining, bool(_choice.get("up_to", false)))
				return
		"name_card":
			var src: CardInstance = card(cmd.card)
			if src != null:
				src.named_card = str(cmd.value)
				_emit(&"card_named", {"player": cmd.player, "card": src.uid, "name": src.named_card})
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
	return p.duelist.surge() + STYLE_SURGE_BONUS


func aspect_shielded(p: PlayerState) -> bool:
	return p.relic != null and bool(p.relic.def.relic_flags.get("aspect_shield", false))


## A standing effect is swallowing every Energy gain this player would make.
func energy_blocked(p: PlayerState) -> bool:
	return _has_floating(p.index, "no_gain")


## What taking this option would leave of the attack in the air: `life` is the life cards this
## player would still lose. Clients preview it against the current number while the player hovers
## a choice, so the maths is answered here once rather than guessed at on every seat. {} when the
## outcome is not something that can be promised ahead of the roll of the rest of the sequence.
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
			var life: int = int(damage_breakdown(a).get("wounds", 0))
			if cmd.type == &"no_defense":
				return {"life": life}
			# A stop only takes the attack to nothing when it is the one the attack still needs.
			var stops: int = int(a.get("stop_count", 0)) + 1
			return {"life": 0 if stops >= int(a.get("stops_needed", 1)) else life}
	return {}


## Standing forbids in force on the player right now, as forbid `what` words.
func restrictions(p: PlayerState) -> Array[String]:
	var out: Array[String] = []
	for what in FORBID_KINDS:
		if _forbidden(p, what):
			out.append(what)
	return out


func _change_fervor_needed(p: PlayerState, value: int) -> void:
	var before: int = p.fervor_needed
	p.fervor_needed = maxi(1, value)
	_emit(&"fervor_needed_changed", {"player": p.index, "from": before, "to": p.fervor_needed})
	_check_aspect_up(p)


func _change_fervor(p: PlayerState, delta: int, source_owner: int) -> void:
	if delta < 0 and source_owner != p.index and fervor_shielded(p):
		_emit(&"fervor_shielded", {"player": p.index})
		return
	if delta > 0:
		delta *= fervor_gain(p)
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
	if value < p.fervor and source_owner != p.index and fervor_shielded(p):
		_emit(&"fervor_shielded", {"player": p.index})
		return
	var before: int = p.fervor
	p.fervor = maxi(0, value)
	_emit(&"fervor_changed", {"player": p.index, "from": before, "to": p.fervor, "source": _effect_source.uid if _effect_source != null else -1})
	_check_aspect_up(p)


func fervor_shielded(p: PlayerState) -> bool:
	return p.relic != null and bool(p.relic.def.relic_flags.get("fervor_shield", false))


## Full Fervor raises the duelist an aspect. At the duelist's own top aspect it is the Ascension win;
## a forbidden Ascension win falls back to the old peak (full Energy, Fervor to 0).
func _check_aspect_up(p: PlayerState) -> void:
	if p.fervor < fervor_needed(p):
		return
	if p.duelist.aspect < p.highest_aspect:
		p.fervor = 0
		_aspect_up(p)
	elif not p.no_ascension_win:
		_win(p.index, "ascension")
	else:
		p.fervor = 0
		p.duelist.energy = CardInstance.MAX_STAGE
		_emit(&"fervor_peak", {"player": p.index, "energy": p.duelist.energy})


func _aspect_up(p: PlayerState) -> void:
	p.duelist.aspect += 1
	p.duelist.energy = CardInstance.MAX_STAGE
	_discard_drills(p)
	_emit(&"aspect_up", {"player": p.index, "aspect": p.duelist.aspect})


func _lose_aspect(p: PlayerState, source_owner: int) -> void:
	if p.duelist.aspect <= 1:
		return
	if source_owner != p.index and p.relic != null and bool(p.relic.def.relic_flags.get("aspect_shield", false)):
		return
	p.duelist.aspect -= 1
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
	while p.duelist.aspect > target:
		var before: int = p.duelist.aspect
		_lose_aspect(p, source_owner)
		if p.duelist.aspect == before:
			break


## Changing aspect clears the Drills. A Mastery that guards Drills stops this too: the guard is
## "cannot be discarded for any reason", not "cannot be discarded by the opponent".
func _discard_drills(p: PlayerState) -> void:
	if _drills_protected(p):
		return
	for d in p.drills():
		_move_to_discard(d)


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
	if ic.def.type == CardDef.Type.ALLY:
		if ic.power_used_combat != state.combat_count:
			return true
		return ic.power_uses_combat < uses
	# Duelist Powers are once per turn; an aspect change mid-Combat does not refresh them.
	if ic.power_used_turn != state.turn:
		return true
	return ic.power_used_combat == state.combat_count and ic.power_uses_combat < uses


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
	if e.has("amount_per_set_seal"):
		# One card for each Seal of the named set in play, on either side.
		n = _set_seals_in_play(str(e["amount_per_set_seal"]))
		if n <= 0:
			return
	var cands: Array[CardInstance] = _search_candidates(p, e)
	var looks: bool = _search_looks_at_deck(e)
	if cands.is_empty() and not looks:
		return
	var distinct: Array[CardInstance] = _search_distinct(cands)
	if looks or (bool(e.get("choose", true)) and distinct.size() > 1):
		_choice = {"kind": "search_pick", "player": p.index, "effect": e, "remaining": n}
		_prompt_search_pick(p, distinct, n, e)
		return
	for i in range(n):
		cands = _search_candidates(p, e)
		if cands.is_empty():
			break
		_search_take(p, cands[0], e)
	_search_done(p, e)


func _set_seals_in_play(set_name: String) -> int:
	var n: int = 0
	for pl in state.players:
		n += pl.seals_of_set(set_name)
	return n


func _search_looks_at_deck(e: Dictionary) -> bool:
	var source: String = str(e.get("source", "deck"))
	return source == "deck" or source == "either"


## Offers the distinct hits of a search. Up to `n` may be taken at once as a batch. A deck search
## also lists the whole Life Deck under `library`, by title so the order gives nothing away.
func _prompt_search_pick(p: PlayerState, hits: Array[CardInstance], n: int, e: Dictionary = {}) -> void:
	var opts: Array[Command] = []
	for c in hits:
		opts.append(Command.new(p.index, &"pick_option", c.uid))
	opts.append(Command.new(p.index, &"pick_none"))
	var context: Dictionary = {"search": true, "amount": mini(n, hits.size()), "to": str(e.get("to", "hand"))}
	if _search_looks_at_deck(e):
		var deck: Array[CardInstance] = p.life_deck.duplicate()
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
		prompt.set_batch(&"pick_option", 1, mini(n, hits.size()))


## The end of a search: the deck that was looked through is shuffled.
func _search_done(p: PlayerState, e: Dictionary) -> void:
	var shuffled_in: bool = str(e.get("to", "hand")) == "deck_shuffle"
	if (_search_looks_at_deck(e) or shuffled_in) and shuffle_decks and not bool(e.get("no_shuffle", false)):
		rng.shuffle(p.life_deck)
		_emit(&"deck_shuffled", {"player": p.index})


## Every card the search could take, in pool order (deck, then discard when "either").
func _search_candidates(p: PlayerState, e: Dictionary) -> Array[CardInstance]:
	var pools: Array = []
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
	elif c.def.type == CardDef.Type.SEAL and type_name != "seal":
		return false
	if wanted >= 0 and c.def.type != wanted:
		return false
	if type_name == "attack" and not c.def.is_attack():
		return false
	if type_name == "strike_or_art" and c.def.type != CardDef.Type.STRIKE and c.def.type != CardDef.Type.ART:
		# A Strike or Art card of any use, attack or block, which is how the source card reads.
		return false
	if e.has("aspect") and c.def.lowest_aspect() != int(e["aspect"]):
		# "Search for a level 1 Ally": the aspect the personality would come into play at.
		return false
	if type_name == "hand_combat" and not c.def.is_hand_combat_card():
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
	if e.has("has_effect") and not _def_has_effect(c.def, e["has_effect"]):
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
		if str(e.get("at", "")) == "fight_back":
			if state.step == GameState.Step.COMBAT:
				p.pending_fight_back.append({"effect": e, "source": c.uid})
		else:
			var list: Array[Dictionary] = [e]
			_queue.append({"effects": list, "index": 0, "trigger": "on_wound", "owner": p.index, "ctx": {}, "source": c})


## The opponent may use a "during your opponent's Declare step" card before the active player decides.
func _open_declare_window(p: PlayerState) -> bool:
	var opp: PlayerState = state.players[1 - p.index]
	var opts: Array[Command] = []
	for c in opp.non_combats():
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
		if c.def.type == CardDef.Type.ALLY and names.has(c.def.character):
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
		if hit.def.type == CardDef.Type.ALLY and e.has("stages"):
			hit.energy = clampi(int(e["stages"]), 0, CardInstance.MAX_STAGE)
	elif to == "attack":
		# "Search for a card that performs an attack and play it during this attack phase." It
		# goes to hand first so it is performed from a legal place, and the phase does not hand
		# over until it has been performed.
		_erase_from_zone(hit)
		hit.zone = &"hand"
		p.hand.append(hit)
		_pending_attack = hit.uid
	elif to == "deck_bottom" or to == "deck_shuffle":
		_move_to_deck_bottom(hit)
	else:
		_erase_from_zone(hit)
		hit.zone = &"hand"
		p.hand.append(hit)
	p.last_searched = hit.uid
	_emit(&"search", {"player": p.index, "card": hit.uid, "type": str(e.get("card_type", "")), "to": to})


## `to`: "in_control", "duelist", "character" (the X of the card's "X only" gate, wherever X
## stands) or "named" (the personality the attach effect names, which may differ from the gate).
func _attach(c: CardInstance, p: PlayerState, to: String) -> void:
	var host: CardInstance = _attach_host(p, c.def)
	if host == null:
		host = p.in_control() if to == "in_control" else p.duelist
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
func _shuffle_discard_into_deck(p: PlayerState, n: int, all: bool, from: String = "top", school: String = "") -> void:
	var pool: Array[CardInstance] = []
	for c in p.discard:
		if school == "" or c.def.school == school:
			pool.append(c)
	var count: int = pool.size() if all else mini(n, pool.size())
	for i in range(count):
		# The pile runs oldest first, so its top is the end of the array and its bottom is the front.
		var from_front: bool = from == "bottom" or (from == "top_and_bottom" and i % 2 == 1)
		var c: CardInstance = pool[i] if from_front else pool[pool.size() - 1 - i]
		p.discard.erase(c)
		c.zone = &"life_deck"
		p.life_deck.append(c)
		_emit(&"recover", {"player": p.index, "card": c.uid})
	if count > 0 and shuffle_decks:
		rng.shuffle(p.life_deck)


# --- Card movement --------------------------------------------------------

func _draw(player_index: int, n: int) -> void:
	var p: PlayerState = state.players[player_index]
	for i in range(n):
		if p.life_deck.is_empty():
			_lose(player_index, "survival")
			return
		var c: CardInstance = p.life_deck.pop_front()
		c.zone = &"hand"
		p.hand.append(c)
		_emit(&"draw", {"player": player_index, "card": c.uid})


## Takes the top life card off the deck for damage. Null (and a loss) if there is none.
func _flip_life_card(p: PlayerState) -> CardInstance:
	if p.life_deck.is_empty():
		_lose(p.index, "survival")
		return null
	var c: CardInstance = p.life_deck.pop_front()
	c.zone = &"none"
	return c


## Life cards lost to a cost or effect, not to attack damage. Seals count but still bypass the discard pile.
func _discard_life(p: PlayerState, n: int) -> void:
	for i in range(n):
		var c: CardInstance = _flip_life_card(p)
		if c == null:
			return
		if c.def.type == CardDef.Type.SEAL:
			_bypass_seal(c)
		else:
			_move_to_discard(c)
			_on_wound(p, c)
		_emit(&"life_card_lost", {"player": p.index, "card": c.uid})


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


func _remove_discard(p: PlayerState, n: int, all: bool) -> void:
	var count: int = p.discard.size() if all else mini(n, p.discard.size())
	for i in range(count):
		var c: CardInstance = p.discard.back()
		_remove_from_game(c)


func _move_to_discard(c: CardInstance) -> void:
	if c.def.type == CardDef.Type.SEAL:
		_bypass_seal(c)
		return
	_erase_from_zone(c)
	var owner: PlayerState = state.players[c.owner]
	c.zone = &"discard"
	c.attached_to = null
	c.remain = 0
	owner.discard.append(c)
	for under in c.cards_under:
		under.zone = &"discard"
		owner.discard.append(under)
	c.cards_under.clear()
	_drop_attachments(c)
	_emit(&"card_moved", {"card": c.uid, "to": "discard", "owner": c.owner})


func _remove_from_game(c: CardInstance) -> void:
	_erase_from_zone(c)
	var owner: PlayerState = state.players[c.owner]
	c.zone = &"removed"
	c.attached_to = null
	c.remain = 0
	owner.removed.append(c)
	for under in c.cards_under:
		under.zone = &"removed"
		owner.removed.append(under)
	c.cards_under.clear()
	_drop_attachments(c)
	_emit(&"card_moved", {"card": c.uid, "to": "removed", "owner": c.owner})


func _move_to_deck_bottom(c: CardInstance) -> void:
	_erase_from_zone(c)
	var owner: PlayerState = state.players[c.owner]
	c.zone = &"life_deck"
	c.attached_to = null
	c.remain = 0
	owner.life_deck.append(c)
	_emit(&"card_moved", {"card": c.uid, "to": "deck_bottom", "owner": c.owner})


## Attachments fall off when their host leaves play.
func _drop_attachments(host: CardInstance) -> void:
	if host.def.type != CardDef.Type.ALLY and host.def.type != CardDef.Type.DUELIST:
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
		remain = maxi(remain, int(def.remain_when.get("remain", 1)))
	if remain > 0 and c.remain_combat != state.combat_count and state.step == GameState.Step.COMBAT:
		_erase_from_zone(c)
		c.zone = &"in_play"
		c.controller = c.owner
		c.remain = remain
		c.remain_combat = state.combat_count
		owner.in_play.append(c)
		_emit(&"remain", {"player": c.owner, "card": c.uid, "uses": remain})
		return
	if _has_floating_school(c.owner, "after_use_bottom", def.school) and def.school != "":
		_move_to_deck_bottom(c)
	elif def.bottom_after_use:
		_move_to_deck_bottom(c)
	elif def.remove_after_use and not empowered and not _kept_by_seal(def):
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
	state.winner = player_index
	state.win_reason = reason
	state.step = GameState.Step.GAME_OVER
	prompt = null
	_queue.clear()
	_emit(&"game_over", {"winner": player_index, "reason": reason})


func _lose(player_index: int, reason: String) -> void:
	_win(1 - player_index, reason)


func _emit(type: StringName, data: Dictionary = {}) -> void:
	var ev: GameEvent = GameEvent.new(type, data)
	if record_display_state:
		ev.state = _display_state()
	events.append(ev)


## The numbers a client shows on the table right now. See `GameEvent.state`.
func _display_state() -> Dictionary:
	var energy: Dictionary = {}
	var fervor: Array[int] = []
	var zones: Array = []
	for p in state.players:
		energy[p.duelist.uid] = p.duelist.energy
		for a in p.allies():
			energy[a.uid] = a.energy
		fervor.append(p.fervor)
		zones.append([p.life_deck.size(), p.hand.size(), p.discard.size(), p.removed.size()])
	# Where the turn stood, so the banner over the table never runs ahead of the beat under it.
	return {
		"energy": energy, "fervor": fervor, "zones": zones,
		"turn": state.turn, "step": state.step, "phase": state.phase,
		"active": state.active, "attacker": state.attacker,
	}
