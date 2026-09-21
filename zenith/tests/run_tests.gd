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
		test_freestyle_mastery_searches_named_support_cards,
		test_setup_and_first_turn,
		test_surge_has_no_style_bonus,
		test_non_combat_placement,
		test_drill_school_lock,
		test_grounds_forces_skip_and_recover,
		test_strike_damage_and_fight_back,
		test_drill_and_mastery_modifiers,
		test_stage_overflow_to_life,
		test_art_cost_and_damage,
		test_parry_stops_strike,
		test_guard_cannot_stop_focused,
		test_shield_drill_once_per_combat,
		test_endurance,
		test_declined_endurance_is_announced,
		test_option_outcomes_preview_the_wounds,
		test_forecast_counts_energy_overflow_as_wounds,
		test_fervor_aspect_up,
		test_drill_guard_survives_aspect_change,
		test_shuffle_discard_takes_only_its_school,
		test_draw_discard_up_to,
		test_stopping_an_attack_is_remembered_and_forces_a_pass,
		test_search_then_runs_even_when_nothing_was_taken,
		test_place_from_hand_takes_drills_but_not_seals,
		test_bloodline_gates_on_the_personality_in_control,
		test_an_only_gate_can_name_a_side_or_a_person,
		test_a_card_can_read_the_bottom_of_the_discard_pile,
		test_a_life_card_can_buy_more_damage,
		test_a_bought_life_card_is_a_requirement_not_a_cost,
		test_a_keyword_can_be_lent_by_an_attachment,
		test_a_mastery_can_buy_wounds_off_with_the_discard_pile,
		test_a_hold_drains_them_at_the_start_of_each_of_their_phases,
		test_remain_can_count_the_aspect_and_read_either_of_two_cards,
		test_a_reveal_can_take_every_match_at_once,
		test_a_seal_can_turn_their_removal_into_a_discard,
		test_a_card_can_lock_out_what_would_drag_an_aspect_down,
		test_a_constant_can_read_the_keyword_on_the_card_it_boosts,
		test_a_constant_can_shift_the_strike_table_both_ways,
		test_a_power_can_buy_a_second_use_with_a_card_from_hand,
		test_grounds_can_read_the_gate_rather_than_the_keyword,
		test_an_attack_can_trade_its_own_damage_for_their_drills,
		test_a_ransom_spends_the_reserve_to_strip_a_drill,
		test_an_attachment_on_their_duelist_can_stop_them_preventing_damage,
		test_a_hand_attack_can_count_down_to_a_number_or_take_every_match,
		test_a_one_shot_stop_can_wait_for_the_kind_it_names,
		test_a_bloodline_can_be_lent_by_an_attachment,
		test_two_variants_of_one_character_are_one_person,
		test_a_modifier_can_outlast_the_card_that_made_it,
		test_a_duelist_power_can_swing_twice_in_one_combat,
		test_ally_guard_named_for_a_bloodline_covers_only_kin,
		test_bloodline_counts_only_its_own,
		test_deck_loss_guard,
		test_in_play_can_shuffle_into_the_deck,
		test_optional_start_in_play,
		test_search_to_attack_performs_it_now,
		test_end_of_combat_window,
		test_effects_can_target_by_combat_role,
		test_attack_cost_from_hand,
		test_shuffle_discard_from_bottom,
		test_recur_source_pays_with_a_signature_card,
		test_chosen_attach_host_and_discard_side,
		test_energy_all_and_chosen_personality,
		test_may_can_ask_the_opponent,
		test_remove_discard_choice,
		test_discard_in_play_any_side,
		test_power_not_refreshed_by_aspect_change,
		test_ascension_win_and_gating,
		test_pass_flow_discard_and_next_turn,
		test_discard_step_simultaneous,
		test_deck_out_loses,
		test_seal_bypass_and_instant_win,
		test_capture_and_pending_win,
		test_critical_damage_choices,
		test_final_strike_forces_pass,
		test_ally_control_and_redirect,
		test_ally_takes_control_when_the_opponent_uses_a_card,
		test_only_one_ally_takes_control_per_card,
		test_mastery_can_block_for_a_hand_card,
		test_end_combat_effect,
		test_blocked_energy_gain_is_reported,
		test_events_carry_the_state_they_fired_at,
		test_random_hand_discard,
		test_reserve_swap,
		test_reserve_swap_simultaneous,
		test_reserve_batch,
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
		test_seals_immune_unless_named,
		test_end_combat_card_is_no_defense,
		test_locked_out_drill_shuffles_back,
		test_look_at_rearrange,
		test_attachment_modifier,
		test_constant_power,
		test_relic_use,
		test_start_in_play,
		test_pay_stages,
		test_name_card,
		test_copied_attack,
		test_prevent_all_and_no_prevent,
		test_relic_shields,
		test_set_aspect,
		test_draw_until_and_draw_discard,
		test_search_to_play,
		test_attack_variants,
		test_owner_chooses_discard,
		test_stop_next,
		test_only_attacks,
		test_energy_without_overflow,
		test_use_in_attack_phase,
		test_may_prompt,
		test_pay_energy,
		test_look_at,
		test_search_choice,
		test_before_damage_skip,
		test_stops_needed,
		test_ally_power_without_control,
		test_life_per_opponent_seal,
		test_lonely_drill,
		test_unused_remain_returns,
		test_return_removed,
		test_last_searched_target,
		test_forbid_unless_energy,
		test_forced_combat_from_reserve,
		test_promoted_if_successful,
		test_draw_check_named,
		test_search_looks_through_the_deck,
		test_ai_weighs_grounds,
		test_attachment_limit_attached,
		test_attach_to_other_named_personality,
		test_draw_check_discard_and_else,
		test_mastery_on_attack_and_blocks_to_bottom,
		test_wound_trigger_at_fight_back,
		test_wound_trigger_at_turn_end,
		test_look_at_play_option,
		test_bond_and_unbond,
		test_search_by_effect,
		test_end_turn,
		test_declare_window,
		test_a_deck_that_never_attacks_still_declares_to_spend_what_it_carries,
		test_grounds_can_tax_one_kind_of_attack,
		test_a_restriction_can_last_one_attack_phase_not_the_whole_combat,
		test_a_profile_can_pivot_on_the_matchup,
		test_a_profile_can_pivot_on_where_the_duel_stands,
		test_a_forced_combat_skip_says_why,
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
		test_relic_in_combat,
		test_capture_instead_of_damage,
		test_last_attack_in_view,
		test_outcome_lines_and_titles,
		test_constant_keyed_triggers,
		test_seal_power_on_place_and_capture,
		test_used_non_combat_is_spent,
		test_discard_draw_check_and_otherwise,
		test_search_to_deck_and_from_hand,
		test_fervor_cap_seal_guard_and_kept_card,
		test_success_non_combat_and_set_seal_damage,
		test_root_deck_is_legal,
		test_card_zones_stay_consistent,
		test_clone_plays_identically,
		test_clone_is_independent,
		test_sim_for_hides_and_keeps,
		test_ai_answers_every_prompt,
		test_ai_search_reports_and_is_repeatable,
		test_ai_values_a_fusion_by_what_it_gains,
		test_duelist_constant_holds_while_an_ally_leads,
		test_ai_follows_a_tutor_chain,
		test_ai_evaluator_routes,
		test_ai_seal_guard_and_climb_grounds,
		test_attack_forecast_reports_energy_left,
		test_ai_reserve_swaps,
		test_archetype_label,
		test_ai_profile_merge,
		test_automaton_deck_is_legal,
		test_a_drill_can_pay_more_for_its_own_kind,
		test_a_keyword_count_reads_both_sides,
		test_a_drill_can_lock_allies_out,
		test_a_search_can_arrive_at_full_energy,
		test_energy_paid_can_buy_energy_damage,
		test_a_drill_can_raise_the_hand_limit,
		test_a_drill_answers_one_successful_attack_a_combat,
		test_no_modifiers_are_added_against_the_machine,
		test_a_power_can_read_another_card_by_title,
		test_a_card_can_answer_an_ascension_win,
		test_set_energy_can_reach_every_personality,
		test_a_search_can_stack_the_deck,
		test_beginning_of_turn_runs_for_both_players_when_the_card_says_so,
		test_an_attack_can_multiply_the_base_damage,
		test_a_card_can_stop_an_attack_that_already_succeeded,
		test_a_mastery_can_read_the_card_it_burns,
		test_a_power_can_check_whether_the_drawn_card_attacks,
		test_a_power_can_need_two_named_allies,
		test_energy_can_reach_any_personality_on_the_table,
		test_an_ally_can_block_for_one_named_personality,
		test_a_printed_limit_beats_the_signature_allowance,
		test_an_aspect_one_ally_is_legal_in_a_shallow_deck,
		test_profile_state_key_matches_the_seat_view,
		test_branch_margin_keeps_the_leader_and_drops_the_tail,
		test_search_merges_identical_moves_from_hand,
		test_a_profile_can_leave_prompt_kinds_to_the_scorer,
		test_an_ally_power_refreshes_each_combat,
		test_the_taller_ladder_wins_by_standing_above_it,
		test_an_adventure_run_round_trips_through_json_and_the_save,
		test_adventure_ladders_field_legal_opponents,
		test_an_adventure_offer_is_three_legal_cards_the_deck_can_run,
		test_the_stage_two_grant_raises_the_aspect_count,
		test_adventure_offers_follow_the_run_seed,
		test_an_adventure_pick_is_refused_when_it_was_not_offered,
		test_an_adventure_cut_is_refused_at_the_card_floor,
		test_adventure_starters_and_opponents_are_legal,
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


func deck(cards: Array[String], alignment: String = "vigil", style: String = "", mastery: String = "", aspects: int = 3, duelist: String = "tf_vigil", relic: String = "", reserve: Array[String] = []) -> DeckList:
	var d: DeckList = DeckList.new()
	d.relic_id = relic
	d.reserve = reserve.duplicate()
	d.name = "Test %s" % alignment
	d.duelist_id = duelist
	d.aspects = aspects
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


## Puts a fresh copy of `id` straight into a player's hand, for a card the opening draw may miss.
func to_hand(e: DuelEngine, player: int, id: String) -> CardInstance:
	var c: CardInstance = e._instance(lib.get_def(id), player, &"hand")
	e.player(player).hand.append(c)
	return c


## A card put straight into the Life Deck, where a search can reach it. `deck()` cards near the
## front are drawn into the opening hand instead, which a search of the deck cannot see.
func to_deck(e: DuelEngine, player: int, id: String) -> CardInstance:
	var c: CardInstance = e._instance(lib.get_def(id), player, &"life_deck")
	e.player(player).life_deck.append(c)
	return c


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
	eq(lib.get_def("tf_vigil").highest_aspect(), 3, "vigil aspects")
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
	var bad: DeckList = deck(["t_strike", "t_art"], "vigil", "pyre", "t_mastery_pyre")
	var bad_problems: Array[String] = DeckValidator.validate(bad, lib)
	check(bad_problems.size() >= 2, "small mixed-school deck rejected: %s" % ", ".join(bad_problems))


func test_freestyle_mastery_searches_named_support_cards() -> void:
	var shipped: CardLibrary = CardLibrary.new()
	shipped.load_dir("res://data/cards")
	for target_id in ["keepers_drill", "first_cut"]:
		var cards: Array[String] = []
		for i in range(30):
			cards.append("sword_lunge")
		var decks: Array[DeckList] = [deck(cards, "vigil", "freestyle", "freestyle_mastery", 3, "duelist_iota"), deck(cards, "pact", "", "", 3, "duelist_zeta")]
		var e: DuelEngine = DuelEngine.new()
		e.shuffle_decks = false
		e.setup(decks, shipped, StrikeTable.load_from("res://data/strike_table.json"), 5)
		e.start()
		# Pay with a named support card, then search for the other support type.
		var payment: CardInstance = e._instance(shipped.get_def("first_cut" if target_id == "keepers_drill" else "keepers_drill"), 0, &"hand")
		e.player(0).hand.append(payment)
		var target: CardInstance = e._instance(shipped.get_def(target_id), 0, &"life_deck")
		e.player(0).life_deck.append(target)
		var foreign: CardInstance = e._instance(shipped.get_def("vales_insight"), 0, &"life_deck")
		e.player(0).life_deck.append(foreign)
		to_combat(e)
		check(e.prompt != null and bool(e.prompt.context.get("may", false)), "Freestyle Mastery offers its entering-combat exchange")
		answer(e, &"pick_option", -1, "yes")
		eq(payment.zone, &"discard", "named support can pay the signature discard")
		check(e.prompt != null and bool(e.prompt.context.get("search", false)), "signature payment opens the search")
		if e.prompt == null or not bool(e.prompt.context.get("search", false)):
			continue
		check(e.prompt.find(&"pick_option", target.uid) != null, "search offers the Duelist's named %s" % target_id)
		check(e.prompt.find(&"pick_option", foreign.uid) == null, "another Duelist's named support is not this Duelist's signature")
		check(e.prompt.find(&"pick_option", e.player(0).life_deck[0].uid) == null, "generic cards are visible but cannot be selected as signatures")
		check(e.prompt.find(&"pick_none") != null, "signature search still allows taking nothing")
		var public_prompt: PromptView = PromptView.of(e.prompt, e)
		check(public_prompt.find(&"pick_option", target.uid) != null, "client receives a selectable support card")
		eq((e.prompt.context.get("library", []) as Array).size(), e.player(0).life_deck.size(), "search shows the whole Life Deck")
		answer(e, &"pick_option", target.uid)
		eq(target.zone, &"hand", "chosen signature support goes to hand, without requiring it to be playable now")
		check(not e.player(0).in_play.has(target), "search to hand never places the support automatically")


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
	var e: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
	eq(e.state.active, 0, "vigil goes first")
	eq(e.player(1).duelist.energy, 5, "opposing starts at 5")
	eq(e.player(0).hand.size(), 3, "active drew 3")
	eq(e.player(1).hand.size(), 0, "opposing has no opening hand")
	eq(prompt_kind(e), &"declare", "no placeables skips straight to declare")
	eq(e.player(0).duelist.energy, 8, "power up by surge 2 plus the flat Style bonus")


func test_surge_has_no_style_bonus() -> void:
	var e: DuelEngine = engine(deck(filler(), "vigil", "pyre", "t_mastery_pyre"), deck(filler(), "pact"))
	eq(e.player(0).duelist.energy, 8, "the Surge bonus is flat, the Mastery adds nothing on top")
	eq(e.player(0).style, "pyre", "the deck's Style reaches the player")


func test_non_combat_placement() -> void:
	var e: DuelEngine = engine(deck(filler(["t_drill_strike", "t_seal_1", "t_noncombat_draw"])), deck(filler(), "pact"))
	eq(prompt_kind(e), &"non_combat", "placement prompt")
	eq(e.prompt.options.size(), 4, "three placeables plus done")
	answer(e, &"place", uid_in_hand(e, 0, "t_drill_strike"))
	answer(e, &"place", uid_in_hand(e, 0, "t_seal_1"))
	eq(e.player(0).fervor, 1, "seal power resolved on placement")
	answer(e, &"place", uid_in_hand(e, 0, "t_noncombat_draw"))
	eq(e.player(0).drills().size(), 1, "drill in play")
	eq(e.player(0).seals().size(), 1, "seal in play")
	eq(e.player(0).non_combats().size(), 1, "non-combat in play")
	eq(prompt_kind(e), &"declare", "empty hand moves on to declare")


func test_drill_school_lock() -> void:
	var e: DuelEngine = engine(deck(filler(["t_drill_strike", "t_drill_shield", "t_drill_strike"])), deck(filler(), "pact"))
	answer(e, &"place", uid_in_hand(e, 0, "t_drill_strike"))
	var tide: int = uid_in_hand(e, 0, "t_drill_shield")
	check(e.prompt.find(&"place", tide) == null, "tide drill locked out by pyre drill")
	var dup: int = uid_in_hand(e, 0, "t_drill_strike")
	check(e.prompt.find(&"place", dup) == null, "duplicate styled drill locked out")


func test_grounds_forces_skip_and_recover() -> void:
	var e: DuelEngine = engine(deck(filler(["t_grounds", "t_strike", "t_strike"])), deck(filler(), "pact"))
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
	var e: DuelEngine = engine(deck(filler()), deck(filler(["t_art", "t_art", "t_art"]), "pact"))
	to_combat(e)
	eq(e.player(1).hand.size(), 3, "opposing drew 3 at combat")
	eq(prompt_kind(e), &"attack_action", "attack prompt")
	eq(e.prompt.player, 0, "active attacks first")
	var s: int = uid_in_hand(e, 0, "t_strike")
	answer(e, &"attack", s)
	eq(e.player(1).duelist.energy, 3, "energy 7 vs 5 deals 2 stages")
	eq(prompt_kind(e), &"attack_action", "fight back")
	eq(e.prompt.player, 1, "defender now attacks")
	eq(e.card(s).zone, &"discard", "strike discarded after use")


func test_drill_and_mastery_modifiers() -> void:
	var e: DuelEngine = engine(deck(filler(["t_drill_strike"]), "vigil", "pyre", "t_mastery_pyre"), deck(filler(["t_art", "t_art", "t_art", "t_art"]), "pact"))
	answer(e, &"place", uid_in_hand(e, 0, "t_drill_strike"))
	to_combat(e)
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike"))
	# energy 8 (surge 2 + 1) -> might 6.5M band F vs 4.0M band E = 2, +1 drill, +1 mastery
	eq(e.player(1).duelist.energy, 1, "drill and mastery add 2 stages")


func test_stage_overflow_to_life() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(["t_art", "t_art", "t_art"]), "pact"))
	to_combat(e)
	e.player(1).duelist.energy = 1
	var deck_before: int = e.player(1).life_deck.size()
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike"))
	# attacker 6.0M band F vs defender at energy 1 = 900k band C: 4 stages, 1 absorbed, 3 overflow
	eq(e.player(1).duelist.energy, 0, "energy floors at 0")
	eq(e.player(1).discard.size(), 3, "three stages overflowed to life cards")
	eq(e.player(1).life_deck.size(), deck_before - 3, "life deck shrank by three")


func test_art_cost_and_damage() -> void:
	var e: DuelEngine = engine(deck(filler(["t_art", "t_art", "t_art"])), deck(filler(), "pact"))
	to_combat(e)
	answer(e, &"attack", uid_in_hand(e, 0, "t_art"))
	eq(e.player(0).duelist.energy, 6, "art cost 2 energy from 8")
	eq(e.player(1).discard.size(), 4, "art dealt 4 wounds")
	e.player(0).duelist.energy = 1
	answer(e, &"pass")
	eq(e.prompt.player, 0, "back to the active player")
	check(e.prompt.find(&"attack", uid_in_hand(e, 0, "t_art")) == null, "cannot afford an art at energy 1")


func test_parry_stops_strike() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(["t_parry", "t_parry", "t_parry"]), "pact"))
	to_combat(e)
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike"))
	eq(prompt_kind(e), &"defense", "defense prompt")
	var parry: int = uid_in_hand(e, 1, "t_parry")
	answer(e, &"defend", parry)
	check(has_event(e, &"attack_stopped"), "attack stopped")
	eq(e.player(1).duelist.energy, 5, "no damage")
	eq(e.card(parry).zone, &"discard", "parry discarded")


func test_guard_cannot_stop_focused() -> void:
	var e: DuelEngine = engine(deck(filler(["t_strike_focused", "t_strike_focused", "t_strike_focused"])), deck(filler(["t_guard", "t_guard", "t_guard"]), "pact"))
	to_combat(e)
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike_focused"))
	eq(prompt_kind(e), &"attack_action", "no defense possible, straight to fight back")
	eq(e.player(1).duelist.energy, 3, "focused strike landed")


func test_shield_drill_once_per_combat() -> void:
	var e: DuelEngine = engine(deck(filler(["t_art", "t_art", "t_art"])), deck(filler(), "pact"))
	inject(e, 1, "t_drill_shield")
	to_combat(e)
	answer(e, &"attack", uid_in_hand(e, 0, "t_art"))
	check(has_event(e, &"shield"), "shield fired")
	eq(e.player(1).discard.size(), 0, "shield stopped the art")
	answer(e, &"pass")
	answer(e, &"attack", uid_in_hand(e, 0, "t_art"))
	eq(e.player(1).discard.size(), 4, "second art in the same combat gets through")


func test_endurance() -> void:
	var e: DuelEngine = engine(deck(filler(["t_art", "t_art", "t_art"])), deck(filler(["t_parry", "t_parry", "t_parry", "t_strike_endure"]), "pact", "tide", "t_mastery_tide"))
	to_combat(e)
	answer(e, &"attack", uid_in_hand(e, 0, "t_art"))
	eq(prompt_kind(e), &"endurance", "endurance prompt on the flipped card")
	answer(e, &"endure")
	eq(e.player(1).removed.size(), 1, "endurance card removed from game")
	eq(e.player(1).discard.size(), 1, "endurance 2 left one more wound")
	eq(prompt_kind(e), &"attack_action", "battle finished")


## Both seats watch the Endurance choice being offered, so turning it down has to be an outcome
## they can see rather than silence.
func test_declined_endurance_is_announced() -> void:
	var e: DuelEngine = engine(deck(filler(["t_art", "t_art", "t_art"])), deck(filler(["t_parry", "t_parry", "t_parry", "t_strike_endure"]), "pact", "tide", "t_mastery_tide"))
	to_combat(e)
	answer(e, &"attack", uid_in_hand(e, 0, "t_art"))
	eq(prompt_kind(e), &"endurance", "endurance prompt on the flipped card")
	var pending: Prompt = e.prompt
	check(int(pending.context.get("remaining", 0)) > 0, "the prompt says how many wounds are still coming")
	check(int(pending.context.get("endurance", 0)) > 0, "and how many the card could prevent")
	e.events.clear()
	answer(e, &"no_endure")
	check(has_event(e, &"endurance_declined"), "declining says so")
	check(not has_event(e, &"endurance_used"), "and claims no prevention")
	eq(e.player(1).removed.size(), 0, "the card stays in the discard pile")


## Each option of a damage decision carries what it would leave, so the client previews the
## number rather than working the rules out for itself.
func test_option_outcomes_preview_the_wounds() -> void:
	var e: DuelEngine = engine(deck(filler(["t_art", "t_art", "t_art"])), deck(filler(["t_parry", "t_parry", "t_parry", "t_strike_endure"]), "pact", "tide", "t_mastery_tide"))
	to_combat(e)
	answer(e, &"attack", uid_in_hand(e, 0, "t_art"))
	eq(prompt_kind(e), &"endurance", "endurance prompt on the flipped card")
	var p: PromptView = PromptView.of(e.prompt, e)
	var endure: OptionView = p.find(&"endure")
	var decline: OptionView = p.find(&"no_endure")
	check(endure != null and decline != null, "both answers are offered")
	var remaining: int = int(e.state.attack["life_remaining"])
	eq(int(decline.outcome["life"]), remaining, "declining leaves every wound still coming")
	var prevents: int = mini(int(e.prompt.context["endurance"]), remaining)
	eq(int(endure.outcome["life"]), remaining - prevents, "enduring takes that many off")
	check(int(endure.outcome["life"]) < int(decline.outcome["life"]), "so the preview is worth showing")
	# The wire carries it, since the joiner previews from the same data.
	eq(int(OptionView.from_dict(endure.to_dict()).outcome["life"]), int(endure.outcome["life"]), "outcome survives the round trip")


## Energy past what the target is standing on becomes wounds. The deal path has always done
## this; the forecast has to say the same, or a Strike that will cost life cards reads as
## costing none and the client leads with a zero.
func test_forecast_counts_energy_overflow_as_wounds() -> void:
	# The defender holds a stop, so the sequence pauses on their prompt with the attack in the
	# air and the forecast on show.
	var e: DuelEngine = engine(deck(filler()), deck(filler(["t_parry", "t_parry", "t_parry"]), "pact", "tide", "t_mastery_tide"))
	to_combat(e)
	e.player(1).duelist.energy = 1
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike"))
	var a: Dictionary = e.state.attack
	check(not a.is_empty(), "an attack is in the air")
	if a.is_empty():
		return
	var d: Dictionary = e.damage_breakdown(a)
	var stages: int = int(d["stages"])
	check(stages > 1, "the Strike is bigger than the single Energy the target holds")
	eq(int(d["overflow"]), stages - 1, "everything past that one Energy overflows")
	eq(int(d["wounds"]), int(d["life"]) + stages - 1, "and the wound total counts it")
	# The defender's own preview must agree, so the big number matches what lands.
	if prompt_kind(e) == &"defense":
		var p: PromptView = PromptView.of(e.prompt, e)
		var take: OptionView = p.find(&"no_defense")
		check(take != null, "taking the hit is offered")
		if take != null:
			eq(int(take.outcome["life"]), int(d["wounds"]), "taking it costs the whole wound total")


func test_fervor_aspect_up() -> void:
	var e: DuelEngine = engine(deck(filler(["t_drill_strike", "t_taunt", "t_strike"])), deck(filler(), "pact"))
	answer(e, &"place", uid_in_hand(e, 0, "t_drill_strike"))
	to_combat(e)
	e.player(0).fervor = 4
	answer(e, &"use", uid_in_hand(e, 0, "t_taunt"))
	eq(e.player(0).duelist.aspect, 2, "aspect up at 5 fervor")
	eq(e.player(0).duelist.energy, 10, "energy to full on aspect up")
	eq(e.player(0).fervor, 0, "fervor reset, no carry-over")
	eq(e.player(0).drills().size(), 0, "drills discarded on aspect up")
	check(not e.is_over(), "aspect 2 of 3 is not a win")


## "Draw up to N cards from the bottom of your discard pile": the pile settles which cards, so only
## the count is asked, and drawing none is allowed.
func test_draw_discard_up_to() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
	var p: PlayerState = e.player(0)
	for i in range(5):
		p.discard.append(e._instance(lib.get_def("t_strike"), 0, &"discard"))
	var hand_before: int = p.hand.size()
	e._apply_effect({"op": "draw_discard", "amount": 3, "from": "bottom", "up_to": true}, 0, {}, null)
	check(e.prompt != null and e.prompt.kind == &"pick_option", "the count is asked for")
	eq(e.prompt.options.size(), 4, "three counts and a none")
	check(e.prompt.find(&"pick_none") != null, "drawing none is allowed")
	e.submit(Command.new(0, &"pick_option", -1, "2"))
	eq(p.hand.size(), hand_before + 2, "only the chosen number is drawn")
	eq(p.discard.size(), 3, "and the rest stay in the pile")
	# A pile shorter than the card asks for offers only what is there.
	e.prompt = null
	e._apply_effect({"op": "draw_discard", "amount": 9, "from": "bottom", "up_to": true}, 0, {}, null)
	eq(e.prompt.options.size(), 4, "three cards left means three counts and a none")
	e.submit(e.prompt.find(&"pick_none"))
	eq(p.discard.size(), 3, "a refusal draws nothing")
	# Without `up_to` it still takes the lot, which is what every other card that reads it wants.
	e.prompt = null
	e._apply_effect({"op": "draw_discard", "amount": 2, "from": "bottom"}, 0, {}, null)
	check(e.prompt == null or e.prompt.kind != &"pick_option", "no count is asked")
	eq(p.discard.size(), 1, "and two came straight out")


## "If you stopped an opponent's attack during his previous attack phase, your opponent must pass
## during his next attack phase." Two rules: the condition is about a block you made, not about
## your own attack being stopped, and a forced pass is a pass, so it counts toward ending Combat.
func test_stopping_an_attack_is_remembered_and_forces_a_pass() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(["t_parry"]), "pact"))
	var them: PlayerState = e.player(1)
	check(not them.stopped_last_phase and not them.stopped_this_phase, "nobody has stopped anything yet")
	to_combat(e)
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike"))
	answer(e, &"defend", uid_in_hand(e, 1, "t_parry"))
	# The block lands in the attacker's phase; by the time the defender is the attacker, the
	# record has rolled forward, which is what "his previous attack phase" means.
	eq(e.state.attacker, them.index, "the phase handed over to the player who blocked")
	check(them.stopped_last_phase, "and their block is remembered as last phase's")
	check(not them.stopped_this_phase, "the running record is clear again")
	check(not e.player(0).stopped_last_phase, "the attacker stopped nothing")
	# A forced pass is a real pass: it counts toward the two consecutive passes that end Combat.
	var f: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
	to_combat(f)
	var defender: PlayerState = f.player(1 - f.state.attacker)
	defender.pass_next_phase = true
	answer(f, &"pass")
	check(not defender.pass_next_phase, "the forced pass was spent")
	eq(f.state.step, GameState.Step.DISCARD, "two passes in a row ended Combat")


## "After a successful energy attack, pick a Dragon Ball out of your deck and capture a Dragon Ball
## from the damaged foe." Two things under one yes, not one conditional on the other: with no Seal
## left to fetch, the capture still happens.
func test_search_then_runs_even_when_nothing_was_taken() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
	var theirs: CardInstance = inject(e, 1, "t_seal_2")
	eq(theirs.controller, 1, "the rival holds a Seal")
	var fetch: Dictionary = {"op": "search", "card_type": "seal", "to": "play", "then": [{"op": "capture_seal"}]}
	e.prompt = null
	e._enqueue([fetch], "secondary", 0, {}, null)
	e._drain()
	check(e.prompt != null and bool(e.prompt.context.get("search", false)), "the deck is searched")
	e.submit(e.prompt.find(&"pick_none"))
	eq(e.player(0).seals().size(), 1, "taking nothing from the deck still captured theirs")
	eq(theirs.controller, 0, "and it is the rival's Seal that moved")


## "In place of an attack, you may place in play a Non-Combat card from your hand." A Drill is a
## Non-Combat card and a Seal is not, so the Seal in hand is never on the list.
func test_place_from_hand_takes_drills_but_not_seals() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
	var p: PlayerState = e.player(0)
	var drill: CardInstance = to_hand(e, 0, "t_drill_strike")
	var seal: CardInstance = to_hand(e, 0, "t_seal_1")
	var study: CardInstance = to_hand(e, 0, "t_noncombat_draw")
	e._apply_effect({"op": "search", "source": "hand", "card_type": "non_combat_or_drill", "to": "play"}, 0, {}, null)
	check(e.prompt != null, "the hand is offered")
	var offered: Array[int] = e.prompt.card_options()
	check(offered.has(drill.uid), "the Drill is on the list")
	check(offered.has(study.uid), "so is the Non-Combat")
	check(not offered.has(seal.uid), "the Seal is not")
	e.submit(e.prompt.find(&"pick_none"))
	eq(p.seals().size(), 0, "and nothing was placed")


## A bloodline is inherited, so it sits on the personality, not on the player. A "Draconic only"
## card asks who is in control of Combat: a duelist without the blood cannot use it, but an Ally
## who has it can, which is how the source card works for a leader whose kin carry the line.
func test_bloodline_gates_on_the_personality_in_control() -> void:
	var e: DuelEngine = engine(deck(filler(["t_ally_kin", "t_kin_rite"])), deck(filler(), "pact"))
	answer(e, &"place", uid_in_hand(e, 0, "t_ally_kin"))
	var kin: CardInstance = e.player(0).allies()[0]
	eq(kin.def.bloodline, "draconic", "the Ally carries the line")
	eq(e.player(0).duelist.def.bloodline, "", "the duelist does not")
	var rite: int = uid_in_hand(e, 0, "t_kin_rite")
	answer(e, &"declare")
	check(e.prompt.find(&"use", rite) == null, "with the duelist in control the rite cannot be used")
	var f: DuelEngine = engine(deck(filler(["t_ally_kin", "t_kin_rite"])), deck(filler(), "pact"))
	answer(f, &"place", uid_in_hand(f, 0, "t_ally_kin"))
	kin = f.player(0).allies()[0]
	f.player(0).duelist.energy = 1
	answer(f, &"declare")
	answer(f, &"control", kin.uid)
	check(f.prompt.find(&"use", uid_in_hand(f, 0, "t_kin_rite")) != null, "with the kin in control it can")


## A guard that names a bloodline shields only the Allies carrying it. The duelist need not carry
## it herself, which is the whole point: she guards her kin, not every hireling she happens to
## lead. A guard with no bloodline named still covers everyone.
func test_ally_guard_named_for_a_bloodline_covers_only_kin() -> void:
	var e: DuelEngine = engine(deck(filler(), "vigil", "", "", 3, "tf_kinwarden"), deck(filler(), "pact"))
	var me: PlayerState = e.player(0)
	eq(me.duelist.def.bloodline, "", "the warden carries no line of her own")
	var kin: CardInstance = inject(e, 0, "t_ally_kin")
	var hireling: CardInstance = inject(e, 0, "t_ally_squire")
	check(e._ally_protected(me, kin), "the kin is guarded")
	check(not e._ally_protected(me, hireling), "the hireling of no line is not")

	var open_guard: DuelEngine = engine(deck(filler(), "vigil", "", "", 3, "tf_warden"), deck(filler(), "pact"))
	check(open_guard._ally_protected(open_guard.player(0), inject(open_guard, 0, "t_ally_squire")),
		"a guard that names no line still covers a hireling")


## "For each personality with that blood you have in play." The duelist counts only when the blood
## is theirs, so a leader of another line adds nothing while their kin each add one.
func test_bloodline_counts_only_its_own() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
	var p: PlayerState = e.player(0)
	eq(e.bloodline_count(p, "draconic"), 0, "a duelist of no line counts nobody")
	inject(e, 0, "t_ally_kin")
	inject(e, 0, "t_ally_squire")
	eq(e.bloodline_count(p, "draconic"), 1, "only the Ally with the line counts")
	eq(e.bloodline_count(p, "verdant"), 0, "and not for another line")
	e.shuffle_decks = false
	for i in range(4):
		p.discard.append(e._instance(lib.get_def("t_strike"), 0, &"discard"))
	var deck_before: int = p.life_deck.size()
	e._apply_effect({"op": "shuffle_discard", "amount": 1, "per_bloodline": "draconic"}, 0, {}, null)
	eq(p.life_deck.size(), deck_before + 1, "one card back for the one kin in play")


## "When your opponent uses a card effect besides damage that makes you discard the top cards of
## your Life Deck, you may discard this card from your hand to reduce the amount by 10, to a
## minimum of 0." The offer goes to the player losing the cards, before any of them turn over.
func test_deck_loss_guard() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
	to_hand(e, 1, "t_last_ward")
	var foe: PlayerState = e.player(1)
	var deck_before: int = foe.life_deck.size()
	e._apply_effect({"op": "discard_life", "who": "opponent", "amount": 4}, 0, {}, null)
	check(e.prompt != null and e.prompt.kind == &"pick_option", "the loser is asked")
	eq(e.prompt.player, 1, "and it is their choice, not the attacker's")
	eq(foe.life_deck.size(), deck_before, "nothing has left the deck yet")
	var guard: Command = e.prompt.options[0]
	e.submit(guard)
	eq(foe.life_deck.size(), deck_before, "4 reduced by 10 is none at all")
	eq(uid_in_hand(e, 1, "t_last_ward"), -1, "the guard was discarded to pay for it")
	# Declining takes the cards, and the guard stays in hand.
	var f: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
	to_hand(f, 1, "t_last_ward")
	var other: PlayerState = f.player(1)
	var before: int = other.life_deck.size()
	f._apply_effect({"op": "discard_life", "who": "opponent", "amount": 4}, 0, {}, null)
	f.submit(f.prompt.find(&"pick_none"))
	eq(other.life_deck.size(), before - 4, "all four came off")
	check(uid_in_hand(f, 1, "t_last_ward") >= 0, "and the guard is still in hand")
	# Your own effect is not "your opponent's", so it is never offered.
	var g: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
	to_hand(g, 0, "t_last_ward")
	var mine: PlayerState = g.player(0)
	var own: int = mine.life_deck.size()
	g._apply_effect({"op": "discard_life", "amount": 2}, 0, {}, null)
	eq(mine.life_deck.size(), own - 2, "a cost you pay yourself is not guarded")


## "Shuffle all of your opponent's Dragon Balls back into his Life Deck" takes them off the table
## without discarding them, which matters because the discard pile is a resource.
func test_in_play_can_shuffle_into_the_deck() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
	var foe: PlayerState = e.player(1)
	var seal: CardInstance = inject(e, 1, "t_seal_1")
	var deck_before: int = foe.life_deck.size()
	e.shuffle_decks = false
	e._apply_effect({"op": "discard_in_play", "who": "opponent", "card_type": "seal", "to": "deck_shuffle", "all": true}, 0, {}, null)
	eq(seal.zone, &"life_deck", "the Seal went back into the Life Deck")
	eq(foe.life_deck.size(), deck_before + 1, "the deck grew by it")
	eq(foe.discard.size(), 0, "and nothing reached the discard pile")


## "Before the first turn begins, you may search your Life Deck for this Drill and place it into
## play." It is an offer, not an automatic placement, so the game opens by asking.
func test_optional_start_in_play() -> void:
	var e: DuelEngine = engine(deck(filler(["t_drill_setup"])), deck(filler(), "pact"))
	eq(prompt_kind(e), &"start_play", "the offer comes before the first turn")
	eq(e.prompt.player, e.state.active, "the active player is asked first")
	eq(e.player(0).drills().size(), 0, "and nothing is on the table until they say so")
	answer(e, &"done")
	eq(e.player(0).drills().size(), 0, "declining leaves the Drill in the Life Deck")
	eq(e.state.turn, 1, "and the first turn begins")
	var f: DuelEngine = engine(deck(filler(["t_drill_setup"])), deck(filler(), "pact"))
	var offered: int = f.prompt.options[0].card
	answer(f, &"place", offered)
	eq(f.player(0).drills().size(), 1, "accepting puts it into play")
	eq(f.state.turn, 1, "with no second offer, the first turn begins")


## "Search your Reserve for a card that performs an attack and play it during this attack phase."
## The fetched card is performed now rather than going to hand for later.
func test_search_to_attack_performs_it_now() -> void:
	var e: DuelEngine = engine(deck(filler(["t_call_to_arms"]), "vigil", "", "", 3, "tf_vigil", "", ["t_art"]), deck(filler(), "pact"))
	answer(e, &"reserve_done")
	var fetcher: int = uid_in_hand(e, 0, "t_call_to_arms")
	to_combat(e)
	answer(e, &"use", fetcher)
	eq(prompt_kind(e), &"pick_option", "the Reserve is searched")
	check(bool(e.prompt.context.get("search", false)), "and the prompt is that search")
	e.submit(e.prompt.options[0])
	eq(uid_in_hand(e, 0, "t_art"), -1, "it never waited in hand")
	eq(e.player(0).attack_count_combat, 1, "the fetched card was performed as this phase's attack")
	check(has_event(e, &"attack_declared"), "an attack really started")


## "Use at the end of Combat." Combat is over once both players pass, but the CRD gives that moment
## its own window: the player whose turn it is resolves their end-of-Combat effects first, then the
## opponent. A card that names that timing is not offered during the attack phase.
func test_end_of_combat_window() -> void:
	var e: DuelEngine = engine(deck(filler(["t_aftermath"])), deck(filler(), "pact"))
	var after: CardInstance = e.player(0).hand[0]
	for c in e.player(0).hand:
		if c.def.id == "t_aftermath":
			after = c
	var drill: CardInstance = inject(e, 1, "t_drill_aftermath")
	to_combat(e)
	eq(prompt_kind(e), &"attack_action", "the attacker is asked for an attack")
	check(e.prompt.find(&"use", after.uid) == null, "a card that reads 'at the end of Combat' is not an attack-phase action")
	var opp_hand: int = e.player(1).hand.size()
	var fervor: int = e.player(0).fervor
	answer(e, &"pass")
	answer(e, &"pass")
	eq(prompt_kind(e), &"combat_end", "both passing opens the end-of-Combat window")
	eq(e.prompt.player, e.state.active, "and the active player goes first")
	eq(e.player(1).hand.size(), opp_hand + 1, "a Drill's end-of-Combat trigger already fired")
	answer(e, &"use", after.uid)
	eq(e.player(0).fervor, fervor + 2, "the card resolved")
	eq(after.zone, &"discard", "and was spent")
	eq(e.state.step, GameState.Step.DISCARD, "with nothing left for either player to use, Combat ends")
	eq(drill.zone, &"in_play", "the Drill stayed in play")


## "The attacker draws 2 cards from his discard pile. The defender raises 5 stages." A Combat card
## either player may use, so its two halves read by Combat role, not by who owns the card.
func test_effects_can_target_by_combat_role() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
	e.state.attacker = 1
	eq(e._who_index("attacker", 0), 1, "the attacker is the attacker whoever played the card")
	eq(e._who_index("defender", 0), 0, "and so is the defender")
	eq(e._who_index("self", 0), 0, "self and opponent still read from the owner")
	eq(e._who_index("opponent", 0), 1, "the other way round")
	var att: PlayerState = e.player(1)
	for i in range(3):
		att.discard.append(e._instance(lib.get_def("t_strike"), 1, &"discard"))
	var hand_before: int = att.hand.size()
	att.duelist.energy = 0
	e.player(0).duelist.energy = 0
	e._apply_effect({"op": "draw_discard", "who": "attacker", "amount": 2, "from": "top"}, 0, {}, null)
	e._apply_effect({"op": "energy", "who": "defender", "amount": 5}, 0, {}, null)
	eq(att.hand.size(), hand_before + 2, "the attacker drew, though the defender played the card")
	eq(e.player(0).duelist.energy, 5, "and the defender took the Energy")
	eq(att.duelist.energy, 0, "the attacker got none")


## "You may discard a card from your hand to perform a physical attack": a cost, so the power is
## not offered with an empty hand and the card goes before the attack rather than after it.
func test_attack_cost_from_hand() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
	var p: PlayerState = e.player(0)
	var spec: Dictionary = {"kind": "strike", "life": 2, "cost_hand": 1}
	check(e._can_pay(p.duelist, p, spec), "with cards in hand the attack is payable")
	var held: Array[CardInstance] = p.hand.duplicate()
	for c in held:
		p.hand.erase(c)
		c.zone = &"life_deck"
		p.life_deck.append(c)
	check(not e._can_pay(p.duelist, p, spec), "with an empty hand it is not")
	check(e._can_pay(p.duelist, p, {"kind": "strike", "life": 2}), "an attack with no hand cost still is")


## "Shuffle the bottom 3 cards of your discard pile into your Life Deck" takes them from the
## bottom, which is the front of the pile, not the cards just discarded.
func test_shuffle_discard_from_bottom() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
	e.shuffle_decks = false
	var p: PlayerState = e.player(0)
	var order: Array[CardInstance] = []
	for i in range(5):
		var c: CardInstance = e._instance(lib.get_def("t_strike"), 0, &"discard")
		p.discard.append(c)
		order.append(c)
	e._shuffle_discard_into_deck(p, 2, false, "bottom")
	eq(order[0].zone, &"life_deck", "the oldest card went back")
	eq(order[1].zone, &"life_deck", "and the one above it")
	eq(order[4].zone, &"discard", "the newest card stayed in the pile")
	e._shuffle_discard_into_deck(p, 1, false, "top")
	eq(order[4].zone, &"life_deck", "from the top it is the newest that goes back")


## "Remove a Signature card from your discard pile to shuffle this card into your Life Deck."
## Signature is our name for a card titled after the duelist, which is the rule the source card
## uses, so the cost only takes those and does nothing when there are none.
func test_recur_source_pays_with_a_signature_card() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
	var p: PlayerState = e.player(0)
	var spent: CardInstance = e._instance(lib.get_def("t_taunt"), 0, &"discard")
	p.discard.append(spent)
	var plain: CardInstance = e._instance(lib.get_def("t_strike"), 0, &"discard")
	p.discard.append(plain)
	var deck_before: int = p.life_deck.size()
	e._apply_effect({"op": "recur_source", "cost": {"signature_of": "duelist"}}, 0, {}, spent)
	eq(p.life_deck.size(), deck_before, "with no Signature card in the pile, nothing happens")
	eq(spent.zone, &"discard", "and the card stays where it was")
	var signature: CardInstance = e._instance(lib.get_def("t_vigil_ray"), 0, &"discard")
	p.discard.append(signature)
	e._apply_effect({"op": "recur_source", "cost": {"signature_of": "duelist"}}, 0, {}, spent)
	eq(signature.zone, &"removed", "the Signature card pays the cost")
	eq(spent.zone, &"life_deck", "and the card that asked goes back into the Life Deck")
	eq(plain.zone, &"discard", "the card with no character on it was never a candidate")


## "Attach this card to one of your personalities" asks which, and the attachment only helps while
## that personality is the one attacking. "Choose a player and remove his discard pile" asks whose.
func test_chosen_attach_host_and_discard_side() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
	var p: PlayerState = e.player(0)
	var ally: CardInstance = inject(e, 0, "t_ally_squire")
	var curse: CardInstance = e._instance(lib.get_def("t_strike"), 0, &"resolving")
	e._apply_effect({"op": "attach", "to": "choose"}, 0, {}, curse)
	check(e.prompt != null and e.prompt.kind == &"pick_option", "the host is asked for")
	eq(e.prompt.card_options().size(), 2, "the duelist and the Ally are both offered")
	e.submit(Command.new(0, &"pick_option", ally.uid))
	eq(curse.attached_to, ally, "it lands on the personality that was picked")
	# With only the duelist there is nobody to pick between, so it attaches without asking.
	p.in_play.erase(ally)
	var second: CardInstance = e._instance(lib.get_def("t_strike"), 0, &"resolving")
	e._apply_effect({"op": "attach", "to": "choose"}, 0, {}, second)
	eq(second.attached_to, p.duelist, "and with no Ally it goes straight to the duelist")
	e.player(1).discard.append(e._instance(lib.get_def("t_strike"), 1, &"discard"))
	p.discard.append(e._instance(lib.get_def("t_strike"), 0, &"discard"))
	e.prompt = null
	e._enqueue([{"op": "remove_discard", "who": "opponent", "choose_player": true, "all": true}], "secondary", 0, {}, null)
	e._drain()
	check(e.prompt != null and e.prompt.kind == &"pick_option", "the pile is asked for")
	eq(e.prompt.options.size(), 2, "either player's pile may go")
	e.submit(Command.new(0, &"pick_option", -1, "self"))
	eq(p.discard.size(), 0, "picking yourself burns your own pile")
	eq(e.player(1).discard.size(), 1, "and leaves theirs alone")


## "Raise all of your personalities" lifts the Duelist and every Ally; "raise any of them" asks,
## unless the Duelist is the only one there to pick.
func test_energy_all_and_chosen_personality() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
	var p: PlayerState = e.player(0)
	var ally: CardInstance = inject(e, 0, "t_ally_squire")
	p.duelist.energy = 2
	ally.energy = 1
	e._apply_effect({"op": "energy", "amount": "max", "target": "all"}, 0, {}, null)
	eq(p.duelist.energy, CardInstance.MAX_STAGE, "the duelist is full")
	eq(ally.energy, CardInstance.MAX_STAGE, "and so is the Ally")
	p.duelist.energy = 2
	ally.energy = 1
	e._apply_effect({"op": "energy", "amount": "max", "target": "choose"}, 0, {}, null)
	check(e.prompt != null and e.prompt.kind == &"pick_option", "with an Ally out, the pick is asked")
	eq(e.prompt.card_options().size(), 2, "the duelist and the Ally are both on offer")
	e.submit(Command.new(0, &"pick_option", ally.uid))
	eq(ally.energy, CardInstance.MAX_STAGE, "the chosen personality is raised")
	eq(p.duelist.energy, 2, "and the other is left alone")
	p.in_play.erase(ally)
	p.duelist.energy = 3
	e._apply_effect({"op": "energy", "amount": "max", "target": "choose"}, 0, {}, null)
	eq(p.duelist.energy, CardInstance.MAX_STAGE, "with no Ally there is nothing to ask about")


## "Unless your opponent discards a card from hand, ..." is their call, so the prompt crosses the
## table while the effect stays with the card's owner.
func test_may_can_ask_the_opponent() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
	e.player(1).hand.append(e._instance(lib.get_def("t_strike"), 1, &"hand"))
	var ask: Dictionary = {"may": true, "asks": "opponent", "op": "discard_hand", "who": "opponent",
		"amount": 1, "random": false, "otherwise": [{"op": "fervor", "amount": 2}]}
	# A "you may" is raised while the queue drains, not by applying the effect straight off, and the
	# queue only drains with nothing else being asked.
	e.prompt = null
	e._enqueue([ask], "secondary", 0, {}, null)
	e._drain()
	check(e.prompt != null, "the question is raised")
	eq(e.prompt.player, 1, "and it is the opponent who answers it")
	var before: int = e.player(0).fervor
	e.submit(Command.new(1, &"pick_option", -1, "no"))
	eq(e.player(0).fervor, before + 2, "a refusal runs the otherwise, which belongs to the card's owner")


## "Remove up to N cards in your opponent's discard pile" puts the pile in front of the chooser
## rather than skimming the top, and taking nothing is a legal answer.
func test_remove_discard_choice() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
	var foe: PlayerState = e.player(1)
	for i in range(5):
		foe.discard.append(e._instance(lib.get_def("t_strike"), 1, &"discard"))
	e._apply_effect({"op": "remove_discard", "who": "opponent", "amount": 3, "choose": true, "up_to": true}, 0, {}, null)
	check(e.prompt != null, "the pile is offered")
	eq(e.prompt.kind, &"pick_discard", "as a discard-pile pick")
	eq(e.prompt.player, 0, "to the player whose card it is")
	eq(e.prompt.card_options().size(), 5, "every card in the pile is on offer, not just the top 3")
	check(e.prompt.find(&"pick_none") != null, "and taking none is allowed")
	var picked: Array[int] = [e.prompt.card_options()[1], e.prompt.card_options()[3]]
	e.submit(Command.new(0, e.prompt.batch_type, -1, picked))
	eq(foe.discard.size(), 3, "the two chosen cards left the pile")
	for uid in picked:
		eq(e.card(uid).zone, &"removed", "and are out of the game")
	# Without `choose` it still skims the top, which is what every other card that reads it wants.
	e._apply_effect({"op": "remove_discard", "who": "opponent", "amount": 2}, 0, {}, null)
	check(e.prompt == null or e.prompt.kind != &"pick_discard", "no pick when the card does not offer a choice")
	eq(foe.discard.size(), 1, "and two more are gone")


## "Remove a Seal in play from the game" names no side, so both players' Seals are on offer.
func test_discard_in_play_any_side() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
	inject(e, 0, "t_seal_1")
	inject(e, 1, "t_seal_1")
	e._apply_effect({"op": "discard_in_play", "who": "any", "card_type": "seal", "amount": 1, "remove": true, "choose": true}, 0, {}, null)
	check(e.prompt != null, "the pick is offered")
	eq(e.prompt.card_options().size(), 2, "both Seals are on offer, mine as well as theirs")


## "Shuffle 3 Steel cards in your discard pile into your Life Deck" takes only that school, and
## takes as many of them as it can find rather than stopping at the first card of another school.
func test_shuffle_discard_takes_only_its_school() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
	var p: PlayerState = e.player(0)
	var mine: Array[String] = ["t_strike", "t_parry", "t_strike", "t_parry", "t_strike"]
	for id in mine:
		var c: CardInstance = e._instance(lib.get_def(id), 0, &"discard")
		p.discard.append(c)
	var before: int = p.life_deck.size()
	e._shuffle_discard_into_deck(p, 2, false, "top", "pyre")
	eq(p.life_deck.size(), before + 2, "two cards came back")
	for c in p.life_deck.slice(before):
		eq(c.def.school, "pyre", "and both were Pyre, past the Tide cards in the way")
	eq(p.discard.size(), 3, "the rest of the pile stays put")
	var tide: int = 0
	for c in p.discard:
		if c.def.school == "tide":
			tide += 1
	eq(tide, 2, "including every Tide card")
	e._shuffle_discard_into_deck(p, 9, false, "top", "pyre")
	eq(p.discard.size(), 2, "asking for more than the pile holds takes what there is")


## A Mastery that guards Drills reads "cannot be discarded for any reason", so the aspect change
## clears no Drills either, and losing an aspect keeps them too.
func test_drill_guard_survives_aspect_change() -> void:
	var e: DuelEngine = engine(deck(filler(["t_drill_strike", "t_taunt", "t_strike"]), "vigil", "", "t_mastery_drills"), deck(filler(), "pact"))
	answer(e, &"place", uid_in_hand(e, 0, "t_drill_strike"))
	to_combat(e)
	e.player(0).fervor = 4
	answer(e, &"use", uid_in_hand(e, 0, "t_taunt"))
	eq(e.player(0).duelist.aspect, 2, "aspect still rises")
	eq(e.player(0).drills().size(), 1, "but the guarded Drill stays in play")
	e._lose_aspect(e.player(0), 1)
	eq(e.player(0).duelist.aspect, 1, "the aspect is lost")
	eq(e.player(0).drills().size(), 1, "and the guarded Drill still stays")


## A Duelist Power is once per turn; rising an aspect mid-Combat does not hand out a second use.
func test_power_not_refreshed_by_aspect_change() -> void:
	var e: DuelEngine = engine(deck(filler(["t_taunt", "t_taunt", "t_strike"])), deck(filler(), "pact"))
	to_combat(e)
	var me: PlayerState = e.player(0)
	check(e._power_available(me, me.duelist), "power fresh at the first attack")
	answer(e, &"power", me.duelist.uid)
	check(not e._power_available(me, me.duelist), "used this turn")
	me.fervor = 4
	answer(e, &"pass")
	answer(e, &"use", uid_in_hand(e, 0, "t_taunt"))
	eq(me.duelist.aspect, 2, "rose an aspect mid-Combat")
	check(not e._power_available(me, me.duelist), "the new aspect's Power waits for the next turn")
	skip_to_turn(e, 3)
	check(e._power_available(me, me.duelist), "fresh again on the owner's next turn")


func test_ascension_win_and_gating() -> void:
	var e: DuelEngine = engine(deck(filler(["t_taunt", "t_taunt", "t_strike"])), deck(filler(), "pact"))
	to_combat(e)
	e.player(0).duelist.aspect = 2
	e.player(0).fervor = 4
	e.player(1).highest_aspect = 5
	answer(e, &"use", uid_in_hand(e, 0, "t_taunt"))
	eq(e.player(0).duelist.aspect, 3, "reached own top aspect")
	eq(e.player(0).fervor, 0, "fervor resets on the climb")
	check(not e.is_over(), "reaching the top aspect is not yet the win")
	e.player(0).fervor = 4
	answer(e, &"pass")
	answer(e, &"use", uid_in_hand(e, 0, "t_taunt"))
	check(e.is_over(), "full fervor at the own top aspect ends the duel, whatever the rival's stack")
	eq(e.state.winner, 0, "ascension winner")
	eq(e.state.win_reason, "ascension", "ascension reason")


func test_pass_flow_discard_and_next_turn() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
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


## The Discard step asks both players at once. The opposing player may answer first, the
## turn does not move until the active player has answered too.
func test_discard_step_simultaneous() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
	to_combat(e)
	answer(e, &"pass")
	answer(e, &"pass")
	eq(e.prompts.size(), 2, "both players hold a keep prompt")
	eq(e.prompt.player, 0, "the active player's prompt is first")
	eq(e.prompt_of(1).kind, &"keep", "the opposing player's is a keep prompt too")
	check(e.submit(Command.new(1, &"discard_all")), "the opposing player answers first")
	eq(e.player(1).discard.size(), 3, "their hand went to the discard")
	eq(e.state.step, GameState.Step.DISCARD, "still the discard step")
	eq(e.prompts.size(), 1, "only the active player's prompt is left")
	check(e.submit(Command.new(0, &"keep", e.player(0).hand[0].uid)), "the active player answers")
	eq(e.player(0).hand.size(), 1, "active kept one")
	eq(e.state.turn, 2, "the turn moves once both have answered")


func test_deck_out_loses() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(["t_strike", "t_strike"], "pact"))
	to_combat(e)
	check(e.is_over(), "drawing from an empty deck ends the game")
	eq(e.state.winner, 0, "player 1 lost by survival")
	eq(e.state.win_reason, "survival", "survival reason")


func test_seal_bypass_and_instant_win() -> void:
	var e: DuelEngine = engine(deck(filler(["t_art", "t_art", "t_art"])), deck(filler(["t_parry", "t_parry", "t_parry", "t_seal_2"]), "pact"))
	to_combat(e)
	answer(e, &"attack", uid_in_hand(e, 0, "t_art"))
	eq(e.player(1).discard.size(), 4, "seal did not count as a wound")
	eq(e.player(1).life_deck.back().def.id, "t_seal_2", "seal went to the deck bottom")
	# Instant win on placing the seventh yourself.
	var e2: DuelEngine = engine(deck(filler(["t_seal_7"])), deck(filler(), "pact"))
	for i in range(1, 7):
		inject(e2, 0, "t_seal_%d" % i)
	answer(e2, &"place", uid_in_hand(e2, 0, "t_seal_7"))
	check(e2.is_over(), "seventh seal placed wins")
	eq(e2.state.win_reason, "seal", "seal reason")


func test_capture_and_pending_win() -> void:
	var e: DuelEngine = engine(deck(filler(["t_strike_wound", "t_strike_wound", "t_strike_wound"])), deck(filler([], 20), "pact"))
	var t: CardInstance = inject(e, 1, "t_seal_7")
	for i in range(1, 7):
		inject(e, 0, "t_seal_%d" % i)
	to_combat(e)
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike_wound"))
	eq(prompt_kind(e), &"critical", "five wounds are critical damage")
	answer(e, &"capture", t.uid)
	eq(t.controller, 0, "seal changed hands")
	if prompt_kind(e) == &"pick_option":
		answer(e, &"pick_option", -1, "no")   # the captured Seal's power is optional
	eq(e.player(0).seals().size(), 7, "seven seals held")
	check(not e.is_over(), "captured seventh does not win at once")
	check(e.player(0).seal_victory_pending, "victory pending")
	skip_to_turn(e, 3)
	check(e.is_over(), "win at the start of the capturing player's next turn")
	eq(e.state.win_reason, "seal", "seal reason")


## Critical damage (5+ wounds in one attack) offers a Seal, an Ally, or the rival's Fervor. Card
## text beats the rulebook, so a printed "cannot be discarded" or a Fervor shield takes that option
## off the list here exactly as it would anywhere else, and a rival guarded on both gets no prompt.
func test_critical_damage_choices() -> void:
	var e: DuelEngine = engine(deck(filler(["t_strike_wound", "t_strike_wound"])), deck(filler([], 20), "pact", "", "", 3, "tf_shepherd", "t_relic_shield"))
	var squire: CardInstance = inject(e, 1, "t_ally_squire")
	check(e._ally_protected(e.player(1), squire), "the rival's constant protects Allies")
	check(e.fervor_shielded(e.player(1)), "the rival's Relic shields Fervor")
	e.player(1).fervor = 2
	to_combat(e)
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike_wound"))
	eq(prompt_kind(e), &"redirect", "the defender may hand the damage to the ally first")
	answer(e, &"target", e.player(1).duelist.uid)
	check(prompt_kind(e) != &"critical", "guarded on every count, so nothing is on offer")
	eq(e.player(1).allies().size(), 1, "the ally is still there")
	eq(e.player(1).fervor, 2, "and the Fervor is untouched")

	# An unguarded rival still loses the Ally, or the Fervor, at the attacker's choice.
	var open_field: DuelEngine = engine(deck(filler(["t_strike_wound", "t_strike_wound"])), deck(filler([], 20), "pact"))
	var exposed: CardInstance = inject(open_field, 1, "t_ally_squire")
	check(not open_field._ally_protected(open_field.player(1), exposed), "nothing guards this one")
	open_field.player(1).fervor = 2
	to_combat(open_field)
	answer(open_field, &"attack", uid_in_hand(open_field, 0, "t_strike_wound"))
	if prompt_kind(open_field) == &"redirect":
		answer(open_field, &"target", open_field.player(1).duelist.uid)
	eq(prompt_kind(open_field), &"critical", "critical prompt with no Seals in play")
	var kinds: Array[StringName] = []
	for o in open_field.prompt.options:
		kinds.append(o.type)
	check(kinds.has(&"discard_ally") and kinds.has(&"lower_fervor") and kinds.has(&"no_critical"), "ally, fervor and decline offered")
	check(not kinds.has(&"capture"), "no Seal to capture")
	answer(open_field, &"discard_ally", exposed.uid)
	eq(open_field.player(1).allies().size(), 0, "the unguarded ally is discarded")
	check(has_event(open_field, &"critical_ally"), "critical_ally event")
	answer(open_field, &"pass")
	answer(open_field, &"attack", uid_in_hand(open_field, 0, "t_strike_wound"))
	eq(prompt_kind(open_field), &"critical", "second critical hit")
	answer(open_field, &"lower_fervor")
	eq(open_field.player(1).fervor, 1, "rival fervor lowered by 1")
	var wounded: DuelEngine = engine(deck(filler(["t_strike_wound", "t_strike_wound", "t_strike_wound"])), deck(filler([], 20), "pact"))
	to_combat(wounded)
	answer(wounded, &"attack", uid_in_hand(wounded, 0, "t_strike_wound"))
	check(prompt_kind(wounded) != &"critical", "nothing to take means no prompt")


func test_final_strike_forces_pass() -> void:
	var e: DuelEngine = engine(deck(filler(["t_taunt", "t_taunt", "t_taunt"])), deck(filler(["t_art", "t_art", "t_art"]), "pact"))
	to_combat(e)
	var fodder: int = uid_in_hand(e, 0, "t_taunt")
	answer(e, &"final_strike", fodder)
	eq(e.card(fodder).zone, &"discard", "fodder discarded")
	eq(e.player(1).duelist.energy, 3, "final strike used the table")
	check(e.player(0).must_pass, "must pass afterwards")
	answer(e, &"pass")
	check(has_event(e, &"combat_end"), "forced pass ended combat")


func test_ally_control_and_redirect() -> void:
	var e: DuelEngine = engine(deck(filler(["t_ally_squire", "t_taunt", "t_taunt"])), deck(filler(), "pact"))
	answer(e, &"place", uid_in_hand(e, 0, "t_ally_squire"))
	var ally: CardInstance = e.player(0).allies()[0]
	eq(ally.energy, 4, "ally enters at 3 and powers up 1")
	to_combat(e)
	e.player(0).duelist.energy = 1
	ally.energy = 3
	answer(e, &"pass")
	answer(e, &"attack", uid_in_hand(e, 1, "t_strike"))
	eq(prompt_kind(e), &"control", "control prompt at energy 1 with an ally")
	answer(e, &"control", ally.uid)
	# An Ally holding Combat can still push the hit onto the Duelist, so the choice is offered.
	eq(prompt_kind(e), &"redirect", "redirect prompt with the Duelist behind the Ally in control")
	var targets: Array[int] = []
	for o in e.prompt.options:
		targets.append(o.card)
	check(targets.has(e.player(0).duelist.uid), "the Duelist is one of the targets")
	check(targets.has(ally.uid), "so is the Ally in control")
	answer(e, &"target", ally.uid)
	# attacker 4.0M band E vs ally might 300k band B = 4 stages: 3 to the ally, 1 wound
	eq(ally.energy, 0, "ally absorbed the stages")
	eq(e.player(0).discard.size(), 1, "overflow wound taken from the owner's deck")
	eq(e.player(0).duelist.energy, 1, "duelist untouched")


## "Whenever your opponent plays or uses a card outside of their Defender Defends phase, you may
## have one Ally take control of Combat before any effects occur." The printed use is getting an
## Ally in front of a card that is about to hit your Allies or your spent Duelist.
func test_ally_takes_control_when_the_opponent_uses_a_card() -> void:
	var e: DuelEngine = engine(deck(filler(["t_ally_squire"])), deck(filler(["t_taunt"]), "pact"))
	answer(e, &"place", uid_in_hand(e, 0, "t_ally_squire"))
	var ally: CardInstance = e.player(0).allies()[0]
	to_combat(e)
	# Pass the phase over and let seat 1 use a card in place of an attack.
	e.player(0).duelist.energy = 1
	answer(e, &"pass")
	answer(e, &"use", uid_in_hand(e, 1, "t_taunt"))
	eq(prompt_kind(e), &"respond", "the card opens a window before any of it resolves")
	eq(e.prompt.player, 0, "and the window belongs to the other player")
	answer(e, &"control", ally.uid)
	eq(e.player(0).in_control(), ally, "the Ally stepped in before the card resolved")
	eq(e.player(1).fervor, 2, "and the card then resolved as normal")


func test_only_one_ally_takes_control_per_card() -> void:
	var e: DuelEngine = engine(deck(filler(["t_ally_squire"])), deck(filler(["t_taunt"]), "pact"))
	answer(e, &"place", uid_in_hand(e, 0, "t_ally_squire"))
	var first: CardInstance = e.player(0).allies()[0]
	var second: CardInstance = inject(e, 0, "t_ally_squire")
	second.energy = 3
	to_combat(e)
	e.player(0).duelist.energy = 1
	answer(e, &"pass")
	answer(e, &"use", uid_in_hand(e, 1, "t_taunt"))
	answer(e, &"control", first.uid)
	check(prompt_kind(e) != &"respond", "the window does not reopen for the second Ally")
	eq(e.player(0).in_control(), first, "the first Ally keeps control")
	check(e.player(0).in_control() != second, "the second never got the offer")


## A Mastery can be the block itself: "once per Combat, discard a card from your hand to stop an
## attack, and if that card is one of yours, lower their Fervor". The discard is queued before the
## Mastery's own lines, so the line that asks what was discarded reads it off the discard pile.
func test_mastery_can_block_for_a_hand_card() -> void:
	var e: DuelEngine = engine(deck(filler(), "vigil", "tide", "t_mastery_block"), deck(filler(["t_strike"]), "pact"))
	to_combat(e)
	answer(e, &"pass")
	answer(e, &"attack", uid_in_hand(e, 1, "t_strike"))
	var mastery: CardInstance = e.player(0).mastery
	eq(prompt_kind(e), &"defense", "the defender is asked")
	var offered: bool = false
	for o in e.prompt.options:
		if o.card == mastery.uid:
			offered = true
	check(offered, "the Mastery is on the list of blocks")
	var hand_before: int = e.player(0).hand.size()
	answer(e, &"defend", mastery.uid)
	if prompt_kind(e) == &"discard_choice":
		answer(e, &"discard_choice", e.prompt.options[0].card)
	eq(e.player(0).hand.size(), hand_before - 1, "it cost a card from hand")
	check(has_event(e, &"attack_stopped"), "and it stopped the attack")
	eq(mastery.power_used_combat, e.state.combat_count, "spent for this Combat")
	check(e.player(0).mastery != null, "the Mastery itself stays in play")


func test_end_combat_effect() -> void:
	var e: DuelEngine = engine(deck(filler(["t_truce", "t_truce", "t_truce"])), deck(filler(), "pact"))
	to_combat(e)
	answer(e, &"use", uid_in_hand(e, 0, "t_truce"))
	check(has_event(e, &"combat_end"), "truce ended combat")
	eq(e.state.step, GameState.Step.DISCARD, "moved to discard step")


## A gain swallowed by a standing `no_gain` used to change nothing and say nothing, so a card
## like Root Mastery ("go to full Energy") looked like it had not worked at all.
func test_blocked_energy_gain_is_reported() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
	e.dev_effect(0, {"op": "float", "what": "no_gain", "duration": "turn"})
	check(e.energy_blocked(e.player(0)), "the player reports that Energy gain is blocked")
	check(not e.energy_blocked(e.player(1)), "the other player is unaffected")
	var seat: SeatPlayer = SeatPlayer.of(e.player(0), e)
	check(seat.energy_blocked, "the seat view carries it, so a client can show the flag")
	e.events.clear()
	var before: int = e.player(0).duelist.energy
	e.dev_effect(0, {"op": "energy", "amount": "max", "target": "duelist"})
	eq(e.player(0).duelist.energy, before, "the gain really is swallowed")
	check(has_event(e, &"gain_blocked"), "and it says so instead of passing in silence")
	check(not has_event(e, &"energy_changed"), "no Energy change is claimed")
	e.events.clear()
	e.dev_effect(0, {"op": "energy", "amount": 3, "target": "duelist"})
	check(has_event(e, &"gain_blocked"), "a plain gain is reported the same way")


## Every animated event carries the table numbers as they stood when it fired, so a client can
## pace an update's beats instead of drawing the end state under all of them.
func test_events_carry_the_state_they_fired_at() -> void:
	var r: Referee = Referee.new()
	var decks: Array[DeckList] = [deck(filler()), deck(filler(), "pact")]
	r.setup(decks, lib, table, 1)
	r.start()
	var updates: Array[SeatUpdate] = r.take_updates()
	var stamped: int = 0
	var seen_energy: bool = false
	for l in updates[0].lines:
		if not l.has("data"):
			continue
		check(l.has("state"), "animated line %s carries its state" % str(l.get("type", "")))
		var st: Dictionary = l.get("state", {})
		eq((st.get("fervor", []) as Array).size(), 2, "one Fervor count per player")
		eq((st.get("zones", []) as Array).size(), 2, "one zone row per player")
		# Where the turn stood, so the banner over the table cannot run ahead of the beat.
		for key in ["turn", "step", "phase", "active", "attacker"]:
			check(st.has(key), "the beat's state carries %s" % key)
		check(int(st["step"]) != GameState.Step.GAME_OVER, "and it is a step of the turn it fired in")
		if str(l.get("type", "")) == "power_up":
			# Allies gain too, and only the event knows what each of them stands at.
			check((l["data"] as Dictionary).has("energies"), "power up lists what each personality holds")
			seen_energy = true
		stamped += 1
	check(stamped > 0, "the opening update animates something")
	check(seen_energy, "the opening Power Up is one of them")
	# The AI's simulations must not pay for any of this.
	check(not r.sim_for(0, 5).record_display_state, "a simulation records no display state")


func test_random_hand_discard() -> void:
	var e: DuelEngine = engine(deck(filler(["t_scout", "t_scout", "t_scout"])), deck(filler(), "pact"))
	to_combat(e)
	eq(e.player(1).hand.size(), 3, "opponent drew 3")
	answer(e, &"use", uid_in_hand(e, 0, "t_scout"))
	eq(e.player(1).hand.size(), 1, "two random cards left the hand")
	eq(e.player(1).discard.size(), 2, "they went to the discard pile")


func test_reserve_swap() -> void:
	var reserve: Array[String] = ["t_art", "t_taunt"]
	var e: DuelEngine = engine(deck(filler(), "vigil", "", "", 3, "tf_vigil", "t_relic", reserve), deck(filler(), "pact"))
	eq(prompt_kind(e), &"reserve", "setup opens with the reserve prompt")
	eq(e.prompt.player, 0, "active player swaps first")
	var art_uid: int = e.player(0).reserve[0].uid
	var deck_before: int = e.player(0).life_deck.size()
	answer(e, &"reserve_in", art_uid)
	eq(e.card(art_uid).zone, &"life_deck", "reserve card entered the life deck")
	for ev in e.events:
		if ev.type == &"reserve_swap":
			check(CardText.event_line(ev, e, 0).contains("Test Art"), "the swapping seat's log names the card")
			check(CardText.event_line(ev, e, 1) == "%s brings a card in from the Reserve." % e.player(0).name, "the other seat's log does not: %s" % CardText.event_line(ev, e, 1))
	eq(e.player(0).reserve.size(), 2, "a random life card took its place")
	eq(e.player(0).life_deck.size(), deck_before, "deck size unchanged")
	check(e.prompt.find(&"reserve_in", e.player(0).reserve[1].uid) == null, "the swapped-out card cannot come straight back")
	answer(e, &"reserve_done")
	eq(e.state.turn, 1, "opponent without Reserve is skipped and the first turn begins")
	eq(e.player(0).hand.size(), 3, "normal draw followed")


## Both players hold a reserve prompt at once. Either may answer first, each seat's view puts
## its own decision first, the referee routes each seat to its own prompt, and the turn begins
## only once both are done.
func test_reserve_swap_simultaneous() -> void:
	var reserve: Array[String] = ["t_art", "t_taunt"]
	var r: Referee = Referee.new()
	var e: DuelEngine = engine(deck(filler(), "vigil", "", "", 3, "tf_vigil", "t_relic", reserve), deck(filler(), "pact", "", "", 3, "tf_vigil", "t_relic", reserve))
	r.engine = e
	eq(e.prompts.size(), 2, "one reserve prompt per player")
	eq(e.prompt.player, 0, "the active player's prompt comes first")
	eq(e.prompt_of(1).kind, &"reserve", "the other player has a reserve prompt too")
	eq(SeatView.of(e, 1).deciding, 1, "seat 1's view says seat 1 is deciding")
	eq(SeatView.of(e, 0).deciding, 0, "seat 0's view says seat 0 is deciding")
	check(r.prompt_for(1) != null, "the referee hands seat 1 its prompt")
	var one_in: int = e.player(1).reserve[0].uid
	eq(r.submit(1, Command.new(1, &"reserve_in", one_in).to_dict()), "", "seat 1 may answer before seat 0")
	eq(e.card(one_in).zone, &"life_deck", "seat 1's card entered its deck")
	eq(e.prompts.size(), 2, "seat 1's prompt reopened with what is left, seat 0's untouched")
	eq(r.submit(1, Command.new(1, &"reserve_done").to_dict()), "", "seat 1 finishes")
	eq(e.prompts.size(), 1, "only seat 0 is still swapping")
	eq(e.state.turn, 0, "the turn waits for seat 0")
	eq(SeatView.of(e, 1).deciding, 0, "seat 1's view now waits on seat 0")
	eq(r.submit(1, Command.new(1, &"reserve_done").to_dict()), "It is not your decision.", "a finished seat cannot answer again")
	var clone: DuelEngine = e.clone()
	eq(clone.prompts.size(), 1, "a clone carries the open prompts")
	eq(r.submit(0, Command.new(0, &"reserve_done").to_dict()), "", "seat 0 finishes")
	eq(e.state.turn, 1, "the first turn begins once both are done")
	eq(e.prompts.size(), 1, "back to one prompt at a time")


## Several Reserve cards can come in as one batch command; the batch must stay inside the
## options, and the wire form the referee sees carries the same list.
func test_reserve_batch() -> void:
	var reserve: Array[String] = ["t_art", "t_taunt", "t_parry"]
	var e: DuelEngine = engine(deck(filler(), "vigil", "", "", 3, "tf_vigil", "t_relic", reserve), deck(filler(), "pact"))
	eq(e.prompt.batch_type, &"reserve_in", "the reserve prompt takes a batch")
	eq(e.prompt.batch_max, 3, "up to every reserve card")
	var a: int = e.player(0).reserve[0].uid
	var b: int = e.player(0).reserve[1].uid
	var stranger: int = e.player(0).life_deck[0].uid
	check(e.prompt.accept(Command.new(0, &"reserve_in", -1, [a, stranger])) == null, "a uid outside the options is refused")
	check(e.prompt.accept(Command.new(0, &"reserve_in", -1, [a, a])) == null, "repeats are refused")
	check(e.prompt.accept(Command.new(1, &"reserve_in", -1, [a])) == null, "the other seat cannot answer")
	check(e.prompt.accept(Command.new(0, &"reserve_in", -1, [])) == null, "an empty batch is not a swap")
	var view: PromptView = PromptView.of(e.prompt, e)
	var batch: OptionView = PromptView.from_dict(view.to_dict()).batch_option([a, b])
	eq(batch.label, "Bring in 2", "the batch option labels itself")
	var deck_before: int = e.player(0).life_deck.size()
	check(e.submit(batch.to_command(0)), "the batch is accepted")
	eq(e.card(a).zone, &"life_deck", "first card entered the deck")
	eq(e.card(b).zone, &"life_deck", "second card entered the deck")
	eq(e.player(0).reserve.size(), 3, "two random cards came out")
	eq(e.state.turn, 1, "the batch also finishes the swap")
	eq(e.player(0).life_deck.size() + e.player(0).hand.size(), deck_before, "two swaps keep the deck size, less the opening draw")
	var r: Referee = Referee.new()
	var e2: DuelEngine = engine(deck(filler(), "vigil", "", "", 3, "tf_vigil", "t_relic", reserve), deck(filler(), "pact"))
	r.engine = e2
	var uids: Array[int] = [e2.player(0).reserve[0].uid, e2.player(0).reserve[2].uid]
	eq(r.submit(0, r.prompt_for(0).batch_option(uids).to_command(0).to_dict()), "", "the referee takes the batch in wire form")
	eq(e2.card(uids[1]).zone, &"life_deck", "and applied it")


func test_bracket_first_player() -> void:
	var giant: DeckList = deck(filler(), "vigil", "", "", 3, "tf_giant")
	var e: DuelEngine = engine(giant, deck(filler(), "vigil", "", "", 3, "tf_pageboy"))
	eq(e.state.active, 1, "the duelist below band D opens the duel")
	eq(e.player(0).duelist.energy, 5, "no stage penalty under the bracket rule")
	check(has_event(e, &"bracket_rule"), "bracket rule event emitted")


func test_search_and_in_play_discard() -> void:
	var e: DuelEngine = engine(deck(filler(["t_seek", "t_glare", "t_strike", "t_art"])), deck(filler(["t_noncombat_draw", "t_strike", "t_strike"]), "pact"))
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
	var e: DuelEngine = engine(deck(filler(["t_art_stubborn", "t_art_stubborn", "t_art_stubborn"])), deck(filler(["t_ward", "t_ward", "t_ward"]), "pact"))
	to_combat(e)
	var hand_before: int = e.player(0).hand.size()
	answer(e, &"attack", uid_in_hand(e, 0, "t_art_stubborn"))
	answer(e, &"defend", uid_in_hand(e, 1, "t_ward"))
	eq(e.player(0).hand.size(), hand_before - 1 + 2, "stopped attack drew two")


func test_determinism() -> void:
	var a: DuelEngine = engine(deck(filler(["t_art", "t_taunt", "t_parry", "t_seal_1"])), deck(filler(["t_guard", "t_ward"]), "pact"), 42, true)
	var b: DuelEngine = engine(deck(filler(["t_art", "t_taunt", "t_parry", "t_seal_1"])), deck(filler(["t_guard", "t_ward"]), "pact"), 42, true)
	var ids_a: Array[String] = []
	var ids_b: Array[String] = []
	for c in a.player(0).life_deck:
		ids_a.append(c.def.id)
	for c in b.player(0).life_deck:
		ids_b.append(c.def.id)
	eq(ids_a, ids_b, "same seed, same shuffle")
	var c: DuelEngine = engine(deck(filler(["t_art", "t_taunt", "t_parry", "t_seal_1"])), deck(filler(["t_guard", "t_ward"]), "pact"), 43, true)
	var ids_c: Array[String] = []
	for card in c.player(0).life_deck:
		ids_c.append(card.def.id)
	check(ids_a != ids_c, "different seed, different shuffle")


## Online play: a second engine fed only the wire form of the first one's commands ends every
## step in the same state, including the values that ride on commands (pay amounts, option keys).
func test_command_wire_lockstep() -> void:
	var a: DuelEngine = engine(deck(filler(["t_art", "t_taunt", "t_parry", "t_seal_1", "t_pay_art", "t_empower_art"])), deck(filler(["t_guard", "t_ward"]), "pact"), 77, true)
	var b: DuelEngine = engine(deck(filler(["t_art", "t_taunt", "t_parry", "t_seal_1", "t_pay_art", "t_empower_art"])), deck(filler(["t_guard", "t_ward"]), "pact"), 77, true)
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
		eq(b.player(i).duelist.energy, a.player(i).duelist.energy, "player %d energy" % i)
	# Values ride along unchanged: option keys, pay amounts, named titles.
	for sample in [Command.new(1, &"attack", 12, "empower"), Command.new(0, &"pay", -1, 4), Command.new(0, &"name_card", 3, "Test Parry"), Command.new(1, &"pass")]:
		var back: Command = Command.from_dict(sample.to_dict())
		check(back.matches(sample), "wire form keeps %s" % sample.describe())
		check(typeof(back.value) == typeof(sample.value), "value type kept for %s" % sample.describe())


## A face-down card's uid must not give away what it is. Uids are dealt after the shuffle, so
## the same deck list under two seeds maps uids to different cards.
func test_uids_hide_deck_order() -> void:
	var cards: Array[String] = filler(["t_art", "t_taunt", "t_parry", "t_seal_1", "t_guard", "t_ward"])
	var a: DuelEngine = engine(deck(cards), deck(filler(), "pact"), 11, true)
	var b: DuelEngine = engine(deck(cards), deck(filler(), "pact"), 12, true)
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
	var e: DuelEngine = engine(deck(filler(["t_art", "t_taunt", "t_parry", "t_seal_1"])), deck(filler(["t_guard", "t_ward"]), "pact", "", "", 3, "tf_vigil", "t_relic", ["t_summons"]))
	answer(e, &"reserve_done")
	var v0: SeatView = SeatView.of(e, 0)
	var v1: SeatView = SeatView.of(e, 1)
	eq(v0.cards.size(), e.all_cards().size(), "every card has a row")
	for uid in v0.player(0).hand:
		check(not v0.card(uid).hidden(), "own hand is visible")
		check(v1.card(uid).hidden(), "the other seat sees only a back")
		eq(v1.card(uid).zone, &"hand", "but knows the zone")
	for uid in v0.player(0).life_deck:
		check(v0.card(uid).hidden(), "own Life Deck stays face down")
	for uid in v1.player(1).reserve:
		check(not v1.card(uid).hidden(), "own Reserve is visible")
		check(v0.card(uid).hidden(), "the other seat cannot read the Reserve")
	check(not v1.card(v0.player(0).duelist).hidden(), "duelists are public")
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
	eq(hidden_in_wire, e.player(0).life_deck.size() + e.player(1).life_deck.size() + e.player(0).hand.size() + e.player(0).reserve.size(), "exactly the hidden cards go out blank")


func test_referee_gates_commands() -> void:
	var r: Referee = Referee.new()
	r.engine.shuffle_decks = false
	r.setup([deck(filler(["t_art", "t_taunt", "t_parry", "t_seal_1"])), deck(filler(["t_guard", "t_ward"]), "pact")], lib, table, 5)
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
	r2.setup([deck(filler(["t_strike_plus2"])), deck(filler(), "pact")], lib, table, 5)
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
	var e: DuelEngine = engine(deck(filler(["t_remain_strike", "t_strike", "t_strike"])), deck(filler(), "pact"))
	to_combat(e)
	var uid: int = uid_in_hand(e, 0, "t_remain_strike")
	answer(e, &"attack", uid)
	eq(e.card(uid).zone, &"in_play", "card stays on the table")
	eq(e.card(uid).remain, 1, "one more use")
	check(has_event(e, &"remain"), "remain event")
	# The client draws from the seat view alone, so a card it is about to be offered has to be in
	# one of the view's zones or it is invisible and unclickable however the prompt reads.
	var seat: SeatPlayer = SeatView.of(e, 0, false).player(0)
	check(seat.remain.has(uid), "the seat view puts the kept card in its own zone")
	check(not seat.non_combats.has(uid) and not seat.allies.has(uid) and not seat.drills.has(uid),
		"and only there, so it is drawn once")
	answer(e, &"pass")
	check(e.prompt.find(&"attack", uid) != null, "the table copy can attack again")
	answer(e, &"attack", uid)
	eq(e.card(uid).zone, &"discard", "spent after the second use")


func test_empower() -> void:
	var e: DuelEngine = engine(deck(filler(["t_empower_art", "t_empower_art", "t_strike"])), deck(filler([], 20), "pact"))
	to_combat(e)
	var deck_before: int = e.player(1).life_deck.size()
	answer(e, &"attack", uid_in_hand(e, 0, "t_empower_art"), "empower")
	eq(e.player(1).life_deck.size(), deck_before - 6, "art 4 wounds plus Empower 2")
	eq(e.player(0).fervor, 0, "empowered use drops the after-empower effect")
	answer(e, &"pass")
	deck_before = e.player(1).life_deck.size()
	answer(e, &"attack", uid_in_hand(e, 0, "t_empower_art"))
	eq(e.player(1).life_deck.size(), deck_before - 4, "plain use deals 4")
	eq(e.player(0).fervor, 1, "plain use keeps the secondary effect")


func test_counter_window() -> void:
	var e: DuelEngine = engine(deck(filler(["t_taunt", "t_taunt", "t_strike"])), deck(filler(["t_counter", "t_counter", "t_counter"]), "pact"))
	to_combat(e)
	var taunt: int = uid_in_hand(e, 0, "t_taunt")
	answer(e, &"use", taunt)
	eq(prompt_kind(e), &"respond", "opponent gets a response window")
	eq(e.prompt.player, 1, "the opponent responds")
	var k: int = uid_in_hand(e, 1, "t_counter")
	answer(e, &"counter", k)
	eq(e.player(0).fervor, 0, "countered card does nothing")
	eq(e.card(taunt).zone, &"discard", "countered card is discarded")
	eq(e.card(k).zone, &"discard", "counter card is spent")
	check(has_event(e, &"countered"), "countered event")
	eq(prompt_kind(e), &"attack_action", "play moves on to the fight back")
	answer(e, &"pass")
	answer(e, &"use", uid_in_hand(e, 0, "t_taunt"))
	answer(e, &"decline")
	eq(e.player(0).fervor, 2, "declined counter lets the card resolve")
	# "Use when needed" is the response window and nothing else: the counter's owner cannot
	# play it as an action in their own attack phase, where it would do nothing.
	eq(prompt_kind(e), &"attack_action", "fight back after the declined counter")
	eq(e.prompt.player, 1, "the counter's owner is choosing")
	var held: int = uid_in_hand(e, 1, "t_counter")
	check(held >= 0 and e.prompt.find(&"use", held) == null, "a pure counter card is not an attack-phase action")
	check(e.prompt.find(&"final_strike", held) != null, "it can still be thrown away for a Final Strike")


func test_forbid_art_attacks() -> void:
	var e: DuelEngine = engine(deck(filler(["t_forbid_arts", "t_strike", "t_strike"])), deck(filler(["t_art", "t_art", "t_art"]), "pact"))
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
	var e: DuelEngine = engine(deck(filler(["t_drill_strike"]), "vigil", "pyre", "t_mastery_pyre"), deck(filler(["t_parry", "t_parry", "t_parry"]), "pact"))
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
	eq(str((d["adds"] as Array)[0]["source"]), "Test Pyre Drill", "the Drill is named")
	eq(int(d["stages"]), 4, "forecast total")
	var wire: SeatView = SeatView.from_dict(v.to_dict())
	eq(int(wire.attack["damage"]["stages"]), 4, "wire form keeps the breakdown")
	answer(e, &"no_defense")
	eq(e.player(1).duelist.energy, 1, "what landed matches the forecast")
	var base_line: String = ""
	var mod_line: String = ""
	for ev in e.events:
		if ev.type == &"base_damage":
			base_line = CardText.event_line(ev, e)
		elif ev.type == &"modified_damage":
			mod_line = CardText.event_line(ev, e)
	check(base_line.begins_with("Strike Table: Might"), "base damage log line names the table: %s" % base_line)
	check(mod_line.contains("Test Pyre Drill") and mod_line.ends_with("Total 4 stages."), "modifier log line lists sources and total: %s" % mod_line)
	eq(prompt_kind(e), &"attack_action", "fight back prompt")
	check(bool(e.prompt.context.get("fight_back", false)), "the defender's attack phase is flagged as a fight back")
	eq(CardText.prompt_title(e.prompt), "Fight back", "fight back title")
	check(e.prompt.find(&"final_strike", uid_in_hand(e, 1, "t_parry")) != null, "a Final Strike is still offered on any hand card")


## Before an attack is chosen, the view carries what each offered attack would deal right now,
## built the same way declaring it would, and the number that then lands is the same one.
func test_attack_forecasts_in_view() -> void:
	var e: DuelEngine = engine(deck(filler(["t_drill_strike", "t_strike_plus2", "t_empower_art"]), "vigil", "pyre", "t_mastery_pyre"), deck(filler(["t_parry", "t_parry", "t_parry"]), "pact"))
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
	var fp: Dictionary = v.forecast(e.player(0).duelist.uid)
	eq(int(fp.get("life", -1)), 3, "the duelist's Power attack forecasts its printed wounds")
	var fa: Dictionary = v.forecast(art)
	eq(int(fa["life"]), 4, "an Art forecasts its base wounds")
	eq(int(fa["cost_stages"]), DuelEngine.ART_COST, "the Art's cost travels with the forecast")
	eq(int((fa["empowered"] as Dictionary)["life"]), 6, "the empower option forecasts its extra wounds")
	var steps: PackedStringArray = CardText.breakdown_steps(fh)
	check(steps[0].begins_with("Table 2"), "steps start with the table: %s" % steps[0])
	check(steps.size() == 4 and steps[1].contains("Test Heavy Strike"), "the card's own bonus is a step: %s" % ", ".join(steps))
	eq(CardText.short_damage(6, 0), "6 Energy", "short damage wording")
	eq(CardText.short_damage(0, 4), "4 wounds", "short wounds wording")
	var wire: SeatView = SeatView.from_dict(v.to_dict())
	eq(int(wire.forecast(heavy)["stages"]), 6, "wire form keeps the forecasts")
	answer(e, &"attack", heavy)
	answer(e, &"no_defense")
	eq(e.player(1).duelist.energy, 0, "the forecast Strike lands as forecast: 6 on 5 Energy")
	eq(e.player(1).discard.size(), 1, "with one wound overflowing")
	var badge: Dictionary = CardText.attack_badge(lib.get_def("t_strike_plus2"))
	eq(str(badge["num"]) + " " + str(badge["word"]), "+2 Energy", "Strike badge")
	badge = CardText.attack_badge(lib.get_def("t_strike"))
	eq(str(badge["num"]), "Table", "a bare Strike badge points at the table")
	badge = CardText.attack_badge(lib.get_def("t_art"))
	eq(str(badge["num"]) + " " + str(badge["word"]), "4 wounds", "Art badge shows the base wounds")


## "X only" on a card that attaches to X: playable while X is on the table, and it lands on X.
func test_attach_to_named_character() -> void:
	var alone: DuelEngine = engine(deck(filler(["t_oath", "t_oath", "t_oath"])), deck(filler(), "pact"))
	to_combat(alone)
	check(alone.prompt.find(&"use", uid_in_hand(alone, 0, "t_oath")) == null, "no Squire on the table: the oath cannot be used")
	var e: DuelEngine = engine(deck(filler(["t_oath", "t_oath", "t_oath"])), deck(filler(), "pact"))
	var squire: CardInstance = inject(e, 0, "t_ally_squire")
	to_combat(e)
	var oath: int = uid_in_hand(e, 0, "t_oath")
	check(oath >= 0 and e.prompt.find(&"use", oath) != null, "with the Squire in play the oath is usable though the duelist is in control")
	answer(e, &"use", oath)
	check(e.card(oath).attached_to == squire, "the oath attaches to the Squire, not the duelist")
	eq(e.player(0).attachments().size(), 1, "one attachment in play")


## "Limit 1 attached" caps copies on the table, not copies in the deck.
func test_attachment_limit_attached() -> void:
	var e: DuelEngine = engine(deck(filler(["t_vow", "t_vow", "t_vow"])), deck(filler(), "pact"))
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
	var e: DuelEngine = engine(deck(filler(["t_ally_squire", "t_pledge", "t_pledge"])), deck(filler(), "pact"))
	answer(e, &"place", uid_in_hand(e, 0, "t_ally_squire"))
	var squire: CardInstance = e.player(0).allies()[0]
	answer(e, &"declare")
	var first: int = uid_in_hand(e, 0, "t_pledge")
	check(e.prompt.find(&"use", first) == null, "the duelist is in control, so the Squire's card cannot be used")
	var f: DuelEngine = engine(deck(filler(["t_ally_squire", "t_pledge", "t_pledge"])), deck(filler(), "pact"))
	answer(f, &"place", uid_in_hand(f, 0, "t_ally_squire"))
	squire = f.player(0).allies()[0]
	f.player(0).duelist.energy = 1
	answer(f, &"declare")
	answer(f, &"control", squire.uid)
	first = uid_in_hand(f, 0, "t_pledge")
	check(f.prompt.find(&"use", first) != null, "with the Squire in control it can")
	answer(f, &"use", first)
	eq(f.card(first).attached_to, f.player(0).duelist, "it attaches to the named duelist, not to the Squire")
	var text: String = CardText.rules_text(f.card(first).def)
	check(text.contains("Attach this card to your Test Vigil.") and text.contains("Test Vigil may have only 1 \"Test Squire's Pledge\" attached."), "worded: %s" % text)
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
	var e: DuelEngine = engine(deck(filler(["t_seek", "t_seek_quiet", "t_strike", "t_art"])), deck(filler(), "pact"))
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
	var none: DuelEngine = engine(deck(filler(["t_seek", "t_strike", "t_strike"])), deck(filler(), "pact"))
	to_combat(none)
	none.shuffle_decks = true
	answer(none, &"use", uid_in_hand(none, 0, "t_seek"))
	eq(prompt_kind(none), &"pick_option", "no match still shows the deck")
	eq(none.prompt.card_options().size(), 0, "with nothing to pick")
	eq(PromptView.of(none.prompt, none).title, "Search: nothing in your Life Deck matches", "and says so")
	answer(none, &"pick_none")
	check(has_event(none, &"deck_shuffled"), "shuffled all the same")
	# `no_shuffle` leaves the order alone.
	var quiet: DuelEngine = engine(deck(filler(["t_seek_quiet", "t_strike", "t_strike", "t_art"])), deck(filler(), "pact"))
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
	var e: DuelEngine = engine(deck(filler(drills)), deck(filler(), "pact"))
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


## A deck should be able to play one way into a beatdown and another into a slow deck. The pivot
## keys off what the rival declares itself to be, which both players can see.
func test_a_profile_can_pivot_on_the_matchup() -> void:
	var base: AiProfile = AiProfile.default_profile()
	base.merge({"play": {"declare_bias": 1.0}, "own": {"ally": 2.0},
		"vs": {
			"strike_beatdown": {"play": {"declare_bias": -4.0}, "own": {"ally": 9.0}},
			"+seals": {"play": {"declare_bias": 5.0}},
		}})
	eq(base.w("play", "declare_bias"), 1.0, "with no opponent named, the base profile stands")
	var vs_none: AiProfile = base.for_matchup("art_beatdown", [])
	eq(vs_none.w("play", "declare_bias"), 1.0, "an archetype it names no pivot for changes nothing")
	var vs_beat: AiProfile = base.for_matchup("strike_beatdown", ["fervor"])
	eq(vs_beat.w("play", "declare_bias"), -4.0, "against a beatdown it pulls back")
	eq(vs_beat.w("own", "ally"), 9.0, "and values what keeps it alive")
	eq(vs_beat.w("own", "life"), base.w("own", "life"), "weights the pivot does not name are left alone")
	eq(base.w("play", "declare_bias"), 1.0, "and the base profile is not modified in place")
	var vs_seal: AiProfile = base.for_matchup("seals", ["arts", "drills"])
	eq(vs_seal.w("play", "declare_bias"), 1.0, "an archetype with no entry leaves the base")
	var vs_sealed: AiProfile = base.for_matchup("art_beatdown", ["seals"])
	eq(vs_sealed.w("play", "declare_bias"), 5.0, "a subtheme pivot fires on its own")
	var both: AiProfile = base.for_matchup("strike_beatdown", ["seals"])
	eq(both.w("play", "declare_bias"), 5.0, "and the subtheme is the finer statement, so it wins")
	eq(both.w("own", "ally"), 9.0, "while the archetype's other weights still apply")


## Placing Grounds costs you the Combat that turn, so the turn can end without Combat ever being
## offered. The log has to say why, or it reads as the game skipping your turn for no reason.
func test_a_forced_combat_skip_says_why() -> void:
	var e: DuelEngine = engine(deck(filler(["t_grounds_weight"])), deck(filler(), "pact"))
	var uid: int = uid_in_hand(e, 0, "t_grounds_weight")
	check(uid >= 0, "the Grounds are in the opening hand")
	eq(prompt_kind(e), &"non_combat", "a turn opens on the Non-Combat step")
	answer(e, &"place", uid)
	check(e.player(0).placed_grounds, "the seat is marked as having placed Grounds")
	while prompt_kind(e) == &"non_combat":
		answer(e, &"done")
	check(not has_event(e, &"combat_declared"), "Combat was never offered")
	var said: String = ""
	for ev in e.events:
		if ev.type == &"combat_skipped":
			check(bool(ev.data.get("forced", false)), "the skip was forced, not chosen")
			eq(str(ev.data.get("reason", "")), "grounds", "and the reason names the Grounds")
			said = CardText.event_line(ev, e, 0)
	check(said.contains("placed Grounds"), "the log explains the missing Combat: '%s'" % said)


## The other pivot axis: a deck can hold back until its plan is on the table and then press. The
## facts are read off the seat's own view, so the AI sees only what the table shows.
func test_a_profile_can_pivot_on_where_the_duel_stands() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
	var r: Referee = Referee.new()
	r.engine = e
	var profile: AiProfile = AiProfile.default_profile()
	profile.merge({"play": {"declare_bias": -3.0},
		"when": {"bonded": {"play": {"declare_bias": 5.0}}, "life_below:20": {"own": {"life_low": 9.0}}}})
	var view: SeatView = r.view_for(0)
	var quiet: String = profile.state_key(view, 0)
	check(not quiet.contains("bonded"), "nothing is fused yet, so the pivot is off: '%s'" % quiet)
	eq(profile.for_state(quiet).w("play", "declare_bias"), -3.0, "and it plays the held-back weight")
	var me: PlayerState = e.player(0)
	var fused: CardInstance = me.allies()[0] if not me.allies().is_empty() else null
	if fused == null:
		fused = e._instance(lib.get_def("t_ally_herald"), 0, &"in_play")
		me.in_play.append(fused)
	fused.cards_under.append(e._instance(lib.get_def("t_ally_herald"), 0, &"under"))
	var loud: String = profile.state_key(r.view_for(0), 0)
	check(loud.contains("bonded"), "partners stacked underneath is what a fusion looks like: '%s'" % loud)
	eq(profile.for_state(loud).w("play", "declare_bias"), 5.0, "so now it presses")
	eq(profile.w("play", "declare_bias"), -3.0, "and the base profile is untouched")


## Combat runs many attack phases back and forth, so a restriction aimed at one of them is a far
## smaller thing than one that lasts the whole Combat. It lifts when the phase it was aimed at ends,
## and never outlives the Combat if that phase never came.
func test_a_restriction_can_last_one_attack_phase_not_the_whole_combat() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
	var foe: PlayerState = e.player(1)
	e._float(1, "forbid", "next_attack_phase", {"what": "strike_cards", "source": -1})
	check(e._forbidden(foe, "strike_cards"), "the restriction is on")
	e._expire_attack_phase_floats(0)
	check(e._forbidden(foe, "strike_cards"), "the other player's phase ending does not lift it")
	e._expire_attack_phase_floats(1)
	check(not e._forbidden(foe, "strike_cards"), "their own phase ending lifts it")
	e._float(1, "forbid", "next_attack_phase", {"what": "strike_cards", "source": -1})
	check(e._forbidden(foe, "strike_cards"), "set again, with the phase still to come")
	e._expire_floating("combat")
	check(not e._forbidden(foe, "strike_cards"), "and Combat ending clears one that never fired")


## Grounds could only ever double every cost at once. A place can now be heavy for one kind of
## attack and ordinary for the other, which is how a hall taxes a swing but not a spell.
func test_grounds_can_tax_one_kind_of_attack() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
	var me: PlayerState = e.player(0)
	var strike_spec: Dictionary = {"kind": "strike"}
	var art_spec: Dictionary = {"kind": "art"}
	var strike_before: int = e._cost_stages(strike_spec, me)
	var art_before: int = e._cost_stages(art_spec, me)
	var heavy: CardDef = lib.get_def("t_grounds_weight")
	e.state.grounds = e._instance(heavy, 0, &"grounds")
	eq(e._cost_stages(strike_spec, me), strike_before + 2, "the Grounds tax the Strike by 2")
	eq(e._cost_stages(art_spec, me), art_before, "and leave the Art untouched")
	check(CardText.rules_text(heavy).contains("Strikes cost 2 more Energy"), "the card says so: %s" % CardText.rules_text(heavy))
	e.state.grounds = null
	eq(e._cost_stages(strike_spec, me), strike_before, "and the tax goes with them")


## A deck can be built to never attack and still need Combat open, because some of its cards only
## work once it is. Attacks alone cannot speak for that hand, so `declare_use` weighs what it carries.
func test_a_deck_that_never_attacks_still_declares_to_spend_what_it_carries() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
	var me: PlayerState = e.player(0)
	var profile: AiProfile = AiProfile.default_profile()
	profile.merge({"play": {"declare_bias": -12.0}})
	me.hand.clear()
	var empty: float = AiScorer._declare_score(profile, me)
	check(empty < 1.0, "nothing in hand scores under skipping, which is a flat 1.0 (%.2f)" % empty)
	var carried: CardDef = lib.get_def("t_noncombat_draw")
	for i in range(3):
		me.hand.append(e._instance(carried, 0, &"hand"))
	eq(AiScorer._declare_score(profile, me), empty, "while declare_use is off, carrying them counts for nothing")
	profile.merge({"play": {"declare_use": 2.0}})
	var holding: float = AiScorer._declare_score(profile, me)
	check(holding > empty, "with declare_use on, a hand of Combat-only cards is a reason to open one (%.2f over %.2f)" % [holding, empty])
	check(holding > 1.0, "and enough of them outweighs skipping (%.2f)" % holding)
	me.hand.clear()
	eq(AiScorer._declare_score(profile, me), empty, "spend them and it goes quiet again")


func shipped_library() -> CardLibrary:
	var lib: CardLibrary = CardLibrary.new()
	lib.load_dir("res://data/cards")
	return lib


## Step 10: one multiplier at most, caps at deal time, and "cannot be reduced" ignores both
## reductions and caps.
func test_multiplier_cap_and_no_reduce() -> void:
	var e: DuelEngine = engine(deck(filler(["t_strike", "t_strike", "t_strike_firm"])), deck(filler(["t_art", "t_art", "t_art"]), "pact"))
	inject(e, 0, "t_drill_strike")
	inject(e, 0, "t_drill_double")
	to_combat(e)
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike"))
	# table 2, +1 drill, then x2 = 6 stages: 5 absorbed, 1 wound
	eq(e.player(1).duelist.energy, 0, "doubled strike empties the duelist")
	eq(e.player(1).discard.size(), 1, "one stage overflowed")
	var mod: Dictionary = {}
	for ev in e.events:
		if ev.type == &"modified_damage":
			mod = ev.data
	eq(int(mod.get("stages", 0)), 6, "modified damage reports the doubled total")
	check(CardText.modified_damage_line(mod).contains("x2 (Test Doubling Drill)"), "the multiplier is named in the log: %s" % CardText.modified_damage_line(mod))
	e.player(1).duelist.energy = 5
	inject(e, 1, "t_drill_cap")
	answer(e, &"pass")
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike"))
	eq(e.player(1).duelist.energy, 2, "the cap holds the doubled strike to 3 stages")
	e.player(1).duelist.energy = 5
	answer(e, &"pass")
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike_firm"))
	eq(e.player(1).duelist.energy, 0, "a strike that cannot be reduced ignores the cap")
	check(SeatView.of(e, 1).attack.is_empty(), "attack cleared after resolution")


## Seals are immune to card effects that do not name them.
func test_seals_immune_unless_named() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
	inject(e, 1, "t_seal_1")
	inject(e, 1, "t_noncombat_draw")
	eq(e.player(1).in_play.size(), 2, "a Seal and a Non-Combat in play")
	eq(e.dev_effect(0, {"op": "discard_in_play", "who": "opponent", "card_type": "any", "all": true}), "", "dev effect ran")
	eq(e.player(1).seals().size(), 1, "the Seal stays")
	eq(e.player(1).non_combats().size(), 0, "the Non-Combat went")
	eq(e.dev_effect(0, {"op": "discard_in_play", "who": "opponent", "card_type": "seal"}), "", "a named Seal effect ran")
	eq(e.player(1).seals().size(), 0, "named, the Seal goes")


## Cards that end Combat are attack actions only, never a defense, even if they could stop.
func test_end_combat_card_is_no_defense() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(["t_truce_guard", "t_truce_guard", "t_truce_guard"]), "pact"))
	to_combat(e)
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike"))
	eq(prompt_kind(e), &"attack_action", "no defense possible, straight to the fight back")
	check(e.prompt.find(&"use", uid_in_hand(e, 1, "t_truce_guard")) != null, "but it can be used in the attack phase")


## A school Drill locked out by the Drill in play may be shown and shuffled back.
func test_locked_out_drill_shuffles_back() -> void:
	var e: DuelEngine = engine(deck(filler(["t_drill_guard", "t_drill_guard", "t_drill_guard"])), deck(filler(), "pact"))
	inject(e, 0, "t_drill_strike")
	e._prompt_non_combat()   # the prompt was built before the Drill arrived
	eq(prompt_kind(e), &"non_combat", "non-combat prompt")
	var guard: int = uid_in_hand(e, 0, "t_drill_guard")
	check(e.prompt.find(&"place", guard) == null, "a Tide Drill cannot join Pyre Drills")
	check(e.prompt.find(&"shuffle_back", guard) != null, "so it may be shuffled back")
	var deck_before: int = e.player(0).life_deck.size()
	answer(e, &"shuffle_back", guard)
	eq(e.card(guard).zone, &"life_deck", "the Drill is back in the Life Deck")
	eq(e.player(0).life_deck.size(), deck_before + 1, "deck grew by one")
	check(has_event(e, &"drill_shuffled_back"), "event logged")


## Look at the top three and put them back in any order.
func test_look_at_rearrange() -> void:
	var e: DuelEngine = engine(deck(filler(["t_order"])), deck(filler(), "pact"))
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
	var e: DuelEngine = engine(deck(filler(["t_forbid_arts", "t_strike", "t_strike"]), "vigil", "pyre", "t_mastery_pyre"), deck(filler(["t_art", "t_art", "t_art"]), "pact", "tide", "t_mastery_hard"))
	var v: SeatView = SeatView.of(e, 0)
	eq(v.player(1).fervor_needed, DuelEngine.FERVOR_TO_ASPECT, "the plain player needs the rulebook count")
	eq(v.player(0).fervor_needed, 6, "opposite a demanding Mastery the view says 6")
	eq(v.player(0).recover_gain, e.player(0).duelist.surge() + DuelEngine.STYLE_SURGE_BONUS, "recover gain is Surge Rate plus the flat bonus")
	eq(v.player(1).recover_gain, e.recover_gain(e.player(1)), "the view matches the engine getter")
	e.player(0).fervor = 4
	e.dev_effect(0, {"op": "fervor", "amount": 1})
	eq(e.player(0).duelist.aspect, 1, "5 Fervor is not enough opposite the Mastery")
	eq(e.player(0).fervor, 5, "Fervor keeps counting")
	e.dev_effect(0, {"op": "set_fervor_needed", "amount": 8})
	eq(SeatView.of(e, 1).player(0).fervor_needed, 8, "a raised base shows in the view")
	e.dev_effect(0, {"op": "fervor_needed", "amount": -3})
	eq(e.player(0).fervor_needed, 5, "delta op moves the base")
	eq(e.player(0).duelist.aspect, 1, "a base below the Mastery's demand still needs 6")
	check(has_event(e, &"fervor_needed_changed"), "fervor_needed_changed event")
	e.dev_effect(0, {"op": "fervor", "amount": 1})
	eq(e.player(0).duelist.aspect, 2, "6 Fervor rises an aspect opposite the Mastery")
	eq(e.player(0).fervor, 0, "and resets")
	to_combat(e)
	answer(e, &"use", uid_in_hand(e, 0, "t_forbid_arts"))
	var during: SeatView = SeatView.of(e, 1)
	check(during.player(1).restrictions.has("art_attacks"), "a forbid in force is listed on its target")
	check(during.player(0).restrictions.is_empty(), "and not on the other player")
	var back: SeatPlayer = SeatPlayer.from_dict(during.player(1).to_dict())
	eq(back.restrictions, during.player(1).restrictions, "wire form keeps restrictions")
	eq(back.fervor_needed, during.player(1).fervor_needed, "wire form keeps fervor needed")
	eq(during.duelist_owner(e.player(0).duelist.uid).index, 0, "duelist_owner finds the seat")
	eq(during.live_energy(e.player(0).duelist.uid), e.player(0).duelist.energy, "live_energy reads the card")
	check(during.duelist_owner(uid_in_hand(e, 0, "t_strike")) == null, "a hand card has no standing")


func test_attachment_modifier() -> void:
	var e: DuelEngine = engine(deck(filler(["t_attach", "t_strike", "t_strike"])), deck(filler(), "pact"))
	to_combat(e)
	var charm: int = uid_in_hand(e, 0, "t_attach")
	answer(e, &"use", charm)
	eq(e.card(charm).zone, &"in_play", "attached card sits in play")
	eq(e.card(charm).attached_to, e.player(0).duelist, "attached to the duelist")
	eq(e.player(0).attachments().size(), 1, "counted as an attachment")
	answer(e, &"pass")
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike"))
	eq(e.player(1).duelist.energy, 1, "2 from the table plus 2 from the attachment")


func test_constant_power() -> void:
	var e: DuelEngine = engine(deck(filler(), "vigil", "", "", 3, "tf_constant"), deck(filler(["t_guard", "t_guard", "t_guard"]), "pact"))
	to_combat(e)
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike"))
	check(has_event(e, &"attack_declared"), "attack went out")
	eq(prompt_kind(e), &"attack_action", "no defense prompt: a stops-any guard cannot stop a focused attack")
	eq(e.player(1).duelist.energy, 3, "table 1 (same band) plus the constant +1")


func test_relic_use() -> void:
	var e: DuelEngine = engine(deck(filler(), "vigil", "", "", 3, "tf_vigil", "t_relic_use"), deck(filler(), "pact"))
	eq(prompt_kind(e), &"non_combat", "relic power offered in the Non-Combat step")
	var m: int = e.player(0).relic.uid
	answer(e, &"relic", m)
	eq(e.player(0).hand.size(), 5, "relic drew two")
	check(has_event(e, &"relic_used"), "relic_used event")
	eq(prompt_kind(e), &"declare", "once per game: no second offer")


func test_start_in_play() -> void:
	var e: DuelEngine = engine(deck(filler(["t_start_drill"])), deck(filler(), "pact"))
	eq(e.player(0).drills().size(), 1, "drill began the game in play")
	to_combat(e)
	eq(e.player(0).fervor, 1, "entering-combat effect fired")
	var fired: int = 0
	var line: String = ""
	for ev in e.events:
		if ev.type == &"trigger_fired" and e.card(int(ev.data.get("card", -1))).def.id == "t_start_drill":
			fired += 1
			line = CardText.event_line(ev, e)
	eq(fired, 1, "the drill's trigger is logged once")
	eq(line, "Test Opening Drill triggers when entering Combat.", "with the card and the moment")


func test_pay_stages() -> void:
	var e: DuelEngine = engine(deck(filler(["t_pay_art", "t_strike", "t_strike"])), deck(filler(), "pact"))
	to_combat(e)
	var deck_before: int = e.player(1).life_deck.size()
	answer(e, &"attack", uid_in_hand(e, 0, "t_pay_art"))
	eq(prompt_kind(e), &"pay", "pay prompt")
	eq(e.prompt.options.size(), 5, "0, 2, 4, 6, 8 from 8 energy")
	answer(e, &"pay", -1, 4)
	eq(e.player(0).duelist.energy, 4, "paid 4")
	eq(e.player(1).life_deck.size(), deck_before - 6, "4 base plus 2 bought")


func test_name_card() -> void:
	var e: DuelEngine = engine(deck(filler(["t_name_drill"])), deck(filler(["t_art", "t_art", "t_art"]), "pact"))
	answer(e, &"place", uid_in_hand(e, 0, "t_name_drill"))
	eq(prompt_kind(e), &"name_card", "naming prompt")
	answer(e, &"name_card", e.player(0).drills()[0].uid, "Test Art")
	check(has_event(e, &"card_named"), "card_named event")
	to_combat(e)
	answer(e, &"pass")
	check(e.prompt.find(&"attack", uid_in_hand(e, 1, "t_art")) == null, "named card locked out")


func test_copied_attack() -> void:
	var e: DuelEngine = engine(deck(filler(["t_strike_plus2", "t_strike_plus2", "t_strike_plus2"])), deck(filler(["t_copy_parry", "t_copy_parry", "t_copy_parry"]), "pact"))
	to_combat(e)
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike_plus2"))
	answer(e, &"defend", uid_in_hand(e, 1, "t_copy_parry"))
	check(has_event(e, &"attack_stopped"), "parry stopped it")
	check(e.prompt.find(&"copied_attack") != null, "copied attack offered")
	answer(e, &"copied_attack")
	check(e.player(0).duelist.energy < 7, "copied attack dealt stage damage back")


func test_prevent_all_and_no_prevent() -> void:
	var e: DuelEngine = engine(deck(filler(["t_prevent_all", "t_strike", "t_strike"])), deck(filler(["t_strike", "t_no_prevent_art", "t_art"]), "pact"))
	to_combat(e)
	answer(e, &"use", uid_in_hand(e, 0, "t_prevent_all"))
	answer(e, &"attack", uid_in_hand(e, 1, "t_strike"))
	eq(e.player(0).duelist.energy, 8, "prevented strike did nothing")
	answer(e, &"pass")
	var deck_before: int = e.player(0).life_deck.size()
	answer(e, &"attack", uid_in_hand(e, 1, "t_no_prevent_art"))
	eq(e.player(0).life_deck.size(), deck_before - 4, "unpreventable art still lands")


func test_relic_shields() -> void:
	var e: DuelEngine = engine(deck(filler(["t_jeer", "t_set_aspect", "t_strike"])), deck(filler(), "pact", "", "", 3, "tf_vigil", "t_relic_shield"))
	check(e.player(1).no_ascension_win, "relic forbids the ascension win")
	e.player(1).fervor = 2
	e.player(1).duelist.aspect = 2
	to_combat(e)
	answer(e, &"use", uid_in_hand(e, 0, "t_jeer"))
	eq(e.player(1).fervor, 2, "fervor shielded")
	check(has_event(e, &"fervor_shielded"), "fervor_shielded event")
	answer(e, &"pass")
	answer(e, &"use", uid_in_hand(e, 0, "t_set_aspect"))
	eq(e.player(1).duelist.aspect, 2, "aspect shielded")


func test_set_aspect() -> void:
	var e: DuelEngine = engine(deck(filler(["t_set_aspect", "t_strike", "t_strike"])), deck(filler(), "pact"))
	e.player(1).duelist.aspect = 3
	to_combat(e)
	answer(e, &"use", uid_in_hand(e, 0, "t_set_aspect"))
	eq(e.player(1).duelist.aspect, 1, "dropped to aspect 1")
	eq(e.player(1).duelist.energy, 5, "lost aspect resets energy")


func test_draw_until_and_draw_discard() -> void:
	var e: DuelEngine = engine(deck(filler(["t_draw_until", "t_draw_discard", "t_strike"])), deck(filler(), "pact"))
	to_combat(e)
	var refill: int = uid_in_hand(e, 0, "t_draw_until")
	answer(e, &"use", refill)
	eq(e.player(0).hand.size(), 5, "drew up to five")
	answer(e, &"pass")
	answer(e, &"use", uid_in_hand(e, 0, "t_draw_discard"))
	eq(e.card(refill).zone, &"hand", "bottom of the discard pile came back to hand")


func test_search_to_play() -> void:
	var e: DuelEngine = engine(deck(filler(["t_search_play", "t_strike", "t_strike", "t_drill_free"])), deck(filler(), "pact"))
	to_combat(e)
	answer(e, &"use", uid_in_hand(e, 0, "t_search_play"))
	take_search(e)
	eq(e.player(0).drills().size(), 1, "drill searched straight into play")


func test_attack_variants() -> void:
	var e: DuelEngine = engine(deck(filler(["t_variant_strike", "t_strike", "t_strike"]), "vigil", "pyre", "t_mastery_pyre"), deck(filler(), "pact"))
	to_combat(e)
	var deck_before: int = e.player(1).life_deck.size()
	answer(e, &"attack", uid_in_hand(e, 0, "t_variant_strike"))
	eq(e.player(1).duelist.energy, 0, "table 2 + 1 + 3 (variant) + 1 (mastery) empties 5 energy")
	eq(e.player(1).life_deck.size(), deck_before - 2, "overflow of 2 into wounds")


func test_owner_chooses_discard() -> void:
	var e: DuelEngine = engine(deck(filler(["t_owner_glare", "t_strike", "t_strike"])), deck(filler(["t_art", "t_art", "t_art"]), "pact"))
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
	var e: DuelEngine = engine(deck(filler(["t_strike", "t_strike", "t_strike"])), deck(filler(["t_stop_next", "t_stop_next", "t_stop_next"]), "pact"))
	to_combat(e)
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike"))
	answer(e, &"defend", uid_in_hand(e, 1, "t_stop_next"))
	answer(e, &"pass")
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike"))
	check(has_event(e, &"floating_stop"), "the next attack was stopped by the standing effect")
	eq(e.player(1).duelist.energy, 5, "no damage taken")


func test_only_attacks() -> void:
	var e: DuelEngine = engine(deck(filler(["t_only_attacks", "t_strike", "t_strike"])), deck(filler(["t_taunt", "t_taunt", "t_taunt"]), "pact"))
	to_combat(e)
	answer(e, &"use", uid_in_hand(e, 0, "t_only_attacks"))
	eq(e.prompt.player, 1, "fight back")
	check(e.prompt.find(&"use", uid_in_hand(e, 1, "t_taunt")) == null, "non-attack combat card locked out")
	check(e.prompt.find(&"pass") != null, "passing stays legal")


func test_energy_without_overflow() -> void:
	var e: DuelEngine = engine(deck(filler(["t_energy_noover", "t_strike", "t_strike"])), deck(filler(), "pact"))
	to_combat(e)
	var deck_before: int = e.player(1).life_deck.size()
	answer(e, &"use", uid_in_hand(e, 0, "t_energy_noover"))
	eq(e.player(1).duelist.energy, 0, "drained to zero")
	eq(e.player(1).life_deck.size(), deck_before, "no life lost past zero")
	var logged: bool = false
	for ev in e.events:
		if ev.type == &"energy_changed" and int(ev.data.get("to", -1)) == 0 and e.card(int(ev.data.get("source", -1))).def.id == "t_energy_noover":
			logged = true
	check(logged, "the energy change is logged with its source card")


func test_use_in_attack_phase() -> void:
	var e: DuelEngine = engine(deck(filler(["t_use_in_attack", "t_strike", "t_strike"])), deck(filler(), "pact"))
	to_combat(e)
	var uid: int = uid_in_hand(e, 0, "t_use_in_attack")
	check(e.prompt.find(&"use", uid) != null, "a defense flagged use_in_attack can be used in the attack phase")
	answer(e, &"use", uid)
	eq(e.player(0).fervor, 1, "its effect resolved")


# --- Choice prompts, inspection, and the rest -------------------------------

func test_may_prompt() -> void:
	var no: DuelEngine = engine(deck(filler(["t_may_search", "t_strike", "t_strike", "t_art"])), deck(filler(), "pact"))
	to_combat(no)
	answer(no, &"use", uid_in_hand(no, 0, "t_may_search"))
	eq(prompt_kind(no), &"pick_option", "a 'you may' line asks first")
	eq(no.prompt.player, 0, "the owner answers")
	var pv: PromptView = PromptView.of(no.prompt, no)
	eq(pv.title, "Test Bargain: use the optional effect?", "the prompt names the card")
	check(no.card(int(pv.context.get("source", -1))).def.id == "t_may_search", "the prompt carries the card that asked")
	var text: String = str(pv.context.get("text", ""))
	check(text.contains("Energy") and text.contains("search"), "the prompt says what a yes does: %s" % text)
	check(not text.contains(" may "), "without the 'may'")
	var skip: Dictionary = {"trigger": "before_damage", "may": true, "skip_damage": true, "op": "discard_in_play", "who": "opponent", "card_type": "drill", "all": true}
	var skip_text: String = CardText.may_text(skip)
	check(not skip_text.begins_with("Hit") and skip_text.ends_with("The attack then deals no damage."), "a fired trigger drops its head but keeps the damage cost: %s" % skip_text)
	answer(no, &"pick_option", -1, "no")
	eq(no.player(0).duelist.energy, 8, "declined: no cost paid")
	check(uid_in_hand(no, 0, "t_art") < 0, "declined: no search either")
	var yes: DuelEngine = engine(deck(filler(["t_may_search", "t_strike", "t_strike", "t_art"])), deck(filler(), "pact"))
	to_combat(yes)
	answer(yes, &"use", uid_in_hand(yes, 0, "t_may_search"))
	answer(yes, &"pick_option", -1, "yes")
	eq(yes.player(0).duelist.energy, 6, "accepted: cost paid")
	take_search(yes)
	check(uid_in_hand(yes, 0, "t_art") >= 0, "accepted: the 'then' search ran")


func test_pay_energy() -> void:
	var e: DuelEngine = engine(deck(filler(["t_pay_energy", "t_strike", "t_strike"])), deck(filler(), "pact"))
	to_combat(e)
	answer(e, &"use", uid_in_hand(e, 0, "t_pay_energy"))
	eq(prompt_kind(e), &"pay", "pay prompt")
	answer(e, &"pay", -1, 3)
	eq(e.player(0).duelist.energy, 5, "paid 3")
	eq(e.player(0).fervor, 3, "the 'then' line ran once per Energy")


func test_look_at() -> void:
	var cards: Array[String] = filler(["t_look"])
	cards.append("t_art")
	var e: DuelEngine = engine(deck(cards), deck(filler(), "pact"))
	to_combat(e)
	answer(e, &"use", uid_in_hand(e, 0, "t_look"))
	eq(prompt_kind(e), &"pick_option", "one matching card among the bottom three")
	var art: int = e.prompt.options[0].card
	eq(e.card(art).def.id, "t_art", "the art at the bottom is offered")
	answer(e, &"pick_option", art)
	eq(e.card(art).zone, &"hand", "taken into hand")


func test_search_choice() -> void:
	var e: DuelEngine = engine(deck(filler(["t_seek", "t_strike", "t_strike", "t_art", "t_art_big"])), deck(filler(), "pact"))
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
	var e: DuelEngine = engine(deck(filler(["t_skip_strike", "t_strike", "t_strike"])), deck(filler(), "pact"))
	to_combat(e)
	inject(e, 1, "t_drill_free")
	answer(e, &"attack", uid_in_hand(e, 0, "t_skip_strike"))
	eq(prompt_kind(e), &"pick_option", "successful attack offers the instead-of-damage choice")
	answer(e, &"pick_option", -1, "yes")
	eq(e.player(1).drills().size(), 0, "drill discarded")
	eq(e.player(1).duelist.energy, 5, "no damage dealt instead")


func test_stops_needed() -> void:
	var e: DuelEngine = engine(deck(filler(), "vigil", "", "", 3, "tf_double"), deck(filler(["t_parry", "t_parry", "t_parry"]), "pact"))
	to_combat(e)
	answer(e, &"power", e.player(0).duelist.uid)
	answer(e, &"defend", uid_in_hand(e, 1, "t_parry"))
	eq(prompt_kind(e), &"defense", "one stop is not enough: defend again")
	answer(e, &"defend", uid_in_hand(e, 1, "t_parry"))
	check(has_event(e, &"attack_stopped"), "two stops end it")
	eq(e.player(1).duelist.energy, 5, "no damage")


func test_ally_power_without_control() -> void:
	var e: DuelEngine = engine(deck(filler(["t_ally_free"])), deck(filler(), "pact"))
	answer(e, &"place", uid_in_hand(e, 0, "t_ally_free"))
	to_combat(e)
	var al: CardInstance = e.player(0).allies()[0]
	check(e.prompt.find(&"power", al.uid) != null, "ally power offered while the duelist is in control")
	var deck_before: int = e.player(1).life_deck.size()
	answer(e, &"power", al.uid)
	eq(e.player(1).life_deck.size(), deck_before - 1, "the ally's strike dealt its wound")


func test_life_per_opponent_seal() -> void:
	var e: DuelEngine = engine(deck(filler(["t_seal_strike", "t_strike", "t_strike"])), deck(filler(), "pact", "pyre", "t_mastery_pyre"))
	inject(e, 1, "t_seal_2")
	inject(e, 1, "t_seal_3")
	to_combat(e)
	var deck_before: int = e.player(1).life_deck.size()
	answer(e, &"attack", uid_in_hand(e, 0, "t_seal_strike"))
	eq(e.player(1).life_deck.size(), deck_before - 2, "one wound per opponent Seal")


func test_lonely_drill() -> void:
	var e: DuelEngine = engine(deck(filler(["t_lonely_drill", "t_drill_free"])), deck(filler(), "pact"))
	answer(e, &"place", uid_in_hand(e, 0, "t_lonely_drill"))
	eq(e.player(0).drills().size(), 1, "alone it stays")
	answer(e, &"place", uid_in_hand(e, 0, "t_drill_free"))
	eq(e.player(0).drills().size(), 1, "company discards it")
	eq(e.player(0).drills()[0].def.id, "t_drill_free", "the newcomer remains")


func test_unused_remain_returns() -> void:
	var e: DuelEngine = engine(deck(filler(["t_strike", "t_strike", "t_strike"])), deck(filler(["t_returning_block", "t_returning_block", "t_returning_block"]), "pact"))
	to_combat(e)
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike"))
	var b: int = uid_in_hand(e, 1, "t_returning_block")
	answer(e, &"defend", b)
	eq(e.card(b).zone, &"in_play", "stays for a second use")
	answer(e, &"pass")
	answer(e, &"pass")
	eq(e.card(b).zone, &"life_deck", "unused second use: shuffled back instead of removed")


func test_return_removed() -> void:
	var e: DuelEngine = engine(deck(filler(["t_recall", "t_strike", "t_strike"])), deck(filler(), "pact"))
	var al: CardInstance = inject(e, 0, "t_ally_squire")
	e._remove_from_game(al)
	eq(al.zone, &"removed", "ally removed")
	to_combat(e)
	answer(e, &"use", uid_in_hand(e, 0, "t_recall"))
	eq(al.zone, &"life_deck", "removed ally shuffled back")


func test_last_searched_target() -> void:
	var e: DuelEngine = engine(deck(filler(["t_heal", "t_strike", "t_strike"])), deck(filler(), "pact"))
	var al: CardInstance = inject(e, 0, "t_ally_squire")
	e._move_to_discard(al)
	to_combat(e)
	answer(e, &"use", uid_in_hand(e, 0, "t_heal"))
	eq(al.zone, &"in_play", "ally back from the discard")
	eq(al.energy, 10, "then raised to full")


func test_forbid_unless_energy() -> void:
	var e: DuelEngine = engine(deck(filler(["t_lock", "t_strike", "t_strike"])), deck(filler(), "pact"))
	to_combat(e)
	answer(e, &"use", uid_in_hand(e, 0, "t_lock"))
	eq(prompt_kind(e), &"pick_option", "choose the locked type")
	answer(e, &"pick_option", -1, "strike_cards")
	check(not e._forbidden(e.player(1), "strike_cards"), "at 5 Energy the lock does not bite")
	e.player(1).duelist.energy = 4
	check(e._forbidden(e.player(1), "strike_cards"), "below 5 Energy it does")


func test_forced_combat_from_reserve() -> void:
	var reserve: Array[String] = ["t_invite"]
	var e: DuelEngine = engine(deck(filler()), deck(filler(), "pact", "", "", 3, "tf_vigil", "t_relic", reserve))
	answer(e, &"reserve_done")
	eq(e.player(1).non_combats().size(), 1, "the summons began the game in play from the Reserve")
	check(has_event(e, &"combat_declared"), "the active player could not skip Combat")
	eq(prompt_kind(e), &"attack_action", "straight into the attack phase")


func test_promoted_if_successful() -> void:
	var e: DuelEngine = engine(deck(filler(["t_promote_drill", "t_strike_end", "t_strike"])), deck(filler(["t_parry", "t_parry", "t_parry"]), "pact"))
	answer(e, &"place", uid_in_hand(e, 0, "t_promote_drill"))
	to_combat(e)
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike_end"))
	answer(e, &"defend", uid_in_hand(e, 1, "t_parry"))
	check(has_event(e, &"attack_stopped"), "parried")
	check(has_event(e, &"combat_end"), "promoted 'if successful' line still ended Combat")


func test_draw_check_named() -> void:
	var cards: Array[String] = ["t_scry", "t_strike", "t_strike", "t_ally_squire"]
	cards.append_array(filler())
	var e: DuelEngine = engine(deck(cards), deck(filler(), "pact"))
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
		var e: DuelEngine = engine(deck(cards), deck(filler(), "pact"))
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
## used block of that school under the Life Deck.
func test_mastery_on_attack_and_blocks_to_bottom() -> void:
	for pay in [true, false]:
		var e: DuelEngine = engine(deck(filler(), "vigil", "pyre", "t_mastery_flare"), deck(filler(["t_parry", "t_parry", "t_parry"]), "pact", "tide", "t_mastery_keep"))
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
	var f: DuelEngine = engine(deck(filler(["t_strike_focused", "t_strike_focused", "t_strike_focused"]), "vigil", "pyre", "t_mastery_flare"), deck(filler(), "pact"))
	to_combat(f)
	answer(f, &"attack", uid_in_hand(f, 0, "t_strike_focused"))
	check(prompt_kind(f) != &"pick_option", "no question for an attack that is already Focused")
	var shipped: CardLibrary = CardLibrary.new()
	shipped.load_dir("res://data/cards")
	var text: String = CardText.rules_text(shipped.defs.get("pyre_mastery"))
	check(text.contains("When you perform an attack") and text.contains("bottom of your Life Deck"), "the shipped Mastery words both halves: %s" % text)


func test_wound_trigger_at_fight_back() -> void:
	# P1's deck: the wound card sits on top after the three cards drawn at Combat.
	var cards: Array[String] = ["t_strike", "t_strike", "t_strike", "t_wound_art"]
	cards.append_array(filler())
	var e: DuelEngine = engine(deck(filler(["t_art", "t_art", "t_art"])), deck(cards, "pact"))
	to_combat(e)
	answer(e, &"attack", uid_in_hand(e, 0, "t_art"))
	var wounded: bool = false
	for c in e.player(1).discard:
		if c.def.id == "t_wound_art":
			wounded = true
	check(wounded, "the wound card was flipped")
	eq(e.player(1).fervor, 2, "its effect fired at the start of the fight-back phase")


## The other wound timing: the CRD errata moves some of these to the end of the turn, after Combat
## and the Discard step, which is its own window rather than a late fight-back.
func test_wound_trigger_at_turn_end() -> void:
	var cards: Array[String] = ["t_strike", "t_strike", "t_strike", "t_late_art"]
	cards.append_array(filler())
	var e: DuelEngine = engine(deck(filler(["t_art", "t_art", "t_art"])), deck(cards, "pact"))
	to_combat(e)
	answer(e, &"attack", uid_in_hand(e, 0, "t_art"))
	var wounded: bool = false
	for c in e.player(1).discard:
		if c.def.id == "t_late_art":
			wounded = true
	check(wounded, "the wound card was flipped")
	eq(e.player(1).fervor, 0, "it has not fired yet: this is not a fight-back trigger")
	eq(e.state.turn, 1, "still the first turn")
	while e.state.turn == 1 and e.prompt != null:
		answer(e, e.prompt.options[e.prompt.options.size() - 1].type, e.prompt.options[e.prompt.options.size() - 1].card)
	eq(e.player(1).fervor, 2, "it fired as the turn ended")


func test_look_at_play_option() -> void:
	var cards: Array[String] = ["t_peek_top", "t_strike", "t_strike", "t_drill_footwork_named", "t_strike"]
	cards.append_array(filler())
	var e: DuelEngine = engine(deck(cards), deck(filler(), "pact"))
	to_combat(e)
	answer(e, &"use", uid_in_hand(e, 0, "t_peek_top"))
	eq(prompt_kind(e), &"pick_option", "one matching card in the top three")
	answer(e, &"pick_option", e.prompt.options[0].card)
	# "You may place it into play instead": taking it is not the same as playing it, so it asks.
	eq(prompt_kind(e), &"pick_option", "where it goes is a second question")
	eq(e.player(0).drills().size(), 0, "nothing is in play until that is answered")
	answer(e, &"pick_option", e.prompt.options[0].card, "play")
	eq(e.player(0).drills().size(), 1, "a yes puts the matching card into play")
	# The same look with a no leaves it in hand instead.
	var f: DuelEngine = engine(deck(cards), deck(filler(), "pact"))
	to_combat(f)
	answer(f, &"use", uid_in_hand(f, 0, "t_peek_top"))
	answer(f, &"pick_option", f.prompt.options[0].card)
	answer(f, &"pick_option", f.prompt.options[1].card, "hand")
	eq(f.player(0).drills().size(), 0, "a no keeps it off the table")
	check(uid_in_hand(f, 0, "t_drill_footwork_named") >= 0, "and puts it in hand")


func test_bond_and_unbond() -> void:
	var reserve: Array[String] = ["t_bonded_hands"]
	var e: DuelEngine = engine(deck(filler(["t_ally_left", "t_ally_right", "t_bond_rite"]), "vigil", "", "", 3, "tf_vigil", "t_relic", reserve), deck(filler(), "pact"))
	answer(e, &"reserve_done")
	answer(e, &"place", uid_in_hand(e, 0, "t_ally_left"))
	answer(e, &"place", uid_in_hand(e, 0, "t_ally_right"))
	answer(e, &"place", uid_in_hand(e, 0, "t_bond_rite"))
	to_combat(e)
	var rite: CardInstance = e.player(0).non_combats()[0]
	answer(e, &"use", rite.uid)
	eq(e.player(0).allies().size(), 1, "two Allies became one Bond")
	var bond: CardInstance = e.player(0).allies()[0]
	eq(bond.def.id, "t_bonded_hands", "the Bond card came from the Reserve")
	eq(bond.energy, 10, "at full Energy")
	eq(bond.cards_under.size(), 2, "both Allies under it")
	check(has_event(e, &"bonded"), "bonded event")
	skip_to_turn(e, 3)
	skip_to_turn(e, 5)
	eq(e.player(0).allies().size(), 2, "after two of the owner's turns the Bond burned out and both returned")
	eq(bond.zone, &"reserve", "the Bond card went back to the Reserve")


func test_search_by_effect() -> void:
	var e: DuelEngine = engine(deck(filler(["t_thief_seek", "t_strike", "t_strike"])), deck(filler(), "pact"))
	var scout: CardInstance = e._instance(lib.get_def("t_scout"), 0, &"discard")
	e.player(0).discard.append(scout)
	var taunt: CardInstance = e._instance(lib.get_def("t_taunt"), 0, &"discard")
	e.player(0).discard.append(taunt)
	to_combat(e)
	answer(e, &"use", uid_in_hand(e, 0, "t_thief_seek"))
	eq(scout.zone, &"hand", "only the card that discards from the opponent's hand matched")
	eq(taunt.zone, &"discard", "the other stayed")


func test_end_turn() -> void:
	var e: DuelEngine = engine(deck(filler(["t_end_turn", "t_strike", "t_strike"])), deck(filler(), "pact"))
	to_combat(e)
	answer(e, &"use", uid_in_hand(e, 0, "t_end_turn"))
	eq(e.state.active, 1, "the turn ended at once")
	eq(e.player(0).hand.size(), 2, "no Discard step for the user")
	eq(e.player(1).hand.size(), 6, "nor for the opponent: the three Combat draws plus their own three")


func test_declare_window() -> void:
	var reserve: Array[String] = ["t_summons"]
	var e: DuelEngine = engine(deck(filler()), deck(filler(["t_taunt", "t_taunt", "t_taunt"]), "pact", "", "", 3, "tf_vigil", "t_relic", reserve))
	answer(e, &"reserve_done")
	var herald: CardInstance = e.player(1).non_combats()[0]
	eq(herald.def.id, "t_summons", "the herald began the game in play from the Reserve")
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
	var e: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
	to_combat(e)
	eq(prompt_kind(e), &"attack_action", "at an attack decision")
	eq(e.dev_effect(0, {"op": "fervor", "amount": 2}), "", "accepted")
	eq(e.player(0).fervor, 2, "fervor raised")
	eq(prompt_kind(e), &"attack_action", "the same decision is back")
	eq(e.dev_effect(0, {"op": "fervor", "amount": 3}), "", "accepted again")
	eq(e.player(0).duelist.aspect, 2, "reaching 5 Fervor rose an aspect through the normal path")
	eq(e.player(0).fervor, 0, "and reset Fervor")
	var life_before: int = e.player(1).life_deck.size()
	eq(e.dev_effect(0, {"op": "discard_life", "amount": 2, "who": "opponent"}), "", "opponent-targeted effect")
	eq(e.player(1).life_deck.size(), life_before - 2, "the rival took two wounds")
	check(has_event(e, &"dev"), "the log gets a dev line")
	eq(e.dev_effect(0, {"op": "end_turn"}), "", "end turn accepted")
	eq(e.state.active, 1, "the turn passed")


## Generated rules text: conditions stay attached, same-trigger lines fold, both-player effects
## read once, and aspect cards show constants and every part of a Power.
func test_card_text_wording() -> void:
	var plain_gain: Dictionary = {"op": "energy", "amount": 3}
	eq(CardText.effect_text(plain_gain), "Gain 3 Energy.", "an unconditional line reads bare")
	var hit: Dictionary = {"trigger": "if_successful", "op": "fervor", "amount": 1}
	eq(CardText.effect_text(hit), "Hit: Raise your Fervor 1.", "Hit label")
	var hit_ally: Dictionary = {"trigger": "if_successful", "op": "fervor", "amount": 1, "when": {"allies_min": 1}}
	eq(CardText.effect_text(hit_ally), "Hit: If you have an Ally in play, raise your Fervor 1.", "other conditions stay as sentences")
	var entering: Dictionary = {"trigger": "entering_combat", "op": "energy", "amount": 5}
	eq(CardText.effect_text(entering), "When entering Combat, gain 5 Energy.", "a triggered line")
	var remain: CardDef = CardDef.from_dict({"id": "r", "title": "R", "type": "strike", "attack": {"kind": "strike"}, "remain": 1})
	eq(CardText.rules_text(remain), "Strike.\nRemain 1.", "Remain shorthand")
	var remain2: CardDef = CardDef.from_dict({"id": "r2", "title": "R2", "type": "strike", "attack": {"kind": "strike"}, "remain_when": {"when": {"allies_min": 2}, "remain": 2}})
	eq(CardText.rules_text(remain2), "Strike.\nIf you have 2 or more Allies in play, Remain 2.", "Remain keeps its capital mid-sentence")
	var pair: Array = [
		{"trigger": "entering_combat", "op": "fervor", "who": "opponent", "amount": -2},
		{"trigger": "entering_combat", "op": "energy", "amount": 2, "target": "duelist"},
	]
	eq(CardText.effects_text(pair), PackedStringArray(["When entering Combat, lower your opponent's Fervor 2 and gain 2 Energy."]), "same trigger folds into one sentence")
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
	var may: Dictionary = {"op": "energy", "who": "opponent", "amount": -4, "may": true}
	eq(CardText.effect_text(may), "You may have your opponent lose 4 Energy.", "a may on the opponent reads as a choice")
	eq(CardText.effect_text({"trigger": "on_place", "op": "name_card"}), "When placed, name a card. Neither player may play or use it while this is in play.", "no doubled lead-in")
	var uses: Array = [{"trigger": "use", "op": "discard_hand", "amount": 1, "random": false}, {"trigger": "use", "op": "draw", "amount": 2}]
	eq(CardText.effects_text(uses), PackedStringArray(["Use in Combat: Discard a card from your hand. Draw 2 cards."]), "uses share one label")
	var f: CardDef = CardDef.from_dict({"id": "x", "title": "X", "type": "personality", "aspects": [
		{"aspect": 1, "surge": 1, "might": [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
			"power": {"attack": {"kind": "strike", "stages": 3}, "effects": [{"op": "energy", "amount": 5}, {"trigger": "if_stopped", "op": "draw", "amount": 1}], "uses": 2},
			"constant": {"first_styled_unstoppable": true, "forbid_opponent": ["art_attacks"]}, "shield": "strike"},
	]})
	var lines: PackedStringArray = CardText.aspect_text(f, 1)
	eq(lines.size(), 3, "power, constant, and shield lines")
	eq(lines[0], "Power: Strike doing +3 Energy. Gain 5 Energy. If stopped, draw a card. May be used twice per Combat.", "every part of the Power")
	eq(lines[1], "Constant: Your first attack each Combat with a school card cannot be stopped. Your opponent may not perform Arts.", "constants render")
	eq(lines[2], "Defense Shield: stops the first unstopped Strike each Combat.", "shield renders")
	# An Ally who answers from the side has no other way to tell the player she may be used.
	var aside: CardDef = CardDef.from_dict({"id": "y", "title": "Y", "type": "personality", "aspects": [
		{"aspect": 1, "surge": 1, "might": [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
			"power": {"defense": {"stops": "strike"}, "no_control_needed": true}},
	]})
	check(CardText.aspect_text(aside, 1)[0].ends_with("This personality does not have to be in control to use this Power."),
		"a Power usable from the side says so: %s" % CardText.aspect_text(aside, 1)[0])
	var relic: CardDef = CardDef.from_dict({"id": "m", "title": "M", "type": "relic", "reserve_size": 13, "uses_per_game": 2, "limit_per_deck": 1,
		"effects": [{"trigger": "relic_use", "op": "forbid", "who": "opponent", "what": "mastery", "duration": "turn"}]})
	eq(CardText.rules_text(relic), "Reserve 13.\nTwice per game, during your Non-Combat step: Your opponent may not use a Mastery this turn.\nLimit 1 per deck.", "relic text in reading order")
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
		var phrase_only: Array[String] = ["Stops", "from the game", "Remain", "Hit", "aspect", "cannot be prevented", "Cannot be stopped", "Signature", "Limit", "Constant"]
		check(r.search(key) != null or key in phrase_only, "pattern finds its own key: %s" % key)
	var r: RegEx = RegEx.new()
	r.compile(str(CardText.KEYWORDS[1]["pattern"]))
	check(r.search("Your opponent removes all Drills in play from the game.") != null, "removal phrase matches a generated sentence")
	r.compile(str(CardText.KEYWORDS[2]["pattern"]))
	check(r.search("Remain 1.") != null, "remain phrase matches")
	r.compile(str(CardText.KEYWORDS[3]["pattern"]))
	check(r.search("Hit: Raise your Fervor 1.") != null, "hit label matches")


# --- Timing windows and outcome data ------------------------------------------

## A spent Duelist may hand the attack phase to an Ally; the Ally then performs the attack.
func test_attacker_ally_control() -> void:
	var e: DuelEngine = engine(deck(filler(["t_ally_squire", "t_strike", "t_strike"])), deck(filler(), "pact"))
	answer(e, &"place", uid_in_hand(e, 0, "t_ally_squire"))
	var ally: CardInstance = e.player(0).allies()[0]
	eq(prompt_kind(e), &"declare", "nothing else to place: at the Declare step")
	e.player(0).duelist.energy = 1
	answer(e, &"declare")
	eq(prompt_kind(e), &"control", "the attacker chooses who is in control at Energy 1")
	eq(e.prompt.player, 0, "it is the attacker's choice")
	eq(str(e.prompt.context.get("role", "")), "attacker", "context names the role")
	answer(e, &"control", ally.uid)
	eq(prompt_kind(e), &"attack_action", "then the attack phase")
	eq(e.player(0).in_control(), ally, "the Ally is in control")
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike"))
	eq(int(e.state.last_attack.get("performer", -1)), ally.uid, "the Ally performed the attack")
	eq(prompt_kind(e), &"attack_action", "the fight back follows")
	eq(e.prompt.player, 1, "the rival's phase, no control prompt at Energy 5")


## A Non-Combat in play may stop an attack, and is spent by it like any other use.
func test_non_combat_defense_is_spent() -> void:
	var e: DuelEngine = engine(deck(filler(["t_strike", "t_strike", "t_strike"])), deck(filler(), "pact"))
	var block: CardInstance = inject(e, 1, "t_noncombat_parry")
	to_combat(e)
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike"))
	eq(prompt_kind(e), &"defense", "defense prompt")
	check(e.prompt.find(&"defend", block.uid) != null, "the Non-Combat in play is a legal defense")
	answer(e, &"defend", block.uid)
	check(has_event(e, &"attack_stopped"), "it stopped the Strike")
	eq(e.player(1).fervor, 1, "its own effect resolved")
	eq(block.zone, &"discard", "and the card is spent")
	eq(e.player(1).non_combats().size(), 0, "no longer in play")


## After a Final Strike the player cannot defend either; the attack goes straight to the shields.
func test_no_defense_after_final_strike() -> void:
	var e: DuelEngine = engine(deck(filler(["t_taunt", "t_parry", "t_parry"])), deck(filler(["t_strike", "t_strike", "t_strike"]), "pact"))
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
	var e: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
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


## A Relic whose power is a Combat action is offered in place of an attack, not in the Non-Combat step.
func test_relic_in_combat() -> void:
	var e: DuelEngine = engine(deck(filler(), "vigil", "", "", 3, "tf_vigil", "t_relic_combat"), deck(filler(), "pact"))
	eq(prompt_kind(e), &"declare", "nothing to place and no Relic offer in the Non-Combat step")
	answer(e, &"declare")
	var m: int = e.player(0).relic.uid
	check(e.prompt.find(&"use", m) != null, "the Relic is an attack-phase action")
	answer(e, &"use", m)
	eq(e.player(0).hand.size(), 5, "the Relic drew two")
	check(has_event(e, &"relic_used"), "relic_used event")
	eq(prompt_kind(e), &"attack_action", "used in place of an attack: fight back")
	eq(e.prompt.player, 1, "the rival's phase")
	answer(e, &"pass")
	check(e.prompt.find(&"use", m) == null, "once per game")


## Battle step 11: an attacking Ally with the capture trait may take a Seal instead of dealing damage.
func test_capture_instead_of_damage() -> void:
	var e: DuelEngine = engine(deck(filler(["t_ally_captor"])), deck(filler(), "pact"))
	answer(e, &"place", uid_in_hand(e, 0, "t_ally_captor"))
	var seal: CardInstance = inject(e, 1, "t_seal_1")
	to_combat(e)
	var al: CardInstance = e.player(0).allies()[0]
	var deck_before: int = e.player(1).life_deck.size()
	answer(e, &"power", al.uid)
	eq(prompt_kind(e), &"capture_instead", "the capturing Ally is asked")
	eq(e.prompt.player, 0, "by its owner")
	check(e.prompt.find(&"deal_damage") != null, "dealing the damage stays an option")
	answer(e, &"capture", seal.uid)
	if prompt_kind(e) == &"pick_option":
		answer(e, &"pick_option", -1, "no")   # the captured Seal's power is optional
	eq(e.player(0).seals().size(), 1, "the Seal changed hands")
	eq(e.player(1).duelist.energy, 5, "no Energy damage")
	eq(e.player(1).life_deck.size(), deck_before, "no wounds")
	check(has_event(e, &"capture_instead"), "capture_instead event")
	eq(prompt_kind(e), &"attack_action", "battle over")
	al.power_used_combat = -1   # Ally powers are once per Combat; reopen it to try the other branch
	inject(e, 1, "t_seal_2")
	answer(e, &"pass")
	answer(e, &"power", al.uid)
	answer(e, &"deal_damage")
	eq(e.player(1).life_deck.size(), deck_before - 1, "the second time the Ally dealt its wound")


## The outcome of an attack outlives the attack in the view, on both seats and over the wire.
func test_last_attack_in_view() -> void:
	var e: DuelEngine = engine(deck(filler(["t_strike", "t_parry", "t_parry"])), deck(filler(["t_strike", "t_strike", "t_strike"]), "pact"))
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
	var e: DuelEngine = engine(deck(filler(["t_strike", "t_parry", "t_taunt"])), deck(filler(["t_strike", "t_counter", "t_counter"]), "pact"))
	to_combat(e)
	var begin: String = ""
	for ev in e.events:
		if ev.type == &"combat_begin":
			begin = CardText.event_line(ev, e, 0)
	eq(begin, "Combat: Test vigil attacks first.", "Combat opening line")
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike"))
	var lines: Array[String] = []
	for ev in e.events:
		if ev.type == &"attack_end":
			lines.append(CardText.event_line(ev, e, 1))
	eq(lines.size(), 1, "one attack_end line")
	check(lines[0].begins_with("Test vigil's Test Strike lands for "), "landing line names the card and the damage: %s" % lines[0])
	answer(e, &"attack", uid_in_hand(e, 1, "t_strike"))
	answer(e, &"defend", uid_in_hand(e, 0, "t_parry"))
	lines.clear()
	for ev in e.events:
		if ev.type == &"attack_end":
			lines.append(CardText.event_line(ev, e, 0))
	eq(lines[lines.size() - 1], "Test pact's Test Strike is stopped by Test Parry.", "stopped line names the defense")
	answer(e, &"use", uid_in_hand(e, 0, "t_taunt"))
	eq(prompt_kind(e), &"respond", "counter window")
	eq(CardText.prompt_title(e.prompt), "Counter Test Taunt?", "the respond prompt names the card")
	eq(int(e.prompt.context.get("source", -1)), e.card(int(e.prompt.context["card"])).uid, "and carries it as the source")
	var pending_uid: int = int(e.prompt.context["card"])
	for seat in range(2):
		var pending_view: SeatView = SeatView.of(e, seat)
		eq(pending_view.pending_card, pending_uid, "both seats see the announced pending card")
		check(not pending_view.card(pending_uid).hidden(), "announced card face is public during its response window")
		eq(SeatView.from_dict(pending_view.to_dict()).pending_card, pending_uid, "pending card survives network serialization")
		for other_uid in pending_view.player(1 - seat).hand:
			if other_uid != pending_uid:
				check(pending_view.card(other_uid).hidden(), "unannounced opponent hand cards remain private")
	answer(e, &"decline")
	eq(SeatView.of(e, 0).pending_card, -1, "pending card clears after the response")
	eq(SeatView.from_dict({}).pending_card, -1, "older views default to no pending card")
	var ctrl: Prompt = Prompt.new()
	ctrl.kind = &"control"
	ctrl.context = {"role": "attacker"}
	eq(CardText.prompt_title(ctrl), "Who attacks? Your Duelist is spent", "attacker control title")
	var crit: Prompt = Prompt.new()
	crit.kind = &"critical"
	crit.context = {"life_dealt": 6}
	eq(CardText.prompt_title(crit), "Critical damage (6 wounds): choose one", "critical title carries the count")
	var pick: Prompt = Prompt.new()
	pick.kind = &"pick_option"
	pick.context = {"purpose": "capture", "card_title": "Test Thief"}
	eq(CardText.prompt_title(pick), "Test Thief: capture which Seal?", "purpose-driven pick title")


## A constant power's keyed lists fire at their key: turn start, entering Combat, and each attack.
func test_constant_keyed_triggers() -> void:
	var e: DuelEngine = engine(deck(filler(), "vigil", "", "", 3, "tf_grinder"), deck(filler(), "pact"))
	eq(e.player(0).fervor, 1, "turn-start constant fired on turn 1")
	to_combat(e)
	eq(e.player(0).fervor, 2, "entering-Combat constant fired for the active player")
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike"))
	eq(e.player(0).fervor, 3, "on-attack constant fired with the Strike")
	answer(e, &"pass")
	answer(e, &"pass")
	skip_to_turn(e, 3)
	eq(e.player(0).fervor, 4, "turn-start constant fired again on the owner's next turn, not the rival's")


## A Seal's text (no trigger of its own) is its placement power; a captor may use it on capture.
func test_seal_power_on_place_and_capture() -> void:
	var e: DuelEngine = engine(deck(filler(["t_seal_plain"])), deck(filler(), "pact"))
	answer(e, &"place", uid_in_hand(e, 0, "t_seal_plain"))
	eq(e.player(0).fervor, 1, "the placed Seal's power fired")
	eq(e.player(0).hand.size(), 3, "both lines of it (drew one after placing one)")
	var c: DuelEngine = engine(deck(filler(["t_strike_wound", "t_strike_wound", "t_strike_wound"])), deck(filler([], 20), "pact"))
	var t: CardInstance = inject(c, 1, "t_seal_plain")
	to_combat(c)
	answer(c, &"attack", uid_in_hand(c, 0, "t_strike_wound"))
	eq(prompt_kind(c), &"critical", "five wounds: critical damage")
	answer(c, &"capture", t.uid)
	eq(t.controller, 0, "captured")
	eq(prompt_kind(c), &"pick_option", "the captor is asked about the Seal's power")
	check(bool(c.prompt.context.get("may", false)), "as a may question")
	answer(c, &"pick_option", -1, "yes")
	eq(c.player(0).fervor, 1, "the power resolved for the captor")
	eq(prompt_kind(c), &"attack_action", "and the battle went on")


## A Non-Combat used from play as an attack action does its effect once and is discarded.
func test_used_non_combat_is_spent() -> void:
	var e: DuelEngine = engine(deck(filler(["t_strike", "t_strike", "t_strike"])), deck(filler(), "pact"))
	var study: CardInstance = inject(e, 0, "t_noncombat_draw")
	to_combat(e)
	var hand_before: int = e.player(0).hand.size()
	check(e.prompt.find(&"use", study.uid) != null, "the Non-Combat in play can be used")
	answer(e, &"use", study.uid)
	eq(e.player(0).hand.size(), hand_before + 2, "its effect resolved")
	eq(study.zone, &"discard", "and the card is spent")
	eq(e.player(0).non_combats().size(), 0, "no longer in play")


func to_discard(e: DuelEngine, player: int, id: String) -> CardInstance:
	var c: CardInstance = e._instance(lib.get_def(id), player, &"discard")
	e.player(player).discard.append(c)
	return c


## Drawing from the discard pile can check the card's school, and an either-or effect runs its
## second half on a no.
func test_discard_draw_check_and_otherwise() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
	to_discard(e, 0, "t_drill_strike")
	to_discard(e, 0, "t_art")
	var draw: Dictionary = {"op": "draw_discard", "amount": 1, "from": "bottom", "if_school": "pyre", "effects": [{"op": "fervor", "amount": 1}]}
	e.dev_effect(0, draw)
	eq(e.player(0).fervor, 1, "the bottom card was Pyre, so the follow-up ran")
	e.dev_effect(0, draw)
	eq(e.player(0).fervor, 1, "the next one was not")
	eq(e.player(0).discard.size(), 0, "both were drawn")
	e.player(1).fervor = 3
	e.dev_effect(0, {"may": true, "op": "fervor", "amount": 2, "otherwise": [{"op": "fervor", "who": "opponent", "amount": -2}]})
	answer(e, &"pick_option", -1, "no")
	eq(e.player(0).fervor, 1, "a no leaves the first half undone")
	eq(e.player(1).fervor, 1, "and does the second")
	check(CardText.effect_text({"may": true, "op": "fervor", "amount": 2, "otherwise": [{"op": "fervor", "who": "opponent", "amount": -2}]}).contains("If you do not"), "the text says so")


## Chosen cards go from the discard pile under the Life Deck, and a card can be placed from hand.
func test_search_to_deck_and_from_hand() -> void:
	var e: DuelEngine = engine(deck(filler(["t_noncombat_draw", "t_drill_strike"])), deck(filler(), "pact"))
	var a: CardInstance = to_discard(e, 0, "t_art")
	to_discard(e, 0, "t_strike")
	var deck_before: int = e.player(0).life_deck.size()
	e.dev_effect(0, {"op": "search", "source": "discard", "amount": 2, "to": "deck_bottom"})
	eq(prompt_kind(e), &"pick_option", "two different cards, so the owner picks")
	answer(e, &"pick_option", a.uid)
	if prompt_kind(e) == &"pick_option" and bool(e.prompt.context.get("search", false)):
		answer(e, &"pick_none")
	eq(a.zone, &"life_deck", "the picked card went under the Life Deck")
	eq(e.player(0).life_deck.size(), deck_before + 1, "only the picked one")
	eq(e.player(0).life_deck.back(), a, "at the bottom")
	var study: int = uid_in_hand(e, 0, "t_noncombat_draw")
	e.dev_effect(0, {"op": "search", "source": "hand", "card_type": "non_combat_any", "to": "play"})
	eq(prompt_kind(e), &"pick_option", "a Non-Combat and a Drill in hand: a choice")
	answer(e, &"pick_option", study)
	eq(e.card(study).zone, &"in_play", "placed from hand")


## Grounds can cap an Fervor gain, a Drill can guard Seals, and a card can stay out of the
## removed pile while a Seal is in play.
func test_fervor_cap_seal_guard_and_kept_card() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
	var field: CardInstance = e._instance(lib.get_def("t_grounds_cap"), 0, &"grounds")
	e.state.grounds = field
	e.dev_effect(0, {"op": "fervor", "amount": 3})
	eq(e.player(0).fervor, 1, "a gain of 3 under the cap is 1")
	var t: CardInstance = inject(e, 1, "t_seal_plain")
	inject(e, 1, "t_drill_keeper")
	e.dev_effect(0, {"op": "capture_seal"})
	eq(t.controller, 1, "a guarded Seal is not captured")
	var kept: CardInstance = inject(e, 0, "t_noncombat_kept")
	to_combat(e)
	answer(e, &"use", kept.uid)
	eq(kept.zone, &"discard", "discarded, not removed, while the Seal is in play")


## A Non-Combat in play can answer a successful attack, and an Art can count a set's Seals.
func test_success_non_combat_and_set_seal_damage() -> void:
	var e: DuelEngine = engine(deck(filler(["t_art_set", "t_art_set", "t_art_set"])), deck(filler([], 30), "pact"))
	var eyes: CardInstance = inject(e, 0, "t_noncombat_eyes")
	inject(e, 1, "t_seal_plain")
	to_combat(e)
	var life_before: int = e.player(1).life_deck.size()
	answer(e, &"attack", uid_in_hand(e, 0, "t_art_set"))
	var guard: int = 0
	while e.prompt != null and not bool(e.prompt.context.get("may", false)) and e.prompt.kind != &"attack_action" and guard < 10:
		guard += 1
		for quiet in [&"no_defense", &"no_endure", &"no_critical", &"target"]:
			var opt: Command = e.prompt.find(quiet)
			if opt != null:
				e.submit(opt)
				break
	eq(life_before - e.player(1).life_deck.size(), 2, "1 printed wound plus 1 for the Seal in play")
	check(e.prompt != null and bool(e.prompt.context.get("may", false)), "the Non-Combat asks after the Art lands")
	answer(e, &"pick_option", -1, "yes")
	eq(e.player(0).fervor, 1, "its effect ran")
	eq(eyes.zone, &"discard", "and it spent itself")


## The Root house deck is legal at 90 cards with no Relic.
func test_root_deck_is_legal() -> void:
	var d: DeckList = DeckList.load_from("res://data/decks/root_seals.json")
	eq(d.total_cards(), 90, "84 life cards, five aspects and the Mastery")
	eq(", ".join(DeckValidator.validate(d, shipped_library())), "", "no validator problems")


## The Construct deck runs four aspects and no Relic.
func test_automaton_deck_is_legal() -> void:
	var d: DeckList = DeckList.load_from("res://data/decks/shade_salvage.json")
	eq(d.total_cards(), 85, "80 life cards, four aspects and the Mastery")
	eq(", ".join(DeckValidator.validate(d, shipped_library())), "", "no validator problems")


# --- Construct rules ------------------------------------------------------

## The Drill pays +1 wound to anyone and +2 to a personality carrying the keyword.
func test_a_drill_can_pay_more_for_its_own_kind() -> void:
	for pair in [["tf_vigil", 5], ["tf_machine", 6]]:
		var e: DuelEngine = engine(deck(filler(["t_drill_assembly", "t_art", "t_art", "t_art"]), "vigil", "", "", 3, str(pair[0])), deck(filler(), "pact"))
		answer(e, &"place", uid_in_hand(e, 0, "t_drill_assembly"))
		to_combat(e)
		var before: int = e.player(1).life_deck.size()
		answer(e, &"attack", uid_in_hand(e, 0, "t_art"))
		eq(before - e.player(1).life_deck.size(), int(pair[1]), "%s took %d wounds" % [str(pair[0]), int(pair[1])])


## "+1 wound for each Construct personality in play" counts both sides, because the card says
## what a personality is, not whose it is.
func test_a_keyword_count_reads_both_sides() -> void:
	var e: DuelEngine = engine(deck(filler(), "vigil", "", "", 3, "tf_machine"), deck(filler(), "pact"))
	eq(e.tag_count("construct"), 1, "one Construct personality to start")
	inject(e, 0, "t_ally_cog")
	eq(e.tag_count("construct"), 2, "the Ally is one too")
	to_combat(e)
	var before: int = e.player(1).life_deck.size()
	answer(e, &"power", e.player(0).duelist.uid)
	eq(before - e.player(1).life_deck.size(), 3, "1 printed plus 2 Construct")


## A Drill that shuts the rival's following out of play.
func test_a_drill_can_lock_allies_out() -> void:
	var e: DuelEngine = engine(deck(filler(["t_drill_lockout"])), deck(filler(["t_ally_squire"]), "pact"))
	answer(e, &"place", uid_in_hand(e, 0, "t_drill_lockout"))
	to_combat(e)
	answer(e, &"pass")
	answer(e, &"pass")
	skip_to_turn(e, 2)
	check(e.prompt.find(&"place", uid_in_hand(e, 1, "t_ally_squire")) == null, "the Drill keeps the Ally out")


## "Put them into play at their highest Energy": the search takes two and both arrive full.
func test_a_search_can_arrive_at_full_energy() -> void:
	var e: DuelEngine = engine(deck(filler(["t_retinue"])), deck(filler(), "pact"))
	var squire: CardInstance = to_deck(e, 0, "t_ally_squire")
	var kin: CardInstance = to_deck(e, 0, "t_ally_kin")
	to_combat(e)
	answer(e, &"use", uid_in_hand(e, 0, "t_retinue"))
	eq(prompt_kind(e), &"pick_option", "the search asks")
	answer(e, &"pick_option", squire.uid)
	answer(e, &"pick_option", kin.uid)
	eq(e.player(0).allies().size(), 2, "both came into play")
	eq(squire.energy, CardInstance.MAX_STAGE, "at full Energy")
	eq(kin.energy, CardInstance.MAX_STAGE, "both of them")


## A payment can buy Energy damage instead of wounds.
func test_energy_paid_can_buy_energy_damage() -> void:
	var e: DuelEngine = engine(deck(filler(["t_gathering_dark"])), deck(filler(), "pact"))
	to_combat(e)
	answer(e, &"attack", uid_in_hand(e, 0, "t_gathering_dark"))
	eq(prompt_kind(e), &"pay", "pay prompt")
	answer(e, &"pay", -1, 3)
	eq(e.player(0).duelist.energy, 5, "paid 3 of 8")
	# 1 printed Energy of damage and 3 bought, off a defender sitting at 5.
	eq(e.player(1).duelist.energy, 1, "1 printed and 3 bought")


## A Drill that raises the end-of-turn hand limit.
func test_a_drill_can_raise_the_hand_limit() -> void:
	var e: DuelEngine = engine(deck(filler(["t_drill_composure"])), deck(filler(), "pact"))
	answer(e, &"place", uid_in_hand(e, 0, "t_drill_composure"))
	to_combat(e)
	answer(e, &"pass")
	answer(e, &"pass")
	while e.prompt != null and e.prompt.kind == &"keep" and e.prompt.player == 1:
		answer(e, &"discard_all")
	check(e.player(0).hand.size() <= 2, "kept no more than two")
	check(e.player(0).hand.size() == mini(2, e.player(0).hand.size()), "and was not asked to cut to one")


## A Drill answers a successful attack, and only once in a Combat.
func test_a_drill_answers_one_successful_attack_a_combat() -> void:
	var e: DuelEngine = engine(deck(filler(["t_drill_takedown"])), deck(filler(), "pact"))
	answer(e, &"place", uid_in_hand(e, 0, "t_drill_takedown"))
	to_combat(e)
	var before: int = e.player(0).hand.size()
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike"))
	eq(prompt_kind(e), &"pick_option", "the Drill asks first")
	answer(e, &"pick_option", -1, "yes")
	eq(e.player(0).hand.size(), before, "the Strike left the hand and the Drill put one back")
	answer(e, &"pass")
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike"))
	eq(e.player(0).hand.size(), before - 1, "the second attack got nothing")
	# Declining does not spend the Combat's one use: the card says "you may", and the once only
	# goes when it is taken.
	var d: DuelEngine = engine(deck(filler(["t_drill_takedown"])), deck(filler(), "pact"))
	answer(d, &"place", uid_in_hand(d, 0, "t_drill_takedown"))
	to_combat(d)
	answer(d, &"attack", uid_in_hand(d, 0, "t_strike"))
	answer(d, &"pick_option", -1, "no")
	answer(d, &"pass")
	var held: int = d.player(0).hand.size()
	answer(d, &"attack", uid_in_hand(d, 0, "t_strike"))
	eq(prompt_kind(d), &"pick_option", "still on offer after a decline")
	answer(d, &"pick_option", -1, "yes")
	eq(d.player(0).hand.size(), held, "and it draws this time")


## "No modifiers are added to Strikes performed against her": the attacker's own bonuses drop,
## and only for that kind.
func test_no_modifiers_are_added_against_the_machine() -> void:
	var e: DuelEngine = engine(deck(filler(["t_drill_assembly", "t_strike", "t_art"])), deck(filler(), "pact", "", "", 3, "tf_machine"))
	answer(e, &"place", uid_in_hand(e, 0, "t_drill_assembly"))
	e.player(1).duelist.aspect = 2
	to_combat(e)
	var forecasts: Dictionary = e.attack_forecasts(0)
	var strike: Dictionary = forecasts.get(uid_in_hand(e, 0, "t_strike"), {})
	var art: Dictionary = forecasts.get(uid_in_hand(e, 0, "t_art"), {})
	check(not strike.is_empty() and not art.is_empty(), "both attacks are forecast")
	eq(int(strike.get("life", -1)), 0, "the Drill's wound was blanked on the Strike")
	eq(int(art.get("life", -1)), 5, "and still applies to an Art, which the constant does not name")


## A card may read another card by title, wherever it sits in play.
func test_a_power_can_read_another_card_by_title() -> void:
	for pair in [[false, 2], [true, 6]]:
		var e: DuelEngine = engine(deck(filler(), "vigil", "", "", 3, "tf_machine"), deck(filler(), "pact"))
		e.player(0).duelist.aspect = 3
		if bool(pair[0]):
			inject(e, 0, "t_relay")
		to_combat(e)
		var before: int = e.player(1).life_deck.size()
		answer(e, &"power", e.player(0).duelist.uid)
		eq(before - e.player(1).life_deck.size(), int(pair[1]), "%s the named card in play" % ("with" if bool(pair[0]) else "without"))


## The CRD errata for "Vegeta Scans The City" makes the card an answer to the win itself, so the
## Ascension win opens a window for it and falls through when nothing answers.
func test_a_card_can_answer_an_ascension_win() -> void:
	for pair in [[true, -1], [false, 0]]:
		var e: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
		if bool(pair[0]):
			inject(e, 1, "t_reckoning")
		e.player(0).duelist.aspect = 3
		e.player(0).fervor = 4
		e._change_fervor(e.player(0), 1, 0)
		if bool(pair[0]):
			eq(prompt_kind(e), &"respond", "the rival is asked before the win lands")
			eq(str(e.prompt.context.get("mode", "")), "ascension", "and told what it is answering")
			answer(e, &"use", e.player(1).non_combats()[0].uid)
			eq(e.player(0).duelist.aspect, 3, "knocked off the top Aspect, then climbed straight back")
		eq(e.state.winner, int(pair[1]), "won by Ascension only when nothing answered")
	# Declining the window is still a win.
	var d: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
	inject(d, 1, "t_reckoning")
	d.player(0).duelist.aspect = 3
	d.player(0).fervor = 4
	d._change_fervor(d.player(0), 1, 0)
	answer(d, &"decline")
	eq(d.state.winner, 0, "declining lets it through")


## "Set all of their personalities to N" reaches the Allies, not only whoever holds Combat.
func test_set_energy_can_reach_every_personality() -> void:
	var e: DuelEngine = engine(deck(filler(["t_levelling"])), deck(filler(), "pact"))
	var ally: CardInstance = inject(e, 1, "t_ally_squire")
	ally.energy = 9
	e.player(1).duelist.energy = 9
	to_combat(e)
	answer(e, &"use", uid_in_hand(e, 0, "t_levelling"))
	eq(e.player(1).duelist.energy, 4, "the duelist was set")
	eq(ally.energy, 4, "and so was the Ally")


## "Place them on top of your Life Deck": the last card picked is the one drawn first.
func test_a_search_can_stack_the_deck() -> void:
	var e: DuelEngine = engine(deck(filler(["t_levelling", "t_recall_top"])), deck(filler(), "pact"))
	var first: CardInstance = e._instance(lib.get_def("t_art"), 0, &"discard")
	var second: CardInstance = e._instance(lib.get_def("t_parry"), 0, &"discard")
	e.player(0).discard.append(first)
	e.player(0).discard.append(second)
	to_combat(e)
	answer(e, &"use", uid_in_hand(e, 0, "t_recall_top"))
	answer(e, &"pick_option", first.uid)
	answer(e, &"pick_option", second.uid)
	eq(e.player(0).life_deck[0].uid, second.uid, "the last pick sits on top")
	eq(e.player(0).life_deck[1].uid, first.uid, "the first pick under it")


## Beginning-of-turn lines belong to their own turn unless the card says every turn.
func test_beginning_of_turn_runs_for_both_players_when_the_card_says_so() -> void:
	var e: DuelEngine = engine(deck(filler(["t_drill_every_turn"])), deck(filler(), "pact"))
	answer(e, &"place", uid_in_hand(e, 0, "t_drill_every_turn"))
	var after_place: int = e.player(0).fervor
	to_combat(e)
	answer(e, &"pass")
	answer(e, &"pass")
	skip_to_turn(e, 2)
	eq(e.player(0).fervor, after_place + 1, "it fired on the rival's turn too")
	skip_to_turn(e, 3)
	eq(e.player(0).fervor, after_place + 2, "and again on its owner's")


## "Physical attack doing three times the Base Damage." The multiplier rides on the attack itself,
## not on a modifier, and it lands after the additions the way a modifier's would.
func test_an_attack_can_multiply_the_base_damage() -> void:
	var e: DuelEngine = engine(deck(filler(["t_triple_kick", "t_strike"])), deck(filler(), "pact"))
	to_combat(e)
	var forecasts: Dictionary = e.attack_forecasts(0)
	var plain: Dictionary = forecasts.get(uid_in_hand(e, 0, "t_strike"), {})
	var tripled: Dictionary = forecasts.get(uid_in_hand(e, 0, "t_triple_kick"), {})
	check(not plain.is_empty() and not tripled.is_empty(), "both attacks are forecast")
	if plain.is_empty() or tripled.is_empty():
		return
	var base: int = int(plain.get("stages", 0))
	check(base > 0, "the plain Strike does Energy damage to multiply")
	eq(int(tripled.get("stages", 0)), base * 3, "three times the Base Damage")


## "Stops a successful energy or physical attack." It is barred from the ordinary defense window
## and offered in its own, after the attack is already through.
func test_a_card_can_stop_an_attack_that_already_succeeded() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(["t_parry"]), "pact"))
	to_combat(e)
	var truce: CardInstance = to_hand(e, 1, "t_late_truce")
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike"))
	# The ordinary window must not offer it: it names its own timing. A real block is in hand, so
	# that window opens on its own account.
	eq(prompt_kind(e), &"defense", "the ordinary defense window opens first")
	check(not bool(e.prompt.context.get("late", false)), "and it is the ordinary one")
	check(e.prompt.find(&"defend", truce.uid) == null, "the truce is not offered before the attack resolves")
	answer(e, &"no_defense")
	eq(prompt_kind(e), &"defense", "the late window opens once the attack is through")
	check(bool(e.prompt.context.get("late", false)), "and it says it is the late one")
	var before: int = e.player(1).life_deck.size()
	answer(e, &"defend", truce.uid)
	check(has_event(e, &"attack_stopped"), "the successful attack was stopped after all")
	eq(e.player(1).life_deck.size(), before, "so no wounds landed")
	# Declining instead lets it through, and the window does not reopen on the same attack.
	var f: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
	to_combat(f)
	to_hand(f, 1, "t_late_truce")
	answer(f, &"attack", uid_in_hand(f, 0, "t_strike"))
	eq(prompt_kind(f), &"defense", "with nothing else to play the late window is the only one")
	check(bool(f.prompt.context.get("late", false)), "and it is the late one")
	answer(f, &"no_defense")
	check(has_event(f, &"attack_successful"), "declining leaves the attack standing")
	check(prompt_kind(f) != &"defense", "and it does not reopen on the same attack")


## "Remove the top card of your discard pile to raise your Fervor 1, or 2 if it is a Pyre card."
## The card that burns picks the branch, and it is read before it leaves.
func test_a_mastery_can_read_the_card_it_burns() -> void:
	var e: DuelEngine = engine(deck(filler(), "vigil", "pyre", "t_ember_mastery"), deck(filler(), "pact"))
	to_combat(e)
	var me: PlayerState = e.player(0)
	me.discard.append(e._instance(lib.get_def("t_pyre_jab"), 0, &"discard"))
	var start: int = me.fervor
	answer(e, &"use", me.mastery.uid)
	eq(me.fervor, start + 2, "a Pyre card on top pays double")
	eq(me.discard.size(), 0, "and it left the game")
	# Once per Combat, so the second read waits; a plain card pays one.
	var f: DuelEngine = engine(deck(filler(), "vigil", "pyre", "t_ember_mastery"), deck(filler(), "pact"))
	to_combat(f)
	var mine: PlayerState = f.player(0)
	mine.discard.append(f._instance(lib.get_def("t_late_truce"), 0, &"discard"))
	var began: int = mine.fervor
	answer(f, &"use", mine.mastery.uid)
	eq(mine.fervor, began + 1, "anything else pays one")
	check(f.prompt.find(&"use", mine.mastery.uid) == null, "and it is spent for the Combat")


## "Draw a card and show it to your opponent. If it is a Physical or Energy Combat card, your
## opponent discards 3 from the top of his Life Deck."
func test_a_power_can_check_whether_the_drawn_card_attacks() -> void:
	# Two runs that differ only in what the knight's own Life Deck has on top, so the gap between
	# the rival's remaining cards is the Power and nothing else.
	var attacks: Array[String] = ["t_strike", "t_strike", "t_strike", "t_strike", "t_strike", "t_strike", "t_strike", "t_strike", "t_strike", "t_strike", "t_strike", "t_strike"]
	var quiet: Array[String] = ["t_taunt", "t_taunt", "t_taunt", "t_taunt", "t_taunt", "t_taunt", "t_taunt", "t_taunt", "t_taunt", "t_taunt", "t_taunt", "t_taunt"]
	var left: Array[int] = []
	for list in [attacks, quiet]:
		var e: DuelEngine = engine(deck(list, "vigil", "", "", 3, "tf_knight"), deck(filler(), "pact"))
		e.player(0).duelist.aspect = 2
		to_combat(e)
		left.append(e.player(1).life_deck.size())
	eq(left[1] - left[0], 3, "an attack card on top costs the rival three, a Combat card nothing")


## "If that card is a Goku named card, and if Chi-Chi and Gohan are in play, draw another card."
## Both names, not either: one Ally is not enough.
func test_a_power_can_need_two_named_allies() -> void:
	var e: DuelEngine = engine(deck(filler(["t_knights_oath"]), "vigil", "", "", 3, "tf_knight"), deck(filler(), "pact"))
	var me: PlayerState = e.player(0)
	me.life_deck.insert(0, e._instance(lib.get_def("t_knights_oath"), 0, &"life_deck"))
	inject(e, 0, "t_ally_squire")
	var one_ally: int = me.hand.size()
	to_combat(e)
	eq(me.hand.size(), one_ally + 1, "the Signature card is drawn, but only that one")
	var f: DuelEngine = engine(deck(filler(["t_knights_oath"]), "vigil", "", "", 3, "tf_knight"), deck(filler(), "pact"))
	var mine: PlayerState = f.player(0)
	mine.life_deck.insert(0, f._instance(lib.get_def("t_knights_oath"), 0, &"life_deck"))
	inject(f, 0, "t_ally_squire")
	inject(f, 0, "t_ally_herald")
	var both: int = mine.hand.size()
	to_combat(f)
	eq(mine.hand.size(), both + 2, "with both named Allies out it draws again")


## "Raise any personality to their highest power stage." The card does not say whose, so the whole
## table is on the list and the chooser decides, the other side included.
func test_energy_can_reach_any_personality_on_the_table() -> void:
	var e: DuelEngine = engine(deck(filler(["t_rally_any"])), deck(filler(), "pact"))
	inject(e, 1, "t_ally_squire")
	to_combat(e)
	var theirs: PlayerState = e.player(1)
	var squire: CardInstance = theirs.allies()[0]
	squire.energy = 1
	e.player(0).duelist.energy = 1
	answer(e, &"use", uid_in_hand(e, 0, "t_rally_any"))
	eq(prompt_kind(e), &"pick_option", "the table is offered")
	check(e.prompt.find(&"pick_option", squire.uid) != null, "the rival's Ally is on the list too")
	check(e.prompt.find(&"pick_option", e.player(0).duelist.uid) != null, "and so is your own duelist")
	answer(e, &"pick_option", squire.uid)
	eq(squire.energy, CardInstance.MAX_STAGE, "the chosen personality went to full Energy")
	eq(e.player(0).duelist.energy, 1, "and nobody else moved")


## "Stop a physical attack performed against Gohan or Goku. Your Main Personality does not have to
## be in control for her to use this power."
func test_an_ally_can_block_for_one_named_personality() -> void:
	for pair in [["tf_knight", true], ["tf_vigil", false]]:
		var e: DuelEngine = engine(deck(filler(), "pact"), deck(filler(), "vigil", "", "", 3, str(pair[0])))
		inject(e, 1, "t_ally_shieldmother")
		to_combat(e)
		# Whoever the bracket hands the first attack phase to, the guarded side has to be defending.
		if e.state.attacker == 1:
			answer(e, &"pass")
		var mother: CardInstance = e.player(1).allies()[0]
		answer(e, &"attack", uid_in_hand(e, 0, "t_strike"))
		# With nothing else to block with, the window opens only when her Power can answer.
		var offered: bool = prompt_kind(e) == &"defense" and e.prompt.find(&"power_defend", mother.uid) != null
		eq(offered, bool(pair[1]), "she answers from the side only for a personality she names")
		if not bool(pair[1]):
			continue
		answer(e, &"power_defend", mother.uid)
		check(has_event(e, &"attack_stopped"), "and the Strike is stopped")


## The fourth copy is what naming your Main Personality buys, but a card that prints its own limit
## keeps it: "Limit 2 per deck" on a Signature card means two.
func test_a_printed_limit_beats_the_signature_allowance() -> void:
	var four: Array[String] = filler(["t_knights_oath", "t_knights_oath", "t_knights_oath", "t_knights_oath"])
	var problems: Array[String] = DeckValidator.validate(deck(four, "vigil", "", "", 3, "tf_knight"), lib)
	var named: bool = false
	for p in problems:
		if p.contains("t_knights_oath"):
			named = true
	check(named, "four copies of a limit-2 Signature card is illegal")
	var two: Array[String] = filler(["t_knights_oath", "t_knights_oath"])
	for p in DeckValidator.validate(deck(two, "vigil", "", "", 3, "tf_knight"), lib):
		check(not p.contains("t_knights_oath"), "two is fine: %s" % p)
	# A Signature card with no printed limit still gets the fourth copy.
	var four_plain: Array[String] = filler(["t_vigil_ray", "t_vigil_ray", "t_vigil_ray", "t_vigil_ray"])
	for p in DeckValidator.validate(deck(four_plain, "vigil", "", "", 3, "tf_vigil"), lib):
		check(not p.contains("t_vigil_ray"), "the allowance still applies where nothing is printed: %s" % p)


## Two copies of one card in hand are one move, so the search keeps only the first. A card on the
## table is never merged with its twin, since the two can differ.
func test_search_merges_identical_moves_from_hand() -> void:
	var e: DuelEngine = engine(deck(filler([], 20)), deck(filler(), "pact"))
	var hand: Array[CardInstance] = e.player(0).hand
	var a: CardInstance = null
	var b: CardInstance = null
	for i in range(hand.size()):
		for j in range(i + 1, hand.size()):
			if a == null and hand[i].def.id == hand[j].def.id:
				a = hand[i]
				b = hand[j]
	check(a != null, "the opening hand holds two copies of one card")
	if a == null:
		return
	var p: Prompt = Prompt.new()
	p.player = 0
	p.options = [Command.new(0, &"attack", a.uid), Command.new(0, &"attack", b.uid), Command.new(0, &"pass")] as Array[Command]
	eq(AiSearch._distinct(e, p, [0, 1, 2] as Array[int]), [0, 2] as Array[int], "the second copy is the same move")
	eq(AiSearch._distinct(e, p, [1, 0, 2] as Array[int]), [1, 2] as Array[int], "whichever copy ranks first is kept")
	b.zone = &"in_play"
	eq(AiSearch._distinct(e, p, [0, 1, 2] as Array[int]).size(), 3, "a copy on the table stays its own move")


## A profile can hand named prompt kinds to the scorer. None do unless they say so.
func test_a_profile_can_leave_prompt_kinds_to_the_scorer() -> void:
	var plain: AiProfile = AiProfile.default_profile()
	check(not plain.scorer_decides(&"control"), "the default searches every kind")
	var gated: AiProfile = AiProfile.default_profile()
	gated.merge({"think": {"scorer_kinds": ["control", "keep"]}})
	check(gated.scorer_decides(&"control"), "a listed kind goes to the scorer")
	check(not gated.scorer_decides(&"attack_action"), "an unlisted kind is still searched")
	check(not AiProfile.default_profile().scorer_decides(&"control"), "the merge did not reach the defaults")


## The margin cutoff drops candidates the ordering already puts far behind, and always keeps the
## leader. 0 and 1 are off, so no profile changes behaviour until it opts in.
func test_branch_margin_keeps_the_leader_and_drops_the_tail() -> void:
	var prior: Array[float] = [10.0, 9.0, 2.0, 0.0]
	var all: Array[int] = [0, 1, 2, 3]
	eq(AiSearch._within_margin(all, prior, 0.0).size(), 4, "0 keeps everything")
	eq(AiSearch._within_margin(all, prior, 1.0).size(), 4, "1 keeps everything")
	var half: Array[int] = AiSearch._within_margin(all, prior, 0.5)
	eq(half, [0, 1] as Array[int], "half the spread keeps the leader and the close second")
	var tight: Array[int] = AiSearch._within_margin(all, prior, 0.05)
	eq(tight, [0] as Array[int], "a tight margin keeps the leader alone")
	var flat: Array[float] = [4.0, 4.0, 4.0]
	eq(AiSearch._within_margin([0, 1, 2] as Array[int], flat, 0.5).size(), 3,
		"no spread means nothing to cut")
	eq(AiSearch._within_margin([2] as Array[int], prior, 0.1), [2] as Array[int],
		"a single candidate is never dropped")


## The AI reads a profile's `when` facts straight off the engine instead of building a SeatView,
## because the search pays that per world per node. Both paths must name the same facts.
func test_profile_state_key_matches_the_seat_view() -> void:
	var profile: AiProfile = AiProfile.new()
	profile.data = {"when": {
		"bonded": {}, "allies_min:1": {}, "allies_min:2": {}, "aspect_min:1": {},
		"aspect_min:2": {}, "fervor_min:1": {}, "seals_min:1": {}, "life_below:99": {},
		"life_below:3": {},
	}}
	var e: DuelEngine = engine(deck(filler(["t_ally_squire"]), "vigil", "", "", 3, "tf_vigil"),
		deck(filler(["t_ally_kin"]), "vigil", "", "", 3, "tf_titan"), 4242, true)
	var compared: int = 0
	for step in range(24):
		for seat in range(2):
			var from_view: String = profile.state_key(SeatView.of(e, seat, false), seat)
			var from_engine: String = profile.state_key_of(e, seat)
			eq(from_engine, from_view, "seat %d, step %d: same facts from either path" % [seat, step])
			compared += 1
		if e.is_over() or e.prompt == null or e.prompt.options.is_empty():
			break
		e.submit(e.prompt.options[0])
		e.take_events()
	check(compared >= 10, "compared %d states" % compared)


## House rule 2026-09-20: an Ally printed only at its first Aspect can never outgrow a Duelist, so
## it is legal in any deck. The 2-aspect gap still governs every Ally that climbs.
func test_an_aspect_one_ally_is_legal_in_a_shallow_deck() -> void:
	var shallow: Array[String] = filler(["t_ally_squire"])
	for p in DeckValidator.validate(deck(shallow, "vigil", "", "", 2, "tf_vigil"), lib):
		check(not p.contains("t_ally_squire"), "an Aspect-1 Ally is legal at 2 aspects: %s" % p)
	for p in DeckValidator.validate(deck(shallow, "vigil", "", "", 1, "tf_vigil"), lib):
		check(not p.contains("t_ally_squire"), "and at 1 aspect: %s" % p)
	# One that climbs to a second Aspect still has to sit two below the Duelist.
	var climbs: Array[String] = filler(["t_ally_squire_2"])
	var named: bool = false
	for p in DeckValidator.validate(deck(climbs, "vigil", "", "", 3, "tf_vigil"), lib):
		if p.contains("t_ally_squire_2"):
			named = true
	check(named, "an Aspect-2 Ally is still illegal at 3 aspects")
	for p in DeckValidator.validate(deck(climbs, "vigil", "", "", 4, "tf_vigil"), lib):
		check(not p.contains("t_ally_squire_2"), "and legal at 4: %s" % p)


## Ally and Duelist are one card type now, so "whose Power refreshes when" comes from the seat:
## an Ally's Power is once a Combat, the Main Personality's is once a turn.
func test_an_ally_power_refreshes_each_combat() -> void:
	var e: DuelEngine = engine(deck(filler(["t_taunt", "t_taunt"])), deck(filler(), "pact"))
	var me: PlayerState = e.player(0)
	var ally: CardInstance = inject(e, 0, "t_ally_free")
	to_combat(e)
	check(e._power_available(me, ally), "the Ally's Power is fresh")
	e._mark_power_used(ally)
	check(not e._power_available(me, ally), "and spent once used")
	# A second Combat in the same turn is a fresh Combat for the Ally.
	e.state.combat_count += 1
	check(e._power_available(me, ally), "an Ally refreshes each Combat")
	e.state.combat_count -= 1
	check(not e._power_available(me, ally), "and not otherwise")


## Most Powerful Personality: a duelist whose ladder is taller than the rival's wins the moment
## they enter the first Aspect above everything the rival can reach. Level ladders leave no such
## Aspect, and then the Fervor route is the only one.
func test_the_taller_ladder_wins_by_standing_above_it() -> void:
	var e: DuelEngine = engine(deck(filler(["t_taunt", "t_taunt"]), "vigil", "", "", 5, "tf_titan"), deck(filler(), "pact"))
	eq(e.player(0).highest_aspect, 5, "five Aspects")
	eq(e.player(1).highest_aspect, 3, "against three")
	eq(e.mppv_aspect(e.player(0)), 4, "so Aspect 4 is the winning rung")
	eq(e.mppv_aspect(e.player(1)), 0, "and the shorter ladder has no rung above the taller one")
	to_combat(e)
	e.player(0).duelist.aspect = 3
	e.player(0).fervor = 4
	answer(e, &"use", uid_in_hand(e, 0, "t_taunt"))
	eq(e.player(0).duelist.aspect, 4, "the climb lands on Aspect 4")
	check(e.is_over(), "and entering it ends the duel outright, with the Fervor meter empty")
	eq(e.state.winner, 0, "the taller ladder won")
	eq(e.state.win_reason, "ascension", "recorded as an Ascension win")

	# Level ladders: climbing the same Aspect proves nothing.
	var f: DuelEngine = engine(deck(filler(["t_taunt"]), "vigil", "", "", 5, "tf_titan"), deck(filler(), "pact", "", "", 5, "tf_titan"))
	eq(f.mppv_aspect(f.player(0)), 0, "level ladders leave no rung above")
	to_combat(f)
	f.player(0).duelist.aspect = 3
	f.player(0).fervor = 4
	answer(f, &"use", uid_in_hand(f, 0, "t_taunt"))
	eq(f.player(0).duelist.aspect, 4, "it still climbs")
	check(not f.is_over(), "but climbing is not the win when the rival can match the Aspect")

	# The relic that gives up the Ascension win gives up this route with it.
	var g: DuelEngine = engine(deck(filler(["t_taunt"]), "vigil", "", "", 5, "tf_titan"), deck(filler(), "pact"))
	to_combat(g)
	g.player(0).no_ascension_win = true
	g.player(0).duelist.aspect = 3
	g.player(0).fervor = 4
	answer(g, &"use", uid_in_hand(g, 0, "t_taunt"))
	eq(g.player(0).duelist.aspect, 4, "the climb still happens")
	check(not g.is_over(), "but a duelist who cannot win by Ascension cannot win this way either")

	# And the card that answers an Ascension win answers this one: it drops the Aspect back under.
	var h: DuelEngine = engine(deck(filler(["t_taunt"]), "vigil", "", "", 5, "tf_titan"), deck(filler(), "pact"))
	inject(h, 1, "t_reckoning")
	to_combat(h)
	h.player(0).duelist.aspect = 3
	h.player(0).fervor = 4
	answer(h, &"use", uid_in_hand(h, 0, "t_taunt"))
	eq(prompt_kind(h), &"respond", "the rival is asked before the win stands")
	answer(h, &"use", h.player(1).non_combats()[0].uid)
	eq(h.player(0).duelist.aspect, 3, "the answer knocked them back down a rung")
	check(not h.is_over(), "so the win does not stand")


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


## Every card's `zone` has to agree with the pile it is actually sitting in. An effect that moves
## a card by hand and forgets to take it out of its old pile leaves it in two places, which shows
## up as phantom cards in a seat's view rather than as an error. Swept over a whole shipped game.
func test_card_zones_stay_consistent() -> void:
	var shipped: CardLibrary = CardLibrary.new()
	shipped.load_dir("res://data/cards")
	var ref: Referee = Referee.new()
	var pair: Array[DeckList] = [DeckList.load_from("res://data/decks/pyre_beatdown.json"), DeckList.load_from("res://data/decks/storm_volley.json")]
	ref.setup(pair, shipped, StrikeTable.load_from("res://data/strike_table.json"), 21)
	ref.start()
	var picker: RandomNumberGenerator = RandomNumberGenerator.new()
	picker.seed = 4
	var steps: int = 0
	var bad: String = ""
	while not ref.is_over() and steps < 300 and bad == "":
		steps += 1
		bad = zone_mismatch(ref.engine)
		var seat: int = ref.engine.prompt.player
		var opts: Array[Command] = ref.engine.prompt.options
		ref.submit(seat, opts[picker.randi_range(0, opts.size() - 1)].to_dict())
	eq(bad, "", "no card is in a pile its zone does not name")
	check(steps > 20, "the sweep got a real game, not an early exit")


## The name of the first card whose zone and pile disagree, or "" when they all agree.
func zone_mismatch(e: DuelEngine) -> String:
	for uid in e._cards:
		var c: CardInstance = e._cards[uid]
		for p in e.state.players:
			var piles: Dictionary = {
				&"life_deck": p.life_deck, &"hand": p.hand, &"discard": p.discard,
				&"in_play": p.in_play, &"removed": p.removed, &"reserve": p.reserve,
			}
			for zone in piles:
				var pile: Array[CardInstance] = piles[zone]
				if pile.has(c) and c.zone != zone:
					return "%s is in %s with zone %s" % [c.def.id, zone, c.zone]
	return ""


## A clone taken at any prompt, fed the same commands, stays in step with the original. A fresh
## clone is taken every few steps so mid-effect and mid-attack positions are covered.
func test_clone_plays_identically() -> void:
	for pairing in [["pyre_beatdown", "tide_companions"], ["shade_henchmen", "storm_volley"], ["freestyle_swords", "steel_beatdown"]]:
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


## Referee.sim_for preserves all permitted observations and our known composition, while
## inferring the rival's undisclosed cards from a reproducible public-information prior.
func test_sim_for_hides_and_keeps() -> void:
	var lib: CardLibrary = CardLibrary.new()
	lib.load_dir("res://data/cards")
	var ref: Referee = Referee.new()
	var pair: Array[DeckList] = [DeckList.load_from("res://data/decks/pyre_beatdown.json"), DeckList.load_from("res://data/decks/storm_volley.json")]
	ref.setup(pair, lib, StrikeTable.load_from("res://data/strike_table.json"), 21)
	ref.start()
	var picker: RandomNumberGenerator = RandomNumberGenerator.new()
	picker.seed = 4
	var compared: int = 0
	var deals_differ: int = 0
	var steps: int = 0
	while not ref.is_over() and steps < 300:
		steps += 1
		var seat: int = ref.engine.prompt.player
		if steps % 10 == 0:
			var visible: SeatView = ref.view_for(seat)
			var original: String = views_text(ref.engine)
			var original_rng: int = ref.engine.rng._rng.state
			var sim: DuelEngine = ref.sim_for(seat, steps)
			eq(JSON.stringify(SeatView.of(sim, seat).to_dict()), JSON.stringify(visible.to_dict()), "step %d: every permitted observation survives sampling" % steps)
			eq(JSON.stringify(PromptView.of(sim.prompt_of(seat), sim).to_dict()), JSON.stringify(ref.prompt_for(seat).to_dict()), "step %d: the seat keeps its revealed legal decision" % steps)
			eq(hidden_titles(sim, seat), hidden_titles(ref.engine, seat), "step %d: our known deck/hand/Reserve composition is preserved" % steps)
			var repeated: DuelEngine = ref.sim_for(seat, steps)
			var other: DuelEngine = ref.sim_for(seat, steps + 1000)
			var same_slots: bool = true
			var different_slots: bool = false
			var preserved_reveals: bool = true
			for value in visible.cards.values():
				var card: SeatCard = value
				if not card.hidden():
					preserved_reveals = preserved_reveals and sim.card(card.uid).def.id == card.def_id
				elif card.owner == 1 - seat:
					same_slots = same_slots and sim.card(card.uid).def.id == repeated.card(card.uid).def.id
					different_slots = different_slots or sim.card(card.uid).def.id != other.card(card.uid).def.id
			eq(same_slots, true, "step %d: identical seeds infer identical enemy identities at every hidden UID" % steps)
			eq(preserved_reveals, true, "step %d: own hand and every explicitly revealed choice retain identity" % steps)
			eq(sim.rng._rng.state, repeated.rng._rng.state, "step %d: the sampled future random stream is reproducible" % steps)
			check(sim.rng._rng.state != other.rng._rng.state, "step %d: another sample gets an independent future random stream" % steps)
			if different_slots:
				deals_differ += 1
			compared += 1
			var guard: int = 0
			while not sim.is_over() and guard < 4000:
				guard += 1
				sim.submit(sim.prompt.options[picker.randi_range(0, sim.prompt.options.size() - 1)])
			check(sim.is_over(), "step %d: the inferred simulation plays to the end" % steps)
			eq(views_text(ref.engine), original, "step %d: sampling and playout cannot mutate the real position" % steps)
			eq(ref.engine.rng._rng.state, original_rng, "step %d: sampling and playout cannot consume real randomness" % steps)
		var opts: Array[Command] = ref.engine.prompt.options
		ref.submit(seat, opts[picker.randi_range(0, opts.size() - 1)].to_dict())
	check(compared >= 5, "compared %d simulations" % compared)
	check(deals_differ >= compared / 2, "different seeds inferred different opposing deals in %d of %d simulations" % [deals_differ, compared])


func hidden_titles(e: DuelEngine, owner: int) -> Array[String]:
	var out: Array[String] = []
	var p: PlayerState = e.player(owner)
	for list in [p.hand, p.life_deck, p.reserve]:
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
	var pairings: Array = [["pyre_beatdown", "tide_companions"], ["shade_henchmen", "storm_volley"], ["freestyle_swords", "steel_beatdown"]]
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
				check(not players[1 - seat].choose(ref, 1 - seat).is_empty(), "both seats answer their own reserve swap")
			elif ref.engine.prompts.size() == 1 and not kinds.has(&"non_combat"):
				eq(players[1 - seat].choose(ref, 1 - seat).is_empty(), true, "the seat not deciding gets no answer")
			refused = ref.submit(seat, players[seat].choose(ref, seat))
			ref.engine.take_events()
		eq(refused, "", "%s vs %s: every AI answer was accepted" % [pairing[0], pairing[1]])
		check(ref.is_over(), "%s vs %s finished in %d steps" % [pairing[0], pairing[1], steps])
	for kind in [&"reserve", &"non_combat", &"declare", &"attack_action", &"defense", &"keep"]:
		check(kinds.has(kind), "the AI met a %s prompt" % kind)


## The search weighs more than one option, leaves the real engine alone, and picks the same
## command again from the same seed.
func test_ai_search_reports_and_is_repeatable() -> void:
	var ref: Referee = shipped_referee("pyre_beatdown", "steel_beatdown", 12)
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
	# Repeatability must depend on a fixed amount of work, not machine speed or live difficulty.
	profile.merge({"think": {"samples": 3, "budget_ms": 0, "node_budget": 600}})
	var first: AiPlayer = AiPlayer.new(profile, 77)
	var second: AiPlayer = AiPlayer.new(profile, 77)
	var a: Dictionary = first.choose(ref, seat)
	var b: Dictionary = second.choose(ref, seat)
	eq(JSON.stringify(b), JSON.stringify(a), "same seed, same choice")
	check(first.search.last_report.size() >= 2, "the search compared %d options" % first.search.last_report.size())
	eq(int(first.search.last_report[0]["samples"]), 3, "every option met all three deals")
	eq(views_text(ref.engine), before, "thinking did not move the real duel")
	eq(ref.submit(seat, a), "", "the referee accepts the choice")


## A deck that runs two Allies for the card they fuse into should read the fusion as the plan, not
## as one more Non-Combat to spend. The card is worth the bands the fused personality gains over the
## partners it eats, and worth nothing at all until both partners are on the table.
func test_ai_values_a_fusion_by_what_it_gains() -> void:
	var e: DuelEngine = engine(deck(filler(["t_bonding_rite"])), deck(filler(), "pact"))
	var profile: AiProfile = AiProfile.default_profile()
	profile.merge({"play": {"bond_band": 4.0}})
	var rite: CardInstance = inject(e, 0, "t_bonding_rite")
	var me: PlayerState = e.player(0)
	eq(AiScorer._bond_value(e, me, rite.def, profile), 0.0, "nothing to fuse, nothing to value")
	var first: CardInstance = inject(e, 0, "t_ally_twin_a")
	first.energy = 3
	eq(AiScorer._bond_value(e, me, rite.def, profile), 0.0, "one partner is still nothing")
	var second: CardInstance = inject(e, 0, "t_ally_twin_b")
	second.energy = 3
	# Partners sit in band B on the fixture table; the fused card at 6.8M is band F.
	var paid: float = AiScorer._bond_value(e, me, rite.def, profile)
	check(paid >= 12.0, "both partners out makes the fusion worth the bands it gains: %.1f" % paid)
	var plain: CardInstance = inject(e, 0, "t_drill_footwork_named")
	eq(AiScorer._bond_value(e, me, plain.def, profile), 0.0, "a card that fuses nothing is not a fusion")


## A Duelist's constant power does not switch itself off when an Ally takes over Combat. The CRD is
## explicit about it, and it matters most for a constant that guards the Allies: they are exposed
## exactly when one of them steps up to fight.
func test_duelist_constant_holds_while_an_ally_leads() -> void:
	var e: DuelEngine = engine(deck(filler(["t_ally_squire"]), "vigil", "", "", 3, "tf_warden"), deck(filler(), "pact"))
	answer(e, &"place", uid_in_hand(e, 0, "t_ally_squire"))
	var ally: CardInstance = e.player(0).allies()[0]
	var me: PlayerState = e.player(0)
	check(e._ally_protected(me, ally), "the Duelist guards them while she leads")
	me.controlling = ally
	check(e._ally_protected(me, ally), "and still guards them once the Ally leads")
	eq(e._constant(me).get("protect_allies", false), true, "the Duelist's constant is still in force")


## A deck whose payoff sits two searches away should read the first search as worth playing. Nothing
## here names a card: the chain's value is the payoff's value, stepped down once per link, so a
## deck's tutor priorities fall out of the weights it already has.
func test_ai_follows_a_tutor_chain() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
	var me: PlayerState = e.player(0)
	to_deck(e, 0, "t_tutor_rite")
	to_deck(e, 0, "t_bonding_rite")
	var first: CardInstance = inject(e, 0, "t_ally_twin_a")
	var second: CardInstance = inject(e, 0, "t_ally_twin_b")
	first.energy = 3
	second.energy = 3
	var tutor: CardInstance = to_hand(e, 0, "t_tutor_tutor")
	var flat: AiProfile = AiProfile.default_profile()
	flat.merge({"play": {"bond_band": 4.0, "tutor_decay": 0.0}})
	var chaining: AiProfile = AiProfile.default_profile()
	chaining.merge({"play": {"bond_band": 4.0, "tutor_decay": 0.6}})
	# The cache is only valid for one profile and one board, which is all `scores` ever asks of it.
	AiScorer._value_cache.clear()
	var plain: float = AiScorer.card_value(e, me, tutor, flat, AiScorer.TUTOR_DEPTH)
	AiScorer._value_cache.clear()
	var chained: float = AiScorer.card_value(e, me, tutor, chaining, AiScorer.TUTOR_DEPTH)
	check(chained > plain + 4.0, "two links away, the fusion still pulls the first search: %.1f against %.1f" % [chained, plain])
	# And the far end is worth more than the road to it, so nothing prefers the tutor to the payoff.
	AiScorer._value_cache.clear()
	var rite: CardInstance = to_hand(e, 0, "t_bonding_rite")
	var payoff: float = AiScorer.card_value(e, me, rite, chaining, AiScorer.TUTOR_DEPTH)
	check(payoff > chained, "the fusion itself outranks the card that goes to find it")


## Each win route moves the evaluation: fewer life cards is worse, Seals and Ascension are better,
## and a profile that ignores a route does not count it.
func test_ai_evaluator_routes() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
	var profile: AiProfile = AiProfile.default_profile()
	var base: float = AiEvaluator.evaluate(e, 0, profile)
	var rival_base: float = AiEvaluator.evaluate(e, 1, profile)
	e.player(0).fervor = 4
	var with_fervor: float = AiEvaluator.evaluate(e, 0, profile)
	check(with_fervor > base, "Fervor toward the Ascension win is worth something")
	e.player(0).fervor = 0
	inject(e, 0, "t_seal_1")
	var with_seal: float = AiEvaluator.evaluate(e, 0, profile)
	check(with_seal > base, "a Seal in play is worth something")
	check(AiEvaluator.evaluate(e, 1, profile) < rival_base, "and the other seat sees it as a threat")
	var deaf: AiProfile = AiProfile.default_profile()
	deaf.merge({"own": {"seal": 0.0}})
	eq(AiEvaluator.evaluate(e, 0, deaf), base, "a profile with no Seal weight ignores it")
	var lost: CardInstance = e.player(0).life_deck.pop_back()
	e.player(0).removed.append(lost)
	check(AiEvaluator.evaluate(e, 0, profile) < with_seal, "a lost life card is worse")
	e.state.winner = 1
	eq(AiEvaluator.evaluate(e, 0, profile), -AiEvaluator.WIN, "a lost duel is the floor")
	eq(AiEvaluator.evaluate(e, 1, profile), AiEvaluator.WIN, "a won duel is the ceiling")


## A Drill that guards Seals shuts off capture, so the AI values it above a plain Drill on its own
## side and as a target on the other. Grounds that cap Fervor are worth the climb they deny.
func test_ai_seal_guard_and_climb_grounds() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
	var profile: AiProfile = AiProfile.default_profile()
	inject(e, 0, "t_seal_1")
	var with_seal: float = AiEvaluator.evaluate(e, 0, profile)
	var rival_with_seal: float = AiEvaluator.evaluate(e, 1, profile)
	var plain: CardInstance = inject(e, 0, "t_drill_free")
	var with_plain: float = AiEvaluator.evaluate(e, 0, profile)
	check(with_plain > with_seal, "a plain Drill is worth something")
	e.player(0).in_play.erase(plain)
	inject(e, 0, "t_drill_keeper")
	var with_guard: float = AiEvaluator.evaluate(e, 0, profile)
	check(with_guard > with_plain, "a Drill that guards the Seal is worth more (%.2f vs %.2f)" % [with_guard, with_plain])
	check(AiEvaluator.evaluate(e, 1, profile) < rival_with_seal, "and the seat across the table sees Seals it can no longer take")
	var deaf: AiProfile = AiProfile.default_profile()
	deaf.merge({"own": {"seal_guard": 0.0}})
	eq(AiEvaluator.evaluate(e, 0, deaf), with_plain, "a profile with no guard weight scores it as a plain Drill")
	var keeper: CardInstance = e._instance(lib.get_def("t_drill_keeper"), 0, &"hand")
	var footwork: CardInstance = e._instance(lib.get_def("t_drill_free"), 0, &"hand")
	check(AiScorer.hold_value(keeper, profile) > AiScorer.hold_value(footwork, profile), "and it is the Drill to keep out of the two")
	var cap: CardDef = lib.get_def("t_grounds_cap")
	var climber: AiProfile = AiProfile.default_profile()
	climber.merge({"own": {"ascension": 45.0, "fervor": 6.0}, "foe": {"ascension": 10.0}})
	var patient: AiProfile = AiProfile.default_profile()
	patient.merge({"own": {"ascension": 5.0, "fervor": 0.0}, "foe": {"ascension": 45.0}})
	check(AiEvaluator.grounds_value(e, 0, cap, patient) > 0.0, "Grounds that cap Fervor suit a deck that is not climbing")
	check(AiEvaluator.grounds_value(e, 0, cap, climber) < 0.0, "and hurt one that is")


## An attack forecast says what Energy the performer is left on after paying, which is what tells a
## scorer whether the stages it is spending were going to survive the Combat anyway.
func test_attack_forecast_reports_energy_left() -> void:
	var e: DuelEngine = engine(deck(filler(["t_art"])), deck(filler(), "pact"))
	to_combat(e)
	var forecasts: Dictionary = e.attack_forecasts(e.prompt.player)
	check(not forecasts.is_empty(), "the attack prompt forecasts something")
	for key in forecasts:
		var f: Dictionary = forecasts[key]
		check(f.has("energy_left"), "and every forecast says what Energy the performer is left on")
		check(int(f["energy_left"]) >= 0, "which is never below zero")


## Which Reserve cards seat 0's AI brings in for a shipped matchup, by card id.
func reserve_swaps(mine: String, theirs: String) -> Array[String]:
	var ref: Referee = shipped_referee(mine, theirs, 5)
	var driver: AiPlayer = AiPlayer.new(AiProfile.for_deck(DeckList.load_from("res://data/decks/%s.json" % mine), ""), 1)
	var steps: int = 0
	while ref.engine.prompt != null and ref.engine.prompt.kind == &"reserve" and steps < 60:
		steps += 1
		var seat: int = ref.engine.prompt.player
		if seat == 0:
			ref.submit(0, driver.choose(ref, 0))
		else:
			ref.submit(1, ref.engine.prompt.find(&"reserve_done").to_dict())
	var out: Array[String] = []
	for ev in ref.engine.events:
		if ev.type == &"reserve_swap" and int(ev.data.get("player", -1)) == 0:
			out.append(ref.engine.card(int(ev.data["in"])).def.id)
	return out


## The Reserve swap reads the opponent's duelist, Mastery and Relic, brings in answers that fit,
## leaves the rest, and keeps toolbox attacks where the deck can fetch them.
func test_ai_reserve_swaps() -> void:
	var tide: DuelEngine = shipped_engine("tide_companions", "pyre_beatdown", 1)
	var tide_signs: Dictionary = AiReserve.read_setup(tide.player(0))
	eq(float(tide_signs["ally"]), 1.0, "the Tide setup cards read as an Ally deck")
	eq(float(tide_signs["camps"]), 1.0, "that sits on its lowest aspect")
	eq(float(tide_signs["non_combat"]), AiReserve.PRIOR, "and an effect aimed at the opponent is not a sign")
	var pyre_signs: Dictionary = AiReserve.read_setup(tide.player(1))
	eq(float(pyre_signs["ally"]), AiReserve.PRIOR, "the Pyre setup cards show no Allies")
	eq(float(pyre_signs["camps"]), AiReserve.PRIOR, "and no reason to sit on an aspect")
	var vale: DuelEngine = shipped_engine("freestyle_swords", "pyre_beatdown", 1)
	eq(float(AiReserve.read_setup(vale.player(0))["drill"]), 1.0, "the Freestyle Mastery reads as a Drill deck")
	check(reserve_swaps("pyre_beatdown", "tide_companions").has("pyre_ashfall"), "Pyre brings its Ally answer in against Tide")
	check(not reserve_swaps("pyre_beatdown", "steel_beatdown").has("pyre_ashfall"), "and leaves it out against Steel")
	check(reserve_swaps("steel_beatdown", "freestyle_swords").has("scorn_smirks"), "Steel brings its Drill answer in against Freestyle")
	check(reserve_swaps("steel_beatdown", "pyre_beatdown").has("steel_skull_crack"), "and its plain strong card every game")
	check(not reserve_swaps("steel_beatdown", "pyre_beatdown").has("open_challenge"), "a card that starts in play from the Reserve stays there")
	eq(reserve_swaps("tide_companions", "shade_henchmen").size(), 0, "the Tide profile brings nothing in")
	check(not reserve_swaps("storm_volley", "pyre_beatdown").has("headlong_plunge"), "Storm leaves a toolbox attack where its fetch card can reach it")
	check(reserve_swaps("storm_volley", "tide_companions").has("headlong_plunge"), "unless the opponent is what it answers")
	check(not reserve_swaps("freestyle_swords", "pyre_beatdown").has("mutual_escalation"), "an Ascension deck does not bring in the card that gives up the Ascension win")


## A deck's archetype rides from its JSON to both seats' views, the validator knows the
## vocabulary, and the Reserve read takes the declared signs even when the setup cards are silent.
func test_archetype_label() -> void:
	var e: DuelEngine = shipped_engine("shade_henchmen", "freestyle_swords", 1)
	eq(e.player(0).archetype, "allies", "the engine carries the deck's archetype")
	var seen_by_rival: SeatPlayer = SeatView.of(e, 1).player(0)
	eq(seen_by_rival.archetype, "allies", "and shows it to the other seat")
	var back: SeatPlayer = SeatPlayer.from_dict(JSON.parse_string(JSON.stringify(seen_by_rival.to_dict())))
	eq(back.archetype, "allies", "it survives the wire")
	eq(back.subthemes.has("disruption"), true, "with its subthemes")
	eq(Archetype.label("drills"), "Drills", "labels come from one place")
	check(Archetype.plan("allies") != "", "with a line on how the deck wins")
	var plain: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
	eq(float(AiReserve.read_setup(plain.player(0))["seal"]), AiReserve.PRIOR, "an unlabelled deck reads at the prior")
	plain.player(0).archetype = "seals"
	eq(float(AiReserve.read_setup(plain.player(0))["seal"]), 1.0, "a declared Seal deck reads as one though no setup card says so")
	plain.player(0).archetype = ""
	plain.player(0).subthemes = ["drills"]
	eq(float(AiReserve.read_setup(plain.player(0))["drill"]), 0.7, "a subtheme can carry a sign too")
	for word in Archetype.SUBTHEMES.keys():
		check(not str(word).contains("_") and not str(Archetype.SUBTHEMES[word]).contains(" "), "subtheme '%s' is one word" % word)
	var bad: DeckList = DeckList.load_from("res://data/decks/pyre_beatdown.json")
	bad.archetype = "midrange"
	bad.subthemes = ["fervor", "nonsense"]
	var problems: Array[String] = DeckValidator.validate(bad, shipped_library())
	check(", ".join(problems).contains("Unknown archetype 'midrange'") and ", ".join(problems).contains("Unknown subtheme 'nonsense'"), "the validator names words it does not know: %s" % ", ".join(problems))
	for file in ["pyre_beatdown", "steel_beatdown", "shade_henchmen", "tide_companions", "freestyle_swords", "storm_volley", "root_seals"]:
		var d: DeckList = DeckList.load_from("res://data/decks/%s.json" % file)
		check(Archetype.known(d.archetype) and d.difficulty != "", "%s is labelled %s, %s" % [file, d.archetype, d.difficulty])


func test_ai_profile_merge() -> void:
	var p: AiProfile = AiProfile.default_profile()
	p.merge({"name": "test", "own": {"seal": 99.0}, "think": {"search": false}, "nonsense": {"x": 1}})
	eq(p.name, "test", "name taken")
	eq(p.w("own", "seal"), 99.0, "the named weight changed")
	eq(p.w("own", "life"), float(AiProfile.DEFAULTS["own"]["life"]), "the rest kept their defaults")
	eq(p.searches(), false, "think knobs merge too")
	eq(AiProfile.default_profile().w("own", "seal"), float(AiProfile.DEFAULTS["own"]["seal"]), "a merge never writes to the defaults")
	for file in ["default", "easy", "hard"]:
		var loaded: AiProfile = AiProfile.load_from("res://data/ai/profiles/%s.json" % file)
		eq(loaded.name, file, "%s.json loads" % file)


## "Villains, and these two by name, only." The gate lets a side in and also names people from
## outside it, so it passes when any one way in is met, not all of them.
func test_an_only_gate_can_name_a_side_or_a_person() -> void:
	var gated: CardDef = lib.get_def("t_sided_ward")
	var pact: DuelEngine = engine(deck(filler(), "pact"), deck(filler(), "vigil"))
	check(pact._can_play(pact.player(0), gated), "the named side gets in")
	var vigil: DuelEngine = engine(deck(filler(), "vigil"), deck(filler(), "pact"))
	check(not vigil._can_play(vigil.player(0), gated), "a stranger from the other side does not")
	var named: DuelEngine = engine(deck(filler(), "vigil", "", "", 3, "tf_twice"), deck(filler(), "pact"))
	check(named._can_play(named.player(0), gated), "but a duelist the card names does, on either side")
	eq(CardText.gate_text(gated.only), "Pacts, Test Twice-Swinger and Test Dragonblood",
		"and the card says every way in")


## "If the bottom card of your discard pile is a Steel card." The bottom is the oldest card, which
## is the front of the pile, not the card just discarded.
func test_a_card_can_read_the_bottom_of_the_discard_pile() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
	var p: PlayerState = e.player(0)
	var cond: Dictionary = {"discard_bottom_school": "steel"}
	check(not e._cond(cond, 0, {}), "an empty pile reads as no")
	p.discard.append(e._instance(lib.get_def("t_steel_jab"), 0, &"discard"))
	p.discard.append(e._instance(lib.get_def("t_strike"), 0, &"discard"))
	check(e._cond(cond, 0, {}), "the oldest card is the one read, not the newest")
	p.discard.push_front(e._instance(lib.get_def("t_strike"), 0, &"discard"))
	check(not e._cond(cond, 0, {}), "and a card slid under it takes its place")


## "You may discard the top card of your Life Deck to do more damage." The cost is optional, it is
## asked before the attack swings, and saying no costs nothing.
func test_a_life_card_can_buy_more_damage() -> void:
	var paid: DuelEngine = engine(deck(filler(["t_paid_tackle"])), deck(filler(), "pact"))
	to_combat(paid)
	var before: int = paid.player(0).life_deck.size()
	answer(paid, &"attack", uid_in_hand(paid, 0, "t_paid_tackle"))
	eq(prompt_kind(paid), &"pay", "the card asks before it swings")
	answer(paid, &"pay_life", -1, 1)
	eq(paid.player(0).life_deck.size(), before - 1, "the top of the Life Deck paid for it")

	var free: DuelEngine = engine(deck(filler(["t_paid_tackle"])), deck(filler(), "pact"))
	to_combat(free)
	var kept: int = free.player(0).life_deck.size()
	answer(free, &"attack", uid_in_hand(free, 0, "t_paid_tackle"))
	answer(free, &"pay_life", -1, 0)
	eq(free.player(0).life_deck.size(), kept, "saying no spends nothing")
	# Both swings empty the defender's Energy, so the extra shows up as the overflow in wounds.
	check(paid.player(1).life_deck.size() < free.player(1).life_deck.size(),
		"and the paid swing lands harder than the free one")


## "Until the end of the game." The card leaves play and its modifier stays, so the seat is told
## about it separately and the client can stand a ghost of the card in for it.
func test_a_modifier_can_outlast_the_card_that_made_it() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
	var src: CardInstance = e._instance(lib.get_def("t_long_training"), 0, &"removed")
	e.player(0).removed.append(src)
	e._apply_effect({"op": "float", "what": "modifier", "duration": "game",
		"params": {"scope": "own", "kind": "any", "stages": 1}}, 0, {}, src)
	e._expire_floating("combat")
	e._expire_floating("turn")
	eq(e.state.floating.size(), 1, "the effect stands after Combat and after the turn")
	var v: SeatView = SeatView.of(e, 0)
	eq(v.standing.size(), 1, "and the seat is told about it")
	eq(int(v.standing[0]["source"]), src.uid, "naming the card that made it, for the ghost on the table")


## "This power may be used twice per Combat." A duelist Power is once a turn, so the second use
## has to come out of the same Combat, and there is no third.
func test_a_duelist_power_can_swing_twice_in_one_combat() -> void:
	var e: DuelEngine = engine(deck(filler(), "vigil", "", "", 3, "tf_twice"), deck(filler(), "pact"))
	var p: PlayerState = e.player(0)
	check(e._power_available(p, p.duelist), "the first swing is there")
	e._mark_power_used(p.duelist)
	check(e._power_available(p, p.duelist), "and so is the second")
	e._mark_power_used(p.duelist)
	check(not e._power_available(p, p.duelist), "the third is not")


## The rulings call the life card bought by an attack a requirement, not a cost, and Grounds that
## double costs do not reach a requirement. One card goes either way.
func test_a_bought_life_card_is_a_requirement_not_a_cost() -> void:
	var e: DuelEngine = engine(deck(filler(["t_paid_tackle"])), deck(filler(), "pact"))
	e.state.grounds = e._instance(lib.get_def("t_tollgate"), 0, &"grounds")
	to_combat(e)
	var before: int = e.player(0).life_deck.size()
	answer(e, &"attack", uid_in_hand(e, 0, "t_paid_tackle"))
	answer(e, &"pay_life", -1, 1)
	eq(e.player(0).life_deck.size(), before - 1, "the tollgate does not double what is not a cost")


## A keyword belongs to the printing, not to the person, and a card attached to a personality can
## lend them one for as long as it rides there. The source's mark works exactly that way, so
## "Marked only" has to read what the personality carries now, never what their card was printed
## with. Two printings of one person are free to disagree about it.
func test_a_keyword_can_be_lent_by_an_attachment() -> void:
	var e: DuelEngine = engine(deck(filler(), "vigil", "", "", 3, "tf_marked_long"), deck(filler(), "pact"))
	var me: PlayerState = e.player(0)
	var rite: CardDef = lib.get_def("t_marked_rite")
	check(not e.has_tag(me.duelist, "marked"), "this printing carries no mark")
	check(not e._can_play(me, rite), "so a Marked only card is out of reach")
	var mark: CardInstance = inject(e, 0, "t_the_mark")
	mark.attached_to = me.duelist
	check(e.has_tag(me.duelist, "marked"), "the mark laid on them counts")
	check(e.tags_of(me.duelist).has("marked"), "and the seat is told")
	check(e._can_play(me, rite), "now the rite is theirs to use")
	e._remove_from_game(mark)
	check(not e.has_tag(me.duelist, "marked"), "and it leaves when the card does")

	var other: DuelEngine = engine(deck(filler(), "vigil", "", "", 3, "tf_marked_short"), deck(filler(), "pact"))
	check(other.has_tag(other.player(0).duelist, "marked"), "the other printing of the same person has it printed")


## The same for a born line: a card can lend one, and everything that reads a bloodline reads the
## lent one, including the count a card multiplies by.
func test_a_bloodline_can_be_lent_by_an_attachment() -> void:
	var e: DuelEngine = engine(deck(filler(), "vigil", "", "", 3, "tf_marked_long"), deck(filler(), "pact"))
	var me: PlayerState = e.player(0)
	var rite: CardDef = lib.get_def("t_kin_rite")
	eq(e.bloodline_of(me.duelist), "", "this printing carries no line")
	check(not e._can_play(me, rite), "so a Draconic only card is out of reach")
	var blood: CardInstance = inject(e, 0, "t_blood_rite")
	blood.attached_to = me.duelist
	eq(e.bloodline_of(me.duelist), "draconic", "the rite lends them the line")
	check(e._can_play(me, rite), "and the gated card opens")
	eq(e.bloodline_count(me, "draconic"), 1, "the count reads the lent line too")


## Two printings of one character. The character is the identity and is shared, so the deck rules
## read them as one person; the ladder, the keywords and the line belong to the printing and are
## free to differ, which is why the variant is what tells the cards apart.
func test_two_variants_of_one_character_are_one_person() -> void:
	var short_road: CardDef = lib.get_def("tf_marked_short")
	var long_road: CardDef = lib.get_def("tf_marked_long")
	eq(short_road.character, long_road.character, "the same person")
	check(short_road.variant != long_road.variant, "and two printings of them")
	eq(short_road.highest_aspect(), 3, "one climbs three aspects")
	eq(long_road.highest_aspect(), 5, "the other five")
	check(short_road.raw.get("tags", []).has("marked"), "one is marked")
	check(not long_road.raw.get("tags", []).has("marked"), "and the other is not, which is allowed")
	eq(CardText.personality_name(short_road), "Test Two-Faced, the Short Road", "the variant names the card")
	eq(CardText.personality_name(lib.get_def("t_ally_squire")), "Test Squire", "one printing needs no variant")
	var d: DeckList = deck(filler(["tf_marked_short"]), "vigil", "", "t_mastery_pyre", 3, "tf_marked_long")
	var problems: Array[String] = DeckValidator.validate(d, lib)
	check(str(problems).contains("same character as the Duelist"), "and one printing cannot be the other's Ally")


## "Instead of using a Defense, remove any number of your school's cards in your discard pile from
## the game. Prevent 2 wounds from the attack for each one removed." The pile is the armour, so the
## option only appears when there is something in it to burn, and it never costs more than the
## wounds are worth.
func test_a_mastery_can_buy_wounds_off_with_the_discard_pile() -> void:
	var e: DuelEngine = engine(deck(filler(), "vigil", "tide", "t_mastery_burn"), deck(filler(), "pact"))
	var me: PlayerState = e.player(0)
	eq(e._burn_fuel(me, "tide"), 0, "an empty pile is no armour")
	for i in range(3):
		me.discard.append(e._instance(lib.get_def("t_tide_filler"), 0, &"discard"))
	me.discard.append(e._instance(lib.get_def("t_strike"), 0, &"discard"))
	eq(e._burn_fuel(me, "tide"), 3, "only the school's own cards are fuel")
	eq(e._burn_from_discard(me, "tide", 2), 2, "two of them go")
	eq(e._burn_fuel(me, "tide"), 1, "leaving one")
	eq(me.discard.size(), 2, "and the card of another school stays put")
	eq(me.removed.size(), 2, "what was burned is out of the game, not back in the pile")

func test_a_card_can_lock_out_what_would_drag_an_aspect_down() -> void:
	var e: DuelEngine = engine(deck(filler(["t_aspect_lock"])), deck(filler(["t_drop_them"]), "pact"))
	var foe: PlayerState = e.player(1)
	e.player(0).duelist.aspect = 3
	e._apply_effect({"op": "lose_aspect", "who": "opponent"}, 1, {}, null)
	eq(e.player(0).duelist.aspect, 2, "without the lock they drag him down a rung")
	e.player(0).duelist.aspect = 3
	e._apply_effect({"op": "forbid", "who": "opponent", "what": "lower_aspect", "duration": "combat"}, 0, {}, null)
	e._apply_effect({"op": "lose_aspect", "who": "opponent"}, 1, {}, null)
	eq(e.player(0).duelist.aspect, 3, "with it in force he stays where he is")
	e._apply_effect({"op": "lose_aspect", "who": "self"}, 0, {}, null)
	eq(e.player(0).duelist.aspect, 2, "and it never stops him stepping down himself")


## "Their duelist loses 1 Energy at the beginning of each of their attack phases for the remainder
## of Combat." It bites on their phases and not on yours, and once per phase however many times
## the phase is re-entered.
func test_a_hold_drains_them_at_the_start_of_each_of_their_phases() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
	var foe: PlayerState = e.player(1)
	foe.duelist.energy = 8
	e._apply_effect({"op": "float", "who": "opponent", "what": "phase_drain", "duration": "combat",
			"params": {"energy": 1}}, 0, {}, null)
	e.state.attacker = 0
	e._phase_start_drain(e.player(0))
	eq(foe.duelist.energy, 8, "your own phase costs them nothing")
	e.state.attacker = 1
	e.state.attack_phase_count += 1
	e._phase_start_drain(foe)
	eq(foe.duelist.energy, 7, "the start of their phase does")
	e._phase_start_drain(foe)
	eq(foe.duelist.energy, 7, "and it only bites once in the one phase")
	e.state.attack_phase_count += 1
	e._phase_start_drain(foe)
	eq(foe.duelist.energy, 6, "the next phase costs them again")


## "If either of two named cards is in play, this stays on the table to be used X more times this
## Combat, X = your duelist's Aspect." Both halves are read at the moment the attack resolves.
func test_remain_can_count_the_aspect_and_read_either_of_two_cards() -> void:
	var e: DuelEngine = engine(deck(filler(["t_ride_it"])), deck(filler(), "pact"))
	var me: PlayerState = e.player(0)
	var ctx: Dictionary = {}
	check(not e._cond({"card_in_play": ["Test Marker A", "Test Marker B"]}, 0, ctx), "neither marker is out")
	inject(e, 0, "t_marker_b")
	check(e._cond({"card_in_play": ["Test Marker A", "Test Marker B"]}, 0, ctx), "the second one counts")
	me.duelist.aspect = 3
	to_combat(e)
	answer(e, &"attack", uid_in_hand(e, 0, "t_ride_it"))
	while e.prompt != null and e.prompt.kind != &"attack_action":
		e.submit(e.prompt.options[e.prompt.options.size() - 1])
	var kept: CardInstance = null
	for c in me.remain_cards():
		if c.def.id == "t_ride_it":
			kept = c
	check(kept != null, "it stayed on the table")
	if kept != null:
		eq(kept.remain, 3, "for as many more uses as he has Aspects")


## "Put every Non-Combat card revealed into play." There is no choice in it, so nothing is asked.
func test_a_reveal_can_take_every_match_at_once() -> void:
	var e: DuelEngine = engine(deck(filler(["t_reveal_all"])), deck(filler(), "pact"))
	var me: PlayerState = e.player(0)
	e.shuffle_decks = false
	for i in range(3):
		me.life_deck.insert(0, e._instance(lib.get_def("t_marker_b"), 0, &"life_deck"))
	var before: int = me.in_play.size()
	e._apply_effect({"op": "look_at", "amount": 7, "from": "top", "to": "play",
			"pick": {"card_type": "non_combat"}, "all_matches": true}, 0, {}, null)
	eq(me.in_play.size(), before + 3, "all three went into play")
	check(e.prompt == null or e.prompt.kind != &"pick_option", "and nobody was asked to choose")


## "While you control this Seal, cards of yours in play that your opponent would remove from the
## game are discarded instead." It softens their removal and not your own, and the cards land in
## the discard pile where they can still be reached.
func test_a_seal_can_turn_their_removal_into_a_discard() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
	var me: PlayerState = e.player(0)
	var wipe: Dictionary = {"op": "discard_in_play", "who": "opponent", "card_type": "non_combat", "all": true, "remove": true}
	inject(e, 0, "t_drill_free")
	check(not e._removal_becomes_discard(me), "no guard yet")
	e._apply_effect(wipe, 1, {}, null)
	eq(me.removed.size(), 1, "so their card effect takes it out of the game")

	inject(e, 0, "t_seal_guard")
	inject(e, 0, "t_drill_free")
	check(e._removal_becomes_discard(me), "the Seal guards the board")
	var discard_before: int = me.discard.size()
	var removed_before: int = me.removed.size()
	e._apply_effect(wipe, 1, {}, null)
	eq(me.removed.size(), removed_before, "nothing more leaves the game")
	eq(me.discard.size(), discard_before + 1, "it is discarded instead")


## "All Strikes you perform that are marked do +3 Energy and are focused." The keyword on the card
## decides, so a plain Strike out of the same hand gets neither half.
func test_a_constant_can_read_the_keyword_on_the_card_it_boosts() -> void:
	var e: DuelEngine = engine(deck(filler(), "vigil", "", "", 3, "tf_marked_lord"), deck(filler(), "pact"))
	var me: PlayerState = e.player(0)
	me.duelist.aspect = 3
	var marked: CardInstance = e._instance(lib.get_def("t_marked_blow"), 0, &"hand")
	var plain: CardInstance = e._instance(lib.get_def("t_plain_blow"), 0, &"hand")
	eq(e._modifiers_for(me, "own", "strike", marked, {}).size(), 1, "the marked card takes the Constant's modifier")
	eq(e._modifiers_for(me, "own", "strike", plain, {}).size(), 0, "the plain one does not")
	eq(str(e._constant(me).get("focus_tag", "")), "marked", "and the Constant focuses the same set")


## "Base Damage is reduced by 2 when performed against him and raised by 2 when performed by him."
## Both halves live on the personality, so they read off whichever side he is on.
func test_a_constant_can_shift_the_strike_table_both_ways() -> void:
	var e: DuelEngine = engine(deck(filler(), "vigil", "", "", 3, "tf_marked_lord"), deck(filler(), "pact"))
	var me: PlayerState = e.player(0)
	var mine: Dictionary = {"attacker": 0, "defender": 1, "kind": "strike", "spec": {}, "target": -1, "empowered": false}
	var theirs: Dictionary = {"attacker": 1, "defender": 0, "kind": "strike", "spec": {}, "target": -1, "empowered": false}
	me.duelist.aspect = 1
	var plain_mine: int = int(e._damage_calc(mine)["table"])
	var plain_against: int = int(e._damage_calc(theirs)["table"])
	me.duelist.aspect = 2
	eq(int(e._damage_calc(mine)["table"]), plain_mine + 2, "his own Strikes hit the table 2 harder")
	eq(int(e._damage_calc(theirs)["table"]), maxi(0, plain_against - 2), "and Strikes at him land 2 softer")


## "You may discard a marked card from your hand. If you do, this Power may be used a second time
## this Combat." The extra use only exists while the cost is in hand, and it is paid on the way in.
func test_a_power_can_buy_a_second_use_with_a_card_from_hand() -> void:
	var e: DuelEngine = engine(deck(filler(), "vigil", "", "", 3, "tf_marked_lord"), deck(filler(), "pact"))
	var me: PlayerState = e.player(0)
	me.duelist.aspect = 1
	me.hand.clear()
	e._mark_power_used(me.duelist)
	check(not e._power_available(me, me.duelist), "spent, and nothing in hand to buy it back")
	var paid: CardInstance = e._instance(lib.get_def("t_marked_blow"), 0, &"hand")
	me.hand.append(paid)
	check(e._power_available(me, me.duelist), "a marked card in hand opens the second use")
	var plain: CardInstance = e._instance(lib.get_def("t_plain_blow"), 0, &"hand")
	me.hand.append(plain)
	e._charge_extra_use(me, me.duelist)
	check(not me.hand.has(paid), "the marked card is what pays")
	check(me.hand.has(plain), "and the plain one is left alone")
	e._mark_power_used(me.duelist)
	check(not e._power_available(me, me.duelist), "with the cost spent there is no third use")


## "All marked-only attacks do +1 Energy and +1 wound." The Grounds reads the card's play gate,
## which is a different set from the cards that carry the keyword themselves.
func test_grounds_can_read_the_gate_rather_than_the_keyword() -> void:
	var e: DuelEngine = engine(deck(filler(), "vigil", "", "", 3, "tf_marked_lord"), deck(filler(), "pact"))
	var me: PlayerState = e.player(0)
	me.duelist.aspect = 1
	e.state.grounds = e._instance(lib.get_def("t_ring"), 0, &"grounds")
	var gated: CardInstance = e._instance(lib.get_def("t_gated_blow"), 0, &"hand")
	var carried: CardInstance = e._instance(lib.get_def("t_marked_blow"), 0, &"hand")
	eq(e._modifiers_for(me, "own", "strike", gated, {}).size(), 1, "the gated card takes the bonus")
	eq(e._modifiers_for(me, "own", "strike", carried, {}).size(), 0, "carrying the keyword is not the same thing")


## "You may reduce the damage this attack deals by any amount to a minimum of 0. For every wound
## reduced, discard one of your opponent's Drills in play." Capped by the wounds and by the Drills.
func test_an_attack_can_trade_its_own_damage_for_their_drills() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
	var foe: PlayerState = e.player(1)
	inject(e, 1, "t_plain_drill")
	inject(e, 1, "t_plain_drill")
	e.state.attack = {"attacker": 0, "defender": 1, "kind": "art", "life": 3, "stages": 0,
		"spec": {"damage_trade": {"per": 1, "card_type": "drill"}}, "source": -1, "target": -1}
	check(e._prompt_damage_trade(e.player(0), foe, e.state.attack), "the trade is offered")
	eq(e.prompt.options.size(), 3, "none, one Drill or both, and no more than they have")
	e._handle_trade_damage(Command.new(0, &"trade_damage", -1, 2))
	eq(int(e.state.attack["life"]), 1, "two wounds given up")
	eq(foe.drills().size(), 0, "and both Drills gone for them")


## "For the remainder of Combat, during your attack phase you may remove 2 cards in your Reserve
## from the game to remove one of their Drills." It needs both a payable Reserve and a target.
func test_a_ransom_spends_the_reserve_to_strip_a_drill() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
	var me: PlayerState = e.player(0)
	e._apply_effect({"op": "float", "what": "reserve_ransom", "duration": "combat",
		"params": {"cost": 2, "card_type": "drill"}}, 0, {}, null)
	check(e._ransom_options(me).is_empty(), "nothing to pay with and nothing to take")
	for i in range(3):
		me.reserve.append(e._instance(lib.get_def("t_plain_blow"), 0, &"reserve"))
	check(e._ransom_options(me).is_empty(), "a payable Reserve is not enough on its own")
	inject(e, 1, "t_plain_drill")
	eq(e._ransom_options(me).size(), 2, "with a target it offers the two cards it would spend")
	e._handle_ransom(Command.new(0, &"ransom"))
	eq(me.reserve.size(), 1, "two left the Reserve")
	eq(me.removed.size(), 2, "and they left the game")
	eq(e.player(1).drills().size(), 0, "their Drill went with them")


## "Attach to your opponent's duelist. While attached and that personality is in control of Combat,
## damage from your attacks cannot be prevented."
func test_an_attachment_on_their_duelist_can_stop_them_preventing_damage() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
	var me: PlayerState = e.player(0)
	check(not e._attachment_no_prevent(me), "nothing attached yet")
	var gaze: CardInstance = e._instance(lib.get_def("t_gaze"), 0, &"resolving")
	e._attach(gaze, me, "opponent_duelist")
	eq(gaze.attached_to, e.player(1).duelist, "it rides on their duelist")
	check(e._attachment_no_prevent(me), "and their duelist holding Combat turns prevention off")


## "Discard until they have 2 or fewer cards in hand" counts what is held, not what is taken, and
## "discard any Non-Combat cards in his hand" takes every match with nothing to decide.
func test_a_hand_attack_can_count_down_to_a_number_or_take_every_match() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
	var foe: PlayerState = e.player(1)
	foe.hand.clear()
	for i in range(5):
		foe.hand.append(e._instance(lib.get_def("t_plain_blow"), 1, &"hand"))
	e._apply_effect({"op": "discard_hand", "who": "opponent", "down_to": 2, "random": false}, 0, {}, null)
	eq(int(e.prompt.context.get("amount", 0)), 3, "five down to two is three cards")
	e._choice = {}
	e.prompt = null
	e.prompts.clear()
	foe.hand.clear()
	for i in range(2):
		foe.hand.append(e._instance(lib.get_def("t_plain_drill"), 1, &"hand"))
	foe.hand.append(e._instance(lib.get_def("t_plain_blow"), 1, &"hand"))
	e._apply_effect({"op": "discard_hand", "who": "opponent", "all": true, "random": false,
		"filter": "non_combat", "reveal": true}, 0, {}, null)
	eq(foe.hand.size(), 1, "both Drills went and the attack card stayed")
	check(e.prompt == null, "and nothing was asked, because nothing was a choice")


## "Stops an energy attack during your opponent's next attack phase." A one-shot stop that names a
## kind waits for that kind instead of spending itself on the first thing thrown.
func test_a_one_shot_stop_can_wait_for_the_kind_it_names() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
	var me: PlayerState = e.player(0)
	e._apply_effect({"op": "float", "what": "stop_next", "duration": "combat",
		"params": {"kind": "art"}}, 0, {}, null)
	var strike_at_me: Dictionary = {"attacker": 1, "defender": 0, "kind": "strike", "focused": false,
		"stopped": false, "unstoppable": false, "spec": {}, "stop_count": 0, "stops_needed": 1, "target": -1}
	e._apply_shields(me, strike_at_me)
	check(not bool(strike_at_me["stopped"]), "a Strike is not what it waits for, so it goes through")
	var art_at_me: Dictionary = {"attacker": 1, "defender": 0, "kind": "art", "focused": false,
		"stopped": false, "unstoppable": false, "spec": {}, "stop_count": 0, "stops_needed": 1, "target": -1}
	e._apply_shields(me, art_at_me)
	check(bool(art_at_me["stopped"]), "and the Art it named is stopped")


# --- Adventure mode -------------------------------------------------------

const ADVENTURE_SAVE_PATH: String = "user://adventure/test_run.json"
const ADVENTURE_LADDER_SIZE: int = 8
const ADVENTURE_TIER_SUFFIXES: Array[String] = ["_start", "_boss", "_t1", "_t2", "_t3", "_t4", "_t5"]


## The deck id a starter or an opponent was scaled from, so a ladder can be checked for mirrors.
func adventure_deck_family(deck_id: String) -> String:
	for suffix in ADVENTURE_TIER_SUFFIXES:
		if deck_id.ends_with(suffix):
			return deck_id.trim_suffix(suffix)
	return deck_id


## A run is saved between every stage, so it has to survive JSON's floats and come back the same.
func test_an_adventure_run_round_trips_through_json_and_the_save() -> void:
	var run: AdventureRun = AdventureRun.begin("pyre_beatdown_start", 4242)
	check(run != null, "the starter resolves into a run")
	if run == null:
		return
	run.stage = 3
	run.aspects = 3
	run.status = "reward"
	run.pending_offer.append("pyre_kindling")
	run.picks.append({"stage": 0, "kind": "pick", "id": "pyre_kindling"})
	var copy: AdventureRun = AdventureRun.from_dict(run.to_dict())
	eq(copy.starter_id, run.starter_id, "starter survives to_dict")
	eq(copy.cards.size(), run.cards.size(), "deck survives to_dict")
	eq(copy.stage, 3, "stage survives to_dict")
	eq(copy.run_seed, 4242, "seed survives to_dict")
	eq(copy.pending_offer, run.pending_offer, "the pending offer survives to_dict")
	eq(copy.picks.size(), 1, "the pick history survives to_dict")
	# Through a real file, which is where the floats come from.
	AdventureSave.path_override = ADVENTURE_SAVE_PATH
	check(AdventureSave.store(run), "the run writes to disk")
	check(AdventureSave.exists(), "and the save is found again")
	var loaded: AdventureRun = AdventureSave.load_run()
	check(loaded != null, "the save parses back into a run")
	if loaded != null:
		eq(loaded.stage, 3, "stage came back an int")
		eq(loaded.aspects, 3, "aspects came back an int")
		eq(loaded.run_seed, 4242, "seed came back an int")
		eq(loaded.cards, run.cards, "the deck came back whole")
		eq(int(loaded.picks[0].get("stage", -1)), 0, "and a pick row came back an int")
	AdventureSave.clear()
	check(not AdventureSave.exists(), "clear removes the save")
	AdventureSave.path_override = ""
	# Two seed streams off one run seed, neither zero and never the same for a stage.
	for n in range(ADVENTURE_LADDER_SIZE):
		check(run.stage_seed(n) > 0, "stage seed %d is positive" % n)
		check(run.offer_seed(n) > 0, "offer seed %d is positive" % n)
		check(run.stage_seed(n) != run.offer_seed(n), "stage and offer seeds differ at %d" % n)


func test_adventure_ladders_field_legal_opponents() -> void:
	var shipped: CardLibrary = shipped_library()
	var starters: Array[String] = AdventureLadder.playable_starters()
	eq(starters.size(), 4, "four starters have a ladder")
	for starter_id in starters:
		var ladder: AdventureLadder = AdventureLadder.load_for(starter_id)
		check(ladder != null, "%s has a ladder file" % starter_id)
		if ladder == null:
			continue
		eq(ladder.size(), ADVENTURE_LADDER_SIZE, "%s ladder has 8 stages" % starter_id)
		var own_family: String = adventure_deck_family(starter_id)
		var granted: int = 0
		for n in range(ladder.size()):
			var row: Dictionary = ladder.stage(n)
			var opponent: String = str(row.get("opponent", ""))
			var opponent_deck: DeckList = DeckList.resolve(opponent)
			check(opponent_deck != null, "%s stage %d opponent '%s' resolves" % [starter_id, n + 1, opponent])
			if opponent_deck != null:
				var problems: Array[String] = DeckValidator.validate(opponent_deck, shipped)
				eq(problems.size(), 0, "%s stage %d '%s' is legal: %s" % [starter_id, n + 1, opponent, ", ".join(problems)])
			check(adventure_deck_family(opponent) != own_family,
				"%s stage %d is not a mirror of %s" % [starter_id, n + 1, own_family])
			var level: String = str(row.get("ai_level", ""))
			check(FileAccess.file_exists("res://data/ai/profiles/%s.json" % level),
				"%s stage %d ai_level '%s' has a profile" % [starter_id, n + 1, level])
			eq(str(row.get("story", "x")), "", "%s stage %d has no story text yet" % [starter_id, n + 1])
			if str(row.get("grant", "")) == "aspect":
				granted += 1
		eq(granted, 1, "%s grants exactly one Aspect" % starter_id)


## The reward screen never shows a card the validator would refuse, and never someone else's.
func test_an_adventure_offer_is_three_legal_cards_the_deck_can_run() -> void:
	var shipped: CardLibrary = shipped_library()
	for starter_id in AdventureLadder.playable_starters():
		var ladder: AdventureLadder = AdventureLadder.load_for(starter_id)
		var run: AdventureRun = AdventureRun.begin(starter_id, 91011)
		if ladder == null or run == null:
			check(false, "%s has both a ladder and a starter deck" % starter_id)
			continue
		var duelist: CardDef = shipped.defs.get(run.deck().duelist_id)
		var style: String = run.deck().style
		for n in range(ladder.size()):
			AdventureRewards.finish_stage(run, ladder, shipped, true)
			eq(run.status, "reward", "%s stage %d ends on the reward screen" % [starter_id, n + 1])
			var offer: Array[String] = run.pending_offer
			eq(offer.size(), 3, "%s stage %d offers three cards" % [starter_id, n + 1])
			var seen: Dictionary = {}
			for id in offer:
				check(not seen.has(id), "%s stage %d offers distinct ids" % [starter_id, n + 1])
				seen[id] = true
				var def: CardDef = shipped.defs.get(id)
				check(def != null, "%s stage %d offers a known card '%s'" % [starter_id, n + 1, id])
				if def == null:
					continue
				check(def.type != CardDef.Type.PERSONALITY and def.type != CardDef.Type.SEAL
					and def.type != CardDef.Type.GROUNDS and def.type != CardDef.Type.MASTERY
					and def.type != CardDef.Type.RELIC,
					"%s stage %d: '%s' is a Life Deck card type" % [starter_id, n + 1, id])
				check(def.school == "" or def.school == style,
					"%s stage %d: '%s' is %s, deck Style is %s" % [starter_id, n + 1, id, def.school, style])
				if style == "freestyle":
					eq(def.school, "", "%s stage %d: '%s' carries no school" % [starter_id, n + 1, id])
				check(def.character == "" or def.character == duelist.character,
					"%s stage %d: '%s' is not another duelist's signature" % [starter_id, n + 1, id])
				var trial: DeckList = run.deck()
				trial.cards.append(id)
				var problems: Array[String] = DeckValidator.validate(trial, shipped)
				eq(problems.size(), 0, "%s stage %d: adding '%s' stays legal: %s"
					% [starter_id, n + 1, id, ", ".join(problems)])
			check(AdventureRewards.apply_pick(run, shipped, offer[0] if offer.size() > 0 else ""),
				"%s stage %d picks the first card" % [starter_id, n + 1])
			AdventureRewards.finish_reward(run, ladder)
		eq(run.status, "won", "%s reaches the end of its ladder" % starter_id)


func test_the_stage_two_grant_raises_the_aspect_count() -> void:
	var shipped: CardLibrary = shipped_library()
	var ladder: AdventureLadder = AdventureLadder.load_for("pyre_beatdown_start")
	var run: AdventureRun = AdventureRun.begin("pyre_beatdown_start", 7)
	eq(run.aspects, 2, "a starter opens at two Aspects")
	AdventureRewards.finish_stage(run, ladder, shipped, true)
	eq(run.aspects, 2, "stage 1 grants nothing")
	AdventureRewards.apply_skip(run)
	AdventureRewards.finish_reward(run, ladder)
	AdventureRewards.finish_stage(run, ladder, shipped, true)
	eq(run.aspects, 3, "stage 2 grants the third Aspect")
	var problems: Array[String] = DeckValidator.validate(run.deck(), shipped)
	eq(problems.size(), 0, "and the deck is still legal: %s" % ", ".join(problems))
	# A loss ends the run wherever it happens.
	var lost: AdventureRun = AdventureRun.begin("pyre_beatdown_start", 7)
	AdventureRewards.finish_stage(lost, ladder, shipped, false)
	eq(lost.status, "lost", "a loss ends the run")


func test_adventure_offers_follow_the_run_seed() -> void:
	var shipped: CardLibrary = shipped_library()
	var first: Array[String] = adventure_offer_sequence(shipped, "pyre_beatdown_start", 555)
	var again: Array[String] = adventure_offer_sequence(shipped, "pyre_beatdown_start", 555)
	var other: Array[String] = adventure_offer_sequence(shipped, "pyre_beatdown_start", 556)
	eq(first, again, "the same run seed offers the same cards")
	check(first != other, "a different run seed offers a different sequence somewhere")


## Every offered id of an all-wins, always-skip run, flattened.
func adventure_offer_sequence(shipped: CardLibrary, starter_id: String, run_seed: int) -> Array[String]:
	var out: Array[String] = []
	var ladder: AdventureLadder = AdventureLadder.load_for(starter_id)
	var run: AdventureRun = AdventureRun.begin(starter_id, run_seed)
	if ladder == null or run == null:
		return out
	for n in range(ladder.size()):
		AdventureRewards.finish_stage(run, ladder, shipped, true)
		out.append_array(run.pending_offer)
		AdventureRewards.apply_skip(run)
		AdventureRewards.finish_reward(run, ladder)
	return out


## A stale offer held by a client cannot smuggle a card in.
func test_an_adventure_pick_is_refused_when_it_was_not_offered() -> void:
	var shipped: CardLibrary = shipped_library()
	var ladder: AdventureLadder = AdventureLadder.load_for("pyre_beatdown_start")
	var run: AdventureRun = AdventureRun.begin("pyre_beatdown_start", 31)
	AdventureRewards.finish_stage(run, ladder, shipped, true)
	var before: int = run.cards.size()
	check(not AdventureRewards.apply_pick(run, shipped, "not_a_card_id"), "an unoffered id is refused")
	eq(run.cards.size(), before, "and the deck is untouched")
	eq(run.pending_offer.size(), 3, "and the offer is still standing")
	check(AdventureRewards.apply_pick(run, shipped, run.pending_offer[0]), "an offered id goes in")
	eq(run.cards.size(), before + 1, "the deck grew by one card")
	eq(run.pending_offer.size(), 0, "and the offer is spent")
	eq(str(run.picks[run.picks.size() - 1].get("kind", "")), "pick", "the pick is recorded")
	eq(run.stage, 0, "picking does not advance the stage")


func test_an_adventure_cut_is_refused_at_the_card_floor() -> void:
	var shipped: CardLibrary = shipped_library()
	var run: AdventureRun = AdventureRun.begin("pyre_beatdown_start", 12)
	var guard: int = 0
	while AdventureRewards.can_cut(run) and guard < 200:
		guard += 1
		if not AdventureRewards.apply_cut(run, shipped, run.cards[0]):
			break
	check(guard > 0, "some cards came out")
	check(not AdventureRewards.can_cut(run), "the floor stops the cutting")
	check(not AdventureRewards.apply_cut(run, shipped, run.cards[0]), "and a further cut is refused")
	var cut_deck: DeckList = run.deck()
	eq(cut_deck.total_cards(), DeckValidator.MIN_CARDS_ADVENTURE, "the deck sits on the validator's floor")
	var problems: Array[String] = DeckValidator.validate(cut_deck, shipped)
	eq(problems.size(), 0, "and it is still legal: %s" % ", ".join(problems))
	check(not AdventureRewards.apply_cut(run, shipped, "not_a_card_id"), "a card not in the deck cannot be cut")


## The check tools/validate_starters.gd runs, so adventure data is covered by the suite.
func test_adventure_starters_and_opponents_are_legal() -> void:
	var shipped: CardLibrary = shipped_library()
	var seen: int = 0
	for source in ["res://data/adventure/starters", "res://data/adventure/opponents"]:
		var dir: DirAccess = DirAccess.open(source)
		check(dir != null, "%s exists" % source)
		if dir == null:
			continue
		for entry in dir.get_files():
			if not entry.ends_with(".json"):
				continue
			seen += 1
			var d: DeckList = DeckList.load_from(source + "/" + entry)
			var problems: Array[String] = DeckValidator.validate(d, shipped)
			eq(problems.size(), 0, "%s legal: %s" % [entry, ", ".join(problems)])
	check(seen > 80, "every adventure deck was checked, saw %d" % seen)
