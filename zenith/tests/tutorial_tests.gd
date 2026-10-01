extends SceneTree
## Headless run of the tutorial (lessons 1 to 5) through the Referee and the TutorialDirector, with
## a stand-in player who takes the option each prompt opens, and every free choice tried both ways.
## `-- --trace` prints every action with the log it made.
##   godot --headless --path zenith -s tests/tutorial_tests.gd
## Exit code is 1 when any check fails.

var lib: CardLibrary
var table: StrikeTable
var checks: int = 0
var failures: int = 0
var current: String = ""
var trace: bool = false
## The stand-in's run, played once and read by several tests.
var main: Dictionary = {}


func _init() -> void:
	trace = OS.get_cmdline_user_args().has("--trace")
	var base: CardLibrary = CardLibrary.new()
	base.load_dir("res://data/cards")
	lib = TutorialDirector.library_from(base)
	table = StrikeTable.load_from("res://data/strike_table.json")
	var tests: Array[Callable] = [
		test_the_whole_session_plays_through,
		test_each_beat_lands_its_numbers,
		test_only_the_taught_move_is_open,
		test_every_free_choice_reaches_the_same_next_beat,
		test_resuming_at_a_lesson_rebuilds_the_same_board,
		test_the_session_replays_from_its_history,
		test_a_shorter_range_ends_after_its_last_lesson,
		test_the_straw_knight_stays_out_of_the_shipped_pool,
		test_the_saved_lesson_lives_in_the_profile,
		test_each_lesson_stops_the_table_only_a_few_times,
		test_every_line_has_a_speaker_and_a_place,
		test_the_words_on_screen_follow_the_house_rules,
		test_vale_speaks_for_himself_once_he_fights,
		test_a_stop_reads_itself_on,
		test_a_held_stop_waits_for_the_click,
		test_a_click_finishes_the_line_then_moves_on,
	]
	for t in tests:
		current = t.get_method()
		var before: int = failures
		t.call()
		print("%s %s" % ["ok  " if failures == before else "FAIL", current])
	print("Tutorial tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		printerr("  FAIL [%s] %s" % [current, msg])


func eq(actual: Variant, expected: Variant, msg: String) -> void:
	check(actual == expected, "%s: expected %s, got %s" % [msg, str(expected), str(actual)])


# --- Playing the script -----------------------------------------------------------

func fresh(last: int = 0) -> Array:
	var director: TutorialDirector = TutorialDirector.new(last)
	var referee: Referee = director.build_referee(lib, table, false)
	referee.start()
	return [director, referee]


## What the checks read off the table after an action.
func snapshot(referee: Referee) -> Dictionary:
	var e: DuelEngine = referee.engine
	var out: Dictionary = {}
	for seat in range(2):
		var p: PlayerState = e.player(seat)
		var hand: Array[String] = []
		for c in p.hand:
			hand.append(c.def.id)
		var in_play: Array[String] = []
		for c in p.in_play:
			in_play.append(c.def.id)
		out["p%d" % seat] = {"name": p.name, "character": p.duelist.def.character, "aspect": p.duelist.aspect,
			"energy": p.duelist.energy, "might": p.duelist.might(), "fervor": p.fervor, "life": p.life_deck.size(),
			"discard": p.discard.size(), "hand": hand, "in_play": in_play,
			"top": p.life_deck[0].def.id if not p.life_deck.is_empty() else ""}
	out["last_attack"] = e.state.last_attack.duplicate(true)
	out["attack"] = e.state.attack.duplicate(true)
	out["over"] = e.is_over()
	out["ended"] = e.state.ended
	out["winner"] = e.state.winner
	out["turn"] = e.state.turn
	return out


## The table in a few fields, for comparing two ways of reaching the same step.
func fingerprint(referee: Referee) -> String:
	var s: Dictionary = snapshot(referee)
	var parts: PackedStringArray = PackedStringArray()
	for seat in range(2):
		var p: Dictionary = s["p%d" % seat]
		parts.append("%s A%d E%d F%d L%d D%d H%s P%s T%s" % [p["name"], p["aspect"], p["energy"], p["fervor"], p["life"],
			p["discard"], ",".join(p["hand"]), ",".join(p["in_play"]), p["top"]])
	parts.append("turn %d prompt %s" % [s["turn"], String(referee.engine.prompt.kind) if referee.engine.prompt != null else "-"])
	return " | ".join(parts)


## The whole script with the stand-in. `choose` may pick another open option at a player step.
## {timeline, problem, director, referee, marks}: one timeline entry per action carried out, with
## the snapshot after it; `marks` is the fingerprint the first time each step came up.
func play(last: int = 0, choose: Callable = Callable()) -> Dictionary:
	var pair: Array = fresh(last)
	var director: TutorialDirector = pair[0]
	var referee: Referee = pair[1]
	var timeline: Array[Dictionary] = []
	var marks: Dictionary = {}
	var problem: String = ""
	for _guard in range(TutorialDirector.MAX_STEPS):
		if not marks.has(director.index):
			marks[director.index] = fingerprint(referee)
		var action: Dictionary = director.next_for(referee)
		if str(action["do"]) == "end":
			break
		var step: Dictionary = action.get("step", {})
		var p: PromptView = referee.prompt_for(TutorialDirector.PLAYER)
		var entry: Dictionary = {"at": int(action["at"]), "lesson": director.lesson(), "b": int(step.get("b", -1)),
			"do": str(action["do"]), "kind": String(p.kind) if p != null and str(action["do"]) == "player" else "",
			"rival_kind": String(referee.prompt_for(TutorialDirector.RIVAL).kind) if str(action["do"]) == "rival" else "",
			"gate": action.get("gate", {}), "options": p.options.size() if p != null else 0,
			"library": (p.context.get("library", []) as Array).size() if p != null and str(action["do"]) == "player" else 0,
			"moves": open_moves(action.get("gate", {}), p, referee.view_for(TutorialDirector.PLAYER)),
			"before": snapshot(referee)}
		if trace:
			var said: PackedStringArray = PackedStringArray()
			for l in TutorialDirector.lines_of(step):
				said.append("%s: %s" % [str(l.get("who", "")), str(l.get("text", ""))])
			print("L%d b%d %s %s %s" % [entry["lesson"], entry["b"], entry["do"], entry["kind"], str(action.get("wire", step.get("callout", " / ".join(said))))])
		problem = director.play_one(referee, choose)
		if problem != "":
			break
		entry["after"] = snapshot(referee)
		entry["integrity"] = referee.engine.integrity_problem()
		timeline.append(entry)
		if trace and entry["do"] != "say":
			for ev in referee.engine.take_events():
				var line: String = CardText.event_line(ev, referee.engine, -1, true)
				if line != "":
					print("      %s" % line)
	return {"timeline": timeline, "problem": problem, "director": director, "referee": referee, "marks": marks}


func stand_in() -> Dictionary:
	if main.is_empty():
		main = play()
	return main


## The first action of lesson `n` numbered `b` in the script, of kind `what`, and `nth` of those.
func entry(run: Dictionary, n: int, b: int, what: String, nth: int = 0) -> Dictionary:
	var seen: int = 0
	for e in run["timeline"]:
		if int(e["lesson"]) == n and int(e["b"]) == b and str(e["do"]) == what:
			if seen == nth:
				return e
			seen += 1
	check(false, "lesson %d beat %d has a %s action" % [n, b, what])
	return {"before": {}, "after": {}}


func mine(e: Dictionary, when: String) -> Dictionary:
	return (e[when] as Dictionary).get("p0", {})


func theirs(e: Dictionary, when: String) -> Dictionary:
	return (e[when] as Dictionary).get("p1", {})


## The distinct moves a gate opens: two copies of one card are one move.
func open_moves(g: Dictionary, p: PromptView, v: SeatView) -> Array[String]:
	var out: Array[String] = []
	var enabled: Array = g.get("enabled", [])
	if p == null:
		return out
	for i in range(mini(enabled.size(), p.options.size())):
		if not bool(enabled[i]):
			continue
		var o: OptionView = p.options[i]
		var c: SeatCard = v.card(o.card) if o.card >= 0 else null
		var move: String = "%s %s %s" % [String(o.type), c.def_id if c != null else "", str(o.value)]
		if not out.has(move):
			out.append(move)
	return out


func open_count(g: Dictionary) -> int:
	var n: int = 0
	for on in g.get("enabled", []):
		if bool(on):
			n += 1
	return n


# --- Tests ------------------------------------------------------------------------

func test_the_whole_session_plays_through() -> void:
	var run: Dictionary = stand_in()
	eq(str(run["problem"]), "", "the script plays to its end without a mismatch")
	var director: TutorialDirector = run["director"]
	var referee: Referee = run["referee"]
	check(director.finished(), "every step was reached")
	check(referee.is_over(), "the session is over")
	eq(referee.engine.state.winner, -1, "with no winner")
	check(referee.engine.state.ended, "because it was ended, not won")
	eq(referee.view_for(0).ended, true, "and the player's view says so")
	var clean: bool = true
	for e in run["timeline"]:
		if str(e.get("integrity", "")) != "":
			clean = false
			check(false, "lesson %d beat %d: %s" % [e["lesson"], e["b"], e["integrity"]])
	check(clean, "every card sits in one place after every action")
	var lessons: Array[int] = []
	for e in run["timeline"]:
		if not lessons.has(int(e["lesson"])):
			lessons.append(int(e["lesson"]))
	eq(lessons, [1, 2, 3, 4, 5] as Array[int], "all five lessons were played, in order")


func test_each_beat_lands_its_numbers() -> void:
	var run: Dictionary = stand_in()
	# Lesson 1: the Straw Knight.
	var first: Dictionary = entry(run, 1, 6, "player")
	for id in ["signature_strike_29", "signature_strike_12", "freestyle_art_03"]:
		check((mine(first, "before")["hand"] as Array).has(id), "the first draw brings %s" % id)
	eq(mine(first, "before")["energy"], 7, "Power Up takes Emrys from 5 to 7")
	var knack: Dictionary = entry(run, 1, 8, "player")
	check((mine(knack, "after")["hand"] as Array).has("signature_strike_22"), "Emrys' Power draws the Hilt Guard")
	eq((theirs(knack, "after")["hand"] as Array).size(), 3, "the Knight drew three because Emrys declared")
	var blow: Dictionary = entry(run, 1, 9, "player")
	eq(theirs(blow, "before")["energy"], 5, "the Knight stands at 5")
	eq(theirs(blow, "after")["energy"], 0, "the Rising Blow takes it to 0")
	eq(int((blow["after"]["last_attack"] as Dictionary).get("stages_dealt", 0)), 5, "for 5 Energy")
	eq(mine(blow, "after")["fervor"], 1, "and Attunes Emrys to Fervor 1")
	var thrust: Dictionary = entry(run, 1, 11, "player")
	eq(int((thrust["after"]["last_attack"] as Dictionary).get("life_dealt", 0)), 4, "the Sword Thrust spills 4 wounds")
	eq(int(theirs(thrust, "before")["life"]) - int(theirs(thrust, "after")["life"]), 4, "off the Knight's life")
	var bolt: Dictionary = entry(run, 1, 13, "player")
	eq(mine(bolt, "after")["energy"], 5, "the Art costs 2 Energy, 7 to 5")
	eq(int((bolt["after"]["last_attack"] as Dictionary).get("life_dealt", 0)), 4, "and takes 4 cards")
	eq(table.band(int(mine(bolt, "after")["might"])), 1, "Emrys' Might falls to band B")
	eq(table.band(int(mine(bolt, "before")["might"])), 2, "from band C")
	# No critical damage in the first two lessons, and the Knight never runs dry.
	for e in run["timeline"]:
		if int(e["lesson"]) > 2:
			break
		check(str(e["kind"]) != "critical" and str(e["rival_kind"]) != "critical", "no critical damage at lesson %d beat %d" % [e["lesson"], e["b"]])
		check(int((e["after"]["last_attack"] as Dictionary).get("life_dealt", 0)) < 5, "no attack deals 5 wounds at lesson %d beat %d" % [e["lesson"], e["b"]])
		check(int(theirs(e, "after")["life"]) > 0, "the Straw Knight still has life at lesson %d beat %d" % [e["lesson"], e["b"]])
	# Lesson 2: guard.
	var rope: Dictionary = entry(run, 2, 5, "rival")
	check(bool((rope["after"]["attack"] as Dictionary).get("is_power", false)), "the Knight strikes with its Power")
	var guard_step: Dictionary = entry(run, 2, 6, "player")
	check(bool((guard_step["after"]["last_attack"] as Dictionary).get("stopped", false)), "the Hilt Guard stops it")
	eq((mine(guard_step, "after")["hand"] as Array).count("signature_strike_12"), 2, "and brings the Sword Thrust back")
	var hit: Dictionary = entry(run, 2, 11, "rival")
	eq(int(mine(hit, "before")["energy"]) - int(mine(hit, "after")["energy"]), 3, "the Knight's Strike takes 3 Energy")
	var final_strike: Dictionary = entry(run, 2, 12, "player")
	check(bool((final_strike["after"]["last_attack"] as Dictionary).get("is_final", false)), "Emrys makes a Final Strike")
	var breather: Dictionary = entry(run, 2, 15, "player")
	eq(int(mine(breather, "after")["discard"]), int(mine(breather, "before")["discard"]) - 1, "Recover takes one card off the discard pile")
	eq(int(mine(breather, "after")["life"]), int(mine(breather, "before")["life"]) + 1, "and puts it under the Life Deck")
	# Fervor over lessons 1 to 3.
	eq(mine(entry(run, 1, 17, "say"), "after")["fervor"], 1, "Fervor 1 after lesson 1")
	eq(mine(entry(run, 2, 16, "say"), "after")["fervor"], 2, "Fervor 2 after lesson 2")
	# Lesson 3: the Straw Knight is carried off and Caedan takes the seat.
	var swap: Dictionary = entry(run, 3, 0, "op")
	eq(theirs(swap, "before")["character"], "Straw Knight", "the Knight held the seat")
	eq(theirs(swap, "after")["character"], "Caedan Vale", "Caedan holds it now")
	eq(theirs(swap, "after")["energy"], 10, "fresh at full Energy")
	eq(mine(swap, "after"), mine(swap, "before"), "Emrys keeps everything")
	eq(mine(entry(run, 3, 4, "player"), "after")["fervor"], 3, "the stopped Rising Blow still Attunes, Fervor 3")
	check(bool((entry(run, 3, 5, "rival")["after"]["last_attack"] as Dictionary).get("stopped", false)), "the Riposte stops it")
	eq(mine(entry(run, 3, 8, "player"), "after")["fervor"], 4, "Risks It All, Fervor 4")
	var climb: Dictionary = entry(run, 3, 10, "player")
	eq(mine(climb, "before")["fervor"], 4, "one short of five before the last Rising Blow")
	eq(mine(climb, "before")["aspect"], 1, "on the Eldest")
	eq(mine(climb, "after")["aspect"], 2, "the Rising Blow climbs him to First Plate")
	eq(mine(climb, "after")["energy"], 10, "at full Energy")
	eq(mine(climb, "after")["fervor"], 0, "with Fervor back to 0")
	check(int((climb["after"]["last_attack"] as Dictionary).get("life_dealt", 0)) < 5, "and the Blow is no critical hit")
	# Lesson 4: Steel.
	var dealt: Dictionary = entry(run, 4, 0, "op")
	eq(mine(dealt, "after")["top"], "steel_drill_01", "the Steel cards land on top of Emrys' Life Deck")
	var drills: Dictionary = entry(run, 4, 3, "player", 1)
	check((mine(drills, "after")["in_play"] as Array).has("steel_drill_01") and (mine(drills, "after")["in_play"] as Array).has("steel_drill_04"), "both Drills are in play")
	var tail: Dictionary = entry(run, 4, 5, "player")
	eq(int(theirs(tail, "before")["energy"]) - int(theirs(tail, "after")["energy"]), 3, "the Lashing Tail with the Drill's 2 takes 3 Energy")
	eq(int((tail["after"]["last_attack"] as Dictionary).get("life_dealt", 0)), 4, "and 4 wounds, no critical")
	var shield: Dictionary = entry(run, 4, 6, "player")
	eq(str(((shield["after"]["last_attack"] as Dictionary).get("stopped_by", {}) as Dictionary).get("how", "")), "shield", "the Hardscale Drill stops the Pommel Bash by itself")
	var shout: Dictionary = entry(run, 4, 8, "rival")
	eq(mine(shout, "before")["fervor"], 1, "Emrys holds Fervor 1 before the shout")
	eq(mine(shout, "after")["fervor"], 0, "Disrupt takes it away")
	var endure: Dictionary = entry(run, 4, 9, "player")
	eq(int((endure["after"]["last_attack"] as Dictionary).get("endurance_prevented", 0)), 3, "the Taloned Fist's Endurance prevents 3")
	eq(int((endure["after"]["last_attack"] as Dictionary).get("life_dealt", 0)), 1, "so the shout costs 1 card")
	var hide: Dictionary = entry(run, 4, 13, "player")
	check(bool((hide["after"]["last_attack"] as Dictionary).get("stopped", false)), "the Ironscale Hide stops Vale's Sword Draw")
	check(int(mine(hide, "after")["energy"]) > int(mine(hide, "before")["energy"]), "and puts Energy back")
	eq(mine(hide, "after")["energy"], 10, "up to the full ten")
	# Lesson 5: both.
	var heel: Dictionary = entry(run, 5, 5, "player", 1)
	eq(int(mine(heel, "before")["life"]) - int(mine(heel, "after")["life"]), 1, "Emrys pays a card of his own life")
	var flourish: Dictionary = entry(run, 5, 3, "player", 1)
	check((mine(flourish, "after")["in_play"] as Array).has("signature_drill_01"), "the Flourish puts the Swordplay Drill into play")
	var remain: Dictionary = entry(run, 5, 7, "rival")
	check((mine(remain, "after")["in_play"] as Array).has("steel_strike_07"), "the Twin Claws stay on the table after the first swing")
	var roar: Dictionary = entry(run, 5, 11, "player")
	eq(int((roar["after"]["last_attack"] as Dictionary).get("life_dealt", 0)), 7, "the Empowered Routing Roar deals 7 wounds")
	eq(str((roar["after"]["last_attack"] as Dictionary).get("critical", "")), "fervor", "and the critical hit lowers Caedan's Fervor")
	eq(int(theirs(roar, "before")["fervor"]) - int(theirs(roar, "after")["fervor"]), 1, "by 1")
	check(int(theirs(roar, "after")["fervor"]) > 0, "Caedan still holds Fervor for the win callout")
	var peak: int = 0
	for e in run["timeline"]:
		if int(mine(e, "after")["aspect"]) >= 2:
			peak = maxi(peak, int(mine(e, "after")["fervor"]))
		check(int(theirs(e, "after")["fervor"]) < 5, "Caedan never fills his meter at lesson %d beat %d" % [e["lesson"], e["b"]])
	check(peak < 5, "Emrys never wins by filling the meter at his last Aspect")


## Every player prompt opens exactly the taught move, except the harmless choices, and every
## greyed option carries a reason. A "you may" and a search still ask.
func test_only_the_taught_move_is_open() -> void:
	var run: Dictionary = stand_in()
	var asked_may: int = 0
	var searches: int = 0
	for e in run["timeline"]:
		if str(e["do"]) != "player":
			continue
		var g: Dictionary = e["gate"]
		var open: int = open_count(g)
		var free: bool = str(e["kind"]) == "keep" or (int(e["lesson"]) == 2 and int(e["b"]) == 12)
		if free:
			check(open >= 2, "lesson %d beat %d leaves a free choice" % [e["lesson"], e["b"]])
		else:
			eq((e["moves"] as Array).size(), 1, "lesson %d beat %d opens one move" % [e["lesson"], e["b"]])
		var enabled: Array = g.get("enabled", [])
		var reasons: Array = g.get("reasons", [])
		for i in range(enabled.size()):
			if not bool(enabled[i]):
				check(str(reasons[i]) != "", "lesson %d beat %d: a greyed option has a reason" % [e["lesson"], e["b"]])
		if str(e["kind"]) == "pick_option" and int(e["options"]) == 2 and int(e["library"]) == 0:
			asked_may += 1
		if int(e["library"]) > 0:
			searches += 1
			check(str(g.get("library", "")) != "", "lesson %d beat %d: the searched deck's other cards have a reason" % [e["lesson"], e["b"]])
			check(int(e["library"]) >= int(mine(e, "before")["life"]), "lesson %d beat %d: the search shows the whole Life Deck" % [e["lesson"], e["b"]])
	check(asked_may >= 3, "Emrys' \"you may draw\" is asked every time (%d)" % asked_may)
	check(searches >= 4, "every Life Deck search is shown to the player (%d)" % searches)


## Which card is kept, or thrown for a Final Strike, never changes where the lesson goes.
func test_every_free_choice_reaches_the_same_next_beat() -> void:
	var run: Dictionary = stand_in()
	var beats: Array[String] = _beats(run)
	var tried: int = 0
	for e in run["timeline"]:
		if str(e["do"]) != "player" or open_count(e["gate"]) < 2:
			continue
		var enabled: Array = (e["gate"] as Dictionary).get("enabled", [])
		var alternatives: Array[int] = []
		for i in range(enabled.size()):
			if bool(enabled[i]):
				alternatives.append(i)
		for k in range(1, alternatives.size()):
			var at: int = int(e["at"])
			var pick: int = alternatives[k]
			var other: Dictionary = play(0, func(action: Dictionary) -> int: return pick if int(action["at"]) == at else -1)
			tried += 1
			var where: String = "lesson %d beat %d, option %d" % [e["lesson"], e["b"], pick]
			eq(str(other["problem"]), "", "%s plays on" % where)
			check((other["director"] as TutorialDirector).finished(), "%s reaches the end" % where)
			eq(_beats(other), beats, "%s walks the same beats" % where)
			var last: Dictionary = (other["timeline"] as Array).back()
			eq(mine(last, "after")["aspect"], 2, "%s still climbs" % where)
			eq(bool(last["after"]["ended"]), true, "%s ends the session" % where)
	check(tried >= 6, "the free choices were tried (%d)" % tried)


func _beats(run: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for e in run["timeline"]:
		if str(e["do"]) == "player":
			out.append("%d:%d:%s" % [e["lesson"], e["b"], e["kind"]])
	return out


func test_resuming_at_a_lesson_rebuilds_the_same_board() -> void:
	var run: Dictionary = stand_in()
	var marks: Dictionary = run["marks"]
	for n in range(2, 6):
		var pair: Array = fresh()
		var director: TutorialDirector = pair[0]
		var referee: Referee = pair[1]
		var start: int = director.lesson_start(n)
		eq(director.fast_forward(referee, start), "", "lesson %d is reached headless" % n)
		eq(director.index, start, "the director stands on lesson %d's first step" % n)
		eq(director.lesson(), n, "which belongs to lesson %d" % n)
		eq(fingerprint(referee), str(marks.get(start, "")), "the board at lesson %d is the one the whole session had there" % n)
		var catch_up: SeatUpdate = referee.catch_up(0)
		check(catch_up.view != null, "the table can open on the catch-up at lesson %d" % n)
		var clean: bool = true
		for line in catch_up.lines:
			clean = clean and not (line as Dictionary).has("data")
		check(clean, "the catch-up at lesson %d animates nothing" % n)
		eq(director.fast_forward(referee, director.steps.size()), "", "lesson %d plays on to the end" % n)
		check(director.finished() and referee.is_over(), "a session resumed at lesson %d ends" % n)
	var beat: TutorialDirector = TutorialDirector.new()
	check(beat.beat_index(3, 10) > beat.lesson_start(3), "a beat inside a lesson can be found for the dev flag")
	eq(beat.beat_index(9, 1), -1, "a beat that is not in the script is not found")


## Seed, commands and script operations: the same session, which is what a save could rebuild.
func test_the_session_replays_from_its_history() -> void:
	var run: Dictionary = stand_in()
	var original: Referee = run["referee"]
	var scripted: int = 0
	for h in original.history:
		if (h as Dictionary).has("script"):
			scripted += 1
	check(scripted >= 8, "the board adjustments are in the history (%d)" % scripted)
	var copy: Referee = (run["director"] as TutorialDirector).build_referee(lib, table, false)
	eq(copy.replay(original.history), "", "the history replays")
	eq(fingerprint(copy), fingerprint(original), "to the same table")
	check(copy.is_over() and copy.engine.state.winner == -1, "and the same ended session")


func test_a_shorter_range_ends_after_its_last_lesson() -> void:
	var run: Dictionary = play(2)
	eq(str(run["problem"]), "", "lessons 1 and 2 play through")
	var director: TutorialDirector = run["director"]
	eq(director.last_lesson(), 2, "the range stops at lesson 2")
	eq(director.final_lesson(), 5, "the script still knows its last lesson")
	var referee: Referee = run["referee"]
	check(referee.is_over() and referee.engine.state.winner == -1, "the session ends with no winner after lesson 2")
	for e in run["timeline"]:
		check(int(e["lesson"]) <= 2, "nothing of lesson 3 is played")


func test_the_straw_knight_stays_out_of_the_shipped_pool() -> void:
	var shipped: CardLibrary = CardLibrary.new()
	shipped.load_dir("res://data/cards")
	check(not shipped.has("tutorial_personality_01"), "the shipped pool has no Straw Knight")
	check(lib.has("tutorial_personality_01"), "the tutorial's library does")
	var knight: CardDef = lib.get_def("tutorial_personality_01")
	eq(knight.title, "Straw Knight", "by that name")
	var might: Array = knight.aspect_data(1).get("might", [])
	var flat: bool = might.size() == 11
	for m in might:
		flat = flat and int(m) == 5
	check(flat, "Might 5 at every stage")
	eq(int(knight.aspect_data(1).get("surge", 0)), 2, "Surge 2")
	eq(str((knight.aspect_data(1).get("power", {}) as Dictionary).get("attack", {}).get("kind", "")), "strike", "its Power is a Strike")
	check(not AdventureProgress.school_pool("freestyle", lib).has("tutorial_personality_01"), "no reward pool offers it")
	for dir in DeckList.DIRS:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".json"):
				check(not FileAccess.get_file_as_string(dir.path_join(f)).contains("tutorial_"), "%s/%s does not run a tutorial card" % [dir, f])
	var director: TutorialDirector = TutorialDirector.new()
	for key in director.decks:
		var d: DeckList = director.deck(str(key))
		for id in d.cards:
			var def: CardDef = lib.get_def(id)
			check(not def.title.contains("PLACEHOLDER"), "%s holds no placeholder card (%s)" % [key, id])
			if def.character != "" and not def.is_personality():
				var owner: String = lib.get_def(d.duelist_ids[0]).character
				eq(def.character, owner, "%s holds only its own signature cards (%s)" % [key, id])


func test_the_saved_lesson_lives_in_the_profile() -> void:
	var p: AdventureProgress = AdventureProgress.new()
	eq(p.tutorial_resume_lesson(), 1, "a new profile starts at lesson 1")
	p.reach_lesson(3)
	p.reach_lesson(2)
	eq(p.tutorial_resume_lesson(), 3, "the lesson reached only moves forward")
	var back: AdventureProgress = AdventureProgress.from_dict(JSON.parse_string(JSON.stringify(p.to_dict())))
	eq(back.tutorial_lesson, 3, "and survives the save")
	back.finish_tutorial()
	check(back.tutorial_done, "finishing marks it done")
	eq(back.tutorial_resume_lesson(), 1, "and the next session starts from lesson 1")
	eq(AdventureProgress.from_dict({}).tutorial_lesson, 0, "an older save reads as never begun")


# --- Words and pacing ---------------------------------------------------------------

## Every line of a step as {who, text, ring, lesson}, the words of a move included.
func all_lines(director: TutorialDirector) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s in director.steps:
		var said: Array[Dictionary] = TutorialDirector.lines_of(s)
		if not TutorialDirector.says_of(s).is_empty():
			said.append(TutorialDirector.says_of(s))
		if s.has("callout"):
			said.append({"who": "vale", "text": s["callout"], "ring": s.get("ring", [])})
		for l in said:
			var line: Dictionary = l.duplicate()
			line["lesson"] = int(s.get("lesson", 0))
			out.append(line)
	return out


## Everything the script can put on screen: lines, callouts and greyed-option reasons.
func all_words(director: TutorialDirector) -> Array[String]:
	var out: Array[String] = []
	for l in all_lines(director):
		out.append(str(l.get("text", "")))
	for s in director.steps:
		for r in (s.get("reasons", {}) as Dictionary).values():
			out.append(str(r))
		if s.has("library"):
			out.append(str(s["library"]))
	out.append(str(director.data.get("reason", "")))
	return out


static func ring_targets(ring: Variant) -> Array[String]:
	var out: Array[String] = []
	for r in (ring if ring is Array else [ring]):
		if str(r) != "":
			out.append(str(r))
	return out


## At most 4, 3, 4, 3 and 3 stops in lessons 1 to 5; every other line is a bark or the words of a
## move. The two ways to win are said in lesson 1, where they first happen.
func test_each_lesson_stops_the_table_only_a_few_times() -> void:
	var director: TutorialDirector = TutorialDirector.new()
	var caps: Array[int] = [4, 3, 4, 3, 3]
	var total: int = 0
	for n in range(1, 6):
		var stops: int = director.stop_count(n)
		total += stops
		check(stops >= 1 and stops <= caps[n - 1], "lesson %d stops %d times, at most %d" % [n, stops, caps[n - 1]])
	check(total <= 17, "%d stops in all, at most 17" % total)
	var barks: int = 0
	for s in director.steps:
		if s.has("bark"):
			barks += 1
	var shown: int = 0
	for e in stand_in()["timeline"]:
		if str(e["do"]) == "bark":
			shown += 1
	eq(shown, barks, "every bark is reached")
	var life_win: Dictionary = {}
	var fervor_win: Dictionary = {}
	for l in all_lines(director):
		var rings: Array[String] = ring_targets(l.get("ring", []))
		if life_win.is_empty() and rings.has("life_deck:rival"):
			life_win = l
		if fervor_win.is_empty() and rings.has("fervor:you"):
			fervor_win = l
	eq(int(life_win.get("lesson", 0)), 1, "the Life Deck is first pointed at in lesson 1")
	check(str(life_win.get("text", "")).contains("win"), "and the line says emptying it wins")
	eq(int(fervor_win.get("lesson", 0)), 1, "the Fervor meter is first pointed at in lesson 1")
	check(str(fervor_win.get("text", "")).contains("climb"), "and the line says five Fervor climbs")
	for s in director.steps:
		if not s.has("stop"):
			continue
		var wait: float = 0.0
		for l in TutorialDirector.lines_of(s):
			wait += TutorialPacing.line_time(str(director.speaker(str(l.get("who", ""))).get("at", "")), str(l.get("text", "")))
		check(wait <= 12.0, "the stop at lesson %d beat %d reads in %.1f s" % [int(s["lesson"]), int(s.get("b", -1)), wait])


const RING_KINDS: Array[String] = ["life_deck", "discard", "ladder", "power", "fervor", "aspect", "hand", "number", "text",
	"drill", "prompt", "tray", "duelist"]


## Emrys shouts at his card, Caedan at his once he fights, Vale speaks from the coach box, and a
## note from the box always points at something.
func test_every_line_has_a_speaker_and_a_place() -> void:
	var director: TutorialDirector = TutorialDirector.new()
	var places: Array[String] = ["coach", "caption", "you", "rival"]
	for l in all_lines(director):
		var who: String = str(l.get("who", ""))
		var where: String = "lesson %d \"%s\"" % [int(l["lesson"]), str(l.get("text", ""))]
		check((director.data["speakers"] as Dictionary).has(who), "%s has a known speaker (%s)" % [where, who])
		check(places.has(str(director.speaker(who).get("at", ""))), "%s shows somewhere" % where)
		check(str(l.get("text", "")) != "", "%s says something" % where)
		if who == "caedan":
			check(int(l["lesson"]) >= 3, "%s: Caedan speaks at the rival card only once he fights" % where)
		for target in ring_targets(l.get("ring", [])):
			check(RING_KINDS.has(target.get_slice(":", 0)), "%s rings a known target (%s)" % [where, target])
	for s in director.steps:
		var note: Array[Dictionary] = []
		if s.has("bark"):
			note = TutorialDirector.lines_of(s)
		if not TutorialDirector.says_of(s).is_empty():
			note.append(TutorialDirector.says_of(s))
		for l in note:
			if str(l.get("who", "")) == "vale":
				check(not ring_targets(l.get("ring", [])).is_empty(), "Vale's note \"%s\" points at something" % str(l.get("text", "")))
		if s.has("player") and s.has("callout") and str(s["player"]) != "keep":
			check(not ring_targets(s.get("ring", [])).is_empty(), "lesson %d beat %d: the callout points at the move" % [int(s["lesson"]), int(s.get("b", -1))])


## Real sentences, short ones, and no dashes.
func test_the_words_on_screen_follow_the_house_rules() -> void:
	var director: TutorialDirector = TutorialDirector.new()
	for text in all_words(director):
		check(not text.contains("—") and not text.contains("–") and not text.contains(" - "), "\"%s\" has no dash" % text)
		check(text.strip_edges() == text and text != "", "\"%s\" is trimmed" % text)
		var last: String = text.right(1)
		check(last == "." or last == "!" or last == "?", "\"%s\" ends as a sentence" % text)
	for s in director.steps:
		if s.has("callout"):
			var words: int = TutorialPacing.words(str(s["callout"]))
			check(words <= 18, "lesson %d beat %d: the callout is %d words" % [int(s["lesson"]), int(s.get("b", -1)), words])
	var total: int = 0
	for l in all_lines(director):
		total += TutorialPacing.words(str(l.get("text", "")))
	check(total <= 550, "%d words of lines and callouts" % total)
	print("  %d words of lines and callouts" % total)


## Once Caedan is the rival, the coach box, the callouts and the reasons speak as him: "my Fervor",
## never "his".
func test_vale_speaks_for_himself_once_he_fights() -> void:
	var director: TutorialDirector = TutorialDirector.new()
	var third: RegEx = RegEx.create_from_string("(?i)\\b(he|him|his|caedan|caedan's)\\b")
	var first: RegEx = RegEx.create_from_string("(?i)\\b(i|me|my|mine)\\b")
	var mine: int = 0
	for l in all_lines(director):
		if int(l["lesson"]) < 3 or str(l.get("who", "")) != "vale":
			continue
		var text: String = str(l.get("text", ""))
		check(third.search(text) == null, "lesson %d: \"%s\" speaks as Vale" % [int(l["lesson"]), text])
		if first.search(text) != null:
			mine += 1
	for s in director.steps:
		if int(s.get("lesson", 0)) < 3:
			continue
		for r in (s.get("reasons", {}) as Dictionary).values():
			check(third.search(str(r)) == null, "lesson %d: the reason \"%s\" speaks as Vale" % [int(s["lesson"]), str(r)])
	check(mine >= 3, "Vale says I, me or my in lessons 3 to 5 (%d)" % mine)


func test_a_stop_reads_itself_on() -> void:
	eq(TutorialPacing.read_time("Declare Combat."), 2.0, "a short line stays at least 2 s")
	check(is_equal_approx(TutorialPacing.read_time("one two three four five six seven eight nine ten"), 3.8), "0.8 s plus 0.3 s a word")
	eq(TutorialPacing.read_time("word ".repeat(40).strip_edges()), 7.0, "and at most 7 s")
	eq(TutorialPacing.bark_time("HAH!"), 1.4, "a bark stays at least 1.4 s")
	eq(TutorialPacing.bark_time("x".repeat(80)), 3.2, "and at most 3.2 s")
	check(is_equal_approx(TutorialPacing.bark_time("x".repeat(20)), 1.8), "0.9 s plus 0.045 s a character")
	eq(TutorialPacing.line_time("you", "HAH!"), TutorialPacing.bark_time("HAH!"), "a line at a card is a bark")
	eq(TutorialPacing.line_time("coach", "HAH!"), TutorialPacing.read_time("HAH!"), "a line in the box is read")
	check(is_equal_approx(TutorialPacing.reveal_time("x".repeat(18)), 0.2), "typed at 90 characters a second")
	eq(TutorialPacing.reveal_time("x".repeat(200)), 0.45, "in 0.45 s at most")
	check(TutorialPacing.shouted("It's STRAW, Master Vale!"), "a word in capitals is shouted")
	check(not TutorialPacing.shouted("I know what hits."), "a lone capital I is not")
	var clock: TutorialPacing = TutorialPacing.new([2.0, 1.5] as Array[float], [0.2, 0.1] as Array[float])
	check(not clock.tick(1.0, false), "halfway through the first line")
	check(is_equal_approx(clock.left(), 0.5), "the bar shows half left")
	check(not clock.tick(5.0, true), "a pointer on the box pauses it")
	eq(clock.line, 0, "still on the first line")
	check(clock.tick(1.0, false), "the first line's time runs out")
	eq(clock.line, 1, "on to the second")
	check(clock.tick(1.5, false) and clock.finished(), "and the stop ends on its own")


func test_a_held_stop_waits_for_the_click() -> void:
	var clock: TutorialPacing = TutorialPacing.new([2.0, 3.0] as Array[float], [0.1, 0.1] as Array[float], true)
	clock.tick(2.0, false)
	eq(clock.line, 1, "the first line of a held stop still times out")
	for _i in range(20):
		clock.tick(1.0, false)
	check(not clock.finished(), "the last line does not")
	check(clock.waits_for_click(), "it waits for the click")
	eq(clock.left(), 0.0, "with no timer bar")
	check(clock.skip() and clock.finished(), "and the click ends it")


func test_a_click_finishes_the_line_then_moves_on() -> void:
	var clock: TutorialPacing = TutorialPacing.new([4.0, 4.0] as Array[float], [0.4, 0.4] as Array[float])
	clock.tick(0.1, false)
	check(clock.revealed() < 1.0, "the line is still typing")
	check(not clock.skip(), "a click while it types")
	eq(clock.revealed(), 1.0, "shows the rest at once")
	eq(clock.line, 0, "and stays on the line")
	check(clock.skip(), "the next click")
	eq(clock.line, 1, "moves to the next line")
	clock.skip()
	clock.skip()
	check(clock.finished(), "and past the last one the stop is over")
