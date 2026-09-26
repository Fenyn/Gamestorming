extends SceneTree
## Softlock hunt. A prompt is only answerable if at least one of its options is somewhere the
## player can reach: a button in the side panel, a tile in the tray, the Final Strike button, or
## a card the table actually draws. An option routed to "click the card" whose card the client
## never places is invisible, so a prompt made only of those leaves the game stuck with no way
## to answer it.
##
## Both halves are checked for every prompt of every seat across many real games:
##   1. every click-routed option's card is drawn and visible
##   2. the prompt has at least one affordance of any kind
##
## Run: godot --headless --path zenith -s tests/prompt_reach_tests.gd -- --games=40

const MAX_STEPS: int = 4000
const FaceCacheFill = preload("res://tests/face_cache_fill.gd")

var failures: int = 0
var checks: int = 0
var prompts_seen: int = 0
var reported: Dictionary = {}    # one line per distinct fault, so a common one does not flood


func _initialize() -> void:
	_run.call_deferred()


func _fault(key: String, message: String) -> void:
	failures += 1
	if reported.has(key):
		return
	reported[key] = true
	push_error(message)


func _run() -> void:
	var args: Dictionary = {"games": "40", "seed": "11"}
	for raw in OS.get_cmdline_user_args():
		var parts: PackedStringArray = raw.trim_prefix("--").split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else "1"
	var session: Node = root.get_node("Session")
	session.chosen = [session.decks[0], session.decks[1]] as Array[DeckList]
	session.seed_value = 5
	session.ai_seat = -1
	var scene: PackedScene = load("res://scenes/duel/duel.tscn")
	var duel: Node3D = scene.instantiate()
	var cache: CardFaceCache = duel.get_node("CardFaceCache")
	FaceCacheFill.fill(cache, session.library, session.chosen)
	root.add_child(duel)
	var deadline: int = Time.get_ticks_msec() + 12000
	while (duel.view == null or duel.hud.loading.visible) and Time.get_ticks_msec() < deadline:
		await process_frame
	if duel.view == null:
		push_error("duel scene did not load")
		quit(1)
		return
	# The scene only lends its client code; every game below runs on its own referee.
	var names: Array[String] = []
	var dir: DirAccess = DirAccess.open("res://data/decks")
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if entry.ends_with(".json"):
			names.append(entry.trim_suffix(".json"))
		entry = dir.get_next()
	names.sort()

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(args["seed"])
	for game in range(int(args["games"])):
		var decks: Array[DeckList] = [
			DeckList.load_from("res://data/decks/%s.json" % names[rng.randi() % names.size()]),
			DeckList.load_from("res://data/decks/%s.json" % names[rng.randi() % names.size()]),
		]
		var ref: Referee = Referee.new()
		ref.setup(decks, session.library, session.strike_table, rng.randi(), [], false)
		ref.start()
		var host: DuelHost = DuelHost.new()
		host.setup(ref, [], null, -1)
		var steps: int = 0
		while not ref.is_over() and steps < MAX_STEPS:
			steps += 1
			var seat: int = ref.engine.prompt.player if ref.engine.prompt != null else -1
			if seat < 0:
				break
			_audit(duel, ref, seat)
			_audit_fallback(host, ref, seat)
			var p: Prompt = ref.engine.prompt
			ref.submit(seat, p.options[rng.randi() % p.options.size()].to_dict())
			ref.engine.take_events()
	print("prompt reach: %d prompts, %d checks, %d failures" % [prompts_seen, checks, failures])
	quit(1 if failures > 0 else 0)


## The host has to be able to answer any pending decision on a seat's behalf. Without that an
## AI that yields nothing leaves the duel standing still with no prompt and no way to make one.
func _audit_fallback(host: DuelHost, ref: Referee, seat: int) -> void:
	checks += 1
	var wire: Dictionary = host.fallback_choice(seat)
	if wire.is_empty():
		_fault("fallback/%s" % String(ref.engine.prompt.kind), "the host has no answer for a pending %s" % String(ref.engine.prompt.kind))
		return
	checks += 1
	var legal: bool = false
	for o in ref.prompt_for(seat).options:
		if o.to_command(seat).to_dict() == wire:
			legal = true
			break
	if not legal:
		_fault("fallback_illegal", "the host's fallback is not one of the prompt's own options")


## One prompt, seen the way the client sees it: the view for that seat, the client's own layout,
## and the HUD's own routing of the options.
func _audit(duel: Node3D, ref: Referee, seat: int) -> void:
	var view: SeatView = ref.view_for(seat)
	var p: PromptView = ref.prompt_for(seat)
	if p == null or p.options.is_empty():
		return
	prompts_seen += 1
	duel.view = view
	duel.viewer = seat
	duel.prompt = p
	duel.hud._view = view
	var targets: Dictionary = duel._targets()
	# The viewer's own hand is drawn by Hand3D, not as a table card, so `_targets` marks it
	# invisible on purpose. Those are still clickable.
	var in_hand: Dictionary = {}
	for uid in view.player(seat).hand:
		in_hand[uid] = true
	var routed: Dictionary = duel.hud.routes(p, view)
	var clickable: int = 0
	for opt in routed["click"]:
		checks += 1
		var entry: Variant = targets.get(opt.card)
		var drawn: bool = in_hand.has(opt.card) or (entry is Array and bool((entry as Array)[2]))
		if drawn:
			clickable += 1
		else:
			var card: SeatCard = view.card(opt.card)
			_fault("%s/%s" % [p.kind, "none" if card == null else card.zone],
				"%s prompt: option %s on a card the table never draws (zone %s), so it cannot be clicked" % [
					p.kind, opt.type, "missing" if card == null else card.zone])
	checks += 1
	var total: int = int(routed["primary"].size()) + int(routed["browse"].size()) + int(routed["finals"].size()) + clickable
	if total == 0:
		_fault("stuck/%s" % p.kind, "%s prompt offers %d options and none of them can be reached" % [p.kind, p.options.size()])
