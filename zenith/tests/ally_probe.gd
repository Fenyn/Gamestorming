extends SceneTree
## Counts what actually happens to one deck's Allies: how often one is in play, how often the Duelist
## is spent enough for a takeover, how often both hold at once, who ends up performing the attacks,
## and how much damage gets redirected. Written to tell an Ally deck that is losing on its cards apart
## from one losing because the takeover condition never comes up.
## Polls engine state after every command rather than reading events, since the Referee drains those.
##
## godot --headless --path zenith -s tests/ally_probe.gd -- --deck=tide_companions --repeats=6

const MAX_STEPS: int = 6000


func _init() -> void:
	var args: Dictionary = {"deck": "tide_companions", "repeats": "6", "seed": "77"}
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
	var phases: int = 0
	var phases_low: int = 0
	var ally_turns: int = 0
	var turns: int = 0

	for r in range(int(args["repeats"])):
		for foe in foes:
			for seat in [0, 1]:
				games += 1
				var decks: Array[DeckList] = [null, null]
				decks[seat] = DeckList.load_from("res://data/decks/%s.json" % me)
				decks[1 - seat] = DeckList.load_from("res://data/decks/%s.json" % foe)
				var ref: Referee = Referee.new()
				ref.setup(decks, lib, table, rng.randi())
				ref.start()
				var players: Array[AiPlayer] = [
					AiPlayer.new(fresh(decks[0]), games * 2),
					AiPlayer.new(fresh(decks[1]), games * 2 + 1),
				]
				var in_attack: bool = false
				var bonded: bool = false
				var fusees_seen: bool = false
				var rite_seen: bool = false
				var both_seen: bool = false
				var first_ally: int = -1
				var relic_seen: bool = false
				var rite_was_out: bool = false
				var seen_ally: Dictionary = {}
				var live_allies: Dictionary = {}
				var last_turn: int = 0
				var steps: int = 0
				var st: GameState = ref.engine.state
				while not ref.is_over() and steps < MAX_STEPS:
					steps += 1
					var who: int = ref.engine.prompt.player
					var kind: StringName = ref.engine.prompt.kind
					if who == seat:
						if kind == &"control":
							bump(n, "control_prompt")
							bump(n, "control_%s" % str(ref.engine.prompt.context.get("role", "?")))
						if kind == &"attack_action" and st.attacker == seat:
							var holder: CardInstance = st.players[seat].in_control()
							# Ally is a role, not a type: whoever holds Combat and is not the Duelist.
							if holder != null and holder != st.players[seat].duelist:
								bump(n, "phase_with_ally_in_control")
						if kind == &"redirect":
							bump(n, "redirect_prompt")
						if kind == &"attack_action" and st.attacker == seat:
							phases += 1
							if st.players[seat].duelist.energy <= 1:
								phases_low += 1
					var chosen: Dictionary = players[who].choose(ref, who)
					if who == seat and str(chosen.get("type", "")) == "declare":
						bump(n, "declared")
					if who == seat and str(chosen.get("type", "")) in ["use", "attack", "relic", "place"]:
						var played: CardInstance = ref.engine.card(int(chosen.get("card", -1)))
						if played != null:
							bump(n, "played_%s" % played.def.id)
					ref.submit(who, chosen)
					# One sample per turn of how many Allies we have out and who holds Combat.
					if st.turn != last_turn:
						last_turn = st.turn
						turns += 1
						var out: int = st.players[seat].allies().size()
						n["allies_out"] = int(n.get("allies_out", 0)) + out
						if out > 0:
							bump(n, "turns_with_ally")
							if first_ally < 0:
								first_ally = st.turn
								n["first_ally_turn"] = int(n.get("first_ally_turn", 0)) + st.turn
								bump(n, "games_with_any_ally")
						if st.players[seat].duelist.energy <= 1:
							bump(n, "turns_low")
							if out > 0:
								bump(n, "turns_low_with_ally")
						# A deck that camps its first aspect for a constant power loses that power the
						# moment Fervor pushes it up a rung, so count the turns it spent off the rung.
						if st.players[seat].duelist.aspect > 1:
							bump(n, "turns_off_aspect_1")
						n["fervor"] = int(n.get("fervor", 0)) + st.players[seat].fervor
					# Fusions: the two named Allies becoming one card, and the two things that gate it.
					for al in st.players[seat].allies():
						if not (al.def.raw.get("bond_of", []) as Array).is_empty():
							if not bonded:
								bonded = true
								bump(n, "bonds_formed")
							bump(n, "bond_steps")
					if not relic_seen and st.players[seat].relic_uses > 0:
						relic_seen = true
						bump(n, "relic_used")
					if not fusees_seen and _fusees_ready(ref.engine, st.players[seat]):
						fusees_seen = true
						bump(n, "fusees_ready")
					var rite_out: bool = false
					for nc in st.players[seat].non_combats():
						if _def_bonds(nc.def):
							rite_out = true
							break
					if rite_out and not rite_seen:
						rite_seen = true
						bump(n, "rite_in_play")
					# The Bonding card leaving play without a fusion means it was spent for nothing.
					if rite_was_out and not rite_out and not bonded:
						bump(n, "rite_wasted")
					rite_was_out = rite_out
					# Both gates open at once, which is the only moment the fusion can be chosen.
					if rite_out and _fusees_ready(ref.engine, st.players[seat]):
						if not both_seen:
							both_seen = true
							bump(n, "both_ready")
						if who == seat and kind == &"attack_action":
							bump(n, "chance_offered")
					# Allies that were on the table and are not any more: the fusion eats two, anything
					# else is a loss. Critical damage discards Allies whatever a constant says.
					var now_out: Dictionary = {}
					for al in st.players[seat].allies():
						now_out[al.uid] = true
					for uid in live_allies:
						if now_out.has(uid) or bonded:
							continue
						bump(n, "ally_lost")
						if str(st.attack.get("critical", "")) == "ally":
							bump(n, "ally_lost_critical")
						elif st.attack.is_empty():
							bump(n, "ally_lost_outside_attack")
						else:
							bump(n, "ally_lost_in_attack")
						bump(n, "lost_at_step_%d_phase_%d" % [st.step, st.phase])
						var holder: CardInstance = st.players[seat].in_control()
						bump(n, "lost_while_%s" % ("ally_in_control" if holder != st.players[seat].duelist else "duelist_in_control"))
						var gone: CardInstance = ref.engine.card(uid)
						if gone != null:
							bump(n, "lost_to_zone_%s" % gone.zone)
					live_allies = now_out
					# Which Allies actually reach the table, by id, and whether we got to Combat at all.
					for al in st.players[seat].allies():
						if not seen_ally.has(al.def.id):
							seen_ally[al.def.id] = true
							bump(n, "ally_%s" % al.def.id)
					var ic: CardInstance = st.players[seat].controlling
					if ic != null and ic != st.players[seat].duelist:
						ally_turns += 1
					# Each attack record counted once, as it opens, by who performs it.
					if st.attack.is_empty():
						in_attack = false
					elif not in_attack:
						in_attack = true
						var perf: CardInstance = ref.engine.card(int(st.attack.get("performer", -1)))
						if perf != null and int(st.attack.get("attacker", -1)) == seat:
							bump(n, "duelist_attack" if perf == st.players[seat].duelist else "ally_attack")
				if ref.is_over() and ref.engine.state.winner == seat:
					wins += 1

	print("%s: %d games, %d wins (%.1f%%), %d turns" % [me, games, wins, 100.0 * float(wins) / float(maxi(1, games)), turns])
	print("  Allies in play, averaged over turns  %5.2f" % (float(int(n.get("allies_out", 0))) / float(maxi(1, turns))))
	print("  turns with at least one Ally out     %4.0f%%" % (100.0 * per(n, "turns_with_ally", turns)))
	print("  first Ally lands on turn              %4.1f   (in %.0f%% of games at all)" % [
		float(int(n.get("first_ally_turn", 0))) / float(maxi(1, int(n.get("games_with_any_ally", 0)))),
		100.0 * per(n, "games_with_any_ally", games)])
	print("  the Sensei was spent in              %4.0f%% of games" % (100.0 * per(n, "relic_used", games)))
	print("  turns with the Duelist at 0 or 1     %4.0f%%" % (100.0 * per(n, "turns_low", turns)))
	print("  turns spent above aspect 1           %4.0f%%   (mean Fervor %.1f)" % [
		100.0 * per(n, "turns_off_aspect_1", turns), per(n, "fervor", turns)])
	print("  ...and an Ally out at the same time  %4.0f%%" % (100.0 * per(n, "turns_low_with_ally", turns)))
	print("  control prompts offered to us        %5.2f per game (attacker %.2f, defender %.2f)" % [
		per(n, "control_prompt", games), per(n, "control_attacker", games), per(n, "control_defender", games)])
	print("  attack phases with an Ally holding   %5.2f per game" % per(n, "phase_with_ally_in_control", games))
	print("  redirect prompts offered to us       %5.2f per game" % per(n, "redirect_prompt", games))
	print("  games with both Bond partners out    %4.0f%%" % (100.0 * per(n, "fusees_ready", games)))
	print("  games the Bonding card reached play  %4.0f%%" % (100.0 * per(n, "rite_in_play", games)))
	print("  games both gates were open at once   %4.0f%%   (%.1f attack phases to take it)" % [100.0 * per(n, "both_ready", games), per(n, "chance_offered", games)])
	print("  Bonding cards spent for nothing      %5.2f per game" % per(n, "rite_wasted", games))
	for id in ["old_trick", "lobbed_bolt", "lucky_find", "bonding_rite", "rallying_call", "warding_call", "open_challenge",
			"marrows_retinue", "dismissal", "breakers_yard", "locked_gate_drill", "assembly_drill"]:
		if n.has("played_%s" % id):
			print("    played %-18s %5.2f per game" % [id, per(n, "played_%s" % id, games)])
	for id in ["companion_alpha", "companion_beta", "companion_gamma", "companion_delta", "bonded_pair",
			"salvage_alpha", "salvage_beta", "salvage_gamma", "henchman_epsilon"]:
		if n.has("ally_%s" % id):
			print("    %-18s reached play in %3.0f%% of games" % [id, 100.0 * per(n, "ally_%s" % id, games)])
	print("  Allies lost off the table            %5.2f per game (critical %.2f, in an attack %.2f, elsewhere %.2f)" % [
		per(n, "ally_lost", games), per(n, "ally_lost_critical", games),
		per(n, "ally_lost_in_attack", games), per(n, "ally_lost_outside_attack", games)])
	for k in n.keys():
		if str(k).begins_with("lost_"):
			print("      %-32s %5.2f per game" % [str(k), per(n, str(k), games)])
	print("  combats declared by us               %5.2f per game" % per(n, "declared", games))
	print("  games that formed the Bond           %4.0f%%" % (100.0 * per(n, "bonds_formed", games)))
	print("  attacks performed by an Ally         %5.2f per game" % per(n, "ally_attack", games))
	print("  attacks performed by the Duelist     %5.2f per game" % per(n, "duelist_attack", games))
	print("  our attack phases                    %5.2f per game" % (float(phases) / float(maxi(1, games))))
	print("  ...with the Duelist at 0 or 1 Energy %d of %d (%.0f%%)" % [phases_low, phases, 100.0 * float(phases_low) / float(maxi(1, phases))])
	quit()


func fresh(deck: DeckList) -> AiProfile:
	var profile: AiProfile = AiProfile.for_deck(deck, "")
	profile.merge({"think": {"search": false}})
	return profile


func per(n: Dictionary, key: String, games: int) -> float:
	return float(int(n.get(key, 0))) / float(maxi(1, games))


func bump(n: Dictionary, key: String) -> void:
	n[key] = int(n.get(key, 0)) + 1


## The named partners a Bonding card asks for, all in play at once.
func _fusees_ready(engine: DuelEngine, p: PlayerState) -> bool:
	for c in p.life_deck + p.hand + p.discard + p.reserve + p.in_play:
		var names: Array = c.def.raw.get("bond_of", [])
		if names.is_empty():
			continue
		var found: int = 0
		for al in p.allies():
			if names.has(al.def.character):
				found += 1
		if found == names.size():
			return true
	return false


## A Non-Combat whose power is the fusion itself.
func _def_bonds(def: CardDef) -> bool:
	for e in def.effects:
		if str(e.get("op", "")) == "bond":
			return true
	return false
