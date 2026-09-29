extends SceneTree
## Counts whether an Art deck uses its Allies as a second pool of Energy. An Ally in control pays an
## Art's cost from its own Energy, so an Ally left standing after the Duelist is spent is a way to
## keep casting. This probe counts the moments that decide it: the attacker's control prompt
## (does Combat go to an Ally who can pay for an Art the Duelist cannot), the start of each attack
## phase (Arts in hand that nobody holding Combat can pay for, though an Ally could), and each
## redirect (is the hit put on the one Ally who could still cast).
##
## godot --headless --path zenith -s tests/art_ally_probe.gd -- --deck=storm_mentor --repeats=4

const MAX_STEPS: int = 6000


func _init() -> void:
	var args: Dictionary = {"deck": "storm_mentor", "repeats": "4", "seed": "77", "policy": "scorer", "budget": ""}
	for raw in OS.get_cmdline_user_args():
		var parts: PackedStringArray = raw.trim_prefix("--").split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else "1"
	var lib: CardLibrary = CardLibrary.new()
	lib.load_dir("res://data/cards")
	var table: StrikeTable = StrikeTable.load_from("res://data/strike_table.json")
	var me: String = str(args["deck"])
	var foes: Array[String] = []
	var dir: DirAccess = DirAccess.open("res://data/decks")
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if entry.ends_with(".json") and entry.trim_suffix(".json") != me:
			foes.append(entry.trim_suffix(".json"))
		entry = dir.get_next()
	foes.sort()

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(args["seed"])
	var n: Dictionary = {}
	var games: int = 0
	var wins: int = 0
	for r in range(int(args["repeats"])):
		for foe in foes:
			for seat in [0, 1]:
				games += 1
				var decks: Array[DeckList] = [null, null]
				decks[seat] = DeckList.load_from("res://data/decks/%s.json" % me)
				decks[1 - seat] = DeckList.load_from("res://data/decks/%s.json" % foe)
				var ref: Referee = Referee.new()
				ref.setup(decks, lib, table, rng.randi(), [], false)
				ref.start()
				ref.engine.take_events()
				var players: Array[AiPlayer] = [
					AiPlayer.new(SimSeat.from_legacy(str(args["policy"]), args).make_profile(decks[0]), games * 2),
					AiPlayer.new(SimSeat.from_legacy(str(args["policy"]), args).make_profile(decks[1]), games * 2 + 1),
				]
				var st: GameState = ref.engine.state
				var eng: DuelEngine = ref.engine
				var last_phase: int = -1
				var in_attack: bool = false
				var steps: int = 0
				while not ref.is_over() and steps < MAX_STEPS:
					steps += 1
					var who: int = eng.prompt.player
					var kind: StringName = eng.prompt.kind
					var p: PlayerState = st.players[seat]
					if who == seat and kind == &"attack_action" and st.attacker == seat and st.attack_phase_count != last_phase:
						last_phase = st.attack_phase_count
						_phase_start(eng, p, n)
					var before: Dictionary = {}
					if who == seat and kind == &"control":
						before = _control_context(eng, p)
					if who == seat and kind == &"redirect":
						before = _redirect_context(eng, p)
					var chosen: Dictionary = players[who].choose(ref, who)
					if who == seat and kind == &"control":
						_control_seen(eng, p, str(eng.prompt.context.get("role", "?")), before, int(chosen.get("card", -1)), n)
					if who == seat and kind == &"redirect":
						_redirect_seen(eng, p, before, int(chosen.get("card", -1)), n)
					ref.submit(who, chosen)
					eng.take_events()
					if st.attack.is_empty():
						in_attack = false
					elif not in_attack:
						in_attack = true
						if int(st.attack.get("attacker", -1)) == seat and str(st.attack.get("kind", "")) == "art":
							var perf: CardInstance = eng._performer(st.attack)
							bump(n, "art_by_duelist" if perf == p.duelist else "art_by_ally")
				if ref.is_over() and eng.state.winner == seat:
					wins += 1

	print("%s: %d games, %d wins (%.1f%%)" % [me, games, wins, 100.0 * float(wins) / float(maxi(1, games))])
	print("  Arts cast by the Duelist / by an Ally          %5.2f / %5.2f per game" % [per(n, "art_by_duelist", games), per(n, "art_by_ally", games)])
	print("  our attack phases                              %5.2f per game" % per(n, "phases", games))
	print("    with an Art in hand                          %5.2f" % per(n, "phases_with_art", games))
	print("    ...none payable by whoever holds Combat      %5.2f" % per(n, "phases_art_stranded", games))
	print("    ...but an Ally in play could pay one         %5.2f  (handover open %.2f, Duelist not spent %.2f)" % [
		per(n, "stranded_ally_could", games), per(n, "stranded_ally_could_open", games), per(n, "stranded_ally_could_closed", games)])
	var keys: Array = n.keys()
	keys.sort()
	for k in keys:
		if str(k).begins_with("stranded_") and not str(k).begins_with("stranded_ally_could"):
			print("      %-34s %5.2f" % [str(k), per(n, str(k), games)])
	print("  attacker control prompts                    %5.2f per game" % per(n, "control_attacker", games))
	print("    Ally could cast an Art the Duelist cannot    %5.2f  (took the Ally %.2f, kept the Duelist %.2f)" % [
		per(n, "control_gap", games), per(n, "control_gap_ally", games), per(n, "control_gap_duelist", games)])
	print("    chose an Ally who can cast nothing in hand   %5.2f" % per(n, "control_ally_no_art", games))
	print("  defender control prompts                       %5.2f per game (chose an Ally %.2f)" % [per(n, "control_defender", games), per(n, "control_defender_ally", games)])
	print("  redirect prompts                               %5.2f per game (hit on an Ally %.2f, on the Duelist %.2f)" % [
		per(n, "redirect", games), per(n, "redirect_ally", games), per(n, "redirect_duelist", games)])
	print("    hit drained the only Ally who could cast     %5.2f" % per(n, "redirect_drained_caster", games))
	print("    Duelist took it and a casting Ally was saved %5.2f" % per(n, "redirect_saved_caster", games))
	print("    Ally caster standing, Duelist spent, hit on Duelist cost wounds %5.2f" % per(n, "redirect_saved_cost_wounds", games))
	quit()


func _arts(p: PlayerState) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for c in p.hand:
		if c.def.is_attack() and c.def.attack_kind() == "art":
			out.append(c)
	return out


func _can_cast(eng: DuelEngine, who: CardInstance, p: PlayerState) -> bool:
	for c in _arts(p):
		if eng._can_pay(who, p, c.def.attack, c) and eng._attack_allowed(p, c.def):
			return true
	return false


func _phase_start(eng: DuelEngine, p: PlayerState, n: Dictionary) -> void:
	bump(n, "phases")
	if _arts(p).is_empty():
		return
	bump(n, "phases_with_art")
	if _can_cast(eng, p.in_control(), p):
		return
	bump(n, "phases_art_stranded")
	bump(n, "stranded_allies_%d" % mini(p.allies().size(), 2))
	bump(n, "stranded_duelist_energy_%d" % mini(p.in_control().energy, 4))
	var cheapest: int = 99
	for c in _arts(p):
		cheapest = mini(cheapest, eng._cost_stages(c.def.attack, p, c))
	bump(n, "stranded_cheapest_%d" % mini(cheapest, 5))
	for al in p.allies():
		bump(n, "stranded_ally_energy_%d" % mini(al.energy, 4))
	for al in p.allies():
		if al != p.in_control() and _can_cast(eng, al, p):
			bump(n, "stranded_ally_could")
			bump(n, "stranded_ally_could_open" if eng.may_ally_control(p) else "stranded_ally_could_closed")
			return


func _control_context(eng: DuelEngine, p: PlayerState) -> Dictionary:
	var casters: Array = []
	for o in eng.prompt.options:
		var c: CardInstance = eng.card(o.card)
		if c != null and c != p.duelist and _can_cast(eng, c, p):
			casters.append(c.uid)
	return {"duelist_casts": _can_cast(eng, p.duelist, p), "casters": casters}


func _control_seen(eng: DuelEngine, p: PlayerState, role: String, before: Dictionary, chosen: int, n: Dictionary) -> void:
	var picked: CardInstance = eng.card(chosen)
	if role == "defender":
		bump(n, "control_defender")
		if picked != null and picked != p.duelist:
			bump(n, "control_defender_ally")
		return
	bump(n, "control_attacker")
	var casters: Array = before["casters"]
	if not bool(before["duelist_casts"]) and not casters.is_empty():
		bump(n, "control_gap")
		bump(n, "control_gap_ally" if casters.has(chosen) else "control_gap_duelist")
	if picked != null and picked != p.duelist and not casters.has(chosen) and not _arts(p).is_empty():
		bump(n, "control_ally_no_art")


## Who could cast before the hit, and what each target's Energy would be after it.
func _redirect_context(eng: DuelEngine, p: PlayerState) -> Dictionary:
	var stages: int = int(eng.damage_breakdown(eng.state.attack).get("stages", 0))
	var casters: Array = []
	for al in p.allies():
		if _can_cast(eng, al, p):
			casters.append(al.uid)
	return {"stages": stages, "casters": casters, "duelist_energy": p.duelist.energy}


func _redirect_seen(eng: DuelEngine, p: PlayerState, before: Dictionary, chosen: int, n: Dictionary) -> void:
	bump(n, "redirect")
	var picked: CardInstance = eng.card(chosen)
	var casters: Array = before["casters"]
	var stages: int = int(before["stages"])
	if picked == null:
		return
	if picked == p.duelist:
		bump(n, "redirect_duelist")
		if not casters.is_empty():
			bump(n, "redirect_saved_caster")
			if int(before["duelist_energy"]) < stages:
				bump(n, "redirect_saved_cost_wounds")
		return
	bump(n, "redirect_ally")
	if casters.size() == 1 and casters.has(chosen):
		var keep: int = picked.energy
		picked.energy = maxi(0, keep - stages)
		var still: bool = _can_cast(eng, picked, p)
		picked.energy = keep
		if not still:
			bump(n, "redirect_drained_caster")


func per(n: Dictionary, key: String, games: int) -> float:
	return float(int(n.get(key, 0))) / float(maxi(1, games))


func bump(n: Dictionary, key: String) -> void:
	n[key] = int(n.get(key, 0)) + 1
