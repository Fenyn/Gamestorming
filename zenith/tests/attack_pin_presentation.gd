extends SceneTree
## The Focus slot pins the card an attack was declared with, even when the same update has already
## sent that card somewhere hidden. A Steel attack that goes to the bottom of the Life Deck after
## use is hidden in the update's final view, and the pin used to fall back to the personality.
## Run: godot --headless --path zenith -s tests/attack_pin_presentation.gd

const HALDEN: String = "personality_halden_quarr_1_the_grinder"

var checks: int = 0
var failures: int = 0
var pinned_ids: Array[String] = []
var watching: bool = false
var held_uid: int = -1
var held_samples: Array[bool] = []   # one per frame of a damage beat: attack card held in Play
var held_beats: Array[String] = []
var stop_samples: Array[bool] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	var session: Node = root.get_node("Session")
	var steel: DeckList = null
	var other: DeckList = null
	for value in session.decks:
		var d: DeckList = value
		if steel == null and d.duelist_ids.has(HALDEN):
			steel = d
		elif other == null and d.style != "steel":
			other = d
	_check(steel != null and other != null, "The Steel deck with Halden Quarr is in the precon list")
	if steel == null or other == null:
		quit(1)
		return
	var chosen: Array[DeckList] = [steel, other]
	session.chosen = chosen
	session.seed_value = 5
	session.ai_seat = -1
	var duel: Node3D = load("res://scenes/duel/duel.tscn").instantiate()
	var cache: CardFaceCache = duel.get_node("CardFaceCache")
	var placeholder: ImageTexture = ImageTexture.create_from_image(Image.create(2, 2, false, Image.FORMAT_RGBA8))
	cache._back = placeholder
	for value in session.library.defs.values():
		cache._cache[CardFaceCache.key_for(value)] = placeholder
	root.add_child(duel)
	var deadline: int = Time.get_ticks_msec() + 12000
	while (duel.view == null or duel.hud.loading.visible or duel.busy) and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(duel.view != null and not duel.busy, "Duel scene must finish its opening update")
	if duel.view == null or duel.busy:
		quit(1)
		return
	duel._set_reduced_motion(true)
	var host: DuelHost = duel.duel_host
	var engine: DuelEngine = host.referee.engine
	# Seat 0 plays to its first attack decision holding a Steel attack; seat 1 only passes.
	var attack: OptionView = null
	for step in range(200):
		if engine.is_over() or engine.prompt == null:
			break
		var seat: int = engine.prompt.player
		var p: PromptView = host.prompt_for(seat)
		if seat == 0 and p.kind == &"attack_action":
			for o in p.options:
				var c: CardInstance = engine.card(o.card) if o.type == &"attack" else null
				if c != null and c.zone == &"hand" and c.def.school == "steel":
					attack = o
					break
			if attack != null:
				break
		var pick: OptionView = null
		for wanted in [&"declare", &"pass", &"no_defense", &"no_endure", &"done"]:
			if pick == null:
				pick = p.find(wanted)
		if pick == null:
			pick = p.options[0]
		host.apply(seat, pick.to_command(seat).to_dict())
	_check(attack != null, "Seat 0 reaches an attack decision with a Steel attack in hand")
	if attack == null:
		quit(1)
		return
	var source: int = attack.card
	var source_id: String = engine.card(source).def.id
	# The report: the duelist rose to Aspect 2 and every attack after it pinned the personality.
	_check(str(host.dev(0, {"op": "advance_aspect"}).get("problem", "x")) == "", "The duelist rises an Aspect")
	_check(engine.player(0).duelist.aspect == 2, "Halden stands at Aspect 2")
	# "Your Steel cards go to the bottom of your Life Deck after use" for the rest of the Combat.
	var bottom: Dictionary = {"op": "float", "what": "after_use_bottom", "duration": "combat", "params": {"school": "steel"}}
	_check(str(host.dev(0, bottom).get("problem", "x")) == "", "The Life Deck bottom rule is standing")
	var again: PromptView = host.prompt_for(0)
	var declare: OptionView = again.find(&"attack", source) if again != null else null
	_check(declare != null, "The Steel attack is still on offer after the Aspect change")
	if declare == null:
		quit(1)
		return
	var lines: Array[Dictionary] = []
	var result: Dictionary = host.apply(0, declare.to_command(0).to_dict())
	var updates: Array[SeatUpdate] = result.get("updates", [])
	var last: SeatUpdate = updates[0]
	lines.append_array(last.lines)
	# The defender takes it; the lines up to the attack's end are one exchange.
	for step in range(20):
		if engine.state.attack.is_empty() or engine.prompt == null:
			break
		var seat: int = engine.prompt.player
		var p: PromptView = host.prompt_for(seat)
		var pick: OptionView = null
		for wanted in [&"no_defense", &"no_endure", &"no_critical", &"pass", &"done"]:
			if pick == null:
				pick = p.find(wanted)
		if pick == null:
			pick = p.options[0]
		updates = host.apply(seat, pick.to_command(seat).to_dict()).get("updates", [])
		if updates.is_empty():
			break
		last = updates[0]
		lines.append_array(last.lines)
	_check(engine.card(source).zone == &"life_deck", "The Steel attack went to the Life Deck after use")
	# One update carrying the declaration and the card's trip to the Life Deck, as when the
	# defender has nothing to answer with and the engine runs the exchange through.
	var merged: SeatUpdate = SeatUpdate.new()
	merged.lines = lines
	merged.view = last.view
	merged.prompt = last.prompt
	_check(merged.view.card(source) != null and merged.view.card(source).hidden(), "The final view no longer shows the attack card")
	var declared: Dictionary = {}
	for l in lines:
		if str(l.get("type", "")) == "attack_declared":
			declared = l.get("data", {})
	_check(str(declared.get("id", "")) == source_id, "The declaration names its card for the replay")
	duel.viewer = 0
	held_uid = source
	_watch(duel)
	await duel._play_update(merged)
	watching = false
	_check(not held_samples.is_empty(), "The replay reached the damage beats with the attack declared")
	_check(not held_samples.has(false),
		"The attack card sits in its owner's Play slot through the damage beats: %s" % str(held_beats))
	_check(not duel._held.has(source), "The attack card is let go once the exchange ends")
	var settled: Dictionary = duel._targets()
	var card3d: Card3D = duel.views.get(source)
	_check(settled.has(source) and card3d != null, "The attack card has a slot in the final layout")
	if settled.has(source) and card3d != null:
		var bottom_slot: Transform3D = settled[source][0]
		_check(card3d.transform.origin.distance_to(bottom_slot.origin) < 0.01 and not card3d.face_up,
			"After the exchange the attack card lies face down in the Life Deck, where the view says it went")
	_check(not pinned_ids.is_empty(), "The declaration pinned a face")
	_check(pinned_ids.size() > 0 and pinned_ids[0] == source_id,
		"The Focus slot pins the attack card, not the personality: pinned %s, attacked with %s" % [str(pinned_ids), source_id])
	_check(not pinned_ids.has(engine.player(0).duelist.def.id), "The personality never takes the attack's slot")
	# A Power or a Final Strike still has only the fighter to show.
	duel._pin_attack(-1, 0, {"kind": "strike", "is_final": true})
	_check(duel._pinned_def != null and duel._pinned_def.is_personality(), "An attack with no card of its own pins the personality")
	duel._release_pin()
	await _defense_hold(duel, host, engine, lines)
	duel.queue_free()
	await process_frame
	print("Attack pin presentation: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


## An opponent's defense that the rules have already sent face down into its Life Deck. It arrives
## at the end of one update (the attacker's decision interrupts the exchange), so it is held in
## the defender's Play slot across the boundary, face up with the face its event named, and is let
## go when the next update settles the attack.
func _defense_hold(duel: Node3D, host: DuelHost, engine: DuelEngine, earlier: Array[Dictionary]) -> void:
	var state: Dictionary = {}
	for l in earlier:
		if str(l.get("type", "")) == "attack_declared":
			state = l.get("state", {})
	var now_view: SeatView = host.view_for(0)
	var deck: Array[int] = now_view.player(1).life_deck
	_check(not deck.is_empty(), "The defender has a Life Deck to hide a defense in")
	if deck.is_empty():
		return
	var guard: int = deck[deck.size() - 1]
	var guard_def: CardDef = engine.card(guard).def
	_check(now_view.card(guard).hidden(), "Seat 0 cannot see the defense in the defender's Life Deck")
	var first: SeatUpdate = SeatUpdate.new()
	var first_lines: Array[Dictionary] = [{"type": "defense_played", "player": 1, "state": state,
		"data": {"card": guard, "id": guard_def.id, "stopped": true}, "line": "The defender answers"}]
	first.lines = first_lines
	first.view = now_view
	first.prompt = host.prompt_for(0)
	await duel._play_update(first)
	var v: Card3D = duel.views.get(guard)
	var play_slot: Transform3D = duel.zones.slot(1, &"resolving", 0, 1, 0)
	_check(duel._held.has(guard), "The defense is still held when its update ends mid-exchange")
	_check(v != null and v.visible and v.face_up and v.transform.origin.distance_to(play_slot.origin) < 0.02,
		"The held defense sits face up in the defender's Play slot between updates")
	_check(str(duel._face_keys.get(guard, "")) == CardFaceCache.key_for(guard_def),
		"The held defense wears the face its event named, though the view hides it")
	var second: SeatUpdate = SeatUpdate.new()
	var second_lines: Array[Dictionary] = [
		{"type": "attack_stopped", "player": 1, "state": state, "data": {}, "line": "Stopped"},
		{"type": "attack_end", "player": 0, "state": state, "data": {"stopped": true, "stages_dealt": 0, "life_dealt": 0}, "line": ""}]
	second.lines = second_lines
	second.view = now_view
	second.prompt = host.prompt_for(0)
	held_uid = guard
	stop_samples.clear()
	_watch_stop(duel)
	await duel._play_update(second)
	watching = false
	_check(not stop_samples.is_empty() and not stop_samples.has(false), "The defense is held while the stop beat plays")
	_check(not duel._held.has(guard), "The defense is let go once the attack is stopped")
	var settled: Dictionary = duel._targets()
	if v != null and settled.has(guard):
		var pile: Transform3D = settled[guard][0]
		_check(v.transform.origin.distance_to(pile.origin) < 0.01 and not v.face_up,
			"The released defense lies face down in the defender's Life Deck")


## Every face the replay pins while the declaration beat plays, and whether the attack card sits in
## its owner's Play slot while the damage lands.
func _watch(duel: Node3D) -> void:
	watching = true
	while watching:
		await process_frame
		if not watching or not is_instance_valid(duel):
			return
		if duel._replaying == &"attack_declared" and duel._pinned_def != null:
			var id: String = duel._pinned_def.id
			if pinned_ids.is_empty() or pinned_ids.back() != id:
				pinned_ids.append(id)
		if duel._replaying in [&"base_damage", &"modified_damage", &"damage_stages", &"life_card_flipped"]:
			held_samples.append(_in_play_slot(duel, held_uid, 0))
			if not held_beats.has(String(duel._replaying)):
				held_beats.append(String(duel._replaying))


func _watch_stop(duel: Node3D) -> void:
	watching = true
	while watching:
		await process_frame
		if not watching or not is_instance_valid(duel):
			return
		# The release is the last thing the stop beat does, so sample only while it still toasts.
		if duel._replaying == &"attack_stopped" and duel._held.has(held_uid):
			stop_samples.append(_in_play_slot(duel, held_uid, 1))


func _in_play_slot(duel: Node3D, uid: int, seat: int) -> bool:
	var v: Card3D = duel.views.get(uid)
	var play_slot: Transform3D = duel.zones.slot(seat, &"resolving", 0, 1, 0)
	return duel._held.has(uid) and v != null and v.visible and v.face_up \
		and v.transform.origin.distance_to(play_slot.origin) < 0.02
