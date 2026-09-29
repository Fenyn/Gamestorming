extends SceneTree
## The blue frame on table cards the viewer can use now, and the Remain ghosts in the hand fan.
##
## Run: godot --headless --path zenith -s tests/remain_ghost_tests.gd

const FaceCacheFill = preload("res://tests/face_cache_fill.gd")
const MAX_STEPS: int = 4000

var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _run() -> void:
	var session: Node = root.get_node("Session")
	var decks: Array[DeckList] = [DeckList.load_from("res://data/decks/pyre_beatdown.json"), DeckList.load_from("res://data/decks/tide_deepwater.json")]
	session.chosen = decks
	session.seed_value = 5
	session.ai_seat = -1
	var duel: Node3D = load("res://scenes/duel/duel.tscn").instantiate()
	FaceCacheFill.fill(duel.get_node("CardFaceCache"), session.library, decks)
	root.add_child(duel)
	var deadline: int = Time.get_ticks_msec() + 12000
	while (duel.view == null or duel.hud.loading.visible) and Time.get_ticks_msec() < deadline:
		await process_frame
	if duel.view == null:
		push_error("duel scene did not load")
		quit(1)
		return
	_check_usable_rule(duel)
	var power_seen: bool = false
	var idle_seen: bool = false
	var remain_seen: bool = false
	for game_seed in [7, 11, 19, 23, 31, 43]:
		var ref: Referee = Referee.new()
		ref.setup(decks, session.library, session.strike_table, game_seed, [], false)
		ref.start()
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = game_seed
		var steps: int = 0
		while not ref.is_over() and steps < MAX_STEPS:
			steps += 1
			var seat: int = ref.engine.prompt.player if ref.engine.prompt != null else -1
			if seat < 0:
				break
			var p: PromptView = ref.prompt_for(seat)
			var view: SeatView = ref.view_for(seat)
			var power: bool = p.find(&"power", view.player(seat).duelist) != null
			if power and not power_seen:
				power_seen = true
				_check_duelist_frame(duel, ref, seat, true)
			elif not power and not idle_seen and p.find(&"declare") != null:
				idle_seen = true
				_check_duelist_frame(duel, ref, seat, false)
			if not remain_seen and _remain_option(p, view, seat) >= 0:
				remain_seen = true
				await _check_ghosts(duel, ref, seat)
				break
			ref.submit(seat, _pick(p, rng).to_command(seat).to_dict())
			ref.engine.take_events()
		if remain_seen and power_seen and idle_seen:
			break
	_check(power_seen, "Some game offers a duelist's Power, so the blue frame gets checked on it")
	_check(idle_seen, "Some prompt offers no Power, so its absence gets checked")
	_check(remain_seen, "Some game keeps a card out in Remain with a use offered")
	duel.queue_free()
	await process_frame
	print("remain ghosts: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


## Attacks first, so Remain cards come out; otherwise any option.
func _pick(p: PromptView, rng: RandomNumberGenerator) -> OptionView:
	for wanted in [&"attack", &"declare", &"no_defense", &"no_endure"]:
		var o: OptionView = p.find(wanted)
		if o != null and (wanted != &"attack" or o.value == null):
			return o
	return p.options[rng.randi() % p.options.size()]


func _remain_option(p: PromptView, view: SeatView, seat: int) -> int:
	if p == null:
		return -1
	for uid in view.player(seat).remain:
		if not p.options_for_card(uid).is_empty():
			return uid
	return -1


func _show(duel: Node3D, ref: Referee, seat: int) -> void:
	duel.view = ref.view_for(seat)
	duel.prompt = ref.prompt_for(seat)
	duel.viewer = seat
	duel.hud._view = duel.view
	duel._adopt_cards()


## A use of the card itself counts; a pick, a target or a hand card does not.
func _check_usable_rule(duel: Node3D) -> void:
	var view: SeatView = SeatView.new()
	var me: SeatPlayer = SeatPlayer.new()
	me.index = 0
	me.hand = [7] as Array[int]
	var rival: SeatPlayer = SeatPlayer.new()
	rival.index = 1
	view.players = [me, rival] as Array[SeatPlayer]
	var p: PromptView = PromptView.new()
	p.player = 0
	for pair in [[&"power", 5], [&"use", 8], [&"pick_in_play", 6], [&"control", 9], [&"defend", 7], [&"pass", -1]]:
		var o: OptionView = OptionView.new()
		o.type = pair[0]
		o.card = int(pair[1])
		p.options.append(o)
	var usable: Dictionary = duel.usable_uids(p, view, 0)
	_check(usable.has(5) and usable.has(8) and usable.size() == 2, "Only a Power or a use of a table card wears the blue frame: %s" % str(usable.keys()))
	_check(duel.usable_uids(p, view, 1).is_empty(), "A prompt for the other seat frames nothing for this one")


func _check_duelist_frame(duel: Node3D, ref: Referee, seat: int, expect: bool) -> void:
	_show(duel, ref, seat)
	var duelist: int = duel.view.player(seat).duelist
	var v: Card3D = duel.views.get(duelist)
	v.visible = true
	duel._highlight(duel._legal_uids())
	var blue: bool = v.glow.visible and v._glow_mat.get_shader_parameter("tint") == Color(ZenithTheme.USABLE, 1.0)
	if expect:
		_check(v.is_usable() and blue, "A duelist whose Power the prompt offers wears the blue frame")
	else:
		_check(not v.is_usable() and not blue, "A duelist whose Power is not on offer (%s prompt) wears no blue frame" % String(duel.prompt.kind))
	duel._clear_highlights()
	_check(not v.is_usable() and not v.glow.visible, "Clearing the decision clears the blue frame")


func _check_ghosts(duel: Node3D, ref: Referee, seat: int) -> void:
	_show(duel, ref, seat)
	var view: SeatView = duel.view
	var uid: int = _remain_option(duel.prompt, view, seat)
	var host: DuelHost = DuelHost.new()
	host.setup(ref, [] as Array[int], null, -1)
	duel.duel_host = host
	duel._set_hand(duel._legal_uids())
	var hand: Node3D = duel.hand_3d
	var real: Array[int] = view.player(seat).hand
	var ghosts: Array[SeatCard] = duel.remain_ghosts(view, seat)
	_check(ghosts.size() == view.player(seat).remain.size(), "Every Remain card with uses left has one ghost")
	_check(hand._items.size() == real.size() + ghosts.size() and hand.hand_count() == real.size(),
		"The fan holds the hand plus the ghosts, and the hand count leaves the ghosts out")
	var order_ok: bool = true
	for i in range(hand._items.size()):
		order_ok = order_ok and bool(hand._items[i]["ghost"]) == (i >= real.size())
	_check(order_ok, "Ghosts sit after the real hand cards")
	var item: Dictionary = hand._items[hand._items.size() - ghosts.size() + ghosts.find(view.card(uid))]
	_check(bool(item["ghost"]) and int(item["uid"]) == uid and bool(item["legal"]), "The ghost of a Remain card with an option stands as a choice")
	_check((item["face"] as Sprite3D).material_override is ShaderMaterial and str((item["chip"] as Label3D).text).begins_with("REMAIN"),
		"A ghost is drawn with the spectral face and a Remain chip")
	_check(hand.world_card_transform(uid) == null, "A ghost never lends its pose to the card leaving the table")
	_check(not view.player(seat).hand.has(uid), "The view's hand is untouched")
	var rival: int = 1 - seat
	duel.far_duelist.refresh(view, rival, seat)
	_check(duel.far_duelist.readout._hand == view.player(rival).hand.size(), "The rival's hand of backs keeps its own count")
	var rival_view: SeatView = ref.view_for(rival)
	duel.view = rival_view
	duel.viewer = rival
	duel.prompt = null
	duel._set_hand({})
	_check(not hand.has_uid(uid) and hand.hand_count() == rival_view.player(rival).hand.size(), "From the other seat the Remain card is no ghost and no extra hand card")
	_show(duel, ref, seat)
	duel._set_hand(duel._legal_uids())
	duel.busy = false
	var options: Array[OptionView] = duel.prompt.options_for_card(uid)
	var before: SeatCard = view.card(uid)
	hand.clicked.emit(uid)
	var after: SeatCard = ref.view_for(seat).card(uid)
	var used: bool = after.remain == before.remain - 1 or after.zone != &"in_play"
	_check(options.size() == 1 and used, "Clicking the ghost takes the Remain card's own option (%s): uses %d -> %d, zone %s" % [
		"none" if options.is_empty() else String(options[0].type), before.remain, after.remain, after.zone])
	var deadline: int = Time.get_ticks_msec() + 15000
	while duel.busy and Time.get_ticks_msec() < deadline:
		await process_frame
