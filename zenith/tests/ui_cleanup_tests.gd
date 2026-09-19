extends SceneTree
## UID retention, immediate private-face removal, and shared public status presentation.
const PLAYER_STATUS: Script = preload("res://scripts/duel/player_status.gd")
var checks: int = 0
var failures: int = 0
var redraws: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	var session: Node = root.get_node("Session")
	var def: CardDef = session.library.defs.values()[0]
	var cache: CardFaceCache = CardFaceCache.new()
	var texture: ImageTexture = ImageTexture.create_from_image(Image.create(2, 2, false, Image.FORMAT_RGBA8))
	cache._cache[CardFaceCache.key_for(def, 1)] = texture
	var camera: Camera3D = Camera3D.new()
	root.add_child(camera)
	var hand: Node3D = load("res://scripts/duel/hand_3d.gd").new()
	camera.add_child(hand)
	hand.set_process(false)
	var view: SeatView = SeatView.new()
	var cards: Array[SeatCard] = []
	for uid in range(1, 4):
		var card: SeatCard = SeatCard.from_dict({"uid": uid, "def": def.id, "title": "Test card", "zone": "hand"})
		cards.append(card)
		view.cards[uid] = card
	hand.set_hand(cards, cache, {}, view)
	hand.preview_index(1)
	var original: Node3D = hand._items[1]["node"]
	var face: Sprite3D = hand._items[1]["face"]
	var pose: Transform3D = original.transform
	cards.reverse()
	view.forecasts[2] = {"stages": 7, "life": 0, "cost_stages": 2}
	hand.set_hand(cards, cache, {2: true}, view)
	_check(hand._items[1]["node"] == original and hand._items[1]["face"] == face, "Refresh must retain the actual node and face for a surviving UID")
	_check(original.transform.is_equal_approx(pose), "Refresh must not snap a surviving card's animated pose")
	_check(hand.revealed and hand.keyboard_active and hand._items[hand._hovered]["uid"] == 2, "Reordering must retain browsing and hover by UID")
	_check(hand._items[1]["legal"] and "7" in hand._items[1]["summary"].text and "Cost 2" in hand._items[1]["summary"].text, "Retained cards must receive updated legality and forecast captions")
	hand.remove_uid(3)
	_check(hand._items[hand._hovered]["uid"] == 2, "Removing a different card must retain the hovered UID")
	var hidden: SeatCard = SeatCard.from_dict({"uid": 2, "zone": "hand"})
	var masked: Array[SeatCard] = [hidden, cards[2]]
	hand.set_hand(masked, cache, {}, view)
	_check(not original.visible and original.is_queued_for_deletion(), "A newly hidden card must disappear synchronously before deferred deletion")
	_check(hand._hovered == -1 and hand._items.size() == 1, "Newly hidden cards must leave picking and hover state")
	hand.preview_index(0)
	var old_private: Node3D = hand._items[0]["node"]
	view.seat = 1
	hand.set_hand(masked, cache, {}, view)
	_check(not old_private.visible and hand._items[0]["node"] != old_private, "Changing viewer must discard the previous viewer's render nodes")
	_check(not hand.revealed and not hand.keyboard_active and hand._hovered == -1, "Changing viewer must reset private browsing state")
	var p: SeatPlayer = SeatPlayer.new()
	p.energy_blocked = true
	p.fervor_needed = 7
	p.fervor_gain = 0
	p.restrictions = ["mastery"]
	p.duelist = 1
	p.controlling = 1
	view.players = [p]
	var readout: Control = load("res://scripts/duel/duelist_readout.gd").new()
	root.add_child(readout)
	readout.reduced_motion = true
	readout.refresh(view, 0, 0)
	_check(readout._flags == PLAYER_STATUS.flags(p), "Field readout must use the same complete status formatter as inspection")
	_check("Needs 7 Fervor" in readout.status_text() and "Fervor gain x0" in readout.status_text() and "Cannot gain Energy" in readout.status_text(), "Changed thresholds, blocked gains and restrictions must remain available in full status")
	readout.redraw_requested.connect(func() -> void: redraws += 1)
	readout.card_bounds = readout.card_bounds
	readout.duelist_bounds = readout.duelist_bounds
	_check(redraws == 0, "Unchanged projected bounds must not redraw a paused resource viewport")
	readout.card_bounds = Rect2(10, 20, 100, 140)
	_check(redraws == 1, "Changed projected bounds must request a resource viewport redraw")
	var hud: Node = load("res://scenes/duel/hud.tscn").instantiate()
	_check(not hud.has_node("Root/TopPanel") and not hud.has_node("Root/BottomPanel"), "HUD must not instantiate hidden legacy player panels")
	hud.free()
	readout.free()
	camera.free()
	cache.free()
	await process_frame
	print("UI cleanup tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
