extends SceneTree
## Headless engine tests. No autoloads involved, so `-s` works directly.
##
## From the repo root, with the 4.6 binary:
##   godot --headless --path zenith --import          (once after adding class_name scripts)
##   godot --headless --path zenith -s tests/run_tests.gd
## Exit code is 1 when any check fails.

const CARDS_DIR: String = "res://tests/fixtures/cards"
const TABLE_PATH: String = "res://tests/fixtures/strike_table.json"
const DECK_PATH: String = "res://tests/fixtures/test_deck.json"

var lib: CardLibrary
var table: StrikeTable
var checks: int = 0
var failures: int = 0
var current: String = ""


func _init() -> void:
	lib = CardLibrary.new()
	lib.load_dir(CARDS_DIR)
	table = StrikeTable.load_from(TABLE_PATH)
	var tests: Array[Callable] = [
		test_library_and_strike_table,
		test_deck_list_and_validator,
		test_shipped_decks_are_legal,
		test_setup_and_first_turn,
		test_surge_has_no_style_bonus,
		test_non_combat_placement,
		test_drill_guild_lock,
		test_grounds_forces_skip_and_recover,
		test_strike_damage_and_fight_back,
		test_drill_and_mastery_modifiers,
		test_stage_overflow_to_life,
		test_art_cost_and_damage,
		test_parry_stops_strike,
		test_guard_cannot_stop_focused,
		test_shield_drill_once_per_combat,
		test_endurance,
		test_acclaim_tier_up,
		test_power_not_refreshed_by_tier_change,
		test_favor_win_and_gating,
		test_pass_flow_discard_and_next_turn,
		test_deck_out_loses,
		test_token_bypass_and_instant_win,
		test_capture_and_pending_win,
		test_critical_damage_choices,
		test_final_strike_forces_pass,
		test_ally_control_and_redirect,
		test_end_combat_effect,
		test_random_hand_discard,
		test_armory_swap,
		test_armory_batch,
		test_bracket_first_player,
		test_search_and_in_play_discard,
		test_if_stopped,
		test_determinism,
		test_remain,
		test_empower,
		test_counter_window,
		test_forbid_art_attacks,
		test_effective_values_in_seat_view,
		test_damage_breakdown_in_view,
		test_attack_forecasts_in_view,
		test_attach_to_named_character,
		test_multiplier_cap_and_no_reduce,
		test_tokens_immune_unless_named,
		test_end_combat_card_is_no_defense,
		test_locked_out_drill_shuffles_back,
		test_look_at_rearrange,
		test_attachment_modifier,
		test_constant_power,
		test_master_use,
		test_start_in_play,
		test_pay_stages,
		test_name_card,
		test_copied_attack,
		test_prevent_all_and_no_prevent,
		test_master_shields,
		test_set_tier,
		test_draw_until_and_draw_discard,
		test_search_to_play,
		test_attack_variants,
		test_owner_chooses_discard,
		test_stop_next,
		test_only_attacks,
		test_vigor_without_overflow,
		test_use_in_attack_phase,
		test_may_prompt,
		test_pay_vigor,
		test_look_at,
		test_search_choice,
		test_before_damage_skip,
		test_stops_needed,
		test_ally_power_without_control,
		test_life_per_opponent_token,
		test_lonely_drill,
		test_unused_remain_returns,
		test_return_removed,
		test_last_searched_target,
		test_forbid_unless_vigor,
		test_forced_combat_from_armory,
		test_promoted_if_successful,
		test_draw_check_named,
		test_search_looks_through_the_deck,
		test_ai_weighs_grounds,
		test_attachment_limit_attached,
		test_attach_to_other_named_personality,
		test_draw_check_discard_and_else,
		test_mastery_on_attack_and_blocks_to_bottom,
		test_wound_trigger_at_fight_back,
		test_look_at_play_option,
		test_bond_and_unbond,
		test_search_by_effect,
		test_end_turn,
		test_declare_window,
		test_command_wire_lockstep,
		test_uids_hide_deck_order,
		test_seat_view_masks_hidden_cards,
		test_referee_gates_commands,
		test_card_text_wording,
		test_keyword_table,
		test_dev_effect,
		test_attacker_ally_control,
		test_non_combat_defense_is_spent,
		test_no_defense_after_final_strike,
		test_skipped_phase_does_not_end_combat,
		test_master_in_combat,
		test_capture_instead_of_damage,
		test_last_attack_in_view,
		test_outcome_lines_and_titles,
		test_constant_keyed_triggers,
		test_token_power_on_place_and_capture,
		test_used_non_combat_is_spent,
		test_clone_plays_identically,
		test_clone_is_independent,
		test_sim_for_hides_and_keeps,
		test_ai_answers_every_prompt,
		test_ai_search_reports_and_is_repeatable,
		test_ai_evaluator_routes,
		test_ai_profile_merge,
	]
	for t in tests:
		current = t.get_method()
		var before: int = failures
		t.call()
		print("%s %s" % ["ok  " if failures == before else "FAIL", current])
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


# --- Helpers --------------------------------------------------------------

func check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		printerr("  FAIL [%s] %s" % [current, msg])


func eq(actual: Variant, expected: Variant, msg: String) -> void:
	check(actual == expected, "%s: expected %s, got %s" % [msg, str(expected), str(actual)])


func deck(cards: Array[String], alignment: String = "knight", style: String = "", mastery: String = "", tiers: int = 3, fighter: String = "tf_knight", master: String = "", armory: Array[String] = []) -> DeckList:
	var d: DeckList = DeckList.new()
	d.master_id = master
	d.armory = armory.duplicate()
	d.name = "Test %s" % alignment
	d.fighter_id = fighter
	d.tiers = tiers
	d.style = style
	d.alignment = alignment
	d.mastery_id = mastery
	d.cards = cards.duplicate()
	return d


## Filler strikes so decks never run dry by accident.
func filler(extra: Array[String] = [], count: int = 10) -> Array[String]:
	var out: Array[String] = extra.duplicate()
	for i in range(count):
		out.append("t_strike")
	return out


func engine(a: DeckList, b: DeckList, seed_value: int = 1, shuffle: bool = false) -> DuelEngine:
	var e: DuelEngine = DuelEngine.new()
	e.shuffle_decks = shuffle
	var decks: Array[DeckList] = [a, b]
	e.setup(decks, lib, table, seed_value)
	e.start()
	return e


func answer(e: DuelEngine, type: StringName, card: int = -1, value: Variant = null) -> void:
	var p: Prompt = e.prompt
	check(p != null, "expected a prompt to answer %s" % type)
	if p == null:
		return
	var opt: Command = p.find(type, card, value)
	check(opt != null, "option %s#%d not offered by %s" % [type, card, p.describe()])
	if opt == null:
		return
	e.submit(opt)


func uid_in_hand(e: DuelEngine, player: int, id: String) -> int:
	for c in e.player(player).hand:
		if c.def.id == id:
			return c.uid
	return -1


func inject(e: DuelEngine, player: int, id: String) -> CardInstance:
	var c: CardInstance = e._instance(lib.get_def(id), player, &"in_play")
	e.player(player).in_play.append(c)
	return c


## From the first prompt of a turn to the active player's first attack prompt.
func to_combat(e: DuelEngine) -> void:
	if e.prompt != null and e.prompt.kind == &"non_combat":
		answer(e, &"done")
	answer(e, &"declare")


func has_event(e: DuelEngine, type: StringName) -> bool:
	for ev in e.events:
		if ev.type == type:
			return true
	return false


func prompt_kind(e: DuelEngine) -> StringName:
	return e.prompt.kind if e.prompt != null else &"none"


## Answers prompts with the least eventful option until the given turn begins or the game ends.
func skip_to_turn(e: DuelEngine, turn: int) -> void:
	var guard: int = 0
	while e.state.turn < turn and not e.is_over() and e.prompt != null and guard < 200:
		guard += 1
		var p: Prompt = e.prompt
		var order: Array[StringName] = [&"done", &"skip", &"pass", &"no_defense", &"no_endure", &"no_critical", &"discard_all", &"no_recover", &"control", &"target"]
		var picked: bool = false
		for t in order:
			var opt: Command = p.find(t)
			if opt != null:
				e.submit(opt)
				picked = true
				break
		check(picked, "skip_to_turn had no quiet option for %s" % p.describe())
		if not picked:
			return


# --- Tests ----------------------------------------------------------------

func test_library_and_strike_table() -> void:
	check(lib.defs.size() >= 30, "fixture cards loaded")
	eq(lib.get_def("tf_knight").highest_tier(), 3, "knight tiers")
	eq(table.band(0), 0, "band A")
	eq(table.band(1), 1, "band B starts at 1")
	eq(table.band(4000000), 4, "band E")
	eq(table.band(99999999), 8, "band I")
	eq(table.base_damage(4000000, 4000000), 1, "equal might")
	eq(table.base_damage(6000000, 4000000), 2, "one band up")
	eq(table.base_damage(0, 11600000), 0, "far below")
	eq(table.base_damage(11600000, 0), 9, "far above, capped")


func test_deck_list_and_validator() -> void:
	var d: DeckList = DeckList.load_from(DECK_PATH)
	eq(d.total_cards(), 50, "fixture deck size")
	var problems: Array[String] = DeckValidator.validate(d, lib)
	eq(problems.size(), 0, "fixture deck legal: %s" % ", ".join(problems))
	var bad: DeckList = deck(["t_strike", "t_art"], "knight", "ember", "t_mastery_ember")
	var bad_problems: Array[String] = DeckValidator.validate(bad, lib)
	check(bad_problems.size() >= 2, "small mixed-guild deck rejected: %s" % ", ".join(bad_problems))


func test_shipped_decks_are_legal() -> void:
	var shipped: CardLibrary = CardLibrary.new()
	shipped.load_dir("res://data/cards")
	var table_data: StrikeTable = StrikeTable.load_from("res://data/strike_table.json")
	check(table_data.thresholds.size() == 9, "shipped strike table has nine bands")
	var dir: DirAccess = DirAccess.open("res://data/decks")
	check(dir != null, "decks directory exists")
	if dir == null:
		return
	var found: int = 0
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if entry.ends_with(".json"):
			found += 1
			var d: DeckList = DeckList.load_from("res://data/decks".path_join(entry))
			var problems: Array[String] = DeckValidator.validate(d, shipped)
			eq(problems.size(), 0, "%s legal: %s" % [entry, ", ".join(problems)])
			# Every shipped deck must also play a full random game against itself without the engine asserting.
			var e: DuelEngine = DuelEngine.new()
			var pair: Array[DeckList] = [d, DeckList.load_from("res://data/decks".path_join(entry))]
			e.setup(pair, shipped, table_data, 7)
			e.start()
			var guard: int = 0
			while not e.is_over() and guard < 4000:
				guard += 1
				var opt: Command = e.prompt.options[randi_range(0, e.prompt.options.size() - 1)]
				e.submit(opt)
			check(e.is_over(), "%s random self-play finished (winner %d by %s)" % [entry, e.state.winner, e.state.win_reason])
		entry = dir.get_next()
	dir.list_dir_end()
	check(found >= 2, "at least two shipped decks")


func test_setup_and_first_turn() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(), "knave"))
	eq(e.state.active, 0, "knight goes first")
	eq(e.player(1).fighter.vigor, 5, "opposing starts at 5")
	eq(e.player(0).hand.size(), 3, "active drew 3")
	eq(e.player(1).hand.size(), 0, "opposing has no opening hand")
	eq(prompt_kind(e), &"declare", "no placeables skips straight to declare")
	eq(e.player(0).fighter.vigor, 8, "power up by surge 2 plus the flat Style bonus")


func test_surge_has_no_style_bonus() -> void:
	var e: DuelEngine = engine(deck(filler(), "knight", "ember", "t_mastery_ember"), deck(filler(), "knave"))
	eq(e.player(0).fighter.vigor, 8, "the Surge bonus is flat, the Mastery adds nothing on top")
	eq(e.player(0).style, "ember", "the deck's Style reaches the player")


func test_non_combat_placement() -> void:
	var e: DuelEngine = engine(deck(filler(["t_drill_strike", "t_token_1", "t_noncombat_draw"])), deck(filler(), "knave"))
	eq(prompt_kind(e), &"non_combat", "placement prompt")
	eq(e.prompt.options.size(), 4, "three placeables plus done")
	answer(e, &"place", uid_in_hand(e, 0, "t_drill_strike"))
	answer(e, &"place", uid_in_hand(e, 0, "t_token_1"))
	eq(e.player(0).acclaim, 1, "token power resolved on placement")
	answer(e, &"place", uid_in_hand(e, 0, "t_noncombat_draw"))
	eq(e.player(0).drills().size(), 1, "drill in play")
	eq(e.player(0).tokens().size(), 1, "token in play")
	eq(e.player(0).non_combats().size(), 1, "non-combat in play")
	eq(prompt_kind(e), &"declare", "empty hand moves on to declare")


func test_drill_guild_lock() -> void:
	var e: DuelEngine = engine(deck(filler(["t_drill_strike", "t_drill_shield", "t_drill_strike"])), deck(filler(), "knave"))
	answer(e, &"place", uid_in_hand(e, 0, "t_drill_strike"))
	var tide: int = uid_in_hand(e, 0, "t_drill_shield")
	check(e.prompt.find(&"place", tide) == null, "tide drill locked out by ember drill")
	var dup: int = uid_in_hand(e, 0, "t_drill_strike")
	check(e.prompt.find(&"place", dup) == null, "duplicate styled drill locked out")


func test_grounds_forces_skip_and_recover() -> void:
	var e: DuelEngine = engine(deck(filler(["t_grounds", "t_strike", "t_strike"])), deck(filler(), "knave"))
	answer(e, &"place", uid_in_hand(e, 0, "t_grounds"))
	check(e.state.grounds != null, "grounds in play")
	eq(prompt_kind(e), &"keep", "combat skipped, discard prompt")
	check(has_event(e, &"combat_skipped"), "combat_skipped emitted")
	answer(e, &"keep", e.player(0).hand[0].uid)
	eq(e.player(0).hand.size(), 1, "kept one")
	eq(prompt_kind(e), &"recover", "recover offered after a skipped combat")
	var top: CardInstance = e.player(0).discard.back()
	answer(e, &"recover")
	eq(e.player(0).life_deck.back(), top, "recovered card sits at deck bottom")
	eq(e.state.active, 1, "turn passed")
	eq(e.player(1).hand.size(), 3, "next player drew 3")


func test_strike_damage_and_fight_back() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(["t_art", "t_art", "t_art"]), "knave"))
	to_combat(e)
	eq(e.player(1).hand.size(), 3, "opposing drew 3 at combat")
	eq(prompt_kind(e), &"attack_action", "attack prompt")
	eq(e.prompt.player, 0, "active attacks first")
	var s: int = uid_in_hand(e, 0, "t_strike")
	answer(e, &"attack", s)
	eq(e.player(1).fighter.vigor, 3, "vigor 7 vs 5 deals 2 stages")
	eq(prompt_kind(e), &"attack_action", "fight back")
	eq(e.prompt.player, 1, "defender now attacks")
	eq(e.card(s).zone, &"discard", "strike discarded after use")


func test_drill_and_mastery_modifiers() -> void:
	var e: DuelEngine = engine(deck(filler(["t_drill_strike"]), "knight", "ember", "t_mastery_ember"), deck(filler(["t_art", "t_art", "t_art", "t_art"]), "knave"))
	answer(e, &"place", uid_in_hand(e, 0, "t_drill_strike"))
	to_combat(e)
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike"))
	# vigor 8 (surge 2 + 1) -> might 6.5M band F vs 4.0M band E = 2, +1 drill, +1 mastery
	eq(e.player(1).fighter.vigor, 1, "drill and mastery add 2 stages")


func test_stage_overflow_to_life() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(["t_art", "t_art", "t_art"]), "knave"))
	to_combat(e)
	e.player(1).fighter.vigor = 1
	var deck_before: int = e.player(1).life_deck.size()
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike"))
	# attacker 6.0M band F vs defender at vigor 1 = 900k band C: 4 stages, 1 absorbed, 3 overflow
	eq(e.player(1).fighter.vigor, 0, "vigor floors at 0")
	eq(e.player(1).discard.size(), 3, "three stages overflowed to life cards")
	eq(e.player(1).life_deck.size(), deck_before - 3, "life deck shrank by three")


func test_art_cost_and_damage() -> void:
	var e: DuelEngine = engine(deck(filler(["t_art", "t_art", "t_art"])), deck(filler(), "knave"))
	to_combat(e)
	answer(e, &"attack", uid_in_hand(e, 0, "t_art"))
	eq(e.player(0).fighter.vigor, 6, "art cost 2 vigor from 8")
	eq(e.player(1).discard.size(), 4, "art dealt 4 wounds")
	e.player(0).fighter.vigor = 1
	answer(e, &"pass")
	eq(e.prompt.player, 0, "back to the active player")
	check(e.prompt.find(&"attack", uid_in_hand(e, 0, "t_art")) == null, "cannot afford an art at vigor 1")


func test_parry_stops_strike() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(["t_parry", "t_parry", "t_parry"]), "knave"))
	to_combat(e)
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike"))
	eq(prompt_kind(e), &"defense", "defense prompt")
	var parry: int = uid_in_hand(e, 1, "t_parry")
	answer(e, &"defend", parry)
	check(has_event(e, &"attack_stopped"), "attack stopped")
	eq(e.player(1).fighter.vigor, 5, "no damage")
	eq(e.card(parry).zone, &"discard", "parry discarded")


func test_guard_cannot_stop_focused() -> void:
	var e: DuelEngine = engine(deck(filler(["t_strike_focused", "t_strike_focused", "t_strike_focused"])), deck(filler(["t_guard", "t_guard", "t_guard"]), "knave"))
	to_combat(e)
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike_focused"))
	eq(prompt_kind(e), &"attack_action", "no defense possible, straight to fight back")
	eq(e.player(1).fighter.vigor, 3, "focused strike landed")


func test_shield_drill_once_per_combat() -> void:
	var e: DuelEngine = engine(deck(filler(["t_art", "t_art", "t_art"])), deck(filler(), "knave"))
	inject(e, 1, "t_drill_shield")
	to_combat(e)
	answer(e, &"attack", uid_in_hand(e, 0, "t_art"))
	check(has_event(e, &"shield"), "shield fired")
	eq(e.player(1).discard.size(), 0, "shield stopped the art")
	answer(e, &"pass")
	answer(e, &"attack", uid_in_hand(e, 0, "t_art"))
	eq(e.player(1).discard.size(), 4, "second art in the same combat gets through")


func test_endurance() -> void:
	var e: DuelEngine = engine(deck(filler(["t_art", "t_art", "t_art"])), deck(filler(["t_parry", "t_parry", "t_parry", "t_strike_endure"]), "knave", "tide", "t_mastery_tide"))
	to_combat(e)
	answer(e, &"attack", uid_in_hand(e, 0, "t_art"))
	eq(prompt_kind(e), &"endurance", "endurance prompt on the flipped card")
	answer(e, &"endure")
	eq(e.player(1).removed.size(), 1, "endurance card removed from game")
	eq(e.player(1).discard.size(), 1, "endurance 2 left one more wound")
	eq(prompt_kind(e), &"attack_action", "battle finished")


func test_acclaim_tier_up() -> void:
	var e: DuelEngine = engine(deck(filler(["t_drill_strike", "t_taunt", "t_strike"])), deck(filler(), "knave"))
	answer(e, &"place", uid_in_hand(e, 0, "t_drill_strike"))
	to_combat(e)
	e.player(0).acclaim = 4
	answer(e, &"use", uid_in_hand(e, 0, "t_taunt"))
	eq(e.player(0).fighter.tier, 2, "tier up at 5 acclaim")
	eq(e.player(0).fighter.vigor, 10, "vigor to full on tier up")
	eq(e.player(0).acclaim, 0, "acclaim reset, no carry-over")
	eq(e.player(0).drills().size(), 0, "drills discarded on tier up")
	check(not e.is_over(), "tier 2 of 3 is not a win")


## A Fighter Power is once per turn; rising a tier mid-Combat does not hand out a second use.
func test_power_not_refreshed_by_tier_change() -> void:
	var e: DuelEngine = engine(deck(filler(["t_taunt", "t_taunt", "t_strike"])), deck(filler(), "knave"))
	to_combat(e)
	var me: PlayerState = e.player(0)
	check(e._power_available(me, me.fighter), "power fresh at the first attack")
	answer(e, &"power", me.fighter.uid)
	check(not e._power_available(me, me.fighter), "used this turn")
	me.acclaim = 4
	answer(e, &"pass")
	answer(e, &"use", uid_in_hand(e, 0, "t_taunt"))
	eq(me.fighter.tier, 2, "rose a tier mid-Combat")
	check(not e._power_available(me, me.fighter), "the new tier's Power waits for the next turn")
	skip_to_turn(e, 3)
	check(e._power_available(me, me.fighter), "fresh again on the owner's next turn")


func test_favor_win_and_gating() -> void:
	var e: DuelEngine = engine(deck(filler(["t_taunt", "t_taunt", "t_strike"])), deck(filler(), "knave"))
	to_combat(e)
	e.player(0).fighter.tier = 2
	e.player(0).acclaim = 4
	e.player(1).highest_tier = 5
	answer(e, &"use", uid_in_hand(e, 0, "t_taunt"))
	eq(e.player(0).fighter.tier, 3, "reached own top tier")
	eq(e.player(0).acclaim, 0, "acclaim resets on the climb")
	check(not e.is_over(), "reaching the top tier is not yet the win")
	e.player(0).acclaim = 4
	answer(e, &"pass")
	answer(e, &"use", uid_in_hand(e, 0, "t_taunt"))
	check(e.is_over(), "full acclaim at the own top tier ends the duel, whatever the rival's stack")
	eq(e.state.winner, 0, "favor winner")
	eq(e.state.win_reason, "favor", "favor reason")


func test_pass_flow_discard_and_next_turn() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(), "knave"))
	to_combat(e)
	answer(e, &"pass")
	eq(e.prompt.player, 1, "opponent's attack phase")
	answer(e, &"pass")
	check(has_event(e, &"combat_end"), "two passes end combat")
	eq(prompt_kind(e), &"keep", "active discards first")
	eq(e.prompt.player, 0, "active player keeps")
	answer(e, &"keep", e.player(0).hand[0].uid)
	eq(e.player(0).hand.size(), 1, "active kept one")
	eq(e.prompt.player, 1, "opposing keeps next")
	answer(e, &"discard_all")
	eq(e.player(1).discard.size(), 3, "discard all allowed")
	eq(e.state.turn, 2, "no recover prompt after a declared combat")
	eq(e.state.active, 1, "turn passed to player 1")
	eq(e.player(1).hand.size(), 3, "player 1 drew 3 fresh cards")


func test_deck_out_loses() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(["t_strike", "t_strike"], "knave"))
	to_combat(e)
	check(e.is_over(), "drawing from an empty deck ends the game")
	eq(e.state.winner, 0, "player 1 lost by survival")
	eq(e.state.win_reason, "survival", "survival reason")


func test_token_bypass_and_instant_win() -> void:
	var e: DuelEngine = engine(deck(filler(["t_art", "t_art", "t_art"])), deck(filler(["t_parry", "t_parry", "t_parry", "t_token_2"]), "knave"))
	to_combat(e)
	answer(e, &"attack", uid_in_hand(e, 0, "t_art"))
	eq(e.player(1).discard.size(), 4, "token did not count as a wound")
	eq(e.player(1).life_deck.back().def.id, "t_token_2", "token went to the deck bottom")
	# Instant win on placing the seventh yourself.
	var e2: DuelEngine = engine(deck(filler(["t_token_7"])), deck(filler(), "knave"))
	for i in range(1, 7):
		inject(e2, 0, "t_token_%d" % i)
	answer(e2, &"place", uid_in_hand(e2, 0, "t_token_7"))
	check(e2.is_over(), "seventh token placed wins")
	eq(e2.state.win_reason, "token", "token reason")


func test_capture_and_pending_win() -> void:
	var e: DuelEngine = engine(deck(filler(["t_strike_wound", "t_strike_wound", "t_strike_wound"])), deck(filler([], 20), "knave"))
	var t: CardInstance = inject(e, 1, "t_token_7")
	for i in range(1, 7):
		inject(e, 0, "t_token_%d" % i)
	to_combat(e)
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike_wound"))
	eq(prompt_kind(e), &"critical", "five wounds are critical damage")
	answer(e, &"capture", t.uid)
	eq(t.controller, 0, "token changed hands")
	if prompt_kind(e) == &"pick_option":
		answer(e, &"pick_option", -1, "no")   # the captured Token's power is optional
	eq(e.player(0).tokens().size(), 7, "seven tokens held")
	check(not e.is_over(), "captured seventh does not win at once")
	check(e.player(0).token_victory_pending, "victory pending")
	skip_to_turn(e, 3)
	check(e.is_over(), "win at the start of the capturing player's next turn")
	eq(e.state.win_reason, "token", "token reason")


## Critical damage (5+ wounds in one attack) offers a Token, an Ally, or the rival's Acclaim.
func test_critical_damage_choices() -> void:
	var e: DuelEngine = engine(deck(filler(["t_strike_wound", "t_strike_wound", "t_strike_wound"])), deck(filler([], 20), "knave", "", "", 3, "tf_shepherd", "t_master_shield"))
	var squire: CardInstance = inject(e, 1, "t_ally_squire")
	check(e._ally_protected(e.player(1)), "the rival's constant protects Allies from card effects")
	check(e.acclaim_shielded(e.player(1)), "the rival's Master shields Acclaim from card effects")
	e.player(1).acclaim = 2
	to_combat(e)
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike_wound"))
	eq(prompt_kind(e), &"redirect", "the defender may hand the damage to the ally first")
	answer(e, &"target", e.player(1).fighter.uid)
	eq(prompt_kind(e), &"critical", "critical prompt with no Tokens in play")
	var kinds: Array[StringName] = []
	for o in e.prompt.options:
		kinds.append(o.type)
	check(kinds.has(&"discard_ally") and kinds.has(&"lower_acclaim") and kinds.has(&"no_critical"), "ally, acclaim and decline offered; protection is for card effects only")
	check(not kinds.has(&"capture"), "no Token to capture")
	answer(e, &"discard_ally", squire.uid)
	eq(e.player(1).allies().size(), 0, "the ally is discarded")
	check(has_event(e, &"critical_ally"), "critical_ally event")
	answer(e, &"pass")
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike_wound"))
	eq(prompt_kind(e), &"critical", "second critical hit")
	answer(e, &"lower_acclaim")
	eq(e.player(1).acclaim, 1, "rival acclaim lowered by 1")
	answer(e, &"pass")
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike_wound"))
	eq(prompt_kind(e), &"critical", "third critical hit")
	answer(e, &"lower_acclaim")
	eq(e.player(1).acclaim, 0, "acclaim floors at 0")
	var wounded: DuelEngine = engine(deck(filler(["t_strike_wound", "t_strike_wound", "t_strike_wound"])), deck(filler([], 20), "knave"))
	to_combat(wounded)
	answer(wounded, &"attack", uid_in_hand(wounded, 0, "t_strike_wound"))
	check(prompt_kind(wounded) != &"critical", "nothing to take means no prompt")


func test_final_strike_forces_pass() -> void:
	var e: DuelEngine = engine(deck(filler(["t_taunt", "t_taunt", "t_taunt"])), deck(filler(["t_art", "t_art", "t_art"]), "knave"))
	to_combat(e)
	var fodder: int = uid_in_hand(e, 0, "t_taunt")
	answer(e, &"final_strike", fodder)
	eq(e.card(fodder).zone, &"discard", "fodder discarded")
	eq(e.player(1).fighter.vigor, 3, "final strike used the table")
	check(e.player(0).must_pass, "must pass afterwards")
	answer(e, &"pass")
	check(has_event(e, &"combat_end"), "forced pass ended combat")


func test_ally_control_and_redirect() -> void:
	var e: DuelEngine = engine(deck(filler(["t_ally_squire", "t_taunt", "t_taunt"])), deck(filler(), "knave"))
	answer(e, &"place", uid_in_hand(e, 0, "t_ally_squire"))
	var ally: CardInstance = e.player(0).allies()[0]
	eq(ally.vigor, 4, "ally enters at 3 and powers up 1")
	to_combat(e)
	e.player(0).fighter.vigor = 1
	ally.vigor = 3
	answer(e, &"pass")
	answer(e, &"attack", uid_in_hand(e, 1, "t_strike"))
	eq(prompt_kind(e), &"control", "control prompt at vigor 1 with an ally")
	answer(e, &"control", ally.uid)
	eq(prompt_kind(e), &"redirect", "redirect prompt")
	answer(e, &"target", ally.uid)
	# attacker 4.0M band E vs ally might 300k band B = 4 stages: 3 to the ally, 1 wound
	eq(ally.vigor, 0, "ally absorbed the stages")
	eq(e.player(0).discard.size(), 1, "overflow wound taken from the owner's deck")
	eq(e.player(0).fighter.vigor, 1, "fighter untouched")


func test_end_combat_effect() -> void:
	var e: DuelEngine = engine(deck(filler(["t_truce", "t_truce", "t_truce"])), deck(filler(), "knave"))
	to_combat(e)
	answer(e, &"use", uid_in_hand(e, 0, "t_truce"))
	check(has_event(e, &"combat_end"), "truce ended combat")
	eq(e.state.step, GameState.Step.DISCARD, "moved to discard step")


func test_random_hand_discard() -> void:
	var e: DuelEngine = engine(deck(filler(["t_scout", "t_scout", "t_scout"])), deck(filler(), "knave"))
	to_combat(e)
	eq(e.player(1).hand.size(), 3, "opponent drew 3")
	answer(e, &"use", uid_in_hand(e, 0, "t_scout"))
	eq(e.player(1).hand.size(), 1, "two random cards left the hand")
	eq(e.player(1).discard.size(), 2, "they went to the discard pile")


func test_armory_swap() -> void:
	var armory: Array[String] = ["t_art", "t_taunt"]
	var e: DuelEngine = engine(deck(filler(), "knight", "", "", 3, "tf_knight", "t_master", armory), deck(filler(), "knave"))
	eq(prompt_kind(e), &"armory", "setup opens with the armory prompt")
	eq(e.prompt.player, 0, "active player swaps first")
	var art_uid: int = e.player(0).armory[0].uid
	var deck_before: int = e.player(0).life_deck.size()
	answer(e, &"armory_in", art_uid)
	eq(e.card(art_uid).zone, &"life_deck", "armory card entered the life deck")
	for ev in e.events:
		if ev.type == &"armory_swap":
			check(CardText.event_line(ev, e, 0).contains("Test Art"), "the swapping seat's log names the card")
			check(CardText.event_line(ev, e, 1) == "%s brings a card in from the Armory." % e.player(0).name, "the other seat's log does not: %s" % CardText.event_line(ev, e, 1))
	eq(e.player(0).armory.size(), 2, "a random life card took its place")
	eq(e.player(0).life_deck.size(), deck_before, "deck size unchanged")
	check(e.prompt.find(&"armory_in", e.player(0).armory[1].uid) == null, "the swapped-out card cannot come straight back")
	answer(e, &"armory_done")
	eq(e.state.turn, 1, "opponent without an armory is skipped and the first turn begins")
	eq(e.player(0).hand.size(), 3, "normal draw followed")


## Several Armory cards can come in as one batch command; the batch must stay inside the
## options, and the wire form the referee sees carries the same list.
func test_armory_batch() -> void:
	var armory: Array[String] = ["t_art", "t_taunt", "t_parry"]
	var e: DuelEngine = engine(deck(filler(), "knight", "", "", 3, "tf_knight", "t_master", armory), deck(filler(), "knave"))
	eq(e.prompt.batch_type, &"armory_in", "the armory prompt takes a batch")
	eq(e.prompt.batch_max, 3, "up to every armory card")
	var a: int = e.player(0).armory[0].uid
	var b: int = e.player(0).armory[1].uid
	var stranger: int = e.player(0).life_deck[0].uid
	check(e.prompt.accept(Command.new(0, &"armory_in", -1, [a, stranger])) == null, "a uid outside the options is refused")
	check(e.prompt.accept(Command.new(0, &"armory_in", -1, [a, a])) == null, "repeats are refused")
	check(e.prompt.accept(Command.new(1, &"armory_in", -1, [a])) == null, "the other seat cannot answer")
	check(e.prompt.accept(Command.new(0, &"armory_in", -1, [])) == null, "an empty batch is not a swap")
	var view: PromptView = PromptView.of(e.prompt, e)
	var batch: OptionView = PromptView.from_dict(view.to_dict()).batch_option([a, b])
	eq(batch.label, "Bring in 2", "the batch option labels itself")
	var deck_before: int = e.player(0).life_deck.size()
	check(e.submit(batch.to_command(0)), "the batch is accepted")
	eq(e.card(a).zone, &"life_deck", "first card entered the deck")
	eq(e.card(b).zone, &"life_deck", "second card entered the deck")
	eq(e.player(0).armory.size(), 3, "two random cards came out")
	eq(e.state.turn, 1, "the batch also finishes the swap")
	eq(e.player(0).life_deck.size() + e.player(0).hand.size(), deck_before, "two swaps keep the deck size, less the opening draw")
	var r: Referee = Referee.new()
	var e2: DuelEngine = engine(deck(filler(), "knight", "", "", 3, "tf_knight", "t_master", armory), deck(filler(), "knave"))
	r.engine = e2
	var uids: Array[int] = [e2.player(0).armory[0].uid, e2.player(0).armory[2].uid]
	eq(r.submit(0, r.prompt_for(0).batch_option(uids).to_command(0).to_dict()), "", "the referee takes the batch in wire form")
	eq(e2.card(uids[1]).zone, &"life_deck", "and applied it")


func test_bracket_first_player() -> void:
	var giant: DeckList = deck(filler(), "knight", "", "", 3, "tf_giant")
	var e: DuelEngine = engine(giant, deck(filler(), "knight", "", "", 3, "tf_pageboy"))
	eq(e.state.active, 1, "the fighter below band D opens the duel")
	eq(e.player(0).fighter.vigor, 5, "no stage penalty under the bracket rule")
	check(has_event(e, &"bracket_rule"), "bracket rule event emitted")


func test_search_and_in_play_discard() -> void:
	var e: DuelEngine = engine(deck(filler(["t_seek", "t_glare", "t_strike", "t_art"])), deck(filler(["t_noncombat_draw", "t_strike", "t_strike"]), "knave"))
	to_combat(e)
	# opponent places nothing on our turn; inject a non-combat for the glare to hit
	inject(e, 1, "t_noncombat_draw")
	answer(e, &"use", uid_in_hand(e, 0, "t_seek"))
	take_search(e)
	check(uid_in_hand(e, 0, "t_art") >= 0, "search pulled the art into hand")
	answer(e, &"pass")
	answer(e, &"use", uid_in_hand(e, 0, "t_glare"))
	eq(e.player(1).non_combats().size(), 0, "glare discarded the non-combat in play")


func test_if_stopped() -> void:
	var e: DuelEngine = engine(deck(filler(["t_art_stubborn", "t_art_stubborn", "t_art_stubborn"])), deck(filler(["t_ward", "t_ward", "t_ward"]), "knave"))
	to_combat(e)
	var hand_before: int = e.player(0).hand.size()
	answer(e, &"attack", uid_in_hand(e, 0, "t_art_stubborn"))
	answer(e, &"defend", uid_in_hand(e, 1, "t_ward"))
	eq(e.player(0).hand.size(), hand_before - 1 + 2, "stopped attack drew two")


func test_determinism() -> void:
	var a: DuelEngine = engine(deck(filler(["t_art", "t_taunt", "t_parry", "t_token_1"])), deck(filler(["t_guard", "t_ward"]), "knave"), 42, true)
	var b: DuelEngine = engine(deck(filler(["t_art", "t_taunt", "t_parry", "t_token_1"])), deck(filler(["t_guard", "t_ward"]), "knave"), 42, true)
	var ids_a: Array[String] = []
	var ids_b: Array[String] = []
	for c in a.player(0).life_deck:
		ids_a.append(c.def.id)
	for c in b.player(0).life_deck:
		ids_b.append(c.def.id)
	eq(ids_a, ids_b, "same seed, same shuffle")
	var c: DuelEngine = engine(deck(filler(["t_art", "t_taunt", "t_parry", "t_token_1"])), deck(filler(["t_guard", "t_ward"]), "knave"), 43, true)
	var ids_c: Array[String] = []
	for card in c.player(0).life_deck:
		ids_c.append(card.def.id)
	check(ids_a != ids_c, "different seed, different shuffle")


## Online play: a second engine fed only the wire form of the first one's commands ends every
## step in the same state, including the values that ride on commands (pay amounts, option keys).
func test_command_wire_lockstep() -> void:
	var a: DuelEngine = engine(deck(filler(["t_art", "t_taunt", "t_parry", "t_token_1", "t_pay_art", "t_empower_art"])), deck(filler(["t_guard", "t_ward"]), "knave"), 77, true)
	var b: DuelEngine = engine(deck(filler(["t_art", "t_taunt", "t_parry", "t_token_1", "t_pay_art", "t_empower_art"])), deck(filler(["t_guard", "t_ward"]), "knave"), 77, true)
	var picker: RandomNumberGenerator = RandomNumberGenerator.new()
	picker.seed = 7
	var steps: int = 0
	while not a.is_over() and steps < 400:
		var chosen: Command = a.prompt.options[picker.randi_range(0, a.prompt.options.size() - 1)]
		var wire: Dictionary = chosen.to_dict()
		var decoded: Command = Command.from_dict(wire)
		check(decoded.matches(chosen), "wire form round-trips %s" % chosen.describe())
		a.submit(chosen)
		check(b.submit(decoded), "the second engine accepts %s" % decoded.describe())
		steps += 1
	eq(b.is_over(), a.is_over(), "both engines finished together")
	eq(b.state.winner, a.state.winner, "same winner")
	eq(b.state.turn, a.state.turn, "same turn")
	for i in range(2):
		eq(b.player(i).life_deck.size(), a.player(i).life_deck.size(), "player %d life deck" % i)
		eq(b.player(i).hand.size(), a.player(i).hand.size(), "player %d hand" % i)
		eq(b.player(i).fighter.vigor, a.player(i).fighter.vigor, "player %d vigor" % i)
	# Values ride along unchanged: option keys, pay amounts, named titles.
	for sample in [Command.new(1, &"attack", 12, "empower"), Command.new(0, &"pay", -1, 4), Command.new(0, &"name_card", 3, "Test Parry"), Command.new(1, &"pass")]:
		var back: Command = Command.from_dict(sample.to_dict())
		check(back.matches(sample), "wire form keeps %s" % sample.describe())
		check(typeof(back.value) == typeof(sample.value), "value type kept for %s" % sample.describe())


## A face-down card's uid must not give away what it is. Uids are dealt after the shuffle, so
## the same deck list under two seeds maps uids to different cards.
func test_uids_hide_deck_order() -> void:
	var cards: Array[String] = filler(["t_art", "t_taunt", "t_parry", "t_token_1", "t_guard", "t_ward"])
	var a: DuelEngine = engine(deck(cards), deck(filler(), "knave"), 11, true)
	var b: DuelEngine = engine(deck(cards), deck(filler(), "knave"), 12, true)
	var differs: bool = false
	for c in a.player(0).life_deck:
		var other: CardInstance = b.card(c.uid)
		if other != null and other.def.id != c.def.id:
			differs = true
			break
	check(differs, "the same uid names different cards under different seeds")
	var in_list_order: bool = true
	for i in range(a.player(0).life_deck.size()):
		if a.player(0).life_deck[i].def.id != cards[i]:
			in_list_order = false
			break
	check(not in_list_order, "the deck was shuffled")


func test_seat_view_masks_hidden_cards() -> void:
	var e: DuelEngine = engine(deck(filler(["t_art", "t_taunt", "t_parry", "t_token_1"])), deck(filler(["t_guard", "t_ward"]), "knave", "", "", 3, "tf_knight", "t_master", ["t_summons"]))
	answer(e, &"armory_done")
	var v0: SeatView = SeatView.of(e, 0)
	var v1: SeatView = SeatView.of(e, 1)
	eq(v0.cards.size(), e.all_cards().size(), "every card has a row")
	for uid in v0.player(0).hand:
		check(not v0.card(uid).hidden(), "own hand is visible")
		check(v1.card(uid).hidden(), "the other seat sees only a back")
		eq(v1.card(uid).zone, &"hand", "but knows the zone")
	for uid in v0.player(0).life_deck:
		check(v0.card(uid).hidden(), "own Life Deck stays face down")
	for uid in v1.player(1).armory:
		check(not v1.card(uid).hidden(), "own Armory is visible")
		check(v0.card(uid).hidden(), "the other seat cannot read the Armory")
	check(not v1.card(v0.player(0).fighter).hidden(), "fighters are public")
	eq(v0.player(0).life_deck.size(), e.player(0).life_deck.size(), "deck counts are public")
	eq(v0.deciding, e.prompt.player, "who decides is public")
	var back: SeatView = SeatView.from_dict(v1.to_dict())
	eq(back.cards.size(), v1.cards.size(), "wire form keeps every row")
	eq(back.player(1).hand, v1.player(1).hand, "wire form keeps zone order")
	# A seat choosing among cards may see them, even in its Life Deck; the other seat may not.
	var top: int = e.player(0).life_deck[0].uid
	var p: Prompt = Prompt.new()
	p.player = 0
	p.kind = &"pick_option"
	p.options = [Command.new(0, &"pick_option", top), Command.new(0, &"pick_none")]
	var saved: Prompt = e.prompt
	e.prompt = p
	check(not SeatView.of(e, 0).card(top).hidden(), "a deck card offered as a choice is revealed to its chooser")
	check(SeatView.of(e, 1).card(top).hidden(), "the other seat still sees a back")
	e.prompt = saved
	var hidden_in_wire: int = 0
	for cd in v1.to_dict()["cards"]:
		if str(cd["def"]) == "":
			hidden_in_wire += 1
	eq(hidden_in_wire, e.player(0).life_deck.size() + e.player(1).life_deck.size() + e.player(0).hand.size() + e.player(0).armory.size(), "exactly the hidden cards go out blank")


func test_referee_gates_commands() -> void:
	var r: Referee = Referee.new()
	r.engine.shuffle_decks = false
	r.setup([deck(filler(["t_art", "t_taunt", "t_parry", "t_token_1"])), deck(filler(["t_guard", "t_ward"]), "knave")], lib, table, 5)
	r.start()
	var first: Array[SeatUpdate] = r.take_updates()
	eq(first.size(), 2, "one update per seat")
	var seat: int = r.engine.prompt.player
	var p: PromptView = first[seat].prompt
	check(p != null, "the deciding seat gets its prompt")
	check(first[1 - seat].prompt == null, "the other seat gets none")
	check(first[seat].lines.size() > 0, "setup lines are logged")
	var opt: OptionView = p.options[0]
	check(opt.label != "", "options come labelled")
	var wrong_seat: String = r.submit(1 - seat, opt.to_command(1 - seat).to_dict())
	check(wrong_seat != "", "the other seat cannot answer")
	var forged: String = r.submit(seat, Command.new(seat, &"attack", 999).to_dict())
	check(forged != "", "an option the prompt does not list is refused")
	eq(r.submit(seat, opt.to_command(seat).to_dict()), "", "the listed option is accepted")
	var next: Array[SeatUpdate] = r.take_updates()
	check(next[0].view != null and next[1].view != null, "both seats get a view after every command")
	# Lines a client animates carry the public fields of their event; the rest carry none.
	var r2: Referee = Referee.new()
	r2.engine.shuffle_decks = false
	r2.setup([deck(filler(["t_strike_plus2"])), deck(filler(), "knave")], lib, table, 5)
	r2.start()
	r2.take_updates()
	var att: int = r2.engine.prompt.player
	if r2.engine.prompt.kind == &"non_combat":
		r2.submit(att, Command.new(att, &"done").to_dict())
	r2.submit(att, Command.new(att, &"declare").to_dict())
	r2.take_updates()
	eq(r2.submit(att, r2.engine.prompt.find(&"attack").to_dict()), "", "the first attack option is accepted")
	var landed: Array[SeatUpdate] = r2.take_updates()
	var lines: Array[Dictionary] = landed[1 - att].lines.duplicate()
	if r2.engine.prompt != null and r2.engine.prompt.kind == &"defense":
		eq(r2.submit(1 - att, Command.new(1 - att, &"no_defense").to_dict()), "", "the defender takes the hit")
		lines.append_array(r2.take_updates()[1 - att].lines)
	var stages: Dictionary = {}
	var unlisted: bool = false
	for l in lines:
		match str(l.get("type", "")):
			"damage_stages":
				stages = l.get("data", {})
			"attack_successful", "modified_damage":
				pass
			_:
				if not Referee.ANIMATED.has(StringName(str(l.get("type", "")))):
					unlisted = unlisted or l.has("data")
	check(stages.has("target") and stages.has("stages"), "damage lines carry the target and amount for the other seat: %s" % str(stages))
	check(not unlisted, "unlisted events carry no data")
	eq(next[0].view.seat, 0, "seat 0's view")
	eq(next[1].view.seat, 1, "seat 1's view")


# --- Extended mechanics ----------------------------------------------------

func test_remain() -> void:
	var e: DuelEngine = engine(deck(filler(["t_remain_strike", "t_strike", "t_strike"])), deck(filler(), "knave"))
	to_combat(e)
	var uid: int = uid_in_hand(e, 0, "t_remain_strike")
	answer(e, &"attack", uid)
	eq(e.card(uid).zone, &"in_play", "card stays on the table")
	eq(e.card(uid).remain, 1, "one more use")
	check(has_event(e, &"remain"), "remain event")
	answer(e, &"pass")
	check(e.prompt.find(&"attack", uid) != null, "the table copy can attack again")
	answer(e, &"attack", uid)
	eq(e.card(uid).zone, &"discard", "spent after the second use")


func test_empower() -> void:
	var e: DuelEngine = engine(deck(filler(["t_empower_art", "t_empower_art", "t_strike"])), deck(filler([], 20), "knave"))
	to_combat(e)
	var deck_before: int = e.player(1).life_deck.size()
	answer(e, &"attack", uid_in_hand(e, 0, "t_empower_art"), "empower")
	eq(e.player(1).life_deck.size(), deck_before - 6, "art 4 wounds plus Empower 2")
	eq(e.player(0).acclaim, 0, "empowered use drops the after-empower effect")
	answer(e, &"pass")
	deck_before = e.player(1).life_deck.size()
	answer(e, &"attack", uid_in_hand(e, 0, "t_empower_art"))
	eq(e.player(1).life_deck.size(), deck_before - 4, "plain use deals 4")
	eq(e.player(0).acclaim, 1, "plain use keeps the secondary effect")


func test_counter_window() -> void:
	var e: DuelEngine = engine(deck(filler(["t_taunt", "t_taunt", "t_strike"])), deck(filler(["t_counter", "t_counter", "t_counter"]), "knave"))
	to_combat(e)
	var taunt: int = uid_in_hand(e, 0, "t_taunt")
	answer(e, &"use", taunt)
	eq(prompt_kind(e), &"respond", "opponent gets a response window")
	eq(e.prompt.player, 1, "the opponent responds")
	var k: int = uid_in_hand(e, 1, "t_counter")
	answer(e, &"counter", k)
	eq(e.player(0).acclaim, 0, "countered card does nothing")
	eq(e.card(taunt).zone, &"discard", "countered card is discarded")
	eq(e.card(k).zone, &"discard", "counter card is spent")
	check(has_event(e, &"countered"), "countered event")
	eq(prompt_kind(e), &"attack_action", "play moves on to the fight back")
	answer(e, &"pass")
	answer(e, &"use", uid_in_hand(e, 0, "t_taunt"))
	answer(e, &"decline")
	eq(e.player(0).acclaim, 2, "declined counter lets the card resolve")
	# "Use when needed" is the response window and nothing else: the counter's owner cannot
	# play it as an action in their own attack phase, where it would do nothing.
	eq(prompt_kind(e), &"attack_action", "fight back after the declined counter")
	eq(e.prompt.player, 1, "the counter's owner is choosing")
	var held: int = uid_in_hand(e, 1, "t_counter")
	check(held >= 0 and e.prompt.find(&"use", held) == null, "a pure counter card is not an attack-phase action")
	check(e.prompt.find(&"final_strike", held) != null, "it can still be thrown away for a Final Strike")


func test_forbid_art_attacks() -> void:
	var e: DuelEngine = engine(deck(filler(["t_forbid_arts", "t_strike", "t_strike"])), deck(filler(["t_art", "t_art", "t_art"]), "knave"))
	to_combat(e)
	answer(e, &"use", uid_in_hand(e, 0, "t_forbid_arts"))
	eq(e.prompt.player, 1, "fight back")
	check(e.prompt.find(&"attack", uid_in_hand(e, 1, "t_art")) == null, "forbidden art cannot attack")
	check(e._forbidden(e.player(1), "art_attacks"), "forbid is in force")
	var logged: String = ""
	for ev in e.events:
		if ev.type == &"floating" and str(ev.data.get("op", "")) == "forbid":
			logged = CardText.event_line(ev, e)
	check(logged.contains("may not perform Arts for the rest of Combat"), "the forbid is logged as it lands: %s" % logged)
	answer(e, &"pass")
	answer(e, &"pass")
	check(not e._forbidden(e.player(1), "art_attacks"), "forbid expires with Combat")


## The attack in the air comes with its damage worked out step by step, before the defense, and
## the numbers the battle sequence then applies are the same ones.
func test_damage_breakdown_in_view() -> void:
	var e: DuelEngine = engine(deck(filler(["t_drill_strike"]), "knight", "ember", "t_mastery_ember"), deck(filler(["t_parry", "t_parry", "t_parry"]), "knave"))
	answer(e, &"place", uid_in_hand(e, 0, "t_drill_strike"))
	to_combat(e)
	check(not bool(e.prompt.context.get("fight_back", false)), "the active player's attack phase is not a fight back")
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike"))
	eq(prompt_kind(e), &"defense", "defense prompt with the attack in the air")
	var v: SeatView = SeatView.of(e, 1)
	var a: Dictionary = v.attack
	eq(int(a["attacker"]), 0, "attacker seat in the summary")
	check(not bool(a["landed"]), "nothing has landed before the defense")
	var d: Dictionary = a["damage"]
	eq(int(d["table"]), 2, "Strike Table base")
	eq(str(CardText.band_letter(int(d["attacker_band"]))), "F", "attacker band letter")
	eq((d["adds"] as Array).size(), 2, "the Drill and the Mastery are listed")
	eq(str((d["adds"] as Array)[0]["source"]), "Test Ember Drill", "the Drill is named")
	eq(int(d["stages"]), 4, "forecast total")
	var wire: SeatView = SeatView.from_dict(v.to_dict())
	eq(int(wire.attack["damage"]["stages"]), 4, "wire form keeps the breakdown")
	answer(e, &"no_defense")
	eq(e.player(1).fighter.vigor, 1, "what landed matches the forecast")
	var base_line: String = ""
	var mod_line: String = ""
	for ev in e.events:
		if ev.type == &"base_damage":
			base_line = CardText.event_line(ev, e)
		elif ev.type == &"modified_damage":
			mod_line = CardText.event_line(ev, e)
	check(base_line.begins_with("Strike Table: Might"), "base damage log line names the table: %s" % base_line)
	check(mod_line.contains("Test Ember Drill") and mod_line.ends_with("Total 4 stages."), "modifier log line lists sources and total: %s" % mod_line)
	eq(prompt_kind(e), &"attack_action", "fight back prompt")
	check(bool(e.prompt.context.get("fight_back", false)), "the defender's attack phase is flagged as a fight back")
	eq(CardText.prompt_title(e.prompt), "Fight back", "fight back title")
	check(e.prompt.find(&"final_strike", uid_in_hand(e, 1, "t_parry")) != null, "a Final Strike is still offered on any hand card")


## Before an attack is chosen, the view carries what each offered attack would deal right now,
## built the same way declaring it would, and the number that then lands is the same one.
func test_attack_forecasts_in_view() -> void:
	var e: DuelEngine = engine(deck(filler(["t_drill_strike", "t_strike_plus2", "t_empower_art"]), "knight", "ember", "t_mastery_ember"), deck(filler(["t_parry", "t_parry", "t_parry"]), "knave"))
	answer(e, &"place", uid_in_hand(e, 0, "t_drill_strike"))
	check(SeatView.of(e, 0).forecasts.is_empty(), "no forecasts outside the attack action")
	to_combat(e)
	var v: SeatView = SeatView.of(e, 0)
	check(SeatView.of(e, 1).forecasts.is_empty(), "the other seat gets no forecasts")
	var heavy: int = uid_in_hand(e, 0, "t_strike_plus2")
	var art: int = uid_in_hand(e, 0, "t_empower_art")
	var fh: Dictionary = v.forecast(heavy)
	check(not fh.is_empty(), "a hand Strike has a forecast")
	eq(int(fh["table"]), 2, "forecast reads the Strike Table")
	eq(int(fh["stages"]), 6, "table 2, +2 printed, +1 Drill, +1 Mastery")
	var fp: Dictionary = v.forecast(e.player(0).fighter.uid)
	eq(int(fp.get("life", -1)), 3, "the fighter's Power attack forecasts its printed wounds")
	var fa: Dictionary = v.forecast(art)
	eq(int(fa["life"]), 4, "an Art forecasts its base wounds")
	eq(int(fa["cost_stages"]), DuelEngine.ART_COST, "the Art's cost travels with the forecast")
	eq(int((fa["empowered"] as Dictionary)["life"]), 6, "the empower option forecasts its extra wounds")
	var steps: PackedStringArray = CardText.breakdown_steps(fh)
	check(steps[0].begins_with("Table 2"), "steps start with the table: %s" % steps[0])
	check(steps.size() == 4 and steps[1].contains("Test Heavy Strike"), "the card's own bonus is a step: %s" % ", ".join(steps))
	eq(CardText.short_damage(6, 0), "6 Vigor", "short damage wording")
	eq(CardText.short_damage(0, 4), "4 wounds", "short wounds wording")
	var wire: SeatView = SeatView.from_dict(v.to_dict())
	eq(int(wire.forecast(heavy)["stages"]), 6, "wire form keeps the forecasts")
	answer(e, &"attack", heavy)
	answer(e, &"no_defense")
	eq(e.player(1).fighter.vigor, 0, "the forecast Strike lands as forecast: 6 on 5 Vigor")
	eq(e.player(1).discard.size(), 1, "with one wound overflowing")
	var badge: Dictionary = CardText.attack_badge(lib.get_def("t_strike_plus2"))
	eq(str(badge["num"]) + " " + str(badge["word"]), "+2 Vigor", "Strike badge")
	badge = CardText.attack_badge(lib.get_def("t_strike"))
	eq(str(badge["num"]), "Table", "a bare Strike badge points at the table")
	badge = CardText.attack_badge(lib.get_def("t_art"))
	eq(str(badge["num"]) + " " + str(badge["word"]), "4 wounds", "Art badge shows the base wounds")


## "X only" on a card that attaches to X: playable while X is on the table, and it lands on X.
func test_attach_to_named_character() -> void:
	var alone: DuelEngine = engine(deck(filler(["t_oath", "t_oath", "t_oath"])), deck(filler(), "knave"))
	to_combat(alone)
	check(alone.prompt.find(&"use", uid_in_hand(alone, 0, "t_oath")) == null, "no Squire on the table: the oath cannot be used")
	var e: DuelEngine = engine(deck(filler(["t_oath", "t_oath", "t_oath"])), deck(filler(), "knave"))
	var squire: CardInstance = inject(e, 0, "t_ally_squire")
	to_combat(e)
	var oath: int = uid_in_hand(e, 0, "t_oath")
	check(oath >= 0 and e.prompt.find(&"use", oath) != null, "with the Squire in play the oath is usable though the fighter is in control")
	answer(e, &"use", oath)
	check(e.card(oath).attached_to == squire, "the oath attaches to the Squire, not the fighter")
	eq(e.player(0).attachments().size(), 1, "one attachment in play")


## "Limit 1 attached" caps copies on the table, not copies in the deck.
func test_attachment_limit_attached() -> void:
	var e: DuelEngine = engine(deck(filler(["t_vow", "t_vow", "t_vow"])), deck(filler(), "knave"))
	inject(e, 0, "t_ally_squire")
	to_combat(e)
	var first: int = uid_in_hand(e, 0, "t_vow")
	answer(e, &"use", first)
	eq(e.player(0).attachments().size(), 1, "the first vow is attached")
	answer(e, &"pass")
	eq(e.prompt.player, 0, "back to the vow's owner")
	var second: int = uid_in_hand(e, 0, "t_vow")
	check(second >= 0 and second != first, "another copy is in hand")
	check(e.prompt.find(&"use", second) == null, "and cannot be used while one is attached")
	check(CardText.rules_text(e.card(second).def).contains("Limit 1 attached."), "the card says so")
	eq(DeckValidator.validate(DeckList.load_from("res://data/decks/tide_companions.json"), shipped_library()).size(), 0, "the shipped deck with two copies is legal")


## An "X only" card that attaches to a different named personality: X must be in control to
## play it, it lands on the named one, and that one may hold a single copy.
func test_attach_to_other_named_personality() -> void:
	var e: DuelEngine = engine(deck(filler(["t_ally_squire", "t_pledge", "t_pledge"])), deck(filler(), "knave"))
	answer(e, &"place", uid_in_hand(e, 0, "t_ally_squire"))
	var squire: CardInstance = e.player(0).allies()[0]
	answer(e, &"declare")
	var first: int = uid_in_hand(e, 0, "t_pledge")
	check(e.prompt.find(&"use", first) == null, "the fighter is in control, so the Squire's card cannot be used")
	var f: DuelEngine = engine(deck(filler(["t_ally_squire", "t_pledge", "t_pledge"])), deck(filler(), "knave"))
	answer(f, &"place", uid_in_hand(f, 0, "t_ally_squire"))
	squire = f.player(0).allies()[0]
	f.player(0).fighter.vigor = 1
	answer(f, &"declare")
	answer(f, &"control", squire.uid)
	first = uid_in_hand(f, 0, "t_pledge")
	check(f.prompt.find(&"use", first) != null, "with the Squire in control it can")
	answer(f, &"use", first)
	eq(f.card(first).attached_to, f.player(0).fighter, "it attaches to the named fighter, not to the Squire")
	var text: String = CardText.rules_text(f.card(first).def)
	check(text.contains("Attach this card to your Test Knight.") and text.contains("Test Knight may have only 1 attached."), "worded: %s" % text)
	answer(f, &"pass")
	if prompt_kind(f) == &"control":
		answer(f, &"control", squire.uid)
	var second: int = uid_in_hand(f, 0, "t_pledge")
	check(second >= 0 and f.prompt.find(&"use", second) == null, "a second copy cannot go on the same personality")


## Answers a pending search prompt with its first match.
func take_search(e: DuelEngine) -> void:
	check(e.prompt != null and bool(e.prompt.context.get("search", false)), "a search asks before it takes")
	if e.prompt == null or e.prompt.card_options().is_empty():
		return
	answer(e, &"pick_option", e.prompt.card_options()[0])


## A Life Deck search is a look through the deck: asked even with one match or none, the whole
## deck shown to the searcher alone, "take nothing" allowed, one shuffle at the end unless the
## effect says otherwise.
func test_search_looks_through_the_deck() -> void:
	var e: DuelEngine = engine(deck(filler(["t_seek", "t_seek_quiet", "t_strike", "t_art"])), deck(filler(), "knave"))
	to_combat(e)
	e.shuffle_decks = true
	answer(e, &"use", uid_in_hand(e, 0, "t_seek"))
	eq(prompt_kind(e), &"pick_option", "one match still asks")
	eq(e.prompt.card_options().size(), 1, "the one Art is the only pick")
	check(e.prompt.find(&"pick_none") != null, "taking nothing is allowed")
	var library: Array = e.prompt.context.get("library", [])
	eq(library.size(), e.player(0).life_deck.size(), "the whole Life Deck is listed")
	var mine: SeatView = SeatView.of(e, 0)
	var theirs: SeatView = SeatView.of(e, 1)
	var seen: int = 0
	var leaked: int = 0
	for uid in library:
		if not mine.card(int(uid)).hidden():
			seen += 1
		if not theirs.card(int(uid)).hidden():
			leaked += 1
	eq(seen, library.size(), "the searcher sees every card in it")
	eq(leaked, 0, "the other seat sees none of it")
	var sim: DuelEngine = e.clone()
	sim.determinize(0, 9)
	var kept: int = 0
	for uid in library:
		if sim.card(int(uid)).def == e.card(int(uid)).def:
			kept += 1
	eq(kept, library.size(), "a simulation for the searcher keeps the deck it is looking at")
	answer(e, &"pick_none")
	check(uid_in_hand(e, 0, "t_art") < 0, "nothing taken")
	check(has_event(e, &"deck_shuffled"), "the deck is shuffled after the look")
	# No match: the look still happens, and still ends in a shuffle.
	var none: DuelEngine = engine(deck(filler(["t_seek", "t_strike", "t_strike"])), deck(filler(), "knave"))
	to_combat(none)
	none.shuffle_decks = true
	answer(none, &"use", uid_in_hand(none, 0, "t_seek"))
	eq(prompt_kind(none), &"pick_option", "no match still shows the deck")
	eq(none.prompt.card_options().size(), 0, "with nothing to pick")
	eq(PromptView.of(none.prompt, none).title, "Search: nothing in your Life Deck matches", "and says so")
	answer(none, &"pick_none")
	check(has_event(none, &"deck_shuffled"), "shuffled all the same")
	# `no_shuffle` leaves the order alone.
	var quiet: DuelEngine = engine(deck(filler(["t_seek_quiet", "t_strike", "t_strike", "t_art"])), deck(filler(), "knave"))
	to_combat(quiet)
	quiet.shuffle_decks = true
	answer(quiet, &"use", uid_in_hand(quiet, 0, "t_seek_quiet"))
	take_search(quiet)
	check(uid_in_hand(quiet, 0, "t_art") >= 0, "the Art was taken")
	check(not has_event(quiet, &"deck_shuffled"), "no shuffle when the card says so")


## Grounds bind both players, so the AI weighs a new one against the one in play by whose
## cards it helps and hinders, and counts the Combat that placing it gives up.
func test_ai_weighs_grounds() -> void:
	var drills: Array[String] = []
	for i in range(8):
		drills.append("t_drill_free")
	var e: DuelEngine = engine(deck(filler(drills)), deck(filler(), "knave"))
	var profile: AiProfile = AiProfile.default_profile()
	var hush: CardDef = lib.get_def("t_grounds_hush")
	var forge: CardDef = lib.get_def("t_grounds_forge")
	check(AiEvaluator.grounds_value(e, 0, hush, profile) < 0.0, "Grounds that forbid Non-Combats are bad for the Drill deck")
	check(AiEvaluator.grounds_value(e, 1, hush, profile) >= 0.0, "and not for the deck across the table, which has shown none")
	check(AiEvaluator.grounds_value(e, 0, forge, profile) > AiEvaluator.grounds_value(e, 0, hush, profile), "Strike Grounds suit it better")
	eq(AiEvaluator.grounds_value(e, 0, null, profile), 0.0, "no Grounds is the zero point")
	var before: float = AiEvaluator.evaluate(e, 0, profile)
	e.state.grounds = e._instance(hush, 1, &"grounds")
	check(AiEvaluator.evaluate(e, 0, profile) < before, "the rival's hushing Grounds in play lower the position")
	var card_forge: CardInstance = e._instance(forge, 0, &"hand")
	var card_hush: CardInstance = e._instance(hush, 0, &"hand")
	var me: PlayerState = e.player(0)
	var replace_score: float = AiScorer._grounds_score(e, profile, me, card_forge)
	e.state.grounds = e._instance(forge, 0, &"grounds")
	var downgrade_score: float = AiScorer._grounds_score(e, profile, me, card_hush)
	check(replace_score > downgrade_score, "replacing bad Grounds with good ones scores above the reverse (%.2f vs %.2f)" % [replace_score, downgrade_score])
	check(downgrade_score < 0.0, "swapping good Grounds for bad ones is worse than doing nothing")


func shipped_library() -> CardLibrary:
	var lib: CardLibrary = CardLibrary.new()
	lib.load_dir("res://data/cards")
	return lib


## Step 10: one multiplier at most, caps at deal time, and "cannot be reduced" ignores both
## reductions and caps.
func test_multiplier_cap_and_no_reduce() -> void:
	var e: DuelEngine = engine(deck(filler(["t_strike", "t_strike", "t_strike_firm"])), deck(filler(["t_art", "t_art", "t_art"]), "knave"))
	inject(e, 0, "t_drill_strike")
	inject(e, 0, "t_drill_double")
	to_combat(e)
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike"))
	# table 2, +1 drill, then x2 = 6 stages: 5 absorbed, 1 wound
	eq(e.player(1).fighter.vigor, 0, "doubled strike empties the fighter")
	eq(e.player(1).discard.size(), 1, "one stage overflowed")
	var mod: Dictionary = {}
	for ev in e.events:
		if ev.type == &"modified_damage":
			mod = ev.data
	eq(int(mod.get("stages", 0)), 6, "modified damage reports the doubled total")
	check(CardText.modified_damage_line(mod).contains("x2 (Test Doubling Drill)"), "the multiplier is named in the log: %s" % CardText.modified_damage_line(mod))
	e.player(1).fighter.vigor = 5
	inject(e, 1, "t_drill_cap")
	answer(e, &"pass")
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike"))
	eq(e.player(1).fighter.vigor, 2, "the cap holds the doubled strike to 3 stages")
	e.player(1).fighter.vigor = 5
	answer(e, &"pass")
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike_firm"))
	eq(e.player(1).fighter.vigor, 0, "a strike that cannot be reduced ignores the cap")
	check(SeatView.of(e, 1).attack.is_empty(), "attack cleared after resolution")


## Tokens are immune to card effects that do not name them.
func test_tokens_immune_unless_named() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(), "knave"))
	inject(e, 1, "t_token_1")
	inject(e, 1, "t_noncombat_draw")
	eq(e.player(1).in_play.size(), 2, "a Token and a Non-Combat in play")
	eq(e.dev_effect(0, {"op": "discard_in_play", "who": "opponent", "card_type": "any", "all": true}), "", "dev effect ran")
	eq(e.player(1).tokens().size(), 1, "the Token stays")
	eq(e.player(1).non_combats().size(), 0, "the Non-Combat went")
	eq(e.dev_effect(0, {"op": "discard_in_play", "who": "opponent", "card_type": "token"}), "", "a named Token effect ran")
	eq(e.player(1).tokens().size(), 0, "named, the Token goes")


## Cards that end Combat are attack actions only, never a defense, even if they could stop.
func test_end_combat_card_is_no_defense() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(["t_truce_guard", "t_truce_guard", "t_truce_guard"]), "knave"))
	to_combat(e)
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike"))
	eq(prompt_kind(e), &"attack_action", "no defense possible, straight to the fight back")
	check(e.prompt.find(&"use", uid_in_hand(e, 1, "t_truce_guard")) != null, "but it can be used in the attack phase")


## A guild Drill locked out by the Drill in play may be shown and shuffled back.
func test_locked_out_drill_shuffles_back() -> void:
	var e: DuelEngine = engine(deck(filler(["t_drill_guard", "t_drill_guard", "t_drill_guard"])), deck(filler(), "knave"))
	inject(e, 0, "t_drill_strike")
	e._prompt_non_combat()   # the prompt was built before the Drill arrived
	eq(prompt_kind(e), &"non_combat", "non-combat prompt")
	var guard: int = uid_in_hand(e, 0, "t_drill_guard")
	check(e.prompt.find(&"place", guard) == null, "a Tide Drill cannot join Ember Drills")
	check(e.prompt.find(&"shuffle_back", guard) != null, "so it may be shuffled back")
	var deck_before: int = e.player(0).life_deck.size()
	answer(e, &"shuffle_back", guard)
	eq(e.card(guard).zone, &"life_deck", "the Drill is back in the Life Deck")
	eq(e.player(0).life_deck.size(), deck_before + 1, "deck grew by one")
	check(has_event(e, &"drill_shuffled_back"), "event logged")


## Look at the top three and put them back in any order.
func test_look_at_rearrange() -> void:
	var e: DuelEngine = engine(deck(filler(["t_order"])), deck(filler(), "knave"))
	to_combat(e)
	var top3: Array[int] = [e.player(0).life_deck[0].uid, e.player(0).life_deck[1].uid, e.player(0).life_deck[2].uid]
	answer(e, &"use", uid_in_hand(e, 0, "t_order"))
	eq(prompt_kind(e), &"pick_option", "rearrange prompt")
	check(bool(e.prompt.context.get("rearrange", false)), "flagged as a rearrange")
	eq(e.prompt.options.size(), 3, "three cards to order")
	answer(e, &"pick_option", top3[2])
	eq(e.prompt.options.size(), 2, "two left")
	answer(e, &"pick_option", top3[1])
	eq(prompt_kind(e), &"attack_action", "the last card needs no choice")
	eq(e.player(0).life_deck[0].uid, top3[2], "chosen first goes on top")
	eq(e.player(0).life_deck[1].uid, top3[1], "then the second")
	eq(e.player(0).life_deck[2].uid, top3[0], "the leftover card is third")
	check(has_event(e, &"rearranged"), "rearranged event")


## The seat view carries every effective per-player value, so clients never assume a rules constant.
func test_effective_values_in_seat_view() -> void:
	var e: DuelEngine = engine(deck(filler(["t_forbid_arts", "t_strike", "t_strike"]), "knight", "ember", "t_mastery_ember"), deck(filler(["t_art", "t_art", "t_art"]), "knave", "tide", "t_mastery_hard"))
	var v: SeatView = SeatView.of(e, 0)
	eq(v.player(1).acclaim_needed, DuelEngine.ACCLAIM_TO_TIER, "the plain player needs the rulebook count")
	eq(v.player(0).acclaim_needed, 6, "opposite a demanding Mastery the view says 6")
	eq(v.player(0).recover_gain, e.player(0).fighter.surge() + DuelEngine.STYLE_SURGE_BONUS, "recover gain is Surge Rate plus the flat bonus")
	eq(v.player(1).recover_gain, e.recover_gain(e.player(1)), "the view matches the engine getter")
	e.player(0).acclaim = 4
	e.dev_effect(0, {"op": "acclaim", "amount": 1})
	eq(e.player(0).fighter.tier, 1, "5 Acclaim is not enough opposite the Mastery")
	eq(e.player(0).acclaim, 5, "Acclaim keeps counting")
	e.dev_effect(0, {"op": "set_acclaim_needed", "amount": 8})
	eq(SeatView.of(e, 1).player(0).acclaim_needed, 8, "a raised base shows in the view")
	e.dev_effect(0, {"op": "acclaim_needed", "amount": -3})
	eq(e.player(0).acclaim_needed, 5, "delta op moves the base")
	eq(e.player(0).fighter.tier, 1, "a base below the Mastery's demand still needs 6")
	check(has_event(e, &"acclaim_needed_changed"), "acclaim_needed_changed event")
	e.dev_effect(0, {"op": "acclaim", "amount": 1})
	eq(e.player(0).fighter.tier, 2, "6 Acclaim rises a tier opposite the Mastery")
	eq(e.player(0).acclaim, 0, "and resets")
	to_combat(e)
	answer(e, &"use", uid_in_hand(e, 0, "t_forbid_arts"))
	var during: SeatView = SeatView.of(e, 1)
	check(during.player(1).restrictions.has("art_attacks"), "a forbid in force is listed on its target")
	check(during.player(0).restrictions.is_empty(), "and not on the other player")
	var back: SeatPlayer = SeatPlayer.from_dict(during.player(1).to_dict())
	eq(back.restrictions, during.player(1).restrictions, "wire form keeps restrictions")
	eq(back.acclaim_needed, during.player(1).acclaim_needed, "wire form keeps acclaim needed")
	eq(during.fighter_owner(e.player(0).fighter.uid).index, 0, "fighter_owner finds the seat")
	eq(during.live_vigor(e.player(0).fighter.uid), e.player(0).fighter.vigor, "live_vigor reads the card")
	check(during.fighter_owner(uid_in_hand(e, 0, "t_strike")) == null, "a hand card has no standing")


func test_attachment_modifier() -> void:
	var e: DuelEngine = engine(deck(filler(["t_attach", "t_strike", "t_strike"])), deck(filler(), "knave"))
	to_combat(e)
	var charm: int = uid_in_hand(e, 0, "t_attach")
	answer(e, &"use", charm)
	eq(e.card(charm).zone, &"in_play", "attached card sits in play")
	eq(e.card(charm).attached_to, e.player(0).fighter, "attached to the fighter")
	eq(e.player(0).attachments().size(), 1, "counted as an attachment")
	answer(e, &"pass")
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike"))
	eq(e.player(1).fighter.vigor, 1, "2 from the table plus 2 from the attachment")


func test_constant_power() -> void:
	var e: DuelEngine = engine(deck(filler(), "knight", "", "", 3, "tf_constant"), deck(filler(["t_guard", "t_guard", "t_guard"]), "knave"))
	to_combat(e)
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike"))
	check(has_event(e, &"attack_declared"), "attack went out")
	eq(prompt_kind(e), &"attack_action", "no defense prompt: a stops-any guard cannot stop a focused attack")
	eq(e.player(1).fighter.vigor, 3, "table 1 (same band) plus the constant +1")


func test_master_use() -> void:
	var e: DuelEngine = engine(deck(filler(), "knight", "", "", 3, "tf_knight", "t_master_use"), deck(filler(), "knave"))
	eq(prompt_kind(e), &"non_combat", "master power offered in the Non-Combat step")
	var m: int = e.player(0).master.uid
	answer(e, &"master", m)
	eq(e.player(0).hand.size(), 5, "master drew two")
	check(has_event(e, &"master_used"), "master_used event")
	eq(prompt_kind(e), &"declare", "once per game: no second offer")


func test_start_in_play() -> void:
	var e: DuelEngine = engine(deck(filler(["t_start_drill"])), deck(filler(), "knave"))
	eq(e.player(0).drills().size(), 1, "drill began the game in play")
	to_combat(e)
	eq(e.player(0).acclaim, 1, "entering-combat effect fired")
	var fired: int = 0
	var line: String = ""
	for ev in e.events:
		if ev.type == &"trigger_fired" and e.card(int(ev.data.get("card", -1))).def.id == "t_start_drill":
			fired += 1
			line = CardText.event_line(ev, e)
	eq(fired, 1, "the drill's trigger is logged once")
	eq(line, "Test Opening Drill triggers when entering Combat.", "with the card and the moment")


func test_pay_stages() -> void:
	var e: DuelEngine = engine(deck(filler(["t_pay_art", "t_strike", "t_strike"])), deck(filler(), "knave"))
	to_combat(e)
	var deck_before: int = e.player(1).life_deck.size()
	answer(e, &"attack", uid_in_hand(e, 0, "t_pay_art"))
	eq(prompt_kind(e), &"pay", "pay prompt")
	eq(e.prompt.options.size(), 5, "0, 2, 4, 6, 8 from 8 vigor")
	answer(e, &"pay", -1, 4)
	eq(e.player(0).fighter.vigor, 4, "paid 4")
	eq(e.player(1).life_deck.size(), deck_before - 6, "4 base plus 2 bought")


func test_name_card() -> void:
	var e: DuelEngine = engine(deck(filler(["t_name_drill"])), deck(filler(["t_art", "t_art", "t_art"]), "knave"))
	answer(e, &"place", uid_in_hand(e, 0, "t_name_drill"))
	eq(prompt_kind(e), &"name_card", "naming prompt")
	answer(e, &"name_card", e.player(0).drills()[0].uid, "Test Art")
	check(has_event(e, &"card_named"), "card_named event")
	to_combat(e)
	answer(e, &"pass")
	check(e.prompt.find(&"attack", uid_in_hand(e, 1, "t_art")) == null, "named card locked out")


func test_copied_attack() -> void:
	var e: DuelEngine = engine(deck(filler(["t_strike_plus2", "t_strike_plus2", "t_strike_plus2"])), deck(filler(["t_copy_parry", "t_copy_parry", "t_copy_parry"]), "knave"))
	to_combat(e)
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike_plus2"))
	answer(e, &"defend", uid_in_hand(e, 1, "t_copy_parry"))
	check(has_event(e, &"attack_stopped"), "parry stopped it")
	check(e.prompt.find(&"copied_attack") != null, "copied attack offered")
	answer(e, &"copied_attack")
	check(e.player(0).fighter.vigor < 7, "copied attack dealt stage damage back")


func test_prevent_all_and_no_prevent() -> void:
	var e: DuelEngine = engine(deck(filler(["t_prevent_all", "t_strike", "t_strike"])), deck(filler(["t_strike", "t_no_prevent_art", "t_art"]), "knave"))
	to_combat(e)
	answer(e, &"use", uid_in_hand(e, 0, "t_prevent_all"))
	answer(e, &"attack", uid_in_hand(e, 1, "t_strike"))
	eq(e.player(0).fighter.vigor, 8, "prevented strike did nothing")
	answer(e, &"pass")
	var deck_before: int = e.player(0).life_deck.size()
	answer(e, &"attack", uid_in_hand(e, 1, "t_no_prevent_art"))
	eq(e.player(0).life_deck.size(), deck_before - 4, "unpreventable art still lands")


func test_master_shields() -> void:
	var e: DuelEngine = engine(deck(filler(["t_jeer", "t_set_tier", "t_strike"])), deck(filler(), "knave", "", "", 3, "tf_knight", "t_master_shield"))
	check(e.player(1).no_favor_win, "master forbids the favor win")
	e.player(1).acclaim = 2
	e.player(1).fighter.tier = 2
	to_combat(e)
	answer(e, &"use", uid_in_hand(e, 0, "t_jeer"))
	eq(e.player(1).acclaim, 2, "acclaim shielded")
	check(has_event(e, &"acclaim_shielded"), "acclaim_shielded event")
	answer(e, &"pass")
	answer(e, &"use", uid_in_hand(e, 0, "t_set_tier"))
	eq(e.player(1).fighter.tier, 2, "tier shielded")


func test_set_tier() -> void:
	var e: DuelEngine = engine(deck(filler(["t_set_tier", "t_strike", "t_strike"])), deck(filler(), "knave"))
	e.player(1).fighter.tier = 3
	to_combat(e)
	answer(e, &"use", uid_in_hand(e, 0, "t_set_tier"))
	eq(e.player(1).fighter.tier, 1, "dropped to tier 1")
	eq(e.player(1).fighter.vigor, 5, "lost tier resets vigor")


func test_draw_until_and_draw_discard() -> void:
	var e: DuelEngine = engine(deck(filler(["t_draw_until", "t_draw_discard", "t_strike"])), deck(filler(), "knave"))
	to_combat(e)
	var refill: int = uid_in_hand(e, 0, "t_draw_until")
	answer(e, &"use", refill)
	eq(e.player(0).hand.size(), 5, "drew up to five")
	answer(e, &"pass")
	answer(e, &"use", uid_in_hand(e, 0, "t_draw_discard"))
	eq(e.card(refill).zone, &"hand", "bottom of the discard pile came back to hand")


func test_search_to_play() -> void:
	var e: DuelEngine = engine(deck(filler(["t_search_play", "t_strike", "t_strike", "t_drill_free"])), deck(filler(), "knave"))
	to_combat(e)
	answer(e, &"use", uid_in_hand(e, 0, "t_search_play"))
	take_search(e)
	eq(e.player(0).drills().size(), 1, "drill searched straight into play")


func test_attack_variants() -> void:
	var e: DuelEngine = engine(deck(filler(["t_variant_strike", "t_strike", "t_strike"]), "knight", "ember", "t_mastery_ember"), deck(filler(), "knave"))
	to_combat(e)
	var deck_before: int = e.player(1).life_deck.size()
	answer(e, &"attack", uid_in_hand(e, 0, "t_variant_strike"))
	eq(e.player(1).fighter.vigor, 0, "table 2 + 1 + 3 (variant) + 1 (mastery) empties 5 vigor")
	eq(e.player(1).life_deck.size(), deck_before - 2, "overflow of 2 into wounds")


func test_owner_chooses_discard() -> void:
	var e: DuelEngine = engine(deck(filler(["t_owner_glare", "t_strike", "t_strike"])), deck(filler(["t_art", "t_art", "t_art"]), "knave"))
	to_combat(e)
	answer(e, &"use", uid_in_hand(e, 0, "t_owner_glare"))
	eq(prompt_kind(e), &"discard_choice", "choice prompt")
	eq(e.prompt.player, 0, "the card's owner picks")
	var victim: int = e.prompt.options[0].card
	eq(e.card(victim).owner, 1, "options are the opponent's hand")
	answer(e, &"discard_choice", victim)
	eq(e.card(victim).zone, &"discard", "chosen card discarded")
	eq(e.player(1).hand.size(), 2, "opponent down to two")


func test_stop_next() -> void:
	var e: DuelEngine = engine(deck(filler(["t_strike", "t_strike", "t_strike"])), deck(filler(["t_stop_next", "t_stop_next", "t_stop_next"]), "knave"))
	to_combat(e)
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike"))
	answer(e, &"defend", uid_in_hand(e, 1, "t_stop_next"))
	answer(e, &"pass")
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike"))
	check(has_event(e, &"floating_stop"), "the next attack was stopped by the standing effect")
	eq(e.player(1).fighter.vigor, 5, "no damage taken")


func test_only_attacks() -> void:
	var e: DuelEngine = engine(deck(filler(["t_only_attacks", "t_strike", "t_strike"])), deck(filler(["t_taunt", "t_taunt", "t_taunt"]), "knave"))
	to_combat(e)
	answer(e, &"use", uid_in_hand(e, 0, "t_only_attacks"))
	eq(e.prompt.player, 1, "fight back")
	check(e.prompt.find(&"use", uid_in_hand(e, 1, "t_taunt")) == null, "non-attack combat card locked out")
	check(e.prompt.find(&"pass") != null, "passing stays legal")


func test_vigor_without_overflow() -> void:
	var e: DuelEngine = engine(deck(filler(["t_vigor_noover", "t_strike", "t_strike"])), deck(filler(), "knave"))
	to_combat(e)
	var deck_before: int = e.player(1).life_deck.size()
	answer(e, &"use", uid_in_hand(e, 0, "t_vigor_noover"))
	eq(e.player(1).fighter.vigor, 0, "drained to zero")
	eq(e.player(1).life_deck.size(), deck_before, "no life lost past zero")
	var logged: bool = false
	for ev in e.events:
		if ev.type == &"vigor_changed" and int(ev.data.get("to", -1)) == 0 and e.card(int(ev.data.get("source", -1))).def.id == "t_vigor_noover":
			logged = true
	check(logged, "the vigor change is logged with its source card")


func test_use_in_attack_phase() -> void:
	var e: DuelEngine = engine(deck(filler(["t_use_in_attack", "t_strike", "t_strike"])), deck(filler(), "knave"))
	to_combat(e)
	var uid: int = uid_in_hand(e, 0, "t_use_in_attack")
	check(e.prompt.find(&"use", uid) != null, "a defense flagged use_in_attack can be used in the attack phase")
	answer(e, &"use", uid)
	eq(e.player(0).acclaim, 1, "its effect resolved")


# --- Choice prompts, inspection, and the rest -------------------------------

func test_may_prompt() -> void:
	var no: DuelEngine = engine(deck(filler(["t_may_search", "t_strike", "t_strike", "t_art"])), deck(filler(), "knave"))
	to_combat(no)
	answer(no, &"use", uid_in_hand(no, 0, "t_may_search"))
	eq(prompt_kind(no), &"pick_option", "a 'you may' line asks first")
	eq(no.prompt.player, 0, "the owner answers")
	var pv: PromptView = PromptView.of(no.prompt, no)
	eq(pv.title, "Test Bargain: use the optional effect?", "the prompt names the card")
	check(no.card(int(pv.context.get("source", -1))).def.id == "t_may_search", "the prompt carries the card that asked")
	var text: String = str(pv.context.get("text", ""))
	check(text.contains("Vigor") and text.contains("search"), "the prompt says what a yes does: %s" % text)
	check(not text.contains(" may "), "without the 'may'")
	var skip: Dictionary = {"trigger": "before_damage", "may": true, "skip_damage": true, "op": "discard_in_play", "who": "opponent", "card_type": "drill", "all": true}
	var skip_text: String = CardText.may_text(skip)
	check(not skip_text.begins_with("Hit") and skip_text.ends_with("The attack then deals no damage."), "a fired trigger drops its head but keeps the damage cost: %s" % skip_text)
	answer(no, &"pick_option", -1, "no")
	eq(no.player(0).fighter.vigor, 8, "declined: no cost paid")
	check(uid_in_hand(no, 0, "t_art") < 0, "declined: no search either")
	var yes: DuelEngine = engine(deck(filler(["t_may_search", "t_strike", "t_strike", "t_art"])), deck(filler(), "knave"))
	to_combat(yes)
	answer(yes, &"use", uid_in_hand(yes, 0, "t_may_search"))
	answer(yes, &"pick_option", -1, "yes")
	eq(yes.player(0).fighter.vigor, 6, "accepted: cost paid")
	take_search(yes)
	check(uid_in_hand(yes, 0, "t_art") >= 0, "accepted: the 'then' search ran")


func test_pay_vigor() -> void:
	var e: DuelEngine = engine(deck(filler(["t_pay_vigor", "t_strike", "t_strike"])), deck(filler(), "knave"))
	to_combat(e)
	answer(e, &"use", uid_in_hand(e, 0, "t_pay_vigor"))
	eq(prompt_kind(e), &"pay", "pay prompt")
	answer(e, &"pay", -1, 3)
	eq(e.player(0).fighter.vigor, 5, "paid 3")
	eq(e.player(0).acclaim, 3, "the 'then' line ran once per Vigor")


func test_look_at() -> void:
	var cards: Array[String] = filler(["t_look"])
	cards.append("t_art")
	var e: DuelEngine = engine(deck(cards), deck(filler(), "knave"))
	to_combat(e)
	answer(e, &"use", uid_in_hand(e, 0, "t_look"))
	eq(prompt_kind(e), &"pick_option", "one matching card among the bottom three")
	var art: int = e.prompt.options[0].card
	eq(e.card(art).def.id, "t_art", "the art at the bottom is offered")
	answer(e, &"pick_option", art)
	eq(e.card(art).zone, &"hand", "taken into hand")


func test_search_choice() -> void:
	var e: DuelEngine = engine(deck(filler(["t_seek", "t_strike", "t_strike", "t_art", "t_art_big"])), deck(filler(), "knave"))
	to_combat(e)
	answer(e, &"use", uid_in_hand(e, 0, "t_seek"))
	eq(prompt_kind(e), &"pick_option", "two distinct arts: the searcher chooses")
	eq(e.prompt.options.size(), 3, "two cards plus none")
	var big: int = -1
	for o in e.prompt.options:
		if o.card >= 0 and e.card(o.card).def.id == "t_art_big":
			big = o.card
	answer(e, &"pick_option", big)
	check(uid_in_hand(e, 0, "t_art_big") >= 0, "chosen card searched")


func test_before_damage_skip() -> void:
	var e: DuelEngine = engine(deck(filler(["t_skip_strike", "t_strike", "t_strike"])), deck(filler(), "knave"))
	to_combat(e)
	inject(e, 1, "t_drill_free")
	answer(e, &"attack", uid_in_hand(e, 0, "t_skip_strike"))
	eq(prompt_kind(e), &"pick_option", "successful attack offers the instead-of-damage choice")
	answer(e, &"pick_option", -1, "yes")
	eq(e.player(1).drills().size(), 0, "drill discarded")
	eq(e.player(1).fighter.vigor, 5, "no damage dealt instead")


func test_stops_needed() -> void:
	var e: DuelEngine = engine(deck(filler(), "knight", "", "", 3, "tf_double"), deck(filler(["t_parry", "t_parry", "t_parry"]), "knave"))
	to_combat(e)
	answer(e, &"power", e.player(0).fighter.uid)
	answer(e, &"defend", uid_in_hand(e, 1, "t_parry"))
	eq(prompt_kind(e), &"defense", "one stop is not enough: defend again")
	answer(e, &"defend", uid_in_hand(e, 1, "t_parry"))
	check(has_event(e, &"attack_stopped"), "two stops end it")
	eq(e.player(1).fighter.vigor, 5, "no damage")


func test_ally_power_without_control() -> void:
	var e: DuelEngine = engine(deck(filler(["t_ally_free"])), deck(filler(), "knave"))
	answer(e, &"place", uid_in_hand(e, 0, "t_ally_free"))
	to_combat(e)
	var al: CardInstance = e.player(0).allies()[0]
	check(e.prompt.find(&"power", al.uid) != null, "ally power offered while the fighter is in control")
	var deck_before: int = e.player(1).life_deck.size()
	answer(e, &"power", al.uid)
	eq(e.player(1).life_deck.size(), deck_before - 1, "the ally's strike dealt its wound")


func test_life_per_opponent_token() -> void:
	var e: DuelEngine = engine(deck(filler(["t_token_strike", "t_strike", "t_strike"])), deck(filler(), "knave", "ember", "t_mastery_ember"))
	inject(e, 1, "t_token_2")
	inject(e, 1, "t_token_3")
	to_combat(e)
	var deck_before: int = e.player(1).life_deck.size()
	answer(e, &"attack", uid_in_hand(e, 0, "t_token_strike"))
	eq(e.player(1).life_deck.size(), deck_before - 2, "one wound per opponent Token")


func test_lonely_drill() -> void:
	var e: DuelEngine = engine(deck(filler(["t_lonely_drill", "t_drill_free"])), deck(filler(), "knave"))
	answer(e, &"place", uid_in_hand(e, 0, "t_lonely_drill"))
	eq(e.player(0).drills().size(), 1, "alone it stays")
	answer(e, &"place", uid_in_hand(e, 0, "t_drill_free"))
	eq(e.player(0).drills().size(), 1, "company discards it")
	eq(e.player(0).drills()[0].def.id, "t_drill_free", "the newcomer remains")


func test_unused_remain_returns() -> void:
	var e: DuelEngine = engine(deck(filler(["t_strike", "t_strike", "t_strike"])), deck(filler(["t_returning_block", "t_returning_block", "t_returning_block"]), "knave"))
	to_combat(e)
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike"))
	var b: int = uid_in_hand(e, 1, "t_returning_block")
	answer(e, &"defend", b)
	eq(e.card(b).zone, &"in_play", "stays for a second use")
	answer(e, &"pass")
	answer(e, &"pass")
	eq(e.card(b).zone, &"life_deck", "unused second use: shuffled back instead of removed")


func test_return_removed() -> void:
	var e: DuelEngine = engine(deck(filler(["t_recall", "t_strike", "t_strike"])), deck(filler(), "knave"))
	var al: CardInstance = inject(e, 0, "t_ally_squire")
	e._remove_from_game(al)
	eq(al.zone, &"removed", "ally removed")
	to_combat(e)
	answer(e, &"use", uid_in_hand(e, 0, "t_recall"))
	eq(al.zone, &"life_deck", "removed ally shuffled back")


func test_last_searched_target() -> void:
	var e: DuelEngine = engine(deck(filler(["t_heal", "t_strike", "t_strike"])), deck(filler(), "knave"))
	var al: CardInstance = inject(e, 0, "t_ally_squire")
	e._move_to_discard(al)
	to_combat(e)
	answer(e, &"use", uid_in_hand(e, 0, "t_heal"))
	eq(al.zone, &"in_play", "ally back from the discard")
	eq(al.vigor, 10, "then raised to full")


func test_forbid_unless_vigor() -> void:
	var e: DuelEngine = engine(deck(filler(["t_lock", "t_strike", "t_strike"])), deck(filler(), "knave"))
	to_combat(e)
	answer(e, &"use", uid_in_hand(e, 0, "t_lock"))
	eq(prompt_kind(e), &"pick_option", "choose the locked type")
	answer(e, &"pick_option", -1, "strike_cards")
	check(not e._forbidden(e.player(1), "strike_cards"), "at 5 Vigor the lock does not bite")
	e.player(1).fighter.vigor = 4
	check(e._forbidden(e.player(1), "strike_cards"), "below 5 Vigor it does")


func test_forced_combat_from_armory() -> void:
	var armory: Array[String] = ["t_invite"]
	var e: DuelEngine = engine(deck(filler()), deck(filler(), "knave", "", "", 3, "tf_knight", "t_master", armory))
	answer(e, &"armory_done")
	eq(e.player(1).non_combats().size(), 1, "the summons began the game in play from the Armory")
	check(has_event(e, &"combat_declared"), "the active player could not skip Combat")
	eq(prompt_kind(e), &"attack_action", "straight into the attack phase")


func test_promoted_if_successful() -> void:
	var e: DuelEngine = engine(deck(filler(["t_promote_drill", "t_strike_end", "t_strike"])), deck(filler(["t_parry", "t_parry", "t_parry"]), "knave"))
	answer(e, &"place", uid_in_hand(e, 0, "t_promote_drill"))
	to_combat(e)
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike_end"))
	answer(e, &"defend", uid_in_hand(e, 1, "t_parry"))
	check(has_event(e, &"attack_stopped"), "parried")
	check(has_event(e, &"combat_end"), "promoted 'if successful' line still ended Combat")


func test_draw_check_named() -> void:
	var cards: Array[String] = ["t_scry", "t_strike", "t_strike", "t_ally_squire"]
	cards.append_array(filler())
	var e: DuelEngine = engine(deck(cards), deck(filler(), "knave"))
	to_combat(e)
	answer(e, &"use", uid_in_hand(e, 0, "t_scry"))
	eq(e.player(0).hand.size(), 4, "named card drawn, so a second draw followed")
	var line: String = ""
	var rival_line: String = ""
	var drawn: String = ""
	for ev in e.events:
		if ev.type == &"draw_check":
			check(bool(ev.data.get("matched", false)), "the check reports a match")
			drawn = e.card(int(ev.data["card"])).def.title
			line = CardText.event_line(ev, e, 0)
			rival_line = CardText.event_line(ev, e, 1)
	check(line.begins_with("Test Scry: the drawn card is %s" % drawn) and line.ends_with(", a named card."), "the checker's seat sees the card: %s" % line)
	check(not rival_line.contains(drawn) and rival_line.contains("a named card") and rival_line.contains("effect follows"), "the other seat learns only the result: %s" % rival_line)


## `discard: true` checks a life card thrown away, and `else_effects` pay out on a miss.
func test_draw_check_discard_and_else() -> void:
	for named in [true, false]:
		var cards: Array[String] = ["t_tithe", "t_strike", "t_strike", "t_ally_squire" if named else "t_strike"]
		cards.append_array(filler())
		var e: DuelEngine = engine(deck(cards), deck(filler(), "knave"))
		to_combat(e)
		var life_before: int = e.player(0).life_deck.size()
		answer(e, &"use", uid_in_hand(e, 0, "t_tithe"))
		var gained: int = 2 if named else 1
		eq(e.player(0).hand.size(), 2 + gained, "named %s: drew %d" % [named, gained])
		eq(e.player(0).life_deck.size(), life_before - 1 - gained, "one life card thrown away, %d drawn" % gained)
		var line: String = ""
		for ev in e.events:
			if ev.type == &"draw_check":
				eq(bool(ev.data.get("matched", false)), named, "the check reports %s" % named)
				eq(e.card(int(ev.data["card"])).zone, &"discard", "the checked card is in the discard pile")
				line = CardText.event_line(ev, e, 1)
		check(line.contains("the discarded card is"), "the log says discarded: %s" % line)
	var shipped: CardLibrary = CardLibrary.new()
	shipped.load_dir("res://data/cards")
	var text: String = CardText.rules_text(shipped.defs.get("steel_mastery"))
	check(text.contains("discard the top card of your Life Deck.") and text.contains("Otherwise, draw a card."),"the shipped Mastery words both branches: %s" % text)


## A Mastery's `on_attack` line is offered when its owner attacks, and `blocks_to_bottom` sends a
## used block of that guild under the Life Deck.
func test_mastery_on_attack_and_blocks_to_bottom() -> void:
	for pay in [true, false]:
		var e: DuelEngine = engine(deck(filler(), "knight", "ember", "t_mastery_flare"), deck(filler(["t_parry", "t_parry", "t_parry"]), "knave", "tide", "t_mastery_keep"))
		to_combat(e)
		var life_before: int = e.player(0).life_deck.size()
		answer(e, &"attack", uid_in_hand(e, 0, "t_strike"))
		eq(prompt_kind(e), &"pick_option", "the Mastery asks before the attack goes on")
		eq(e.prompt.player, 0, "and asks the attacker")
		answer(e, &"pick_option", -1, "yes" if pay else "no")
		eq(e.player(0).life_deck.size(), life_before - (1 if pay else 0), "pay %s: life cards spent" % pay)
		eq(prompt_kind(e), &"defense", "the rival may still block with a Strike block")
		eq(bool(e.prompt.context.get("focused", false)), pay, "pay %s: the attack is Focused only when paid for" % pay)
		var parry: int = uid_in_hand(e, 1, "t_parry")
		answer(e, &"defend", parry)
		eq(e.card(parry).zone, &"life_deck", "the Tide block went back to the Life Deck")
		eq(e.player(1).life_deck.back().uid, parry, "at the bottom")
	# A Focused attack is not asked about.
	var f: DuelEngine = engine(deck(filler(["t_strike_focused", "t_strike_focused", "t_strike_focused"]), "knight", "ember", "t_mastery_flare"), deck(filler(), "knave"))
	to_combat(f)
	answer(f, &"attack", uid_in_hand(f, 0, "t_strike_focused"))
	check(prompt_kind(f) != &"pick_option", "no question for an attack that is already Focused")
	var shipped: CardLibrary = CardLibrary.new()
	shipped.load_dir("res://data/cards")
	var text: String = CardText.rules_text(shipped.defs.get("ember_mastery"))
	check(text.contains("When you perform an attack") and text.contains("bottom of your Life Deck"), "the shipped Mastery words both halves: %s" % text)


func test_wound_trigger_at_fight_back() -> void:
	# P1's deck: the wound card sits on top after the three cards drawn at Combat.
	var cards: Array[String] = ["t_strike", "t_strike", "t_strike", "t_wound_art"]
	cards.append_array(filler())
	var e: DuelEngine = engine(deck(filler(["t_art", "t_art", "t_art"])), deck(cards, "knave"))
	to_combat(e)
	answer(e, &"attack", uid_in_hand(e, 0, "t_art"))
	var wounded: bool = false
	for c in e.player(1).discard:
		if c.def.id == "t_wound_art":
			wounded = true
	check(wounded, "the wound card was flipped")
	eq(e.player(1).acclaim, 2, "its effect fired at the start of the fight-back phase")


func test_look_at_play_option() -> void:
	var cards: Array[String] = ["t_peek_top", "t_strike", "t_strike", "t_drill_footwork_named", "t_strike"]
	cards.append_array(filler())
	var e: DuelEngine = engine(deck(cards), deck(filler(), "knave"))
	to_combat(e)
	answer(e, &"use", uid_in_hand(e, 0, "t_peek_top"))
	eq(prompt_kind(e), &"pick_option", "one matching card in the top three")
	answer(e, &"pick_option", e.prompt.options[0].card)
	eq(e.player(0).drills().size(), 1, "the matching card went straight into play")


func test_bond_and_unbond() -> void:
	var armory: Array[String] = ["t_bonded_hands"]
	var e: DuelEngine = engine(deck(filler(["t_ally_left", "t_ally_right", "t_bond_rite"]), "knight", "", "", 3, "tf_knight", "t_master", armory), deck(filler(), "knave"))
	answer(e, &"armory_done")
	answer(e, &"place", uid_in_hand(e, 0, "t_ally_left"))
	answer(e, &"place", uid_in_hand(e, 0, "t_ally_right"))
	answer(e, &"place", uid_in_hand(e, 0, "t_bond_rite"))
	to_combat(e)
	var rite: CardInstance = e.player(0).non_combats()[0]
	answer(e, &"use", rite.uid)
	eq(e.player(0).allies().size(), 1, "two Allies became one Bond")
	var bond: CardInstance = e.player(0).allies()[0]
	eq(bond.def.id, "t_bonded_hands", "the Bond card came from the Armory")
	eq(bond.vigor, 10, "at full Vigor")
	eq(bond.cards_under.size(), 2, "both Allies under it")
	check(has_event(e, &"bonded"), "bonded event")
	skip_to_turn(e, 3)
	skip_to_turn(e, 5)
	eq(e.player(0).allies().size(), 2, "after two of the owner's turns the Bond burned out and both returned")
	eq(bond.zone, &"armory", "the Bond card went back to the Armory")


func test_search_by_effect() -> void:
	var e: DuelEngine = engine(deck(filler(["t_thief_seek", "t_strike", "t_strike"])), deck(filler(), "knave"))
	var scout: CardInstance = e._instance(lib.get_def("t_scout"), 0, &"discard")
	e.player(0).discard.append(scout)
	var taunt: CardInstance = e._instance(lib.get_def("t_taunt"), 0, &"discard")
	e.player(0).discard.append(taunt)
	to_combat(e)
	answer(e, &"use", uid_in_hand(e, 0, "t_thief_seek"))
	eq(scout.zone, &"hand", "only the card that discards from the opponent's hand matched")
	eq(taunt.zone, &"discard", "the other stayed")


func test_end_turn() -> void:
	var e: DuelEngine = engine(deck(filler(["t_end_turn", "t_strike", "t_strike"])), deck(filler(), "knave"))
	to_combat(e)
	answer(e, &"use", uid_in_hand(e, 0, "t_end_turn"))
	eq(e.state.active, 1, "the turn ended at once")
	eq(e.player(0).hand.size(), 2, "no Discard step for the user")
	eq(e.player(1).hand.size(), 6, "nor for the opponent: the three Combat draws plus their own three")


func test_declare_window() -> void:
	var armory: Array[String] = ["t_summons"]
	var e: DuelEngine = engine(deck(filler()), deck(filler(["t_taunt", "t_taunt", "t_taunt"]), "knave", "", "", 3, "tf_knight", "t_master", armory))
	answer(e, &"armory_done")
	var herald: CardInstance = e.player(1).non_combats()[0]
	eq(herald.def.id, "t_summons", "the herald began the game in play from the Armory")
	eq(prompt_kind(e), &"declare", "turn 1: the opponent has no hand to pay with, so no window")
	var kept: CardInstance = e._instance(lib.get_def("t_taunt"), 1, &"hand")
	e.player(1).hand.append(kept)
	skip_to_turn(e, 2)
	answer(e, &"skip")
	answer(e, &"keep", kept.uid)
	answer(e, &"no_recover")
	eq(e.state.active, 0, "turn 3 is the active player's again")
	eq(prompt_kind(e), &"respond", "the opponent is asked during the active player's Declare step")
	eq(e.prompt.player, 1, "the card's owner responds")
	answer(e, &"use", herald.uid)
	eq(kept.zone, &"discard", "the single card in hand paid the cost")
	check(has_event(e, &"combat_declared"), "Combat forced")
	eq(prompt_kind(e), &"attack_action", "straight into the attack phase")
	eq(herald.zone, &"removed", "the card removed itself after use")


## A dev effect runs through the queue with its triggers and the same prompt comes back.
func test_dev_effect() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(), "knave"))
	to_combat(e)
	eq(prompt_kind(e), &"attack_action", "at an attack decision")
	eq(e.dev_effect(0, {"op": "acclaim", "amount": 2}), "", "accepted")
	eq(e.player(0).acclaim, 2, "acclaim raised")
	eq(prompt_kind(e), &"attack_action", "the same decision is back")
	eq(e.dev_effect(0, {"op": "acclaim", "amount": 3}), "", "accepted again")
	eq(e.player(0).fighter.tier, 2, "reaching 5 Acclaim rose a tier through the normal path")
	eq(e.player(0).acclaim, 0, "and reset Acclaim")
	var life_before: int = e.player(1).life_deck.size()
	eq(e.dev_effect(0, {"op": "discard_life", "amount": 2, "who": "opponent"}), "", "opponent-targeted effect")
	eq(e.player(1).life_deck.size(), life_before - 2, "the rival took two wounds")
	check(has_event(e, &"dev"), "the log gets a dev line")
	eq(e.dev_effect(0, {"op": "end_turn"}), "", "end turn accepted")
	eq(e.state.active, 1, "the turn passed")


## Generated rules text: conditions stay attached, same-trigger lines fold, both-player effects
## read once, and tier cards show constants and every part of a Power.
func test_card_text_wording() -> void:
	var plain_gain: Dictionary = {"op": "vigor", "amount": 3}
	eq(CardText.effect_text(plain_gain), "Gain 3 Vigor.", "an unconditional line reads bare")
	var hit: Dictionary = {"trigger": "if_successful", "op": "acclaim", "amount": 1}
	eq(CardText.effect_text(hit), "Hit: Raise your Acclaim 1.", "Hit label")
	var hit_ally: Dictionary = {"trigger": "if_successful", "op": "acclaim", "amount": 1, "when": {"allies_min": 1}}
	eq(CardText.effect_text(hit_ally), "Hit: If you have an Ally in play, raise your Acclaim 1.", "other conditions stay as sentences")
	var entering: Dictionary = {"trigger": "entering_combat", "op": "vigor", "amount": 5}
	eq(CardText.effect_text(entering), "When entering Combat, gain 5 Vigor.", "a triggered line")
	var remain: CardDef = CardDef.from_dict({"id": "r", "title": "R", "type": "strike", "attack": {"kind": "strike"}, "remain": 1})
	eq(CardText.rules_text(remain), "Strike.\nRemain 1.", "Remain shorthand")
	var remain2: CardDef = CardDef.from_dict({"id": "r2", "title": "R2", "type": "strike", "attack": {"kind": "strike"}, "remain_when": {"when": {"allies_min": 2}, "remain": 2}})
	eq(CardText.rules_text(remain2), "Strike.\nIf you have 2 or more Allies in play, Remain 2.", "Remain keeps its capital mid-sentence")
	var pair: Array = [
		{"trigger": "entering_combat", "op": "acclaim", "who": "opponent", "amount": -2},
		{"trigger": "entering_combat", "op": "vigor", "amount": 2, "target": "fighter"},
	]
	eq(CardText.effects_text(pair), PackedStringArray(["When entering Combat, lower your opponent's Acclaim 2 and gain 2 Vigor."]), "same trigger folds into one sentence")
	var forbids: Array = [
		{"op": "forbid", "what": "end_combat"}, {"op": "forbid", "who": "opponent", "what": "end_combat"},
		{"op": "forbid", "what": "stop_all"}, {"op": "forbid", "who": "opponent", "what": "stop_all"},
	]
	eq(CardText.effects_text(forbids), PackedStringArray(["Neither player may use cards that end Combat or use cards that stop all attacks for the remainder of Combat."]), "a forbid on both players reads once")
	var sweep: Array = [
		{"op": "discard_in_play", "who": "self", "card_type": "ally", "all": true, "remove": true},
		{"op": "discard_in_play", "card_type": "ally", "all": true, "remove": true, "who": "opponent"},
	]
	eq(CardText.effects_text(sweep), PackedStringArray(["All Allies in play are removed from the game."]), "clearing both sides reads once")
	var may: Dictionary = {"op": "vigor", "who": "opponent", "amount": -4, "may": true}
	eq(CardText.effect_text(may), "You may have your opponent lose 4 Vigor.", "a may on the opponent reads as a choice")
	eq(CardText.effect_text({"trigger": "on_place", "op": "name_card"}), "When placed, name a card. Neither player may play or use it while this is in play.", "no doubled lead-in")
	var uses: Array = [{"trigger": "use", "op": "discard_hand", "amount": 1, "random": false}, {"trigger": "use", "op": "draw", "amount": 2}]
	eq(CardText.effects_text(uses), PackedStringArray(["Use in Combat: Discard a card from your hand. Draw 2 cards."]), "uses share one label")
	var f: CardDef = CardDef.from_dict({"id": "x", "title": "X", "type": "fighter", "tiers": [
		{"tier": 1, "surge": 1, "might": [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
			"power": {"attack": {"kind": "strike", "stages": 3}, "effects": [{"op": "vigor", "amount": 5}, {"trigger": "if_stopped", "op": "draw", "amount": 1}], "uses": 2},
			"constant": {"first_styled_unstoppable": true, "forbid_opponent": ["art_attacks"]}, "shield": "strike"},
	]})
	var lines: PackedStringArray = CardText.tier_text(f, 1)
	eq(lines.size(), 3, "power, constant, and shield lines")
	eq(lines[0], "Power: Strike doing +3 Vigor. Gain 5 Vigor. If stopped, draw a card. May be used twice per Combat.", "every part of the Power")
	eq(lines[1], "Constant: Your first attack each Combat with a guild card cannot be stopped. Your opponent may not perform Arts.", "constants render")
	eq(lines[2], "Defense Shield: stops the first unstopped Strike each Combat.", "shield renders")
	var master: CardDef = CardDef.from_dict({"id": "m", "title": "M", "type": "master", "armory_size": 13, "uses_per_game": 2, "limit_per_deck": 1,
		"effects": [{"trigger": "master_use", "op": "forbid", "who": "opponent", "what": "mastery", "duration": "turn"}]})
	eq(CardText.rules_text(master), "Armory 13.\nTwice per game, during your Non-Combat step: Your opponent may not use a Mastery this turn.\nLimit 1 per deck.", "master text in reading order")
	var stiller: CardDef = CardDef.from_dict({"id": "s", "title": "S", "type": "combat", "defense": {"stops": "any", "stop_all": "any"}, "effects": [{"op": "stop_all", "kind": "any"}]})
	eq(CardText.rules_text(stiller).count("Stops all attacks"), 1, "a line already said by the defense is not repeated")
	for id in lib.all_ids():
		var text: String = CardText.rules_text(lib.get_def(id))
		check(not text.contains("_") and not text.contains("..") and not text.contains("  "), "clean text on %s: %s" % [id, text])


## Every keyword has a pattern that compiles, a role, and a tip, and the patterns find their words.
func test_keyword_table() -> void:
	var seen: Dictionary = {}
	for k in CardText.KEYWORDS:
		var key: String = str(k.get("key", ""))
		check(key != "" and not seen.has(key), "unique key: %s" % key)
		seen[key] = true
		check(str(k.get("role", "")) != "" and str(k.get("tip", "")).length() > 20, "role and tip on %s" % key)
		var r: RegEx = RegEx.new()
		eq(r.compile(str(k.get("pattern", ""))), OK, "pattern compiles for %s" % key)
		var phrase_only: Array[String] = ["Stops", "from the game", "Remain", "Hit", "tier", "cannot be prevented", "Cannot be stopped", "Signature", "Limit", "Constant"]
		check(r.search(key) != null or key in phrase_only, "pattern finds its own key: %s" % key)
	var r: RegEx = RegEx.new()
	r.compile(str(CardText.KEYWORDS[1]["pattern"]))
	check(r.search("Your opponent removes all Drills in play from the game.") != null, "removal phrase matches a generated sentence")
	r.compile(str(CardText.KEYWORDS[2]["pattern"]))
	check(r.search("Remain 1.") != null, "remain phrase matches")
	r.compile(str(CardText.KEYWORDS[3]["pattern"]))
	check(r.search("Hit: Raise your Acclaim 1.") != null, "hit label matches")


# --- Timing windows and outcome data ------------------------------------------

## A spent Fighter may hand the attack phase to an Ally; the Ally then performs the attack.
func test_attacker_ally_control() -> void:
	var e: DuelEngine = engine(deck(filler(["t_ally_squire", "t_strike", "t_strike"])), deck(filler(), "knave"))
	answer(e, &"place", uid_in_hand(e, 0, "t_ally_squire"))
	var ally: CardInstance = e.player(0).allies()[0]
	eq(prompt_kind(e), &"declare", "nothing else to place: at the Declare step")
	e.player(0).fighter.vigor = 1
	answer(e, &"declare")
	eq(prompt_kind(e), &"control", "the attacker chooses who is in control at Vigor 1")
	eq(e.prompt.player, 0, "it is the attacker's choice")
	eq(str(e.prompt.context.get("role", "")), "attacker", "context names the role")
	answer(e, &"control", ally.uid)
	eq(prompt_kind(e), &"attack_action", "then the attack phase")
	eq(e.player(0).in_control(), ally, "the Ally is in control")
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike"))
	eq(int(e.state.last_attack.get("performer", -1)), ally.uid, "the Ally performed the attack")
	eq(prompt_kind(e), &"attack_action", "the fight back follows")
	eq(e.prompt.player, 1, "the rival's phase, no control prompt at Vigor 5")


## A Non-Combat in play may stop an attack, and is spent by it like any other use.
func test_non_combat_defense_is_spent() -> void:
	var e: DuelEngine = engine(deck(filler(["t_strike", "t_strike", "t_strike"])), deck(filler(), "knave"))
	var block: CardInstance = inject(e, 1, "t_noncombat_parry")
	to_combat(e)
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike"))
	eq(prompt_kind(e), &"defense", "defense prompt")
	check(e.prompt.find(&"defend", block.uid) != null, "the Non-Combat in play is a legal defense")
	answer(e, &"defend", block.uid)
	check(has_event(e, &"attack_stopped"), "it stopped the Strike")
	eq(e.player(1).acclaim, 1, "its own effect resolved")
	eq(block.zone, &"discard", "and the card is spent")
	eq(e.player(1).non_combats().size(), 0, "no longer in play")


## After a Final Strike the player cannot defend either; the attack goes straight to the shields.
func test_no_defense_after_final_strike() -> void:
	var e: DuelEngine = engine(deck(filler(["t_taunt", "t_parry", "t_parry"])), deck(filler(["t_strike", "t_strike", "t_strike"]), "knave"))
	to_combat(e)
	answer(e, &"final_strike", uid_in_hand(e, 0, "t_taunt"))
	eq(prompt_kind(e), &"attack_action", "rival's fight back")
	eq(e.prompt.player, 1, "rival attacks")
	answer(e, &"attack", uid_in_hand(e, 1, "t_strike"))
	check(not has_event(e, &"defense_played"), "no Parry was offered or played")
	var reason: String = ""
	for ev in e.events:
		if ev.type == &"no_defense" and bool(ev.data.get("auto", false)):
			reason = str(ev.data.get("reason", ""))
	eq(reason, "final_strike", "the auto no-defense says why")
	check(has_event(e, &"attack_successful"), "the Strike went through")
	eq(prompt_kind(e), &"attack_action", "the rival attacks again after the forced pass")
	eq(e.prompt.player, 1, "same rival")


## A skipped attack phase never happened, so the passes around it are not consecutive.
func test_skipped_phase_does_not_end_combat() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(), "knave"))
	to_combat(e)
	e.player(1).skip_next_attack_phase = true
	answer(e, &"pass")
	check(has_event(e, &"attack_phase_skipped"), "the rival's phase was skipped")
	eq(prompt_kind(e), &"attack_action", "back to the active player")
	eq(e.prompt.player, 0, "same player again")
	answer(e, &"pass")
	check(not has_event(e, &"combat_end"), "two passes by one player around a skip do not end Combat")
	eq(e.prompt.player, 1, "the rival finally gets a phase")
	answer(e, &"pass")
	check(has_event(e, &"combat_end"), "consecutive passes end it")
	answer(e, &"keep", e.player(0).hand[0].uid)
	answer(e, &"keep", e.player(1).hand[0].uid)
	check(has_event(e, &"recover_step"), "the Recover step is announced even after Combat")
	eq(e.state.turn, 2, "and no card returns")


## A Master whose power is a Combat action is offered in place of an attack, not in the Non-Combat step.
func test_master_in_combat() -> void:
	var e: DuelEngine = engine(deck(filler(), "knight", "", "", 3, "tf_knight", "t_master_combat"), deck(filler(), "knave"))
	eq(prompt_kind(e), &"declare", "nothing to place and no Master offer in the Non-Combat step")
	answer(e, &"declare")
	var m: int = e.player(0).master.uid
	check(e.prompt.find(&"use", m) != null, "the Master is an attack-phase action")
	answer(e, &"use", m)
	eq(e.player(0).hand.size(), 5, "the Master drew two")
	check(has_event(e, &"master_used"), "master_used event")
	eq(prompt_kind(e), &"attack_action", "used in place of an attack: fight back")
	eq(e.prompt.player, 1, "the rival's phase")
	answer(e, &"pass")
	check(e.prompt.find(&"use", m) == null, "once per game")


## Battle step 11: an attacking Ally with the capture trait may take a Token instead of dealing damage.
func test_capture_instead_of_damage() -> void:
	var e: DuelEngine = engine(deck(filler(["t_ally_captor"])), deck(filler(), "knave"))
	answer(e, &"place", uid_in_hand(e, 0, "t_ally_captor"))
	var token: CardInstance = inject(e, 1, "t_token_1")
	to_combat(e)
	var al: CardInstance = e.player(0).allies()[0]
	var deck_before: int = e.player(1).life_deck.size()
	answer(e, &"power", al.uid)
	eq(prompt_kind(e), &"capture_instead", "the capturing Ally is asked")
	eq(e.prompt.player, 0, "by its owner")
	check(e.prompt.find(&"deal_damage") != null, "dealing the damage stays an option")
	answer(e, &"capture", token.uid)
	if prompt_kind(e) == &"pick_option":
		answer(e, &"pick_option", -1, "no")   # the captured Token's power is optional
	eq(e.player(0).tokens().size(), 1, "the Token changed hands")
	eq(e.player(1).fighter.vigor, 5, "no Vigor damage")
	eq(e.player(1).life_deck.size(), deck_before, "no wounds")
	check(has_event(e, &"capture_instead"), "capture_instead event")
	eq(prompt_kind(e), &"attack_action", "battle over")
	al.power_used_combat = -1   # Ally powers are once per Combat; reopen it to try the other branch
	inject(e, 1, "t_token_2")
	answer(e, &"pass")
	answer(e, &"power", al.uid)
	answer(e, &"deal_damage")
	eq(e.player(1).life_deck.size(), deck_before - 1, "the second time the Ally dealt its wound")


## The outcome of an attack outlives the attack in the view, on both seats and over the wire.
func test_last_attack_in_view() -> void:
	var e: DuelEngine = engine(deck(filler(["t_strike", "t_parry", "t_parry"])), deck(filler(["t_strike", "t_strike", "t_strike"]), "knave"))
	to_combat(e)
	eq(SeatView.of(e, 0).last_attack.size(), 0, "nothing yet")
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike"))
	var v1: SeatView = SeatView.of(e, 1)
	eq(v1.attack.size(), 0, "the attack itself has left the view")
	eq(str(v1.last_attack.get("source_title", "")), "Test Strike", "the rival's seat sees what hit")
	eq(bool(v1.last_attack.get("stopped", true)), false, "it landed")
	check(int(v1.last_attack.get("stages_dealt", 0)) > 0, "and how hard")
	eq(int(v1.last_attack.get("attacker", -1)), 0, "who attacked")
	answer(e, &"attack", uid_in_hand(e, 1, "t_strike"))
	eq(SeatView.of(e, 0).battle_step, 7, "the defense prompt sits at battle step 7 in the view")
	answer(e, &"defend", uid_in_hand(e, 0, "t_parry"))
	var v0: SeatView = SeatView.from_dict(SeatView.of(e, 0).to_dict())
	eq(bool(v0.last_attack.get("stopped", false)), true, "the second attack was stopped")
	eq(str(v0.last_attack.get("stopped_by_title", "")), "Test Parry", "by what, after the wire round trip")
	eq(int(v0.last_attack.get("attacker", -1)), 1, "and whose it was")
	answer(e, &"pass")
	answer(e, &"pass")
	eq(SeatView.of(e, 0).last_attack.size(), 0, "cleared when Combat ends")


## Log lines for the attack's end and Combat's start, and titles that name the card asking.
func test_outcome_lines_and_titles() -> void:
	var e: DuelEngine = engine(deck(filler(["t_strike", "t_parry", "t_taunt"])), deck(filler(["t_strike", "t_counter", "t_counter"]), "knave"))
	to_combat(e)
	var begin: String = ""
	for ev in e.events:
		if ev.type == &"combat_begin":
			begin = CardText.event_line(ev, e, 0)
	eq(begin, "Combat: Test knight attacks first.", "Combat opening line")
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike"))
	var lines: Array[String] = []
	for ev in e.events:
		if ev.type == &"attack_end":
			lines.append(CardText.event_line(ev, e, 1))
	eq(lines.size(), 1, "one attack_end line")
	check(lines[0].begins_with("Test knight's Test Strike lands for "), "landing line names the card and the damage: %s" % lines[0])
	answer(e, &"attack", uid_in_hand(e, 1, "t_strike"))
	answer(e, &"defend", uid_in_hand(e, 0, "t_parry"))
	lines.clear()
	for ev in e.events:
		if ev.type == &"attack_end":
			lines.append(CardText.event_line(ev, e, 0))
	eq(lines[lines.size() - 1], "Test knave's Test Strike is stopped by Test Parry.", "stopped line names the defense")
	answer(e, &"use", uid_in_hand(e, 0, "t_taunt"))
	eq(prompt_kind(e), &"respond", "counter window")
	eq(CardText.prompt_title(e.prompt), "Counter Test Taunt?", "the respond prompt names the card")
	eq(int(e.prompt.context.get("source", -1)), e.card(int(e.prompt.context["card"])).uid, "and carries it as the source")
	var ctrl: Prompt = Prompt.new()
	ctrl.kind = &"control"
	ctrl.context = {"role": "attacker"}
	eq(CardText.prompt_title(ctrl), "Who attacks? Your Fighter is spent", "attacker control title")
	var crit: Prompt = Prompt.new()
	crit.kind = &"critical"
	crit.context = {"life_dealt": 6}
	eq(CardText.prompt_title(crit), "Critical damage (6 wounds): choose one", "critical title carries the count")
	var pick: Prompt = Prompt.new()
	pick.kind = &"pick_option"
	pick.context = {"purpose": "capture", "card_title": "Test Thief"}
	eq(CardText.prompt_title(pick), "Test Thief: capture which Token?", "purpose-driven pick title")


## A constant power's keyed lists fire at their key: turn start, entering Combat, and each attack.
func test_constant_keyed_triggers() -> void:
	var e: DuelEngine = engine(deck(filler(), "knight", "", "", 3, "tf_grinder"), deck(filler(), "knave"))
	eq(e.player(0).acclaim, 1, "turn-start constant fired on turn 1")
	to_combat(e)
	eq(e.player(0).acclaim, 2, "entering-Combat constant fired for the active player")
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike"))
	eq(e.player(0).acclaim, 3, "on-attack constant fired with the Strike")
	answer(e, &"pass")
	answer(e, &"pass")
	skip_to_turn(e, 3)
	eq(e.player(0).acclaim, 4, "turn-start constant fired again on the owner's next turn, not the rival's")


## A Token's text (no trigger of its own) is its placement power; a captor may use it on capture.
func test_token_power_on_place_and_capture() -> void:
	var e: DuelEngine = engine(deck(filler(["t_token_plain"])), deck(filler(), "knave"))
	answer(e, &"place", uid_in_hand(e, 0, "t_token_plain"))
	eq(e.player(0).acclaim, 1, "the placed Token's power fired")
	eq(e.player(0).hand.size(), 3, "both lines of it (drew one after placing one)")
	var c: DuelEngine = engine(deck(filler(["t_strike_wound", "t_strike_wound", "t_strike_wound"])), deck(filler([], 20), "knave"))
	var t: CardInstance = inject(c, 1, "t_token_plain")
	to_combat(c)
	answer(c, &"attack", uid_in_hand(c, 0, "t_strike_wound"))
	eq(prompt_kind(c), &"critical", "five wounds: critical damage")
	answer(c, &"capture", t.uid)
	eq(t.controller, 0, "captured")
	eq(prompt_kind(c), &"pick_option", "the captor is asked about the Token's power")
	check(bool(c.prompt.context.get("may", false)), "as a may question")
	answer(c, &"pick_option", -1, "yes")
	eq(c.player(0).acclaim, 1, "the power resolved for the captor")
	eq(prompt_kind(c), &"attack_action", "and the battle went on")


## A Non-Combat used from play as an attack action does its effect once and is discarded.
func test_used_non_combat_is_spent() -> void:
	var e: DuelEngine = engine(deck(filler(["t_strike", "t_strike", "t_strike"])), deck(filler(), "knave"))
	var study: CardInstance = inject(e, 0, "t_noncombat_draw")
	to_combat(e)
	var hand_before: int = e.player(0).hand.size()
	check(e.prompt.find(&"use", study.uid) != null, "the Non-Combat in play can be used")
	answer(e, &"use", study.uid)
	eq(e.player(0).hand.size(), hand_before + 2, "its effect resolved")
	eq(study.zone, &"discard", "and the card is spent")
	eq(e.player(0).non_combats().size(), 0, "no longer in play")


# --- Simulation support ----------------------------------------------------

func shipped_engine(deck_a: String, deck_b: String, seed_value: int) -> DuelEngine:
	var lib: CardLibrary = CardLibrary.new()
	lib.load_dir("res://data/cards")
	var e: DuelEngine = DuelEngine.new()
	var pair: Array[DeckList] = [DeckList.load_from("res://data/decks/%s.json" % deck_a), DeckList.load_from("res://data/decks/%s.json" % deck_b)]
	e.setup(pair, lib, StrikeTable.load_from("res://data/strike_table.json"), seed_value)
	e.start()
	return e


func views_text(e: DuelEngine) -> String:
	return JSON.stringify([SeatView.of(e, 0).to_dict(), SeatView.of(e, 1).to_dict()])


## A clone taken at any prompt, fed the same commands, stays in step with the original. A fresh
## clone is taken every few steps so mid-effect and mid-attack positions are covered.
func test_clone_plays_identically() -> void:
	for pairing in [["ember_beatdown", "tide_companions"], ["shade_henchmen", "storm_volley"], ["freestyle_swords", "steel_beatdown"]]:
		var a: DuelEngine = shipped_engine(pairing[0], pairing[1], 11)
		var b: DuelEngine = a.clone()
		var picker: RandomNumberGenerator = RandomNumberGenerator.new()
		picker.seed = 5
		var steps: int = 0
		var drift: int = 0
		while not a.is_over() and steps < 4000:
			var i: int = picker.randi_range(0, a.prompt.options.size() - 1)
			if b.prompt == null or b.prompt.options.size() != a.prompt.options.size() or not b.prompt.options[i].matches(a.prompt.options[i]):
				drift += 1
				break
			b.submit(b.prompt.options[i])
			a.submit(a.prompt.options[i])
			steps += 1
			if steps % 7 == 0:
				if views_text(a) != views_text(b):
					drift += 1
					break
				b = a.clone()
		eq(drift, 0, "%s vs %s clone stayed in step for %d steps" % [pairing[0], pairing[1], steps])
		check(a.is_over(), "%s vs %s finished" % [pairing[0], pairing[1]])
		eq(views_text(b), views_text(a), "%s vs %s same end state" % [pairing[0], pairing[1]])


## Playing on a clone changes nothing in the engine it came from.
func test_clone_is_independent() -> void:
	var a: DuelEngine = shipped_engine("shade_henchmen", "tide_companions", 3)
	var picker: RandomNumberGenerator = RandomNumberGenerator.new()
	picker.seed = 9
	for n in range(60):
		if a.is_over():
			break
		a.submit(a.prompt.options[picker.randi_range(0, a.prompt.options.size() - 1)])
	var before: String = views_text(a)
	var b: DuelEngine = a.clone()
	var guard: int = 0
	while not b.is_over() and guard < 4000:
		guard += 1
		b.submit(b.prompt.options[picker.randi_range(0, b.prompt.options.size() - 1)])
	check(b.is_over(), "the clone played to the end")
	eq(views_text(a), before, "the original did not move")
	eq(a.events.size() > 0, true, "the original kept its events")


## Referee.sim_for: the seat's own view of the simulated engine is exactly its view of the real
## one, the hidden cards are the same cards in a new deal, and the deal changes with the seed.
func test_sim_for_hides_and_keeps() -> void:
	var lib: CardLibrary = CardLibrary.new()
	lib.load_dir("res://data/cards")
	var ref: Referee = Referee.new()
	var pair: Array[DeckList] = [DeckList.load_from("res://data/decks/ember_beatdown.json"), DeckList.load_from("res://data/decks/storm_volley.json")]
	ref.setup(pair, lib, StrikeTable.load_from("res://data/strike_table.json"), 21)
	ref.start()
	var picker: RandomNumberGenerator = RandomNumberGenerator.new()
	picker.seed = 4
	var compared: int = 0
	var hands_differ: int = 0
	var steps: int = 0
	while not ref.is_over() and steps < 300:
		steps += 1
		var seat: int = ref.engine.prompt.player
		if steps % 10 == 0:
			var sim: DuelEngine = ref.sim_for(seat, steps)
			eq(JSON.stringify(SeatView.of(sim, seat).to_dict()), JSON.stringify(ref.view_for(seat).to_dict()), "step %d: the seat sees the same table in the simulation" % steps)
			var foe: int = 1 - seat
			eq(hidden_titles(sim, foe), hidden_titles(ref.engine, foe), "step %d: the opponent's hidden cards are the same cards" % steps)
			var other: DuelEngine = ref.sim_for(seat, steps + 1000)
			if hand_titles(sim, foe) != hand_titles(ref.engine, foe) or hand_titles(other, foe) != hand_titles(ref.engine, foe):
				hands_differ += 1
			compared += 1
			var guard: int = 0
			while not sim.is_over() and guard < 4000:
				guard += 1
				sim.submit(sim.prompt.options[picker.randi_range(0, sim.prompt.options.size() - 1)])
			check(sim.is_over(), "step %d: the simulation plays to the end" % steps)
		var opts: Array[Command] = ref.engine.prompt.options
		ref.submit(seat, opts[picker.randi_range(0, opts.size() - 1)].to_dict())
	check(compared >= 5, "compared %d simulations" % compared)
	check(hands_differ >= compared / 2, "the opponent's hand was dealt again in %d of %d simulations" % [hands_differ, compared])


func hidden_titles(e: DuelEngine, owner: int) -> Array[String]:
	var out: Array[String] = []
	var p: PlayerState = e.player(owner)
	for list in [p.hand, p.life_deck, p.armory]:
		for c in list:
			out.append(c.def.id)
	out.sort()
	return out


func hand_titles(e: DuelEngine, owner: int) -> Array[String]:
	var out: Array[String] = []
	for c in e.player(owner).hand:
		out.append(c.def.id)
	return out


# --- AI ---------------------------------------------------------------------

func shipped_referee(deck_a: String, deck_b: String, seed_value: int) -> Referee:
	var lib: CardLibrary = CardLibrary.new()
	lib.load_dir("res://data/cards")
	var ref: Referee = Referee.new()
	var pair: Array[DeckList] = [DeckList.load_from("res://data/decks/%s.json" % deck_a), DeckList.load_from("res://data/decks/%s.json" % deck_b)]
	ref.setup(pair, lib, StrikeTable.load_from("res://data/strike_table.json"), seed_value)
	ref.start()
	return ref


## Two scorer AIs play every shipped deck to the end through the referee. The referee refuses
## anything that is not an option, so a finished game means every answer was legal.
func test_ai_answers_every_prompt() -> void:
	var kinds: Dictionary = {}
	var pairings: Array = [["ember_beatdown", "tide_companions"], ["shade_henchmen", "storm_volley"], ["freestyle_swords", "steel_beatdown"]]
	for pairing in pairings:
		var ref: Referee = shipped_referee(pairing[0], pairing[1], 31)
		var profile: AiProfile = AiProfile.default_profile()
		profile.merge({"think": {"search": false, "noise": 2.0}})
		var players: Array[AiPlayer] = [AiPlayer.new(profile, 1), AiPlayer.new(profile, 2)]
		var refused: String = ""
		var steps: int = 0
		while not ref.is_over() and steps < 4000 and refused == "":
			steps += 1
			var seat: int = ref.engine.prompt.player
			kinds[ref.engine.prompt.kind] = true
			if steps == 1:
				eq(players[1 - seat].choose(ref, 1 - seat).is_empty(), true, "the seat not deciding gets no answer")
			refused = ref.submit(seat, players[seat].choose(ref, seat))
			ref.engine.take_events()
		eq(refused, "", "%s vs %s: every AI answer was accepted" % [pairing[0], pairing[1]])
		check(ref.is_over(), "%s vs %s finished in %d steps" % [pairing[0], pairing[1], steps])
	for kind in [&"armory", &"non_combat", &"declare", &"attack_action", &"defense", &"keep"]:
		check(kinds.has(kind), "the AI met a %s prompt" % kind)


## The search weighs more than one option, leaves the real engine alone, and picks the same
## command again from the same seed.
func test_ai_search_reports_and_is_repeatable() -> void:
	var ref: Referee = shipped_referee("ember_beatdown", "steel_beatdown", 12)
	var quick: AiProfile = AiProfile.default_profile()
	quick.merge({"think": {"search": false}})
	var driver: AiPlayer = AiPlayer.new(quick, 3)
	var steps: int = 0
	while not ref.is_over() and steps < 400 and not (ref.engine.prompt.kind == &"attack_action" and ref.engine.prompt.options.size() > 3):
		steps += 1
		ref.submit(ref.engine.prompt.player, driver.choose(ref, ref.engine.prompt.player))
	eq(ref.engine.prompt.kind, &"attack_action", "reached an attack action with choices")
	var seat: int = ref.engine.prompt.player
	var before: String = views_text(ref.engine)
	var profile: AiProfile = AiProfile.default_profile()
	profile.merge({"think": {"samples": 3, "budget_ms": 60000}})
	var first: AiPlayer = AiPlayer.new(profile, 77)
	var second: AiPlayer = AiPlayer.new(profile, 77)
	var a: Dictionary = first.choose(ref, seat)
	var b: Dictionary = second.choose(ref, seat)
	eq(JSON.stringify(b), JSON.stringify(a), "same seed, same choice")
	check(first.search.last_report.size() >= 2, "the search compared %d options" % first.search.last_report.size())
	eq(int(first.search.last_report[0]["samples"]), 3, "every option met all three deals")
	eq(views_text(ref.engine), before, "thinking did not move the real duel")
	eq(ref.submit(seat, a), "", "the referee accepts the choice")


## Each win route moves the evaluation: fewer life cards is worse, Tokens and Favor are better,
## and a profile that ignores a route does not count it.
func test_ai_evaluator_routes() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(), "knave"))
	var profile: AiProfile = AiProfile.default_profile()
	var base: float = AiEvaluator.evaluate(e, 0, profile)
	var rival_base: float = AiEvaluator.evaluate(e, 1, profile)
	e.player(0).acclaim = 4
	var with_acclaim: float = AiEvaluator.evaluate(e, 0, profile)
	check(with_acclaim > base, "Acclaim toward the Favor win is worth something")
	e.player(0).acclaim = 0
	inject(e, 0, "t_token_1")
	var with_token: float = AiEvaluator.evaluate(e, 0, profile)
	check(with_token > base, "a Token in play is worth something")
	check(AiEvaluator.evaluate(e, 1, profile) < rival_base, "and the other seat sees it as a threat")
	var deaf: AiProfile = AiProfile.default_profile()
	deaf.merge({"own": {"token": 0.0}})
	eq(AiEvaluator.evaluate(e, 0, deaf), base, "a profile with no Token weight ignores it")
	var lost: CardInstance = e.player(0).life_deck.pop_back()
	e.player(0).removed.append(lost)
	check(AiEvaluator.evaluate(e, 0, profile) < with_token, "a lost life card is worse")
	e.state.winner = 1
	eq(AiEvaluator.evaluate(e, 0, profile), -AiEvaluator.WIN, "a lost duel is the floor")
	eq(AiEvaluator.evaluate(e, 1, profile), AiEvaluator.WIN, "a won duel is the ceiling")


func test_ai_profile_merge() -> void:
	var p: AiProfile = AiProfile.default_profile()
	p.merge({"name": "test", "own": {"token": 99.0}, "think": {"search": false}, "nonsense": {"x": 1}})
	eq(p.name, "test", "name taken")
	eq(p.w("own", "token"), 99.0, "the named weight changed")
	eq(p.w("own", "life"), float(AiProfile.DEFAULTS["own"]["life"]), "the rest kept their defaults")
	eq(p.searches(), false, "think knobs merge too")
	eq(AiProfile.default_profile().w("own", "token"), float(AiProfile.DEFAULTS["own"]["token"]), "a merge never writes to the defaults")
	for file in ["default", "easy", "hard"]:
		var loaded: AiProfile = AiProfile.load_from("res://data/ai/profiles/%s.json" % file)
		eq(loaded.name, file, "%s.json loads" % file)
