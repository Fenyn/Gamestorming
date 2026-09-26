extends SceneTree
## A real survival point must replay its full discard return as one short table beat.
## Run: godot --headless --path zenith -s tests/second_wind_presentation.gd

const FaceCacheFill = preload("res://tests/face_cache_fill.gd")

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	var session: Node = root.get_node("Session")
	var chosen: Array[DeckList] = [session.decks[0], session.decks[1]]
	session.chosen = chosen
	session.seed_value = 5
	session.ai_seat = -1
	var duel: Node3D = load("res://scenes/duel/duel.tscn").instantiate()
	var cache: CardFaceCache = duel.get_node("CardFaceCache")
	FaceCacheFill.fill(cache, session.library, chosen)
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
	host.referee.engine.state.points_to_win = [2, 2]
	var life_count: int = host.referee.engine.player(0).life_deck.size()
	var result: Dictionary = host.dev(0, {"op": "discard_life", "amount": life_count + 1})
	_check(str(result.get("problem", "")) == "", "Supported debug effect must resolve a survival point")
	var updates: Array[SeatUpdate] = result.get("updates", [])
	if updates.is_empty():
		quit(1)
		return
	var update: SeatUpdate = updates[0]
	var bulk_cards: Array[int] = []
	var recovery_start: int = -1
	var point_line: String = ""
	var wind_line: String = ""
	for index in range(update.lines.size()):
		if str(update.lines[index].get("type", "")) == "point_scored":
			point_line = str(update.lines[index].get("line", ""))
		if str(update.lines[index].get("type", "")) == "second_wind":
			wind_line = str(update.lines[index].get("line", ""))
		var cards: Array[int] = duel._second_wind_cards(update.lines, index)
		if not cards.is_empty() and recovery_start < 0:
			bulk_cards = cards
			recovery_start = index
	_check(bulk_cards.size() > 10, "Survival point must return a full discard pile")
	_check(point_line.contains("point") and wind_line.contains("Life Deck"), "Point and Second Wind must each have one readable summary line")
	_check(recovery_start >= 0 and str(update.lines[recovery_start + bulk_cards.size()].get("type", "")) == "second_wind", "Only Second Wind recoveries use the grouped beat")
	if recovery_start >= 0:
		var ordinary: Array[Dictionary] = [update.lines[recovery_start], update.lines[recovery_start + 1]]
		_check(duel._second_wind_cards(ordinary, 0).is_empty(), "Ordinary multi-card recovery retains individual beats")
	var started: int = Time.get_ticks_msec()
	await duel._play_update(update)
	var elapsed: int = Time.get_ticks_msec() - started
	_check(elapsed < 2500, "A full-deck return must not wait on each recovered card (%d ms)" % elapsed)
	_check(duel.view.player(0).life_deck.size() > 0, "Recovered Life Deck must remain visible after replay")
	_check(duel._second_wind_returning.is_empty(), "Temporary public reveal state must clear after replay")
	# Exercise the actual tween, independent of the many preceding damage beats. Every card
	# starts in the discard rail and must arrive within one animation duration.
	duel._set_reduced_motion(false)
	var targets: Dictionary = duel._targets()
	for uid in bulk_cards:
		var card: Card3D = duel.views.get(uid)
		if card != null:
			card.transform = duel.zones.slot(0, &"discard", 0)
	started = Time.get_ticks_msec()
	await duel._fly_recover_batch(bulk_cards, targets)
	var tween_elapsed: int = Time.get_ticks_msec() - started
	_check(tween_elapsed < 1000, "Full discard flight must finish as one parallel tween (%d ms)" % tween_elapsed)
	for uid in bulk_cards:
		var card: Card3D = duel.views.get(uid)
		if card != null and targets.has(uid):
			var target: Transform3D = targets[uid][0]
			_check(card.transform.origin.distance_to(target.origin) < 0.001, "Recovered card must land on its final pile slot")
	# A card lost just before the reset is hidden again in the final public view. Its public
	# loss event still has to reveal it at the discard rail before the shuffle takes it back.
	var last_loss: Dictionary = {}
	for index in range(recovery_start):
		var line: Dictionary = update.lines[index]
		if str(line.get("type", "")) == "life_card_lost":
			var data: Dictionary = line.get("data", {})
			var uid: int = int(data.get("card", -1))
			if bulk_cards.has(uid) and duel.view.player(0).life_deck.has(uid):
				last_loss = line
	_check(not last_loss.is_empty(), "Fixture must contain a lost card hidden by the reset")
	if not last_loss.is_empty():
		var data: Dictionary = last_loss["data"]
		var uid: int = int(data["card"])
		_check(duel.view.card(uid).hidden(), "The returned card must be hidden in the final public view")
		duel._set_reduced_motion(true)
		duel._second_wind_returning[uid] = true
		duel._live = last_loss.get("state", {})
		await duel._fly_life_loss(uid, 0, targets, "-1 Life", str(data.get("id", "")))
		var card: Card3D = duel.views.get(uid)
		_check(card != null and card.face_up, "Public loss must briefly reveal a card hidden by the final view")
		duel._second_wind_returning.clear()
		duel._live = {}
	duel.queue_free()
	await process_frame
	print("Second Wind presentation: %d checks, %d failures (%d ms replay, %d ms tween)" % [checks, failures, elapsed, tween_elapsed])
	quit(0 if failures == 0 else 1)
