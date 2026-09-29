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
		test_steel_and_root_masteries_need_their_bloodline,
		test_every_art_file_belongs_to_a_card_in_its_group_folder,
		test_title_searches_still_find_their_cards,
		test_shipped_decks_are_legal,
		test_freestyle_mastery_searches_named_support_cards,
		test_setup_and_first_turn,
		test_surge_has_no_style_bonus,
		test_non_combat_placement,
		test_drill_school_lock,
		test_grounds_forces_skip_and_recover,
		test_strike_damage_and_fight_back,
		test_the_first_attacker_is_named_as_combat_opens,
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
		test_double_power_rule_decides_first_player,
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
		test_attack_badge_table_base,
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
		test_declaring_needs_something_to_do,
		test_the_search_leaves_a_final_strike_to_the_scorer,
		test_grounds_can_tax_one_kind_of_attack,
		test_a_restriction_can_last_one_attack_phase_not_the_whole_combat,
		test_restrictions_list_what_the_rules_forbid,
		test_a_barred_stop_all_does_not_skip_the_defense,
		test_a_profile_can_pivot_on_the_matchup,
		test_a_profile_can_pivot_on_where_the_duel_stands,
		test_a_forced_combat_skip_says_why,
		test_command_wire_lockstep,
		test_uids_hide_deck_order,
		test_seat_view_masks_hidden_cards,
		test_referee_gates_commands,
		test_card_text_wording,
		test_card_text_condenses_repeated_branches,
		test_rules_layout_splits_text_into_blocks_and_chips,
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
		test_scorer_reads_effects_the_way_the_engine_resolves_them,
		test_scorer_prices_optional_costs_burns_and_keeps,
		test_scorer_counts_the_mastery_lines_an_attack_triggers,
		test_scorer_prices_may_lines_relic_uses_and_soaked_energy,
		test_scorer_prices_lines_against_the_table,
		test_scorer_reads_attacks_the_way_they_land,
		test_scorer_prices_critical_and_capture_choices,
		test_evaluator_discounts_refilled_energy_and_doomed_hand_cards,
		test_search_defers_to_the_scorer_on_stances_and_near_ties,
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
		test_ally_legality_does_not_read_the_decks_aspect_count,
		test_profile_state_key_matches_the_seat_view,
		test_branch_margin_keeps_the_leader_and_drops_the_tail,
		test_search_merges_identical_moves_from_hand,
		test_a_profile_can_leave_prompt_kinds_to_the_scorer,
		test_an_ally_power_refreshes_each_combat,
		test_the_taller_ladder_wins_by_standing_above_it,
		test_edric_gives_ground_goes_under_the_deck_only_for_edric,
		test_closing_ranks_rides_along_with_the_attack,
		test_storm_focused_bolt_blanks_their_next_attack_phase_of_strikes,
		test_storm_assailing_arc_pulls_their_energy_down_to_yours,
		test_storm_trick_shot_pays_energy_for_every_later_hit,
		test_shade_draining_blast_deals_energy_and_refunds_its_user,
		test_first_to_two_a_deck_out_scores_a_point_and_reshuffles,
		test_first_to_two_the_hit_that_scores_loses_its_leftover_damage,
		test_first_to_two_an_ascension_scores_once_and_resets_nothing,
		test_first_to_two_a_seal_set_scores_one_point_under_the_adventure_rules,
		test_lives_are_per_seat_so_the_player_falls_twice_and_the_opponent_once,
		test_entering_combat_roles_read_attacker_and_defender,
		test_a_standoff_keeps_only_the_users_hand,
		test_a_non_combat_search_that_takes_nothing_is_still_spent,
		test_recovering_top_and_bottom_never_takes_one_card_twice,
		test_the_integrity_check_catches_a_card_in_two_places,
		test_adventure_rules_give_the_boss_two_lives_and_everyone_else_one,
		test_a_sim_match_with_lives_gives_each_seat_its_own_points_to_win,
		test_an_adventure_run_round_trips_through_json_and_the_save,
		test_adventure_bands_field_every_tier,
		test_adventure_map_is_three_acts_of_connected_tiers,
		test_adventure_map_paths_hold_two_to_five_fights,
		test_adventure_map_fields_legal_opponents,
		test_adventure_storylines_set_act_bosses,
		test_lead_in_slots_follow_how_the_pair_met,
		test_lead_in_general_call_gets_a_fitting_reply,
		test_lead_in_joined_ally_and_whisper_add_a_line,
		test_lead_in_data_is_well_formed,
		test_story_log_records_results_and_round_trips,
		test_adventure_encounters_bring_a_guest_from_the_storyline,
		test_a_guest_ally_starts_in_play,
		test_adventure_boss_win_joins_the_run,
		test_adventure_achievements_track_steps,
		test_adventure_journal_routes,
		test_adventure_xp_levels_pay_milestones,
		test_every_reward_bundle_is_well_formed,
		test_an_adventure_offer_is_three_legal_bundles_the_deck_can_run,
		test_the_first_duel_grant_offers_an_aspect_choice,
		test_adventure_offers_follow_the_run_seed,
		test_an_adventure_bundle_is_refused_when_it_was_not_offered,
		test_an_ally_bundle_brings_its_named_cards_and_opens_the_follow_ups,
		test_an_adventure_cut_is_refused_at_the_card_floor,
		test_adventure_starters_and_opponents_are_legal,
		test_a_card_can_wait_for_a_five_wound_hit,
		test_seals_can_be_put_under_their_owners_life_deck,
		test_naming_a_strike_strips_every_copy_from_their_deck,
		test_naming_nothing_still_counts_as_the_search,
		test_a_look_can_send_the_whole_look_to_either_end,
		test_a_card_can_reach_into_the_rivals_deck_and_remove_one,
		test_an_attachment_can_waive_what_attacks_cost,
		test_the_cost_waiver_needs_the_school_in_hand,
		test_a_drill_can_price_arts_lower,
		test_the_entering_combat_window_is_the_only_time_that_card_is_offered,
		test_both_players_get_an_entering_combat_window_active_first,
		test_a_card_can_answer_the_hit_it_just_took,
		test_the_after_damage_window_reads_what_the_attack_actually_dealt,
		test_a_next_phase_stop_waits_for_the_phase_it_names,
		test_a_stop_set_while_defending_reaches_their_next_phase,
		test_a_hand_discard_can_name_the_band_it_takes,
		test_one_choice_can_reach_a_non_combat_an_ally_or_the_grounds,
		test_a_burn_can_take_the_bottom_of_the_discard_pile,
		test_a_burn_can_take_any_number_of_cards_from_the_pile,
		test_a_hand_effect_reads_from_the_right_side,
		test_a_standing_bonus_can_leave_out_the_attack_that_set_it,
		test_a_rider_can_exile_the_top_of_your_own_deck,
		test_a_gate_can_want_an_ally_and_a_variant_can_read_their_keyword,
		test_the_expansion_cards_are_in_the_shipped_library,
		test_the_storm_strike_answers_stop_a_strike,
		test_storm_twin_earthing_stops_their_next_strike_as_well,
		test_the_expansion_shield_drills_take_one_attack_of_their_kind,
		test_storm_conduit_drill_and_idle_spark_move_what_an_art_costs,
		test_storm_scattering_gale_puts_their_seals_under_their_deck,
		test_storm_free_current_waives_costs_for_a_storm_hand,
		test_storm_mustering_peal_waits_for_a_five_wound_hit,
		test_storm_silencing_static_names_a_strike_and_strips_their_deck,
		test_storm_return_stroke_refills_and_returning_front_goes_under_the_deck,
		test_root_sightline_drill_sends_the_whole_look_to_one_end,
		test_root_trail_cut_reaches_into_their_deck,
		test_root_thorn_hedge_goes_into_play_when_hit_and_is_used_later,
		test_root_quickening_is_focused_against_a_marked_duelist,
		test_root_kin_clearing_needs_an_ally_before_it_clears_the_table,
		test_root_old_growth_spends_your_own_deck_or_your_hand,
		test_root_scattered_seed_pays_whether_it_lands_or_not,
		test_root_briar_tangle_remains_for_two_more_uses,
		test_pyre_rising_heat_reads_fervor_and_banked_coals_holds_it,
		test_pyre_hearthstone_keeps_drills_through_a_climb_only,
		test_pyre_endurance_x_and_drawing_flue_read_fervor,
		test_pyre_burned_through_bars_endurance_against_pyre_only,
		test_pyre_flare_volley_may_discard_a_card_for_more_wounds,
		test_pyre_white_flame_removes_its_wounds_and_draws_from_the_bottom,
		test_pyre_unmaking_blaze_trades_its_damage_for_an_aspect,
		test_pyre_heat_haze_stops_every_art_once_fervor_is_up,
		test_pyre_choking_smoke_burns_their_pile_at_low_fervor,
		test_pyre_burnt_offering_drill_spends_the_whole_hand,
		test_pyre_cinder_sift_drill_buys_a_card_back_on_a_landed_strike,
		test_pyre_conflagration_clears_both_tables,
		test_pyre_bonfire_puts_several_drills_into_play,
		test_pyre_tinder_mastery_burns_the_top_discard_for_strike_energy,
		test_pyre_cinder_mastery_lowers_fervor_and_punishes_a_block,
		test_a_cost_floor_never_raises_a_cheaper_attack,
		test_pyre_smoldering_drill_sits_outside_the_drill_school_lock,
		test_pyre_backdraft_stops_every_art_against_its_user,
		test_pyre_scouring_flame_reaches_either_side_of_the_table,
		test_pyre_firestorm_takes_all_allies_or_all_drills,
		test_pyre_blazing_charge_bars_prevention_by_strike_cards,
		test_pyre_flame_lash_keeps_its_fervor_when_empowered_and_stacks_the_rest_on_top,
		test_pyre_rekindling_and_phoenix_flame_must_take_from_the_pile,
		test_pyre_sword_cleave_lends_its_word_only_to_attacks_from_hand,
		test_pyre_blazing_hide_makes_fervor_hits_secondary,
		test_pyre_conflagration_is_paid_by_the_duelist,
		test_steel_shipped_cards_match_their_printed_text,
		test_steel_drills_tax_and_starve_the_opponent,
		test_steel_towering_frame_doubles_only_the_table,
		test_steel_endurance_pays_and_counts,
		test_steel_scorching_breath_covers_its_own_wounds,
		test_steel_blood_unbound_is_discarded_to_power_a_strike,
		test_steel_masteries_show_the_drawn_card,
		test_steel_bloodrage_mastery_writes_onto_attacks_and_pays_on_recovery,
		test_steel_constricting_grip_holds_their_surge_at_zero,
		test_steel_drawn_breath_banks_the_gain_for_the_next_attack,
		test_steel_cornered_blood_and_awakened_blood_read_empower_and_damage,
		test_tide_shipped_cards_match_their_printed_text,
		test_tide_mooring_and_salt_burn_drills,
		test_tide_frozen_over_holds_fervor_until_their_turn,
		test_tide_sounding_lets_the_opponent_pick_below_aspect_three,
		test_tide_backwash_returns_a_card_per_fervor,
		test_tide_drowning_numbers_read_their_fervor,
		test_tide_narrow_channel_and_parting_waters,
		test_tide_leeching_brine_rides_their_duelist,
		test_tide_masteries_stop_with_a_discard_and_grant_arts_a_line,
		test_shade_prying_whisper_removes_unless_they_discard,
		test_shade_silenced_whisper_lets_them_choose_and_shows_a_seal_hand,
		test_shade_returning_whisper_leaves_the_game_only_on_a_hit,
		test_shade_stilling_whisper_shuts_off_a_non_combat_card,
		test_shade_wasting_mark_weakens_their_attacks_until_full,
		test_shade_opening_whisper_must_be_the_first_card,
		test_shade_searches_and_names_reach_their_life_deck,
		test_shade_mockery_hex_and_creeping_dark_mill_by_the_numbers,
		test_shade_stolen_secret_looks_skips_and_banks,
		test_shade_drills_answer_hits_and_stops,
		test_shade_masteries_discard_to_hurt_their_hand,
		test_root_vine_and_thorns_shuffle_discards_back,
		test_root_seed_burst_sifts_four_and_removes_two,
		test_storm_sensei_relic_moves_one_wound_each_way,
		test_surging_drill_adds_the_performers_surge,
		test_fivefold_spark_empowers_into_three_unfocused_uses,
		test_unpaid_bolt_waives_art_costs_for_the_combat,
		test_centering_raises_a_personality_and_frees_its_next_art,
		test_art_costs_can_be_paid_with_a_life_card,
		test_scavenger_trades_three_discards_for_a_small_art,
		test_braking_drill_caps_strike_energy_damage,
		test_razing_drill_fires_at_the_start_of_every_turn,
		test_braced_beam_puts_grounds_into_play,
		test_vigilant_effort_hardens_against_a_pact_duelist,
		test_storm_sensei_cards_read_as_printed,
		test_root_new_shoots_takes_the_top_or_bottom_three,
		test_root_swallowing_earth_puts_a_seal_under_its_deck,
		test_root_guards_stop_their_kind,
		test_root_stone_cleaver_bars_shields_and_takes_allies,
		test_root_strangling_vine_silences_a_drill_for_the_game,
		test_root_sap_flow_discounts_costs_outside_the_drill_lock,
		test_root_fallen_oak_and_grove_kin_spend_allies,
		test_root_compost_and_deeproot_masteries_draw_on_a_root_card,
		test_root_sacred_grove_exiles_other_schools_and_grants_a_hit,
		test_storm_brewing_mastery_asks_wound_or_price,
		test_storm_squall_mastery_locks_strikes_after_a_storm_art,
		test_every_mastery_line_runs_on_a_mastery_trigger,
		test_storm_shipped_cards_match_their_printed_text,
		test_storm_backflash_and_grounding_drills_answer_the_defense,
		test_storm_seeking_spark_and_stormwall_drills,
		test_storm_gathering_front_lightning_rod_and_steady_current,
		test_storm_gale_and_conductor_masteries,
		test_freestyle_cards_match_their_printed_text,
		test_a_banned_card_is_an_adventure_bomb_only,
		test_signature_cards_match_their_printed_text,
		test_personalities_match_their_printed_cards,
		test_banned_bombs_counter_level_and_feed,
		test_a_boss_power_is_used_from_outside_the_deck,
		test_the_card_group_tells_signature_from_freestyle,
		test_every_shipped_card_lands_in_one_group,
		test_a_duelist_stack_is_one_character_consecutive_from_aspect_one,
		test_a_duelist_may_mix_two_printed_lines_of_one_character,
		test_mppv_reads_the_announced_ladders_off_the_deck_lists,
		test_an_ally_in_the_deck_is_any_aspect_one_to_three,
		test_an_ally_climbs_by_overlaying_its_next_aspect,
		test_both_players_may_field_the_same_ally,
		test_an_ally_may_share_a_character_with_the_rival_duelist,
		test_discarding_an_overlaid_ally_takes_all_of_its_aspects,
		test_fervor_never_moves_an_allys_aspect,
		test_a_seat_view_carries_the_current_aspect_card_and_the_public_ladder,
		test_cloning_and_determinizing_keep_a_stack_whole,
		test_every_shipped_deck_names_a_legal_duelist_stack,
		test_every_shipped_personality_is_on_the_compact_might_scale,
		test_gideon_mournes_ladder_sits_where_the_other_four_aspect_duelist_sits,
		test_an_adventure_run_gains_the_next_aspect_card_of_its_own_line,
		test_the_card_group_answers_for_every_non_hand_type,
		test_a_personality_is_named_by_its_character_alone,
		test_the_deck_detail_labels_a_one_line_stack_and_a_mixed_one,
		test_an_option_carries_the_owner_only_for_a_card_on_the_table,
		test_a_side_marker_appears_only_when_two_options_read_alike,
		test_the_log_names_the_owner_when_both_sides_hold_one_title,
		test_motes_price_a_card_by_its_printed_tell,
		test_the_wallet_earns_spends_and_refuses_what_it_cannot_pay,
		test_the_collection_holds_what_a_deck_may_run_and_dissolves_the_rest,
		test_a_won_run_pays_out_and_settles_its_cards_at_a_discount,
		test_a_run_lost_at_stage_five_keeps_four_payouts_and_pays_full_price,
		test_the_vendor_sells_a_rotating_shelf_of_buyable_cards,
		test_a_loadout_swap_is_legal_only_through_the_validator,
		test_a_run_settles_for_what_it_added_across_a_save,
		test_the_collection_caps_at_three_four_or_one_and_dissolves_the_rest,
		test_keeping_and_buying_stop_at_the_collection_cap,
		test_a_loadout_takes_no_more_copies_than_the_collection_holds,
		test_the_loadout_stops_at_the_full_deck_maximum_before_the_validator_does,
		test_bought_deck_slots_raise_the_loadout_cap_at_a_rising_price,
		test_owned_aspects_gate_the_loadout_and_the_run,
		test_the_upgrades_file_round_trips_through_a_path_override,
		test_the_pending_queue_lists_what_resolves_next_in_order,
		test_a_pending_job_the_seat_cannot_see_reads_as_hidden,
		test_the_pending_queue_shows_the_attack_and_the_wounds_it_is_still_flipping,
		test_a_response_window_with_nothing_in_it_still_says_so,
		test_the_quiet_combat_beats_reach_the_client_as_events,
		test_a_lost_life_card_reaches_the_client_once,
		test_an_unstoppable_attack_offers_no_defense,
		test_the_view_counts_the_passes_that_would_end_combat,
		test_combat_beats_are_stamped_with_the_phase_they_belong_to,
		test_the_fighters_numbers_carry_their_printed_baseline,
		test_a_portrait_backdrop_takes_the_colour_of_its_decks_mastery,
		test_presence_keeps_only_known_keys_with_the_right_types,
		test_presence_clamps_the_pointer_and_the_hand_slot,
		test_presence_hand_hover_is_a_slot_and_nothing_else,
		test_presence_never_names_a_card_the_receiver_cannot_see,
		test_presence_caps_strings_and_refuses_unknown_looks,
		test_a_follow_up_is_used_inside_the_attack_it_follows,
		test_declining_a_follow_up_leaves_the_attack_as_it_was,
		test_the_integrity_check_catches_a_card_in_no_list,
		test_an_adventure_run_saves_its_duel_history,
		test_a_referee_rebuilt_from_its_history_stands_in_the_same_place,
		test_a_duel_result_is_recorded_once,
		test_a_conceded_duel_is_a_loss_and_leaves_no_history,
		test_a_drill_blocks_from_play_and_stays_there,
		test_a_non_combat_blocks_only_once_placed,
		test_a_non_combat_block_goes_where_its_text_says,
		test_a_placed_stop_all_non_combat_stops_the_rest_of_combat,
		test_a_combat_block_runs_its_rider_as_part_of_the_stop,
		test_a_forbidden_non_combat_or_drill_cannot_block_from_play,
		test_chance_picks_the_opener_from_the_seed,
		test_a_forced_opener_overrides_double_power_and_chance,
		test_a_match_record_comes_back_whole_from_its_line,
		test_a_match_record_rebuilds_its_duel_for_replay,
		test_the_match_record_loader_refuses_what_it_cannot_check,
		test_client_match_records_keep_their_last_lines_where_they_are_pointed,
		test_match_stats_count_each_deck_and_its_wilson_range,
		test_match_stats_read_the_matchup_grid_the_same_from_both_seats,
		test_match_stats_give_the_first_player_rate_overall_and_per_deck,
		test_match_stats_bucket_concessions_and_share_out_the_endings,
		test_match_stats_group_records_by_catalog,
		test_match_stats_skip_dev_client_and_unverified_records,
		test_match_stats_count_the_cards_of_two_replayed_duels,
		test_a_decision_clock_gives_each_kind_of_prompt_its_time,
		test_a_decision_clock_warns_then_drains_the_bank,
		test_a_decision_clock_banks_time_at_each_own_turn_up_to_the_cap,
		test_decision_clocks_run_per_seat_and_the_earlier_deadline_loses,
		test_a_decision_clock_waits_for_its_panel_or_its_grace,
		test_a_catch_up_gives_a_seat_its_view_prompt_and_this_turn,
		test_a_replay_stepped_to_its_end_stands_where_the_duel_ended,
		test_a_replay_jump_shows_the_table_stepping_there_shows,
		test_a_replay_step_back_then_forward_returns_to_the_same_table,
		test_a_full_information_replay_names_every_card,
		test_a_replay_reads_client_and_server_records_from_their_files,
		test_queue_pairs_two_oldest_first,
		test_queue_ignores_duplicate_join,
		test_queue_forgets_a_leaver,
		test_requeue_keeps_join_time,
		test_queue_holds_pairs_at_the_duel_cap,
		test_queue_drops_after_max_wait,
		test_an_identity_keeps_its_key_and_signs_only_its_own_bytes,
		test_the_rating_port_matches_the_openskill_golden_fixture,
		test_a_rating_shows_forty_times_its_ordinal_and_is_provisional_while_unsure,
		test_the_ratings_store_round_trips_and_rebuilds_from_the_records,
		test_the_leaver_ladder_climbs_and_clears_after_a_day,
		test_the_ranked_queue_pairs_on_mu_within_a_widening_window,
		test_the_ranked_queue_does_not_pair_the_same_two_twice_in_a_row,
		test_a_version_2_record_carries_its_match_and_a_version_1_record_still_loads,
		test_match_stats_count_ranked_matches_by_deck_and_by_score,
		test_a_match_conceded_as_a_whole_loads_and_counts_like_a_concession,
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


## `duelist` names a stack, not a card: the fixture ladders are one card per Aspect, `<base>_1`
## up to `<base>_5`, and `aspects` says how many rungs the deck runs. A base with no `_1` card is
## taken as a character name and resolved against the shipped library, lowest id per Aspect.
func stack_ids(duelist: String, aspects: int) -> Array[String]:
	var out: Array[String] = []
	if lib.has("%s_1" % duelist):
		for i in range(1, aspects + 1):
			out.append("%s_%d" % [duelist, i])
		return out
	var source: CardLibrary = lib if lib.has("%s_1" % duelist) else shipped()
	var by_aspect: Dictionary = {}
	for id in source.all_ids():
		var def: CardDef = source.defs[id]
		if not def.is_personality() or def.character != duelist:
			continue
		# A character with two printed lines offers two cards at a tier. Prefer the one that
		# prints an Aspect title, which is the one written as a Duelist rung.
		var held: String = str(by_aspect.get(def.aspect, ""))
		if held == "" or (def.aspect_title != "" and (source.defs[held] as CardDef).aspect_title == ""):
			by_aspect[def.aspect] = id
	for i in range(1, aspects + 1):
		if by_aspect.has(i):
			out.append(str(by_aspect[i]))
	return out


func deck(cards: Array[String], alignment: String = "vigil", style: String = "", mastery: String = "", aspects: int = 3, duelist: String = "tf_vigil", relic: String = "", reserve: Array[String] = []) -> DeckList:
	var d: DeckList = DeckList.new()
	d.relic_id = relic
	d.reserve = reserve.duplicate()
	d.name = "Test %s" % alignment
	d.set_duelist(stack_ids(duelist, aspects))
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
	vigil_opens(e, a, b)
	e.start()
	return e


## Helper-built duels between a Vigil and a Pact deck open with the Vigil seat when chance would
## decide, so every fixture test keeps its seating. Same-side pairings and Double Power stay as the
## engine rules them.
func vigil_opens(e: DuelEngine, a: DeckList, b: DeckList) -> void:
	if a.alignment == b.alignment:
		return
	for ev in e.events:
		if ev.type == &"setup" and str(ev.data.get("reason", "")) == "chance":
			e.set_first_player(0 if a.alignment == "vigil" else 1)


## The data of the engine's `setup` event, or {} when it has been taken.
func setup_event(e: DuelEngine) -> Dictionary:
	for ev in e.events:
		if ev.type == &"setup":
			return ev.data
	return {}


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
	eq(lib.get_def("tf_vigil_1").aspect, 1, "the fixture ladder is one card per Aspect")
	eq(PersonalityStack.from_ids(lib, stack_ids("tf_vigil", 3)).highest_aspect(), 3, "vigil aspects")
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


func test_every_art_file_belongs_to_a_card_in_its_group_folder() -> void:
	var shipped: CardLibrary = shipped_library()
	var root: String = CardFace.ART_DIR
	var files: int = 0
	for group in DirAccess.get_directories_at(root):
		for f in DirAccess.get_files_at(root + group):
			if not (f.ends_with(".png") or f.ends_with(".svg")):
				continue
			files += 1
			var id: String = f.get_basename()
			check(shipped.defs.has(id), "art %s/%s names a card" % [group, f])
			eq(id.get_slice("_", 0), group, "art %s sits in its group folder" % f)
	check(files > 300, "the art folders were read: %d files" % files)
	eq(CardFace.art_path("pyre_strike_07"), root + "pyre/pyre_strike_07", "the art path follows the id's group")


func test_title_searches_still_find_their_cards() -> void:
	var shipped: CardLibrary = shipped_library()
	var titles: Array[String] = []
	for def in shipped.defs.values():
		titles.append((def as CardDef).title)
	for word in ["Sword", "Swordplay", "Sweep", "Steel Kindred Standoff", "Caedan's Sword Draw"]:
		var found: int = 0
		for t in titles:
			if t.contains(word):
				found += 1
		check(found > 0, "a card title still contains \"%s\"" % word)


func test_steel_and_root_masteries_need_their_bloodline() -> void:
	var shipped: CardLibrary = shipped_library()
	var steel: DeckList = DeckList.load_from("res://data/decks/steel_beatdown.json")
	eq(", ".join(DeckValidator.validate(steel, shipped)), "", "a Draconic Duelist may run Steel")
	var outsider: Array[String] = ["personality_07", "personality_08",
		"personality_09"]
	steel.set_duelist(outsider)
	var problems: String = ", ".join(DeckValidator.validate(steel, shipped))
	check(problems.contains("needs a Draconic Duelist"), "a Duelist of no line may not: %s" % problems)
	var root: DeckList = DeckList.load_from("res://data/decks/root_seals.json")
	root.set_duelist(outsider)
	problems = ", ".join(DeckValidator.validate(root, shipped))
	check(problems.contains("needs a Verdant Duelist"), "Root asks for Verdant: %s" % problems)
	check(CardText.rules_text(shipped.defs["steel_mastery_01"]).contains("Draconic duelists only."),
		"the Mastery prints its gate")


func test_a_portrait_backdrop_takes_the_colour_of_its_decks_mastery() -> void:
	var shipped: CardLibrary = CardLibrary.new()
	shipped.load_dir("res://data/cards")
	var pyre: DeckList = DeckList.load_from("res://data/decks/pyre_attrition.json")
	var tide: DeckList = DeckList.load_from("res://data/decks/tide_deepwater.json")
	var face: CardDef = shipped.defs.get(pyre.duelist_face_id())
	var pyre_mastery: CardDef = shipped.defs.get(pyre.mastery_id)
	var tide_mastery: CardDef = shipped.defs.get(tide.mastery_id)
	check(face != null and pyre_mastery != null and tide_mastery != null, "shipped decks resolve")
	if face == null or pyre_mastery == null or tide_mastery == null:
		return
	CardFace.default_backdrop = CardFace.NEUTRAL_BACKDROP
	eq(CardFace.resolve_backdrop(CardFace.NO_BACKDROP), CardFace.NEUTRAL_BACKDROP, "no deck named means the neutral dark")
	var pyre_color: Color = CardFace.mastery_backdrop(pyre, shipped)
	eq(pyre_color, Palette.SCHOOL_COLORS[pyre_mastery.school].darkened(CardFace.BACKDROP_DARKEN), "the backdrop is the deck's Mastery hue, darkened")
	# The same duelist in a deck with another school's Mastery, as both seats of one duel.
	var borrowed: DeckList = DeckList.load_from("res://data/decks/pyre_attrition.json")
	borrowed.mastery_id = tide.mastery_id
	var tide_color: Color = CardFace.mastery_backdrop(borrowed, shipped)
	check(tide_color != pyre_color, "a Tide Mastery gives the same duelist another backdrop")
	check(CardFaceCache.key_for(face, 1, pyre_color) != CardFaceCache.key_for(face, 1, tide_color), "one duelist for two decks is two cached faces")
	eq(CardFaceCache.key_for(face, 1, pyre_color), CardFaceCache.key_for(face, 1, pyre_color), "the key is stable for one deck")
	var strike: CardDef = null
	for id in pyre.cards:
		var def: CardDef = shipped.defs.get(id)
		if def != null and not def.is_personality():
			strike = def
			break
	check(strike != null and CardFaceCache.key_for(strike, 0, pyre_color) == CardFaceCache.key_for(strike, 0, tide_color), "cards without a portrait ignore the backdrop")


func test_freestyle_mastery_searches_named_support_cards() -> void:
	var shipped: CardLibrary = CardLibrary.new()
	shipped.load_dir("res://data/cards")
	for target_id in ["signature_drill_05", "signature_noncombat_07"]:
		var cards: Array[String] = []
		for i in range(30):
			cards.append("freestyle_strike_04")
		var decks: Array[DeckList] = [deck(cards, "vigil", "freestyle", "freestyle_mastery_01", 3, "Sir Edric Rooke"), deck(cards, "pact", "", "", 3, "Caedan Vale")]
		var e: DuelEngine = DuelEngine.new()
		e.shuffle_decks = false
		e.setup(decks, shipped, StrikeTable.load_from("res://data/strike_table.json"), 5)
		vigil_opens(e, decks[0], decks[1])
		e.start()
		# Pay with a named support card, then search for the other support type.
		var payment: CardInstance = e._instance(shipped.get_def("signature_noncombat_07" if target_id == "signature_drill_05" else "signature_drill_05"), 0, &"hand")
		e.player(0).hand.append(payment)
		var target: CardInstance = e._instance(shipped.get_def(target_id), 0, &"life_deck")
		e.player(0).life_deck.append(target)
		var foreign: CardInstance = e._instance(shipped.get_def("signature_noncombat_03"), 0, &"life_deck")
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
			var rng: RandomNumberGenerator = RandomNumberGenerator.new()
			rng.seed = 7
			var guard: int = 0
			while not e.is_over() and guard < 4000:
				guard += 1
				var opt: Command = e.prompt.options[rng.randi_range(0, e.prompt.options.size() - 1)]
				e.submit(opt)
			check(e.is_over(), "%s random self-play finished (winner %d by %s)" % [entry, e.state.winner, e.state.win_reason])
		entry = dir.get_next()
	dir.list_dir_end()
	check(found >= 2, "at least two shipped decks")


func test_setup_and_first_turn() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
	eq(e.state.active, 0, "the helper seats the Vigil deck first")
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
	eq(int(e.prompt.context.get("card", -1)), top.uid, "the recover prompt names the discard card it would return")
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
	e.player(0).duelist.go_to_aspect(2)
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
		for key in ["step", "phase", "active", "attacker"]:
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
	# A card brought in earlier in the batch may be the random one a later swap sends back out, so
	# the first is read off the swap events and only the last is sure to still be in the deck.
	var brought: Array[int] = []
	for ev in e.events:
		if ev.type == &"reserve_swap":
			brought.append(int(ev.data.get("in", -1)))
	check(brought.has(a), "first card entered the deck")
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


func test_double_power_rule_decides_first_player() -> void:
	var giant: DeckList = deck(filler(), "vigil", "", "", 3, "tf_giant")
	var e: DuelEngine = engine(giant, deck(filler(), "vigil", "", "", 3, "tf_pageboy"))
	eq(e.state.active, 1, "the weaker duelist opens the duel")
	eq(e.player(0).duelist.energy, 2, "the duelist with double the Might starts at Energy 2")
	eq(e.player(1).duelist.energy, CardInstance.MAX_STAGE, "the weaker starts at full Energy")
	check(has_event(e, &"double_power"), "Double Power event emitted")
	eq(str(setup_event(e).get("reason", "")), "double_power", "the setup event says why")
	# Under double: chance decides and nobody's Energy moves. Built by hand, since the helper seats
	# a Vigil deck first.
	var even: DuelEngine = DuelEngine.new()
	even.shuffle_decks = false
	var pair: Array[DeckList] = [deck(filler(), "vigil"), deck(filler(), "pact")]
	even.setup(pair, lib, table, 1)
	even.start()
	eq(str(setup_event(even).get("reason", "")), "chance", "chance decides when the Double Power Rule does not apply")
	eq(int(setup_event(even).get("first", -1)), even.state.active, "and the setup event names the seat it picked")
	eq(even.player(1 - even.state.active).duelist.energy, 5, "the second player keeps the usual starting stage")
	check(not has_event(even, &"double_power"), "no Double Power event")


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
	r2.engine.set_first_player(0)   # the seat holding the heavy Strike attacks first
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
	var declared: Dictionary = {}
	var unlisted: bool = false
	for l in lines:
		match str(l.get("type", "")):
			"attack_declared":
				declared = l.get("data", {})
			"damage_stages":
				stages = l.get("data", {})
			"attack_successful", "modified_damage":
				pass
			_:
				if not Referee.ANIMATED.has(StringName(str(l.get("type", "")))):
					unlisted = unlisted or l.has("data")
	check(stages.has("target") and stages.has("stages"), "damage lines carry the target and amount for the other seat: %s" % str(stages))
	# The attack card is public once declared, but the same update can send it to a hidden zone
	# before the other seat replays the declaration, so the line names it as well as its uid.
	eq(str(declared.get("id", "")), "t_strike_plus2", "the declared attack carries its card id for the other seat")
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
	check(mod_line.contains("Test Pyre Drill") and mod_line.ends_with("Total 4 Energy."), "modifier log line lists sources and total: %s" % mod_line)
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


## Inside a duel a table Strike's badge reads the Strike Table number for the matchup it is shown
## in, its printed modifier added; an unknown or wild matchup keeps the "Table" wording.
func test_attack_badge_table_base() -> void:
	var e: DuelEngine = engine(deck(filler(["t_strike", "t_strike_plus2"])), deck(filler(), "pact"))
	var v: SeatView = SeatView.of(e, 0)
	var mine: int = e.player(0).in_control().might()
	var theirs: int = e.player(1).in_control().might()
	eq(v.strike_mights(0, lib), Vector2i(mine, theirs), "seat 0 strikes at its own Might into the rival's")
	eq(v.strike_mights(1, lib), Vector2i(theirs, mine), "the rival's Strikes read the other way round")
	var base: int = CardText.strike_table_base(lib.get_def("t_strike"), table, mine, theirs)
	eq(base, table.base_damage(mine, theirs), "a bare Strike's base is the table result")
	eq(CardText.strike_table_base(lib.get_def("t_art"), table, mine, theirs), -1, "an Art has no table base")
	eq(CardText.strike_table_base(lib.get_def("t_strike"), table, -1, -1), -1, "an unknown matchup has no table base")
	eq(str(CardText.attack_badge(lib.get_def("t_strike"), 3)["num"]), "3", "a bare Strike shows the table number")
	var plus: Dictionary = CardText.attack_badge(lib.get_def("t_strike_plus2"), 3)
	eq(str(plus["num"]) + " " + str(plus["word"]), "5 Energy", "a +2 Strike shows table plus 2")
	eq(str(CardText.attack_badge(lib.get_def("t_strike"), -1)["num"]), "Table", "no table base keeps the Table wording")
	eq(str(CardText.attack_badge(lib.get_def("t_art"), 3)["num"]), "4", "an Art ignores the table base")
	var hidden: SeatView = SeatView.from_dict(v.to_dict())
	hidden.card(hidden.player(1).controlling).def_id = ""
	eq(hidden.strike_mights(0, lib), Vector2i(-1, -1), "an unseen personality in control leaves the matchup unknown")
	var wild_lib: CardLibrary = CardLibrary.new()
	wild_lib.defs = lib.defs.duplicate()
	var rival: SeatCard = v.card(v.player(1).controlling)
	var raw: Dictionary = (lib.get_def(rival.def_id).raw as Dictionary).duplicate(true)
	raw["wild"] = true
	wild_lib.defs[rival.def_id] = CardDef.from_dict(raw)
	eq(v.strike_mights(0, wild_lib), Vector2i(-1, -1), "a wild personality in control never reads the table")


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
	# Which value a pivot leaves in place, read without the shipped calibration on top.
	base.data["scale"] = {}
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
	# "Their next attack phase" is the one after the phase it was set in, so the phase running when
	# it was set neither spends it nor is bound by it.
	e._expire_attack_phase_floats(1)
	check(e._forbidden(foe, "strike_cards"), "and the phase it was set in does not spend it")
	e.state.attack_phase_count += 1
	e._expire_attack_phase_floats(1)
	check(not e._forbidden(foe, "strike_cards"), "their own next phase ending lifts it")
	e._float(1, "forbid", "next_attack_phase", {"what": "strike_cards", "source": -1})
	check(e._forbidden(foe, "strike_cards"), "set again, with the phase still to come")
	e._expire_floating("combat")
	check(not e._forbidden(foe, "strike_cards"), "and Combat ending clears one that never fired")


## The AI and the seat view read `restrictions`, so it has to list exactly what the rules enforce,
## a rival's Seal and a phase restriction the current phase is not bound by included.
func test_restrictions_list_what_the_rules_forbid() -> void:
	var e: DuelEngine = real_engine(real_deck([], "vigil"), real_deck([], "pact"))
	check(not e.restrictions(e.player(0)).has("mastery"), "no Seal, no forbid")
	real_inject(e, 1, "seal_28")
	check(e.restrictions(e.player(0)).has("mastery"), "their Seal 7 forbids my Mastery in the list too")
	check(not e.restrictions(e.player(1)).has("mastery"), "and leaves their own alone")
	e._float(1, "forbid", "next_attack_phase", {"what": "strike_cards", "source": -1})
	e.state.attacker = 1
	check(not e.restrictions(e.player(1)).has("strike_cards"), "the phase it was set in is not bound by it")
	for p in e.state.players:
		for what in DuelEngine.FORBID_KINDS:
			eq(e.restrictions(p).has(what), e._forbidden(p, what), "restrictions and the rules agree on %s for player %d" % [what, p.index])


## An attack that "may not be stopped by Strike cards" is not stopped by a stop-all a Strike left
## earlier, so that stop-all must not skip the defender's defense window either.
func test_a_barred_stop_all_does_not_skip_the_defense() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
	var src: CardInstance = inject(e, 1, "t_strike")
	e._float(1, "stop_all", "combat", {"kind": "any", "source": src.uid})
	var a: Dictionary = {"unstoppable": false, "stops_needed": 1, "kind": "strike", "focused": false, "stopped": false, "spec": {}}
	check(e._standing_stop(e.player(1), a), "an open stop-all covers the attack")
	a["spec"] = {"no_stop_by": "strike"}
	check(not e._standing_stop(e.player(1), a), "one a Strike left does not cover an attack Strikes may not stop")


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
	var empty: float = AiScorer._declare_score(e, profile, me)
	check(empty < 1.0, "nothing in hand scores under skipping, which is a flat 1.0 (%.2f)" % empty)
	for i in range(3):
		inject(e, 0, "t_noncombat_draw")
	eq(AiScorer._declare_score(e, profile, me), empty, "while declare_use is off, carrying them counts for nothing")
	profile.merge({"play": {"declare_use": 2.0}})
	var holding: float = AiScorer._declare_score(e, profile, me)
	check(holding > empty, "with declare_use on, Non-Combats used only in Combat are a reason to open one (%.2f over %.2f)" % [holding, empty])
	check(holding > 1.0, "and enough of them outweighs skipping (%.2f)" % holding)
	for c in me.in_play.duplicate():
		if c.def.id == "t_noncombat_draw":
			me.in_play.erase(c)
	eq(AiScorer._declare_score(e, profile, me), empty, "spend them and it goes quiet again")


## Declaring hands the rival three cards and an attack phase, so a positive `declare_bias` is how
## readily to fight, not a reason to open a Combat with nothing to do in it.
func test_declaring_needs_something_to_do() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
	var me: PlayerState = e.player(0)
	var profile: AiProfile = AiProfile.default_profile()
	profile.merge({"play": {"declare_bias": 2.5}})
	me.hand.clear()
	me.duelist.energy = 0
	for id in ["t_parry", "t_ward", "t_guard"]:
		me.hand.append(e._instance(lib.get_def(id), 0, &"hand"))
	var blocks: float = AiScorer._declare_score(e, profile, me)
	check(blocks < 1.0, "a hand of blocks and a power it cannot pay for scores under skipping (%.2f)" % blocks)
	var entry: CardDef = CardDef.from_dict({"id": "d", "title": "D", "type": "drill",
		"effects": [{"trigger": "entering_combat", "op": "draw", "amount": 3}]})
	var drill: CardInstance = e._instance(entry, 0, &"in_play")
	me.in_play.append(drill)
	eq(AiScorer._declare_score(e, profile, me), blocks, "cards drawn on entering Combat are no reason to open one")
	me.in_play.erase(drill)
	me.hand.append(e._instance(lib.get_def("t_art"), 0, &"hand"))
	eq(AiScorer._declare_score(e, profile, me), blocks, "an Art it cannot pay for is still no reason")
	me.duelist.energy = 5
	var armed: float = AiScorer._declare_score(e, profile, me)
	check(armed > 1.0, "once the Art and the power can be paid, the bias applies and it declares (%.2f)" % armed)


## A final strike is a last resort. The search does not weigh one the scorer rates below passing,
## so a playout that likes the damage cannot pick it over a hand still worth holding.
func test_the_search_leaves_a_final_strike_to_the_scorer() -> void:
	var e: DuelEngine = engine(deck(filler(["t_parry", "t_ward", "t_guard"])), deck(filler(), "pact"))
	to_combat(e)
	var prompt: Prompt = e.prompt_of(0)
	var profile: AiProfile = AiProfile.default_profile()
	var prior: Array[float] = AiScorer.scores(e, profile, 0)
	var offered: bool = false
	for o in prompt.options:
		offered = offered or o.type == &"final_strike"
	check(offered, "the engine offers a final strike")
	for i in AiSearch._candidates(e, prompt, prior, prompt.options.size()):
		check(prompt.options[i].type != &"final_strike" or prior[i] > 0.0, "a final strike the scorer rates at %.2f is not searched" % prior[i])
	for i in AiSearch._shortlist(prompt, prior, prompt.options.size(), e):
		check(prompt.options[i].type != &"final_strike" or prior[i] > 0.0, "nor modelled as the rival's reply (%.2f)" % prior[i])


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
	e.player(1).duelist.go_to_aspect(2)
	to_combat(e)
	answer(e, &"use", uid_in_hand(e, 0, "t_jeer"))
	eq(e.player(1).fervor, 2, "fervor shielded")
	check(has_event(e, &"fervor_shielded"), "fervor_shielded event")
	answer(e, &"pass")
	answer(e, &"use", uid_in_hand(e, 0, "t_set_aspect"))
	eq(e.player(1).duelist.aspect, 2, "aspect shielded")


func test_set_aspect() -> void:
	var e: DuelEngine = engine(deck(filler(["t_set_aspect", "t_strike", "t_strike"])), deck(filler(), "pact"))
	e.player(1).duelist.go_to_aspect(3)
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
	var text: String = CardText.rules_text(shipped.defs.get("steel_mastery_01"))
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
	var text: String = CardText.rules_text(shipped.defs.get("pyre_mastery_01"))
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
func test_card_text_condenses_repeated_branches() -> void:
	var any_stop: CardDef = CardDef.from_dict({"id": "s", "title": "S", "type": "combat", "defense": {"stops": "any"}})
	eq(CardText.rules_text(any_stop), "Stops any attack.", "a stop of either kind reads as any attack")
	var shipped: CardLibrary = shipped_library()
	var steel: String = CardText.rules_text(shipped.defs["steel_mastery_03"])
	check(not steel.contains("If you do not"), "a decline that matches the miss folds into Otherwise: %s" % steel)
	check(steel.contains("Otherwise, prevent 4 Energy"), "the miss still reads in full: %s" % steel)
	var pyre: String = CardText.rules_text(shipped.defs["pyre_mastery_03"])
	check(pyre.contains("Otherwise, +1 Energy."), "a branch that repeats the other one's opening states only the difference: %s" % pyre)
	var shade: String = CardText.rules_text(shipped.defs["shade_mastery_02"])
	check(shade.contains("your opponent discards a card from hand, at random if the top card of your discard pile is Shade."),
		"a discard split on a school check reads as one line: %s" % shade)
	var volley: String = CardText.rules_text(shipped.defs["freestyle_art_05"])
	check(volley.contains("This card stays on the table to be used 1 more time by a Draik Ally."),
		"an Ally-only Remain keeps the printed sentence: %s" % volley)


func test_rules_layout_splits_text_into_blocks_and_chips() -> void:
	var layout: Dictionary = RulesLayout.build("Draconic duelists only.\nWhen entering Combat, draw a card. If you do, gain 2 Energy. Otherwise, Attune 1.\nEndurance 2. Attune 1. Disrupt 2. Limit 1 per deck. Remove from the game after use.")
	eq(Array(layout["gate"]), ["Draconic duelists only."], "a who-may-use sentence goes to the gate")
	var paras: Array = layout["paras"]
	eq(paras.size(), 5, "a lead-in block, two indented branches and a line per rider: %s" % str(paras))
	eq(str(paras[0]["lead"]), "When entering Combat,", "the trigger is the lead-in")
	check(bool(paras[1]["indent"]) and bool(paras[2]["indent"]), "If you do / Otherwise are indented")
	eq(str(paras[3]["text"]), "Attune 1.", "a Fervor rider stays in the text on its own line")
	var words: Array = []
	for t in layout["tags"]:
		words.append(str(t["word"]))
	eq(words, ["REMOVED AFTER USE", "ENDURANCE 2", "LIMIT 1"], "coloured chips lead, bookkeeping follows")
	var raise: Dictionary = {"op": "fervor", "amount": 1}
	eq(CardText.effect_text(raise), "Attune 1.", "raising your own Fervor is Attune")
	var lower: Dictionary = {"op": "fervor", "who": "opponent", "amount": -2}
	eq(CardText.effect_text(lower), "Disrupt 2.", "lowering the rival's Fervor is Disrupt")
	eq(CardText.may_action(raise), "Attune 1", "a prompt button uses the keyword")
	eq(CardText.may_action(lower), "Disrupt 2", "and so does the rival side")
	eq(CardText.fervor_word({"player": 0, "from": 1, "to": 3, "source_owner": 0}), "Attune 2", "a gain reads as Attune")
	eq(CardText.fervor_word({"player": 0, "from": 3, "to": 1, "source_owner": 1}), "Disrupt 2", "a loss the rival caused reads as Disrupt")
	eq(CardText.fervor_word({"player": 0, "from": 3, "to": 1, "source_owner": 0}), "", "a loss of your own doing keeps the bare number")
	var e: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
	var gain: GameEvent = GameEvent.new(&"fervor_changed", {"player": 0, "from": 1, "to": 2, "source": -1, "source_owner": 0})
	eq(CardText.event_line(gain, e), "%s Attunes 1 (Fervor 1 → 2)." % e.player(0).name, "the log names a gain as Attune")
	var loss: GameEvent = GameEvent.new(&"fervor_changed", {"player": 0, "from": 3, "to": 1, "source": -1, "source_owner": 1})
	eq(CardText.event_line(loss, e), "%s is Disrupted 2 (Fervor 3 → 1)." % e.player(0).name, "and a loss the rival caused as Disrupt")


func test_card_text_wording() -> void:
	var plain_gain: Dictionary = {"op": "energy", "amount": 3}
	eq(CardText.effect_text(plain_gain), "Gain 3 Energy.", "an unconditional line reads bare")
	var hit: Dictionary = {"trigger": "if_successful", "op": "fervor", "amount": 1}
	eq(CardText.effect_text(hit), "Hit: Attune 1.", "Hit label")
	var hit_ally: Dictionary = {"trigger": "if_successful", "op": "fervor", "amount": 1, "when": {"allies_min": 1}}
	eq(CardText.effect_text(hit_ally), "Hit: If you have an Ally in play, Attune 1.", "other conditions stay as sentences")
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
	eq(CardText.effects_text(pair), PackedStringArray(["When entering Combat, Disrupt 2 and gain 2 Energy."]), "same trigger folds into one sentence")
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
	var f: CardDef = CardDef.from_dict({"id": "x", "title": "X", "type": "personality",
		"aspect": 1, "surge": 1, "might": [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
		"power": {"attack": {"kind": "strike", "stages": 3}, "effects": [{"op": "energy", "amount": 5}, {"trigger": "if_stopped", "op": "draw", "amount": 1}], "uses": 2},
		"constant": {"first_styled_unstoppable": true, "forbid_opponent": ["art_attacks"]}, "shield": "strike"})
	var lines: PackedStringArray = CardText.aspect_text(f, 1)
	eq(lines.size(), 3, "power, constant, and shield lines")
	eq(lines[0], "Power: Strike doing +3 Energy. Gain 5 Energy. If stopped, draw a card. May be used twice per Combat.", "every part of the Power")
	eq(lines[1], "Constant: Your first attack each Combat with a school card cannot be stopped. Your opponent may not perform Arts.", "constants render")
	eq(lines[2], "Defense Shield: stops the first unstopped Strike each Combat.", "shield renders")
	# An Ally who answers from the side has no other way to tell the player she may be used.
	var aside: CardDef = CardDef.from_dict({"id": "y", "title": "Y", "type": "personality",
		"aspect": 1, "surge": 1, "might": [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
		"power": {"defense": {"stops": "strike"}, "no_control_needed": true}})
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
		var phrase_only: Array[String] = ["Stops", "from the game", "Remain", "Hit", "aspect", "cannot be prevented", "Cannot be stopped", "Signature", "Limit", "Constant", "Attune", "Disrupt"]
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
	e.player(1).duelist.go_to_aspect(2)
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
		e.player(0).duelist.go_to_aspect(3)
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
		e.player(0).duelist.go_to_aspect(3)
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
	d.player(0).duelist.go_to_aspect(3)
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
		e.player(0).duelist.go_to_aspect(2)
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


## Ally legality does not read the deck's height (2026-09-21, following the later rulings
## revision). Any Aspect 1 to 3 personality card is legal in any deck; Aspect 4 and up never are.
func test_ally_legality_does_not_read_the_decks_aspect_count() -> void:
	for id in ["t_ally_squire", "t_ally_squire_2", "t_ally_squire_3"]:
		for count in [1, 2, 3, 4, 5]:
			var d: DeckList = deck(filler([id]), "vigil", "", "", count,
				"tf_vigil" if count <= 3 else "tf_titan")
			d.mode = "adventure"
			for p in DeckValidator.validate(d, lib):
				check(not p.contains(id), "%s is Ally-legal at %d aspects: %s" % [id, count, p])
	# Aspect 4 is past the Ally ceiling at every height, including the tallest Duelist.
	for count in [3, 5]:
		var named: bool = false
		for p in DeckValidator.validate(deck(filler(["t_ally_squire_4"]), "vigil", "", "", count, "tf_titan"), lib):
			if p.contains("t_ally_squire_4"):
				named = true
		check(named, "an Aspect 4 Ally is refused at %d aspects" % count)


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
	e.player(0).duelist.go_to_aspect(3)
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
	f.player(0).duelist.go_to_aspect(3)
	f.player(0).fervor = 4
	answer(f, &"use", uid_in_hand(f, 0, "t_taunt"))
	eq(f.player(0).duelist.aspect, 4, "it still climbs")
	check(not f.is_over(), "but climbing is not the win when the rival can match the Aspect")

	# The relic that gives up the Ascension win gives up this route with it.
	var g: DuelEngine = engine(deck(filler(["t_taunt"]), "vigil", "", "", 5, "tf_titan"), deck(filler(), "pact"))
	to_combat(g)
	g.player(0).no_ascension_win = true
	g.player(0).duelist.go_to_aspect(3)
	g.player(0).fervor = 4
	answer(g, &"use", uid_in_hand(g, 0, "t_taunt"))
	eq(g.player(0).duelist.aspect, 4, "the climb still happens")
	check(not g.is_over(), "but a duelist who cannot win by Ascension cannot win this way either")

	# And the card that answers an Ascension win answers this one: it drops the Aspect back under.
	var h: DuelEngine = engine(deck(filler(["t_taunt"]), "vigil", "", "", 5, "tf_titan"), deck(filler(), "pact"))
	inject(h, 1, "t_reckoning")
	to_combat(h)
	h.player(0).duelist.go_to_aspect(3)
	h.player(0).fervor = 4
	answer(h, &"use", uid_in_hand(h, 0, "t_taunt"))
	eq(prompt_kind(h), &"respond", "the rival is asked before the win stands")
	answer(h, &"use", h.player(1).non_combats()[0].uid)
	eq(h.player(0).duelist.aspect, 3, "the answer knocked them back down a rung")
	check(not h.is_over(), "so the win does not stand")


## Adventure house rule: first to `points_to_win`. Running out of Life Deck costs a point and the
## discard pile becomes the new deck; removed cards stay out and the table is untouched.
func test_first_to_two_a_deck_out_scores_a_point_and_reshuffles() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(["t_strike", "t_strike"], "pact"))
	e.state.points_to_win = [2, 2]
	for i in range(4):
		to_discard(e, 1, "t_strike")
	var gone: CardInstance = e._instance(lib.get_def("t_strike"), 1, &"removed")
	e.player(1).removed.append(gone)
	var drill: CardInstance = inject(e, 1, "t_drill_strike")
	to_combat(e)
	check(not e.is_over(), "the first deck-out does not end a first-to-two duel")
	eq(e.state.points[0], 1, "it scores the rival a point")
	eq(e.player(1).hand.size(), 3, "and the draw that ran dry still finishes")
	eq(e.player(1).life_deck.size(), 3, "out of a new deck made of the four discards")
	check(e.player(1).discard.is_empty(), "which left the discard pile empty")
	check(e.player(1).removed.has(gone), "a removed card stays removed")
	check(e.player(1).in_play.has(drill), "and the table is untouched")
	# The second time is the duel.
	e.player(1).life_deck.clear()
	e._draw(1, 1)
	check(e.is_over(), "the second deck-out ends it")
	eq(e.state.winner, 0, "for the duelist who emptied them twice")
	eq(e.state.win_reason, "survival", "by survival")

	# A duelist with nothing to shuffle back has nothing left to fight with.
	var f: DuelEngine = engine(deck(filler()), deck(["t_strike", "t_strike"], "pact"))
	f.state.points_to_win = [2, 2]
	to_combat(f)
	check(f.is_over(), "an empty discard pile makes the first deck-out final")
	eq(f.state.winner, 0, "and the rival wins")


func test_first_to_two_the_hit_that_scores_loses_its_leftover_damage() -> void:
	var e: DuelEngine = engine(deck(filler(["t_art", "t_art", "t_art"])), deck(filler(), "pact"))
	e.state.points_to_win = [2, 2]
	to_combat(e)
	while e.player(1).life_deck.size() > 2:
		e.player(1).removed.append(e.player(1).life_deck.pop_back())
	for i in range(3):
		to_discard(e, 1, "t_strike")
	answer(e, &"attack", uid_in_hand(e, 0, "t_art"))
	check(not e.is_over(), "the duel goes on")
	eq(e.state.points[0], 1, "four wounds into a two-card deck score a point")
	eq(e.player(1).life_deck.size(), 5, "the new deck is the three old discards and the two wounds")
	check(e.player(1).discard.is_empty(), "and the rest of the hit never reaches it")


func test_first_to_two_an_ascension_scores_once_and_resets_nothing() -> void:
	var e: DuelEngine = engine(deck(filler(["t_taunt", "t_taunt"]), "vigil", "", "", 5, "tf_titan"), deck(filler(), "pact"))
	e.state.points_to_win = [2, 2]
	to_combat(e)
	e.player(0).duelist.go_to_aspect(3)
	e.player(0).fervor = 4
	answer(e, &"use", uid_in_hand(e, 0, "t_taunt"))
	eq(e.player(0).duelist.aspect, 4, "the climb lands above the rival's ladder")
	check(not e.is_over(), "which is a point and not the duel")
	eq(e.state.points[0], 1, "one point")
	# Standing there is still true on every later check, and it must not score again.
	e.player(0).fervor = 5
	e._check_aspect_up(e.player(0))
	eq(e.player(0).duelist.aspect, 5, "the next meter is an ordinary climb")
	eq(e.state.points[0], 1, "and not a second point")
	check(not e.is_over(), "so the duel is still on")
	# The second point has to come from their Life Deck.
	e.player(1).life_deck.clear()
	e.player(1).discard.clear()
	e._draw(1, 1)
	check(e.is_over(), "Ascension plus an emptied deck is the full win")
	eq(e.state.winner, 0, "for the climber")


## Steel Standoff (printed: "the user may hold all his extra cards until his next turn"): the user
## keeps their hand through the Discard step, the opponent discards as usual. It used to carry an
## end_turn op that skipped the Discard step for both players.
## The guard for the Watchful Eye loop: the engine names a card listed twice or sitting where its
## zone does not say, and the Referee records the first such fault after the command that caused it.
func test_the_integrity_check_catches_a_card_in_two_places() -> void:
	var r: Referee = Referee.new()
	var decks: Array[DeckList] = [deck(filler()), deck(filler(), "pact")]
	r.setup(decks, lib, table, 1, [], false)
	r.start()
	eq(r.engine.integrity_problem(), "", "a fresh duel is sound")
	# Plant the bug: one card in the Life Deck twice.
	var twin: CardInstance = r.engine.player(0).life_deck[0]
	r.engine.player(0).life_deck.append(twin)
	check(r.engine.integrity_problem().contains("listed twice"), "the engine names the duplicate: %s" % r.engine.integrity_problem())
	var p: Prompt = r.engine.prompt
	r.submit(p.player, p.options[0].to_dict())
	check(r.integrity_fault.contains("listed twice"), "the Referee records it after the next command: %s" % r.integrity_fault)
	r.engine.player(0).life_deck.pop_back()
	# A card whose own zone disagrees with where it sits.
	var e: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
	var stray: CardInstance = e.player(0).life_deck[0]
	stray.zone = &"discard"
	check(e.integrity_problem().contains("zone says discard"), "a stale zone is named too: %s" % e.integrity_problem())


## "Shuffle the top and bottom cards of your discard pile into your Life Deck" with two cards in
## the pile took the same card twice, which then lived in the Life Deck twice and could be used
## forever from the hand (the long-game stall first blamed on Mourne's Smirk).
func test_recovering_top_and_bottom_never_takes_one_card_twice() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
	var a: CardInstance = to_discard(e, 0, "t_strike")
	var b: CardInstance = to_discard(e, 0, "t_art")
	var before: int = e.player(0).life_deck.size()
	e.dev_effect(0, {"op": "shuffle_discard", "amount": 2, "from": "top_and_bottom"})
	eq(e.player(0).life_deck.size(), before + 2, "two cards went back")
	check(e.player(0).life_deck.has(a) and e.player(0).life_deck.has(b), "both of them, not one twice")
	eq(e.player(0).life_deck.count(a), 1, "the first once")
	eq(e.player(0).life_deck.count(b), 1, "the second once")
	check(e.player(0).discard.is_empty(), "and the pile is empty")


## Mourne's Smirk loop: a Non-Combat whose search found or took nothing stayed in play, so it could
## be used again and again. Using it spends it whatever the search took.
func test_a_non_combat_search_that_takes_nothing_is_still_spent() -> void:
	# With a Seal in the deck, the player looks and takes nothing.
	var e: DuelEngine = engine(deck(filler(["t_seal_1"])), deck(filler(), "pact"))
	var fetch: CardInstance = inject(e, 0, "t_seal_fetch")
	to_combat(e)
	answer(e, &"use", fetch.uid)
	eq(prompt_kind(e), &"pick_option", "the search asks")
	answer(e, &"pick_none")
	check(fetch.zone != &"in_play", "the card left play after taking nothing (zone %s)" % fetch.zone)
	# With no Seal in the deck at all.
	var f: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
	var dry: CardInstance = inject(f, 0, "t_seal_fetch")
	to_combat(f)
	answer(f, &"use", dry.uid)
	if prompt_kind(f) == &"pick_option" and f.prompt.find(&"pick_none") != null:
		answer(f, &"pick_none")
	check(dry.zone != &"in_play", "a search with nothing to find still spends the card (zone %s)" % dry.zone)


func test_a_standoff_keeps_only_the_users_hand() -> void:
	var e: DuelEngine = engine(deck(filler(["t_standoff", "t_strike", "t_strike"])), deck(filler(), "pact"))
	to_combat(e)
	answer(e, &"use", uid_in_hand(e, 0, "t_standoff"))
	check(has_event(e, &"combat_end"), "the standoff ended Combat")
	eq(e.state.step, GameState.Step.DISCARD, "and the turn went on to its Discard step")
	eq(e.prompts.size(), 1, "only one player is asked to discard")
	eq(e.prompt.player, 1, "the opponent")
	eq(e.player(0).hand.size(), 2, "the user kept both remaining cards")
	var held: int = e.player(1).hand.size()
	check(e.submit(Command.new(1, &"discard_all")), "the opponent discards as usual")
	eq(e.player(1).discard.size(), held, "their whole hand went to the discard pile")
	skip_to_turn(e, 2)
	eq(e.player(0).hand.size(), 2, "the user's hand was still whole when their turn ended")
	# The keep lasted one Discard step; on the user's own turn the rule is back to normal.
	check(not e._has_floating(0, "keep_hand"), "and the float is gone by the next turn")


## Card data says "attacker" / "defender" at the entering-Combat window; the engine keys the window
## "active" / "opposing". Emrys Rooke's tier 1 power was written "attacker" and never fired.
func test_entering_combat_roles_read_attacker_and_defender() -> void:
	check(DuelEngine.role_matches("attacker", "active"), "attacker is the active player")
	check(not DuelEngine.role_matches("attacker", "opposing"), "and not the other one")
	check(DuelEngine.role_matches("defender", "opposing"), "defender is the opposing player")
	check(not DuelEngine.role_matches("defender", "active"), "and not the active one")
	check(DuelEngine.role_matches("active", "active") and DuelEngine.role_matches("opposing", "opposing"), "the window's own names still match")
	check(DuelEngine.role_matches("", "active") and DuelEngine.role_matches("", "opposing"), "no role means either side")
	eq(CardText.role_name("active"), "attacker", "worded as the attacker")
	eq(CardText.role_name("opposing"), "defender", "worded as the defender")
	eq(CardText.role_name("defender"), "defender", "printed words pass through")


## Adventure lives (2026-09-22): the player has two, an ordinary opponent one. `set_lives` is
## seat-ordered, so seat 1 needs two points against a two-life seat 0 and seat 0 needs one.
func test_lives_are_per_seat_so_the_player_falls_twice_and_the_opponent_once() -> void:
	var e: DuelEngine = DuelEngine.new()
	e.shuffle_decks = false
	var decks: Array[DeckList] = [deck(filler()), deck(filler(), "pact")]
	e.setup(decks, lib, table, 1)
	e.set_lives([2, 1])
	e.start()
	eq(e.state.points_to_win[0], 1, "one point beats a one-life opponent")
	eq(e.state.points_to_win[1], 2, "two beat a two-life player")
	to_combat(e)
	to_discard(e, 0, "t_strike")
	to_discard(e, 1, "t_strike")
	e._win(1, "survival")
	check(not e.is_over(), "the player's first fall is a point")
	eq(e.state.points[1], 1, "one point to the rival")
	e._win(0, "survival")
	check(e.is_over(), "the opponent's first fall is the duel")
	eq(e.state.winner, 0, "for the player")
	# A boss has two lives as well, so the rule is symmetric again.
	var f: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
	f.state.points_to_win = [2, 2]
	to_combat(f)
	to_discard(f, 1, "t_strike")
	f._win(0, "survival")
	check(not f.is_over(), "a boss survives the first fall")
	f._win(0, "survival")
	check(f.is_over(), "and not the second")


## The lives numbers moved out of Session so a headless SceneTree runner can read them.
func test_adventure_rules_give_the_boss_two_lives_and_everyone_else_one() -> void:
	var plain: Array[int] = AdventureRules.lives_for({"opponent": "steel_beatdown_t3", "tier": "t3"})
	eq(plain[0], AdventureRules.PLAYER_LIVES, "the player has two lives on an ordinary stage")
	eq(plain[1], AdventureRules.OPPONENT_LIVES, "and an ordinary opponent has one")
	var boss: Array[int] = AdventureRules.lives_for({"opponent": "steel_beatdown_boss", "tier": "boss"})
	eq(boss[0], AdventureRules.PLAYER_LIVES, "the player still has two against the boss")
	eq(boss[1], AdventureRules.BOSS_LIVES, "and the boss has two as well")
	# A row that names no tier is an ordinary stage, not a boss.
	eq(AdventureRules.lives_for({})[1], AdventureRules.OPPONENT_LIVES, "an unnamed tier is ordinary")


## SimMatch.lives is seat-ordered and overrides the symmetric points_to_win, which is what lets
## tests/adventure_lab.gd play a ladder stage the way the client does.
func test_a_sim_match_with_lives_gives_each_seat_its_own_points_to_win() -> void:
	var runner: SimMatch = SimMatch.make(lib, table, 4000)
	runner.lives = [2, 1]
	var side: SimSeat = SimSeat.from_legacy("random", {})
	eq(side.error, "", "the random side builds")
	var result: Dictionary = runner.play(deck(filler()), deck(filler(), "pact"), 0, side, side,
		[7, 8, 9, 10])
	check(bool(result["ok"]), "the staged duel finished: %s" % str(result["error"]))
	var points: Array = result["points"]
	var winner: int = int(result["winner_seat"])
	# Seat 0 has two lives, so seat 1 needs two points to take it; seat 0 needs one.
	eq(int(points[winner]), 2 if winner == 1 else 1, "the winner scored exactly what its rival's lives cost")
	check(int(points[1 - winner]) < (2 if winner == 0 else 1), "and the loser fell short")


func test_first_to_two_a_seal_set_scores_one_point_under_the_adventure_rules() -> void:
	# The printed game, and first-to-two without the option: the set is the duel.
	var e: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
	e.state.points_to_win = [2, 2]
	e._win(0, "seal")
	check(e.is_over(), "a full Seal set ends a first-to-two duel on the spot")
	eq(e.state.win_reason, "seal", "as a Seal win")
	# The adventure rule set: the set is one point, once, and a second set scores nothing more.
	var f: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
	f.state.points_to_win = [2, 2]
	f.state.seal_scores_point = true
	f._win(0, "seal")
	check(not f.is_over(), "with the option the set is a point and the duel goes on")
	eq(f.state.points[0], 1, "one point")
	f._win(0, "seal")
	check(not f.is_over(), "the same set cannot score twice")
	eq(f.state.points[0], 1, "still one point")
	f._win(0, "survival")
	check(f.is_over(), "the set plus an emptied deck is the full win")


## "If used by X, place this card at the bottom of your Life Deck after use": the source card's
## rider on Edric's own stop. Anyone else discards it.
func test_edric_gives_ground_goes_under_the_deck_only_for_edric() -> void:
	var shipped: CardLibrary = shipped_library()
	var e: DuelEngine = shipped_engine("pyre_ascent", "steel_beatdown", 11)
	for seat in range(2):
		var p: PlayerState = e.player(seat)
		var c: CardInstance = e._instance(shipped.get_def("signature_strike_23"), seat, &"hand")
		p.hand.append(c)
		e._finish_card(c, false)
		if p.duelist.def.character == "Sir Edric Rooke":
			check(p.life_deck.back() == c, "Edric's copy goes to the bottom of his Life Deck")
		else:
			check(p.discard.has(c), "anyone else's copy is discarded")
	var text: String = CardText.rules_text(shipped.get_def("signature_strike_23"))
	check(text.contains("Raise your or your opponent's Fervor 1") or text.contains("your opponent's Fervor"), "the Fervor line offers either side: %s" % text)
	check(text.contains("bottom of your Life Deck"), "and the text carries the rider: %s" % text)


## Answers the other seat's prompts with the least eventful option while an attack is in the air.
func _quiet_defender(e: DuelEngine, seat: int) -> void:
	var guard: int = 0
	while e.prompt != null and e.prompt.player != seat and not e.state.attack.is_empty() and guard < 8:
		guard += 1
		var quiet: Command = null
		for t in [&"no_defense", &"no_endure", &"decline", &"control", &"target"]:
			if quiet == null:
				quiet = e.prompt.find(t)
		if quiet == null:
			return
		e.submit(quiet)


## "Use when performing an attack. That attack does +2 wounds for each Draconic personality you
## have in play. Draw a card." The source card rides along with an attack; it is not an action of
## its own, so it is never offered as one and it does not spend an attack phase.
func test_closing_ranks_rides_along_with_the_attack() -> void:
	var shipped: CardLibrary = shipped_library()
	# The starters carry no Reserve, so the duel opens on the first turn and not on a swap.
	var e: DuelEngine = DuelEngine.new()
	var pair: Array[DeckList] = [
		DeckList.load_from("res://data/adventure/starters/steel_beatdown_start.json"),
		DeckList.load_from("res://data/adventure/starters/pyre_beatdown_start.json")]
	e.setup(pair, shipped, StrikeTable.load_from("res://data/strike_table.json"), 5)
	e.start()
	var seat: int = 0 if e.player(0).duelist.def.character == "Halden Quarr" else 1
	var p: PlayerState = e.player(seat)
	var ranks: CardInstance = e._instance(shipped.get_def("freestyle_combat_11"), seat, &"hand")
	p.hand.append(ranks)
	var bolt: CardInstance = e._instance(shipped.get_def("freestyle_art_02"), seat, &"hand")
	p.hand.append(bolt)
	to_attack(e, seat)
	eq(prompt_kind(e), &"attack_action", "Quarr has an attack phase")
	check(e.prompt.find(&"use", ranks.uid) == null, "the card is not an action of its own")
	p.duelist.energy = 10
	var foe_life: int = e.player(1 - seat).life_deck.size()
	var hand_before: int = p.hand.size()
	answer(e, &"attack", bolt.uid)
	# Nothing can stop this Art. The window opens once it has connected, so first step through
	# whatever the defender is asked on the way there, and again after it while wounds are dealt.
	_quiet_defender(e, seat)
	eq(prompt_kind(e), &"follow_up", "a connected attack opens the window before its damage")
	eq(str(e.prompt.context.get("window", "")), "performing_attack", "and names it")
	eq(e.player(1 - seat).life_deck.size(), foe_life, "no wound has been dealt yet")
	answer(e, &"use", ranks.uid)
	_quiet_defender(e, seat)
	# Quarr is Draconic and has no Allies: one Draconic personality, so +2 on the Art's base 4.
	var dealt: int = foe_life - e.player(1 - seat).life_deck.size()
	check(dealt >= 6, "the attack it rode on dealt its 4 wounds plus 2: dealt %d" % dealt)
	check(p.removed.has(ranks), "the card is removed from the game after use")
	eq(p.hand.size(), hand_before - 2 + 1, "two cards left the hand and one was drawn")
	var text: String = CardText.rules_text(shipped.get_def("freestyle_combat_11"))
	check(text.contains("Use when performing an attack.") and text.contains("That attack does +2 wounds for each Draconic personality"), "worded as printed: %s" % text)


## A Focused Art that, once it lands, blanks every Strike in the rival's next attack phase: the
## Energy and the wounds both, since a Strike can carry either.
func test_storm_focused_bolt_blanks_their_next_attack_phase_of_strikes() -> void:
	# Both sides Storm, so the defender can be handed a Storm Strike with printed stages below.
	var e: DuelEngine = real_engine(real_deck([], "pact", "storm"), real_deck([], "vigil", "storm"))
	var bolt: CardInstance = real_to_hand(e, 0, "storm_art_17")
	# A Strike with printed stages on top of the table, so there is real damage to blank: two
	# duelists of the same Might would otherwise trade 0 off the table and prove nothing.
	var blow: CardInstance = real_to_hand(e, 1, "storm_strike_03")
	to_attack(e, 0)
	e.player(0).duelist.energy = 5
	var foe_life: int = e.player(1).life_deck.size()
	answer(e, &"attack", bolt.uid)
	eq(foe_life - e.player(1).life_deck.size(), 5, "the bolt dealt its printed 5 wounds")
	check(has_event(e, &"floating"), "and left a standing effect behind")
	eq(e.prompt.player, 1, "their attack phase")
	var life_before: int = e.player(0).life_deck.size()
	var energy_before: int = e.player(0).duelist.energy
	answer(e, &"attack", blow.uid)
	eq(e.player(0).life_deck.size(), life_before, "no wounds from their Strike")
	eq(e.player(0).duelist.energy, energy_before, "and no Energy lost to it")
	eq(int(e.state.last_attack.get("stages_dealt", -1)), 0, "the +2 Strike dealt nothing")
	var text: String = CardText.rules_text(shipped().get_def("storm_art_17"))
	check(text.contains("Focused Art dealing 5 wounds") and text.contains("Prevent all damage from Strikes during your opponent's next attack phase"), "worded as printed: %s" % text)


## "If their personality in control has more Energy than yours, lower it to match": a leveller
## that only ever pulls the rival down, read after the Art's own cost is paid.
func test_storm_assailing_arc_pulls_their_energy_down_to_yours() -> void:
	var e: DuelEngine = real_engine(real_deck([], "pact", "storm"), real_deck([], "vigil"))
	var first: CardInstance = real_to_hand(e, 0, "storm_art_18")
	var second: CardInstance = real_to_hand(e, 0, "storm_art_18")
	to_attack(e, 0)
	e.player(0).duelist.energy = 5
	e.player(1).duelist.energy = 9
	answer(e, &"attack", first.uid)
	eq(e.player(0).duelist.energy, 3, "the Art cost 2")
	eq(e.player(1).duelist.energy, 3, "their duelist came down to match")
	answer(e, &"pass")
	e.player(1).duelist.energy = 1
	answer(e, &"attack", second.uid)
	eq(e.player(1).duelist.energy, 1, "a duelist already below is never raised")
	var text: String = CardText.rules_text(shipped().get_def("storm_art_18"))
	check(text.contains("Endurance 2.") and text.contains("Focused Art dealing 6 wounds") and text.contains("lower it to match"), "worded as printed: %s" % text)


## "All your attacks gain 'Hit: your duelist gains 2 Energy'" for the rest of Combat: the shot
## itself earns its cost back, and a plain Strike later in the same Combat is paid too.
func test_storm_trick_shot_pays_energy_for_every_later_hit() -> void:
	var e: DuelEngine = real_engine(real_deck([], "pact", "storm"), real_deck([], "vigil"))
	var shot: CardInstance = real_to_hand(e, 0, "storm_art_19")
	to_attack(e, 0)
	e.player(0).duelist.energy = 5
	e.player(1).fervor = 2
	answer(e, &"attack", shot.uid)
	eq(e.player(1).fervor, 0, "their Fervor dropped 2")
	eq(e.player(0).duelist.energy, 5, "the shot paid its 2 and earned them back on landing")
	answer(e, &"pass")
	answer(e, &"attack", uid_in_hand(e, 0, "root_strike_04"))
	eq(e.player(0).duelist.energy, 7, "a later Strike that lands pays 2 more")
	var text: String = CardText.rules_text(shipped().get_def("storm_art_19"))
	check(text.contains("Endurance 3.") and text.contains("your attacks gain \"Hit: your duelist gains 2 Energy.\""), "worded as printed: %s" % text)


## An Art that deals Energy instead of wounds and refunds more than it cost when it lands, and a
## plain Focused Art that raises Fervor on landing.
func test_shade_draining_blast_deals_energy_and_refunds_its_user() -> void:
	var e: DuelEngine = real_engine(real_deck([], "pact", "shade"), real_deck([], "vigil"))
	var blast: CardInstance = real_to_hand(e, 0, "shade_art_07")
	var prep: CardInstance = real_to_hand(e, 0, "shade_art_06")
	to_attack(e, 0)
	e.player(0).duelist.energy = 6
	e.player(1).duelist.energy = 8
	var foe_life: int = e.player(1).life_deck.size()
	answer(e, &"attack", blast.uid)
	eq(e.player(1).duelist.energy, 4, "4 Energy of damage")
	eq(e.player(1).life_deck.size(), foe_life, "and no wounds")
	eq(e.player(0).duelist.energy, 8, "paid 2, got 4 back")
	answer(e, &"pass")
	var fervor_before: int = e.player(0).fervor
	answer(e, &"attack", prep.uid)
	eq(e.player(0).fervor, fervor_before + 1, "the Focused Art raised Fervor on landing")
	var text: String = CardText.rules_text(shipped().get_def("shade_art_06"))
	check(text.contains("Focused Art.") and text.contains("Hit: Attune 1"), "worded as printed: %s" % text)
	var blast_text: String = CardText.rules_text(shipped().get_def("shade_art_07"))
	check(blast_text.contains("Art dealing 4 Energy") and blast_text.contains("Costs 2 Energy"), "worded as printed: %s" % blast_text)


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
	profile.merge({"think": {"search": true, "samples": 3, "budget_ms": 0, "node_budget": 600}})
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
	var plain: float = AiScorer.card_value(e, me, tutor, flat, AiScorer.TUTOR_DEPTH)
	var chained: float = AiScorer.card_value(e, me, tutor, chaining, AiScorer.TUTOR_DEPTH)
	check(chained > plain + 4.0, "two links away, the fusion still pulls the first search: %.1f against %.1f" % [chained, plain])
	# And the far end is worth more than the road to it, so nothing prefers the tutor to the payoff.
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
	check(reserve_swaps("pyre_beatdown", "tide_companions").has("pyre_art_02"), "Pyre brings its Ally answer in against Tide")
	check(not reserve_swaps("pyre_beatdown", "steel_beatdown").has("pyre_art_02"), "and leaves it out against Steel")
	check(reserve_swaps("steel_beatdown", "freestyle_swords").has("signature_combat_07"), "Steel brings its Drill answer in against Freestyle")
	# A plain card comes in when it clears the deck's average by the bar. Locking Jaws sits about a
	# quarter above Steel's average, which is not enough, so the check uses a card far above it.
	var steel: DuelEngine = shipped_engine("steel_beatdown", "pyre_beatdown", 5)
	var steel_profile: AiProfile = AiProfile.for_deck(DeckList.load_from("res://data/decks/steel_beatdown.json"), "")
	var big: CardDef = CardDef.from_dict({"id": "big", "title": "Big", "type": "strike", "school": "steel", "attack": {"kind": "strike", "printed_life": 12}})
	check(AiReserve.score(steel, 0, steel._instance(big, 0, &"reserve"), steel_profile) > 0.0, "a plain card far above the deck's average comes in")
	check(AiReserve.score(steel, 0, steel._instance(shipped().get_def("steel_strike_01"), 0, &"reserve"), steel_profile) < 0.0, "one a quarter above it stays out")
	check(not reserve_swaps("steel_beatdown", "pyre_beatdown").has("freestyle_noncombat_09"), "a card that starts in play from the Reserve stays there")
	eq(reserve_swaps("tide_companions", "shade_henchmen").size(), 0, "the Tide profile brings nothing in")
	check(not reserve_swaps("storm_volley", "pyre_beatdown").has("freestyle_strike_03"), "Storm leaves a toolbox attack where its fetch card can reach it")
	check(reserve_swaps("storm_volley", "tide_companions").has("freestyle_strike_03"), "unless the opponent is what it answers")
	check(not reserve_swaps("freestyle_swords", "pyre_beatdown").has("freestyle_combat_14"), "an Ascension deck does not bring in the card that gives up the Ascension win")


## The scorer reads a card the way the engine resolves it: a check's two branches, an effect the
## chooser may aim at either side, a standing modifier over the attacks it touches, and an Art's
## base wounds.
func test_scorer_reads_effects_the_way_the_engine_resolves_them() -> void:
	var profile: AiProfile = AiProfile.default_profile()
	# "Remove a card from your discard pile. If it is a Pyre card, +2 Fervor; otherwise +1."
	var mastery: Array = shipped().get_def("pyre_mastery_02").effects
	var expected: float = -profile.w("effect", "remove_discard") + 1.5 * profile.w("effect", "fervor")
	check(is_equal_approx(AiScorer.effects_value(mastery, profile, ["use"]), expected), "both branches of the check count as an even call: %.2f" % AiScorer.effects_value(mastery, profile, ["use"]))
	var either: Array = shipped().get_def("freestyle_noncombat_10").effects
	check(AiScorer.effects_value(either, profile, ["use"]) > 0.0, "a Seal either side may lose is aimed at the rival's, not read as self-harm")
	var year: Array = shipped().get_def("freestyle_noncombat_05").effects
	eq(AiScorer.effects_value(year, profile, ["use"]), 6.0 * profile.w("play", "damage_stage"), "+1 to every attack for the game is six attacks' worth")
	check(is_equal_approx(AiScorer.modifier_value({"scope": "own", "stages": 1}, "game", profile), 4.0 * AiScorer.modifier_value({"scope": "own", "stages": 1}, "combat", profile)), "a game-long modifier outweighs one for the Combat")
	var e: DuelEngine = real_engine(real_deck([], "pact"), real_deck([], "vigil"))
	var art: CardInstance = real_to_hand(e, 0, "storm_art_07")
	check(AiScorer.hold_value(art, profile) > 1.5 + 4.0 * profile.w("play", "damage_life"), "a held Art is worth its printed wounds")
	var policing: AiProfile = AiProfile.default_profile()
	policing.merge({"effect": {"fervor_foe": 3.0, "remove_hand": 3.0}})
	eq(AiScorer.effects_value([{"op": "fervor", "who": "opponent", "amount": -1}], policing, []), 3.0, "`fervor_foe` prices the rival's Fervor taken away")
	eq(AiScorer.effects_value([{"op": "remove_hand", "who": "opponent", "amount": 1}], policing, []), 3.0, "`remove_hand` prices a card taken from their hand for good")
	eq(AiScorer.effects_value([{"op": "remove_hand", "who": "opponent", "amount": 1}], profile, []), profile.w("effect", "discard_hand"), "and falls back to a discard's weight")
	var blank: CardDef = CardDef.from_dict({"id": "x", "title": "X", "type": "strike", "attack": {"kind": "strike"}})
	eq(AiScorer._expected_damage_value(blank.attack, "strike", profile), AiScorer.EVEN_TABLE_STAGES * profile.w("play", "damage_stage"), "a plain Strike is read at the equal-band table result")


## The scorer prices what a choice costs and buys, rather than taking whichever option comes first:
## paying a life card for more damage, burning the discard pile against a hit, and which card to
## keep through the opponent's turn.
func test_scorer_prices_optional_costs_burns_and_keeps() -> void:
	# Steel Clawed Heel: "You may discard the top card of your Life Deck: +3 wounds."
	var steel: DuelEngine = real_engine(real_deck(["steel_strike_20"], "vigil", "steel", "Emrys Rooke"), real_deck([], "pact"))
	var steps: int = 0
	while steel.prompt != null and not (steel.prompt.kind == &"attack_action" and steel.prompt.player == 0) and steps < 20:
		steps += 1
		var quiet: Command = null
		for t in [&"done", &"declare", &"decline", &"pass"]:
			quiet = steel.prompt.find(t) if quiet == null else quiet
		steel.submit(quiet if quiet != null else steel.prompt.options[steel.prompt.options.size() - 1])
	answer(steel, &"attack", uid_in_hand(steel, 0, "steel_strike_20"))
	eq(prompt_kind(steel), &"pay", "the life cost is offered")
	var paid: Command = AiScorer.pick(steel, AiProfile.default_profile())
	eq(paid.type, &"pay_life", "the scorer answers it")
	eq(int(paid.value), 1, "and pays a card for three wounds")
	# Tide Fathom Mastery: burn Tide cards from the discard pile, two wounds prevented per card.
	var tide_deck: DeckList = real_deck([], "pact", "tide")
	tide_deck.mastery_id = "tide_mastery_02"
	var burn: DuelEngine = real_engine(real_deck(["storm_art_07"], "vigil", "storm"), tide_deck)
	for i in range(4):
		real_to_discard(burn, 1, "tide_art_02")
	to_attack(burn, 0)
	burn.player(0).duelist.energy = 5
	answer(burn, &"attack", uid_in_hand(burn, 0, "storm_art_07"))
	var guard: int = 0
	while burn.prompt != null and burn.prompt.kind != &"defense" and guard < 6:
		guard += 1
		burn.submit(burn.prompt.options[0])
	eq(prompt_kind(burn), &"defense", "the defender is asked")
	var most: int = 0
	for o in burn.prompt.options:
		if o.type == &"burn_defense":
			most = maxi(most, int(o.value))
	check(most >= 2, "several burns are offered")
	var burned: Command = AiScorer.pick(burn, AiProfile.default_profile())
	check(burned.type != &"burn_defense" or int(burned.value) == most, "a burn clears the whole hit rather than one card's worth: %s" % burned.describe())
	# Keeping one card through the opponent's turn: the block can act there, the attack cannot.
	var k: DuelEngine = real_engine(real_deck([], "pact"), real_deck([], "vigil"))
	var me: PlayerState = k.player(k.state.active)
	var block: CardInstance = real_to_hand(k, me.index, "steel_strike_19")
	var swing: CardInstance = real_to_hand(k, me.index, "storm_art_07")
	var profile: AiProfile = AiProfile.default_profile()
	check(AiScorer.hold_value(swing, profile) > AiScorer.hold_value(block, profile), "the Art is the better card to hold in general")
	check(AiScorer._keep_score(k, me, block, profile) > AiScorer._keep_score(k, me, swing, profile), "but the block is the one to keep through their turn")


## A "you may" line is priced by what it costs and what it buys, a Relic use by what it takes away
## now, and the Duelist's soaked Energy by what the deck wants it for.
func test_scorer_prices_may_lines_relic_uses_and_soaked_energy() -> void:
	var profile: AiProfile = AiProfile.default_profile()
	var e: DuelEngine = real_engine(real_deck([], "pact"), real_deck([], "vigil"))
	var me: PlayerState = e.player(0)
	# "You may discard the top card of your Life Deck: this attack is Focused." With no attack in the
	# air there is nothing for Focus to get past, so the life card is a pure cost.
	e._choice = {"effect": shipped().get_def("pyre_mastery_01").effects[0]}
	check(AiScorer._may_yes_score(e, me, profile) < 0.0, "a life card paid for nothing is declined")
	e._choice = {"effect": {"op": "draw", "amount": 1, "may": true}}
	check(AiScorer._may_yes_score(e, me, profile) > 0.0, "a free draw is taken")
	# The Blank Mask forbids the rival's Mastery for the turn.
	var mask: CardInstance = e._instance(shipped().get_def("relic_01"), 0, &"reserve")
	var foe: PlayerState = e.player(1)
	foe.mastery = null
	eq(AiScorer.relic_score(e, profile, me, mask), 0.0, "forbidding a Mastery they do not have is worth nothing")
	foe.mastery = e._instance(shipped().get_def("pyre_mastery_01"), 1, &"in_play")
	check(AiScorer.relic_score(e, profile, me, mask) > 0.0, "and forbidding one they have is worth a use")
	# A deck that fights through its Allies wants its Duelist's Energy spent once an Ally can take over.
	var tide: AiProfile = AiProfile.for_deck(DeckList.load_from("res://data/decks/tide_companions.json"), "")
	eq(AiScorer.duelist_energy_price(e, me, tide), tide.w("own", "energy"), "with no Ally out, Energy keeps its price")


## The scorer prices a line against the table it lands on: a draw that decks someone, an "all"
## that counts what is there, a forbid on a side, a card type picked for what the rival holds.
func test_scorer_prices_lines_against_the_table() -> void:
	var profile: AiProfile = AiProfile.default_profile()
	var e: DuelEngine = real_engine(real_deck([], "pact"), real_deck([], "vigil"))
	var me: PlayerState = e.player(0)
	var foe: PlayerState = e.player(1)
	# Drawing past the end of a Life Deck loses the duel.
	while me.life_deck.size() > 2:
		me.life_deck.pop_back()
	eq(AiScorer.effects_value([{"op": "draw", "amount": 3}], profile, [], 0.0, e, 0), -AiEvaluator.WIN, "a draw that empties our deck loses")
	check(AiScorer.effects_value([{"op": "draw", "amount": 3}], profile, []) > 0.0, "read from the card alone, a draw is still a draw")
	# Removing every Ally counts the Allies on each side.
	var dismissal: Array = shipped().get_def("freestyle_combat_17").effects
	eq(AiScorer.effects_value(dismissal, profile, [], 0.0, e, 0), 0.0, "with no Allies anywhere it does nothing")
	real_inject(e, 1, _an_ally_id())
	check(AiScorer.effects_value(dismissal, profile, [], 0.0, e, 0) > 0.0, "with only theirs out it is a gain")
	real_inject(e, 0, _an_ally_id())
	real_inject(e, 0, _an_ally_id())
	check(AiScorer.effects_value(dismissal, profile, [], 0.0, e, 0) < 0.0, "with more of ours out it is a loss")
	# A forbid on our own side is a cost.
	check(AiScorer.effects_value([{"op": "forbid", "who": "self", "what": "drills"}], profile, [], 0.0, e, 0) < 0.0, "forbidding ourselves costs")
	# "Discard all their Allies or all their Drills": the pick follows what they hold.
	e._choice = {"kind": "card_type", "effect": {"op": "discard_in_play", "who": "opponent", "all": true}}
	check(AiScorer._word_score(e, me, profile, "ally") > AiScorer._word_score(e, me, profile, "drill"), "their Ally goes when they have no Drills")
	# Declaring Combat makes them draw three: with two left, that ends the duel.
	while foe.life_deck.size() > 2:
		foe.life_deck.pop_back()
	var declare: Prompt = Prompt.new()
	declare.player = 0
	declare.kind = &"declare"
	declare.options = [Command.new(0, &"declare"), Command.new(0, &"skip")]
	eq(AiScorer._score(e, profile, declare, declare.options[0], {}), AiEvaluator.WIN, "declaring into a deck that cannot draw three wins")


## The attack score reads the hit the way it will land: Energy past the defender's gauge is wounds,
## a killing blow is the game, an Empowered swing loses its "after Empower" text, and a Final Strike
## is a bare Strike that costs the card thrown.
func test_scorer_reads_attacks_the_way_they_land() -> void:
	var profile: AiProfile = AiProfile.default_profile()
	var e: DuelEngine = real_engine(real_deck([], "pact"), real_deck([], "vigil"))
	var me: PlayerState = e.player(0)
	var foe: PlayerState = e.player(1)
	var strike: Command = Command.new(0, &"attack", -1)
	foe.in_control().energy = 0
	var hit: Dictionary = {-1: {"stages": 5, "life": 0, "overflow": 5, "wounds": 5, "cost_stages": 0}}
	var soaked: Dictionary = {-1: {"stages": 5, "life": 0, "overflow": 0, "wounds": 0, "cost_stages": 0}}
	check(AiScorer._attack_score(e, profile, me, foe, strike, null, hit) > AiScorer._attack_score(e, profile, me, foe, strike, null, soaked), "Energy past an empty gauge is priced as wounds")
	while foe.life_deck.size() > 4:
		foe.life_deck.pop_back()
	eq(AiScorer._attack_score(e, profile, me, foe, strike, null, hit), AiEvaluator.WIN, "five wounds into four life cards wins")
	# Empower drops the lines marked "after Empower".
	var card: CardInstance = real_to_hand(e, 0, "signature_strike_02")
	var plain: Command = Command.new(0, &"attack", card.uid)
	var empower: Command = Command.new(0, &"attack", card.uid, "empower")
	var same: Dictionary = {card.uid: {"stages": 3, "life": 0, "overflow": 0, "wounds": 0, "cost_stages": 0, "empowered": {"stages": 3, "life": 0, "overflow": 0, "wounds": 0, "cost_stages": 0}}}
	foe.life_deck.append_array([])
	check(AiScorer._attack_score(e, profile, me, foe, empower, card, same) < AiScorer._attack_score(e, profile, me, foe, plain, card, same), "with the same numbers, Empower is worth less by the text it drops")
	# A Final Strike with the card: the bare Strike's numbers, less the card.
	var final_cmd: Command = Command.new(0, &"final_strike", card.uid)
	same[card.uid]["final"] = {"stages": 3, "life": 0, "overflow": 0, "wounds": 0, "cost_stages": 0}
	check(AiScorer._attack_score(e, profile, me, foe, final_cmd, card, same) < AiScorer._attack_score(e, profile, me, foe, plain, card, same), "throwing the card away is worth less than swinging with it")


## Critical damage and capture choices are priced by what they change: a lethal hit beats a Seal, the
## strongest Ally goes first, and the rival's Fervor matters more near their Ascension.
func test_scorer_prices_critical_and_capture_choices() -> void:
	var profile: AiProfile = AiProfile.default_profile()
	var e: DuelEngine = real_engine(real_deck([], "pact"), real_deck([], "vigil"))
	var me: PlayerState = e.player(0)
	var foe: PlayerState = e.player(1)
	var seal: CardInstance = real_inject(e, 1, "seal_08")
	check(AiScorer._capture_score(e, profile, me, foe, seal) > 0.0, "taking a Seal is worth something")
	var weak: CardInstance = real_inject(e, 1, _an_ally_id())
	var strong: CardInstance = real_inject(e, 1, _an_ally_id())
	weak.energy = 0
	strong.energy = 8
	check(AiScorer._ally_worth(e, profile, foe, strong) > AiScorer._ally_worth(e, profile, foe, weak), "the Ally with more Energy is the one to take")
	foe.fervor = 0
	eq(AiScorer._lower_fervor_score(e, profile, foe), 0.0, "no Fervor, nothing to take")
	foe.fervor = 3
	check(AiScorer._lower_fervor_score(e, profile, foe) > 0.0, "a Fervor taken sets their climb back")


## What the Mastery adds to an attack counts toward that attack, when the attack meets its gate.
func test_scorer_counts_the_mastery_lines_an_attack_triggers() -> void:
	var d: DeckList = real_deck([], "pact", "storm")
	d.mastery_id = "storm_mastery_02"
	var e: DuelEngine = real_engine(d, real_deck([], "vigil"))
	var profile: AiProfile = AiProfile.default_profile()
	var me: PlayerState = e.player(0)
	var storm: float = AiScorer._mastery_attack_value(e, profile, me, shipped().get_def("storm_art_07"), "art", 0.0)
	check(storm > 0.0, "a Storm Art is worth the Strike lock it sets")
	eq(AiScorer._mastery_attack_value(e, profile, me, shipped().get_def("tide_art_02"), "art", 0.0), 0.0, "another school's Art sets nothing")


## The evaluator's resource terms: Energy the next Power Up refills anyway, and cards past what the
## discard step keeps, count half.
func test_evaluator_discounts_refilled_energy_and_doomed_hand_cards() -> void:
	var e: DuelEngine = real_engine(real_deck([], "pact"), real_deck([], "vigil"))
	var p: PlayerState = e.player(e.state.active)
	p.duelist.energy = CardInstance.MAX_STAGE
	var gain: int = e.recover_gain(p)
	eq(AiEvaluator.held_energy(e, p), float(CardInstance.MAX_STAGE) - 0.5 * float(mini(gain, CardInstance.MAX_STAGE)), "a full gauge counts its refilled part at half")
	p.duelist.energy = 0
	eq(AiEvaluator.held_energy(e, p), 0.0, "an empty one is empty")
	while p.hand.size() < 4:
		real_to_hand(e, p.index, "storm_art_07")
	var keep: int = e._hand_keep(p)
	e.state.step = GameState.Step.COMBAT
	eq(AiEvaluator.kept_hand(e, p), float(keep) + 0.5 * float(p.hand.size() - keep), "on its own turn the cards past the limit count half")
	e.state.step = GameState.Step.RECOVER
	eq(AiEvaluator.kept_hand(e, p), float(p.hand.size()), "after the discard step every card counts")


## Declaring Combat is answered by the scorer, and a single thin ply does not overrule it.
func test_search_defers_to_the_scorer_on_stances_and_near_ties() -> void:
	var profile: AiProfile = AiProfile.default_profile()
	check(profile.scorer_decides(&"declare"), "the declare prompt is a stance the scorer answers")
	var search: AiSearch = AiSearch.new()
	search.metrics = {"completed_depth": 1}
	var completed: Array[Dictionary] = [{"index": 0, "value": 10.4}, {"index": 1, "value": 10.0}]
	var prior: Array[float] = [1.0, 5.0]
	eq(search._trust_scorer_at_depth_one(profile, completed, prior, 0), 1, "a depth-1 lead under the margin keeps the scorer's pick")
	completed[0]["value"] = 12.0
	eq(search._trust_scorer_at_depth_one(profile, completed, prior, 0), 0, "a clear lead stands")
	search.metrics = {"completed_depth": 2}
	completed[0]["value"] = 10.4
	eq(search._trust_scorer_at_depth_one(profile, completed, prior, 0), 0, "and two completed plies are trusted as they are")


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
	# Merge mechanics, read without the shipped calibration on top; the scale checks below add their own.
	p.data["scale"] = {}
	p.merge({"name": "test", "own": {"seal": 99.0}, "think": {"search": false}, "nonsense": {"x": 1}})
	eq(p.name, "test", "name taken")
	eq(p.w("own", "seal"), 99.0, "the named weight changed")
	eq(p.w("own", "life"), float(AiProfile.DEFAULTS["own"]["life"]), "the rest kept their defaults")
	eq(p.searches(), false, "think knobs merge too")
	eq(float(AiProfile.default_profile().data["own"]["seal"]), float(AiProfile.DEFAULTS["own"]["seal"]), "a merge never writes to the defaults")
	eq(AiProfile.default_profile().w("own", "seal"), float(AiProfile.DEFAULTS["own"]["seal"]) * float(AiProfile.DEFAULTS["scale"]["own.seal"]), "and a default profile reads through the shipped calibration")
	p.merge({"scale": {"own.seal": 1.5}})
	eq(p.w("own", "seal"), 148.5, "a scale multiplies the deck's own value")
	eq(p.w("own", "life"), float(AiProfile.DEFAULTS["own"]["life"]), "and leaves unscaled weights alone")
	p.merge({"own": {"seal": 10.0}})
	eq(p.w("own", "seal"), 15.0, "and still applies when the value under it changes")
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
	var short_road: CardDef = lib.get_def("tf_marked_short_1")
	var long_road: CardDef = lib.get_def("tf_marked_long_1")
	eq(short_road.character, long_road.character, "the same person")
	check(short_road.variant != long_road.variant, "and two printings of them")
	eq(PersonalityStack.from_ids(lib, stack_ids("tf_marked_short", 3)).highest_aspect(), 3, "one climbs three aspects")
	eq(PersonalityStack.from_ids(lib, stack_ids("tf_marked_long", 5)).highest_aspect(), 5, "the other five")
	check(short_road.raw.get("tags", []).has("marked"), "one is marked")
	check(not long_road.raw.get("tags", []).has("marked"), "and the other is not, which is allowed")
	# The name is the character and nothing else since 2026-09-21: the card face already prints the
	# Aspect title under it, and a card two lines share carries no variant to print at all.
	eq(CardText.personality_name(short_road), "Test Two-Faced", "the name is the character")
	eq(CardText.personality_name(long_road), "Test Two-Faced", "both printings read the same")
	eq(CardText.personality_line(short_road), "the Short Road", "the line is what tells them apart")
	eq(CardText.personality_name(lib.get_def("t_ally_squire")), "Test Squire", "one printing needs no variant")
	var d: DeckList = deck(filler(["tf_marked_short_1"]), "vigil", "", "t_mastery_pyre", 3, "tf_marked_long")
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
	e.player(0).duelist.go_to_aspect(3)
	e._apply_effect({"op": "lose_aspect", "who": "opponent"}, 1, {}, null)
	eq(e.player(0).duelist.aspect, 2, "without the lock they drag him down a rung")
	e.player(0).duelist.go_to_aspect(3)
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
	me.duelist.go_to_aspect(3)
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
	me.duelist.go_to_aspect(3)
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
	me.duelist.go_to_aspect(1)
	var plain_mine: int = int(e._damage_calc(mine)["table"])
	var plain_against: int = int(e._damage_calc(theirs)["table"])
	me.duelist.go_to_aspect(2)
	eq(int(e._damage_calc(mine)["table"]), plain_mine + 2, "his own Strikes hit the table 2 harder")
	eq(int(e._damage_calc(theirs)["table"]), maxi(0, plain_against - 2), "and Strikes at him land 2 softer")


## "You may discard a marked card from your hand. If you do, this Power may be used a second time
## this Combat." The extra use only exists while the cost is in hand, and it is paid on the way in.
func test_a_power_can_buy_a_second_use_with_a_card_from_hand() -> void:
	var e: DuelEngine = engine(deck(filler(), "vigil", "", "", 3, "tf_marked_lord"), deck(filler(), "pact"))
	var me: PlayerState = e.player(0)
	me.duelist.go_to_aspect(1)
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
	me.duelist.go_to_aspect(1)
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
## The most duels a run can hold: three acts of up to 5 fights and a boss each.
const ADVENTURE_MAX_DUELS: int = 18
## Bundle `group` values that name a school. The other four are freestyle, grounds, ally, signature.
const ADVENTURE_SCHOOL_GROUPS: Array[String] = ["pyre", "steel", "tide", "storm", "root", "shade"]
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
	run.duelist_ids.append("personality_03")
	run.status = "reward"
	run.node_id = "a1t4l2"
	run.path = ["a1t1l1", "a1t2l1", "a1t3l2", "a1t4l2"]
	run.pending_offer.append("pyre_strike_12")
	run.picks.append({"stage": 0, "kind": "pick", "id": "pyre_strike_12"})
	var copy: AdventureRun = AdventureRun.from_dict(run.to_dict())
	eq(copy.node_id, "a1t4l2", "the node the run stands on survives to_dict")
	eq(copy.path, run.path, "and so does the path walked")
	var older: Dictionary = run.to_dict()
	older["version"] = AdventureRun.SAVE_VERSION - 1
	check(AdventureRun.from_dict(older) == null, "a save from before the node map is refused, not migrated")
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
		eq(loaded.duelist_ids, run.duelist_ids, "the Duelist's Aspect cards came back whole")
		eq(loaded.run_seed, 4242, "seed came back an int")
		eq(loaded.cards, run.cards, "the deck came back whole")
		eq(int(loaded.picks[0].get("stage", -1)), 0, "and a pick row came back an int")
	AdventureSave.clear()
	check(not AdventureSave.exists(), "clear removes the save")
	# An older save on disk loads as nothing and is removed, so no Continue points at it.
	var stale: Dictionary = run.to_dict()
	stale["version"] = AdventureRun.SAVE_VERSION - 1
	var handle: FileAccess = FileAccess.open(AdventureSave.path(), FileAccess.WRITE)
	handle.store_string(JSON.stringify(stale))
	handle.close()
	check(AdventureSave.load_run() == null, "an older save loads as no run")
	check(not AdventureSave.exists(), "and the stale file is dropped")
	AdventureSave.path_override = ""
	# Two seed streams off one run seed, neither zero and never the same for a duel.
	for n in range(ADVENTURE_MAX_DUELS):
		check(run.stage_seed(n) > 0, "stage seed %d is positive" % n)
		check(run.offer_seed(n) > 0, "offer seed %d is positive" % n)
		check(run.stage_seed(n) != run.offer_seed(n), "stage and offer seeds differ at %d" % n)


## Every banded family fields every deck tier the map can ask for, whichever roll comes up, and
## every one of those decks is legal.
func test_adventure_bands_field_every_tier() -> void:
	var shipped: CardLibrary = shipped_library()
	eq(AdventureDecks.playable_starters().size(), 14, "every starter can begin a run")
	for family in AdventureDecks.banded_families():
		for tier in ["t1", "t2", "t3", "t4", "t5", "boss"]:
			var deck: DeckList = DeckList.resolve("%s_%s" % [family, tier])
			check(deck != null, "%s fields a %s deck" % [family, tier])
			if deck != null:
				var problems: Array[String] = DeckValidator.validate(deck, shipped)
				eq(problems.size(), 0, "%s_%s is legal: %s" % [family, tier, ", ".join(problems)])


const ADVENTURE_MAP_SEEDS: Array[int] = [1, 2, 3, 77, 4242]


## Three acts; tiers 1 to 7 joined without crossing, every node on a path from the start to the
## act's boss; tier 1 offers a choice; the Relic tier is all Relic nodes; the same seed rolls the same map.
func test_adventure_map_is_three_acts_of_connected_tiers() -> void:
	for starter_id in AdventureDecks.playable_starters():
		for run_seed in ADVENTURE_MAP_SEEDS:
			var map: AdventureMap = AdventureMap.generate(starter_id, run_seed)
			check(map != null, "%s seed %d rolls a map" % [starter_id, run_seed])
			if map == null:
				continue
			var tag: String = "%s seed %d" % [starter_id, run_seed]
			eq(map.acts, 3, "%s has three acts" % tag)
			var again: AdventureMap = AdventureMap.generate(starter_id, run_seed)
			eq(again.nodes, map.nodes, "%s: the same seed rolls the same map" % tag)
			check(AdventureMap.generate(starter_id, run_seed + 1000).nodes != map.nodes,
				"%s: another seed rolls another map" % tag)
			check(map.start_ids().size() >= 2, "%s: tier 1 offers a choice" % tag)
			var reached: Dictionary = {}
			var frontier: Array[String] = map.start_ids()
			while not frontier.is_empty():
				var id: String = frontier.pop_back()
				if reached.has(id):
					continue
				reached[id] = true
				frontier.append_array(map.next_of(id))
			eq(reached.size(), map.nodes.size(), "%s: every node can be reached from the start" % tag)
			for act in range(1, 4):
				var boss: String = AdventureMap.boss_id_of(act)
				eq(str(map.node(boss).get("type", "")), "boss", "%s act %d ends in a boss" % [tag, act])
				eq(map.next_of(boss).size(), 0 if act == 3 else map.ids_at(act + 1, 1).size(),
					"%s act %d boss leads on to every start of the next act" % [tag, act])
				for tier in range(1, AdventureMap.PATH_TIERS + 1):
					var row: Array[String] = map.ids_at(act, tier)
					check(not row.is_empty(), "%s act %d tier %d has nodes" % [tag, act, tier])
					var drawn: Array = []
					for id in row:
						var n: Dictionary = map.node(id)
						check(not map.next_of(id).is_empty(), "%s: %s leads somewhere" % [tag, id])
						if tier == 1:
							eq(str(n["type"]), "duel", "%s: %s opens the act with a duel" % [tag, id])
						if act == 1 and tier == 3:
							eq(str(n["type"]), "relic", "%s: %s is on the Relic tier" % [tag, id])
						elif str(n["type"]) == "relic":
							check(false, "%s: %s is a Relic node off the Relic tier" % [tag, id])
						for to in map.next_of(id):
							var t: Dictionary = map.node(to)
							if tier < AdventureMap.PATH_TIERS:
								eq(int(t["tier"]), tier + 1, "%s: %s leads one tier up" % [tag, id])
								drawn.append([int(n["lane"]), int(t["lane"])])
							else:
								eq(to, boss, "%s: %s leads to the boss" % [tag, id])
					for e in drawn:
						for f in drawn:
							var crossed: bool = (int(f[0]) < int(e[0]) and int(f[1]) > int(e[1])) \
								or (int(f[0]) > int(e[0]) and int(f[1]) < int(e[1]))
							check(not crossed, "%s act %d tier %d: edges %s and %s cross" % [tag, act, tier, e, f])


## Every path through tiers 1 to 7 of an act holds 2 to 5 fights. Across many runs a path with
## only 2 is rare and most paths hold 3 or 4.
func test_adventure_map_paths_hold_two_to_five_fights() -> void:
	var totals: Dictionary = {}
	var paths: int = 0
	for run_seed in range(1, 61):
		var map: AdventureMap = AdventureMap.generate("tide_deepwater_start", run_seed)
		if map == null:
			check(false, "seed %d rolls a map" % run_seed)
			continue
		for act in range(1, 4):
			var got: Vector2i = map.fight_range(act)
			check(got.x >= 2 and got.y <= 5, "seed %d act %d: paths hold %d to %d fights" % [run_seed, act, got.x, got.y])
			var counts: Dictionary = map.path_fight_counts(act)
			for k in counts.keys():
				totals[int(k)] = int(totals.get(int(k), 0)) + int(counts[k])
				paths += int(counts[k])
	var two: float = float(totals.get(2, 0)) / float(maxi(paths, 1))
	var middle: float = float(int(totals.get(3, 0)) + int(totals.get(4, 0))) / float(maxi(paths, 1))
	print("  map paths by fight count: %s over %d paths" % [str(totals), paths])
	check(two < 0.10, "paths with only 2 fights are rare: %.2f" % two)
	check(middle > 0.5, "most paths hold 3 or 4 fights: %.2f" % middle)


## Every fighting node names a deck that exists, never the starter's own family, never the same
## family as the fight just before it, with an AI profile. Quarr ends every run but his own. A path
## gains three Aspects: its first duel and the act 1 and act 2 bosses.
func test_adventure_map_fields_legal_opponents() -> void:
	var resolved: Dictionary = {}
	for starter_id in AdventureDecks.playable_starters():
		var own: String = AdventureDecks.family_of(starter_id)
		for run_seed in ADVENTURE_MAP_SEEDS:
			var map: AdventureMap = AdventureMap.generate(starter_id, run_seed)
			if map == null:
				check(false, "%s seed %d rolls a map" % [starter_id, run_seed])
				continue
			var tag: String = "%s seed %d" % [starter_id, run_seed]
			var final: String = str(map.duel_for(AdventureMap.boss_id_of(3)).get("opponent", ""))
			if own == "steel_beatdown":
				check(final != "steel_beatdown_boss", "%s: Quarr does not fight himself" % tag)
			else:
				eq(final, "steel_beatdown_boss", "%s: Quarr is the final boss" % tag)
			for id in map.nodes.keys():
				var n: Dictionary = map.node(id)
				var duel: Dictionary = map.duel_for(id)
				eq(not duel.is_empty(), AdventureMap.is_fight(str(n["type"])), "%s: %s has a duel exactly when it is a fight" % [tag, id])
				if duel.is_empty():
					continue
				var opponent: String = str(duel.get("opponent", ""))
				if not resolved.has(opponent):
					resolved[opponent] = DeckList.resolve(opponent) != null
				check(bool(resolved[opponent]), "%s: %s opponent '%s' resolves" % [tag, id, opponent])
				var set_boss: bool = str(n["type"]) == "boss" \
					and not AdventureStory.boss_for(starter_id, int(n["act"])).is_empty()
				if not set_boss:
					check(not AdventureDecks.same_character_families(own).has(AdventureDecks.family_of(opponent)),
						"%s: %s does not meet the run's own character" % [tag, id])
				check(FileAccess.file_exists("res://data/ai/profiles/%s.json" % str(duel.get("ai_level", ""))),
					"%s: %s ai_level has a profile" % [tag, id])
				eq(str(duel.get("story", "x")), "", "%s: %s has no story text yet" % [tag, id])
				for to in map.next_of(id):
					var after: String = str(map.duel_for(to).get("opponent", ""))
					if after != "" and int(map.node(to)["act"]) == int(n["act"]):
						check(AdventureDecks.family_of(after) != AdventureDecks.family_of(opponent),
							"%s: %s and %s fight the same family back to back" % [tag, id, to])
			# Grants sit on the first two bosses, and offer only owned Aspects (design doc 8.6).
			var grants: Array[String] = []
			for id in map.nodes.keys():
				if str(map.duel_for(id).get("grant", "")) == "aspect":
					grants.append(id)
			var expected: Array[String] = [AdventureMap.boss_id_of(1)]
			expected.append(AdventureMap.boss_id_of(2))
			grants.sort()
			expected.sort()
			eq(grants, expected, "%s: Aspect grants on the act 1 and 2 bosses" % tag)


## The three storyline starters meet their set act 1 and act 2 bosses at the act's boss tier, and
## Quarr at the end. Edric's two decks are one character, so a random draw never pairs them.
func test_adventure_storylines_set_act_bosses() -> void:
	var expected: Dictionary = {
		"tide_deepwater_start": ["steel_heir_t3", "freestyle_swords_t5"],
		"shade_mind_siege_start": ["shade_salvage_t3", "shade_henchmen_t5"],
		"pyre_beatdown_start": ["storm_volley_t3", "pyre_ascent_t5"],
	}
	eq(AdventureStory.open_starters().size(), 3, "three starters are open on a new save")
	for starter_id in expected.keys():
		for run_seed in ADVENTURE_MAP_SEEDS:
			var map: AdventureMap = AdventureMap.generate(starter_id, run_seed)
			var tag: String = "%s seed %d" % [starter_id, run_seed]
			eq(str(map.duel_for(AdventureMap.boss_id_of(1)).get("opponent", "")), expected[starter_id][0], "%s act 1 boss" % tag)
			eq(str(map.duel_for(AdventureMap.boss_id_of(2)).get("opponent", "")), expected[starter_id][1], "%s act 2 boss" % tag)
			eq(str(map.duel_for(AdventureMap.boss_id_of(3)).get("opponent", "")), "steel_beatdown_boss", "%s final boss" % tag)
	var edric: Array[String] = AdventureDecks.same_character_families("tide_deepwater")
	check(edric.has("pyre_ascent"), "Edric's decks are one character: %s" % str(edric))


func _lead_in_ctx(main: String, opponent: String, extra: Dictionary = {}) -> Dictionary:
	var ctx: Dictionary = AdventureLeadIns.empty_context()
	ctx["main"] = main
	ctx["opponent"] = opponent
	ctx.merge(extra, true)
	return ctx


func _lead_in_slot(ctx: Dictionary) -> String:
	var key: String = str(AdventureLeadIns.pick(ctx).get("key", ""))
	return key.get_slice("|", 2)


## A pair's slot follows how the two have met: first, again, after a loss, act 3, level, boss.
func test_lead_in_slots_follow_how_the_pair_met() -> void:
	var edric: String = "Sir Edric Rooke"
	eq(_lead_in_slot(_lead_in_ctx(edric, "Dame Alder Rooke")), "first", "never met plays first")
	eq(_lead_in_slot(_lead_in_ctx(edric, "Dame Alder Rooke", {"met": 1})), "again", "met before plays again")
	eq(_lead_in_slot(_lead_in_ctx(edric, "Dame Alder Rooke", {"met": 1, "last": "lost"})), "after_loss", "a loss last time plays after_loss")
	eq(_lead_in_slot(_lead_in_ctx(edric, "Dame Alder Rooke", {"met": 1, "act": 3})), "act3", "act 3 plays act3")
	eq(_lead_in_slot(_lead_in_ctx(edric, "Dame Alder Rooke", {"met": 1, "act": 3, "level": 3})), "level", "a levelled main plays level first")
	eq(_lead_in_slot(_lead_in_ctx(edric, "Dame Alder Rooke", {"met": 1, "shown": ["%s|Dame Alder Rooke|again" % edric]})), "first", "a scene shown this run gives way")
	eq(_lead_in_slot(_lead_in_ctx(edric, "Emrys Rooke", {"boss": true})), "boss", "a boss node plays boss")
	eq(_lead_in_slot(_lead_in_ctx(edric, "Emrys Rooke", {"boss": true, "met": 1, "last": "lost"})), "boss_again", "losing the boss plays boss_again")
	var first_meet: Dictionary = AdventureLeadIns.pick(_lead_in_ctx("Gideon Mourne", "Sable Draik", {"boss": true}))
	var met_before: Dictionary = AdventureLeadIns.pick(_lead_in_ctx("Gideon Mourne", "Sable Draik", {"boss": true, "met": 1}))
	check(str(first_meet["narration"]) != str(met_before["narration"]), "Sable's boss scene has a met and an unmet variant")
	var fire: Dictionary = AdventureLeadIns.pick(_lead_in_ctx("Gideon Mourne", edric, {"met": 1, "act": 3, "family": "pyre_ascent"}))
	var tide: Dictionary = AdventureLeadIns.pick(_lead_in_ctx("Gideon Mourne", edric, {"met": 1, "act": 3, "family": "tide_deepwater"}))
	check(str(fire["narration"]) != str(tide["narration"]), "Edric's fire deck has its own act 3 scene")
	var alder: Dictionary = AdventureLeadIns.pick(_lead_in_ctx(edric, "Dame Alder Rooke"))
	var lines: Array = alder["lines"]
	eq(str(lines[0]["speaker"]), "Alder", "the speaker is read off the line")
	eq(str(lines[0]["side"]), AdventureLeadIns.SIDE_OPPONENT, "the opponent speaks from the opponent's side")
	eq(str(lines[1]["side"]), AdventureLeadIns.SIDE_MAIN, "the main speaks from the main's side")
	check(AdventureLeadIns.pick(_lead_in_ctx(edric, "Nobody Anyone")).is_empty(), "an unknown opponent has no lead-in")


## An opponent with no pair entry calls, and the main answers with a reply that fits the call.
func test_lead_in_general_call_gets_a_fitting_reply() -> void:
	var sable: Dictionary = AdventureLeadIns.pick(_lead_in_ctx("Sir Edric Rooke", "Sable Draik"))
	eq(str(sable["key"]), "call|Sable Draik", "Sable calls Edric")
	var lines: Array = sable["lines"]
	eq(lines.size(), 2, "a call and a reply")
	eq(str(lines[1]["side"]), AdventureLeadIns.SIDE_MAIN, "Edric answers")
	check(str(lines[1]["text"]) in ["Not a chance!"], "Edric answers a demand: %s" % lines[1]["text"])
	var siphon: Dictionary = AdventureLeadIns.pick(_lead_in_ctx("Sir Edric Rooke", "Siphon", {"construct": true, "shown": ["reply|Sir Edric Rooke|2"]}))
	eq(str((siphon["lines"] as Array)[1]["text"]), "I'd feed you if I could...", "the construct reply answers a construct")
	var levelled: Dictionary = AdventureLeadIns.pick(_lead_in_ctx("Sir Edric Rooke", "Sable Draik", {"level": 3}))
	eq(str((levelled["lines"] as Array)[1]["text"]), "You fight like my brother. That's not a compliment.", "a levelled reply is preferred once reached")


## A joined Ally adds a line once per act, its `once` line first; Ashmark hears someone he beat.
func test_lead_in_joined_ally_and_whisper_add_a_line() -> void:
	var first: Dictionary = AdventureLeadIns.pick(_lead_in_ctx("Gideon Mourne", "Sable Draik", {"joined": ["Orvath Kell"], "act": 2}))
	var last: Dictionary = (first["lines"] as Array).back()
	eq(str(last["side"]), AdventureLeadIns.SIDE_ALLY, "Kell speaks as the ally")
	eq(str(last["text"]), "I still wear the gorget, my lord. Someone has to.", "Kell's first line is his once line")
	check((first["keys"] as Array).has("joined|Orvath Kell|act2"), "the act is marked")
	var later: Dictionary = AdventureLeadIns.pick(_lead_in_ctx("Gideon Mourne", "Sable Draik",
		{"joined": ["Orvath Kell"], "act": 3, "shown": ["joined|Orvath Kell|once"]}))
	eq(str(((later["lines"] as Array).back() as Dictionary)["text"]), "Guard up, my lord!", "after the once line Kell uses any")
	var same_act: Dictionary = AdventureLeadIns.pick(_lead_in_ctx("Gideon Mourne", "Sable Draik",
		{"joined": ["Orvath Kell"], "act": 2, "shown": ["joined|Orvath Kell|act2"]}))
	eq((same_act["lines"] as Array).size(), 2, "Kell speaks once an act")
	var whisper: Dictionary = AdventureLeadIns.pick(_lead_in_ctx("Bram Ashmark", "Siphon", {"beaten": ["Gideon Mourne"], "seed": 0}))
	var sides: Array[String] = []
	for line in whisper["lines"]:
		sides.append(str(line["side"]))
	check(sides.has(AdventureLeadIns.SIDE_WHISPER), "Ashmark hears someone he beat: %s" % str(sides))
	var none: Dictionary = AdventureLeadIns.pick(_lead_in_ctx("Bram Ashmark", "Siphon", {"seed": 0}))
	for line in none["lines"]:
		check(str(line["side"]) != AdventureLeadIns.SIDE_WHISPER, "no whisper before a win this run")


## Every authored line names a known speaker, stays short, and every pair names real characters.
func test_lead_in_data_is_well_formed() -> void:
	var data: Dictionary = AdventureLeadIns.read_data()
	check(not data.is_empty(), "lead_ins.json parses")
	var shipped: CardLibrary = CardLibrary.new()
	shipped.load_dir("res://data/cards")
	var characters: Array[String] = []
	for id in shipped.all_ids():
		var def: CardDef = shipped.defs[id]
		if def.is_personality() and not characters.has(def.character):
			characters.append(def.character)
	var names: Dictionary = data.get("names", {})
	for who in names.keys():
		check(characters.has(str(who)), "%s is a character" % who)
	var short_names: Array = names.values()
	var scenes: Array[Dictionary] = AdventureLeadIns.all_scenes(data)
	check(scenes.size() > 80, "every scene is listed for the preview: %d" % scenes.size())
	for scene in scenes:
		var title: String = str(scene["title"])
		check(str(scene["narration"]).length() <= 120, "%s narration is short" % title)
		check(not (scene["lines"] as Array).is_empty(), "%s has lines" % title)
		for line in scene["lines"]:
			check(short_names.has(str(line["speaker"])), "%s: %s is in names" % [title, line["speaker"]])
			check(str(line["side"]) != AdventureLeadIns.SIDE_ALLY, "%s: %s is one of the pair" % [title, line["speaker"]])
			check(str(line["text"]).length() <= 90, "%s line is short: %s" % [title, line["text"]])
	for slots in (data.get("pairs", {}) as Dictionary).values():
		for pair in (slots as Dictionary).values():
			for slot in (pair as Dictionary).keys():
				check(AdventureLeadIns.SLOT_ORDER.has(str(slot)), "%s is a known slot" % slot)
	for who in (data.get("joined", {}) as Dictionary).keys():
		check(names.has(str(who)), "joined %s has a short name" % who)


func test_story_log_records_results_and_round_trips() -> void:
	var story: AdventureStoryLog = AdventureStoryLog.new()
	story.begin_run("run_a")
	story.record_result("Bram Ashmark", "Siphon", true)
	story.record_result("Bram Ashmark", "Siphon", false)
	story.mark_shown(["Bram Ashmark|Siphon|first"])
	eq(story.met("Bram Ashmark", "Siphon"), 2, "two duels met")
	eq(story.last("Bram Ashmark", "Siphon"), "lost", "the last result is kept")
	check(story.beaten.has("Siphon"), "a win adds the opponent to this run's beaten")
	var back: AdventureStoryLog = AdventureStoryLog.from_dict(JSON.parse_string(JSON.stringify(story.to_dict())))
	eq(back.met("Bram Ashmark", "Siphon"), 2, "met survives a save")
	check(back.shown.has("Bram Ashmark|Siphon|first"), "shown survives a save")
	back.begin_run("run_b")
	check(back.beaten.is_empty() and back.shown.is_empty(), "a new run clears the run's lists")
	eq(back.met("Bram Ashmark", "Siphon"), 2, "meetings outlive the run")


## An Encounter carries a guest from the run's storyline; a run with no guests has no Encounters.
func test_adventure_encounters_bring_a_guest_from_the_storyline() -> void:
	var met: int = 0
	for run_seed in range(1, 31):
		var edric: AdventureMap = AdventureMap.generate("tide_deepwater_start", run_seed)
		for id in edric.nodes.keys():
			if str(edric.node(id)["type"]) == "encounter":
				met += 1
				check(AdventureStory.guests_for("tide_deepwater_start").has(str(edric.duel_for(id).get("guest", ""))),
					"seed %d: %s brings a storyline guest" % [run_seed, id])
		var bram: AdventureMap = AdventureMap.generate("pyre_beatdown_start", run_seed)
		for id in bram.nodes.keys():
			check(str(bram.node(id)["type"]) != "encounter", "seed %d: Ashmark fields no guests (%s)" % [run_seed, id])
	check(met > 0, "Edric's runs meet encounters: %d" % met)


func test_a_guest_ally_starts_in_play() -> void:
	var shipped: CardLibrary = shipped_library()
	var e: DuelEngine = DuelEngine.new()
	var decks: Array[DeckList] = [DeckList.resolve("tide_deepwater_start"), DeckList.resolve("steel_heir_t3")]
	e.setup(decks, shipped, StrikeTable.load_from("res://data/strike_table.json"), 5)
	check(e.set_guest_ally(0, "personality_35"), "a personality can join as a guest")
	check(not e.set_guest_ally(0, "no_such_card"), "an unknown card cannot")
	var found: bool = false
	for c in e.state.players[0].in_play:
		if c.def.id == "personality_35":
			found = true
			eq(c.controller, 0, "the guest fights for the player")
	check(found, "the guest is in play before the duel starts")
	e.start()
	check(not e.state.is_over(), "the duel starts with a guest in play")


## Beating Edric's act 1 boss adds Emrys to the run deck once; beating an ordinary duel adds nothing.
func test_adventure_boss_win_joins_the_run() -> void:
	var shipped: CardLibrary = shipped_library()
	var run: AdventureRun = AdventureRun.begin("tide_deepwater_start", 5)
	var map: AdventureMap = AdventureMap.generate("tide_deepwater_start", 5)
	run.node_id = map.start_ids()[0]
	eq(AdventureStory.apply_boss_win(run, map, shipped), "", "an ordinary duel adds nobody")
	run.node_id = AdventureMap.boss_id_of(1)
	var before: int = run.cards.size()
	eq(AdventureStory.apply_boss_win(run, map, shipped), "personality_35", "Emrys joins after the act 1 boss")
	eq(run.cards.size(), before + 1, "his card is in the run deck")
	check(DeckValidator.validate(run.deck(), shipped).is_empty(), "the deck is still legal")
	eq(AdventureStory.apply_boss_win(run, map, shipped), "", "he joins only once")
	run.node_id = AdventureMap.boss_id_of(2)
	eq(AdventureStory.apply_boss_win(run, map, shipped), "", "the act 2 boss adds nobody")
	var mourne: AdventureRun = AdventureRun.begin("shade_mind_siege_start", 5)
	var mourne_map: AdventureMap = AdventureMap.generate("shade_mind_siege_start", 5)
	mourne.node_id = AdventureMap.boss_id_of(1)
	eq(AdventureStory.apply_boss_win(mourne, mourne_map, shipped), "personality_47", "Kell joins Mourne after the act 1 boss")


## Achievements: ordered steps, hidden ones revealed by their first step, unordered ones in any
## order, chained through a completed achievement, and a secret one invisible until done.
func test_adventure_achievements_track_steps() -> void:
	AdventureUnlocks.path_override = "user://adventure/test_unlocks.json"
	AdventureUnlocks.clear()
	var u: AdventureUnlocks = AdventureUnlocks.load_unlocks()
	eq(u.available_starters(), ["tide_deepwater_start", "shade_mind_siege_start", "pyre_beatdown_start"] as Array[String],
		"a new save opens the three storyline starters")
	var edric_act2: Dictionary = {"event": "duel_won", "main": "Sir Edric Rooke", "starter": "tide_deepwater_start",
		"node": "boss", "act": 2, "opponent": "Caedan Vale", "allies": [], "blocks": 3, "aspect": 3}
	var done: Array[Dictionary] = AdventureAchievements.apply(u, [edric_act2] as Array[Dictionary])
	eq(done.size(), 1, "Edric's act 2 boss completes the Vale test")
	eq(str(done[0].get("starter", "")), "freestyle_swords_start", "which opens Caedan's starter")
	eq(AdventureAchievements.apply(u, [edric_act2] as Array[Dictionary]).size(), 0, "and only once")
	# Hidden: undiscovered until its first step, then named.
	var row: Dictionary = _journal_row(u, "edric_fire_in_the_knight")
	eq(str(row.get("state", "")), "unknown", "a hidden achievement starts unknown")
	eq(str(row.get("title", "")), "Undiscovered", "and unnamed")
	eq(str(row.get("reward", "")), "", "with its reward hidden")
	var beat_bram: Dictionary = {"event": "duel_won", "main": "Sir Edric Rooke", "opponent": "Bram Ashmark",
		"node": "duel", "act": 1, "allies": [], "blocks": 0, "aspect": 2}
	eq(AdventureAchievements.apply(u, [beat_bram] as Array[Dictionary]).size(), 0, "one early win is only a first step")
	var revealed: Dictionary = _journal_row(u, "edric_fire_in_the_knight")
	eq(str(revealed.get("state", "")), "progress", "which reveals it")
	check(str(revealed.get("hint", "")).contains("Aspect 3"), "with the plain hint: %s" % str(revealed.get("hint", "")))
	check(str(revealed.get("reward", "")) != "", "and its reward named")
	var shallow: Dictionary = beat_bram.duplicate()
	shallow["act"] = 2
	eq(AdventureAchievements.apply(u, [shallow] as Array[Dictionary]).size(), 0, "the second step wants Aspect 3")
	var deep: Dictionary = shallow.duplicate()
	deep["aspect"] = 3
	eq(AdventureAchievements.apply(u, [deep] as Array[Dictionary]).size(), 1, "and completes once it is met")
	# Allies together, and a block limit.
	var together: Dictionary = {"event": "duel_won", "main": "Sir Edric Rooke", "allies": ["Emrys Rooke"], "act": 1}
	eq(AdventureAchievements.apply(u, [together] as Array[Dictionary]).size(), 0, "one of the two allies is not enough")
	together["allies"] = ["Emrys Rooke", "Dame Alder Rooke"]
	eq(AdventureAchievements.apply(u, [together] as Array[Dictionary]).size(), 1, "both complete the line holds")
	var head_on: Dictionary = {"event": "duel_won", "main": "Bram Ashmark", "opponent": "Siphon", "node": "boss", "act": 1, "blocks": 1}
	eq(AdventureAchievements.apply(u, [head_on] as Array[Dictionary]).size(), 0, "a block spoils head-on")
	head_on["blocks"] = 0
	eq(AdventureAchievements.apply(u, [head_on] as Array[Dictionary]).size(), 1, "and none earns it")
	# Unordered, then a secret chained off it.
	eq(_journal_row(u, "quarr_unbroken").size(), 0, "a secret achievement is not in the journal")
	for main in ["Bram Ashmark", "Gideon Mourne"]:
		AdventureAchievements.apply(u, [{"event": "run_won", "main": main}] as Array[Dictionary])
	eq(u.steps_done("the_heart").size(), 2, "the Heart's steps land in any order")
	var last: Array[Dictionary] = AdventureAchievements.apply(u,
		[{"event": "run_won", "main": "Sir Edric Rooke"}] as Array[Dictionary])
	eq(last.size(), 1, "the third main completes the Heart")
	eq(u.steps_done("quarr_unbroken").size(), 1, "whose completion is the secret's first step")
	check(u.save(), "unlocks save")
	var loaded: AdventureUnlocks = AdventureUnlocks.load_unlocks()
	check(loaded.is_complete("the_heart") and loaded.steps_done("quarr_unbroken").size() == 1,
		"achievement progress survives a reload")
	AdventureUnlocks.clear()
	AdventureUnlocks.path_override = ""


## The journal's joins: deck routes leave secrets out and name a hidden one only once started,
## a secret-only deck is known as one, and a character's milestones come back in level order.
func test_adventure_journal_routes() -> void:
	var u: AdventureUnlocks = AdventureUnlocks.new()
	var p: AdventureProgress = AdventureProgress.new()
	eq(AdventureAchievements.routes("steel_beatdown_start", u, p).size(), 0, "a secret route is never listed")
	check(AdventureAchievements.secret_only("steel_beatdown_start"), "so Quarr's deck is secret-only")
	check(not AdventureAchievements.secret_only("pyre_ascent_start"), "Ember Ascendant has public routes")
	check(not AdventureAchievements.secret_only("storm_volley_start"), "a deck with no route at all is not secret")
	var ascent: Array[Dictionary] = AdventureAchievements.routes("pyre_ascent_start", u, p)
	var texts: Array[String] = []
	for r in ascent:
		texts.append(str(r["text"]))
	check(texts.has("Achievement: The hero falls") and texts.has("Edric level 5"),
		"both of Ember Ascendant's routes are named: %s" % str(texts))
	p.personality_xp["Sir Edric Rooke"] = 520
	for r in AdventureAchievements.routes("pyre_ascent_start", u, p):
		if str(r["text"]) == "Edric level 5":
			eq([int(r["done"]), int(r["total"])], [4, 5], "a level route counts the level reached")
	var ms: Array[Dictionary] = p.milestones("Sir Edric Rooke")
	eq(ms.map(func(m: Dictionary) -> int: return int(m["level"])), [2, 3, 4, 5, 7], "Edric's authored levels in order")
	eq(ms.filter(func(m: Dictionary) -> bool: return bool(m["reached"])).size(), 3, "three reached at level 4")
	eq(p.personality_xp_to("Sir Edric Rooke", 5), 180, "and 180 XP short of level 5")
	eq(p.milestones("Caedan Vale").size(), 0, "a character with no track has no authored milestones")
	var shipped: CardLibrary = shipped_library()
	eq(AdventureProgress.reward_short({"starter": "pyre_ascent_start"}, shipped), "Deck: Ember Ascendant", "a deck reward in short")
	eq(AdventureProgress.reward_short({"abilities": ["start_relic", "start_reserve"]}, shipped), "Starting Relic and Reserve",
		"both run-start abilities read as one")
	eq(AdventureProgress.reward_short({"cards": ["signature_art_04", "signature_drill_05"]}, shipped), "2 signature cards",
		"signatures are counted")


func _journal_row(u: AdventureUnlocks, id: String) -> Dictionary:
	for row in AdventureAchievements.journal(u, shipped_library()):
		if str(row["id"]) == id:
			return row
	return {}


## XP: the main, the allies in play and the beaten opponent all gain; levels pay out once each,
## school levels hand out the school's cards in order and dust past the cap, and a milestone
## opens a starter or grants an ability.
func test_adventure_xp_levels_pay_milestones() -> void:
	var shipped: CardLibrary = shipped_library()
	var p: AdventureProgress = AdventureProgress.new()
	eq(AdventureProgress.level_of(0, [0, 100, 250], 100), 1, "0 XP is level 1")
	eq(AdventureProgress.level_of(250, [0, 100, 250], 100), 3, "a threshold reached is its level")
	eq(AdventureProgress.level_of(460, [0, 100, 250], 100), 5, "past the curve each step adds a level")
	var boss: Dictionary = {"main": "Sir Edric Rooke", "school": "tide", "node": "boss", "act": 1,
		"opponent": "Emrys Rooke", "allies": ["Emrys Rooke", "Tavin Vale"], "run_won": false}
	var ups: Array[Dictionary] = []
	for i in range(4):
		ups.append_array(p.award(boss))
	eq(int(p.personality_xp["Sir Edric Rooke"]), 100, "the main gains boss XP")
	eq(int(p.personality_xp["Emrys Rooke"]), 4 * (15 + 15), "an ally who is also the beaten boss gains both")
	eq(p.personality_level("Sir Edric Rooke"), 2, "100 XP is level 2")
	var edric_twos: int = 0
	for up in ups:
		if str(up["key"]) == "Sir Edric Rooke" and int(up["level"]) == 2:
			edric_twos += 1
	eq(edric_twos, 1, "a level is reported once")
	eq(p.award({"main": "Sir Edric Rooke", "node": "duel"}).size(), 0, "and not again on the next win")
	# Rewards.
	var collection: AdventureCollection = AdventureCollection.new()
	var unlocks: AdventureUnlocks = AdventureUnlocks.new()
	var wallet: AdventureWallet = AdventureWallet.new()
	var emrys: Dictionary = p.reward_for({"kind": "personality", "key": "Emrys Rooke", "level": 2}, shipped)
	AdventureProgress.grant(emrys, "Emrys Rooke", shipped, collection, unlocks, wallet)
	check(unlocks.is_open("steel_heir_start"), "Emrys's level 2 opens Steel Inheritance")
	var edric3: Dictionary = p.reward_for({"kind": "personality", "key": "Sir Edric Rooke", "level": 3}, shipped)
	AdventureProgress.grant(edric3, "Sir Edric Rooke", shipped, collection, unlocks, wallet)
	check(unlocks.has_ability("Sir Edric Rooke", AdventureUnlocks.ABILITY_RELIC), "Edric's level 3 grants a starting Relic")
	var generic: Dictionary = p.reward_for({"kind": "personality", "key": "Tavin Vale", "level": 2}, shipped)
	eq(int(generic.get("signatures", 0)), 2, "a character with no track gets two signatures a level")
	var pool: Array[String] = AdventureProgress.school_pool("tide", shipped)
	for school in ["freestyle", "tide", "pyre"]:
		for id in AdventureProgress.school_pool(school, shipped):
			check(not shipped.get_def(id).is_signature(), "a signature card is never in the %s pool: %s" % [school, id])
	var first: Dictionary = p.reward_for({"kind": "school", "key": "tide", "level": 2}, shipped)
	eq(first["cards"], pool.slice(0, 3), "a school level hands out the next three of its pool")
	var second: Dictionary = p.reward_for({"kind": "school", "key": "tide", "level": 3}, shipped)
	eq(second["cards"], pool.slice(3, 6), "and the level after, the three after that")
	var mastery: Dictionary = p.reward_for({"kind": "school", "key": "tide", "level": 4}, shipped)
	var has_mastery: bool = false
	for id in mastery["cards"]:
		if shipped.has(str(id)) and shipped.get_def(str(id)).type == CardDef.Type.MASTERY:
			has_mastery = true
	check(has_mastery, "a mastery level adds a Mastery")
	for i in range(3):
		collection.add(pool[0], 1, shipped)
	var before: int = wallet.motes
	AdventureProgress.grant({"cards": [pool[0]]}, "", shipped, collection, unlocks, wallet)
	check(wallet.motes > before, "a copy past the cap dusts into Motes")
	# A starting Relic comes from the character's own precon.
	var run: AdventureRun = AdventureRun.begin("tide_deepwater_start", 9)
	AdventureProgress.prepare_run(run, shipped, collection, unlocks)
	check(run.relic_id != "", "Edric's run starts with a Relic")
	eq(DeckValidator.validate(run.deck(), shipped).size(), 0, "and the deck is still legal")
	# The whole path a won duel takes: the storyline join, XP, and achievements, in one call.
	var edric: AdventureRun = AdventureRun.begin("tide_deepwater_start", 5)
	var edric_map: AdventureMap = AdventureMap.generate("tide_deepwater_start", 5)
	edric.node_id = AdventureMap.boss_id_of(1)
	var fresh: AdventureProgress = AdventureProgress.new()
	var lines: Array[Dictionary] = AdventureProgress.record_win(edric, edric_map, null, shipped,
		AdventureCollection.new(), AdventureUnlocks.new(), fresh, AdventureWallet.new())
	check(lines.size() > 1 and str(lines[0]["kind"]) == "join" and str(lines[0]["title"]) == "Emrys Rooke",
		"the act 1 boss win reports Emrys joining: %s" % str(lines))
	eq(str(lines[1]["kind"]), "xp", "then the XP it paid")
	var emrys_routes: Array[Dictionary] = AdventureAchievements.routes("steel_heir_start", AdventureUnlocks.new(), fresh)
	check(emrys_routes.size() == 1 and str(emrys_routes[0]["text"]) == "Emrys level 2",
		"a locked deck names what opens it: %s" % str(emrys_routes))
	eq(int(fresh.personality_xp.get("Sir Edric Rooke", 0)), 25, "Edric gains boss XP")
	eq(int(fresh.personality_xp.get("Emrys Rooke", 0)), 15, "Emrys gains XP for being beaten at a boss")
	eq(int(fresh.school_xp.get("tide", 0)), 25, "and Tide gains school XP")
	var exclusive: Array[String] = AdventureProgress.exclusive_ids()
	check(exclusive.has("personality_32"), "milestone and achievement cards are known")
	for id in AdventureVendor.pool(shipped):
		check(not exclusive.has(id), "the vendor never stocks %s" % id)


## The reward screen never shows a bundle the validator would refuse, and never someone else's.
## An all-wins run across the whole map, taking the first choice and the first bundle every time.
func test_an_adventure_offer_is_three_legal_bundles_the_deck_can_run() -> void:
	var shipped: CardLibrary = shipped_library()
	for starter_id in AdventureDecks.playable_starters():
		var map: AdventureMap = AdventureMap.generate(starter_id, 91011)
		var run: AdventureRun = AdventureRun.begin(starter_id, 91011)
		if map == null or run == null:
			check(false, "%s has both a map and a starter deck" % starter_id)
			continue
		var duelist: CardDef = shipped.defs.get(run.deck().duelist_face_id())
		var style: String = run.deck().style
		var taken: Dictionary = {}
		var n: int = 0
		while run.status != "won" and n < ADVENTURE_MAX_DUELS:
			check(run.walk_to_next_duel(map), "%s duel %d is reachable" % [starter_id, n + 1])
			var progress: float = map.progress_of(run.node_id)
			var eligible: Array[String] = AdventureRewards.eligible(run, shipped, progress)
			AdventureRewards.finish_stage(run, map, shipped, true)
			if run.status == "aspect":
				check(AdventureRewards.apply_aspect(run, shipped, run.pending_aspects[0]),
					"%s stage %d takes the offered Aspect" % [starter_id, n + 1])
				AdventureRewards.finish_aspect(run, map, shipped)
				eligible = AdventureRewards.eligible(run, shipped, progress)
			eq(run.status, "reward", "%s stage %d ends on the reward screen" % [starter_id, n + 1])
			var offer: Array[String] = run.pending_offer
			if offer.size() != 3:
				print("    note: %s stage %d offered %d bundles of %d eligible"
					% [starter_id, n + 1, offer.size(), eligible.size()])
			# As many as it can: three, less what the per-group cap keeps out of a thin pool.
			var per_group: Dictionary = {}
			for id in eligible:
				var g: String = str(AdventureBundles.by_id(id).get("group", ""))
				per_group[g] = int(per_group.get(g, 0)) + 1
			var room: int = 0
			for g in per_group.keys():
				room += mini(int(per_group[g]), AdventureRewards.MAX_PER_GROUP)
			check(offer.size() == mini(AdventureRewards.OFFER_SIZE, room),
				"%s stage %d offers as many bundles as it can" % [starter_id, n + 1])
			var seen: Dictionary = {}
			var groups: Dictionary = {}
			var own_school_offered: bool = false
			for id in offer:
				check(not seen.has(id), "%s stage %d offers distinct bundles" % [starter_id, n + 1])
				seen[id] = true
				check(not taken.has(id), "%s stage %d does not re-offer '%s'" % [starter_id, n + 1, id])
				var bundle: Dictionary = AdventureBundles.by_id(id)
				check(not bundle.is_empty(), "%s stage %d offers a known bundle '%s'" % [starter_id, n + 1, id])
				if bundle.is_empty():
					continue
				var group: String = str(bundle.get("group", ""))
				groups[group] = int(groups.get(group, 0)) + 1
				if group == style:
					own_school_offered = true
				var school_group: bool = ADVENTURE_SCHOOL_GROUPS.has(group)
				check(not school_group or group == style,
					"%s stage %d: '%s' is a %s bundle, deck Style is %s" % [starter_id, n + 1, id, group, style])
				if group == AdventureBundles.GROUP_SIGNATURE:
					eq(str(bundle.get("character", "")), duelist.character,
						"%s stage %d: '%s' is this Duelist's own signature bundle" % [starter_id, n + 1, id])
				if str(bundle.get("tier", "")) == "late":
					check(progress >= 0.5, "%s stage %d: late bundle '%s' waits for half way" % [starter_id, n + 1, id])
				var trial: DeckList = run.deck()
				trial.cards.append_array(AdventureBundles.cards_of(bundle))
				var problems: Array[String] = DeckValidator.validate(trial, shipped)
				eq(problems.size(), 0, "%s stage %d: adding '%s' whole stays legal: %s"
					% [starter_id, n + 1, id, ", ".join(problems)])
			for group in groups.keys():
				check(int(groups[group]) <= AdventureRewards.MAX_PER_GROUP,
					"%s stage %d: no more than two %s bundles" % [starter_id, n + 1, group])
			var own_eligible: bool = false
			for id in eligible:
				if str(AdventureBundles.by_id(id).get("group", "")) == style:
					own_eligible = true
			if own_eligible:
				check(own_school_offered, "%s stage %d offers one of its own school" % [starter_id, n + 1])
			var picked: String = offer[0] if offer.size() > 0 else ""
			if picked != "":
				check(AdventureRewards.apply_bundle(run, shipped, picked),
					"%s stage %d takes the first bundle" % [starter_id, n + 1])
				taken[picked] = true
				eq(DeckValidator.validate(run.deck(), shipped).size(), 0,
					"%s stage %d: the deck is legal after the bundle" % [starter_id, n + 1])
			else:
				AdventureRewards.apply_skip(run)
			AdventureRewards.finish_reward(run, map)
			n += 1
		eq(run.status, "won", "%s beats the final boss" % starter_id)
		eq(run.node_id, map.final_id(), "%s ends on the final boss" % starter_id)


## A granting boss stops for a choice among the owned Aspect cards instead of handing one over
## silently. An ordinary duel never grants.
func test_the_first_duel_grant_offers_an_aspect_choice() -> void:
	var shipped: CardLibrary = shipped_library()
	var map: AdventureMap = AdventureMap.generate("pyre_beatdown_start", 7)
	var run: AdventureRun = AdventureRun.begin("pyre_beatdown_start", 7)
	run.owned_aspects = ["personality_03", "personality_56"]
	eq(run.aspects(), 2, "a starter opens at two Aspects")
	check(run.walk_to_next_duel(map), "the run steps onto its first duel")
	AdventureRewards.finish_stage(run, map, shipped, true)
	eq(run.status, "reward", "an ordinary duel grants nothing")
	AdventureRewards.apply_skip(run)
	AdventureRewards.finish_reward(run, map)
	run.node_id = AdventureMap.boss_id_of(1)
	run.status = "stage"
	AdventureRewards.finish_stage(run, map, shipped, true)
	eq(run.status, "aspect", "the act 1 boss stops for the Aspect choice")
	eq(run.pending_aspects, ["personality_03", "personality_56"],
		"and lists both of Bram Ashmark's third Aspects")
	eq(run.pending_offer.size(), 0, "the bundle offer waits until the Aspect is taken")
	eq(run.aspects(), 2, "and nothing has been granted yet")
	check(not AdventureRewards.apply_aspect(run, shipped, "personality_09"),
		"an Aspect that was not offered is refused")
	check(AdventureRewards.apply_aspect(run, shipped, "personality_03"),
		"the Hollow line's third Aspect is taken")
	eq(run.aspects(), 3, "the stack grew by one card")
	eq(DeckValidator.validate(run.deck(), shipped).size(), 0, "and the Duelist stack still validates")
	AdventureRewards.finish_aspect(run, map, shipped)
	eq(run.status, "reward", "then the run moves on to its bundles")
	check(run.pending_offer.size() > 0, "which were built after the Aspect went in")
	eq(str(run.picks[run.picks.size() - 1].get("kind", "")), "aspect", "the Aspect is recorded as a pick")
	AdventureRewards.apply_skip(run)
	AdventureRewards.finish_reward(run, map)
	eq(run.status, "map", "a won duel hands the run back to the map")
	run.node_id = AdventureMap.boss_id_of(2)
	run.status = "stage"
	AdventureRewards.finish_stage(run, map, shipped, true)
	eq(run.status, "reward", "with no owned tier 4 the act 2 boss goes straight to the bundles")
	eq(run.aspects(), 3, "so the Aspect count is unchanged")
	# A loss ends the run wherever it happens.
	var lost: AdventureRun = AdventureRun.begin("pyre_beatdown_start", 7)
	lost.walk_to_next_duel(map)
	AdventureRewards.finish_stage(lost, map, shipped, false)
	eq(lost.status, "lost", "a loss ends the run")
	# A Duelist with nowhere left to climb skips the grant and says so.
	var topped: AdventureRun = AdventureRun.begin("pyre_beatdown_start", 7)
	topped.duelist_ids = ["personality_01", "personality_55",
		"personality_56", "personality_57",
		"personality_58"]
	topped.node_id = AdventureMap.boss_id_of(1)
	topped.status = "stage"
	AdventureRewards.finish_stage(topped, map, shipped, true)
	eq(topped.status, "reward", "a full stack goes straight to the bundles")
	eq(str(topped.picks[0].get("kind", "")), "aspect_skipped", "and the skipped grant is recorded")


func test_adventure_offers_follow_the_run_seed() -> void:
	var shipped: CardLibrary = shipped_library()
	var first: Array[String] = adventure_offer_sequence(shipped, "pyre_beatdown_start", 555)
	var again: Array[String] = adventure_offer_sequence(shipped, "pyre_beatdown_start", 555)
	var other: Array[String] = adventure_offer_sequence(shipped, "pyre_beatdown_start", 556)
	eq(first, again, "the same run seed offers the same bundles")
	check(first != other, "a different run seed offers a different sequence somewhere")


## Every offered bundle id of an all-wins, always-skip run, flattened.
func adventure_offer_sequence(shipped: CardLibrary, starter_id: String, run_seed: int) -> Array[String]:
	var out: Array[String] = []
	var map: AdventureMap = AdventureMap.generate(starter_id, run_seed)
	var run: AdventureRun = AdventureRun.begin(starter_id, run_seed)
	if map == null or run == null:
		return out
	while run.status != "won" and run.walk_to_next_duel(map):
		AdventureRewards.finish_stage(run, map, shipped, true)
		if run.status == "aspect":
			AdventureRewards.apply_aspect(run, shipped, run.pending_aspects[0])
			AdventureRewards.finish_aspect(run, map, shipped)
		out.append_array(run.pending_offer)
		AdventureRewards.apply_skip(run)
		AdventureRewards.finish_reward(run, map)
	return out


## A stale offer held by a client cannot smuggle a bundle in, and a bundle is all or nothing.
func test_an_adventure_bundle_is_refused_when_it_was_not_offered() -> void:
	var shipped: CardLibrary = shipped_library()
	var map: AdventureMap = AdventureMap.generate("pyre_beatdown_start", 31)
	var run: AdventureRun = AdventureRun.begin("pyre_beatdown_start", 31)
	run.walk_to_next_duel(map)
	AdventureRewards.finish_stage(run, map, shipped, true)
	if run.status == "aspect":
		AdventureRewards.apply_aspect(run, shipped, run.pending_aspects[0])
		AdventureRewards.finish_aspect(run, map, shipped)
	var before: int = run.cards.size()
	check(not AdventureRewards.apply_bundle(run, shipped, "not_a_bundle_id"), "an unoffered id is refused")
	eq(run.cards.size(), before, "and the deck is untouched")
	eq(run.pending_offer.size(), 3, "and the offer is still standing")
	# A deck that changed since the offer was drawn refuses the whole bundle, not part of it.
	var blocked: String = run.pending_offer[0]
	var blocked_cards: Array[String] = AdventureBundles.cards_of_id(blocked)
	var stuffed: AdventureRun = AdventureRun.begin("pyre_beatdown_start", 31)
	stuffed.walk_to_next_duel(map)
	AdventureRewards.finish_stage(stuffed, map, shipped, true)
	if stuffed.status == "aspect":
		AdventureRewards.apply_aspect(stuffed, shipped, stuffed.pending_aspects[0])
		AdventureRewards.finish_aspect(stuffed, map, shipped)
	for i in range(DeckValidator.SIGNATURE_LIMIT):
		stuffed.cards.append(blocked_cards[0])
	var stuffed_before: int = stuffed.cards.size()
	check(not AdventureRewards.apply_bundle(stuffed, shipped, blocked),
		"a bundle whose first card no longer fits is refused whole")
	eq(stuffed.cards.size(), stuffed_before, "and not one of its cards went in")
	eq(stuffed.pending_offer.size(), 3, "the offer is still there to choose from")
	# The clean run takes it.
	var expected: int = before + blocked_cards.size()
	check(AdventureRewards.apply_bundle(run, shipped, blocked), "an offered bundle goes in")
	eq(run.cards.size(), expected, "the deck grew by every card of the bundle")
	eq(run.pending_offer.size(), 0, "and the offer is spent")
	var last: Dictionary = run.picks[run.picks.size() - 1]
	eq(str(last.get("kind", "")), "bundle", "the pick is recorded as a bundle")
	eq(str(last.get("id", "")), blocked, "with the bundle id")
	eq((last.get("cards", []) as Array).size(), blocked_cards.size(), "and the cards it added")
	eq(run.taken_bundles(), [blocked], "taken_bundles reads it back")
	eq(run.stage, 0, "taking a bundle does not advance the stage")


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


## Answers the windows an attack opens on its way to landing. It never passes, so the phase stays
## where it is and the Combat's own records are still standing when the test reads them.
func settle(e: DuelEngine, limit: int = 40, order: Array[StringName] = [&"no_defense", &"no_endure", &"no_critical", &"target", &"decline"]) -> void:
	var guard: int = 0
	while e.prompt != null and not e.is_over() and guard < limit:
		guard += 1
		var quiet: Command = null
		for t in order:
			quiet = e.prompt.find(t)
			if quiet != null:
				break
		if quiet == null:
			return
		e.submit(quiet)


## "Use only after you have taken 5 or more wounds from a single attack this Combat." The clause is
## an `only.when`, so it runs through the same `_cond` every other card condition does, and it gates
## the use rather than the placement.
func test_a_card_can_wait_for_a_five_wound_hit() -> void:
	var e: DuelEngine = engine(deck(filler(["t_strike_wound"], 30)), deck(filler([], 30), "pact"))
	var rally: CardDef = lib.get_def("t_rally_after_wound")
	var them: PlayerState = e.player(1)
	inject(e, 1, "t_rally_after_wound")
	check(not e._can_play(them, rally), "nothing has landed yet, so the card cannot be used")
	to_combat(e)
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike_wound"))
	settle(e, 6)
	check(them.worst_wound_combat >= 5, "the hit is remembered as %d wounds" % them.worst_wound_combat)
	check(e._can_play(them, rally), "and now the card may be used")
	# The record belongs to the Combat, not the duel.
	skip_to_turn(e, e.state.turn + 2)
	eq(them.worst_wound_combat, 0, "a new Combat starts the count again")
	check(not e._can_play(them, rally), "so the card waits again")
	check(CardText.rules_text(rally).contains("taken 5 or more wounds from a single attack this Combat"),
		"the gate prints: %s" % CardText.rules_text(rally))


## "Choose 1 or 2 of your opponent's Seals in play and place them at the bottom of their Life Deck."
## Not a discard: `to: "deck_bottom"` puts them under, in the order the chooser picked them, and the
## deck is not shuffled, so both players can count on where they went.
func test_seals_can_be_put_under_their_owners_life_deck() -> void:
	var e: DuelEngine = engine(deck(filler(["t_sink_seals"], 20)), deck(filler([], 20), "pact"))
	var first: CardInstance = inject(e, 1, "t_seal_1")
	var second: CardInstance = inject(e, 1, "t_seal_2")
	to_combat(e)
	answer(e, &"use", uid_in_hand(e, 0, "t_sink_seals"))
	eq(prompt_kind(e), &"pick_in_play", "the user chooses which Seals go under")
	eq(e.prompt.player, 0, "and the choice is theirs, not the owner's")
	check(e.prompt.find(&"pick_none") == null, "\"1 or 2\" takes at least one")
	check(e.submit(Command.new(0, &"pick_in_play", -1, [first.uid, second.uid])), "both go under")
	var theirs: Array[CardInstance] = e.player(1).life_deck
	eq(e.card(first.uid).zone, &"life_deck", "the Seal went to the deck, not the discard pile")
	eq(theirs[theirs.size() - 2].uid, first.uid, "the Seal chosen first sits above the other")
	eq(theirs[theirs.size() - 1].uid, second.uid, "and the one chosen second is the bottom card")
	eq(e.player(1).seals().size(), 0, "neither is in play any more")
	var text: String = CardText.rules_text(lib.get_def("t_sink_seals"))
	check(text.contains("bottom of their Life Deck"), "the card says where they go: %s" % text)


## "Name a card that can perform a Strike. Search your opponent's Life Deck for all copies of it and
## discard them." A search, so it asks, shows the searcher the whole deck, allows naming nothing,
## and shuffles once at the end whatever was named.
func test_naming_a_strike_strips_every_copy_from_their_deck() -> void:
	var e: DuelEngine = engine(deck(filler(["t_name_strip"], 20)), deck(filler([], 20), "pact"))
	var them: PlayerState = e.player(1)
	for i in range(3):
		to_deck(e, 1, "t_strike_wound")
	to_deck(e, 1, "t_plain_art_11")
	to_combat(e)
	answer(e, &"use", uid_in_hand(e, 0, "t_name_strip"))
	eq(prompt_kind(e), &"name_card", "naming is a prompt, not an assumption")
	eq(e.prompt.player, 0, "the searcher names it")
	check(e.prompt.find(&"name_card", -1, "Test Wounding Strike") != null, "a card that performs a Strike is on the list")
	check(e.prompt.find(&"name_card", -1, "Test Plain Art") == null, "an Art is not")
	check(e.prompt.find(&"pick_none") != null, "and nothing may be named")
	eq((e.prompt.context.get("library", []) as Array).size(), them.life_deck.size(),
		"the whole deck is laid out for the searcher")
	var view: SeatView = SeatView.of(e, 0)
	check(not view.card(them.life_deck[0].uid).hidden(), "the searcher sees it")
	var blind: SeatView = SeatView.of(e, 1)
	check(blind.card(them.life_deck[0].uid).hidden(), "the owner learns nothing new")
	var before: int = them.life_deck.size()
	answer(e, &"name_card", -1, "Test Wounding Strike")
	eq(them.life_deck.size(), before - 3, "all three copies came out")
	var in_pile: int = 0
	for c in them.discard:
		if c.def.id == "t_strike_wound":
			in_pile += 1
	eq(in_pile, 3, "and they are in their discard pile")


## Naming nothing is a legal answer, and the deck is still searched, so it is still shuffled.
func test_naming_nothing_still_counts_as_the_search() -> void:
	var e: DuelEngine = engine(deck(filler([], 20)), deck(filler([], 20), "pact"), 3, true)
	to_deck(e, 1, "t_plain_art_11")
	var namer: CardInstance = to_hand(e, 0, "t_name_strip_removes")
	to_combat(e)
	answer(e, &"use", namer.uid)
	eq(prompt_kind(e), &"name_card", "an Art is in there to name")
	var before: int = e.player(1).life_deck.size()
	answer(e, &"pick_none")
	eq(e.player(1).life_deck.size(), before, "nothing left the deck")
	check(has_event(e, &"deck_shuffled"), "but the deck was searched, so it is shuffled")


## "Look at the top 2 cards of your Life Deck and put them all on top or all on the bottom, in any
## order." The end is one choice for the whole look; the order inside it is the rearrange step.
func test_a_look_can_send_the_whole_look_to_either_end() -> void:
	var e: DuelEngine = engine(deck(filler([], 30)), deck(filler([], 30), "pact"))
	inject(e, 0, "t_foresight_place")
	to_combat(e)
	eq(prompt_kind(e), &"pick_option", "the Drill asks which end")
	eq(str(e.prompt.context.get("purpose", "")), "look_place", "top or bottom, for the whole look")
	var looked: Array = e.prompt.context.get("library", [])
	eq(looked.size(), 2, "two cards were looked at")
	var seen_a: int = int(looked[0])
	var seen_b: int = int(looked[1])
	answer(e, &"pick_option", -1, "bottom")
	eq(prompt_kind(e), &"pick_option", "then the order inside them")
	check(e.prompt.find(&"pick_option", seen_b) != null, "both are still on offer")
	answer(e, &"pick_option", seen_b)
	var mine: Array[CardInstance] = e.player(0).life_deck
	eq(mine[mine.size() - 1].uid, seen_b, "the card placed first is the bottom card")
	eq(mine[mine.size() - 2].uid, seen_a, "and the other sits above it")
	eq(e.card(seen_a).zone, &"life_deck", "no card left the deck")
	check(not has_event(e, &"deck_shuffled"), "and nothing was shuffled")
	var text: String = CardText.rules_text(lib.get_def("t_foresight_place"))
	check(text.contains("all on top or all on the bottom"), "the Drill says so: %s" % text)


## "Look at the top 4 cards of your opponent's Life Deck, remove 1 non-Seal card from the game, and
## put the rest back on top in any order." The looker sees them and sets the order; the owner is
## told neither. "Remove 1" is not a may, so there is no "take nothing" while a legal card is there.
func test_a_card_can_reach_into_the_rivals_deck_and_remove_one() -> void:
	var e: DuelEngine = engine(deck(filler(["t_deck_raid"], 20)), deck(filler([], 20), "pact"))
	to_combat(e)
	var them: PlayerState = e.player(1)
	var seal: CardInstance = e._instance(lib.get_def("t_seal_1"), 1, &"life_deck")
	them.life_deck.insert(0, seal)
	var top: Array[int] = []
	for i in range(4):
		top.append(them.life_deck[i].uid)
	answer(e, &"use", uid_in_hand(e, 0, "t_deck_raid"))
	eq(prompt_kind(e), &"pick_option", "the looker picks what goes")
	eq(e.prompt.player, 0, "and it is the looker's pick, not the owner's")
	check(e.prompt.find(&"pick_none") == null, "\"Remove 1\" is not a may")
	check(e.prompt.find(&"pick_option", seal.uid) == null, "a Seal is never a legal pick")
	eq((e.prompt.context.get("library", []) as Array).size(), 4, "all four are shown to the looker")
	var raider: SeatView = SeatView.of(e, 0)
	check(not raider.card(seal.uid).hidden(), "including the Seal they may not take")
	check(SeatView.of(e, 1).card(top[3]).hidden(), "the owner sees none of it")
	var gone: int = top[1]
	answer(e, &"pick_option", gone)
	eq(e.card(gone).zone, &"removed", "the picked card left the game")
	eq(prompt_kind(e), &"pick_option", "the rest go back in the looker's order")
	answer(e, &"pick_option", top[3])
	eq(them.life_deck[0].uid, top[3], "the card placed first is the new top card")
	answer(e, &"pick_option", top[2])
	eq(them.life_deck[1].uid, top[2], "and the next one sits under it")
	eq(them.life_deck[2].uid, seal.uid, "the Seal went back with them")
	var text: String = CardText.rules_text(lib.get_def("t_deck_raid"))
	check(text.contains("opponent's Life Deck"), "the card says whose deck: %s" % text)


## "Reveal your hand; if 3 or more cards in it are of that school, attach this to your duelist.
## While attached, the attacks that duelist performs cost no Energy." The waiver is a `scope: "cost"`
## modifier, which is the same mechanism a Drill uses to make Arts cheaper.
func test_an_attachment_can_waive_what_attacks_cost() -> void:
	var e: DuelEngine = engine(deck(filler(["t_free_hand", "t_plain_art_11"], 20)), deck(filler([], 20), "pact"))
	var me: PlayerState = e.player(0)
	for i in range(3):
		to_hand(e, 0, "t_strike")
	var art: Dictionary = lib.get_def("t_plain_art_11").attack
	eq(e._cost_stages(art, me), 2, "an Art costs 2 to start with")
	to_combat(e)
	eq(prompt_kind(e), &"follow_up", "entering Combat opens the card's own window")
	eq(str(e.prompt.context.get("window", "")), "entering_combat", "and it is that window")
	eq(e.prompt.player, e.state.active, "the active player prepares first")
	check(e.prompt.find(&"decline") != null, "using it is optional")
	var chosen: Command = AiScorer.pick(e, AiProfile.default_profile(), null, 0)
	eq(chosen.type, &"use", "the scorer takes the window rather than declining")
	answer(e, &"use", uid_in_hand(e, 0, "t_free_hand"))
	check(has_event(e, &"hand_revealed"), "the hand was shown before it was counted")
	var riders: Array[CardInstance] = me.attachments()
	eq(riders.size(), 1, "three school cards in hand, so it rode onto the duelist")
	eq(riders[0].attached_to, me.duelist, "onto the duelist, not the card in control")
	eq(e._cost_stages(art, me), 0, "and attacks cost nothing while it is there")
	var rider: int = riders[0].uid
	settle(e, 30, [&"pass", &"no_defense", &"no_endure", &"no_critical", &"done", &"skip"])
	eq(e.card(rider).zone, &"discard", "it is discarded at the end of Combat")
	eq(e._cost_stages(art, me), 2, "and the Art costs 2 again")


## The count is a real condition: a hand short of the school leaves the card with nothing to do.
func test_the_cost_waiver_needs_the_school_in_hand() -> void:
	var e: DuelEngine = engine(deck(["t_free_hand", "t_art", "t_art", "t_art", "t_art", "t_art", "t_art", "t_art", "t_art"]), deck(filler([], 20), "pact"))
	to_combat(e)
	eq(prompt_kind(e), &"follow_up", "the window opens whether or not the count will hold")
	var me: PlayerState = e.player(0)
	var pyre: int = 0
	for c in me.hand:
		if c.def.school == "pyre":
			pyre += 1
	check(pyre < 3, "the hand holds %d cards of the school, short of three" % pyre)
	answer(e, &"use", uid_in_hand(e, 0, "t_free_hand"))
	check(has_event(e, &"hand_revealed"), "the hand was still shown")
	eq(me.attachments().size(), 0, "but nothing attached")
	eq(e._cost_stages(lib.get_def("t_plain_art_11").attack, me), 2, "so attacks still cost what they cost")


## The same `scope: "cost"` modifier on a Drill, with a floor: "your Arts cost 1 instead of 2".
func test_a_drill_can_price_arts_lower() -> void:
	var e: DuelEngine = engine(deck(filler([], 20)), deck(filler([], 20), "pact"))
	inject(e, 0, "t_cheap_arts_drill")
	var me: PlayerState = e.player(0)
	eq(e._cost_stages(lib.get_def("t_plain_art_11").attack, me), 1, "the Drill takes an Art from 2 to 1")
	eq(e._cost_stages(lib.get_def("t_strike").attack, me), 0, "and leaves Strikes where they were")
	eq(e._cost_stages(lib.get_def("t_plain_art_11").attack, e.player(1)), 2, "the other side pays full price")
	var text: String = CardText.rules_text(lib.get_def("t_cheap_arts_drill"))
	check(text.contains("cost 1 less") and text.contains("minimum of 1"), "the Drill prints its price: %s" % text)


## `use_at: "entering_combat"` is the only moment that card may be used. It is not an attack-phase
## action, which is how every other `use_at` already behaves: `_prompt_attack_action` only offers a
## hand Combat card whose `use_at` is empty.
func test_the_entering_combat_window_is_the_only_time_that_card_is_offered() -> void:
	var e: DuelEngine = engine(deck(filler(["t_free_hand"], 20)), deck(filler([], 20), "pact"))
	to_combat(e)
	var uid: int = uid_in_hand(e, 0, "t_free_hand")
	eq(prompt_kind(e), &"follow_up", "the window opened as Combat was entered")
	check(e.prompt.find(&"use", uid) != null, "and the card is on offer in it")
	answer(e, &"decline")
	eq(prompt_kind(e), &"attack_action", "declining carries straight on into Combat")
	eq(e.prompt.player, e.state.active, "with the active player's attack phase")
	check(e.prompt.find(&"use", uid) == null, "the card is not an ordinary attack-phase action")
	eq(e.card(uid).zone, &"hand", "and it is still in hand")
	check(CardText.rules_text(lib.get_def("t_free_hand")).contains("Use when entering Combat"), "the card says when")


## Both sides get the window, the active player first, which is the order the design doc gives for
## preparing. The opposing player is still on the hand they had: their draw comes after both
## preparations, so a card drawn for this Combat cannot be used in their own window.
func test_both_players_get_an_entering_combat_window_active_first() -> void:
	var e: DuelEngine = engine(deck(filler(["t_free_hand"], 20)), deck(filler([], 20), "pact"))
	var theirs: CardInstance = to_hand(e, 1, "t_free_hand")
	to_combat(e)
	eq(prompt_kind(e), &"follow_up", "the first window")
	eq(e.prompt.player, e.state.active, "belongs to the active player")
	eq(str(e.prompt.context.get("role", "")), "active", "and says so")
	answer(e, &"decline")
	eq(prompt_kind(e), &"follow_up", "then the other side is asked")
	eq(e.prompt.player, e.state.opposing(), "the opposing player")
	eq(str(e.prompt.context.get("role", "")), "opposing", "and that window says so too")
	check(e.prompt.find(&"use", theirs.uid) != null, "their own copy is on offer")
	answer(e, &"decline")
	eq(prompt_kind(e), &"attack_action", "and then Combat proper")


## "Use immediately after you take damage from an attack." A Non-Combat answering this timing goes
## straight from hand: it is never placed first, and it lands in the discard pile like any card
## used from hand.
func test_a_card_can_answer_the_hit_it_just_took() -> void:
	var e: DuelEngine = engine(deck(filler(["t_strike_wound"], 30)), deck(filler([], 30), "pact"))
	var riposte: CardInstance = to_hand(e, 1, "t_after_hit")
	to_combat(e)
	var attacker_deck: int = e.player(0).life_deck.size()
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike_wound"))
	settle(e, 8, [&"no_defense", &"no_endure", &"target"])
	eq(prompt_kind(e), &"follow_up", "the player who was hit gets a window")
	eq(e.prompt.player, 1, "it belongs to the defender, not the attacker")
	eq(str(e.prompt.context.get("window", "")), "after_damage", "and it is that window")
	check(e.prompt.find(&"decline") != null, "using it is optional")
	check(e.prompt.find(&"use", riposte.uid) != null, "the Non-Combat is on offer straight from hand")
	# The AI answers the new window from the option types it already knows, and takes a card whose
	# effect is worth something rather than declining by default.
	var picked: Command = AiScorer.pick(e, AiProfile.default_profile(), null, 1)
	eq(picked.type, &"use", "the scorer uses it rather than declining")
	eq(picked.card, riposte.uid, "and picks the card that costs the attacker three")
	answer(e, &"use", riposte.uid)
	eq(e.player(0).life_deck.size(), attacker_deck - 3, "the attacker lost the top 3 of their Life Deck")
	eq(e.card(riposte.uid).zone, &"discard", "and the card went to the pile, never onto the table")
	check(CardText.rules_text(lib.get_def("t_after_hit")).contains("immediately after you take damage from an attack"),
		"the card says when: %s" % CardText.rules_text(lib.get_def("t_after_hit")))


## The window opens once per attack and only when the attack landed something. `use_after_damage`
## says which kind of damage a card answers; the default is either.
func test_the_after_damage_window_reads_what_the_attack_actually_dealt() -> void:
	var e: DuelEngine = engine(deck(filler([], 20)), deck(filler([], 20), "pact"))
	var picky: CardInstance = to_hand(e, 1, "t_after_hit_wounds")
	var either: CardInstance = to_hand(e, 1, "t_after_hit")
	to_combat(e)
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike"))
	eq(prompt_kind(e), &"follow_up", "an Energy-only hit still opens the window")
	eq(int(e.prompt.context.get("life", -1)), 0, "no wounds landed")
	check(int(e.prompt.context.get("stages", 0)) > 0, "but Energy damage did")
	check(e.prompt.find(&"use", either.uid) != null, "a card that answers either kind is offered")
	check(e.prompt.find(&"use", picky.uid) == null, "one that wants wounds is not")
	answer(e, &"decline")
	eq(prompt_kind(e), &"attack_action", "declining hands the phase over as usual")
	eq(e.prompt.player, 1, "to the defender, who now fights back")
	# A stopped attack dealt nothing, so no window opens at all.
	var f: DuelEngine = engine(deck(filler([], 20)), deck(filler(["t_parry"], 20), "pact"))
	to_hand(f, 1, "t_after_hit")
	to_combat(f)
	answer(f, &"attack", uid_in_hand(f, 0, "t_strike"))
	answer(f, &"defend", uid_in_hand(f, 1, "t_parry"))
	eq(prompt_kind(f), &"attack_action", "a stopped attack opens no window")


## "Stops a Strike, and stops your opponent's next Strike in their next attack phase." A
## `next_attack_phase` float is aimed at the attacks it answers, so the phase it waits for is the
## opponent's, not its owner's own, and the phase it was set in is not the one it means.
func test_a_next_phase_stop_waits_for_the_phase_it_names() -> void:
	var e: DuelEngine = engine(deck(filler(["t_late_art_stop"], 20)), deck(filler(["t_art"], 20), "pact"))
	to_combat(e)
	answer(e, &"attack", uid_in_hand(e, 0, "t_late_art_stop"))
	settle(e, 8, [&"no_defense", &"no_endure", &"no_critical", &"target"])
	eq(e.state.attacker, 1, "the phase handed over")
	answer(e, &"attack", uid_in_hand(e, 1, "t_art"))
	check(bool(e.state.last_attack.get("stopped", false)), "their Art ran into the standing stop")


## The same float set from the defending seat has to live through the owner's own phase in between,
## and must not answer the attack it was played against: that one the card itself stopped.
func test_a_stop_set_while_defending_reaches_their_next_phase() -> void:
	var e: DuelEngine = engine(deck(filler([], 20)), deck(filler(["t_guard_echo"], 20), "pact"))
	to_combat(e)
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike"))
	answer(e, &"defend", uid_in_hand(e, 1, "t_guard_echo"))
	check(bool(e.state.last_attack.get("stopped", false)), "the card stopped the Strike it answered")
	var standing: bool = false
	for f in e.state.floating:
		if str(f.get("op", "")) == "stop_next":
			standing = true
	check(standing, "and its standing stop was not spent on that same attack")
	eq(e.state.attacker, 1, "the phase handed over to the defender")
	answer(e, &"pass")
	eq(e.state.attacker, 0, "and back again")
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike"))
	check(bool(e.state.last_attack.get("stopped", false)), "their next Strike is stopped by it")


## "Look at their hand, choose a Strike card, they discard it." The band is a `_search_matches`
## spec, so the filter is the same vocabulary a search uses. With nothing of that band in hand
## nothing is discarded, but the hand was still seen.
func test_a_hand_discard_can_name_the_band_it_takes() -> void:
	var e: DuelEngine = engine(deck(filler(["t_band_squall"], 20)), deck(filler([], 20), "pact"))
	var art: CardInstance = to_hand(e, 1, "t_art")
	to_combat(e)
	answer(e, &"attack", uid_in_hand(e, 0, "t_band_squall"))
	settle(e, 8, [&"no_defense", &"no_endure", &"no_critical", &"target"])
	eq(prompt_kind(e), &"discard_choice", "the hand is shown and a card is chosen from it")
	eq(e.prompt.player, 0, "the attacker chooses, not the owner")
	check(has_event(e, &"hand_revealed"), "and the hand was shown first")
	check(e.prompt.find(&"discard_choice", art.uid) == null, "an Art is out of the band and not on offer")
	var strike_uid: int = uid_in_hand(e, 1, "t_strike")
	check(e.prompt.find(&"discard_choice", strike_uid) != null, "a Strike is on offer")
	answer(e, &"discard_choice", strike_uid)
	eq(e.card(strike_uid).zone, &"discard", "the Strike went")
	eq(e.card(art.uid).zone, &"hand", "the Art stayed")
	# A hand with nothing of that band: seen, but nothing leaves it.
	var arts: Array[String] = []
	for i in range(12):
		arts.append("t_art")
	var f: DuelEngine = engine(deck(filler(["t_band_squall"], 20)), deck(arts, "pact"))
	to_combat(f)
	var held: int = f.player(1).hand.size()
	answer(f, &"attack", uid_in_hand(f, 0, "t_band_squall"))
	settle(f, 8, [&"no_defense", &"no_endure", &"no_critical", &"target"])
	check(has_event(f, &"hand_revealed"), "the hand was still shown")
	check(prompt_kind(f) != &"discard_choice", "but there was nothing of that band to choose")
	eq(f.player(1).hand.size(), held, "and nothing left the hand")


## "Discard one of your opponent's Non-Combat, Ally or Grounds in play": one choice over all three.
## The Grounds is not in anyone's in-play zone, so the candidate list reaches into `state.grounds`,
## and only when the Grounds on the table is the opponent's own card.
func test_one_choice_can_reach_a_non_combat_an_ally_or_the_grounds() -> void:
	var e: DuelEngine = engine(deck(filler(["t_wedge"], 20)), deck(filler([], 20), "pact"))
	var theirs: CardInstance = inject(e, 1, "t_ally_free")
	e.state.grounds = e._instance(lib.get_def("t_grounds_plain"), 1, &"grounds")
	var g: int = e.state.grounds.uid
	to_combat(e)
	answer(e, &"use", uid_in_hand(e, 0, "t_wedge"))
	eq(prompt_kind(e), &"pick_in_play", "one choice covers all three")
	check(e.prompt.find(&"pick_in_play", g) != null, "the Grounds is one of the options")
	check(e.prompt.find(&"pick_in_play", theirs.uid) != null, "and so is their Ally")
	answer(e, &"pick_in_play", g)
	check(e.state.grounds == null, "the Grounds left the table")
	eq(e.card(g).zone, &"discard", "and went to a discard pile")
	eq(e.card(g).owner, 1, "its owner's, which is the opponent's")
	eq(e.card(theirs.uid).zone, &"in_play", "the Ally was the other choice, so it stayed")
	# Your own Grounds is not the opponent's, so it is never the card that goes.
	var f: DuelEngine = engine(deck(filler(["t_wedge"], 20)), deck(filler([], 20), "pact"))
	inject(f, 1, "t_ally_free")
	f.state.grounds = f._instance(lib.get_def("t_grounds_plain"), 0, &"grounds")
	to_combat(f)
	answer(f, &"use", uid_in_hand(f, 0, "t_wedge"))
	check(f.state.grounds != null, "your own Grounds stays on the table")
	var wedge_text: String = CardText.rules_text(lib.get_def("t_wedge"))
	check(wedge_text.contains("Non-Combat card, Ally, or Grounds"), "the card names all three: %s" % wedge_text)


## "Remove the bottom 2 cards of your discard pile from the game." The pile runs oldest first, so
## its bottom is the front of the list and its top is the back.
func test_a_burn_can_take_the_bottom_of_the_discard_pile() -> void:
	var e: DuelEngine = engine(deck(filler(["t_bottom_burn"], 20)), deck(filler([], 20), "pact"))
	to_combat(e)
	var me: PlayerState = e.player(0)
	me.discard.clear()
	var pile: Array[CardInstance] = []
	for id in ["t_art", "t_strike", "t_guard", "t_parry"]:
		var c: CardInstance = e._instance(lib.get_def(id), 0, &"discard")
		me.discard.append(c)
		pile.append(c)
	answer(e, &"use", uid_in_hand(e, 0, "t_bottom_burn"))
	eq(e.card(pile[0].uid).zone, &"removed", "the bottom card went")
	eq(e.card(pile[1].uid).zone, &"removed", "and the one above it")
	eq(e.card(pile[2].uid).zone, &"discard", "the rest of the pile stayed")
	eq(e.card(pile[3].uid).zone, &"discard", "the top of it included")
	var burn_text: String = CardText.rules_text(lib.get_def("t_bottom_burn"))
	check(burn_text.contains("the bottom 2 cards"), "the card says which end: %s" % burn_text)


## "Choose any cards in your discard pile and remove them from the game": no cap, and choosing none
## is a legal answer, so the whole pile goes up as one batch.
func test_a_burn_can_take_any_number_of_cards_from_the_pile() -> void:
	var e: DuelEngine = engine(deck(filler(["t_any_burn"], 20)), deck(filler([], 20), "pact"))
	to_combat(e)
	var me: PlayerState = e.player(0)
	me.discard.clear()
	var pile: Array[CardInstance] = []
	for id in ["t_art", "t_strike", "t_guard"]:
		var c: CardInstance = e._instance(lib.get_def(id), 0, &"discard")
		me.discard.append(c)
		pile.append(c)
	answer(e, &"use", uid_in_hand(e, 0, "t_any_burn"))
	eq(prompt_kind(e), &"pick_discard", "the pile is put in front of its owner")
	eq(e.prompt.card_options().size(), 3, "every card in it is on offer")
	check(e.prompt.find(&"pick_none") != null, "and choosing none is allowed")
	check(e.submit(Command.new(0, &"pick_option", -1, [pile[0].uid, pile[2].uid])), "two of the three are taken at once")
	eq(e.card(pile[0].uid).zone, &"removed", "the first picked left the game")
	eq(e.card(pile[2].uid).zone, &"removed", "and so did the other")
	eq(e.card(pile[1].uid).zone, &"discard", "the one left alone stayed")
	var any_text: String = CardText.rules_text(lib.get_def("t_any_burn"))
	check(any_text.contains("any cards in your discard pile"), "the card names no number: %s" % any_text)


## An effect aimed at the card's own user reads as an instruction, not as third person about them.
func test_a_hand_effect_reads_from_the_right_side() -> void:
	var mine: String = CardText.effect_text({"op": "discard_hand", "all": true, "random": false})
	check(mine.contains("Discard your whole hand"), "own side is an instruction: %s" % mine)
	check(not mine.to_lower().contains("you discards"), "and never 'you discards': %s" % mine)
	var theirs: String = CardText.effect_text({"op": "discard_hand", "who": "opponent", "all": true, "random": false})
	check(theirs.contains("Your opponent discards their whole hand"), "their side names them: %s" % theirs)
	var down: String = CardText.effect_text({"op": "discard_hand", "down_to": 2})
	check(down.contains("Discard until you have"), "the down-to form too: %s" % down)
	var gone: String = CardText.effect_text({"op": "discard_hand", "amount": 1, "to": "removed"})
	check(gone.contains("Remove a card in your hand"), "and the remove form: %s" % gone)
	var every: String = CardText.effect_text({"op": "discard_hand", "all": true, "random": false, "filter": "non_combat"})
	check(every.contains("Discard every Non-Combat card in your hand"), "and the filtered form: %s" % every)


## "All of your OTHER attacks do +N for the remainder of Combat." The line runs while the attack
## that carries it is still in the air, so without the flag it would pay itself.
func test_a_standing_bonus_can_leave_out_the_attack_that_set_it() -> void:
	var paid_itself: int = float_attack_damage("t_self_boost")
	var excluded: int = float_attack_damage("t_other_attacks")
	check(paid_itself > excluded, "the flag keeps the bonus off its own attack: %d against %d" % [paid_itself, excluded])
	var e: DuelEngine = engine(deck(filler(["t_other_attacks"], 20)), deck(filler([], 20), "pact"))
	to_combat(e)
	answer(e, &"attack", uid_in_hand(e, 0, "t_other_attacks"))
	settle(e, 8, [&"no_defense", &"no_endure", &"no_critical", &"target"])
	eq(e._modifiers_for(e.player(0), "own", "strike", null, {}).size(), 1,
		"and once that attack is over the bonus is there for the ones that follow")
	var other_text: String = CardText.rules_text(lib.get_def("t_other_attacks"))
	check(other_text.contains("your other attacks"), "the card says 'other': %s" % other_text)


## What one attack takes off the defending duelist's Energy, for comparing two cards.
func float_attack_damage(id: String) -> int:
	var e: DuelEngine = engine(deck(filler([id], 20)), deck(filler([], 20), "pact"))
	to_combat(e)
	var them: PlayerState = e.player(1)
	var before: int = them.duelist.energy
	answer(e, &"attack", uid_in_hand(e, 0, id))
	settle(e, 8, [&"no_defense", &"no_endure", &"no_critical", &"target"])
	return before - them.duelist.energy


## "Remove the top 3 cards of your own Life Deck from the game." The cards leave off the top the
## way a cost takes them, so anything that reads a discarded life card still fires; they just do
## not land in the pile, which puts them past recovery.
func test_a_rider_can_exile_the_top_of_your_own_deck() -> void:
	var e: DuelEngine = engine(deck(filler(["t_self_exile"], 20)), deck(filler([], 20), "pact"))
	to_combat(e)
	var me: PlayerState = e.player(0)
	var doomed: Array[int] = [me.life_deck[0].uid, me.life_deck[1].uid, me.life_deck[2].uid]
	var pile: int = me.discard.size()
	var deck_before: int = me.life_deck.size()
	answer(e, &"use", uid_in_hand(e, 0, "t_self_exile"))
	eq(me.life_deck.size(), deck_before - 3, "three cards came off the top")
	eq(me.discard.size(), pile + 1, "and none of them reached the discard pile, only the card itself")
	for uid in doomed:
		eq(e.card(uid).zone, &"removed", "the card is out of the duel")
	var text: String = CardText.rules_text(lib.get_def("t_self_exile"))
	check(text.contains("Remove the top 3 cards of your Life Deck from the game"), "the rider prints: %s" % text)


## Two smaller gates the new cards lean on: "you must have an Ally in play to use this", and a
## conditional Focused that reads the keyword on the personality being attacked.
func test_a_gate_can_want_an_ally_and_a_variant_can_read_their_keyword() -> void:
	var e: DuelEngine = engine(deck(filler(["t_gate_needs_ally"], 20)), deck(filler([], 20), "pact", "", "", 3, "tf_marked_lord"))
	var me: PlayerState = e.player(0)
	var gated: CardDef = lib.get_def("t_gate_needs_ally")
	check(not e._can_play(me, gated), "no Ally, no use")
	inject(e, 0, "t_ally_free")
	check(e._can_play(me, gated), "with an Ally on the table it is legal")
	check(CardText.rules_text(gated).contains("must have an Ally in play"), "and it says so")
	check(e._cond({"defender_tag": "marked"}, 0, {}), "the personality across the table carries the keyword")
	check(not e._cond({"defender_tag": "marked"}, 1, {}), "ours does not")
	var f: DuelEngine = engine(deck(filler(["t_marked_hunter"], 20)), deck(filler(["t_guard"], 20), "pact", "", "", 3, "tf_marked_lord"))
	to_combat(f)
	if f.prompt != null and f.prompt.player != 0:
		answer(f, &"pass")   # the first-player rule handed the phase to the other side
	answer(f, &"attack", uid_in_hand(f, 0, "t_marked_hunter"))
	var guard_uid: int = uid_in_hand(f, 1, "t_guard")
	check(guard_uid >= 0, "the defender is holding a Guard")
	check(f.prompt == null or f.prompt.find(&"defend", guard_uid) == null,
		"the attack is Focused against a Marked duelist, so a Guard cannot stop it")
	# The control: the same Strike against a duelist without the keyword is not Focused.
	var g: DuelEngine = engine(deck(filler(["t_marked_hunter"], 20)), deck(filler(["t_guard"], 20), "pact"))
	to_combat(g)
	if g.prompt != null and g.prompt.player != 0:
		answer(g, &"pass")
	answer(g, &"attack", uid_in_hand(g, 0, "t_marked_hunter"))
	eq(prompt_kind(g), &"defense", "an unmarked duelist gets the defence window")
	check(g.prompt.find(&"defend", uid_in_hand(g, 1, "t_guard")) != null, "and the Guard may stop it")


# --- The Storm and Root expansion -----------------------------------------
# These drive real shipped cards rather than fixtures, so what they assert is what a player meets.

var _shipped_lib: CardLibrary = null
var _shipped_table: StrikeTable = null


func shipped() -> CardLibrary:
	if _shipped_lib == null:
		_shipped_lib = shipped_library()
	return _shipped_lib


## A deck of real cards. `root_timber_blow` is the padding: a plain Strike with no rider, there
## only so neither deck runs dry, and never the card under test.
func real_deck(cards: Array[String], alignment: String = "vigil", style: String = "", duelist_id: String = "Osric Thornwald") -> DeckList:
	var out: Array[String] = cards.duplicate()
	for i in range(24):
		out.append("root_strike_04")
	return deck(out, alignment, style, "", 3, duelist_id)


func real_engine(a: DeckList, b: DeckList, seed_value: int = 1) -> DuelEngine:
	if _shipped_table == null:
		_shipped_table = StrikeTable.load_from("res://data/strike_table.json")
	var e: DuelEngine = DuelEngine.new()
	e.shuffle_decks = false
	var decks: Array[DeckList] = [a, b]
	e.setup(decks, shipped(), _shipped_table, seed_value)
	vigil_opens(e, a, b)
	e.start()
	return e


func real_to_hand(e: DuelEngine, player: int, id: String) -> CardInstance:
	var c: CardInstance = e._instance(shipped().get_def(id), player, &"hand")
	e.player(player).hand.append(c)
	return c


func real_to_deck(e: DuelEngine, player: int, id: String) -> CardInstance:
	var c: CardInstance = e._instance(shipped().get_def(id), player, &"life_deck")
	e.player(player).life_deck.append(c)
	return c


func real_inject(e: DuelEngine, player: int, id: String) -> CardInstance:
	var c: CardInstance = e._instance(shipped().get_def(id), player, &"in_play")
	e.player(player).in_play.append(c)
	return c


## From the first prompt of a turn to `who`'s attack phase, whichever side the bracket made active.
func to_attack(e: DuelEngine, who: int) -> void:
	var guard: int = 0
	while e.prompt != null and not e.is_over() and guard < 16:
		guard += 1
		if e.prompt.kind == &"attack_action" and e.prompt.player == who:
			return
		var quiet: Command = null
		for t in [&"done", &"declare", &"decline", &"pass"]:
			quiet = e.prompt.find(t)
			if quiet != null:
				break
		if quiet == null:
			return
		e.submit(quiet)


## Every id the expansion added is in the shipped library, under the school and type it carries.
func test_the_expansion_cards_are_in_the_shipped_library() -> void:
	var storm_types: Dictionary = {
		"storm_strike_04": "strike", "storm_strike_05": "strike", "storm_art_11": "art",
		"storm_noncombat_01": "non_combat", "storm_drill_01": "drill",
		"storm_drill_02": "drill", "storm_drill_03": "drill",
		"storm_drill_04": "drill", "storm_noncombat_02": "non_combat",
		"storm_combat_01": "combat", "storm_combat_02": "combat",
		"storm_art_12": "art", "storm_strike_06": "strike", "storm_strike_07": "strike",
		"storm_strike_08": "strike", "storm_art_13": "art", "storm_art_14": "art",
		"storm_art_15": "art", "storm_strike_09": "strike", "storm_art_16": "art",
		"storm_strike_10": "strike", "storm_art_21": "art", "storm_strike_11": "strike",
		"storm_strike_12": "strike", "storm_art_22": "art", "storm_art_23": "art"}
	var root_types: Dictionary = {
		"root_drill_02": "drill", "root_drill_03": "drill", "root_drill_04": "drill",
		"root_noncombat_01": "non_combat", "root_noncombat_02": "non_combat",
		"root_strike_03": "strike", "root_strike_04": "strike", "root_strike_05": "strike",
		"root_strike_06": "strike", "root_strike_07": "strike", "root_strike_08": "strike",
		"root_strike_09": "strike", "root_strike_10": "strike", "root_strike_11": "strike",
		"root_strike_12": "strike", "root_strike_13": "strike", "root_strike_14": "strike",
		"root_strike_15": "strike", "root_strike_16": "strike", "root_combat_03": "combat",
		"root_combat_04": "combat", "root_combat_05": "combat", "root_combat_06": "combat",
		"root_art_05": "art", "root_art_06": "art", "root_art_07": "art",
		"root_art_08": "art", "root_art_09": "art", "root_art_10": "art"}
	var root2_types: Dictionary = {
		"root_strike_17": "strike", "root_strike_18": "strike", "root_strike_19": "strike",
		"root_art_11": "art", "root_art_12": "art", "root_drill_05": "drill", "root_drill_06": "drill",
		"root_combat_07": "combat", "root_combat_08": "combat", "root_noncombat_03": "non_combat",
		"root_noncombat_04": "non_combat", "root_noncombat_05": "non_combat",
		"root_mastery_02": "mastery", "root_mastery_03": "mastery", "root_mastery_04": "mastery"}
	eq(root2_types.size(), 15, "12 more Root cards and 3 Root Masteries were approved")
	root_types.merge(root2_types)
	var storm2_types: Dictionary = {
		"storm_drill_05": "drill", "storm_drill_06": "drill", "storm_drill_07": "drill", "storm_drill_08": "drill",
		"storm_strike_13": "strike", "storm_strike_14": "strike", "storm_art_24": "art",
		"storm_mastery_03": "mastery", "storm_mastery_04": "mastery"}
	eq(storm2_types.size(), 9, "7 more Storm cards and 2 Storm Masteries were approved")
	storm_types.merge(storm2_types)
	var pyre_types: Dictionary = {}
	for n in range(22, 29):
		pyre_types["pyre_strike_%d" % n] = "strike"
	for n in range(4, 12):
		pyre_types["pyre_art_%02d" % n] = "art"
	for n in range(1, 9):
		pyre_types["pyre_drill_%02d" % n] = "drill"
	for id in ["pyre_combat_02", "pyre_combat_03"]:
		pyre_types[id] = "combat"
	for id in ["pyre_mastery_03", "pyre_mastery_04"]:
		pyre_types[id] = "mastery"
	eq(storm_types.size(), 35, "26 Storm cards, then 9 more, were approved")
	eq(root_types.size(), 44, "29 Root cards, then 15 more, were approved")
	eq(pyre_types.size(), 27, "25 Pyre cards and 2 Pyre Masteries were approved")
	var steel_types: Dictionary = {}
	for n in range(23, 29):
		steel_types["steel_strike_%d" % n] = "strike"
	for n in range(7, 15):
		steel_types["steel_art_%02d" % n] = "art"
	for n in range(2, 5):
		steel_types["steel_drill_%02d" % n] = "drill"
		steel_types["steel_mastery_%02d" % n] = "mastery"
	for id in ["steel_noncombat_01", "steel_noncombat_02"]:
		steel_types[id] = "non_combat"
	steel_types["steel_combat_02"] = "combat"
	eq(steel_types.size(), 23, "20 Steel cards and 3 Steel Masteries were approved")
	var tide_types: Dictionary = {}
	for n in range(15, 22):
		tide_types["tide_strike_%d" % n] = "strike"
	for n in range(13, 16):
		tide_types["tide_art_%02d" % n] = "art"
	for n in range(1, 7):
		tide_types["tide_drill_%02d" % n] = "drill"
	for n in range(2, 5):
		tide_types["tide_noncombat_%02d" % n] = "non_combat"
		tide_types["tide_combat_%02d" % n] = "combat"
	for id in ["tide_mastery_03", "tide_mastery_04"]:
		tide_types[id] = "mastery"
	eq(tide_types.size(), 24, "22 Tide cards and 2 Tide Masteries were approved")
	var shade_types: Dictionary = {}
	for n in range(16, 24):
		shade_types["shade_strike_%d" % n] = "strike"
	for id in ["shade_art_12", "shade_art_13"]:
		shade_types[id] = "art"
	for n in range(2, 6):
		shade_types["shade_combat_%02d" % n] = "combat"
	for n in range(4, 8):
		shade_types["shade_drill_%02d" % n] = "drill"
	for id in ["shade_noncombat_01", "shade_noncombat_02"]:
		shade_types[id] = "non_combat"
	for n in range(2, 5):
		shade_types["shade_mastery_%02d" % n] = "mastery"
	eq(shade_types.size(), 23, "20 Shade cards and 3 Shade Masteries were approved")
	var by_school: Dictionary = {"storm": storm_types, "root": root_types, "pyre": pyre_types, "steel": steel_types, "tide": tide_types, "shade": shade_types}
	for school in by_school.keys():
		var wanted: Dictionary = by_school[school]
		for id in wanted.keys():
			var def: CardDef = shipped().get_def(str(id))
			check(def != null, "%s is in the shipped library" % id)
			if def == null:
				continue
			eq(def.school, school, "%s carries its school" % id)
			eq(def.type, int(CardDef.TYPE_NAMES[str(wanted[id])]), "%s is a %s card" % [id, wanted[id]])
			check(CardText.rules_text(def) != "" or def.type == CardDef.Type.DRILL, "%s prints something" % id)
	# 397 before the personality split; the 27 stack cards became 62 one-Aspect cards. The Pyre
	# expansion added 27, Steel 23, Tide 24, Shade 23, the second Root batch 15, Storm 9, and three
	# banned cards came in as adventure bombs. The Storm Sensei sheet added 11 cards and 7
	# personality cards (a four-Aspect duelist and three Allies).
	eq(shipped().defs.size(), 580, "and the set is 511 other cards plus 69 personality cards")


## The school's plain Strike answers. One is printed in the Art band and still stops a Strike,
## which is how the band and the stop are read apart.
func test_the_storm_strike_answers_stop_a_strike() -> void:
	var e: DuelEngine = real_engine(real_deck([], "pact"), real_deck([], "vigil", "storm"))
	var gust: CardInstance = real_to_hand(e, 1, "storm_strike_04")
	var damp: CardInstance = real_to_hand(e, 1, "storm_art_11")
	e.player(0).fervor = 2
	to_attack(e, 0)
	answer(e, &"attack", uid_in_hand(e, 0, "root_strike_04"))
	eq(prompt_kind(e), &"defense", "the defender is offered an answer")
	check(e.prompt.find(&"defend", gust.uid) != null, "the Strike-band answer is legal")
	check(e.prompt.find(&"defend", damp.uid) != null, "so is the one printed in the Art band")
	answer(e, &"defend", gust.uid)
	check(has_event(e, &"attack_stopped"), "the Strike was stopped")
	eq(e.player(1).fervor, 1, "and the blocker's Fervor went up 1")
	eq(e.player(0).fervor, 2, "the attacker's is untouched by that one")
	var f: DuelEngine = real_engine(real_deck([], "pact"), real_deck([], "vigil", "storm"))
	var damp2: CardInstance = real_to_hand(f, 1, "storm_art_11")
	f.player(0).fervor = 2
	to_attack(f, 0)
	answer(f, &"attack", uid_in_hand(f, 0, "root_strike_04"))
	answer(f, &"defend", damp2.uid)
	check(has_event(f, &"attack_stopped"), "the Art-band answer stops the Strike too")
	eq(f.player(0).fervor, 1, "and takes a Fervor off the attacker")


## "Stops a Strike, and stop their next Strike in their next attack phase." The second stop is a
## floating one, so the card is spent and the stop is still waiting.
func test_storm_twin_earthing_stops_their_next_strike_as_well() -> void:
	var e: DuelEngine = real_engine(real_deck([], "pact"), real_deck([], "vigil", "storm"))
	var twin: CardInstance = real_to_hand(e, 1, "storm_strike_05")
	to_attack(e, 0)
	answer(e, &"attack", uid_in_hand(e, 0, "root_strike_04"))
	answer(e, &"defend", twin.uid)
	check(has_event(e, &"attack_stopped"), "the first Strike was stopped")
	eq(e.card(twin.uid).zone, &"discard", "the card itself is spent")
	answer(e, &"pass")
	var deck_before: int = e.player(1).life_deck.size()
	var energy_before: int = e.player(1).duelist.energy
	answer(e, &"attack", uid_in_hand(e, 0, "root_strike_04"))
	eq(e.player(1).life_deck.size(), deck_before, "their next Strike is stopped with no card spent")
	check(has_event(e, &"floating_stop"), "the standing effect is what stopped it")
	check(e.player(1).duelist.energy >= energy_before, "and it cost the defender no Energy either")


## Two Drills, one for each attack kind, each answering the first unstopped attack of its kind.
func test_the_expansion_shield_drills_take_one_attack_of_their_kind() -> void:
	for pair in [["storm_drill_01", "root_strike_04"], ["root_drill_02", "root_strike_04"]]:
		var e: DuelEngine = real_engine(real_deck([], "pact"), real_deck([], "vigil", "root"))
		real_inject(e, 1, str(pair[0]))
		to_attack(e, 0)
		var before: int = e.player(1).duelist.energy
		answer(e, &"attack", uid_in_hand(e, 0, str(pair[1])))
		check(has_event(e, &"shield"), "%s fired against the Strike" % pair[0])
		eq(e.player(1).duelist.energy, before, "nothing landed")
	# The Art shields answer an Art and leave a Strike alone.
	var f: DuelEngine = real_engine(real_deck(["storm_art_22"], "pact"), real_deck([], "vigil", "root"))
	real_inject(f, 1, "root_drill_03")
	to_attack(f, 0)
	answer(f, &"attack", uid_in_hand(f, 0, "root_strike_04"))
	check(not has_event(f, &"shield"), "the Art shield does not answer a Strike")


## `scope: "cost"` on a Drill against a printed cost of 0 on a card: the two ends of the band.
func test_storm_conduit_drill_and_idle_spark_move_what_an_art_costs() -> void:
	var e: DuelEngine = real_engine(real_deck(["storm_art_14"], "pact", "storm"), real_deck([], "vigil"))
	var me: PlayerState = e.player(0)
	var plain: Dictionary = shipped().get_def("storm_art_22").attack
	eq(e._cost_stages(plain, me), 2, "an Art costs 2 to start with")
	eq(e._cost_stages(shipped().get_def("storm_art_14").attack, me), 0, "the free Art costs nothing")
	real_inject(e, 0, "storm_drill_04")
	eq(e._cost_stages(plain, me), 1, "the Drill takes an Art from 2 to 1")
	eq(e._cost_stages(shipped().get_def("root_strike_04").attack, me), 0, "and leaves Strikes alone")
	eq(e._cost_stages(plain, e.player(1)), 2, "the other side pays full price")


## "Choose 1 or 2 of your opponent's Seals in play and put them at the bottom of their Life Deck."
func test_storm_scattering_gale_puts_their_seals_under_their_deck() -> void:
	var e: DuelEngine = real_engine(real_deck(["storm_combat_01"], "pact", "storm"), real_deck([], "vigil"))
	var first: CardInstance = real_inject(e, 1, "seal_08")
	var second: CardInstance = real_inject(e, 1, "seal_09")
	to_attack(e, 0)
	answer(e, &"use", uid_in_hand(e, 0, "storm_combat_01"))
	eq(prompt_kind(e), &"pick_in_play", "the user chooses which Seals go under")
	eq(e.prompt.player, 0, "and the choice is theirs, not the owner's")
	check(e.prompt.find(&"pick_none") == null, "\"1 or 2\" takes at least one")
	eq(e.prompt.batch_min, 1, "and one alone is enough")
	check(e.submit(Command.new(0, &"pick_in_play", -1, [first.uid, second.uid])), "both go under")
	var theirs: Array[CardInstance] = e.player(1).life_deck
	eq(e.card(first.uid).zone, &"life_deck", "the Seal went to the deck, not the discard pile")
	eq(theirs[theirs.size() - 2].uid, first.uid, "the one chosen first sits above the other")
	eq(e.player(1).seals().size(), 0, "neither is in play any more")


## "Reveal your hand; if 3 or more cards in it are Storm cards, attach this to your duelist, and
## while it is there your duelist pays nothing for card effects."
func test_storm_free_current_waives_costs_for_a_storm_hand() -> void:
	# The card has to be in hand before either player prepares: the opposing player's own draw
	# comes after both preparation windows, so a card drawn for this Combat misses its window.
	var e: DuelEngine = real_engine(real_deck([], "pact", "storm"), real_deck([], "vigil"))
	var me: PlayerState = e.player(0)
	var rider: CardInstance = real_to_hand(e, 0, "storm_combat_02")
	for i in range(3):
		real_to_hand(e, 0, "storm_art_22")
	var art: Dictionary = shipped().get_def("storm_art_22").attack
	eq(e._cost_stages(art, me), 2, "an Art costs 2 to start with")
	if e.prompt != null and e.prompt.kind == &"non_combat":
		answer(e, &"done")
	answer(e, &"declare")
	while e.prompt != null and e.prompt.kind == &"follow_up" and e.prompt.player != 0:
		answer(e, &"decline")
	eq(prompt_kind(e), &"follow_up", "entering Combat opens the card's own window")
	eq(str(e.prompt.context.get("window", "")), "entering_combat", "and it is that window")
	eq(e.prompt.player, 0, "for the player holding it")
	check(e.prompt.find(&"decline") != null, "using it is optional")
	answer(e, &"use", rider.uid)
	check(has_event(e, &"hand_revealed"), "the hand was shown before it was counted")
	eq(me.attachments().size(), 1, "three school cards in hand, so it rode onto the duelist")
	eq(me.attachments()[0].attached_to, me.duelist, "onto the duelist, not the card in control")
	check(e._costs_waived(me, me.duelist), "costs other cards add are waived while it is there")
	# "You still have to pay the original cost of the card that you are using" (CRD ruling).
	e._float(1, "modifier", "combat", {"scope": "opponent_cost", "kind": "art", "stages": 2})
	eq(e._cost_stages(art, me), 2, "a tax from the other side is not paid, the Art's own 2 is")
	me.duelist.energy = 0
	check(not e._can_pay(me.duelist, me, art), "so an Art is not free")
	var ally: CardInstance = real_inject(e, 0, _an_ally_id())
	check(not e._costs_waived(me, ally), "an Ally still pays its own")
	skip_to_turn(e, 3)
	eq(me.attachments().size(), 1, "and it stays after Combat")
	# A hand short of the school leaves it with nothing to do.
	var f: DuelEngine = real_engine(real_deck([], "pact", "storm"), real_deck([], "vigil"))
	var lone: CardInstance = real_to_hand(f, 0, "storm_combat_02")
	if f.prompt != null and f.prompt.kind == &"non_combat":
		answer(f, &"done")
	answer(f, &"declare")
	while f.prompt != null and f.prompt.kind == &"follow_up" and f.prompt.player != 0:
		answer(f, &"decline")
	answer(f, &"use", lone.uid)
	check(has_event(f, &"hand_revealed"), "the hand was still shown")
	eq(f.player(0).attachments().size(), 0, "but a hand without the school attaches nothing")
	eq(f._cost_stages(shipped().get_def("storm_art_22").attack, f.player(0)), 2, "so an Art still costs 2")


## "Use only after you have taken 5 or more wounds from a single attack this Combat. Search your
## discard pile for up to 3 Allies and put them into play at full Energy."
func test_storm_mustering_peal_waits_for_a_five_wound_hit() -> void:
	var e: DuelEngine = real_engine(real_deck(["root_art_09"], "pact"), real_deck([], "vigil", "storm"))
	var peal: CardDef = shipped().get_def("storm_noncombat_02")
	var them: PlayerState = e.player(1)
	real_to_hand(e, 1, "storm_noncombat_02")
	check(not e._can_play(them, peal), "nothing has landed yet, so the card cannot be used")
	to_attack(e, 0)
	answer(e, &"attack", uid_in_hand(e, 0, "root_art_09"))
	settle(e, 8)
	check(them.worst_wound_combat >= 5, "the hit is remembered as %d wounds" % them.worst_wound_combat)
	check(e._can_play(them, peal), "and now the card may be used")
	check(CardText.rules_text(peal).contains("5 or more wounds from a single attack this Combat"),
		"the gate prints: %s" % CardText.rules_text(peal))


## "Name a card that can perform a Strike. Search their Life Deck for every copy and discard them."
func test_storm_silencing_static_names_a_strike_and_strips_their_deck() -> void:
	var e: DuelEngine = real_engine(real_deck(["storm_art_23"], "pact", "storm"), real_deck([], "vigil"))
	var them: PlayerState = e.player(1)
	real_to_deck(e, 1, "storm_art_22")
	to_attack(e, 0)
	var before: int = them.life_deck.size()
	answer(e, &"attack", uid_in_hand(e, 0, "storm_art_23"))
	settle(e, 8)
	eq(prompt_kind(e), &"name_card", "naming is a prompt, not an assumption")
	eq(e.prompt.player, 0, "the searcher names it")
	check(e.prompt.find(&"name_card", -1, "Root Timber Blow") != null, "a card that performs a Strike is on the list")
	check(e.prompt.find(&"name_card", -1, "Storm Cold Front") == null, "an Art is not")
	check(e.prompt.find(&"pick_none") != null, "and nothing may be named")
	answer(e, &"name_card", -1, "Root Timber Blow")
	check(them.life_deck.size() < before, "every copy came out of their deck")
	for c in them.life_deck:
		check(c.def.id != "root_strike_04", "none of them is left in the deck")
	var in_pile: int = 0
	for c in them.discard:
		if c.def.id == "root_strike_04":
			in_pile += 1
	check(in_pile > 0, "and they are in their discard pile, not out of the game")


## An attack that refills on a hit, and a Non-Combat that stops from the table and goes back under
## the Life Deck rather than to the pile.
func test_storm_return_stroke_refills_and_returning_front_goes_under_the_deck() -> void:
	var e: DuelEngine = real_engine(real_deck(["storm_strike_07"], "pact", "storm"), real_deck([], "vigil"))
	var me: PlayerState = e.player(0)
	to_attack(e, 0)
	me.duelist.energy = 1
	answer(e, &"attack", uid_in_hand(e, 0, "storm_strike_07"))
	settle(e, 8)
	eq(me.duelist.energy, CardInstance.MAX_STAGE, "a hit leaves the duelist at full Energy")
	eq(me.fervor, 1, "and the Fervor rise is not conditional on the hit")
	var f: DuelEngine = real_engine(real_deck([], "pact"), real_deck([], "vigil", "storm"))
	var front: CardInstance = real_inject(f, 1, "storm_noncombat_01")
	to_attack(f, 0)
	answer(f, &"attack", uid_in_hand(f, 0, "root_strike_04"))
	check(f.prompt != null and f.prompt.find(&"defend", front.uid) != null, "the Non-Combat can answer from the table")
	answer(f, &"defend", front.uid)
	check(has_event(f, &"attack_stopped"), "it stopped the Strike")
	eq(f.card(front.uid).zone, &"life_deck", "and went into the Life Deck, not the discard pile")
	eq(f.player(1).life_deck.back().uid, front.uid, "at the bottom of it")


## "Look at the top 2 cards of your Life Deck and put them all on top or all on the bottom."
func test_root_sightline_drill_sends_the_whole_look_to_one_end() -> void:
	var e: DuelEngine = real_engine(real_deck([], "vigil", "root"), real_deck([], "pact"))
	real_inject(e, 0, "root_drill_04")
	if e.prompt != null and e.prompt.kind == &"non_combat":
		answer(e, &"done")
	answer(e, &"declare")
	eq(prompt_kind(e), &"pick_option", "the Drill asks which end")
	eq(str(e.prompt.context.get("purpose", "")), "look_place", "top or bottom, for the whole look")
	var looked: Array = e.prompt.context.get("library", [])
	eq(looked.size(), 2, "two cards were looked at")
	var seen_a: int = int(looked[0])
	var seen_b: int = int(looked[1])
	answer(e, &"pick_option", -1, "bottom")
	answer(e, &"pick_option", seen_b)
	var mine: Array[CardInstance] = e.player(0).life_deck
	eq(mine[mine.size() - 1].uid, seen_b, "the card placed first is the bottom card")
	eq(mine[mine.size() - 2].uid, seen_a, "and the other sits above it")
	check(not has_event(e, &"deck_shuffled"), "nothing was shuffled")


## "Look at the top 4 cards of their Life Deck, remove 1 non-Seal from the game, put the rest back."
func test_root_trail_cut_reaches_into_their_deck() -> void:
	var e: DuelEngine = real_engine(real_deck(["root_combat_05"], "vigil", "root"), real_deck([], "pact"))
	var them: PlayerState = e.player(1)
	to_attack(e, 0)
	var seal: CardInstance = e._instance(shipped().get_def("seal_08"), 1, &"life_deck")
	them.life_deck.insert(0, seal)
	var top: Array[int] = []
	for i in range(4):
		top.append(them.life_deck[i].uid)
	answer(e, &"use", uid_in_hand(e, 0, "root_combat_05"))
	eq(prompt_kind(e), &"pick_option", "the looker picks what goes")
	eq(e.prompt.player, 0, "and it is the looker's pick, not the owner's")
	check(e.prompt.find(&"pick_none") == null, "\"Remove 1\" is not a may")
	check(e.prompt.find(&"pick_option", seal.uid) == null, "a Seal is never a legal pick")
	eq((e.prompt.context.get("library", []) as Array).size(), 4, "all four are shown to the looker")
	check(SeatView.of(e, 1).card(top[3]).hidden(), "the owner sees none of it")
	var gone: int = top[1]
	answer(e, &"pick_option", gone)
	eq(e.card(gone).zone, &"removed", "the picked card left the game")


## "Whenever you take damage from one of your opponent's attacks, you may place this card directly
## into play from your hand. You can only use it during your Attacker Attacks phase ... to make your
## opponent discard the top 3 cards of his Life Deck" (CRD errata to Namekian Finishing Effort).
func test_root_thorn_hedge_goes_into_play_when_hit_and_is_used_later() -> void:
	var e: DuelEngine = real_engine(real_deck(["root_strike_05"], "pact"), real_deck([], "vigil", "root"))
	var hedge: CardInstance = real_to_hand(e, 1, "root_noncombat_02")
	to_attack(e, 0)
	var attacker_deck: int = e.player(0).life_deck.size()
	answer(e, &"attack", uid_in_hand(e, 0, "root_strike_05"))
	settle(e, 8, [&"no_defense", &"no_endure", &"target"])
	eq(prompt_kind(e), &"follow_up", "the player who was hit gets a window")
	eq(e.prompt.player, 1, "it belongs to the defender, not the attacker")
	eq(str(e.prompt.context.get("window", "")), "after_damage", "and it is that window")
	check(e.prompt.find(&"use", hedge.uid, "place") != null, "the card may be put into play from hand")
	answer(e, &"use", hedge.uid, "place")
	eq(e.card(hedge.uid).zone, &"in_play", "it went onto the table")
	eq(e.player(0).life_deck.size(), attacker_deck, "and did nothing yet")
	e.prompts.clear()
	e._use_card(e.player(1), hedge, false)
	e._drain()
	eq(e.player(0).life_deck.size(), attacker_deck - 3, "used later, the attacker loses the top 3")


## "If performed against a Marked duelist, this attack is Focused." The keyword is read off the
## personality being attacked, not off the attacker.
func test_root_quickening_is_focused_against_a_marked_duelist() -> void:
	var e: DuelEngine = real_engine(real_deck(["root_strike_10"], "vigil", "root"),
		real_deck([], "pact", "", "Bram Ashmark"))
	check(e._cond({"defender_tag": "marked"}, 0, {}), "the personality across the table carries the keyword")
	check(not e._cond({"defender_tag": "marked"}, 1, {}), "ours does not")
	# A stop that answers either kind is the one Focused shuts out; a stop that names the kind
	# still works, which is the game's rule and not this card's.
	var any_stop: CardInstance = real_to_hand(e, 1, "steel_strike_03")
	var kind_stop: CardInstance = real_to_hand(e, 1, "root_strike_15")
	to_attack(e, 0)
	var before: int = e.player(0).duelist.energy
	answer(e, &"attack", uid_in_hand(e, 0, "root_strike_10"))
	eq(prompt_kind(e), &"defense", "the defence window still opens")
	check(e.prompt.find(&"defend", any_stop.uid) == null,
		"the attack is Focused against a Marked duelist, so the universal stop cannot answer it")
	check(e.prompt.find(&"defend", kind_stop.uid) != null, "a stop that names Strikes still can")
	settle(e, 8)
	eq(e.player(0).duelist.energy, mini(CardInstance.MAX_STAGE, before + 4), "and the attacker gained 4 Energy")
	# The control: the same Strike against an unmarked duelist is not Focused.
	var g: DuelEngine = real_engine(real_deck(["root_strike_10"], "vigil", "root"), real_deck([], "pact"))
	var open_stop: CardInstance = real_to_hand(g, 1, "steel_strike_03")
	to_attack(g, 0)
	answer(g, &"attack", uid_in_hand(g, 0, "root_strike_10"))
	eq(prompt_kind(g), &"defense", "an unmarked duelist gets the defence window")
	check(g.prompt.find(&"defend", open_stop.uid) != null, "and the universal stop may answer it")


## "You must have an Ally in play to use this card. They discard all their Non-Combat cards."
func test_root_kin_clearing_needs_an_ally_before_it_clears_the_table() -> void:
	var e: DuelEngine = real_engine(real_deck(["root_combat_06"], "vigil", "root"), real_deck([], "pact"))
	var me: PlayerState = e.player(0)
	var gated: CardDef = shipped().get_def("root_combat_06")
	eq(gated.limit_per_deck, 1, "the printed limit is carried")
	check(not e._can_play(me, gated), "no Ally, no use")
	real_inject(e, 1, "root_drill_03")
	real_inject(e, 1, "storm_drill_03")
	real_inject(e, 0, "personality_52")
	check(e._can_play(me, gated), "with an Ally on the table it is legal")
	to_attack(e, 0)
	answer(e, &"use", uid_in_hand(e, 0, "root_combat_06"))
	eq(e.player(1).drills().size(), 0, "every standing card of theirs went")
	check(CardText.rules_text(gated).contains("must have an Ally in play"), "and the card says so")


## The 10-wound finisher: it exiles the top of your own Life Deck when it lands, and costs you the
## hand when it is stopped.
func test_root_old_growth_spends_your_own_deck_or_your_hand() -> void:
	var e: DuelEngine = real_engine(real_deck(["root_art_09"], "vigil", "root"), real_deck([], "pact"))
	var me: PlayerState = e.player(0)
	to_attack(e, 0)
	var doomed: Array[int] = [me.life_deck[0].uid, me.life_deck[1].uid, me.life_deck[2].uid]
	var pile: int = me.discard.size()
	var attack_uid: int = uid_in_hand(e, 0, "root_art_09")
	answer(e, &"attack", attack_uid)
	settle(e, 10)
	for uid in doomed:
		eq(e.card(uid).zone, &"removed", "a card off the top of your own deck is out of the duel")
	eq(me.discard.size(), pile, "none of them reached your discard pile")
	eq(e.card(attack_uid).zone, &"removed", "and the card itself is removed from the game after use")
	# Stopped instead: the hand goes.
	var f: DuelEngine = real_engine(real_deck(["root_art_09"], "vigil", "root"), real_deck([], "pact"))
	var block: CardInstance = real_to_hand(f, 1, "steel_strike_03")
	to_attack(f, 0)
	answer(f, &"attack", uid_in_hand(f, 0, "root_art_09"))
	check(f.prompt != null and f.prompt.find(&"defend", block.uid) != null, "the universal stop answers an Art")
	answer(f, &"defend", block.uid)
	settle(f, 8)
	eq(f.player(0).hand.size(), 0, "a stopped attack costs the attacker their whole hand")
	eq(f.card(block.uid).zone, &"discard", "and the stop went to the pile")


## "If successful, put the bottom 3 of your discard pile under your Life Deck. If stopped, remove
## 2 of them from the game." It pays whichever way the attack goes.
func test_root_scattered_seed_pays_whether_it_lands_or_not() -> void:
	var e: DuelEngine = real_engine(real_deck(["root_art_08"], "vigil", "root"), real_deck([], "pact"))
	var me: PlayerState = e.player(0)
	var oldest: Array[int] = []
	for i in range(3):
		var c: CardInstance = e._instance(shipped().get_def("root_strike_04"), 0, &"discard")
		me.discard.append(c)
		oldest.append(c.uid)
	to_attack(e, 0)
	answer(e, &"attack", uid_in_hand(e, 0, "root_art_08"))
	settle(e, 10)
	for uid in oldest:
		eq(e.card(uid).zone, &"life_deck", "the oldest three went back into the deck")
	eq(me.life_deck.back().uid, oldest[2], "under it, in order, with no shuffle")
	var f: DuelEngine = real_engine(real_deck(["root_art_08"], "vigil", "root"), real_deck([], "pact"))
	var them_block: CardInstance = real_to_hand(f, 1, "steel_strike_03")
	var burned: CardInstance = f._instance(shipped().get_def("root_strike_04"), 0, &"discard")
	f.player(0).discard.append(burned)
	var second: CardInstance = f._instance(shipped().get_def("root_strike_04"), 0, &"discard")
	f.player(0).discard.append(second)
	to_attack(f, 0)
	answer(f, &"attack", uid_in_hand(f, 0, "root_art_08"))
	answer(f, &"defend", them_block.uid)
	settle(f, 8)
	eq(f.card(second.uid).zone, &"removed", "a stop costs the seed instead")


## "This attack stays on the table to be used 2 more times this Combat."
func test_root_briar_tangle_remains_for_two_more_uses() -> void:
	var e: DuelEngine = real_engine(real_deck(["root_strike_09"], "vigil", "root"), real_deck([], "pact"))
	to_attack(e, 0)
	var uid: int = uid_in_hand(e, 0, "root_strike_09")
	answer(e, &"attack", uid)
	settle(e, 8)
	eq(e.card(uid).zone, &"in_play", "the card stays on the table")
	eq(e.card(uid).remain, 2, "with two more uses")
	answer(e, &"pass")
	answer(e, &"attack", uid)
	settle(e, 8)
	eq(e.card(uid).remain, 1, "one left after the second")
	answer(e, &"pass")
	answer(e, &"attack", uid)
	settle(e, 8)
	eq(e.card(uid).zone, &"removed", "and it is removed from the game after the third")


## Signature is a card group beside the schools, not a school and not Freestyle. A personality
## carries a `character` as its own identity and is never one; Mastery, Relic, Seal and Grounds
## carry none at all.
func test_the_card_group_tells_signature_from_freestyle() -> void:
	var shipped: CardLibrary = shipped_library()
	# id, group, is_signature, group word, the line the face prints.
	var cases: Array = [
		["pyre_strike_01", "pyre", false, "Pyre", "Pyre"],
		["freestyle_combat_01", "freestyle", false, "Freestyle", "Freestyle"],
		["signature_strike_02", "signature", true, "Signature", "Signature · Bram Ashmark"],
		["signature_strike_25", "signature", true, "Signature", "Signature · Halden Quarr · Steel"],
		["signature_strike_27", "signature", true, "Signature", "Signature · Halden Quarr · Steel"],
		["signature_strike_28", "signature", true, "Signature", "Signature · Halden Quarr · Steel"],
		# The four type groups. None of these is a school card and none is Freestyle, which is
		# what they all used to answer, so all four shared Freestyle's bronze.
		["personality_01", "personality", false, "Personality", "Personality"],
		["pyre_mastery_01", "pyre", false, "Pyre", "Pyre"],
		["relic_01", "relic", false, "Relic", "Relic"],
		["seal_01", "seal", false, "Seal", "Seal"],
		["grounds_01", "grounds", false, "Grounds", "Grounds"],
	]
	for row: Array in cases:
		var def: CardDef = shipped.defs.get(str(row[0]))
		check(def != null, "'%s' is in the shipped library" % str(row[0]))
		if def == null:
			continue
		eq(def.card_group(), str(row[1]), "'%s' groups as %s" % [def.id, str(row[1])])
		eq(def.is_signature(), bool(row[2]), "'%s' signature flag" % def.id)
		eq(CardText.card_group_name(def), str(row[3]), "'%s' group word" % def.id)
		eq(CardText.card_group_line(def), str(row[4]), "'%s' prints its group line" % def.id)
	# The three schooled Signature cards are Signature for identity and still Steel for legality.
	for id in ["signature_strike_25", "signature_strike_27", "signature_strike_28"]:
		var quarr: CardDef = shipped.defs.get(id)
		check(quarr != null, "'%s' is in the shipped library" % id)
		if quarr == null:
			continue
		eq(quarr.school, "steel", "'%s' keeps its school for DeckValidator" % id)
		eq(quarr.card_group(), "signature", "'%s' groups as Signature all the same" % id)
	eq(CardText.group_name("signature"), "Signature", "the group word for signature")
	eq(CardText.group_name("freestyle"), "Freestyle", "the group word for freestyle")
	eq(CardText.group_name(""), "Freestyle", "an empty school is still Freestyle")


## Every shipped card lands in exactly one group, and the tally is printed for reference.
func test_every_shipped_card_lands_in_one_group() -> void:
	var shipped: CardLibrary = shipped_library()
	var groups: Array[String] = ["freestyle", "signature", "pyre", "tide", "storm", "shade", "steel", "root",
		"personality", "relic", "seal", "grounds"]
	var counts: Dictionary = {}
	var signature_types: Dictionary = {}
	for id: String in shipped.defs.keys():
		var def: CardDef = shipped.defs[id]
		var group: String = def.card_group()
		check(groups.has(group), "'%s' lands in a known group, got '%s'" % [id, group])
		check(not (def.is_signature() and group != "signature"), "'%s' is in one group only" % id)
		check(not (group == "signature" and not def.is_signature()), "'%s' is in one group only" % id)
		check(not (def.is_signature() and def.is_personality()), "'%s': a personality is not a Signature card" % id)
		counts[group] = int(counts.get(group, 0)) + 1
		if def.is_signature():
			signature_types[CardText.type_label(def)] = int(signature_types.get(CardText.type_label(def), 0)) + 1
	var tally: PackedStringArray = PackedStringArray()
	for group in groups:
		tally.append("%s %d" % [group, int(counts.get(group, 0))])
	print("    card groups: %s" % ", ".join(tally))
	var kinds: PackedStringArray = PackedStringArray()
	for kind in signature_types.keys():
		kinds.append("%s %d" % [str(kind), int(signature_types[kind])])
	kinds.sort()
	print("    signature types: %s" % ", ".join(kinds))
	check(int(counts.get("signature", 0)) > 0, "the shipped library holds Signature cards")
	for banned in ["Mastery", "Relic", "Seal", "Grounds", "Personality"]:
		check(not signature_types.has(banned), "no %s card is a Signature card" % banned)


# --- Personality stacks ---------------------------------------------------
# Each Aspect is its own card (2026-09-21). A stack is one character's cards, exactly one per
# tier, consecutive from Aspect 1; the deck names the Duelist's, and any other personality in the
# Life Deck fights as an Ally.

## A legal fixture deck with its Duelist stack swapped, so a validator check sees only the
## problem it is about.
func stack_deck(ids: Array[String], extra: Array[String] = []) -> DeckList:
	var d: DeckList = DeckList.load_from(DECK_PATH)
	d.set_duelist(ids)
	# The fixture deck ships with one Ally of its own; a test that names its own following drops
	# it, and `extra` makes the size back up.
	if not extra.is_empty():
		var kept: Array[String] = []
		for id in d.cards:
			if not (lib.get_def(id) as CardDef).is_personality():
				kept.append(id)
		d.cards = kept
	d.cards.append_array(extra)
	while d.total_cards() < DeckValidator.MIN_CARDS:
		d.cards.append("t_noncombat_draw")
	return d


## The two anchors, and what a deck is refused for when it breaks one.
func test_a_duelist_stack_is_one_character_consecutive_from_aspect_one() -> void:
	var good: DeckList = stack_deck(["t_climber_1", "t_climber_2_ashen", "t_climber_3_tidal"])
	eq(DeckValidator.validate(good, lib), [] as Array[String], "one card per tier from 1 is legal")
	var stack: PersonalityStack = good.duelist_stack(lib)
	eq(stack.size(), 3, "the stack assembles three Aspects")
	eq(stack.lowest_aspect(), 1, "from Aspect 1")
	eq(stack.highest_aspect(), 3, "to Aspect 3")
	eq(stack.def_for(2).id, "t_climber_2_ashen", "and Aspect 2 is the card the deck named")
	eq(stack.card_ids(), ["t_climber_1", "t_climber_2_ashen", "t_climber_3_tidal"], "the ladder reads in tier order")
	eq(good.aspects, 3, "the deck's aspect count is derived from the list")
	eq(good.duelist_face_id(), "t_climber_1", "and the face is the first Aspect")

	var mixed: Array[String] = DeckValidator.validate(
		stack_deck(["t_climber_1", "t_climber_2_ashen", "t_rival_1"]), lib)
	check(str(mixed).contains("is Test Rival, not Test Climber"), "a card of another character is refused")

	var gap: Array[String] = DeckValidator.validate(
		stack_deck(["t_climber_1", "t_climber_3_tidal", "t_rival_1"]), lib)
	check(str(gap).contains("missing Aspect 2"), "a gap in the tiers is refused")

	var doubled: Array[String] = DeckValidator.validate(
		stack_deck(["t_climber_1", "t_climber_2_ashen", "t_climber_2_brined"]), lib)
	check(str(doubled).contains("two cards at Aspect 2"), "two cards of one tier are refused")

	var headless: Array[String] = DeckValidator.validate(
		stack_deck(["t_climber_2_ashen", "t_climber_3_tidal"]), lib)
	check(str(headless).contains("missing Aspect 1"),
		"and a stack that does not start at Aspect 1 is refused")

	check(str(DeckValidator.validate(stack_deck([]), lib)).contains("names no Duelist cards"),
		"so is a deck with none")

	var gated: Array[String] = DeckValidator.validate(
		stack_deck(["t_climber_1", "t_climber_2_ashen", "t_climber_3_cinder"]), lib)
	check(str(gated).contains("does not match alignment vigil"),
		"a Duelist card's own alignment gate is read")


## Bram Ashmark may climb Starved, Leeching, Gorging. The cards of one character mix freely, and
## everything the engine reads off the Duelist is the current card's.
func test_a_duelist_may_mix_two_printed_lines_of_one_character() -> void:
	var d: DeckList = stack_deck(["t_climber_1", "t_climber_2_ashen", "t_climber_3_tidal"])
	eq(DeckValidator.validate(d, lib), [] as Array[String], "one rung off each road is a legal stack")
	var e: DuelEngine = engine(d, deck(filler(), "pact"))
	var me: PlayerState = e.player(0)
	eq(me.highest_aspect, 3, "the deck's height is the stack's")
	eq(me.duelist.def.id, "t_climber_1", "the duel opens on Aspect 1")
	eq(int(me.duelist.power().get("attack", {}).get("stages", 0)), 1, "with Aspect 1's Power")
	check(not e.has_tag(me.duelist, "marked"), "Aspect 1 carries no keyword")
	eq(e.bloodline_of(me.duelist), "", "and no bloodline")

	e._aspect_up(me)
	eq(me.duelist.aspect, 2, "Ascension raises the Aspect")
	eq(me.duelist.def.id, "t_climber_2_ashen", "and moves to that Aspect's own card")
	eq(int(me.duelist.power().get("attack", {}).get("stages", 0)), 2, "the Power is the new card's")
	eq(int((me.duelist.aspect_data().get("constant", {}) as Dictionary).get("strike_table_self", 0)), 2,
		"so is the Constant")
	eq(me.duelist.surge(), 2, "so is the Surge Rate")
	check(e.has_tag(me.duelist, "marked"), "the keywords follow the card")
	eq(e.bloodline_of(me.duelist), "draconic", "so does the bloodline")

	e._aspect_up(me)
	eq(me.duelist.def.id, "t_climber_3_tidal", "the third rung is the other line's card")
	check(not e.has_tag(me.duelist, "marked"), "and its keywords replace the last card's")
	eq(e.bloodline_of(me.duelist), "", "as does its bloodline")
	eq(int((me.duelist.aspect_data().get("constant", {}) as Dictionary).get("strike_table_against", 0)), 1,
		"with its own Constant in force")
	e._lose_aspect(me, 0)
	eq(me.duelist.def.id, "t_climber_2_ashen", "falling back moves to the card below")
	eq(me.duelist.energy, DuelEngine.LOST_ASPECT_ENERGY, "at the rulebook's Energy")


## Most Powerful Personality reads what each side announced, which is now the length of each
## deck's Duelist list.
func test_mppv_reads_the_announced_ladders_off_the_deck_lists() -> void:
	var tall: DeckList = deck(filler(), "vigil", "", "t_mastery_pyre", 5, "tf_titan")
	var short: DeckList = deck(filler(), "pact", "", "", 3, "tf_vigil")
	var e: DuelEngine = engine(tall, short)
	eq(e.player(0).highest_aspect, 5, "five Aspects announced")
	eq(e.player(1).highest_aspect, 3, "against three")
	eq(e.mppv_aspect(e.player(0)), 4, "so Aspect 4 stands above their whole ladder")
	eq(e.mppv_aspect(e.player(1)), 0, "and the shorter ladder has no such Aspect")
	var level: DuelEngine = engine(deck(filler(), "vigil", "", "t_mastery_pyre", 3, "tf_vigil"),
		deck(filler(), "pact", "", "", 3, "tf_vigil"))
	eq(level.mppv_aspect(level.player(0)), 0, "level ladders leave the Fervor road only")


## An Ally is a personality card in the Life Deck at Aspect 1, 2 or 3, whatever height the Duelist
## runs. Its Aspects need not be consecutive and need not include Aspect 1: that is a Duelist rule.
func test_an_ally_in_the_deck_is_any_aspect_one_to_three() -> void:
	var three: Array[String] = ["tf_vigil_1", "tf_vigil_2", "tf_vigil_3"]
	eq(DeckValidator.validate(stack_deck(three, ["t_ally_squire"]), lib), [] as Array[String],
		"an Aspect 1 Ally is legal")
	eq(DeckValidator.validate(stack_deck(three, ["t_ally_squire_3"]), lib), [] as Array[String],
		"so is an Aspect 3 Ally under a three-Aspect Duelist, which the old gap rule refused")
	check(str(DeckValidator.validate(stack_deck(three, ["t_ally_squire_4"]), lib))
		.contains("an Ally may be Aspect 1 to 3"), "Aspect 4 is past the ceiling")
	eq(DeckValidator.validate(stack_deck(three, ["t_ally_squire_2"]), lib), [] as Array[String],
		"a lone Aspect 2 Ally is legal with no Aspect 1 of that character in the deck")
	eq(DeckValidator.validate(stack_deck(three, ["t_ally_squire_2", "t_ally_squire_3"]), lib), [] as Array[String],
		"and an Ally's Aspects need not be consecutive nor start at 1")
	eq(DeckValidator.validate(stack_deck(three, ["t_ally_squire", "t_ally_squire_alt"]), lib), [] as Array[String],
		"two different cards of one character at one Aspect are not copies of each other")

	check(str(DeckValidator.validate(stack_deck(three, ["t_ally_squire", "t_ally_squire"]), lib))
		.contains("exceeds limit 1"), "one copy of each personality card")
	var self_ally: DeckList = stack_deck(["t_climber_1", "t_climber_2_ashen", "t_climber_3_tidal"], ["t_climber_1"])
	check(str(DeckValidator.validate(self_ally, lib)).contains("same character as the Duelist"),
		"and none of them shares the Duelist's character")
	var wrong_side: DeckList = stack_deck(three, ["t_ally_squire"])
	wrong_side.alignment = "pact"
	check(str(DeckValidator.validate(wrong_side, lib)).contains("does not match alignment pact"),
		"an Ally's alignment gate still applies")


## Placing the next Aspect of an Ally already in play overlays it: the old card goes underneath,
## the new one is in play at full Energy, and the Ally's own stack grows by that card.
func test_an_ally_climbs_by_overlaying_its_next_aspect() -> void:
	var d: DeckList = deck(filler(), "vigil", "", "", 4, "tf_titan")
	var e: DuelEngine = engine(d, deck(filler(), "pact"))
	var me: PlayerState = e.player(0)
	var first: CardInstance = to_hand(e, 0, "t_ally_squire")
	var second: CardInstance = to_hand(e, 0, "t_ally_squire_2")
	var third: CardInstance = to_hand(e, 0, "t_ally_squire_3")
	check(e._can_place(me, first), "the Ally's first Aspect may be placed")
	check(not e._can_place(me, second), "a fresh placement is capped by the Duelist's current Aspect")
	e._place(me, first)
	eq(first.energy, DuelEngine.ALLY_STARTING_ENERGY, "an Ally enters at the rulebook's Energy")
	eq(first.ladder(), ["t_ally_squire"], "its stack is the card that was placed")
	check(not e._can_place(me, third), "an Ally climbs one Aspect at a time, never skipping one")
	check(e._can_place(me, second), "the next Aspect may be placed on top, uncapped")
	e._place(me, second)
	eq(second.aspect, 2, "the Ally is at its second Aspect")
	eq(second.def.id, "t_ally_squire_2", "showing that Aspect's card")
	eq(second.energy, CardInstance.MAX_STAGE, "set to its highest stage")
	eq(second.cards_under.size(), 1, "with the old card under it")
	eq(first.zone, &"under", "which has left play")
	eq(second.ladder(), ["t_ally_squire", "t_ally_squire_2"], "and the stack carries both cards")
	eq(me.allies().size(), 1, "one Ally on the table, not two")
	eq(me.duelist.aspect, 1, "the Duelist never moved")
	# Climbing is uncapped, so the Ally may pass the Duelist, and the pile stays flat.
	check(e._can_place(me, third), "the third Aspect goes on next, above the Duelist's own")
	e._place(me, third)
	eq(third.aspect, 3, "the Ally now stands above the Duelist")
	eq(third.cards_under.size(), 2, "with both lower Aspects under it, in one flat pile")
	eq(third.ladder(), ["t_ally_squire", "t_ally_squire_2", "t_ally_squire_3"], "and a three-card stack")
	eq(me.allies().size(), 1, "still one Ally")
	# A second card of the same character is not a second Ally, whatever Aspect it is.
	var twin: CardInstance = to_hand(e, 0, "t_ally_squire_alt")
	check(not e._can_place(me, twin), "a second personality card of one character is not a second Ally")


## An Ally is unique to its controller, not to the table (2014 relaunch rule, adopted 2026-09-21):
## both players may field the same character, the same Aspect, even the same card, at once. One
## player still gets only one Ally per character.
func test_both_players_may_field_the_same_ally() -> void:
	var e: DuelEngine = engine(deck(filler(), "vigil", "", "", 4, "tf_titan"),
		deck(filler(), "vigil", "", "", 4, "tf_titan"))
	var mine: PlayerState = e.player(0)
	var theirs: PlayerState = e.player(1)
	var my_first: CardInstance = to_hand(e, 0, "t_ally_squire")
	var their_first: CardInstance = to_hand(e, 1, "t_ally_squire")
	e._place(mine, my_first)
	check(e._can_place(theirs, their_first), "the rival may field the same card at the same Aspect")
	e._place(theirs, their_first)
	eq(mine.allies().size(), 1, "one Ally on my side")
	eq(theirs.allies().size(), 1, "and one on theirs")
	eq(my_first.def.id, their_first.def.id, "the same card on both sides of the table")
	eq(my_first.aspect, their_first.aspect, "at the same Aspect")
	# One per character per player still holds, at any Aspect.
	var twin: CardInstance = to_hand(e, 0, "t_ally_squire_alt")
	check(not e._can_place(mine, twin), "but one player gets only one Ally per character")
	# Climbing is unaffected by what the rival has on the table.
	var my_second: CardInstance = to_hand(e, 0, "t_ally_squire_2")
	check(e._can_place(mine, my_second), "and may climb while the rival sits on the Aspect below")
	e._place(mine, my_second)
	eq(my_second.aspect, 2, "my Ally is at Aspect 2")
	eq(their_first.aspect, 1, "theirs is still at Aspect 1")
	var their_second: CardInstance = to_hand(e, 1, "t_ally_squire_2")
	e._aspect_up(theirs)
	check(e._can_place(theirs, their_second), "they may follow onto the Aspect I already hold")
	e._place(theirs, their_second)
	eq(mine.allies().size(), 1, "still one Ally each")
	eq(theirs.allies().size(), 1, "both now at Aspect 2")
	# "Discard one of your opponent's Allies" reads sides, not names, so it takes only their copy.
	eq(e._in_play_candidates(theirs, "ally").size(), 1, "the rival has one Ally to take")
	e._apply_effect({"op": "discard_in_play", "who": "opponent", "card_type": "ally",
		"amount": 1, "choose": false}, mine.index, {}, null)
	eq(theirs.allies().size(), 0, "their Ally went")
	eq(mine.allies().size(), 1, "mine, of the very same character, stayed")
	eq(my_second.zone, &"in_play", "and is still the one on my side of the table")


## Nothing in play reads the other side of the table, so an Ally may share a character with the
## rival's Duelist. Not sharing your own Duelist's character is a deck rule and lives there alone.
func test_an_ally_may_share_a_character_with_the_rival_duelist() -> void:
	var mine_deck: DeckList = deck(filler(), "vigil", "", "", 3, "tf_vigil")
	var theirs_deck: DeckList = deck(filler(), "vigil", "", "", 3, "tf_vigil")
	theirs_deck.set_duelist(["t_climber_1", "t_climber_2_ashen", "t_climber_3_tidal"])
	var e: DuelEngine = engine(mine_deck, theirs_deck)
	var mine: PlayerState = e.player(0)
	var theirs: PlayerState = e.player(1)
	eq(theirs.duelist.def.character, "Test Climber", "the rival leads Test Climber")
	var ally: CardInstance = to_hand(e, 0, "t_climber_1")
	check(e._can_place(mine, ally), "I may field the rival Duelist's character as my Ally")
	e._place(mine, ally)
	eq(mine.allies().size(), 1, "it is on the table")
	eq(ally.energy, DuelEngine.ALLY_STARTING_ENERGY, "at the Ally's own starting Energy")
	eq(ally.might(), (lib.get_def("t_climber_1").aspect_data(1).get("might", []) as Array)[ally.energy],
		"and plays with its own Might")
	# My deck may still not run my own Duelist's character, which is the deck rule doing the work.
	var self_ally: DeckList = stack_deck(["t_climber_1", "t_climber_2_ashen", "t_climber_3_tidal"], ["t_climber_1"])
	check(str(DeckValidator.validate(self_ally, lib)).contains("same character as the Duelist"),
		"the deck rule still refuses an Ally of my own Duelist")
	var reserved: DeckList = stack_deck(["t_climber_1", "t_climber_2_ashen", "t_climber_3_tidal"])
	reserved.relic_id = "t_relic"
	reserved.reserve = ["t_climber_1"]
	check(str(DeckValidator.validate(reserved, lib)).contains("Reserve: Ally"),
		"and refuses it in the Reserve too, which a swap would put in the Life Deck")

	# An effect aimed at the rival's Duelist finds their card, never my same-named Ally.
	var ally_before: int = ally.energy
	var rival_before: int = theirs.duelist.energy
	e._apply_effect({"op": "energy", "who": "opponent", "target": "duelist", "amount": -2},
		mine.index, {}, null)
	eq(theirs.duelist.energy, rival_before - 2, "the rival's Duelist lost the Energy")
	eq(ally.energy, ally_before, "my Ally of the same name did not")

	# A character gate reads my side only: the rival leading that character does not switch it on.
	check(e._cond({"ally_present": "Test Climber"}, 0, {}), "my own Ally satisfies the gate")
	check(not e._cond({"ally_present": "Test Climber"}, 1, {}),
		"their Duelist is not an Ally, so it does not satisfy theirs")
	check(not e._cond({"ally_present": "Test Vigil"}, 0, {}),
		"and the rival's characters never satisfy mine")
	eq(e._character_in_play(mine, "Test Climber"), ally, "'in play' for me is my Ally")
	eq(e._character_in_play(theirs, "Test Climber"), theirs.duelist, "and for them, their Duelist")


## An overlaid Ally is one thing on the table: whatever takes it out of play takes every Aspect
## under it, and they all land in the discard pile.
func test_discarding_an_overlaid_ally_takes_all_of_its_aspects() -> void:
	var e: DuelEngine = engine(deck(filler(), "vigil", "", "", 4, "tf_titan"), deck(filler(), "pact"))
	var me: PlayerState = e.player(0)
	var one: CardInstance = to_hand(e, 0, "t_ally_squire")
	var two: CardInstance = to_hand(e, 0, "t_ally_squire_2")
	var three: CardInstance = to_hand(e, 0, "t_ally_squire_3")
	e._place(me, one)
	e._place(me, two)
	e._place(me, three)
	var before: int = me.discard.size()
	e._move_to_discard(three)
	eq(me.discard.size(), before + 3, "all three Aspects went to the discard")
	for c in [one, two, three]:
		eq(c.zone, &"discard", "%s is in the discard" % c.def.id)
	# The order is fixed rather than asked for: lowest Aspect first, so the Aspect that was in
	# play ends on top of the pile, which is what "the card just discarded" means everywhere else.
	eq((me.discard[me.discard.size() - 1] as CardInstance).def.id, "t_ally_squire_3",
		"the Aspect that was in play is the top card")
	eq((me.discard[me.discard.size() - 3] as CardInstance).def.id, "t_ally_squire",
		"and Aspect 1 is the deepest of the three")
	eq(me.allies().size(), 0, "the Ally is gone from the table")
	eq(three.cards_under.size(), 0, "and carries nothing under it any more")


## Fervor climbs the Duelist and never an Ally.
func test_fervor_never_moves_an_allys_aspect() -> void:
	var e: DuelEngine = engine(deck(filler(), "vigil", "", "", 4, "tf_titan"), deck(filler(), "pact"))
	var me: PlayerState = e.player(0)
	var ally: CardInstance = to_hand(e, 0, "t_ally_squire")
	e._place(me, ally)
	me.fervor = e.fervor_needed(me)
	e._check_aspect_up(me)
	eq(me.duelist.aspect, 2, "full Fervor raised the Duelist")
	eq(ally.aspect, 1, "and left the Ally where it stood")
	eq(ally.def.id, "t_ally_squire", "still showing its own card")


## A client renders a personality from the SeatView alone: `def_id` is the card for the Aspect it
## stands at, and `ladder` is the announced stack, which is public from setup.
func test_a_seat_view_carries_the_current_aspect_card_and_the_public_ladder() -> void:
	var d: DeckList = deck(filler(["t_ally_squire"]), "vigil", "", "t_mastery_pyre")
	d.set_duelist(["t_climber_1", "t_climber_2_ashen", "t_climber_3_tidal"])
	var e: DuelEngine = engine(d, deck(filler(), "pact"))
	var me: PlayerState = e.player(0)
	var view: SeatView = SeatView.of(e, 1)
	var seen: SeatCard = view.card(me.duelist.uid)
	eq(seen.def_id, "t_climber_1", "the rival sees the card the Duelist stands at")
	eq(seen.ladder, ["t_climber_1", "t_climber_2_ashen", "t_climber_3_tidal"],
		"and the whole announced ladder, which is what MPPV is read off")
	e._aspect_up(me)
	var after: SeatCard = SeatView.of(e, 1).card(me.duelist.uid)
	eq(after.def_id, "t_climber_2_ashen", "climbing changes the card the view names")
	eq(after.aspect, 2, "and the Aspect number with it")
	eq(after.ladder.size(), 3, "the ladder does not move")
	eq(after.tags, ["marked"], "the keywords shown are the ones carried right now")
	var hidden_ally: CardInstance = to_deck(e, 0, "t_ally_squire")
	var from_rival: SeatCard = SeatView.of(e, 1).card(hidden_ally.uid)
	check(from_rival.hidden(), "a personality in the Life Deck is hidden")
	eq(from_rival.ladder, [] as Array[String], "and gives away no ladder")
	var round_trip: SeatCard = SeatCard.from_dict(after.to_dict())
	eq(round_trip.ladder, after.ladder, "the ladder survives the wire")


## The search and the network both copy engines; a stack must come through both intact.
func test_cloning_and_determinizing_keep_a_stack_whole() -> void:
	var d: DeckList = deck(filler(["t_ally_squire"]), "vigil", "", "t_mastery_pyre")
	d.set_duelist(["t_climber_1", "t_climber_2_ashen", "t_climber_3_tidal"])
	var e: DuelEngine = engine(d, deck(filler(), "pact"))
	e._aspect_up(e.player(0))
	var copy: DuelEngine = e.clone()
	eq(copy.player(0).duelist.aspect, 2, "the clone stands at the same Aspect")
	eq(copy.player(0).duelist.def.id, "t_climber_2_ashen", "showing the same card")
	eq(copy.player(0).duelist.ladder(), e.player(0).duelist.ladder(), "with the same ladder")
	eq(copy.player(0).highest_aspect, 3, "and the same announced height")
	copy.determinize(0, 77)
	eq(copy.player(0).duelist.def.id, "t_climber_2_ashen", "sampling never re-deals a Duelist")
	eq(copy.player(1).duelist.ladder().size(), 3, "nor the rival's, which is public")
	copy._aspect_up(copy.player(0))
	eq(copy.player(0).duelist.def.id, "t_climber_3_tidal", "and the sampled engine can still climb")
	eq(e.player(0).duelist.def.id, "t_climber_2_ashen", "without moving the engine it came from")


## Every shipped deck, starter and opponent file names a legal stack.
func test_every_shipped_deck_names_a_legal_duelist_stack() -> void:
	var shipped: CardLibrary = shipped_library()
	var seen: int = 0
	for dir_path in DeckList.DIRS:
		var dir: DirAccess = DirAccess.open(dir_path)
		check(dir != null, "%s is readable" % dir_path)
		if dir == null:
			continue
		for entry in dir.get_files():
			if not entry.ends_with(".json"):
				continue
			seen += 1
			var d: DeckList = DeckList.load_from("%s/%s" % [dir_path, entry])
			check(not d.duelist_ids.is_empty(), "%s names its Duelist as a list" % entry)
			eq(d.aspects, d.duelist_ids.size(), "%s: the aspect count is the list's length" % entry)
			var stack: PersonalityStack = d.duelist_stack(shipped)
			eq(stack.size(), d.duelist_ids.size(), "%s: every Aspect card resolves" % entry)
			eq(DeckValidator.validate(d, shipped), [] as Array[String], "%s validates" % entry)
	check(seen >= 110, "every shipped deck file was checked, saw %d" % seen)


## The printed ladders are converted to the compact Might scale the Strike Table is built on, one
## band per ten points. A raw printed ladder in the millions would put every duelist in band I.
func test_every_shipped_personality_is_on_the_compact_might_scale() -> void:
	var shipped: CardLibrary = shipped_library()
	var ceiling: int = 100
	var seen: int = 0
	for id: String in shipped.defs.keys():
		var def: CardDef = shipped.defs[id]
		if not def.is_personality():
			continue
		seen += 1
		var might: Array = def.aspect_data(def.aspect).get("might", [])
		eq(might.size(), 11, "%s prints eleven stages" % id)
		if might.size() != 11:
			continue
		eq(int(might[0]), 0, "%s starts at 0 Might" % id)
		var last: int = 0
		for stage in range(11):
			var value: int = int(might[stage])
			check(value <= ceiling, "%s stage %d Might %d is on the compact scale" % [id, stage, value])
			check(value >= last, "%s stage %d does not go backwards" % [id, stage])
			last = value
	check(seen >= 60, "every shipped personality was checked, saw %d" % seen)


## Gideon Mourne's ladder was pasted in on the printed million scale and converted 2026-09-21.
func test_gideon_mournes_ladder_sits_where_the_other_four_aspect_duelist_sits() -> void:
	var shipped: CardLibrary = shipped_library()
	var tops: Array[int] = [20, 26, 32, 38]
	var ids: Array[String] = ["personality_59", "personality_60",
		"personality_61", "personality_62"]
	for i in range(4):
		var def: CardDef = shipped.defs.get(ids[i])
		check(def != null, "%s is in the shipped library" % ids[i])
		if def == null:
			continue
		var might: Array = def.aspect_data(def.aspect).get("might", [])
		eq(int(might[might.size() - 1]), tops[i], "%s tops at %d" % [ids[i], tops[i]])
	var strikes: StrikeTable = StrikeTable.load_from("res://data/strike_table.json")
	var marrow: Array = shipped.get_def("personality_29").aspect_data(4).get("might", [])
	var mourne: Array = shipped.get_def("personality_62").aspect_data(4).get("might", [])
	eq(strikes.band(int(mourne[mourne.size() - 1])), strikes.band(int(marrow[marrow.size() - 1])),
		"and the two four-Aspect duelists top in the same band")


## A run carries its Duelist's cards, and the ladder's Aspect grant hands it the next one.
func test_an_adventure_run_gains_the_next_aspect_card_of_its_own_line() -> void:
	var shipped: CardLibrary = shipped_library()
	var run: AdventureRun = AdventureRun.begin("pyre_attrition_start", 31337)
	check(run != null, "the starter resolves into a run")
	if run == null:
		return
	eq(run.aspects(), 2, "a starter opens at two Aspects")
	eq(run.duelist_ids[0], "personality_01", "starting from the card both lines share")
	eq(run.duelist_ids[1], "personality_55", "and the Glut line's second rung")
	eq(run.next_tier_options(shipped), [] as Array[String], "nothing is offerable until it is owned")
	run.owned_aspects = ["personality_56", "personality_03"]
	eq(run.next_tier_options(shipped), ["personality_03", "personality_56"],
		"both of the character's owned third Aspects are offerable")
	eq(run.next_tier(shipped), "personality_56",
		"and the one picked for now stays on the line the starter was written with")
	# The Hollow line starts from the same shared Aspect 1 and climbs the other way.
	var hollow: AdventureRun = AdventureRun.begin("pyre_beatdown_start", 31337)
	hollow.owned_aspects = run.owned_aspects.duplicate()
	eq(hollow.duelist_ids[1], "personality_02", "the other starter runs the Hollow line")
	eq(hollow.next_tier(shipped), "personality_03",
		"and gains that line's third Aspect from the same pair of options")
	eq(hollow.next_tier_options(shipped), run.next_tier_options(shipped),
		"the options are the character's, not the line's")
	# The line stops at 5, and construction stops there too.
	var topped: AdventureRun = AdventureRun.begin("pyre_attrition_start", 1)
	topped.duelist_ids = ["personality_01", "personality_55",
		"personality_56", "personality_57",
		"personality_58"]
	eq(topped.next_tier_options(shipped), [] as Array[String], "a full stack has nothing left to gain")
	eq(topped.next_tier(shipped), "", "so the grant hands it nothing")


## The bundle data file, read on its own terms. Every rule here is one a reward screen would
## otherwise have to guard against at runtime.
func test_every_reward_bundle_is_well_formed() -> void:
	var shipped: CardLibrary = shipped_library()
	var bundles: Array[Dictionary] = AdventureBundles.all()
	check(bundles.size() > 100, "the bundle file loaded, saw %d" % bundles.size())
	var ids: Dictionary = {}
	for bundle in bundles:
		var id: String = str(bundle.get("id", ""))
		check(id != "", "every bundle names an id")
		check(not ids.has(id), "bundle id '%s' is unique" % id)
		ids[id] = true
		var group: String = str(bundle.get("group", ""))
		check(ADVENTURE_SCHOOL_GROUPS.has(group) or group == AdventureBundles.GROUP_FREESTYLE
			or group == AdventureBundles.GROUP_GROUNDS or group == AdventureBundles.GROUP_ALLY
			or group == AdventureBundles.GROUP_SIGNATURE, "'%s' has a known group '%s'" % [id, group])
		check(AdventureBundles.TIERS.has(str(bundle.get("tier", ""))),
			"'%s' has a known tier '%s'" % [id, str(bundle.get("tier", ""))])
		var entries: Array = bundle.get("cards", [])
		check(entries.size() >= 1 and entries.size() <= 3,
			"'%s' lists one to three card entries, saw %d" % [id, entries.size()])
		var cards: Array[String] = AdventureBundles.cards_of(bundle)
		check(cards.size() >= 2 and cards.size() <= 4,
			"'%s' holds two to four cards, saw %d" % [id, cards.size()])
		var counts: Dictionary = {}
		var schools: Dictionary = {}
		var personalities: Array[String] = []
		for card_id in cards:
			var def: CardDef = shipped.defs.get(card_id)
			check(def != null, "'%s' names a card that exists: '%s'" % [id, card_id])
			if def == null:
				continue
			counts[card_id] = int(counts.get(card_id, 0)) + 1
			check(def.type != CardDef.Type.SEAL and def.type != CardDef.Type.MASTERY
				and def.type != CardDef.Type.RELIC,
				"'%s' holds no Seal, Mastery or Relic: '%s'" % [id, card_id])
			check(not bool(def.raw.get("reserve_only", false)),
				"'%s' holds no Reserve-only card: '%s'" % [id, card_id])
			if def.school != "":
				schools[def.school] = true
			if def.type == CardDef.Type.PERSONALITY:
				personalities.append(card_id)
		for card_id in counts.keys():
			var def: CardDef = shipped.defs[card_id]
			var limit: int = 1 if def.type == CardDef.Type.PERSONALITY else def.limit_per_deck
			check(int(counts[card_id]) <= limit,
				"'%s' holds '%s' x%d, over its own limit of %d" % [id, card_id, counts[card_id], limit])
		check(schools.size() <= 1, "'%s' mixes no schools: %s" % [id, ", ".join(schools.keys())])
		if ADVENTURE_SCHOOL_GROUPS.has(group):
			eq(schools.keys(), [group], "'%s' holds %s cards only" % [id, group])
		if group == AdventureBundles.GROUP_FREESTYLE or group == AdventureBundles.GROUP_GROUNDS:
			eq(schools.size(), 0, "'%s' holds no school card" % id)
		if group == AdventureBundles.GROUP_ALLY:
			_check_ally_bundle(shipped, bundle, id, personalities, cards)
		else:
			eq(personalities.size(), 0, "'%s' holds no personality card" % id)
		if group == AdventureBundles.GROUP_SIGNATURE:
			_check_signature_bundle(shipped, bundle, id, cards, schools)


## An Ally core bundle is one personality plus exactly two cards of that character; a follow-up
## holds named cards alone and says which Ally it needs.
func _check_ally_bundle(shipped: CardLibrary, bundle: Dictionary, id: String,
		personalities: Array[String], cards: Array[String]) -> void:
	var requires: String = str(bundle.get("requires_character", ""))
	if requires != "":
		eq(personalities.size(), 0, "follow-up '%s' holds no personality" % id)
		eq(str(bundle.get("character", "")), "", "follow-up '%s' names no Ally of its own" % id)
		for card_id in cards:
			var def: CardDef = shipped.defs.get(card_id)
			if def == null:
				continue
			check(def.character == requires or _names_character(def, requires),
				"follow-up '%s': '%s' names %s" % [id, card_id, requires])
		return
	eq(personalities.size(), 1, "Ally bundle '%s' holds exactly one personality" % id)
	if personalities.is_empty():
		return
	var ally: CardDef = shipped.defs[personalities[0]]
	eq(str(bundle.get("character", "")), ally.character,
		"Ally bundle '%s' names the character it carries" % id)
	check(DeckValidator.ally_aspect_allowed(ally.aspect),
		"Ally bundle '%s' carries an Aspect %d card, which may sit in a Life Deck" % [id, ally.aspect])
	var named: int = 0
	for card_id in cards:
		if card_id == personalities[0]:
			continue
		var def: CardDef = shipped.defs.get(card_id)
		if def == null:
			continue
		check(def.character == ally.character or _names_character(def, ally.character),
			"Ally bundle '%s': '%s' is one of %s's cards" % [id, card_id, ally.character])
		named += 1
	eq(named, 2, "Ally bundle '%s' brings two of its Ally's named cards" % id)


## A signature bundle belongs to one character. Beside that character's own cards it may hold a
## schoolless card or one of the deck's own school, and nothing else.
func _check_signature_bundle(shipped: CardLibrary, bundle: Dictionary, id: String,
		cards: Array[String], schools: Dictionary) -> void:
	var character: String = str(bundle.get("character", ""))
	check(character != "", "signature bundle '%s' names a character" % id)
	var own: int = 0
	for card_id in cards:
		var def: CardDef = shipped.defs.get(card_id)
		if def == null:
			continue
		if def.character != "":
			eq(def.character, character, "signature bundle '%s': '%s' is %s's" % [id, card_id, character])
			own += 1
		else:
			check(def.school != "" or def.only.has("tag") or def.only.has("duelist_character")
				or def.school == "",
				"signature bundle '%s': '%s' is schoolless or of one school" % [id, card_id])
	check(own >= 1 or schools.size() <= 1,
		"signature bundle '%s' holds its character's cards or one school's" % id)


## Whether a card's `only` gate names a character, which is the other way a card is "named" for
## an Ally.
func _names_character(def: CardDef, character: String) -> bool:
	for key in ["character", "duelist_character"]:
		var value: Variant = def.only.get(key, null)
		if value is Array and (value as Array).has(character):
			return true
		if value != null and str(value) == character:
			return true
	return false


## An Ally arrives with two of its own cards, and its other cards only open up afterwards.
func test_an_ally_bundle_brings_its_named_cards_and_opens_the_follow_ups() -> void:
	var shipped: CardLibrary = shipped_library()
	# Siphon's run is Pact and Siphon is not Gideon Mourne, so Mourne is a legal Ally in it.
	var run: AdventureRun = AdventureRun.begin("storm_volley_start", 606)
	var core_id: String = "mourne_ally_core"
	var follow: String = "mourne_ally_answers"
	var core: Dictionary = AdventureBundles.by_id(core_id)
	var before: Array[String] = AdventureRewards.eligible(run, shipped, 0.5)
	check(before.has(core_id), "the Ally core bundle is eligible")
	check(not before.has(follow), "and its follow-up is not, with no Mourne in the deck")
	run.pending_offer = [core_id]
	check(AdventureRewards.apply_bundle(run, shipped, core_id), "the Ally bundle is taken")
	for card_id in AdventureBundles.cards_of(core):
		check(run.cards.has(card_id), "'%s' joined the run deck" % card_id)
	check(run.cards.has("personality_48"),
		"the personality goes in like any Life Deck card")
	eq(DeckValidator.validate(run.deck(), shipped).size(), 0, "and the deck is legal with the Ally in it")
	var after: Array[String] = AdventureRewards.eligible(run, shipped, 0.5)
	check(after.has(follow), "the follow-up bundle is eligible once the Ally is in the deck")
	check(not after.has(core_id), "and a bundle already taken is not offered again")


# --- Personality client pass (2026-09-21) ---------------------------------
# Each Aspect is its own card, so a Duelist is a stack; both players may field a personality of
# one title; and the four non-school types finally answer `card_group()` with their own group.

## Every non-hand type lands in a group that is true of it, and no two groups share a colour.
func test_the_card_group_answers_for_every_non_hand_type() -> void:
	var shipped: CardLibrary = shipped_library()
	# id, group. The first three are the cases the group accessor already answered.
	var cases: Array = [
		["pyre_strike_01", "pyre"],
		["freestyle_combat_01", "freestyle"],
		["signature_strike_02", "signature"],
		["personality_01", "personality"],
		["pyre_mastery_01", "pyre"],
		["relic_01", "relic"],
		["seal_01", "seal"],
		["grounds_01", "grounds"],
	]
	for row: Array in cases:
		var def: CardDef = shipped.defs.get(str(row[0]))
		check(def != null, "'%s' is in the shipped library" % str(row[0]))
		if def != null:
			eq(def.card_group(), str(row[1]), "'%s' groups as %s" % [def.id, str(row[1])])
	# A Mastery keeps its school, which is the truthful answer for it, and the schoolless one
	# stays Freestyle.
	eq((shipped.defs.get("tide_mastery_01") as CardDef).card_group(), "tide", "a Tide Mastery is Tide")
	eq((shipped.defs.get("freestyle_mastery_01") as CardDef).card_group(), "freestyle", "the schoolless one is Freestyle")
	# Every group the shipped cards reach has a display word and a UI colour of its own. Sharing
	# Freestyle's bronze is what sent the reward screen borrowing Root's green and Steel's silver.
	var groups: Array[String] = []
	for id: String in shipped.defs.keys():
		var group: String = (shipped.defs[id] as CardDef).card_group()
		if not groups.has(group):
			groups.append(group)
		eq(Palette.school_ui(group) == Palette.school_ui("freestyle"), group == "freestyle",
			"'%s' takes Freestyle's colour only if it is Freestyle" % id)
	groups.sort()
	print("    groups in the shipped library: %s" % ", ".join(groups))
	for a in groups:
		check(CardText.GROUP_NAMES.has(a), "'%s' has a display word" % a)
		for b in groups:
			if a == b:
				continue
			check(Palette.school_ui(a) != Palette.school_ui(b), "'%s' and '%s' differ on the UI" % [a, b])
	# Frames: one per group, read off a real card of each so the type branch is what answers.
	var faces: Dictionary = {
		"personality": "personality_01", "relic": "relic_01",
		"seal": "seal_01", "grounds": "grounds_01", "signature": "signature_strike_02",
		"freestyle": "freestyle_combat_01", "pyre": "pyre_strike_01",
	}
	var seen: Array[Color] = []
	for group: String in faces.keys():
		var frame: Color = Palette.frame_color(shipped.defs.get(str(faces[group])))
		check(not seen.has(frame), "'%s' has a frame colour of its own" % group)
		seen.append(frame)


## The name is the character and nothing else, including on the tier two of Bram Ashmark's lines
## share, which carries no line word at all. The line shows where it tells two cards apart.
func test_a_personality_is_named_by_its_character_alone() -> void:
	var shipped: CardLibrary = shipped_library()
	var shared: CardDef = shipped.defs.get("personality_01")
	var glut: CardDef = shipped.defs.get("personality_56")
	var hollow: CardDef = shipped.defs.get("personality_02")
	eq(CardText.personality_name(shared), "Bram Ashmark", "the shared tier 1 is just the name")
	eq(CardText.personality_name(glut), "Bram Ashmark", "and so is a tier that names a line")
	eq(CardText.personality_line(shared), "", "the shared card belongs to no one line")
	eq(CardText.personality_line(glut), "the Glut", "the line is carried beside the name")
	eq(CardText.aspect_name(1, shared), "Starved", "the Aspect title is the card's subtitle")
	eq(CardText.rung_label(shared), "1 · Starved", "a rung is its tier and its title")
	eq(CardText.rung_label(hollow, true), "2 · Leeching · the Hollow", "with the line where it is wanted")
	eq(CardText.rung_label(shared, true), "1 · Starved", "but never on a card that names no line")


## The deck detail's rung labels: quiet for a stack that climbs one line, and naming the line for
## a stack that mixes two.
func test_the_deck_detail_labels_a_one_line_stack_and_a_mixed_one() -> void:
	var shipped: CardLibrary = shipped_library()
	var one_line: PersonalityStack = PersonalityStack.from_ids(shipped, [
		"personality_01", "personality_55",
		"personality_56"] as Array[String])
	check(not CardText.stack_mixes_lines(one_line), "one line, even with a shared tier 1 under it")
	eq(CardText.stack_rungs(one_line), ["1 · Starved", "2 · Gnawing", "3 · Gorging"] as Array[String],
		"so the rungs stay quiet")
	var mixed: PersonalityStack = PersonalityStack.from_ids(shipped, [
		"personality_01", "personality_02",
		"personality_56"] as Array[String])
	check(CardText.stack_mixes_lines(mixed), "Starved, Leeching, Gorging climbs two lines")
	eq(CardText.stack_rungs(mixed),
		["1 · Starved", "2 · Leeching · the Hollow", "3 · Gorging · the Glut"] as Array[String],
		"so every rung says where it came from, bar the one both lines share")


## An option carries the owner seat only for a card both players can see on the table. A card in
## a hand, a Life Deck or a Reserve answers -1, so the field tells nobody anything it did not know.
func test_an_option_carries_the_owner_only_for_a_card_on_the_table() -> void:
	var e: DuelEngine = engine(deck(filler(), "vigil", "", "", 4, "tf_titan"),
		deck(filler(), "vigil", "", "", 4, "tf_titan"))
	var mine: CardInstance = to_hand(e, 0, "t_ally_squire")
	eq(OptionView.public_owner(e, mine.uid), -1, "a card in hand names no owner")
	e._place(e.player(0), mine)
	eq(OptionView.public_owner(e, mine.uid), 0, "the same card on the table does")
	var theirs: CardInstance = to_hand(e, 1, "t_ally_squire")
	eq(OptionView.public_owner(e, theirs.uid), -1, "their hand card stays silent to both seats")
	e._place(e.player(1), theirs)
	eq(OptionView.public_owner(e, theirs.uid), 1, "and speaks once it is placed")
	eq(OptionView.public_owner(e, e.player(0).life_deck[0].uid), -1, "a Life Deck card names no owner")
	eq(OptionView.public_owner(e, -1), -1, "and an option with no card names none either")
	var built: OptionView = OptionView.of(Command.new(0, &"discard_ally", mine.uid), e)
	eq(built.owner, 0, "OptionView.of fills it in")
	eq(OptionView.from_dict(built.to_dict()).owner, 0, "and it survives the round trip online")


## The side marker appears on an option only when another option would read exactly the same, and
## never on a card whose owner the view withheld.
func test_a_side_marker_appears_only_when_two_options_read_alike() -> void:
	var e: DuelEngine = engine(deck(filler(), "vigil", "", "", 4, "tf_titan"),
		deck(filler(), "vigil", "", "", 4, "tf_titan"))
	var mine: CardInstance = to_hand(e, 0, "t_ally_squire")
	var theirs: CardInstance = to_hand(e, 1, "t_ally_squire")
	e._place(e.player(0), mine)
	e._place(e.player(1), theirs)
	var p: PromptView = PromptView.new()
	p.player = 0
	p.options.append(OptionView.of(Command.new(0, &"discard_ally", mine.uid), e))
	p.options.append(OptionView.of(Command.new(0, &"discard_ally", theirs.uid), e))
	eq(p.options[0].label, p.options[1].label, "the two options read the same without a marker")
	var marks: Dictionary = CardText.option_side_marks(p, 0)
	eq(str(marks.get(mine.uid, "")), " · yours", "mine is marked as mine")
	eq(str(marks.get(theirs.uid, "")), " · theirs", "and theirs as theirs")
	eq(str(CardText.option_side_marks(p, 1).get(mine.uid, "")), " · theirs", "seat 1 reads it the other way")
	# One option of a title, or a second option that already reads differently, needs no marker.
	var alone: PromptView = PromptView.new()
	alone.options.append(OptionView.of(Command.new(0, &"discard_ally", mine.uid), e))
	eq(CardText.option_side_marks(alone, 0).size(), 0, "one option of a title is unambiguous")
	var other: CardInstance = to_hand(e, 1, "t_ally_kin")
	e._place(e.player(1), other)
	var distinct: PromptView = PromptView.new()
	distinct.options.append(OptionView.of(Command.new(0, &"discard_ally", mine.uid), e))
	distinct.options.append(OptionView.of(Command.new(0, &"discard_ally", other.uid), e))
	check(distinct.options[0].label != distinct.options[1].label, "two titles read apart already")
	eq(CardText.option_side_marks(distinct, 0).size(), 0, "so neither is marked")
	# A hidden card can never be marked, because the view gave it no owner to mark it by.
	var in_hand: CardInstance = to_hand(e, 0, "t_ally_squire_alt")
	var hidden: PromptView = PromptView.new()
	hidden.options.append(OptionView.of(Command.new(0, &"place", in_hand.uid), e))
	hidden.options.append(OptionView.of(Command.new(0, &"discard_ally", mine.uid), e))
	eq(hidden.options[0].owner, -1, "the hand card carries no owner")
	eq(CardText.option_side_marks(hidden, 0).has(in_hand.uid), false, "and so is never marked")


## A log line names the owner of a personality when both sides hold one of that title in play,
## and says nothing extra when only one side does.
func test_the_log_names_the_owner_when_both_sides_hold_one_title() -> void:
	var e: DuelEngine = engine(deck(filler(), "vigil", "", "", 4, "tf_titan"),
		deck(filler(), "vigil", "", "", 3, "tf_vigil"))
	var mine: CardInstance = to_hand(e, 0, "t_ally_squire")
	e._place(e.player(0), mine)
	eq(CardText._cname(e, mine.uid), mine.def.title, "one Squire on the table needs no owner")
	var theirs: CardInstance = to_hand(e, 1, "t_ally_squire")
	e._place(e.player(1), theirs)
	eq(CardText._cname(e, mine.uid), "%s (%s's)" % [mine.def.title, e.state.players[0].name],
		"two Squires and the line says whose")
	eq(CardText._cname(e, theirs.uid), "%s (%s's)" % [theirs.def.title, e.state.players[1].name],
		"on both sides")
	# A card still in hand is named "a card" to the other seat, owner suffix or not.
	var held: CardInstance = to_hand(e, 0, "t_ally_squire_alt")
	eq(CardText._cname(e, held.uid, 1, 0), "a card", "and a hidden card leaks nothing new")


# --- Motes: the economy, the wallet, the collection, the vendor ------------
#
# Every file these touch goes through a path override, so a test never reaches the player's save.

const MOTES_WALLET_PATH: String = "user://adventure/test_wallet.json"
const MOTES_COLLECTION_PATH: String = "user://adventure/test_collection.json"
const MOTES_STARTER: String = "pyre_beatdown_start"


## A card of each printed tell, and what band it belongs in.
const MOTES_BAND_CASES: Array = [
	["freestyle_strike_06", AdventureEconomy.BAND_BASE],                   # three copies, answers one attack
	["freestyle_combat_17", AdventureEconomy.BAND_LIMITED],                 # printed at two
	["signature_strike_01", AdventureEconomy.BAND_RESTRICTED],             # three copies, but a lockout
	["relic_01", AdventureEconomy.BAND_RESTRICTED],             # printed at one
	["personality_01", AdventureEconomy.BAND_LIMITED],
	["grounds_02", AdventureEconomy.BAND_LIMITED],             # a Grounds sits in the middle
	["grounds_01", AdventureEconomy.BAND_LIMITED],       # even one that forbids
	["seal_01", AdventureEconomy.BAND_RESTRICTED],
]


func test_motes_price_a_card_by_its_printed_tell() -> void:
	var shipped: CardLibrary = shipped_library()
	for row: Array in MOTES_BAND_CASES:
		var def: CardDef = shipped.defs.get(str(row[0]))
		check(def != null, "'%s' is in the shipped library" % str(row[0]))
		if def == null:
			continue
		eq(AdventureEconomy.band(def), str(row[1]), "'%s' is a %s card" % [def.id, str(row[1])])
	check(AdventureEconomy.is_lockout(shipped.defs.get("signature_strike_01")), "a forbid is a lockout")
	check(AdventureEconomy.is_lockout(shipped.defs.get("freestyle_combat_01")), "and so is stopping everything")
	check(not AdventureEconomy.is_lockout(shipped.defs.get("freestyle_strike_06")), "a Strike answer is not")
	check(not AdventureEconomy.is_lockout(shipped.defs.get("seal_01")), "a Seal is exempt by name")
	# Every card in the library is priced, and the bands climb.
	var prices: Array[int] = []
	for band in AdventureEconomy.BANDS:
		prices.append(AdventureEconomy.band_price(band))
	for i in range(1, prices.size()):
		check(prices[i] > prices[i - 1], "band %d costs more than the one below" % i)
	for id: String in shipped.all_ids():
		var def: CardDef = shipped.defs[id]
		check(AdventureEconomy.BANDS.has(AdventureEconomy.band(def)), "'%s' has a band" % id)
		check(AdventureEconomy.price(def) > 0, "'%s' has a price" % id)
		check(AdventureEconomy.discount_price(def) < AdventureEconomy.price(def),
			"'%s' costs less after a win" % id)
		check(AdventureEconomy.dissolve_value(def) < AdventureEconomy.price(def),
			"'%s' dissolves for less than it costs" % id)
	# A later act pays more than an earlier one, a boss more than its act's duels, and beating the
	# final boss pays a bonus on top.
	for act in range(1, 4):
		check(AdventureEconomy.duel_payout(act, true) > AdventureEconomy.duel_payout(act, false),
			"act %d's boss pays more than its duels" % act)
		if act > 1:
			check(AdventureEconomy.duel_payout(act, false) > AdventureEconomy.duel_payout(act - 1, false),
				"act %d pays more than act %d" % [act, act - 1])
	check(AdventureEconomy.completion_bonus() > 0, "beating the final boss pays a bonus")


func test_the_wallet_earns_spends_and_refuses_what_it_cannot_pay() -> void:
	AdventureWallet.path_override = MOTES_WALLET_PATH
	AdventureWallet.clear()
	var wallet: AdventureWallet = AdventureWallet.load_wallet()
	eq(wallet.motes, 0, "a wallet with no file starts empty")
	eq(wallet.earn(120, AdventureWallet.REASON_STAGE, "run-1", 2), 120, "earning adds")
	eq(wallet.earn(0, AdventureWallet.REASON_STAGE, "run-1"), 120, "nothing is not an earning")
	eq(wallet.ledger.size(), 1, "and leaves no ledger entry")
	check(wallet.spend(50, AdventureWallet.REASON_BUY, "card"), "spending what is there works")
	eq(wallet.motes, 70, "the balance comes down")
	check(not wallet.spend(71, AdventureWallet.REASON_BUY, "card"), "spending what is not there does not")
	eq(wallet.motes, 70, "and moves nothing")
	eq(wallet.ledger.size(), 2, "a refused spend is not in the ledger")
	var first: Dictionary = wallet.ledger[0]
	eq(int(first["amount"]), 120, "an earning is positive")
	eq(int(first["stage"]), 2, "a stage payout says which stage")
	eq(str(first["run_id"]), "run-1", "and which run")
	eq(int(wallet.ledger[1]["amount"]), -50, "a spend is negative")
	eq(int(wallet.recent(1).size()), 1, "the screen reads the newest first")
	eq(str(wallet.recent(1)[0]["reason"]), AdventureWallet.REASON_BUY, "newest first")
	# The ledger is a tail, not a history.
	for i in range(AdventureWallet.LEDGER_MAX + 5):
		wallet.earn(1, AdventureWallet.REASON_DISSOLVE)
	eq(wallet.ledger.size(), AdventureWallet.LEDGER_MAX, "the ledger keeps the last N entries")
	wallet.stock_seed = 4242
	check(wallet.save(), "the wallet writes to disk")
	var loaded: AdventureWallet = AdventureWallet.load_wallet()
	eq(loaded.motes, wallet.motes, "the balance came back an int")
	eq(loaded.stock_seed, 4242, "and so did the vendor's seed")
	eq(loaded.ledger.size(), wallet.ledger.size(), "the ledger came back whole")
	eq(int(loaded.ledger[0]["amount"]), int(wallet.ledger[0]["amount"]), "with its amounts as ints")
	AdventureWallet.clear()
	check(not AdventureWallet.exists(), "clear removes the wallet")
	AdventureWallet.path_override = ""


func test_the_collection_holds_what_a_deck_may_run_and_dissolves_the_rest() -> void:
	var shipped: CardLibrary = shipped_library()
	AdventureCollection.path_override = MOTES_COLLECTION_PATH
	AdventureWallet.path_override = MOTES_WALLET_PATH
	AdventureCollection.clear()
	var collection: AdventureCollection = AdventureCollection.load_collection()
	eq(collection.total_copies(), 0, "a collection with no file starts empty")
	# The cap is what DeckValidator would allow, read off its own constants.
	eq(AdventureCollection.cap("freestyle_strike_06", shipped), DeckValidator.DEFAULT_LIMIT, "a plain card caps at three")
	eq(AdventureCollection.cap("freestyle_combat_17", shipped), 2, "a card printed at two caps at two")
	eq(AdventureCollection.cap("signature_strike_06", shipped), DeckValidator.SIGNATURE_LIMIT,
		"a card named for a character caps at the signature fourth")
	eq(AdventureCollection.cap("personality_01", shipped), 1, "a personality caps at one")
	eq(AdventureCollection.cap("seal_01", shipped), 1, "a Seal caps at one")
	eq(AdventureCollection.cap("not_a_card", shipped), 0, "an unknown card is not collectable")
	eq(collection.add("freestyle_strike_06", 2, shipped), 2, "two copies land")
	eq(collection.add("freestyle_strike_06", 5, shipped), 1, "and only the third of the next five")
	eq(collection.copies("freestyle_strike_06"), 3, "the cap holds")
	check(collection.is_full("freestyle_strike_06", shipped), "and the row is full")
	eq(collection.add("not_a_card", 1, shipped), 0, "an unknown card never lands")
	eq(collection.add("personality_01", 3, shipped), 1, "a personality lands once")
	# Dissolving pays a fraction of the price and takes the copy away.
	var wallet: AdventureWallet = AdventureWallet.new()
	var def: CardDef = shipped.defs.get("freestyle_strike_06")
	var paid: int = collection.dissolve("freestyle_strike_06", shipped, wallet)
	eq(paid, AdventureEconomy.dissolve_value(def), "dissolving pays the card's dissolve value")
	eq(wallet.motes, paid, "into the wallet")
	eq(collection.copies("freestyle_strike_06"), 2, "and one copy is gone")
	eq(collection.dissolve("not_held", shipped, wallet), 0, "a card you do not hold dissolves for nothing")
	eq(collection.remove("freestyle_strike_06", 9), 2, "removing takes what is there")
	check(not collection.all_ids().has("freestyle_strike_06"), "and an empty row leaves the collection")
	collection.add("freestyle_combat_17", 2, shipped)
	check(collection.save(), "the collection writes to disk")
	var loaded: AdventureCollection = AdventureCollection.load_collection()
	eq(loaded.copies("freestyle_combat_17"), 2, "the count came back an int")
	eq(loaded.all_ids(), collection.all_ids(), "and the rows came back whole")
	AdventureCollection.clear()
	AdventureCollection.path_override = ""
	AdventureWallet.path_override = ""


## Plays an all-wins run, taking the first choice, the first bundle and the first Aspect card every
## time, and loses the duel after `stop_after` wins when that is not -1. Returns the run, its map,
## the Motes it paid, the cards every taken bundle held and the Aspect cards taken.
func motes_play_run(shipped: CardLibrary, starter_id: String, run_seed: int,
		stop_after: int = -1) -> Dictionary:
	var map: AdventureMap = AdventureMap.generate(starter_id, run_seed)
	var run: AdventureRun = AdventureRun.begin(starter_id, run_seed)
	var wallet: AdventureWallet = AdventureWallet.new()
	var taken: Array[String] = []
	var aspects: Array[String] = []
	var cleared: int = 0
	while run.status != "won" and run.status != "lost":
		if not run.walk_to_next_duel(map):
			break
		var won: bool = stop_after < 0 or cleared < stop_after
		wallet.earn(AdventureRewards.finish_stage(run, map, shipped, won),
			AdventureWallet.REASON_STAGE, run.run_id, run.stage)
		if not won:
			break
		cleared += 1
		if run.status == "aspect":
			var card_id: String = run.pending_aspects[0]
			if AdventureRewards.apply_aspect(run, shipped, card_id):
				aspects.append(card_id)
			AdventureRewards.finish_aspect(run, map, shipped)
		if run.pending_offer.is_empty():
			AdventureRewards.apply_skip(run)
		else:
			var bundle_id: String = run.pending_offer[0]
			var cards: Array[String] = AdventureBundles.cards_of_id(bundle_id)
			if AdventureRewards.apply_bundle(run, shipped, bundle_id):
				taken.append_array(cards)
		wallet.earn(AdventureRewards.finish_reward(run, map),
			AdventureWallet.REASON_COMPLETION, run.run_id)
	return {"run": run, "map": map, "wallet": wallet, "taken": taken, "aspects": aspects}


## The Motes the first `won` duels on the run's path pay, each at its act's rate and a boss at
## the boss rate, plus the bonus when the run was completed.
func motes_expected(map: AdventureMap, path: Array[String], won: int, completed: bool) -> int:
	var total: int = 0
	var counted: int = 0
	for id in path:
		if counted >= won:
			break
		var n: Dictionary = map.node(id)
		var type: String = str(n.get("type", ""))
		if not AdventureMap.is_fight(type):
			continue
		total += AdventureEconomy.duel_payout(int(n.get("act", 1)), type == "boss")
		counted += 1
	return total + (AdventureEconomy.completion_bonus() if completed else 0)


func test_a_won_run_pays_out_and_settles_its_cards_at_a_discount() -> void:
	var shipped: CardLibrary = shipped_library()
	var played: Dictionary = motes_play_run(shipped, MOTES_STARTER, 20260921)
	var run: AdventureRun = played["run"]
	var wallet: AdventureWallet = played["wallet"]
	eq(run.status, "won", "the all-wins run beats the final boss")
	eq(wallet.motes, motes_expected(played["map"], run.path, run.stage, true),
		"it is paid for every duel at its act's rate and the completion bonus")
	# What the run added is what the bundles brought plus the Aspect cards it climbed to.
	var expected: Array[String] = (played["taken"] as Array[String]).duplicate()
	expected.sort()
	eq(run.added_cards(), expected, "added_cards is the bundle cards, and only those")
	eq(run.added_duelist_cards(), played["aspects"], "and the Aspect cards sit apart from them")
	check(not expected.is_empty(), "the run did add something")
	# The run-end screen. A win opens the whole deck, the starter's own cards included.
	check(AdventureSettlement.open(run), "a finished run opens its settlement")
	eq(run.status, "settle", "which is a state of its own")
	check(AdventureSettlement.won(run), "and it remembers the run was won")
	var collection: AdventureCollection = AdventureCollection.new()
	var rows: Array[Dictionary] = AdventureSettlement.offers(run, shipped, true, collection)
	check(rows.size() > expected.size() / 3, "a won run offers more rows than a loss would")
	var starter_offered: bool = false
	for row in rows:
		var def: CardDef = shipped.defs.get(str(row["id"]))
		eq(int(row["price"]), AdventureEconomy.price(def), "'%s' shows its full price" % def.id)
		eq(int(row["discount_price"]), AdventureEconomy.discount_price(def),
			"'%s' shows the win discount" % def.id)
		eq(int(row["unit"]), int(row["discount_price"]), "and charges the discount on a won run")
		eq(int(row["cap_remaining"]), AdventureCollection.cap(def.id, shipped),
			"'%s' says how much room is left" % def.id)
		if run.starter_cards.has(def.id):
			starter_offered = true
	check(starter_offered, "beating the ladder puts the starter's own cards on offer too")
	# Keeping cards spends exactly what the rows said and lands them in the collection.
	var kept_ids: Array[String] = []
	var cost: int = 0
	for row in rows:
		if kept_ids.size() >= 3:
			break
		if int(row["count"]) < 1:
			continue
		kept_ids.append(str(row["id"]))
		cost += int(row["unit"])
	var before: int = wallet.motes
	wallet.earn(cost, AdventureWallet.REASON_STAGE, run.run_id)
	for id in kept_ids:
		eq(AdventureSettlement.keep(run, id, 1, wallet, collection, shipped), 1,
			"keeping '%s' banks one copy" % id)
		eq(collection.copies(id), 1, "'%s' is in the collection" % id)
	eq(wallet.motes, before, "and the Motes for it are gone, to the Mote")
	# A run cannot be settled twice.
	AdventureSettlement.close(run)
	check(run.settled, "closing settles the run")
	eq(run.status, "won", "and leaves it reading as the win it was")
	check(not AdventureSettlement.is_open(run), "a settled run is not open")
	wallet.earn(10000, AdventureWallet.REASON_STAGE, run.run_id)
	eq(AdventureSettlement.keep(run, kept_ids[0], 1, wallet, collection, shipped), 0,
		"and nothing more can be bought from it")
	check(not AdventureSettlement.open(run), "nor can it be reopened")


func test_a_run_lost_at_stage_five_keeps_four_payouts_and_pays_full_price() -> void:
	var shipped: CardLibrary = shipped_library()
	var played: Dictionary = motes_play_run(shipped, MOTES_STARTER, 771, 4)
	var run: AdventureRun = played["run"]
	var wallet: AdventureWallet = played["wallet"]
	eq(run.status, "lost", "the run ends on its fifth duel")
	eq(run.stage, 4, "with four duels won")
	eq(wallet.motes, motes_expected(played["map"], run.path, 4, false), "paid for the four duels it won and no bonus")
	check(wallet.motes > 0, "a lost run still pays")
	check(AdventureSettlement.open(run), "a lost run settles too")
	check(not AdventureSettlement.won(run), "knowing it was lost")
	var collection: AdventureCollection = AdventureCollection.new()
	var rows: Array[Dictionary] = AdventureSettlement.offers(run, shipped, false, collection)
	check(not rows.is_empty(), "with the cards it managed to add on offer")
	var offered: Array[String] = []
	for row in rows:
		var def: CardDef = shipped.defs.get(str(row["id"]))
		eq(int(row["unit"]), AdventureEconomy.price(def), "'%s' is full price after a loss" % def.id)
		offered.append(def.id)
	# Only what the run added: nothing the starter printed is on offer.
	for row in rows:
		var id: String = str(row["id"])
		check(run.added_cards().has(id) or run.added_duelist_cards().has(id),
			"'%s' is a card the run added" % id)
	# A wallet that cannot cover the copy buys nothing at all.
	var poor: AdventureWallet = AdventureWallet.new()
	eq(AdventureSettlement.keep(run, offered[0], 1, poor, collection, shipped), 0,
		"an empty wallet keeps nothing")
	eq(collection.total_copies(), 0, "and the collection stays empty")


func test_the_vendor_sells_a_rotating_shelf_of_buyable_cards() -> void:
	var shipped: CardLibrary = shipped_library()
	var wallet: AdventureWallet = AdventureWallet.new()
	var collection: AdventureCollection = AdventureCollection.new()
	var stock: Array[String] = AdventureVendor.stock(wallet, collection, shipped)
	eq(stock.size(), AdventureEconomy.vendor_stock_size(), "the shelf holds what the economy says")
	for id in stock:
		var def: CardDef = shipped.defs.get(id)
		check(def != null, "'%s' is a real card" % id)
		check(def.type != CardDef.Type.MASTERY, "'%s' is not a Mastery" % id)
		check(def.type != CardDef.Type.RELIC, "'%s' is not a Relic" % id)
		check(def.type != CardDef.Type.SEAL, "'%s' is not a Seal" % id)
	eq(AdventureVendor.stock(wallet, collection, shipped), stock, "the same seed shows the same shelf")
	# A card the collection is already full of is off the shelf.
	var full_id: String = stock[0]
	collection.add(full_id, AdventureCollection.cap(full_id, shipped), shipped)
	var after: Array[String] = AdventureVendor.stock(wallet, collection, shipped)
	check(not after.has(full_id), "a card you hold every copy of is not for sale")
	eq(after.size(), AdventureEconomy.vendor_stock_size(), "and the shelf stays full")
	# Buying spends and banks.
	var buy_id: String = after[0]
	var cost: int = AdventureVendor.price(buy_id, shipped)
	check(not AdventureVendor.buy(buy_id, wallet, collection, shipped), "an empty wallet buys nothing")
	wallet.earn(cost, AdventureWallet.REASON_STAGE)
	check(AdventureVendor.buy(buy_id, wallet, collection, shipped), "with the Motes it does")
	eq(wallet.motes, 0, "and the price is gone")
	eq(collection.copies(buy_id), 1, "the card is in the collection")
	check(not AdventureVendor.buy("clear_mind_not_on_sale", wallet, collection, shipped),
		"a card that is not on the shelf cannot be bought")
	# The paid reroll takes the fee; a free one is the roll at the end of a run.
	check(not AdventureVendor.reroll(wallet, true), "a reroll nobody can pay for is refused")
	wallet.earn(AdventureEconomy.vendor_reroll_fee(), AdventureWallet.REASON_STAGE)
	var before_seed: int = AdventureVendor.seed_of(wallet)
	check(AdventureVendor.reroll(wallet, true), "paying for one works")
	eq(wallet.motes, 0, "the fee is taken")
	check(AdventureVendor.seed_of(wallet) != before_seed, "and the shelf is drawn from a new seed")
	var rolled: Array[String] = AdventureVendor.stock(wallet, collection, shipped)
	check(rolled != after, "which shows a different shelf")
	check(AdventureVendor.reroll(wallet, false), "the roll at the end of a run costs nothing")
	eq(wallet.motes, 0, "and takes no fee")
	check(AdventureVendor.stock(wallet, collection, shipped) != rolled, "but still turns the shelf over")


func test_a_loadout_swap_is_legal_only_through_the_validator() -> void:
	var shipped: CardLibrary = shipped_library()
	var collection: AdventureCollection = AdventureCollection.new()
	for id in ["freestyle_strike_06", "steel_combat_01", "pyre_strike_12", "seal_01",
			"personality_55", "personality_56"]:
		collection.add(str(id), 1, shipped)
	var deck: DeckList = AdventureLoadout.base_deck(MOTES_STARTER)
	check(deck != null, "the starter resolves")
	var size: int = deck.cards.size()
	check(AdventureLoadout.swappable_out(deck).has("pyre_strike_12"), "a card in the deck can go out")
	check(not AdventureLoadout.swappable_out(deck).has("freestyle_strike_06"), "a card that is not cannot")
	# One out, one in, and the deck stays the size it was.
	var legal: Dictionary = AdventureLoadout.swap(deck, "pyre_strike_12", "freestyle_strike_06", shipped, collection)
	eq((legal["problems"] as Array[String]).size(), 0, "a legal swap has nothing to answer for")
	var swapped: DeckList = legal["deck"]
	check(swapped != null, "and hands back the swapped deck")
	if swapped != null:
		eq(swapped.cards.size(), size, "the starter keeps its size")
		eq(swapped.cards.count("freestyle_strike_06"), 1, "the new card is in")
		eq(swapped.cards.count("pyre_strike_12"), deck.cards.count("pyre_strike_12") - 1, "one copy of the old one is out")
	eq(deck.cards.size(), size, "and the deck it was asked about is untouched")
	# The validator's own words come back for each refusal.
	var off_school: Dictionary = AdventureLoadout.swap(deck, "pyre_strike_12", "steel_combat_01", shipped, collection)
	check(swap_problem_mentions(off_school, "steel"), "an off-school card is refused as off-school")
	check(off_school["deck"] == null, "and no deck comes back")
	var over_limit: Dictionary = AdventureLoadout.swap(deck, "signature_strike_08", "pyre_strike_12", shipped, collection)
	check(swap_problem_mentions(over_limit, "exceeds limit"), "a fourth copy is refused as over the limit")
	var seal_deck: DeckList = AdventureLoadout.base_deck("root_seals_start")
	var seal_swap: Dictionary = AdventureLoadout.swap(seal_deck, "seal_08", "seal_01", shipped, collection)
	check(swap_problem_mentions(seal_swap, "Seal set"), "a Seal of another set is refused")
	var unowned: Dictionary = AdventureLoadout.swap(deck, "pyre_strike_12", "freestyle_combat_01", shipped, collection)
	check(swap_problem_mentions(unowned, "collection"), "a card you do not own is not swappable in")
	check(AdventureLoadout.swappable_in(deck, shipped, collection, "pyre_strike_12").has("freestyle_strike_06"),
		"the swappable list holds the legal card")
	check(not AdventureLoadout.swappable_in(deck, shipped, collection, "pyre_strike_12").has("steel_combat_01"),
		"and not the illegal one")
	# A Duelist rung trades for another card of the same character at the same tier.
	var rung: Dictionary = AdventureLoadout.swap_rung(deck, 2, "personality_55", shipped, collection)
	eq((rung["problems"] as Array[String]).size(), 0, "a same-character, same-tier rung swap is legal")
	var rung_deck: DeckList = rung["deck"]
	check(rung_deck != null and rung_deck.duelist_ids[1] == "personality_55",
		"and the rung is the new card")
	eq(rung_deck.aspects if rung_deck != null else 0, deck.aspects, "the stack keeps its height")
	var wrong_tier: Dictionary = AdventureLoadout.swap_rung(deck, 2, "personality_56", shipped, collection)
	check(not (wrong_tier["problems"] as Array[String]).is_empty(), "a card of the wrong tier is refused")
	check(wrong_tier["deck"] == null, "with no deck to run")
	check(AdventureLoadout.swap_rung(deck, 9, "personality_55", shipped).has("problems"),
		"and a rung the Duelist does not have is refused too")
	check(AdventureLoadout.swappable_rungs(deck, shipped, collection, 2).has("personality_55"),
		"the rung list holds the tier-two card")
	check(not AdventureLoadout.swappable_rungs(deck, shipped, collection, 2).has("personality_56"),
		"and not the tier-three one")
	# The run starts from what was assembled, so the settlement charges for what the run added.
	var run: AdventureRun = AdventureLoadout.begin_from(MOTES_STARTER, swapped, 99)
	check(run != null, "a swapped deck begins a run")
	if run != null:
		eq(run.starter_cards, swapped.cards, "whose starting list is the swapped one")
		eq(run.cards, swapped.cards, "and whose deck starts there")
		eq(run.added_cards().size(), 0, "so it has added nothing yet")
		check(run.run_id != "", "and it is named for the ledger")


## True when any problem of a refused swap holds `needle`.
func swap_problem_mentions(result: Dictionary, needle: String) -> bool:
	for problem in result["problems"] as Array[String]:
		if problem.contains(needle):
			return true
	return false


## A run knows what it began from, so it settles for what it added, and a run saved on the settle
## screen comes back to it with what was already bought.
func test_a_run_settles_for_what_it_added_across_a_save() -> void:
	var shipped: CardLibrary = shipped_library()
	var printed: DeckList = DeckList.resolve(MOTES_STARTER)
	var run: AdventureRun = AdventureRun.begin(MOTES_STARTER, 8181)
	run.cards.append("freestyle_strike_06")
	run.cards.append("freestyle_strike_06")
	run.duelist_ids.append("personality_56")
	eq(run.run_id, AdventureRun.id_for(MOTES_STARTER, 8181), "a run is named from its starter and seed")
	eq(run.starter_cards, printed.cards, "the printed starter is its starting deck")
	eq(run.starter_duelist, printed.duelist_ids, "stack included")
	eq(run.added_cards(), ["freestyle_strike_06", "freestyle_strike_06"] as Array[String],
		"so the run settles for what it actually added")
	eq(run.added_duelist_cards(), ["personality_56"] as Array[String],
		"and for the Aspect it climbed to")
	eq(run.settled, false, "a run in flight has not been settled")
	var again: AdventureRun = AdventureRun.from_dict(run.to_dict())
	eq(int(run.to_dict()["version"]), AdventureRun.SAVE_VERSION, "it is written at the current version")
	eq(again.run_id, run.run_id, "the run id survives the round trip")
	eq(again.starter_cards, run.starter_cards, "and so does the starting deck")
	run.status = "lost"
	AdventureSettlement.open(run)
	run.kept["freestyle_strike_06"] = 1
	var settled: AdventureRun = AdventureRun.from_dict(run.to_dict())
	eq(settled.status, "settle", "a run saved on the settle screen comes back to it")
	eq(settled.outcome, "lost", "knowing which way it ended")
	eq(int(settled.kept.get("freestyle_strike_06", 0)), 1, "and what was already bought")
	eq(AdventureSettlement.offers(settled, shipped, false).size(), 2,
		"so the offer no longer lists the copy that was kept")


# --- Copy caps, loadout copies, deck slots and Aspect tiers (2026-09-21) ----

const MOTES_UPGRADES_PATH: String = "user://adventure/test_upgrades.json"
## A second starter, so the "one library, every starter" rule has two decks to share between.
const MOTES_STARTER_TWO: String = "pyre_attrition_start"


func test_the_collection_caps_at_three_four_or_one_and_dissolves_the_rest() -> void:
	var shipped: CardLibrary = shipped_library()
	eq(AdventureCollection.cap("freestyle_strike_06", shipped), AdventureCollection.CAP_NORMAL,
		"a normal card caps at three")
	eq(AdventureCollection.cap("signature_strike_06", shipped), AdventureCollection.CAP_SIGNATURE,
		"a card named for a character caps at four")
	eq(AdventureCollection.cap("personality_01", shipped), 1, "a personality caps at one")
	eq(AdventureCollection.cap("seal_01", shipped), 1, "a Seal caps at one")
	eq(AdventureCollection.cap("freestyle_combat_17", shipped), 2, "a card printed at two keeps the lower cap")
	eq(AdventureCollection.cap("relic_01", shipped), 1, "and a card printed at one keeps that")
	# No shipped card is ever capped above the signature four, nor below its own printed limit
	# when that limit is the looser of the two.
	for id: String in shipped.all_ids():
		var def: CardDef = shipped.defs[id]
		var cap: int = AdventureCollection.cap(id, shipped)
		check(cap >= 1 and cap <= AdventureCollection.CAP_SIGNATURE, "'%s' caps between 1 and 4" % id)
		if def.limit_per_deck < DeckValidator.DEFAULT_LIMIT and def.type != CardDef.Type.SEAL \
				and def.type != CardDef.Type.PERSONALITY:
			eq(cap, def.limit_per_deck, "'%s' keeps its tighter printed limit" % id)
	# Banking past the cap dissolves the overflow instead of dropping it.
	var wallet: AdventureWallet = AdventureWallet.new()
	var fresh: AdventureCollection = AdventureCollection.new()
	var banked: Dictionary = fresh.bank("freestyle_strike_06", 5, shipped, wallet)
	eq(int(banked["added"]), 3, "three of five copies land")
	eq(int(banked["copies"]), 2, "and the other two dissolve")
	eq(int(banked["motes"]), 2 * AdventureEconomy.dissolve_value(shipped.defs["freestyle_strike_06"]),
		"paying the dissolve value per copy")
	eq(wallet.motes, int(banked["motes"]), "into the wallet")
	eq(AdventureCollection.report_line(banked), "2 copies dissolved for %d Motes" % int(banked["motes"]),
		"and the screen has a line to show")
	eq(AdventureCollection.report_line({"copies": 0, "motes": 0}), "", "with nothing to say when nothing dissolved")
	# A saved row above its cap (a card whose printed limit dropped) is trimmed on load, and the
	# overflow is paid back.
	var old: Dictionary = {"version": AdventureCollection.SAVE_VERSION, "cards": {
		"freestyle_strike_06": 5,
		"freestyle_combat_17": 4,
		"personality_01": 3,
		"pyre_strike_12": 3,
	}}
	var migrated: AdventureCollection = AdventureCollection.from_dict(old)
	eq(migrated.copies("freestyle_strike_06"), 5, "the file loads exactly what it held")
	var purse: AdventureWallet = AdventureWallet.new()
	var report: Dictionary = migrated.trim_to_cap(shipped, purse)
	eq(migrated.copies("freestyle_strike_06"), 3, "the trim takes a normal row back to three")
	eq(migrated.copies("freestyle_combat_17"), 2, "a card printed at two back to two")
	eq(migrated.copies("personality_01"), 1, "and a personality back to one")
	eq(migrated.copies("pyre_strike_12"), 3, "a row already inside its cap is left alone")
	eq(int(report["copies"]), 6, "six copies dissolved in all")
	var expected_motes: int = 2 * AdventureEconomy.dissolve_value(shipped.defs["freestyle_strike_06"]) \
		+ 2 * AdventureEconomy.dissolve_value(shipped.defs["freestyle_combat_17"]) \
		+ 2 * AdventureEconomy.dissolve_value(shipped.defs["personality_01"])
	eq(int(report["motes"]), expected_motes, "for what they were worth")
	eq(purse.motes, expected_motes, "paid into the wallet")
	eq((report["rows"] as Array).size(), 3, "with one report row per card")
	eq(int(migrated.trim_to_cap(shipped, purse)["copies"]), 0, "a second trim finds nothing to take")
	eq(purse.motes, expected_motes, "and pays nothing more")


func test_keeping_and_buying_stop_at_the_collection_cap() -> void:
	var shipped: CardLibrary = shipped_library()
	# The vendor: a card the collection is already full of cannot be bought at any price.
	var wallet: AdventureWallet = AdventureWallet.new()
	var collection: AdventureCollection = AdventureCollection.new()
	var stock: Array[String] = AdventureVendor.stock(wallet, collection, shipped)
	var full_id: String = stock[0]
	collection.add(full_id, AdventureCollection.cap(full_id, shipped), shipped)
	wallet.earn(10000, AdventureWallet.REASON_STAGE)
	check(collection.is_full(full_id, shipped), "the row is at its cap")
	check(not AdventureVendor.buy(full_id, wallet, collection, shipped), "so the vendor will not sell another")
	eq(wallet.motes, 10000, "and charges nothing for the refusal")
	eq(collection.copies(full_id), AdventureCollection.cap(full_id, shipped), "the row stays at its cap")
	# The run-end settlement: the same, through `cap_remaining` 0 rather than a dissolve.
	var played: Dictionary = motes_play_run(shipped, MOTES_STARTER, 5150, 4)
	var run: AdventureRun = played["run"]
	check(AdventureSettlement.open(run), "the lost run settles")
	var rows: Array[Dictionary] = AdventureSettlement.offers(run, shipped, false, collection)
	check(not rows.is_empty(), "with cards on offer")
	var offer_id: String = str(rows[0]["id"])
	collection.add(offer_id, AdventureCollection.cap(offer_id, shipped), shipped)
	var capped: Array[Dictionary] = AdventureSettlement.offers(run, shipped, false, collection)
	for row in capped:
		if str(row["id"]) == offer_id:
			eq(int(row["cap_remaining"]), 0, "the row says there is no room left")
	var before: int = wallet.motes
	eq(AdventureSettlement.keep(run, offer_id, 1, wallet, collection, shipped), 0,
		"so Keep banks nothing")
	eq(wallet.motes, before, "and spends nothing")
	eq(collection.copies(offer_id), AdventureCollection.cap(offer_id, shipped),
		"leaving the row at its cap")


## The first Life Deck card of `deck` that `in_id` can legally replace, or "" when there is none.
func loadout_slot_for(deck: DeckList, in_id: String, library: CardLibrary,
		collection: AdventureCollection) -> String:
	for out_id in AdventureLoadout.swappable_out(deck):
		if out_id == in_id:
			continue
		if (AdventureLoadout.swap(deck, out_id, in_id, library, collection)["problems"]
				as Array[String]).is_empty():
			return out_id
	return ""


func test_a_loadout_takes_no_more_copies_than_the_collection_holds() -> void:
	var shipped: CardLibrary = shipped_library()
	var collection: AdventureCollection = AdventureCollection.new()
	eq(collection.add("freestyle_strike_06", 2, shipped), 2, "the collection holds two copies")
	var deck: DeckList = AdventureLoadout.base_deck(MOTES_STARTER)
	eq(AdventureLoadout.starter_of(deck), MOTES_STARTER, "the loadout deck remembers its starter")
	eq(AdventureLoadout.from_collection(deck, "freestyle_strike_06"), 0, "and takes nothing from the library yet")
	# Two copies in is exactly what two copies owned allows.
	var first_slot: String = loadout_slot_for(deck, "freestyle_strike_06", shipped, collection)
	check(first_slot != "", "there is a slot the card can take")
	var one: DeckList = AdventureLoadout.swap(deck, first_slot, "freestyle_strike_06", shipped, collection)["deck"]
	check(one != null, "the first copy swaps in")
	eq(AdventureLoadout.from_collection(one, "freestyle_strike_06"), 1, "one copy is now from the library")
	var second_slot: String = loadout_slot_for(one, "freestyle_strike_06", shipped, collection)
	check(second_slot != "", "and there is a second slot for it")
	var two: DeckList = AdventureLoadout.swap(one, second_slot, "freestyle_strike_06", shipped, collection)["deck"]
	check(two != null, "the second copy swaps in as well")
	eq(two.cards.count("freestyle_strike_06") if two != null else -1, 2, "the deck runs two")
	eq(AdventureLoadout.from_collection(two, "freestyle_strike_06"), 2, "both from the library")
	# A third would be legal to run and is refused anyway: the collection only holds two.
	var third_slot: String = ""
	for out_id in AdventureLoadout.swappable_out(two):
		if out_id != "freestyle_strike_06":
			third_slot = out_id
			break
	var third: Dictionary = AdventureLoadout.swap(two, third_slot, "freestyle_strike_06", shipped, collection)
	check(third["deck"] == null, "a third copy is refused")
	check(swap_problem_mentions(third, "You own 2 copies"), "because the collection only holds two")
	check(not AdventureLoadout.swappable_in(two, shipped, collection, third_slot).has("freestyle_strike_06"),
		"and it is off the swappable list")
	eq(collection.copies("freestyle_strike_06"), 2, "nothing was consumed either way")
	# The library is shared: the same two copies go into a second starter at the same time.
	var other: DeckList = AdventureLoadout.base_deck(MOTES_STARTER_TWO)
	check(other != null, "the second starter resolves")
	var other_slot: String = loadout_slot_for(other, "freestyle_strike_06", shipped, collection)
	check(other_slot != "", "which can take the card too")
	var other_one: DeckList = AdventureLoadout.swap(other, other_slot, "freestyle_strike_06", shipped, collection)["deck"]
	check(other_one != null, "even while the first starter is already running both copies")
	eq(collection.copies("freestyle_strike_06"), 2, "and the collection still holds two")
	# A starter's own cards are the starter's, not the library's.
	eq(AdventureLoadout.from_collection(deck, "pyre_strike_12"), 0,
		"a printed card counts against nothing, however many the starter runs")
	check(collection.copies("pyre_strike_12") == 0, "even with no copy of it in the collection at all")


## Every slot bought and an Aspect card added: the 85-card maximum, not the slot count, is the
## limit, and the loadout says so itself instead of leaving it to the validator.
func test_the_loadout_stops_at_the_full_deck_maximum_before_the_validator_does() -> void:
	var shipped: CardLibrary = shipped_library()
	var deck: DeckList = AdventureLoadout.base_deck(MOTES_STARTER)
	var upgrades: AdventureUpgrades = AdventureUpgrades.new()
	var wallet: AdventureWallet = AdventureWallet.new()
	wallet.earn(10000000, AdventureWallet.REASON_STAGE)
	var most: int = AdventureLoadout.max_slots(deck)
	for i in range(most):
		upgrades.buy_slot(MOTES_STARTER, wallet, most)
	eq(upgrades.slots(MOTES_STARTER), most, "every slot bought")
	# One more card in the stack than the starter prints, as a bought Aspect tier gives.
	var taller: Array[String] = deck.duelist_ids.duplicate()
	taller.append(taller[taller.size() - 1])
	deck.set_duelist(taller)
	while deck.total_cards() < DeckValidator.MAX_CARDS:
		deck.cards.append("freestyle_strike_06")
	eq(AdventureLoadout.ceiling_left(deck), 0, "the whole deck is at the maximum")
	check(AdventureLoadout.size_cap(deck, upgrades) > deck.cards.size(), "while a bought slot is still empty")
	eq(AdventureLoadout.room_left(deck, upgrades), 0, "so there is no room left")
	var result: Dictionary = AdventureLoadout.add_card(deck, "freestyle_strike_06", shipped, null, upgrades)
	eq(result["deck"], null, "the add is refused")
	check(str((result["problems"] as Array[String])[0]).contains("maximum"), "by the loadout, naming the maximum: %s" % str(result["problems"]))


func test_bought_deck_slots_raise_the_loadout_cap_at_a_rising_price() -> void:
	var shipped: CardLibrary = shipped_library()
	# The price curve rises every slot and never goes free.
	eq(AdventureEconomy.slot_cost(0), 0, "there is no zeroth slot")
	eq(AdventureEconomy.slot_cost(1), 100, "the first slot costs 100")
	for i in range(1, 40):
		check(AdventureEconomy.slot_cost(i + 1) > AdventureEconomy.slot_cost(i),
			"slot %d costs more than slot %d" % [i + 1, i])
	var full_win: int = (motes_play_run(shipped, MOTES_STARTER, 20260921)["wallet"] as AdventureWallet).motes
	check(AdventureEconomy.slot_cost(1) <= full_win, "the first slot is inside one full win")
	check(AdventureEconomy.slot_cost_total(3) <= full_win, "and so are the first three together")
	eq(AdventureEconomy.slot_cost_total(3), 330, "which is 330 Motes")
	# The ceiling is the validator's own card maximum, measured from what the starter prints.
	var starter_deck: DeckList = AdventureLoadout.base_deck(MOTES_STARTER)
	eq(starter_deck.total_cards(), 52, "the starter prints 52 cards in all")
	eq(AdventureLoadout.max_slots(starter_deck), DeckValidator.MAX_CARDS - 52,
		"so it has 33 slots to buy before it hits the maximum")
	eq(AdventureLoadout.max_slots_for(MOTES_STARTER), AdventureLoadout.max_slots(starter_deck),
		"and the starter id answers the same")
	var root_deck: DeckList = AdventureLoadout.base_deck("root_seals_start")
	eq(AdventureLoadout.max_slots(root_deck), DeckValidator.MAX_CARDS_ROOT - root_deck.total_cards(),
		"a Root deck is measured against the higher Root maximum")
	var most: int = AdventureLoadout.max_slots(starter_deck)
	var upgrades: AdventureUpgrades = AdventureUpgrades.new()
	var wallet: AdventureWallet = AdventureWallet.new()
	eq(upgrades.slots(MOTES_STARTER), 0, "a starter begins with no bought slots")
	eq(upgrades.next_slot_cost(MOTES_STARTER, most), AdventureEconomy.slot_cost(1), "and the first slot's price")
	check(not upgrades.buy_slot(MOTES_STARTER, wallet, most), "an empty wallet buys no slot")
	eq(upgrades.slots(MOTES_STARTER), 0, "and nothing moves")
	wallet.earn(100000, AdventureWallet.REASON_STAGE)
	var first_cost: int = upgrades.next_slot_cost(MOTES_STARTER, most)
	check(upgrades.buy_slot(MOTES_STARTER, wallet, most), "with Motes it does")
	eq(wallet.motes, 100000 - first_cost, "the price is taken")
	eq(upgrades.slots(MOTES_STARTER), 1, "and the starter has a slot")
	check(upgrades.next_slot_cost(MOTES_STARTER, most) > first_cost, "the next one costs more")
	eq(upgrades.slots(MOTES_STARTER_TWO), 0, "a slot is bought per starter and not for all of them")
	# The loadout cap follows the slots, and Add fills them.
	var collection: AdventureCollection = AdventureCollection.new()
	collection.add("freestyle_strike_06", 2, shipped)
	var deck: DeckList = AdventureLoadout.base_deck(MOTES_STARTER)
	var printed: int = deck.cards.size()
	var none: AdventureUpgrades = AdventureUpgrades.new()
	eq(AdventureLoadout.size_cap(deck, none), printed, "an unbought starter caps at its printed size")
	eq(AdventureLoadout.room_left(deck, none), 0, "with no room to add")
	var refused: Dictionary = AdventureLoadout.add_card(deck, "freestyle_strike_06", shipped, collection, none)
	check(refused["deck"] == null, "so Add is refused at the cap")
	check(swap_problem_mentions(refused, "buy a deck slot"), "and says what would open one")
	eq(AdventureLoadout.size_cap(deck, upgrades), printed + 1, "a bought slot raises the cap by one")
	eq(AdventureLoadout.room_left(deck, upgrades), 1, "leaving one slot free")
	check(AdventureLoadout.swappable_add(deck, shipped, collection, upgrades).has("freestyle_strike_06"),
		"which the collection card can fill")
	var grown: DeckList = AdventureLoadout.add_card(deck, "freestyle_strike_06", shipped, collection, upgrades)["deck"]
	check(grown != null, "and Add fills it")
	eq(grown.cards.size() if grown != null else 0, printed + 1, "the deck is one card bigger")
	eq(AdventureLoadout.room_left(grown, upgrades), 0, "with the slot spent")
	check(AdventureLoadout.add_card(grown, "freestyle_strike_06", shipped, collection, upgrades)["deck"] == null,
		"and a second Add refused until another slot is bought")
	# A starter with an empty slot may still begin: the cap is a ceiling, not a requirement.
	eq(DeckValidator.validate(deck, shipped).size(), 0, "an unfilled slot leaves the deck legal")
	eq(DeckValidator.validate(grown, shipped).size(), 0, "and so does a filled one")


func test_owned_aspects_gate_the_loadout_and_the_run() -> void:
	var shipped: CardLibrary = shipped_library()
	var deck: DeckList = AdventureLoadout.base_deck(MOTES_STARTER)
	var base_aspects: int = deck.duelist_ids.size()
	eq(base_aspects, 2, "the starter prints a two-card stack")
	var collection: AdventureCollection = AdventureCollection.new()
	# Nothing owned: nothing to add, and a run never climbs.
	var locked: Dictionary = AdventureLoadout.add_aspect(deck, "personality_56", shipped, collection)
	check(locked["deck"] == null, "an Aspect card the collection lacks is refused")
	check(swap_problem_mentions(locked, "not in the collection"), "saying so plainly")
	check(AdventureLoadout.swappable_aspect(deck, shipped, collection).is_empty(), "and nothing is on offer")
	var bare: AdventureRun = AdventureLoadout.begin_from(MOTES_STARTER, deck, 4242)
	AdventureProgress.prepare_run(bare, shipped, collection, AdventureUnlocks.new())
	eq(bare.owned_aspects.size(), 0, "a run owns no Aspect above its stack")
	eq(_aspect_grants_over_a_run(bare, shipped, 4242), 0, "and is never offered one")
	# Owned cards go on in order, only the next tier at a time.
	collection.add("personality_56", 1, shipped)
	collection.add("personality_57", 1, shipped)
	eq(AdventureLoadout.aspect_cap(deck), DeckValidator.MAX_ASPECTS, "the stack may reach the construction maximum")
	check(AdventureLoadout.add_aspect(deck, "personality_57", shipped, collection)["deck"] == null,
		"a tier-four card cannot jump onto a two-card stack")
	eq(AdventureLoadout.swappable_aspect(deck, shipped, collection), ["personality_56"] as Array[String],
		"only the owned tier-three card is on offer")
	var tall: DeckList = AdventureLoadout.add_aspect(deck, "personality_56", shipped, collection)["deck"]
	check(tall != null, "the tier-three card goes on")
	eq(DeckValidator.validate(tall, shipped).size(), 0, "which is legal to run")
	# A run from that deck climbs only through what is owned: tier 4 at a boss, then nothing.
	var run: AdventureRun = AdventureLoadout.begin_from(MOTES_STARTER, tall, 4242)
	AdventureProgress.prepare_run(run, shipped, collection, AdventureUnlocks.new())
	eq(run.owned_aspects, ["personality_57"] as Array[String], "the run carries the owned tier-four card")
	eq(run.next_tier_options(shipped), ["personality_57"] as Array[String], "and offers only that")
	eq(_aspect_grants_over_a_run(run, shipped, 4242), 1, "one boss grant climbs to it; the next has nothing owned")
	eq(run.duelist_ids.size(), 4, "so the run finished four Aspects high")


## Plays `run` to the end on its map, winning every duel and taking the first offer. Returns how
## many Aspect choices it was given.
func _aspect_grants_over_a_run(run: AdventureRun, shipped: CardLibrary, run_seed: int) -> int:
	var map: AdventureMap = AdventureMap.generate(run.starter_id, run_seed)
	var granted: int = 0
	while run.status != "won" and run.status != "lost" and run.walk_to_next_duel(map):
		AdventureRewards.finish_stage(run, map, shipped, true)
		if run.status == "aspect":
			granted += 1
			AdventureRewards.apply_aspect(run, shipped, run.pending_aspects[0])
			AdventureRewards.finish_aspect(run, map, shipped)
		if run.pending_offer.is_empty():
			AdventureRewards.apply_skip(run)
		else:
			AdventureRewards.apply_bundle(run, shipped, run.pending_offer[0])
		AdventureRewards.finish_reward(run, map)
	return granted


func test_the_upgrades_file_round_trips_through_a_path_override() -> void:
	AdventureUpgrades.path_override = MOTES_UPGRADES_PATH
	AdventureUpgrades.clear()
	var upgrades: AdventureUpgrades = AdventureUpgrades.load_upgrades()
	eq(upgrades.slots(MOTES_STARTER), 0, "upgrades with no file start empty")
	eq(upgrades.all_starters().size(), 0, "and name no starter")
	var wallet: AdventureWallet = AdventureWallet.new()
	wallet.earn(10000, AdventureWallet.REASON_STAGE)
	var most: int = AdventureLoadout.max_slots_for(MOTES_STARTER)
	check(upgrades.buy_slot(MOTES_STARTER, wallet, most), "a slot is bought")
	check(upgrades.buy_slot(MOTES_STARTER, wallet, most), "and a second")
	check(upgrades.buy_slot(MOTES_STARTER_TWO, wallet, AdventureLoadout.max_slots_for(MOTES_STARTER_TWO)),
		"a second starter buys its own slot")
	eq(wallet.ledger[wallet.ledger.size() - 1]["reason"], AdventureWallet.REASON_SLOT,
		"every purchase leaves a ledger line")
	check(upgrades.save(), "the upgrades write to disk")
	var loaded: AdventureUpgrades = AdventureUpgrades.load_upgrades()
	eq(loaded.slots(MOTES_STARTER), 2, "the slot count came back an int")
	eq(loaded.slots(MOTES_STARTER_TWO), 1, "each starter keeps its own")
	eq(loaded.all_starters(), upgrades.all_starters(), "the rows came back whole")
	eq(int(upgrades.to_dict()["version"]), AdventureUpgrades.SAVE_VERSION, "written at the current version")
	wallet.earn(1000000, AdventureWallet.REASON_STAGE)
	for _i in range(most + 3):
		upgrades.buy_slot(MOTES_STARTER, wallet, most)
	eq(upgrades.slots(MOTES_STARTER), most, "slots stop where the card maximum does")
	eq(upgrades.next_slot_cost(MOTES_STARTER, most), 0, "with nothing left to buy either")
	check(upgrades.next_slot_cost(MOTES_STARTER, -1) > 0,
		"though a caller with no deck to measure against is not stopped")
	# The whole track is a long-term goal: the last slot alone is worth several full wins.
	# The richest full win fights five duels in every act.
	var richest: int = AdventureEconomy.completion_bonus()
	for act in range(1, 4):
		richest += 5 * AdventureEconomy.duel_payout(act, false) + AdventureEconomy.duel_payout(act, true)
	check(AdventureEconomy.slot_cost(most) > richest * 2, "the last slot costs more than two of the richest full wins")
	AdventureUpgrades.clear()
	check(not AdventureUpgrades.exists(), "clear removes the file")
	AdventureUpgrades.path_override = ""


# --- Pending queue and the quiet beats -----------------------------------

## `SeatView.pending` is an ordering contract: the engine resolves the queue top to bottom, and a
## "then" list inserted at the front of the queue jumps ahead of what it interrupted.
func test_the_pending_queue_lists_what_resolves_next_in_order() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler()))
	to_combat(e)
	check(e.pending_items().is_empty(), "nothing is pending at an attack prompt")
	var waiting: CardInstance = inject(e, 0, "t_strike")
	var later: Array[Dictionary] = [{"trigger": "on_attack", "op": "fervor", "amount": 1}]
	e._queue.append({"effects": later, "index": 0, "trigger": "on_attack", "owner": 0, "ctx": {}, "source": waiting})
	var jumper: CardInstance = inject(e, 0, "t_art")
	e._pending_then = {"effects": [{"op": "fervor", "amount": 1}], "owner": 0, "ctx": {}, "source": jumper}
	check(e._flush_then(), "the then list becomes a job of its own")
	var pending: Array[Dictionary] = e.pending_items()
	eq(pending.size(), 2, "both jobs are pending")
	eq(StringName(pending[0]["kind"]), &"trigger", "a queued job reads as a trigger")
	eq(int(pending[0]["uid"]), jumper.uid, "the then job inserted at the front resolves first")
	eq(int(pending[1]["uid"]), waiting.uid, "the job it interrupted comes after it")
	check(bool(pending[0]["current"]) and not bool(pending[1]["current"]), "only the front job is current")
	eq(str(pending[0]["note"]), CardText.trigger_phrase("then"), "the note words the trigger")
	eq(str(pending[1]["title"]), e.card(waiting.uid).def.title, "and a public job is named")
	var v: SeatView = SeatView.of(e, 0)
	eq(v.pending.size(), 2, "the view carries both in the same order")
	eq(int(v.pending[0]["uid"]), jumper.uid, "front first")
	var wire: SeatView = SeatView.from_dict(JSON.parse_string(JSON.stringify(v.to_dict())))
	eq(int(wire.pending[0]["uid"]), jumper.uid, "and the order survives the wire")
	eq(StringName(wire.pending[0]["kind"]), &"trigger", "with its kind intact")
	eq(int(wire.pending[1]["owner"]), 0, "and its owner")


## A seat is told that something of the rival's is queued, never what it is.
func test_a_pending_job_the_seat_cannot_see_reads_as_hidden() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler()))
	to_combat(e)
	var theirs: CardInstance = to_hand(e, 1, "t_taunt")
	var lines: Array[Dictionary] = [{"trigger": "secondary", "op": "fervor", "amount": 1}]
	e._queue.append({"effects": lines, "index": 0, "trigger": "secondary", "owner": 1, "ctx": {}, "source": theirs})
	var owner_view: SeatView = SeatView.of(e, 1)
	eq(owner_view.pending.size(), 1, "the owner sees the job")
	eq(StringName(owner_view.pending[0]["kind"]), &"trigger", "as their own card")
	eq(str(owner_view.pending[0]["title"]), "Test Taunt", "named for them")
	var rival: SeatView = SeatView.of(e, 0)
	eq(StringName(rival.pending[0]["kind"]), &"hidden", "the rival sees only that something is queued")
	eq(int(rival.pending[0]["uid"]), -1, "with no uid to look up")
	eq(str(rival.pending[0]["title"]), "", "no title")
	eq(str(rival.pending[0]["note"]), "", "and no trigger to read it from")
	eq(int(rival.pending[0]["owner"]), 1, "though whose it is stays public")
	check(bool(rival.pending[0]["current"]), "and the fact that it is resolving now stays public too")


## Mid-damage the queue carries the attack that is landing and the wounds it still owes, with
## `current` on the wounds, because that is the loop the engine is actually standing in.
func test_the_pending_queue_shows_the_attack_and_the_wounds_it_is_still_flipping() -> void:
	var e: DuelEngine = engine(deck(filler(["t_art", "t_art", "t_art"])),
			deck(filler(["t_parry", "t_parry", "t_parry", "t_strike_endure"]), "pact", "tide", "t_mastery_tide"))
	to_combat(e)
	answer(e, &"attack", uid_in_hand(e, 0, "t_art"))
	eq(prompt_kind(e), &"endurance", "the life-damage loop pauses on Endurance")
	var v: SeatView = SeatView.of(e, 1)
	var kinds: Array = []
	for item in v.pending:
		kinds.append(StringName(item["kind"]))
	check(kinds.has(&"attack") and kinds.has(&"wounds"), "the attack and the wounds it still owes are both listed")
	check(kinds.find(&"attack") < kinds.find(&"wounds"), "the attack heads the queue and the wounds close it")
	var attack_item: Dictionary = v.pending[kinds.find(&"attack")]
	var wounds_item: Dictionary = v.pending[kinds.find(&"wounds")]
	eq(int(attack_item["target"]), v.player(1).controlling, "the attack points at the defender's fighter")
	eq(int(attack_item["owner"]), 0, "and belongs to the attacker")
	eq(int(wounds_item["target"]), v.player(1).controlling, "the wounds land on the same fighter")
	var left: int = int(e.state.attack["life_remaining"])
	eq(str(wounds_item["note"]), "%d wound%s" % [left, "" if left == 1 else "s"], "the note counts what is left")
	check(bool(wounds_item["current"]), "the engine is standing in the wound loop")
	check(not bool(attack_item["current"]), "not on the declaration that started it")


## A counter window the rival could not have used is still a beat, not silence.
func test_a_response_window_with_nothing_in_it_still_says_so() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler()))
	var seat: int = e.state.active
	to_hand(e, seat, "t_taunt")
	to_combat(e)
	e.events.clear()
	answer(e, &"use", uid_in_hand(e, seat, "t_taunt"))
	var skipped: Dictionary = {}
	for ev in e.events:
		if ev.type == &"window_skipped" and str(ev.data.get("window", "")) == "respond":
			skipped = ev.data
			break
	check(not skipped.is_empty(), "the rival's empty counter window is an event")
	eq(int(skipped.get("player", -1)), 1 - seat, "and it names the seat that had nothing to answer with")
	eq(Referee.ANIMATED.has(&"window_skipped"), true, "so a client can show the window opening and closing")


## The quiet windows reach a client as data with their keys, not as a log line alone.
func test_the_quiet_combat_beats_reach_the_client_as_events() -> void:
	for t in [&"pass", &"attack_phase_skipped", &"entering_combat", &"combat_declared", &"combat_skipped",
			&"no_defense", &"declined_counter", &"control", &"power_used", &"relic_used",
			&"turn_start", &"turn_end", &"recover_step", &"window_skipped"]:
		check(Referee.ANIMATED.has(t), "%s is animated" % t)
	eq(Referee.ANIMATED[&"no_defense"], ["auto", "reason"], "no_defense carries both of its keys")
	var e: DuelEngine = engine(deck(filler()), deck(filler()))
	var seat: int = e.state.active
	to_hand(e, seat, "t_art")
	var r: Referee = Referee.new()
	r.engine = e
	to_combat(e)
	r.take_updates()
	answer(e, &"attack", uid_in_hand(e, seat, "t_art"))
	var updates: Array[SeatUpdate] = r.take_updates()
	var data: Dictionary = {}
	for line in updates[0].lines:
		if str(line.get("type", "")) == "no_defense":
			data = line.get("data", {})
	check(data.has("auto") and data.has("reason"), "a defender with nothing to play reaches both seats as data")
	eq(bool(data["auto"]), true, "the engine made the call")
	eq(str(data["reason"]), "none", "and says why there was no defense")


## A wound used to arrive as a card move and then the wound event for the same card, so the
## client flew the card to the pile twice. The move stays quiet; the wound event is the beat.
func test_a_lost_life_card_reaches_the_client_once() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler()))
	var seat: int = e.state.active
	to_hand(e, seat, "t_art")
	var r: Referee = Referee.new()
	r.engine = e
	to_combat(e)
	r.take_updates()
	answer(e, &"attack", uid_in_hand(e, seat, "t_art"))
	var updates: Array[SeatUpdate] = r.take_updates()
	var wounded: Array[int] = []
	var moved: Array[int] = []
	for line in updates[0].lines:
		var data: Dictionary = line.get("data", {})
		match str(line.get("type", "")):
			"life_card_flipped", "life_card_lost":
				wounded.append(int(data.get("card", -1)))
			"card_moved":
				moved.append(int(data.get("card", -1)))
	check(wounded.size() > 0, "the unanswered Art costs at least one life card")
	for uid in wounded:
		check(not moved.has(uid), "the lost card %d is not also reported as a card move" % uid)


## "Cannot be stopped" used to open the defense window anyway and preview the stop as if it
## would land. Now the window is skipped with its own reason and no preview can say stopped.
func test_an_unstoppable_attack_offers_no_defense() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler()))
	var seat: int = e.state.active
	to_hand(e, seat, "t_art_unstoppable")
	to_hand(e, 1 - seat, "t_ward")
	var r: Referee = Referee.new()
	r.engine = e
	to_combat(e)
	r.take_updates()
	answer(e, &"attack", uid_in_hand(e, seat, "t_art_unstoppable"))
	check(prompt_kind(e) != &"defense", "the holder of a matching stop card is not asked to defend")
	var reason: String = ""
	for line in r.take_updates()[1 - seat].lines:
		if str(line.get("type", "")) == "no_defense":
			reason = str(line.get("data", {}).get("reason", ""))
	eq(reason, "unstoppable", "and the skipped window says why")
	var landed: Dictionary = e.state.attack if not e.state.attack.is_empty() else e.state.last_attack
	eq(bool(landed.get("stopped", true)), false, "the attack lands")


## Two passes in a row end Combat, so the count is worth showing before the second one.
func test_the_view_counts_the_passes_that_would_end_combat() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler()))
	to_combat(e)
	var v: SeatView = SeatView.of(e, 0)
	eq(v.consecutive_passes, 0, "nobody has passed yet")
	answer(e, &"pass")
	var after: SeatView = SeatView.of(e, 0)
	eq(after.consecutive_passes, 1, "one pass stands, so the next one ends Combat")
	eq(SeatView.from_dict(after.to_dict()).consecutive_passes, 1, "the count goes over the wire")


## The first attacker is named from the moment Combat is being prepared: combat_begin carries it,
## and the view shows the active player as the attacker through the prepare phases.
func test_the_first_attacker_is_named_as_combat_opens() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler()))
	to_combat(e)
	var begin_attacker: int = -1
	for ev in e.take_events():
		if ev.type == &"combat_begin":
			begin_attacker = int(ev.data.get("attacker", -1))
	eq(begin_attacker, e.state.active, "combat_begin names the first attacker")
	e.state.phase = GameState.Phase.PREPARE_ACTIVE
	e.state.attacker = 1 - e.state.active
	eq(SeatView.of(e, 0).attacker, e.state.active, "while Combat is prepared the active player shows as the attacker")


## The client's Combat tracker reads each beat's own stamp, so a beat must carry the phase it
## belongs to rather than the phase the engine has already moved on to. One attack and its answer
## reads ATTACK on the declaration, DEFEND on the defense window, BATTLE through the damage, then
## FIGHT_BACK as the exchange changes hands and ATTACK again with the other seat attacking.
func test_combat_beats_are_stamped_with_the_phase_they_belong_to() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
	e.record_display_state = true
	to_combat(e)
	e.take_events()
	var attacker_before: int = e.state.attacker
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike"))
	var order: Array[StringName] = []
	var phases: Dictionary = {}
	var battles: int = 0
	var defends: int = 0
	for ev in e.take_events():
		if ev.type == &"prompt":
			continue   # the decision that follows the exchange, not a beat inside it
		check(not ev.state.is_empty(), "every combat beat carries a display stamp: %s" % ev.type)
		var phase: int = int(ev.state.get("phase", -1))
		order.append(ev.type)
		phases[ev.type] = phase
		if phase == GameState.Phase.DEFEND:
			defends += 1
		if phase == GameState.Phase.BATTLE:
			battles += 1
	check(order.has(&"attack_declared"), "the attack is declared")
	eq(phases.get(&"attack_declared", -1), GameState.Phase.ATTACK, "the declaration is stamped with the attack phase, not the battle that follows it")
	check(defends >= 1, "the defense window gets at least one beat stamped DEFEND")
	eq(phases.get(&"no_defense", GameState.Phase.DEFEND), GameState.Phase.DEFEND, "an undefended attack says so during DEFEND")
	eq(phases.get(&"base_damage", -1), GameState.Phase.BATTLE, "base damage is a battle beat")
	eq(phases.get(&"modified_damage", -1), GameState.Phase.BATTLE, "modified damage is a battle beat")
	check(battles >= 2, "the battle sequence reaches the client as more than one beat")
	eq(phases.get(&"fight_back", -1), GameState.Phase.FIGHT_BACK, "the hand-over is its own beat, stamped FIGHT_BACK")
	eq(order.back(), &"fight_back", "the hand-over is the last beat of the exchange")
	eq(e.state.phase, GameState.Phase.ATTACK, "the exchange settles back on an attack phase")
	eq(e.state.attacker, 1 - attacker_before, "and the other seat is the one attacking")


## The readout carries its own baseline, so a client colours the number without doing rules maths.
## Nothing in the rules modifies a printed Might today, so the whole of the Might swing is the
## Energy stage the fighter stands on; `might_printed` is the same ladder read at the Energy the
## personality takes the field on.
func test_the_fighters_numbers_carry_their_printed_baseline() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler()))
	to_combat(e)
	var duelist: CardInstance = e.player(0).duelist
	var v: SeatView = SeatView.of(e, 0)
	eq(v.player(0).energy, duelist.energy, "the view carries the fighter's live Energy")
	eq(v.player(0).energy_printed, DuelEngine.STARTING_ENERGY, "against the Energy a Duelist opens on")
	eq(v.player(0).energy_delta, duelist.energy - DuelEngine.STARTING_ENERGY, "the delta is the difference and nothing else")
	eq(v.player(0).might, duelist.might(), "and the Might it fights at")
	eq(v.player(0).might_printed, duelist.might_at(DuelEngine.STARTING_ENERGY), "against the printed Might at that stage")
	var baseline: int = v.player(0).might_printed
	duelist.energy = 2
	var hurt: SeatPlayer = SeatView.of(e, 0).player(0)
	eq(hurt.energy_delta, 2 - DuelEngine.STARTING_ENERGY, "a spent Duelist reads below its baseline")
	check(hurt.might_delta < 0, "and its Might reads below the printed number with it")
	eq(hurt.might, hurt.might_printed + hurt.might_delta, "effective is always printed plus delta")
	eq(hurt.might_printed, baseline, "while the baseline itself does not move")
	duelist.energy = 9
	var risen: SeatPlayer = SeatView.of(e, 0).player(0)
	check(risen.might_delta > 0 and risen.energy_delta > 0, "a Duelist above its baseline reads above it")
	var wire: SeatPlayer = SeatPlayer.from_dict(risen.to_dict())
	eq(wire.might_delta, risen.might_delta, "the baseline and the delta go over the wire")
	eq(wire.energy_printed, risen.energy_printed, "both of them")


# --- Presence -----------------------------------------------------------------

func test_presence_keeps_only_known_keys_with_the_right_types() -> void:
	var clean: Dictionary = PresenceState.sanitise({"on": true, "x": 1.0, "z": -1.0, "card": 12,
		"def": "tf_vigil_1", "title": "Test Vigil", "uid": 44, "cards": [1, 2, 3]})
	eq(clean.keys().size(), PresenceState.KEYS.size(), "the output carries exactly the allowed keys")
	for key in clean.keys():
		check(PresenceState.KEYS.has(key), "no unknown key survives (%s)" % str(key))
	check(not clean.has("def") and not clean.has("title"), "a card id or title riding along is dropped")
	eq(int(clean["card"]), 12, "an allowed uid stays")
	eq(PresenceState.sanitise({"on": "yes"}), {}, "a string where a bool belongs rejects the payload")
	eq(PresenceState.sanitise({"on": true, "x": "1.0"}), {}, "a string coordinate rejects it")
	eq(PresenceState.sanitise({"card": 3.5}), {}, "a float uid rejects it")
	eq(PresenceState.sanitise({"on": true, "x": NAN}), {}, "a NaN coordinate rejects it")
	eq(PresenceState.sanitise([1, 2]), {}, "anything but a dictionary is nothing")
	eq(PresenceState.sanitise("hello"), {}, "a bare string is nothing")
	var flood: Dictionary = {}
	for i in range(PresenceState.MAX_RAW_KEYS + 1):
		flood["k%d" % i] = i
	eq(PresenceState.sanitise(flood), {}, "an oversized payload is not even read")
	eq(PresenceState.sanitise({}), PresenceState.idle(), "an empty payload reads as idle")


func test_presence_clamps_the_pointer_and_the_hand_slot() -> void:
	var bounds: Rect2 = PresenceState.TABLE_BOUNDS
	var far: Dictionary = PresenceState.sanitise({"on": true, "x": 999.0, "z": -999})
	eq(float(far["x"]), bounds.end.x, "x is clamped to the table edge")
	eq(float(far["z"]), bounds.position.y, "z is clamped to the other edge, and an int is accepted")
	var off: Dictionary = PresenceState.sanitise({"on": false, "x": 2.0, "z": 1.0})
	eq(float(off["x"]), 0.0, "a pointer off the table carries no point")
	eq(int(PresenceState.sanitise({"hand": PresenceState.MAX_HAND_SLOT + 1})["hand"]), -1, "a slot past the range is dropped")
	eq(int(PresenceState.sanitise({"hand": -5})["hand"]), -1, "a negative slot is dropped")
	eq(int(PresenceState.sanitise({"hand": 3})["hand"]), 3, "a sane slot stays")
	eq(int(PresenceState.sanitise({"card": PresenceState.MAX_UID + 1})["card"]), -1, "an absurd uid is dropped")
	eq(int(PresenceState.sanitise({"look": "pile", "seat": 7, "zone": "discard"})["seat"]), -1, "a pile of no seat is dropped")
	eq(str(PresenceState.sanitise({"look": "pile", "seat": 7, "zone": "discard"})["look"]), "", "and so is the look")


func test_presence_hand_hover_is_a_slot_and_nothing_else() -> void:
	var clean: Dictionary = PresenceState.sanitise({"hand": 2, "card": 41, "def": "tf_vigil_1"})
	eq(int(clean["hand"]), 2, "the slot index goes through")
	eq(int(clean["card"]), -1, "a card uid sent with a hand hover is stripped")
	check(not clean.has("def"), "and no card id rides with it")
	# The sender's side: a card in its own hand or Reserve is visible to it but never public.
	var e: DuelEngine = engine(deck(filler()), deck(filler()))
	to_combat(e)
	var mine: SeatView = SeatView.of(e, 0)
	var own_hand: int = mine.player(0).hand[0]
	check(not mine.card(own_hand).hidden(), "the sender sees its own hand card")
	check(not PresenceState.is_public(mine.card(own_hand)), "but it is not public, so it is never named")
	check(PresenceState.is_public(mine.card(mine.player(1).duelist)), "the rival's duelist is public")


func test_presence_never_names_a_card_the_receiver_cannot_see() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler()))
	to_combat(e)
	var receiver: SeatView = SeatView.of(e, 1)
	var hidden_uid: int = receiver.player(0).hand[0]
	var life_uid: int = receiver.player(0).life_deck[0]
	var duelist: int = receiver.player(0).duelist
	check(receiver.card(hidden_uid).hidden(), "the sender's hand card is hidden from the receiver")
	var forged: Dictionary = PresenceState.sanitise({"card": hidden_uid, "look": "inspect", "look_card": life_uid})
	var shown: Dictionary = PresenceState.for_view(forged, receiver)
	eq(int(shown["card"]), -1, "a hidden hand card's uid is stripped")
	eq(int(shown["look_card"]), -1, "a Life Deck card being inspected is stripped")
	eq(str(shown["look"]), "", "and the inspect becomes nothing")
	var fair: Dictionary = PresenceState.for_view(PresenceState.sanitise({"card": duelist, "look": "inspect", "look_card": duelist}), receiver)
	eq(int(fair["card"]), duelist, "a public card stays")
	eq(str(fair["look"]), "inspect", "and so does an inspect of it")
	eq(int(PresenceState.for_view(PresenceState.sanitise({"card": 999999}), receiver)["card"]), -1, "an unknown uid is stripped")


func test_presence_caps_strings_and_refuses_unknown_looks() -> void:
	var long: String = "discard".repeat(2000)
	var clean: Dictionary = PresenceState.sanitise({"look": long, "zone": long, "seat": 0})
	for key in clean.keys():
		if clean[key] is String:
			check((clean[key] as String).length() <= PresenceState.MAX_TEXT, "no string over the cap survives (%s)" % str(key))
	eq(str(clean["look"]), "", "an oversized look is refused")
	eq(str(PresenceState.sanitise({"look": "Inspecting Test Card"})["look"]), "", "free text is never a look")
	var pile: Dictionary = PresenceState.sanitise({"look": "pile", "seat": 1, "zone": "relic"})
	eq(str(pile["look"]), "pile", "a known pile look stays")
	eq(str(pile["zone"]), "relic", "with its zone")
	eq(str(PresenceState.sanitise({"look": "pile", "seat": 1, "zone": "life_deck"})["look"]), "", "a pile that is not public is refused")
	eq(PresenceState.sanitise({"look": 5}), {}, "a number where text belongs rejects the payload")


# --- The Pyre expansion ---------------------------------------------------

## A shipped card straight into a discard pile, on top.
func real_to_discard(e: DuelEngine, player: int, id: String) -> CardInstance:
	var c: CardInstance = e._instance(shipped().get_def(id), player, &"discard")
	e.player(player).discard.append(c)
	return c


## "+X, X = your Fervor" is read as the attack is worked out, and "your Fervor may not be lowered"
## holds against every lowering, the player's own included.
func test_pyre_rising_heat_reads_fervor_and_banked_coals_holds_it() -> void:
	var e: DuelEngine = real_engine(real_deck([], "pact", "pyre"), real_deck([], "vigil"))
	var me: PlayerState = e.player(0)
	var heat: CardInstance = real_inject(e, 0, "pyre_drill_01")
	var m: Dictionary = heat.def.modifiers[0]
	me.fervor = 3
	eq(e._modifier_amount(m, "stages", me), 3, "Fervor 3 makes it +3 Energy")
	me.fervor = 0
	eq(e._modifier_amount(m, "stages", me), 0, "and Fervor 0 makes it nothing")
	check(CardText.rules_text(heat.def).contains("+X Energy, X = your Fervor"), "it prints as X: %s" % CardText.rules_text(heat.def))
	real_inject(e, 0, "pyre_drill_02")
	me.fervor = 3
	e._apply_effect({"op": "fervor", "who": "opponent", "amount": -2}, 1, {}, null)
	eq(me.fervor, 3, "the opponent's card cannot lower it")
	e._change_fervor(me, -1, 0)
	eq(me.fervor, 3, "nor can the player's own")
	e._set_fervor(me, 0, 1)
	eq(me.fervor, 3, "and a reset is a lowering too")
	e._change_fervor(me, 1, 0)
	eq(me.fervor, 4, "raising it still works")


## "When your duelist advances an Aspect, your other Drills are not discarded. If your opponent's
## Fervor is 0, this Drill is not discarded either." A lost Aspect still clears them all.
func test_pyre_hearthstone_keeps_drills_through_a_climb_only() -> void:
	var e: DuelEngine = real_engine(real_deck([], "pact", "pyre"), real_deck([], "vigil"))
	var me: PlayerState = e.player(0)
	var hearth: CardInstance = real_inject(e, 0, "pyre_drill_06")
	var kiln: CardInstance = real_inject(e, 0, "pyre_drill_07")
	e.player(1).fervor = 1
	e._aspect_up(me)
	eq(kiln.zone, &"in_play", "the other Drill survives the climb")
	eq(hearth.zone, &"discard", "the Hearthstone goes, because their Fervor is not 0")
	var second: CardInstance = real_inject(e, 0, "pyre_drill_06")
	e.player(1).fervor = 0
	e._aspect_up(me)
	eq(second.zone, &"in_play", "at their Fervor 0 the Hearthstone stays as well")
	eq(kiln.zone, &"in_play", "and so does the other Drill")
	e._lose_aspect(me, 1)
	eq(kiln.zone, &"discard", "losing an Aspect still clears the Drills")
	eq(second.zone, &"discard", "the Hearthstone with them")


## Endurance X on a life card is its owner's Fervor, and an Art can add the attacker's Fervor in
## wounds. The CRD takes away Red Arm Cannon's "shuffle into your Life Deck", so it is discarded.
func test_pyre_endurance_x_and_drawing_flue_read_fervor() -> void:
	var e: DuelEngine = real_engine(real_deck(["pyre_art_04"], "pact", "pyre"), real_deck([], "vigil"))
	var hide: CardInstance = real_to_deck(e, 1, "pyre_strike_22")
	e.player(1).fervor = 4
	eq(e._endurance_value(hide, e.player(1)), 4, "Endurance X at Fervor 4 is 4")
	e.player(1).fervor = 0
	eq(e._endurance_value(hide, e.player(1)), 0, "and at Fervor 0 it is nothing")
	check(CardText.rules_text(hide.def).contains("Endurance X. X = your Fervor."), "it prints as X")
	to_attack(e, 0)
	e.player(0).fervor = 3
	var flue: int = uid_in_hand(e, 0, "pyre_art_04")
	var before: int = e.player(1).life_deck.size()
	answer(e, &"attack", flue)
	settle(e, 8)
	eq(before - e.player(1).life_deck.size(), 4, "1 wound plus 3 for Fervor 3")
	eq(e.card(flue).zone, &"discard", "and the card is discarded like any other")


## "Your opponent cannot use Endurance against your Pyre attacks": the bar names a school, so a
## card of another school still meets the Endurance.
func test_pyre_burned_through_bars_endurance_against_pyre_only() -> void:
	var e: DuelEngine = real_engine(real_deck(["pyre_art_05"], "pact", "pyre"), real_deck([], "vigil"))
	var plain: CardInstance = real_to_hand(e, 0, "root_strike_04")
	to_attack(e, 0)
	var through: int = uid_in_hand(e, 0, "pyre_art_05")
	check(not e._endurance_barred(e.player(1), {"source": through}), "nothing bars it yet")
	answer(e, &"attack", through)
	settle(e, 8)
	check(e._has_floating_school(1, "no_endurance", "pyre"), "the bar sits on the defender")
	check(e._endurance_barred(e.player(1), {"source": through}), "a Pyre attack meets no Endurance")
	check(not e._endurance_barred(e.player(1), {"source": plain.uid}), "a Root one still does")
	eq(e.player(0).fervor, 2, "and the hit raised the attacker's Fervor 2")


## "You may discard a card from your hand when you perform this attack for +3 wounds": asked, and
## the card is the attacker's pick. Remain 2 keeps the Art out for two more uses.
func test_pyre_flare_volley_may_discard_a_card_for_more_wounds() -> void:
	var e: DuelEngine = real_engine(real_deck(["pyre_art_06"], "pact", "pyre"), real_deck([], "vigil"))
	var me: PlayerState = e.player(0)
	to_attack(e, 0)
	var volley: int = uid_in_hand(e, 0, "pyre_art_06")
	var before: int = e.player(1).life_deck.size()
	var held: int = me.hand.size()
	answer(e, &"attack", volley)
	eq(prompt_kind(e), &"pay", "the optional discard is asked")
	check(e.prompt.find(&"pay_hand", -1, 0) != null, "and it may be turned down")
	answer(e, &"pay_hand", -1, 1)
	eq(prompt_kind(e), &"discard_choice", "the attacker picks the card")
	answer(e, &"discard_choice", me.hand[0].uid)
	settle(e, 8)
	eq(before - e.player(1).life_deck.size(), 5, "2 wounds plus 3 for the card")
	eq(me.hand.size(), held - 2, "the Art and one card left the hand")
	eq(e.card(volley).zone, &"in_play", "Remain 2 keeps it on the table")
	eq(e.card(volley).remain, 2, "for two more uses")


## Wounds that leave the game instead of reaching the pile, and a draw off the bottom of the deck.
func test_pyre_white_flame_removes_its_wounds_and_draws_from_the_bottom() -> void:
	var e: DuelEngine = real_engine(real_deck(["pyre_art_11"], "pact", "pyre"), real_deck([], "vigil"))
	var low: CardInstance = real_to_deck(e, 0, "pyre_drill_05")
	to_attack(e, 0)
	var flame: int = uid_in_hand(e, 0, "pyre_art_11")
	var removed: int = e.player(1).removed.size()
	var piled: int = e.player(1).discard.size()
	answer(e, &"attack", flame)
	settle(e, 8)
	eq(e.player(1).removed.size() - removed, 6, "all six wounds left the game")
	eq(e.player(1).discard.size(), piled, "none reached the discard pile")
	eq(low.zone, &"hand", "the bottom card of the Life Deck was drawn")
	eq(e.card(flame).zone, &"removed", "and the Art removed itself after use")


## "6 wounds or lower their duelist an Aspect": the Aspect is taken in place of the damage.
func test_pyre_unmaking_blaze_trades_its_damage_for_an_aspect() -> void:
	var e: DuelEngine = real_engine(real_deck(["pyre_art_10"], "pact", "pyre"), real_deck([], "vigil"))
	var them: PlayerState = e.player(1)
	e._aspect_up(them)
	eq(them.duelist.aspect, 2, "their duelist starts one Aspect up")
	to_attack(e, 0)
	var before: int = them.life_deck.size()
	answer(e, &"attack", uid_in_hand(e, 0, "pyre_art_10"))
	settle(e, 4)
	eq(prompt_kind(e), &"pick_option", "the trade is offered once the Art is through")
	answer(e, &"pick_option", -1, "yes")
	settle(e, 8)
	eq(them.duelist.aspect, 1, "their duelist dropped an Aspect")
	eq(them.life_deck.size(), before, "in place of the six wounds")


## "Stops an Art. If your Fervor is 1 or more, stops every Art for the rest of Combat."
func test_pyre_heat_haze_stops_every_art_once_fervor_is_up() -> void:
	for fervor in [1, 0]:
		var e: DuelEngine = real_engine(real_deck(["pyre_art_08"], "pact", "pyre"), real_deck([], "vigil", "pyre"))
		var haze: CardInstance = real_to_hand(e, 1, "pyre_strike_27")
		e.player(1).fervor = fervor
		to_attack(e, 0)
		answer(e, &"attack", uid_in_hand(e, 0, "pyre_art_08"))
		eq(prompt_kind(e), &"defense", "the defender may answer the Art")
		answer(e, &"defend", haze.uid)
		check(has_event(e, &"attack_stopped"), "the Art was stopped at Fervor %d" % fervor)
		eq(e._has_floating(1, "stop_all"), fervor >= 1, "every later Art is stopped only with Fervor up (%d)" % fervor)
		eq(haze.zone, &"removed", "and the card left the game")


## "Lower their Fervor 1. If it is then 1 or lower, remove the bottom 10 cards of their pile."
func test_pyre_choking_smoke_burns_their_pile_at_low_fervor() -> void:
	for start in [0, 3]:
		var e: DuelEngine = real_engine(real_deck(["pyre_art_08"], "pact", "pyre"), real_deck([], "vigil", "pyre"))
		var me: PlayerState = e.player(0)
		var smoke: CardInstance = real_to_hand(e, 1, "pyre_strike_23")
		to_attack(e, 0)
		var bottom: Array[CardInstance] = []
		for i in range(12):
			bottom.append(real_to_discard(e, 0, "root_strike_04"))
		me.fervor = start
		answer(e, &"attack", uid_in_hand(e, 0, "pyre_art_08"))
		answer(e, &"defend", smoke.uid)
		settle(e, 6)
		var burned: int = 0
		for c in bottom:
			if c.zone == &"removed":
				burned += 1
		# The Art raised its user's Fervor 1 before the block took 1 back off.
		eq(me.fervor, start, "the block lowered the Fervor again (start %d)" % start)
		eq(burned, 10 if start <= 1 else 0, "the bottom 10 burn only at Fervor 1 or lower (start %d)" % start)
		if start <= 1:
			eq(bottom[10].zone, &"discard", "the top of the pile is left alone")


## "Discard your hand to stop a Strike or an Art. You must have a card in hand."
func test_pyre_burnt_offering_drill_spends_the_whole_hand() -> void:
	var e: DuelEngine = real_engine(real_deck([], "pact"), real_deck([], "vigil", "pyre"))
	var offering: CardInstance = real_inject(e, 1, "pyre_drill_03")
	to_attack(e, 0)
	check(not e.player(1).hand.is_empty(), "the defender holds cards")
	answer(e, &"attack", uid_in_hand(e, 0, "root_strike_04"))
	eq(prompt_kind(e), &"defense", "the defender may answer")
	check(e.prompt.find(&"defend", offering.uid) != null, "the Drill is offered")
	answer(e, &"defend", offering.uid)
	settle(e, 4)
	check(has_event(e, &"attack_stopped"), "the Strike was stopped")
	eq(e.player(1).hand.size(), 0, "the whole hand went")
	eq(offering.zone, &"in_play", "and the Drill stays in play")
	var f: DuelEngine = real_engine(real_deck([], "pact"), real_deck([], "vigil", "pyre"))
	var empty: CardInstance = real_inject(f, 1, "pyre_drill_03")
	to_attack(f, 0)
	for c in f.player(1).hand.duplicate():
		f._move_to_discard(c)
	answer(f, &"attack", uid_in_hand(f, 0, "root_strike_04"))
	check(not (prompt_kind(f) == &"defense" and f.prompt.find(&"defend", empty.uid) != null), "with no cards in hand it is not offered")


## "Once per Combat, after performing a successful physical attack, you may choose 1 non-Red Style
## card in your discard pile and shuffle it into your Life Deck" (CRD errata to Red Hunting Drill).
func test_pyre_cinder_sift_drill_buys_a_card_back_on_a_landed_strike() -> void:
	var e: DuelEngine = real_engine(real_deck([], "pact", "pyre"), real_deck([], "vigil"))
	var sift: CardInstance = real_inject(e, 0, "pyre_drill_04")
	to_attack(e, 0)
	# Laid down after entering Combat: the duelist's own power draws off the discard pile there.
	var pyre_card: CardInstance = real_to_discard(e, 0, "pyre_art_08")
	var spent: CardInstance = real_to_discard(e, 0, "tide_drill_05")
	var strike: int = uid_in_hand(e, 0, "root_strike_04")
	answer(e, &"attack", strike)
	settle(e, 6)
	eq(prompt_kind(e), &"pick_option", "the landed Strike offers the Drill")
	answer(e, &"pick_option", -1, "yes")
	# "After performing" the attack: its own card is already in the pile and may be the one taken.
	eq(prompt_kind(e), &"pick_option", "the pile is offered")
	check(e.prompt.find(&"pick_option", strike) != null, "the Strike just performed is in the pile already")
	check(e.prompt.find(&"pick_option", pyre_card.uid) == null, "a Pyre card is not offered")
	answer(e, &"pick_option", spent.uid)
	settle(e, 6)
	eq(spent.zone, &"life_deck", "the card went back into the Life Deck")
	eq(sift.power_used_combat, e.state.combat_count, "and the Drill is spent for this Combat")


## "Your duelist pays 5 Energy: discard every Ally and Non-Combat card in play, their duelist's
## Energy to 0, Fervor +1." Both sides of the table go.
func test_pyre_conflagration_clears_both_tables() -> void:
	var e: DuelEngine = real_engine(real_deck(["pyre_combat_02"], "pact", "pyre"), real_deck([], "vigil"))
	var me: PlayerState = e.player(0)
	var fire: CardDef = shipped().get_def("pyre_combat_02")
	var mine: CardInstance = real_inject(e, 0, "pyre_drill_07")
	var theirs: CardInstance = real_inject(e, 1, "storm_drill_01")
	to_attack(e, 0)
	me.duelist.energy = 4
	check(not e._can_play(me, fire), "at 4 Energy the card cannot be used")
	me.duelist.energy = 6
	check(e._can_play(me, fire), "at 6 it can")
	e._prompt_attack_action(me)
	answer(e, &"use", uid_in_hand(e, 0, "pyre_combat_02"))
	settle(e, 4)
	eq(mine.zone, &"discard", "the user's own Drill burned")
	eq(theirs.zone, &"discard", "and the opponent's")
	eq(me.duelist.energy, 0, "the duelist is left at 0 Energy")
	eq(me.fervor, 1, "and the Fervor went up 1")


## "Search your Life Deck for up to 5 Pyre Drills and put them into play."
func test_pyre_bonfire_puts_several_drills_into_play() -> void:
	var e: DuelEngine = real_engine(real_deck(["pyre_strike_24", "root_strike_04", "root_strike_04",
		"pyre_drill_05", "pyre_drill_07", "pyre_drill_08"], "pact", "pyre"), real_deck([], "vigil"))
	var me: PlayerState = e.player(0)
	to_attack(e, 0)
	answer(e, &"attack", uid_in_hand(e, 0, "pyre_strike_24"))
	eq(prompt_kind(e), &"pick_option", "the search is a prompt")
	var picks: Array = []
	for c in me.life_deck:
		if c.def.type == CardDef.Type.DRILL:
			picks.append(c.uid)
	eq(picks.size(), 3, "three Pyre Drills wait in the deck")
	check(e.submit(Command.new(0, &"pick_option", -1, picks)), "all three are taken at once")
	settle(e, 8)
	eq(me.drills().size(), 3, "and all three are in play")
	eq(me.fervor, 1, "the Fervor went up 1")


## "Entering Combat, you may remove the top card of your discard pile from the game. Your Strikes
## do +1 Energy this Combat, +3 if it was a Pyre card."
func test_pyre_tinder_mastery_burns_the_top_discard_for_strike_energy() -> void:
	var d: DeckList = real_deck([], "pact", "pyre")
	d.mastery_id = "pyre_mastery_03"
	var e: DuelEngine = real_engine(d, real_deck([], "vigil"))
	var me: PlayerState = e.player(0)
	var fuel: CardInstance = real_to_discard(e, 0, "pyre_art_08")
	var guard: int = 0
	while e.prompt != null and not (e.prompt.player == 0 and e.prompt.kind == &"pick_option") and guard < 12:
		guard += 1
		var quiet: Command = null
		for t in [&"done", &"declare", &"decline"]:
			quiet = e.prompt.find(t)
			if quiet != null:
				break
		if quiet == null:
			break
		e.submit(quiet)
	eq(prompt_kind(e), &"pick_option", "entering Combat asks whether to burn the top card")
	answer(e, &"pick_option", -1, "yes")
	eq(fuel.zone, &"removed", "the card left the game")
	var bonus: int = 0
	for entry in e._modifiers_for(me, "own", "strike", null, {}):
		bonus += int((entry["m"] as Dictionary).get("stages", 0))
	eq(bonus, 3, "a Pyre card buys +3 Energy on Strikes this Combat")


## "When you perform an Art, lower their Fervor 1. When they stop your Pyre Art, they discard the
## top 2 cards of their Life Deck."
func test_pyre_cinder_mastery_lowers_fervor_and_punishes_a_block() -> void:
	var d: DeckList = real_deck(["pyre_art_08"], "pact", "pyre")
	d.mastery_id = "pyre_mastery_04"
	var e: DuelEngine = real_engine(d, real_deck([], "vigil"))
	var ward: CardInstance = real_to_hand(e, 1, "pyre_strike_20")
	e.player(1).fervor = 2
	to_attack(e, 0)
	var deck_before: int = e.player(1).life_deck.size()
	answer(e, &"attack", uid_in_hand(e, 0, "pyre_art_08"))
	eq(e.player(1).fervor, 1, "performing an Art lowered their Fervor")
	answer(e, &"defend", ward.uid)
	settle(e, 6)
	check(has_event(e, &"attack_stopped"), "the Art was stopped")
	eq(deck_before - e.player(1).life_deck.size(), 2, "stopping a Pyre Art cost them the top 2 cards")


# --- Pyre review, 2026-09-23: every card against its printed text ---------

## "Cost 1 less, to a minimum of 1" lowers what is above the floor and never raises what is under it.
func test_a_cost_floor_never_raises_a_cheaper_attack() -> void:
	var e: DuelEngine = real_engine(real_deck([], "pact"), real_deck([], "vigil"))
	var me: PlayerState = e.player(0)
	e._float(0, "modifier", "combat", {"scope": "cost", "kind": "art", "stages": -1, "min": 1})
	eq(e._cost_stages(shipped().get_def("storm_art_14").attack, me), 0, "a free Art stays free")
	eq(e._cost_stages(shipped().get_def("pyre_art_08").attack, me), 1, "a 1-Energy Art stays at 1")
	eq(e._cost_stages(shipped().get_def("storm_art_22").attack, me), 1, "a 2-Energy Art drops to 1")


## "This card does not count towards or against the Styled Drills you can have in play."
func test_pyre_smoldering_drill_sits_outside_the_drill_school_lock() -> void:
	var e: DuelEngine = real_engine(real_deck([], "pact"), real_deck([], "vigil"))
	var me: PlayerState = e.player(0)
	real_inject(e, 0, "storm_drill_01")
	check(e._can_place(me, e._instance(shipped().get_def("pyre_drill_08"), 0, &"hand")), "it goes down beside a Storm Drill")
	check(not e._can_place(me, e._instance(shipped().get_def("pyre_drill_07"), 0, &"hand")), "another Pyre Drill does not")
	var f: DuelEngine = real_engine(real_deck([], "pact"), real_deck([], "vigil"))
	real_inject(f, 0, "pyre_drill_08")
	eq(f.player(0).drill_school(), "", "on its own it sets no school")
	check(f._can_place(f.player(0), f._instance(shipped().get_def("storm_drill_01"), 0, &"hand")), "so a Storm Drill may still follow it")


## "Stops all energy attacks for the rest of this combat": stopping is defense, so it covers the
## attacks against the user only, though no side is named.
func test_pyre_backdraft_stops_every_art_against_its_user() -> void:
	var e: DuelEngine = real_engine(real_deck(["pyre_strike_03"], "pact", "pyre"), real_deck([], "vigil"))
	to_attack(e, 0)
	answer(e, &"attack", uid_in_hand(e, 0, "pyre_strike_03"))
	settle(e, 8)
	check(e._has_floating(0, "stop_all"), "Arts against the user are stopped")
	check(not e._has_floating(1, "stop_all"), "the user's own Arts are not")
	check(not e._forbidden(e.player(0), "art_attacks"), "the user may still perform an Art")


## "Choose and remove one Non-Combat card in play": either side's.
func test_pyre_scouring_flame_reaches_either_side_of_the_table() -> void:
	var e: DuelEngine = real_engine(real_deck(["pyre_strike_05"], "pact", "pyre"), real_deck([], "vigil"))
	var mine: CardInstance = real_inject(e, 0, "pyre_drill_07")
	var theirs: CardInstance = real_inject(e, 1, "storm_drill_03")
	to_attack(e, 0)
	answer(e, &"attack", uid_in_hand(e, 0, "pyre_strike_05"))
	settle(e, 8)
	eq(prompt_kind(e), &"pick_in_play", "the pick is offered")
	check(e.prompt.find(&"pick_in_play", mine.uid) != null, "the user's own Non-Combat card is on the list")
	check(e.prompt.find(&"pick_in_play", theirs.uid) != null, "and so is the opponent's")
	answer(e, &"pick_in_play", mine.uid)
	eq(mine.zone, &"removed", "the chosen card left the game")
	eq(theirs.zone, &"in_play", "the other stayed")


## "Discard all of the defender's Allies or Drills instead of dealing damage": one kind, all of it.
func test_pyre_firestorm_takes_all_allies_or_all_drills() -> void:
	for kind in ["drill", "ally"]:
		var e: DuelEngine = real_engine(real_deck(["pyre_strike_06"], "pact", "pyre"), real_deck([], "vigil"))
		var d1: CardInstance = real_inject(e, 1, "storm_drill_03")
		var d2: CardInstance = real_inject(e, 1, "storm_drill_04")
		to_attack(e, 0)
		answer(e, &"attack", uid_in_hand(e, 0, "pyre_strike_06"))
		settle(e, 4)
		answer(e, &"pick_option", -1, "yes")
		eq(prompt_kind(e), &"pick_option", "the kind is the user's pick")
		check(e.prompt.find(&"pick_option", -1, "ally") != null and e.prompt.find(&"pick_option", -1, "drill") != null, "Allies or Drills")
		answer(e, &"pick_option", -1, kind)
		settle(e, 6)
		eq(d1.zone == &"discard" and d2.zone == &"discard", kind == "drill", "choosing %s: the Drills go only when Drills are chosen" % kind)


## "Cannot be stopped or prevented by Physical Combat cards": Endurance printed on a Strike card is
## that card preventing damage, so it is not offered; on an Art card it still is.
func test_pyre_blazing_charge_bars_prevention_by_strike_cards() -> void:
	var e: DuelEngine = real_engine(real_deck(["pyre_strike_07"], "pact", "pyre"), real_deck([], "vigil"))
	var them: PlayerState = e.player(1)
	to_attack(e, 0)
	var art_card: CardInstance = e._instance(shipped().get_def("pyre_art_06"), 1, &"life_deck")
	them.life_deck.insert(0, art_card)
	var strike_card: CardInstance = e._instance(shipped().get_def("pyre_strike_25"), 1, &"life_deck")
	them.life_deck.insert(0, strike_card)
	them.duelist.energy = 0
	answer(e, &"attack", uid_in_hand(e, 0, "pyre_strike_07"))
	eq(prompt_kind(e), &"endurance", "an Endurance question comes up")
	eq(int(e.prompt.context.get("card", -1)), art_card.uid, "for the Art card, not the Strike card turned over before it")
	eq(strike_card.zone, &"discard", "the Strike card's Endurance was never offered")
	# A standing prevention put out by a Strike card is set aside too; one from an Art is not.
	var a: Dictionary = {"no_prevent_by": "strike"}
	e._float(1, "prevent_all", "combat", {"source": strike_card.uid})
	check(not e._prevention_float(1, "prevent_all", a), "a Strike card's prevention does not apply")
	e._float(1, "prevent_all", "combat", {"source": art_card.uid})
	check(e._prevention_float(1, "prevent_all", a), "an Art card's does")


## "Raise your anger 1 level. Empower 2. If stopped, search the bottom 5 cards of your Life Deck for
## a Physical Combat card and place it into your hand. The remaining cards are placed on top of your
## Life Deck in any order." The Fervor line is printed before Empower, so Empower keeps it.
func test_pyre_flame_lash_keeps_its_fervor_when_empowered_and_stacks_the_rest_on_top() -> void:
	var e: DuelEngine = real_engine(real_deck(["pyre_strike_11"], "pact", "pyre"), real_deck([], "vigil"))
	var guard: CardInstance = real_to_hand(e, 1, "pyre_strike_14")
	var me: PlayerState = e.player(0)
	to_attack(e, 0)
	var lash: CardInstance = e.card(uid_in_hand(e, 0, "pyre_strike_11"))
	var built: Dictionary = e._build_attack(0, lash, lash.def.attack, lash.def.effects, false, false, true, null, true)
	var ops: Array[String] = []
	for line in built["effects"]:
		ops.append(str((line as Dictionary).get("op", "")))
	check(ops.has("fervor"), "an Empowered Lash still raises the Fervor")
	check(not ops.has("look_at"), "and drops the look printed after Empower")
	check(CardText.rules_text(lash.def).find("Attune 1") in range(0, CardText.rules_text(lash.def).find("Empower 2")),
		"the text prints the Fervor line before Empower: %s" % CardText.rules_text(lash.def))
	var bottom: Array[int] = []
	for i in range(5):
		bottom.append(me.life_deck[me.life_deck.size() - 1 - i].uid)
	answer(e, &"attack", lash.uid)
	answer(e, &"defend", guard.uid)
	eq(prompt_kind(e), &"pick_option", "the stopped Lash looks at the bottom five")
	var taken: int = e.prompt.options[0].card
	answer(e, &"pick_option", taken)
	var rounds: int = 0
	while prompt_kind(e) == &"pick_option" and e.prompt.player == 0 and rounds < 6:
		rounds += 1
		e.submit(e.prompt.options[0])
	eq(e.card(taken).zone, &"hand", "the chosen Strike card went to hand")
	var tops: Array[int] = []
	for i in range(4):
		tops.append(me.life_deck[i].uid)
	for uid in bottom:
		if uid != taken:
			check(tops.has(uid), "card #%d of the five is now on top of the Life Deck" % uid)


## "Choose a Red Style attack in your discard pile ... and place it into your hand" and "shuffle 5
## Red Style cards in your discard pile into your Life Deck" are not optional.
func test_pyre_rekindling_and_phoenix_flame_must_take_from_the_pile() -> void:
	var e: DuelEngine = real_engine(real_deck(["pyre_strike_13"], "pact", "pyre"), real_deck([], "vigil"))
	to_attack(e, 0)
	real_to_discard(e, 0, "pyre_strike_17")
	real_to_discard(e, 0, "pyre_strike_18")
	answer(e, &"attack", uid_in_hand(e, 0, "pyre_strike_13"))
	eq(prompt_kind(e), &"pick_option", "the pick is offered")
	check(e.prompt.find(&"pick_none") == null, "and taking nothing is not an answer")
	var f: DuelEngine = real_engine(real_deck(["pyre_art_07"], "pact", "pyre"), real_deck([], "vigil"))
	to_attack(f, 0)
	var pile: Array[CardInstance] = []
	for id in ["pyre_strike_17", "pyre_strike_17", "pyre_strike_17", "pyre_strike_18", "pyre_strike_18", "pyre_strike_18"]:
		pile.append(real_to_discard(f, 0, id))
	answer(f, &"attack", uid_in_hand(f, 0, "pyre_art_07"))
	settle(f, 8)
	var rounds: int = 0
	while prompt_kind(f) == &"pick_option" and f.prompt.player == 0 and rounds < 6:
		rounds += 1
		check(f.prompt.find(&"pick_none") == null, "no round of the pick may take nothing")
		var k: int = maxi(1, f.prompt.batch_min)
		var uids: Array = []
		for o in f.prompt.options:
			if uids.size() < k and o.card >= 0:
				uids.append(o.card)
		if f.prompt.batch_type != &"":
			f.submit(Command.new(0, &"pick_option", -1, uids))
		else:
			f.submit(Command.new(0, &"pick_option", int(uids[0])))
	var back: int = 0
	for c in pile:
		if c.zone == &"life_deck":
			back += 1
	eq(back, 5, "exactly five Pyre cards went back into the Life Deck")


## "...any Red Style attacks you perform with cards from your hand are considered to have 'Sword'."
func test_pyre_sword_cleave_lends_its_word_only_to_attacks_from_hand() -> void:
	var e: DuelEngine = real_engine(real_deck([], "pact", "pyre"), real_deck([], "vigil"))
	e._float(0, "counts_as_title", "combat", {"school": "pyre", "title": "Sword", "from_hand": true})
	var held: CardInstance = real_to_hand(e, 0, "pyre_strike_18")
	check(e._title_matches(0, held, "Sword"), "a Pyre attack from hand counts as a Sword")
	var again: CardInstance = real_inject(e, 0, "pyre_strike_04")
	again.remain = 1
	again.remain_combat = e.state.combat_count
	check(not e._title_matches(0, again, "Sword"), "one used again from the table does not")
	check(not e._title_matches(0, real_to_hand(e, 0, "root_strike_04"), "Sword"), "nor does another school's")


## "Any 'If successful' effects that raise your anger or lower your opponent's anger are secondary
## effects for the remainder of Combat."
func test_pyre_blazing_hide_makes_fervor_hits_secondary() -> void:
	var e: DuelEngine = real_engine(real_deck(["pyre_strike_22"], "pact", "pyre"), real_deck([], "vigil"))
	to_attack(e, 0)
	answer(e, &"attack", uid_in_hand(e, 0, "pyre_strike_22"))
	settle(e, 8)
	check(e._has_floating(0, "fervor_hits_secondary"), "the Hide put the rule out for the Combat")
	var flare: CardInstance = real_to_hand(e, 0, "pyre_art_09")
	var built: Dictionary = e._build_attack(0, flare, flare.def.attack, flare.def.effects, false, false, false, null, false)
	eq(str((built["effects"][0] as Dictionary).get("trigger", "secondary")), "secondary", "a Hit that raises Fervor now resolves as the attack is performed")
	var laying: CardInstance = real_to_hand(e, 0, "pyre_strike_25")
	var kept: Dictionary = e._build_attack(0, laying, laying.def.attack, laying.def.effects, false, false, false, null, false)
	eq(str((kept["effects"][0] as Dictionary).get("trigger", "")), "if_successful", "any other Hit stays a Hit")


## "Your Main Personality pays 5 power stages": the duelist pays as the card is used.
func test_pyre_conflagration_is_paid_by_the_duelist() -> void:
	var e: DuelEngine = real_engine(real_deck(["pyre_combat_02"], "pact", "pyre"), real_deck([], "vigil"))
	var me: PlayerState = e.player(0)
	to_attack(e, 0)
	me.duelist.energy = 7
	e._prompt_attack_action(me)
	answer(e, &"use", uid_in_hand(e, 0, "pyre_combat_02"))
	settle(e, 4)
	var paid: int = -1
	for ev in e.events:
		if ev.type == &"cost_paid" and int(ev.data.get("player", -1)) == 0:
			paid = int(ev.data.get("stages", -1))
	eq(paid, 5, "the duelist paid 5 Energy")
	eq(me.duelist.energy, 0, "and the card then left them at 0")


# --- The Steel expansion and review, 2026-09-23 ----------------------------

## The shipped Steel cards, each against the clause the review found it missing.
func test_steel_shipped_cards_match_their_printed_text() -> void:
	# "Stops this combat. The turn ends": nobody gets a Discard step.
	var e: DuelEngine = real_engine(real_deck(["steel_combat_01"], "pact", "steel"), real_deck([], "vigil"))
	to_attack(e, 0)
	var turn: int = e.state.turn
	answer(e, &"use", uid_in_hand(e, 0, "steel_combat_01"))
	settle(e, 6, [&"decline", &"done"])
	check(not has_event(e, &"discard_step"), "the turn ended with no Discard step")
	eq(e.state.turn, turn + 1, "and the next turn began")
	# "Use only if your Main Personality has a higher power rating than your opponent's": the two
	# duelists, whoever holds Combat.
	var f: DuelEngine = real_engine(real_deck([], "pact"), real_deck([], "vigil"))
	f.player(0).duelist.energy = 10
	f.player(1).duelist.energy = 1
	check(f._cond({"duelist_higher_might": true}, 0, {}), "the stronger duelist passes the gate")
	check(not f._cond({"duelist_higher_might": true}, 1, {}), "the weaker does not")
	check(CardText.rules_text(shipped().get_def("steel_strike_02")).contains("any number of times"), "Unyielding Scales stays out without a count")
	# "Villains, Goku, and Gohan only" was errata'd to Saiyan Heritage only: the Draconic gate.
	eq(str(shipped().get_def("steel_art_06").only.get("bloodline", "")), "draconic", "Dragonscale Mantle is Draconic only")
	# "When you use a Saiyan Style card to perform an attack, it goes to the bottom of your Life Deck."
	f._float(0, "after_use_bottom", "combat", {"school": "steel"})
	var block: CardInstance = f._instance(shipped().get_def("steel_strike_19"), 0, &"resolving")
	f._finish_card(block, false)
	eq(block.zone, &"discard", "a Steel block is not an attack, so it goes to the pile")
	var swing: CardInstance = f._instance(shipped().get_def("steel_strike_06"), 0, &"resolving")
	swing.attacked_combat = f.state.combat_count
	f._finish_card(swing, false)
	eq(swing.zone, &"life_deck", "a Steel card that attacked goes under the deck")
	# "Your opponent cannot use his Mastery card and Drills": a forbidden Drill's standing text is off.
	real_inject(f, 0, "steel_drill_01")
	eq(f._modifiers_for(f.player(0), "own", "strike", null, {}).size(), 1, "the Drill adds to Strikes")
	f._float(0, "forbid", "combat", {"what": "drills"})
	eq(f._modifiers_for(f.player(0), "own", "strike", null, {}).size(), 0, "and adds nothing while Drills are forbidden")
	# "...cannot use Mastery and Sensei cards": the Relic stands in for the Sensei card.
	var d: DeckList = real_deck([], "pact")
	d.relic_id = "relic_03"
	var g: DuelEngine = real_engine(d, real_deck([], "vigil"))
	check(g.fervor_shielded(g.player(0)), "the Relic shields the Fervor")
	g._float(0, "forbid", "turn", {"what": "relic"})
	check(not g.fervor_shielded(g.player(0)), "and does not while Relics are forbidden")
	# "Your opponent's Main Personality loses 3 power stages."
	var fore: Dictionary = shipped().get_def("steel_strike_04").effects[0]
	eq(str(fore.get("target", "")), "duelist", "Scaled Forearm takes the Energy off their duelist")


## "Your opponent's attacks cost +1, +2 if they declared a Namekian Tokui-Waza" and "your opponent's
## personalities gain 1 less power stage when they power up".
func test_steel_drills_tax_and_starve_the_opponent() -> void:
	for style in ["storm", "root"]:
		var e: DuelEngine = real_engine(real_deck([], "pact", "steel"), real_deck([], "vigil", style))
		var art_spec: Dictionary = shipped().get_def("storm_art_22").attack
		eq(e._cost_stages(art_spec, e.player(1)), 2, "an Art costs them 2 to start with")
		real_inject(e, 0, "steel_drill_02")
		eq(e._cost_stages(art_spec, e.player(1)), 4 if style == "root" else 3, "the Drill taxes a %s deck" % style)
		eq(e._cost_stages(art_spec, e.player(0)), 2, "and never its own side")
	var f: DuelEngine = real_engine(real_deck([], "pact", "steel"), real_deck([], "vigil"))
	var before: int = f.recover_gain(f.player(1))
	real_inject(f, 0, "steel_drill_03")
	eq(f.recover_gain(f.player(1)), before - 1, "they power up 1 less")
	eq(f.recover_gain(f.player(0)), before, "the owner is untouched")
	check(f._can_place(f.player(0), f._instance(shipped().get_def("pyre_drill_07"), 0, &"hand")),
		"and it sits outside the one-school Drill lock")


## "If the performer's power rating is higher, double the Base Damage from the Physical Attack Table."
func test_steel_towering_frame_doubles_only_the_table() -> void:
	var e: DuelEngine = real_engine(real_deck(["steel_strike_24"], "pact", "steel"), real_deck([], "vigil"))
	to_attack(e, 0)
	var frame: CardInstance = e.card(uid_in_hand(e, 0, "steel_strike_24"))
	e.player(0).duelist.energy = 10
	e.player(1).duelist.energy = 1
	var a: Dictionary = e._build_attack(0, frame, frame.def.attack, frame.def.effects, false, false, false, null, true)
	var b: Dictionary = e._damage_calc(a)
	eq(int(b["base_stages"]), 2 * int(b["table"]), "the higher performer doubles the table")
	eq(int(b["stages"]), 2 * int(b["table"]) + 3, "and the card's own +3 is added once")
	e.player(0).duelist.energy = 1
	e.player(1).duelist.energy = 10
	b = e._damage_calc(a)
	eq(int(b["base_stages"]), int(b["table"]), "the lower one does not")


## "When you use Endurance, your Main Personality gains 1 power stage" and "+X, X = the times you
## have used Endurance since you played this card".
func test_steel_endurance_pays_and_counts() -> void:
	var e: DuelEngine = real_engine(real_deck([], "pact"), real_deck([], "vigil"))
	var them: PlayerState = e.player(1)
	to_attack(e, 0)
	var hide: CardInstance = e._instance(shipped().get_def("pyre_strike_25"), 1, &"life_deck")
	them.life_deck.insert(0, hide)
	them.duelist.energy = 0
	e._float(1, "endurance_energy", "combat", {"energy": 1})
	answer(e, &"attack", uid_in_hand(e, 0, "root_strike_04"))
	eq(prompt_kind(e), &"endurance", "the Endurance question comes up")
	answer(e, &"endure", hide.uid)
	eq(them.endurance_uses, 1, "the use is counted")
	eq(them.duelist.energy, 1, "and the duelist gained 1 Energy for it")
	var scales: Dictionary = {"scope": "own", "kind": "strike", "stages": 1, "endurance_mark": 0}
	them.endurance_uses = 3
	eq(e._modifier_amount(scales, "stages", them), 3, "three uses since the mark make +3")
	scales["endurance_mark"] = 2
	eq(e._modifier_amount(scales, "stages", them), 1, "uses before the card was played do not count")


## "For the remainder of Combat, any life cards of damage your attacks deal are removed from the
## game": the Art that says so deals its own wounds that way too.
func test_steel_scorching_breath_covers_its_own_wounds() -> void:
	var e: DuelEngine = real_engine(real_deck(["steel_art_08"], "pact", "steel"), real_deck([], "vigil"))
	to_attack(e, 0)
	var removed: int = e.player(1).removed.size()
	var piled: int = e.player(1).discard.size()
	answer(e, &"attack", uid_in_hand(e, 0, "steel_art_08"))
	settle(e, 8)
	check(e.player(1).removed.size() > removed, "its wounds left the game")
	eq(e.player(1).discard.size(), piled, "and none reached the pile")


## "(When you perform a physical attack you may discard this card from your hand to have that attack
## do an additional +4 power stages and raise your anger 1 level.)" and "when you use Empower, you
## still use all of the effects after the Empower".
func test_steel_blood_unbound_is_discarded_to_power_a_strike() -> void:
	var e: DuelEngine = real_engine(real_deck(["steel_strike_26", "steel_strike_26"], "pact", "steel"), real_deck([], "vigil"))
	var me: PlayerState = e.player(0)
	to_attack(e, 0)
	answer(e, &"attack", uid_in_hand(e, 0, "root_strike_04"))
	eq(prompt_kind(e), &"follow_up", "performing a Strike opens the discard window")
	eq(str(e.prompt.context.get("window", "")), "attack_boost", "and it is that window")
	var spent: int = e.prompt.options[0].card
	answer(e, &"use", spent)
	eq(e.card(spent).zone, &"discard", "the card was discarded")
	eq(prompt_kind(e), &"follow_up", "the second copy may go too")
	answer(e, &"decline")
	eq(me.fervor, 1, "the discarded card raised the Fervor 1")
	eq(_added_by(e, "Steel Blood Unbound", "stages"), 4, "and the Strike did +4 Energy")
	e._float(0, "empower_keeps_text", "combat", {})
	var ashfall: CardInstance = real_to_hand(e, 0, "pyre_art_02")
	var built: Dictionary = e._build_attack(0, ashfall, ashfall.def.attack, ashfall.def.effects, false, false, true, null, false)
	eq((built["effects"] as Array).size(), 2, "an Empowered attack keeps every line after Empower")


## "Draw a card. If it is a Saiyan Style card, you may show it to your opponent and ..."
func test_steel_masteries_show_the_drawn_card() -> void:
	for mastery in ["steel_mastery_02", "steel_mastery_03"]:
		var d: DeckList = real_deck(["steel_strike_06"], "pact", "steel")
		d.mastery_id = mastery
		var e: DuelEngine = real_engine(d, real_deck([], "vigil"))
		var guard: int = 0
		while e.prompt != null and not (e.prompt.player == 0 and e.prompt.kind == &"pick_option") and guard < 12:
			guard += 1
			var quiet: Command = null
			for t in [&"done", &"declare", &"decline"]:
				quiet = e.prompt.find(t)
				if quiet != null:
					break
			if quiet == null:
				break
			e.submit(quiet)
		eq(prompt_kind(e), &"pick_option", "%s asks whether to show the Steel card" % mastery)
		var their_energy: int = e.player(1).in_control().energy
		answer(e, &"pick_option", -1, "yes")
		check(has_event(e, &"cards_revealed"), "the card was shown")
		if mastery == "steel_mastery_02":
			eq(e.player(1).in_control().energy, maxi(0, their_energy - 4), "and they lost 4 Energy")
		else:
			var shield: Dictionary = e._floating_first(0, "prevent_first_attack")
			eq(int(shield.get("stages", 0)), 4, "4 Energy of the first attack will be prevented")
			eq(int(shield.get("life", 0)), 4, "and 4 wounds, because the card was shown")
			settle(e, 6, [&"decline", &"done", &"declare"])
			if prompt_kind(e) == &"attack_action" and e.prompt.player == 1:
				answer(e, &"attack", uid_in_hand(e, 1, "root_strike_04"))
				settle(e, 8)
				check(_added_by(e, "Steel Scale Mastery", "stages") < 0, "the first attack against them had Energy prevented")
				check(e._floating_first(0, "prevent_first_attack").is_empty(), "and it is spent")


## "You cannot win by the Most Powerful Personality Victory. All of your Saiyan Style attacks gain
## 'Raise your anger 1 level. Gain 3 power stages.' During the Rejuvenation Step, if you put any
## Saiyan Style cards back into your Life Deck, raise your anger 2 levels and your Main Personality
## gains 4 power stages."
func test_steel_bloodrage_mastery_writes_onto_attacks_and_pays_on_recovery() -> void:
	var d: DeckList = real_deck([], "vigil", "steel")
	d.mastery_id = "steel_mastery_04"
	var e: DuelEngine = real_engine(real_deck([], "pact"), d)
	var me: PlayerState = e.player(1)
	check(me.no_ascension_win, "the Ascension win is off for the game")
	var charge: CardInstance = real_to_hand(e, 1, "steel_strike_06")
	var built: Dictionary = e._build_attack(1, charge, charge.def.attack, charge.def.effects, false, false, false, null, true)
	eq((built["effects"] as Array).size(), 3, "a Steel attack carries its own line and the two the Mastery gives it")
	var plain: CardInstance = real_to_hand(e, 1, "root_strike_04")
	var other: Dictionary = e._build_attack(1, plain, plain.def.attack, plain.def.effects, false, false, false, null, true)
	eq((other["effects"] as Array).size(), 0, "a Root attack gains nothing")
	real_to_discard(e, 1, "steel_strike_06")
	var fervor: int = me.fervor
	e._handle_recover(Command.new(1, &"recover"))
	# The step's own prompt is still standing in this hand-driven test; the bonus waits in the queue.
	e.prompts.clear()
	e._drain()
	eq(me.fervor, fervor + 2, "putting a Steel card back raises the Fervor 2")


## "If successful, your opponent's Main Personality's PUR is set to 0 until the end of his next turn
## and cannot be modified by other effects."
func test_steel_constricting_grip_holds_their_surge_at_zero() -> void:
	var e: DuelEngine = real_engine(real_deck(["steel_strike_27"], "pact", "steel"), real_deck([], "vigil"))
	check(e.recover_gain(e.player(1)) > 0, "they power up as usual")
	to_attack(e, 0)
	answer(e, &"attack", uid_in_hand(e, 0, "steel_strike_27"))
	settle(e, 8, [&"pick_none", &"no_defense", &"no_endure", &"no_critical", &"target", &"decline"])
	check(e._has_floating(1, "surge_zero"), "the hit holds their Surge")
	eq(e.recover_gain(e.player(1)), 0, "so they power up nothing, the Style bonus included")


## "Raise your Main Personality to his highest power stage. Your next attack does +X power stages,
## X = the power stages gained by this card, for a maximum of +5."
func test_steel_drawn_breath_banks_the_gain_for_the_next_attack() -> void:
	var e: DuelEngine = real_engine(real_deck(["steel_combat_02"], "pact", "steel"), real_deck([], "vigil"))
	var me: PlayerState = e.player(0)
	to_attack(e, 0)
	me.duelist.energy = 2
	answer(e, &"attack", uid_in_hand(e, 0, "root_strike_04"))
	eq(prompt_kind(e), &"follow_up", "the connected Strike offers the card")
	var landing_phase: int = e.state.attack_phase_count
	answer(e, &"use", uid_in_hand(e, 0, "steel_combat_02"))
	eq(me.duelist.energy, CardInstance.MAX_STAGE, "the duelist is at full Energy")
	var bank: Dictionary = {}
	for f in e.state.floating:
		if int(f.get("owner", -1)) == 0 and str(f.get("op", "")) == "modifier" and bool(f.get("once", false)):
			bank = f
	eq(int(bank.get("stages", 0)), 5, "the gain of 8 banks the most it can, +5")
	eq(int(bank.get("from_phase", -1)), landing_phase, "and not for the attack already landing")


## What a named source added to the damage of the attacks so far, read off the modified-damage beats.
func _added_by(e: DuelEngine, source: String, key: String) -> int:
	var total: int = 0
	for ev in e.events:
		if ev.type != &"modified_damage":
			continue
		for add in ev.data.get("adds", []):
			if str((add as Dictionary).get("source", "")) == source:
				total += int((add as Dictionary).get(key, 0))
	return total


## "Your Saiyan Style attacks that have Empower are focused" and "a Saiyan Style Drill that adds
## damage to your attacks".
func test_steel_cornered_blood_and_awakened_blood_read_empower_and_damage() -> void:
	var e: DuelEngine = real_engine(real_deck(["steel_drill_01", "steel_drill_04"], "pact", "steel"), real_deck([], "vigil"))
	e._float(0, "make_focused", "combat", {"school": "steel", "empower_only": true})
	check(e._made_focused(0, real_to_hand(e, 0, "steel_strike_08")), "a Steel attack with Empower is Focused")
	check(not e._made_focused(0, real_to_hand(e, 0, "steel_strike_06")), "one without Empower is not")
	var hits: Array[CardInstance] = e.search_candidates(e.player(0), {"card_type": "drill", "school": "steel", "adds_damage": true, "to": "play"})
	var ids: Array[String] = []
	for c in hits:
		ids.append(c.def.id)
	check(ids.has("steel_drill_01"), "the Drill that adds damage is found")
	check(not ids.has("steel_drill_04"), "the shield Drill is not")


# --- The Tide expansion and review, 2026-09-23 -----------------------------

## Any Aspect-1 personality card that is not the test duelist's own character, to stand as an Ally.
func _an_ally_id() -> String:
	var ids: Array = shipped().defs.keys()
	ids.sort()
	for id in ids:
		var def: CardDef = shipped().defs[id]
		if def.is_personality() and def.aspect == 1 and def.character != "Osric Thornwald" and (def.raw.get("bond_of", []) as Array).is_empty():
			return str(id)
	return ""


## The shipped Tide cards, each against the clause the review found it missing.
func test_tide_shipped_cards_match_their_printed_text() -> void:
	var e: DuelEngine = real_engine(real_deck([], "pact", "tide"), real_deck([], "vigil"))
	# "Discard any cards attached to your Main Personality": the opponent's rider goes too.
	var hex: CardInstance = real_inject(e, 1, "tide_art_15")
	hex.attached_to = e.player(0).duelist
	e._apply_effect({"op": "discard_in_play", "card_type": "attached_to_duelist", "all": true}, 0, {}, null)
	eq(hex.zone, &"discard", "the opponent's card riding the duelist was discarded")
	# Printed as a Drill, so its "+1 to physical attacks" is a standing Drill modifier.
	real_inject(e, 0, "tide_drill_07")
	eq(e._modifiers_for(e.player(0), "own", "strike", null, {}).size(), 1, "Heavy Water adds to Strikes")
	# "Cards that can lower your Main Personality any amount of levels cannot be played or used."
	e._float(1, "forbid", "combat", {"what": "lower_aspect"})
	e._float(0, "forbid", "combat", {"what": "lower_own_aspect"})
	check(not e._can_play(e.player(1), shipped().get_def("pyre_art_10")), "their card that lowers an Aspect cannot be played")
	check(not e._can_play(e.player(0), shipped().get_def("freestyle_art_04")), "nor can the user's own that lowers their own")
	check(e._can_play(e.player(0), shipped().get_def("pyre_art_10")), "the user's card aimed at the other side is untouched")
	# "You may choose to have your Main Personality lose any number of power stages."
	e._apply_effect({"op": "pay_energy", "per": 1, "payer": "duelist", "then": []}, 0, {}, null)
	eq(int(e._choice.get("payer", -1)), e.player(0).duelist.uid, "Ebb's payment is the duelist's")
	e._choice = {}
	e.prompts.clear()
	var spring: Dictionary = shipped().get_def("tide_art_05").effects[0]
	check(bool(spring.get("may", false)) and int(spring.get("aspect", 0)) == 1, "Springwater may fetch a level-1 Ally")
	var confluence: Dictionary = shipped().get_def("tide_art_08").attack["variants"][0]
	check(bool(confluence.get("after_empower", false)), "Confluence's Ally Focus is printed after Empower")
	eq(str(shipped().get_def("tide_strike_04").effects[0].get("who", "")), "any", "Pull Under reaches either side")
	check(shipped().get_def("tide_strike_07").remove_after_use, "Dredge is removed after use (CRD errata to Blue Lunge)")
	eq(str(shipped().get_def("tide_strike_08").effects[0].get("op", "")), "stop_all", "Waterlogged stops Strikes, it does not forbid them")
	eq(str(shipped().get_def("tide_strike_12").effects[0].get("duration", "")), "next_attack_phase", "Undersweep waits for their next phase")


## "Your Allies in play cannot be discarded" and "when you lower your opponent's anger but his anger
## level is 0, your opponent discards the top card of his Life Deck for each anger level lowered".
func test_tide_mooring_and_salt_burn_drills() -> void:
	var e: DuelEngine = real_engine(real_deck([], "pact"), real_deck([], "vigil", "tide"))
	var ally: CardInstance = real_inject(e, 1, _an_ally_id())
	check(not e._in_play_candidates(e.player(1), "ally").is_empty(), "the Ally can be discarded to start with")
	real_inject(e, 1, "tide_drill_02")
	check(e._in_play_candidates(e.player(1), "ally").is_empty(), "the Mooring Drill guards it from a discard")
	check(e._in_play_candidates(e.player(1), "ally", true).is_empty(), "even the owner's own")
	check(e._in_play_candidates(e.player(1), "ally", false, true).has(ally), "but not from being removed from the game")
	var f: DuelEngine = real_engine(real_deck([], "pact", "tide"), real_deck([], "vigil"))
	real_inject(f, 0, "tide_drill_03")
	var them: PlayerState = f.player(1)
	them.fervor = 0
	var deck: int = them.life_deck.size()
	f._change_fervor(them, -2, 0)
	eq(deck - them.life_deck.size(), 2, "lowering an empty Fervor 2 costs them 2 cards")
	them.fervor = 1
	deck = them.life_deck.size()
	f._change_fervor(them, -2, 0)
	eq(them.life_deck.size(), deck, "with Fervor to lower, nothing is milled")


## "Lower your opponent's anger to 0. Your opponent cannot gain any anger until the beginning of his
## next turn."
func test_tide_frozen_over_holds_fervor_until_their_turn() -> void:
	var e: DuelEngine = real_engine(real_deck(["tide_strike_15"], "pact", "tide"), real_deck([], "vigil"))
	var them: PlayerState = e.player(1)
	them.fervor = 3
	to_attack(e, 0)
	answer(e, &"attack", uid_in_hand(e, 0, "tide_strike_15"))
	settle(e, 8)
	eq(them.fervor, 0, "their Fervor went to 0")
	e._change_fervor(them, 2, 1)
	eq(them.fervor, 0, "and it cannot rise")
	skip_to_turn(e, 3)
	eq(e.state.active, 1, "their next turn has begun")
	check(not e._has_floating(1, "no_fervor_gain"), "and the lock is gone with its start")


## "Your opponent chooses 1 of those cards ... If your Main Personality's level is 3 or higher, you
## get to choose the card instead."
func test_tide_sounding_lets_the_opponent_pick_below_aspect_three() -> void:
	for climb in [0, 2]:
		var e: DuelEngine = real_engine(real_deck([], "pact"), real_deck([], "vigil", "tide"))
		var them: PlayerState = e.player(1)
		for i in range(climb):
			e._aspect_up(them)
		var sounding: CardInstance = real_to_hand(e, 1, "tide_strike_17")
		to_attack(e, 0)
		answer(e, &"attack", uid_in_hand(e, 0, "root_strike_04"))
		answer(e, &"defend", sounding.uid)
		settle(e, 2, [&"decline"])
		eq(prompt_kind(e), &"pick_option", "the three are laid out to pick from")
		eq(e.prompt.player, 0 if climb == 0 else 1, "picked by %s" % ("the opponent" if climb == 0 else "the owner at Aspect 3"))
		check(has_event(e, &"cards_revealed"), "the cards were shown")
		var taken: int = e.prompt.options[0].card
		e.submit(e.prompt.options[0])
		eq(e.card(taken).zone, &"hand", "the chosen card went to the owner's hand")
		eq(e.card(taken).owner, 1, "their own card")


## "Shuffle 1 card in your discard pile into your Life Deck for each level of your anger. If all the
## cards you shuffled in were Non-Combat cards, gain 3 power stages."
func test_tide_backwash_returns_a_card_per_fervor() -> void:
	var e: DuelEngine = real_engine(real_deck(["tide_art_13"], "pact", "tide"), real_deck([], "vigil"))
	var me: PlayerState = e.player(0)
	to_attack(e, 0)
	var a: CardInstance = real_to_discard(e, 0, "tide_drill_05")
	var b: CardInstance = real_to_discard(e, 0, "tide_drill_06")
	me.fervor = 2
	me.duelist.energy = 5
	answer(e, &"attack", uid_in_hand(e, 0, "tide_art_13"))
	eq(prompt_kind(e), &"pick_option", "the pick is the user's")
	check(e.prompt.find(&"pick_none") == null, "and not optional")
	check(e.submit(Command.new(0, &"pick_option", -1, [a.uid, b.uid])), "two cards for Fervor 2")
	eq(a.zone, &"life_deck", "the first went back")
	eq(b.zone, &"life_deck", "and the second")
	eq(me.duelist.energy, 5 - 2 + 3, "both were Non-Combat cards, so the Art's cost came back with 1 to spare")


## "X = 5 minus his anger level" and "a Base Damage of X, X = 4 minus your opponent's current anger".
func test_tide_drowning_numbers_read_their_fervor() -> void:
	var e: DuelEngine = real_engine(real_deck([], "pact", "tide"), real_deck([], "vigil"))
	var them: PlayerState = e.player(1)
	them.fervor = 2
	var deck: int = them.life_deck.size()
	e._apply_effect({"op": "discard_life", "who": "opponent", "amount": "five_minus_fervor"}, 0, {}, null)
	eq(deck - them.life_deck.size(), 3, "5 minus Fervor 2 is 3 cards")
	to_attack(e, 0)
	var plain: CardInstance = e.card(uid_in_hand(e, 0, "root_strike_04"))
	e._float(0, "table_base_fervor", "combat", {})
	them.fervor = 1
	var built: Dictionary = e._build_attack(0, plain, plain.def.attack, plain.def.effects, false, false, false, null, true)
	eq(int(e._damage_calc(built)["table"]), 3, "the table reads 4 minus Fervor 1")
	# "If the top card of your opponent's discard pile is not a physical attack."
	real_to_discard(e, 1, "root_strike_04")
	check(not e._cond({"opponent_discard_top_not_attack": "strike"}, 0, {}), "a Strike on top blocks Sinking Blow")
	real_to_discard(e, 1, "tide_drill_05")
	check(e._cond({"opponent_discard_top_not_attack": "strike"}, 0, {}), "a Drill on top does not")


## "Your opponents may only place 1 Non-Combat card in play during their turn" and "remove from the
## game after use; if your Main Personality's level is 3 or higher, discard after use instead".
func test_tide_narrow_channel_and_parting_waters() -> void:
	var e: DuelEngine = real_engine(real_deck([], "pact", "tide"), real_deck([], "vigil"))
	var them: PlayerState = e.player(1)
	eq(e.state.active, 1, "it is their turn")
	var drill_card: CardInstance = e._instance(shipped().get_def("storm_drill_03"), 1, &"hand")
	check(e._can_place(them, drill_card), "they may place a Drill")
	real_inject(e, 0, "tide_drill_06")
	them.non_combats_placed = 1
	check(not e._can_place(them, drill_card), "but not a second Non-Combat card this turn")
	var me: PlayerState = e.player(0)
	var waters: CardInstance = e._instance(shipped().get_def("tide_combat_04"), 0, &"resolving")
	e._finish_card(waters, false)
	eq(waters.zone, &"removed", "below Aspect 3 it leaves the game")
	e._aspect_up(me)
	e._aspect_up(me)
	var again: CardInstance = e._instance(shipped().get_def("tide_combat_04"), 0, &"resolving")
	e._finish_card(again, false)
	eq(again.zone, &"discard", "at Aspect 3 it is discarded instead")


## "If successful attach this card to your opponent's Main Personality. While attached, your
## opponent discards the top 2 cards of his Life Deck at the beginning of his turn. Discard this card
## when your opponent's Main Personality is at their highest power stage."
func test_tide_leeching_brine_rides_their_duelist() -> void:
	var e: DuelEngine = real_engine(real_deck(["tide_art_15"], "pact", "tide"), real_deck([], "vigil"))
	var them: PlayerState = e.player(1)
	to_attack(e, 0)
	var brine: int = uid_in_hand(e, 0, "tide_art_15")
	answer(e, &"attack", brine)
	settle(e, 8)
	eq(e.card(brine).attached_to, them.duelist, "the hit attached it to their duelist")
	var lines: Array = e.card(brine).def.effects_for("turn_start")
	eq(e._turn_start_lines(lines, false).size(), 1, "it fires on their turn")
	eq(e._turn_start_lines(lines, true).size(), 0, "not on its owner's")
	them.duelist.energy = CardInstance.MAX_STAGE
	e._sweep_full_energy_riders()
	eq(e.card(brine).zone, &"discard", "a full duelist shakes it off")


## "Once per Combat, you may discard a card from your hand to stop a physical or energy attack. If
## that card is a Blue Style card, lower your opponent's anger 2 levels." and "All Blue Style energy
## attacks gain 'If successful, raise your anger 1 level.'"
func test_tide_masteries_stop_with_a_discard_and_grant_arts_a_line() -> void:
	var d: DeckList = real_deck([], "vigil", "tide")
	d.mastery_id = "tide_mastery_03"
	var e: DuelEngine = real_engine(real_deck([], "pact"), d)
	var them: PlayerState = e.player(1)
	var tide_card: CardInstance = real_to_hand(e, 1, "tide_strike_16")
	e.player(0).fervor = 3
	to_attack(e, 0)
	answer(e, &"attack", uid_in_hand(e, 0, "root_strike_04"))
	eq(prompt_kind(e), &"defense", "the defender may answer")
	check(e.prompt.find(&"defend", them.mastery.uid) != null, "the Mastery is offered as a stop")
	answer(e, &"defend", them.mastery.uid)
	if prompt_kind(e) == &"discard_choice":
		answer(e, &"discard_choice", tide_card.uid)
	settle(e, 4)
	check(has_event(e, &"attack_stopped"), "the discard stopped the Strike")
	eq(e.player(0).fervor, 1, "a Tide card discarded lowered their Fervor 2")
	var f_deck: DeckList = real_deck([], "pact", "tide")
	f_deck.mastery_id = "tide_mastery_04"
	var f: DuelEngine = real_engine(f_deck, real_deck([], "vigil"))
	var spring: CardInstance = real_to_hand(f, 0, "tide_art_14")
	var built: Dictionary = f._build_attack(0, spring, spring.def.attack, spring.def.effects, false, false, false, null, true)
	eq((built["effects"] as Array).size(), 3, "a Tide Art carries its two lines and the Mastery's Hit")
	var strike_card: CardInstance = real_to_hand(f, 0, "tide_strike_16")
	var plain: Dictionary = f._build_attack(0, strike_card, strike_card.def.attack, strike_card.def.effects, false, false, false, null, true)
	eq((plain["effects"] as Array).size(), 1, "a Tide Strike gains nothing")


# --- The Shade expansion and review, 2026-09-23 ----------------------------

## "Discard one of your opponent's Non-Combat cards or Allies in play. Unless your opponent discards
## a card from his hand when you perform this attack, remove an additional one from the game."
func test_shade_prying_whisper_removes_unless_they_discard() -> void:
	check(bool(shipped().get_def("shade_strike_01").raw.get("reserve_only", false)), "it is Sensei Deck only, so Reserve only")
	for answer_value in ["no", "yes"]:
		var e: DuelEngine = real_engine(real_deck(["shade_strike_01"], "pact", "shade"), real_deck([], "vigil"))
		var first: CardInstance = real_inject(e, 1, "storm_drill_03")
		var second: CardInstance = real_inject(e, 1, "storm_drill_04")
		to_attack(e, 0)
		var held: int = e.player(1).hand.size()
		answer(e, &"attack", uid_in_hand(e, 0, "shade_strike_01"))
		answer(e, &"pick_in_play", first.uid)
		eq(prompt_kind(e), &"pick_option", "the opponent is asked whether to discard")
		eq(e.prompt.player, 1, "and it is their question")
		answer(e, &"pick_option", -1, answer_value)
		if prompt_kind(e) == &"discard_choice":
			e.submit(e.prompt.options[0])
		if answer_value == "no":
			eq(second.zone, &"removed", "refusing costs them the second card, out of the game")
		else:
			eq(second.zone, &"in_play", "discarding a card saves the second")
			eq(e.player(1).hand.size(), held - 1, "and the card came out of their hand")


## "Your opponent must remove from the game 1 non-Dragon Ball card in his hand. If your opponent has
## only Dragon Balls in his hand, he must show you his hand but no cards are removed."
func test_shade_silenced_whisper_lets_them_choose_and_shows_a_seal_hand() -> void:
	var e: DuelEngine = real_engine(real_deck([], "pact"), real_deck([], "vigil"))
	var them: PlayerState = e.player(1)
	e._apply_effect(shipped().get_def("shade_strike_10").effects[0], 0, {}, null)
	eq(prompt_kind(e), &"discard_choice", "the pick is theirs")
	eq(e.prompt.player, 1, "made by the opponent")
	e.prompts.clear()
	e._choice = {}
	for c in them.hand.duplicate():
		e._move_to_discard(c)
	real_to_hand(e, 1, "seal_08")
	e._apply_effect(shipped().get_def("shade_strike_10").effects[0], 0, {}, null)
	check(has_event(e, &"hand_revealed"), "a hand of Seals is shown")
	eq(prompt_kind(e), &"pick_option", "to the attacker, as a look")
	eq(e.prompt.player, 0, "the attacker sees it")
	eq(them.hand.size(), 1, "and nothing was removed")
	var f: DuelEngine = real_engine(real_deck([], "pact"), real_deck([], "vigil"))
	var held: int = f.player(1).hand.size()
	var deck: int = f.player(1).life_deck.size()
	for line in shipped().get_def("shade_strike_04").effects:
		f._apply_effect(line, 0, {}, null)
	eq(f.player(1).hand.size(), held, "Slipping Thought leaves their hand the same size")
	eq(f.player(1).life_deck.size(), deck, "and their deck too, one card in and one drawn")


## "If successful, place 3 cards with 'Kick' in the title on top of your Life Deck and remove this
## card from the game": a stopped one goes to the pile as usual.
func test_shade_returning_whisper_leaves_the_game_only_on_a_hit() -> void:
	var e: DuelEngine = real_engine(real_deck(["shade_strike_09"], "pact", "shade"), real_deck([], "vigil"))
	to_attack(e, 0)
	var whisper: int = uid_in_hand(e, 0, "shade_strike_09")
	answer(e, &"attack", whisper)
	settle(e, 8)
	eq(e.card(whisper).zone, &"removed", "a hit removes it")
	var f: DuelEngine = real_engine(real_deck(["shade_strike_09"], "pact", "shade"), real_deck([], "vigil"))
	var guard: CardInstance = real_to_hand(f, 1, "pyre_strike_14")
	to_attack(f, 0)
	var stopped: int = uid_in_hand(f, 0, "shade_strike_09")
	answer(f, &"attack", stopped)
	answer(f, &"defend", guard.uid)
	settle(f, 6)
	eq(f.card(stopped).zone, &"discard", "a stopped one is discarded")


## "If successful, attach to one of your opponent's Non-Combat cards in play. While attached, this
## Non-Combat card cannot be used."
func test_shade_stilling_whisper_shuts_off_a_non_combat_card() -> void:
	var e: DuelEngine = real_engine(real_deck(["shade_strike_16"], "pact", "shade"), real_deck([], "vigil"))
	var them: PlayerState = e.player(1)
	var drill_card: CardInstance = real_inject(e, 1, "steel_drill_01")
	eq(e._modifiers_for(them, "own", "strike", null, {}).size(), 1, "their Drill adds to Strikes")
	to_attack(e, 0)
	var still: int = uid_in_hand(e, 0, "shade_strike_16")
	answer(e, &"attack", still)
	settle(e, 8)
	eq(e.card(still).attached_to, drill_card, "the hit attached it to their Drill")
	eq(e._modifiers_for(them, "own", "strike", null, {}).size(), 0, "and the Drill does nothing while it rides there")
	e._move_to_discard(drill_card)
	eq(e.card(still).zone, &"discard", "when the Drill goes, the rider goes with it")


## "Attach to your opponent's Main Personality. While attached, all attacks performed by that
## personality do -2 power stages of damage. Discard this card when the attached personality
## reaches his highest power stage."
func test_shade_wasting_mark_weakens_their_attacks_until_full() -> void:
	var e: DuelEngine = real_engine(real_deck(["shade_strike_17"], "pact", "shade"), real_deck([], "vigil"))
	var them: PlayerState = e.player(1)
	to_attack(e, 0)
	var mark: int = uid_in_hand(e, 0, "shade_strike_17")
	answer(e, &"attack", mark)
	settle(e, 8)
	eq(e.card(mark).attached_to, them.duelist, "it rides their duelist")
	var total: int = 0
	for entry in e._modifiers_for(them, "own", "strike", null, {}):
		total += int((entry["m"] as Dictionary).get("stages", 0))
	eq(total, -2, "their attacks do 2 less Energy")
	them.duelist.energy = CardInstance.MAX_STAGE
	e._sweep_full_energy_riders()
	eq(e.card(mark).zone, &"discard", "a full duelist shakes it off")


## "This must be the first card you use during Combat."
func test_shade_opening_whisper_must_be_the_first_card() -> void:
	var e: DuelEngine = real_engine(real_deck(["shade_strike_20"], "pact", "shade"), real_deck([], "vigil"))
	var me: PlayerState = e.player(0)
	var opening: CardDef = shipped().get_def("shade_strike_20")
	to_attack(e, 0)
	check(e._attack_allowed(me, opening), "nothing used yet, so it may open the Combat")
	me.used_card_combat = true
	check(not e._attack_allowed(me, opening), "after any card it may not")


## "Search your opponent's Life Deck for 2 Non-Dragon Ball cards and remove them from the game",
## "name a card ... search your opponent's Life Deck for 1 copy of that card and discard it", and
## "name any Combat card; all of your opponents must search their Life Decks for all copies".
func test_shade_searches_and_names_reach_their_life_deck() -> void:
	var e: DuelEngine = real_engine(real_deck([], "pact", "shade"), real_deck([], "vigil"))
	var them: PlayerState = e.player(1)
	var hits: Array[CardInstance] = e.search_candidates(e.player(0), {"whose": "opponent", "to": "removed"})
	check(not hits.is_empty() and hits[0].owner == 1, "the search looks through their deck")
	# Named Doom: one copy only.
	for i in range(2):
		real_to_deck(e, 1, "tide_strike_16")
	var copies: int = 0
	e._strip_named(them, "Tide Breaking Sea", {"to": "discard", "amount": 1})
	for c in them.discard:
		if c.def.id == "tide_strike_16":
			copies += 1
	eq(copies, 1, "one copy was discarded")
	# Erased Name: the namer chooses from every Combat card and is shown nothing.
	var erased: CardInstance = real_to_hand(e, 0, "shade_combat_02")
	e._prompt_name_card(e.player(0), erased, erased.def.effects[0])
	eq(prompt_kind(e), &"name_card", "a name is asked for")
	check(e.prompt.find(&"name_card", -1, "Pyre Bonfire") != null, "any Strike card in the game may be named")
	check(e.prompt.find(&"name_card", -1, "Steel Hardscale Drill") == null, "a Drill may not")
	check(not e.prompt.context.has("library"), "and their deck is not shown")


## "Your opponent discards 2 cards from the top of his Life Deck for each anger level he is at above
## 0" and "discards an amount of cards from his Life Deck equal to your Main Personality's PUR".
func test_shade_mockery_hex_and_creeping_dark_mill_by_the_numbers() -> void:
	var e: DuelEngine = real_engine(real_deck([], "pact", "shade"), real_deck([], "vigil"))
	var them: PlayerState = e.player(1)
	them.fervor = 2
	var deck: int = them.life_deck.size()
	e._apply_effect({"op": "discard_life", "who": "opponent", "amount": "twice_fervor"}, 0, {}, null)
	eq(deck - them.life_deck.size(), 4, "Fervor 2 costs them 4 cards")
	deck = them.life_deck.size()
	e._apply_effect({"op": "discard_life", "who": "opponent", "amount": "owner_surge"}, 0, {}, null)
	eq(deck - them.life_deck.size(), e.surge_of(e.player(0)), "the user's Surge in cards")
	var held: int = them.hand.size()
	e._apply_effect({"op": "cycle_hand", "who": "opponent"}, 0, {}, null)
	eq(them.hand.size(), held, "their hand went into the deck and as many came back")


## "Look at your opponent's hand. Your opponent skips his next Attacker Attacks phase. The next
## attack you perform this Combat does +2 life cards of damage."
func test_shade_stolen_secret_looks_skips_and_banks() -> void:
	var e: DuelEngine = real_engine(real_deck(["shade_combat_04"], "pact", "shade"), real_deck([], "vigil"))
	to_attack(e, 0)
	answer(e, &"use", uid_in_hand(e, 0, "shade_combat_04"))
	eq(prompt_kind(e), &"pick_option", "the hand is shown as a look")
	eq((e.prompt.context.get("library", []) as Array).size(), e.player(1).hand.size(), "every card in it")
	answer(e, &"pick_none")
	check(has_event(e, &"attack_phase_skipped"), "their next attack phase was skipped")
	var banked: int = 0
	for f in e.state.floating:
		if int(f.get("owner", -1)) == 0 and bool(f.get("once", false)):
			banked = int(f.get("life", 0))
	eq(banked, 2, "and the next attack does +2 wounds")


## "Whenever you perform a successful attack, shuffle a random card from their hand into their Life
## Deck, then they draw 1", and "whenever you stop an attack, you may put your bottom discard under
## your Life Deck".
func test_shade_drills_answer_hits_and_stops() -> void:
	var e: DuelEngine = real_engine(real_deck([], "pact", "shade"), real_deck([], "vigil"))
	real_inject(e, 0, "shade_drill_04")
	to_attack(e, 0)
	var held: int = e.player(1).hand.size()
	var deck: int = e.player(1).life_deck.size()
	answer(e, &"attack", uid_in_hand(e, 0, "root_strike_04"))
	settle(e, 8)
	eq(e.player(1).hand.size(), held, "one card went into their deck and one was drawn")
	check(has_event(e, &"hand_discarded"), "a card left their hand")
	var f: DuelEngine = real_engine(real_deck([], "pact"), real_deck([], "vigil", "shade"))
	real_inject(f, 1, "shade_drill_07")
	var guard: CardInstance = real_to_hand(f, 1, "pyre_strike_14")
	to_attack(f, 0)
	var oldest: CardInstance = f._instance(shipped().get_def("tide_strike_16"), 1, &"discard")
	f.player(1).discard.insert(0, oldest)
	answer(f, &"attack", uid_in_hand(f, 0, "root_strike_04"))
	answer(f, &"defend", guard.uid)
	settle(f, 4)
	eq(prompt_kind(f), &"pick_option", "the stop offers the Drill")
	answer(f, &"pick_option", -1, "yes")
	eq(oldest.zone, &"life_deck", "the bottom discard went under the deck")


## "In place of an attack, discard a card from your hand. If it is a Black Style card, discard a
## card at random from your opponent's hand" and "you may discard a Black Style card during your
## Attacker Attacks phase to raise your anger 1 level and have your Main Personality gain 6".
func test_shade_masteries_discard_to_hurt_their_hand() -> void:
	var d: DeckList = real_deck([], "pact", "shade")
	d.mastery_id = "shade_mastery_04"
	var e: DuelEngine = real_engine(d, real_deck([], "vigil"))
	var me: PlayerState = e.player(0)
	to_attack(e, 0)
	check(e.prompt.find(&"use", me.mastery.uid) == null, "no Shade card in hand, so Eclipse is not offered")
	var fuel: CardInstance = real_to_hand(e, 0, "shade_strike_18")
	e._prompt_attack_action(me)
	me.duelist.energy = 2
	answer(e, &"use", me.mastery.uid)
	if prompt_kind(e) == &"discard_choice":
		answer(e, &"discard_choice", fuel.uid)
	eq(fuel.zone, &"discard", "the Shade card was discarded")
	eq(me.fervor, 1, "Fervor +1")
	eq(me.duelist.energy, 8, "the duelist gained 6")
	eq(prompt_kind(e), &"attack_action", "and the attack phase is still open")
	eq(e.prompt.player, 0, "for the same player")
	# Blight: a Shade attack's Hit may take a Non-Combat card; any other attack's takes a Drill.
	var b: DeckList = real_deck([], "pact", "shade")
	b.mastery_id = "shade_mastery_03"
	var f: DuelEngine = real_engine(b, real_deck([], "vigil"))
	var shade_card: CardInstance = real_to_hand(f, 0, "shade_strike_23")
	var built: Dictionary = f._build_attack(0, shade_card, shade_card.def.attack, shade_card.def.effects, false, false, false, null, true)
	var last_line: Dictionary = (built["effects"] as Array).back()
	eq(str(last_line.get("card_type", "")), "non_combat_card", "a Shade attack gains the Non-Combat line")
	var plain: CardInstance = real_to_hand(f, 0, "root_strike_04")
	var other: Dictionary = f._build_attack(0, plain, plain.def.attack, plain.def.effects, false, false, false, null, true)
	eq(str(((other["effects"] as Array).back() as Dictionary).get("card_type", "")), "drill", "any other attack gains the Drill line")


# --- The second Root expansion, 2026-09-23 --------------------------------

## "If successful, choose a card in your discard pile and shuffle it back into your Life Deck" and
## "shuffle the top card of your discard pile back into your Life Deck".
func test_root_vine_and_thorns_shuffle_discards_back() -> void:
	var e: DuelEngine = real_engine(real_deck([], "pact", "root"), real_deck([], "vigil"))
	var older: CardInstance = real_to_discard(e, 0, "tide_drill_05")
	var top: CardInstance = real_to_discard(e, 0, "tide_drill_06")
	e._apply_effect(shipped().get_def("root_strike_17").effects[0], 0, {}, null)
	eq(prompt_kind(e), &"pick_option", "Creeping Vine asks which card")
	check(e.prompt.find(&"pick_none") == null, "and the choice is not optional")
	answer(e, &"pick_option", older.uid)
	eq(older.zone, &"life_deck", "the chosen card went back into the deck")
	eq(top.zone, &"discard", "the other stayed")
	e._apply_effect(shipped().get_def("root_art_12").effects[0], 0, {}, null)
	eq(top.zone, &"life_deck", "Hurled Thorns took the top card")


## "Choose up to 4 cards in your discard pile. Remove 2 of them from the game. Shuffle the remaining
## cards back into your Life Deck. If successful, remove from the game."
func test_root_seed_burst_sifts_four_and_removes_two() -> void:
	var e: DuelEngine = real_engine(real_deck([], "pact", "root"), real_deck([], "vigil"))
	var pile: Array[CardInstance] = []
	for id in ["tide_drill_05", "tide_drill_06", "storm_drill_03", "storm_drill_04", "steel_drill_01"]:
		pile.append(real_to_discard(e, 0, id))
	var burst: CardDef = shipped().get_def("root_art_11")
	check(bool(burst.attack.get("focused", false)), "it is a Focused Art")
	e._apply_effect(burst.effects[0], 0, {}, null)
	eq(prompt_kind(e), &"pick_option", "the pile is laid out")
	check(e.prompt.find(&"pick_none") != null, "\"up to\" allows none")
	check(e.submit(Command.new(0, &"pick_option", -1, [pile[0].uid, pile[1].uid, pile[2].uid])), "three are chosen")
	eq(prompt_kind(e), &"pick_option", "then two of the three are picked to remove")
	check(e.submit(Command.new(0, &"pick_option", -1, [pile[0].uid, pile[2].uid])), "two are named")
	eq(pile[0].zone, &"removed", "the first named left the game")
	eq(pile[2].zone, &"removed", "and the second")
	eq(pile[1].zone, &"life_deck", "the third went back into the deck")
	eq(pile[3].zone, &"discard", "an unchosen card stayed in the pile")
	var none: DuelEngine = real_engine(real_deck([], "pact", "root"), real_deck([], "vigil"))
	var kept: CardInstance = real_to_discard(none, 0, "tide_drill_05")
	none._apply_effect(burst.effects[0], 0, {}, null)
	check(none.submit(Command.new(0, &"pick_none")), "taking none of the pile is accepted")
	eq(kept.zone, &"discard", "and the pile is left as it was")
	var f: DuelEngine = real_engine(real_deck([], "pact", "root"), real_deck([], "vigil"))
	var burning: CardInstance = f._instance(burst, 0, &"resolving")
	f._apply_effect(burst.effects[1], 0, {}, burning)
	eq(burning.zone, &"removed", "and the hit removes the card itself")


## The last `type` event's data, or {} when there was none.
func last_event(e: DuelEngine, type: StringName) -> Dictionary:
	var out: Dictionary = {}
	for ev in e.events:
		if ev.type == type:
			out = ev.data
	return out


## Answers any open response window for the other seat with its quiet option.
func decline_responses(e: DuelEngine) -> void:
	var guard: int = 0
	while prompt_kind(e) == &"respond" and guard < 4:
		guard += 1
		var quiet: Command = e.prompt.find(&"decline")
		if quiet == null:
			quiet = e.prompt.find(&"pass")
		if quiet == null:
			return
		e.submit(quiet)


## The Storm Sensei's Relic: "All of your attacks do +1 life cards of damage. All of your
## opponent's attacks do -1 life cards of damage." A standing line, read like a Mastery's.
func test_storm_sensei_relic_moves_one_wound_each_way() -> void:
	var e: DuelEngine = real_engine(real_deck(["storm_art_16"]), real_deck([], "pact"))
	e.player(0).relic = e._instance(shipped().get_def("relic_05"), 0, &"side")
	to_attack(e, 0)
	var before: int = e.player(1).life_deck.size()
	answer(e, &"attack", uid_in_hand(e, 0, "storm_art_16"))
	eq(before - e.player(1).life_deck.size(), 7, "a 6-wound Art lands 7 with the Relic behind it")
	var f: DuelEngine = real_engine(real_deck(["storm_art_16"]), real_deck([], "pact"))
	f.player(1).relic = f._instance(shipped().get_def("relic_05"), 1, &"side")
	to_attack(f, 0)
	before = f.player(1).life_deck.size()
	answer(f, &"attack", uid_in_hand(f, 0, "storm_art_16"))
	eq(before - f.player(1).life_deck.size(), 5, "and 5 against it")


## "Your energy attacks do an additional +X life cards of damage, where X is the PUR of the
## personality performing the attack."
func test_surging_drill_adds_the_performers_surge() -> void:
	var e: DuelEngine = real_engine(real_deck(["storm_art_16", "root_strike_04"]), real_deck([], "pact"))
	real_inject(e, 0, "signature_drill_07")
	to_attack(e, 0)
	var surge: int = e.player(0).in_control().surge()
	check(surge > 0, "the duelist has a Surge to add (%d)" % surge)
	var before: int = e.player(1).life_deck.size()
	answer(e, &"attack", uid_in_hand(e, 0, "storm_art_16"))
	eq(before - e.player(1).life_deck.size(), 6 + surge, "a 6-wound Art gains the performer's Surge")
	eq(e.card(uid_in_hand(e, 0, "root_strike_04")) != null, true, "the Strike is still in hand")


## "Focused energy attack doing 2 life cards of damage. Costs 1 power stage to perform. Remove from
## the game after use. Empower 4. This attack is no longer focused. This attack stays on the table
## to be used 2 more times this Combat without using its Empower."
func test_fivefold_spark_empowers_into_three_unfocused_uses() -> void:
	var e: DuelEngine = real_engine(real_deck(["storm_art_25"]), real_deck([], "pact"))
	to_attack(e, 0)
	var uid: int = uid_in_hand(e, 0, "storm_art_25")
	var before: int = e.player(1).life_deck.size()
	answer(e, &"attack", uid, "empower")
	eq(before - e.player(1).life_deck.size(), 6, "2 wounds plus Empower 4")
	eq(bool(last_event(e, &"attack_declared").get("focused", true)), false, "Empower takes the Focus off")
	eq(e.card(uid).zone, &"in_play", "the card stays on the table")
	eq(e.card(uid).remain, 2, "for two more uses this Combat")
	answer(e, &"pass")
	check(e.prompt.find(&"attack", uid) != null, "the table copy attacks again")
	check(e.prompt.find(&"attack", uid, "empower") == null, "without its Empower")
	var g: DuelEngine = real_engine(real_deck(["storm_art_25"]), real_deck([], "pact"))
	to_attack(g, 0)
	var plain: int = uid_in_hand(g, 0, "storm_art_25")
	answer(g, &"attack", plain)
	eq(bool(last_event(g, &"attack_declared").get("focused", false)), true, "unempowered it is Focused")
	eq(g.card(plain).zone, &"removed", "and removed from the game after use")


## "Focused Energy Attack doing 5 life cards of damage. If successful, this personality does not
## have to pay any costs for energy attacks for the remainder of combat."
func test_unpaid_bolt_waives_art_costs_for_the_combat() -> void:
	var e: DuelEngine = real_engine(real_deck(["signature_art_16", "storm_art_16"]), real_deck([], "pact"))
	to_attack(e, 0)
	answer(e, &"attack", uid_in_hand(e, 0, "signature_art_16"))
	answer(e, &"pass")
	var energy: int = e.player(0).in_control().energy
	answer(e, &"attack", uid_in_hand(e, 0, "storm_art_16"))
	eq(e.player(0).in_control().energy, energy, "the next Art this Combat costs nothing")


## "Raise any personality in play to its highest power stage. The next energy attack that
## personality performs this Combat costs 0 power stages to perform."
func test_centering_raises_a_personality_and_frees_its_next_art() -> void:
	var e: DuelEngine = real_engine(real_deck(["storm_art_16", "storm_art_16"]), real_deck([], "pact"))
	var centering: CardInstance = real_inject(e, 0, "freestyle_noncombat_21")
	to_attack(e, 0)
	var me: CardInstance = e.player(0).duelist
	me.energy = 1
	answer(e, &"use", centering.uid)
	decline_responses(e)
	if prompt_kind(e) == &"pick_option":
		answer(e, &"pick_option", me.uid)
	eq(me.energy, CardInstance.MAX_STAGE, "raised to full")
	# Using it took the attack phase; the rival's comes next.
	answer(e, &"pass")
	answer(e, &"attack", uid_in_hand(e, 0, "storm_art_16"))
	eq(me.energy, CardInstance.MAX_STAGE, "and its next Art costs 0")
	answer(e, &"pass")
	answer(e, &"attack", uid_in_hand(e, 0, "storm_art_16"))
	eq(me.energy, CardInstance.MAX_STAGE - DuelEngine.ART_COST, "the one after pays again")


## "For the remainder of Combat you may discard the top card of your Life Deck instead of paying
## costs for any energy attacks Kid Trunks performs."
func test_art_costs_can_be_paid_with_a_life_card() -> void:
	var e: DuelEngine = real_engine(real_deck(["storm_art_16", "storm_art_16"]), real_deck([], "pact"))
	to_attack(e, 0)
	var me: PlayerState = e.player(0)
	var art: Dictionary = shipped().get_def("storm_art_16").attack
	me.duelist.energy = 0
	check(not e._can_pay(me.duelist, me, art), "no Energy, no Art")
	e._float(0, "life_for_art_costs", "combat", {"performer": me.duelist.uid})
	check(e._can_pay(me.duelist, me, art), "until a Life Deck card can pay for it")
	var life: int = me.life_deck.size()
	answer(e, &"attack", uid_in_hand(e, 0, "storm_art_16"))
	eq(me.life_deck.size(), life - 1, "with no Energy the top Life Deck card pays")
	eq(me.duelist.energy, 0, "and no Energy is spent")
	answer(e, &"pass")
	me.duelist.energy = CardInstance.MAX_STAGE
	life = me.life_deck.size()
	answer(e, &"attack", uid_in_hand(e, 0, "storm_art_16"))
	eq(prompt_kind(e), &"pick_option", "with Energy to spare it asks how to pay")
	answer(e, &"pick_option", -1, "life")
	eq(me.life_deck.size(), life - 1, "a Life Deck card, as chosen")
	eq(me.duelist.energy, CardInstance.MAX_STAGE, "and the Energy is kept")
	var power: Dictionary = shipped().get_def("personality_67").raw.get("power", {})
	var pinned: bool = false
	for effect in power.get("effects", []):
		pinned = pinned or (str(effect.get("what", "")) == "life_for_art_costs" and bool(effect.get("this_personality", false)) and str(effect.get("trigger", "")) == "if_successful")
	check(pinned, "Tavin Vale's earlier print puts that out on a hit, pinned to him")


## "When entering Combat, you may remove 3 cards in your discard pile from the game to search your
## discard pile for a card that can perform an energy attack with a Base Damage of less than 6 life
## cards and place it into your hand."
func test_scavenger_trades_three_discards_for_a_small_art() -> void:
	var e: DuelEngine = real_engine(real_deck([], "vigil", "", "PLACEHOLDER Duelist"), real_deck([], "pact"))
	var fodder: Array[CardInstance] = []
	for i in range(3):
		fodder.append(real_to_discard(e, 0, "root_strike_04"))
	var small: CardInstance = real_to_discard(e, 0, "storm_art_06")
	var other_small: CardInstance = real_to_discard(e, 0, "storm_art_07")
	var big: CardInstance = real_to_discard(e, 0, "storm_art_16")
	to_attack(e, 0)
	eq(prompt_kind(e), &"pick_option", "entering Combat asks whether to pay")
	answer(e, &"pick_option", -1, "yes")
	eq(prompt_kind(e), &"pick_discard", "then which three go")
	var uids: Array[int] = [fodder[0].uid, fodder[1].uid, fodder[2].uid]
	check(e.submit(Command.new(0, &"pick_option", -1, uids)), "three are picked")
	for c in fodder:
		eq(c.zone, &"removed", "a paid card left the game")
	eq(prompt_kind(e), &"pick_option", "then the pile is searched")
	check(e.prompt.find(&"pick_option", small.uid) != null and e.prompt.find(&"pick_option", other_small.uid) != null, "a 5-wound Art qualifies")
	check(e.prompt.find(&"pick_option", big.uid) == null, "a 6-wound Art does not")
	answer(e, &"pick_option", small.uid)
	eq(small.zone, &"hand", "the Art is taken into hand")


## "All successful physical attacks performed against you do a maximum of 3 power stages of
## damage." Wounds a Strike prints are untouched (rulings document, #147).
func test_braking_drill_caps_strike_energy_damage() -> void:
	var e: DuelEngine = real_engine(real_deck(["root_strike_04"]), real_deck([], "pact"))
	real_inject(e, 1, "storm_drill_10")
	to_attack(e, 0)
	var them: CardInstance = e.player(1).in_control()
	them.energy = CardInstance.MAX_STAGE
	answer(e, &"attack", uid_in_hand(e, 0, "root_strike_04"))
	eq(CardInstance.MAX_STAGE - them.energy, 3, "a Strike doing more takes 3 Energy at most")


## "At the beginning of every turn, discard 1 opponent's non-combat-non-dragon ball card in play."
func test_razing_drill_fires_at_the_start_of_every_turn() -> void:
	var e: DuelEngine = real_engine(real_deck([]), real_deck([], "pact"))
	var razing: CardDef = shipped().get_def("storm_drill_09")
	eq(e._turn_start_lines(razing.effects_for("turn_start"), true).size(), 1, "on its owner's turn")
	eq(e._turn_start_lines(razing.effects_for("turn_start"), false).size(), 1, "and on the other player's")
	var drill: CardInstance = real_inject(e, 0, "storm_drill_09")
	var theirs: CardInstance = real_inject(e, 1, "storm_drill_03")
	e._apply_effect(razing.effects[0], 0, {}, drill)
	if prompt_kind(e) == &"pick_in_play":
		answer(e, &"pick_in_play", theirs.uid)
	eq(theirs.zone, &"discard", "one of the opponent's Drills or Non-Combats goes")


## "Focused energy attack. Costs 3 power stages to perform. If successful, search your Life Deck for
## any Location and place it into play."
func test_braced_beam_puts_grounds_into_play() -> void:
	var e: DuelEngine = real_engine(real_deck(["signature_art_15", "grounds_05"]), real_deck([], "pact"))
	var yard: CardInstance = null
	for c in e.player(0).hand:
		if c.def.id == "grounds_05":
			yard = c
	e.player(0).hand.erase(yard)
	yard.zone = &"life_deck"
	e.player(0).life_deck.append(yard)
	to_attack(e, 0)
	answer(e, &"attack", uid_in_hand(e, 0, "signature_art_15"))
	eq(prompt_kind(e), &"pick_option", "a hit searches the Life Deck")
	answer(e, &"pick_option", yard.uid)
	eq(e.state.grounds, yard, "and the Grounds are put into play")


## "Heroes only. Energy attack doing 6 life cards of damage. If performed against a villain, this
## attack is focused, gain 2 power stages, and for the remainder of Combat your opponent cannot
## have Allies take control of Combat."
func test_vigilant_effort_hardens_against_a_pact_duelist() -> void:
	var e: DuelEngine = real_engine(real_deck(["freestyle_art_12"]), real_deck([], "pact"))
	to_attack(e, 0)
	e.player(0).duelist.energy = 5
	var before: int = e.player(1).life_deck.size()
	answer(e, &"attack", uid_in_hand(e, 0, "freestyle_art_12"))
	eq(bool(last_event(e, &"attack_declared").get("focused", false)), true, "Focused against a Pact duelist")
	eq(before - e.player(1).life_deck.size(), 6, "for 6 wounds")
	eq(e.player(0).duelist.energy, 5 - DuelEngine.ART_COST + 2, "gaining 2 Energy after the cost")
	check(e._has_floating(1, "no_ally_takeover"), "and their Allies cannot take control")
	check(not e._has_floating(1, "no_ally_control"), "which leaves damage free to land on an Ally")
	var f: DuelEngine = real_engine(real_deck(["freestyle_art_12"]), real_deck([], "vigil"))
	to_attack(f, 0)
	answer(f, &"attack", uid_in_hand(f, 0, "freestyle_art_12"))
	eq(bool(last_event(f, &"attack_declared").get("focused", true)), false, "a plain Art against a Vigil duelist")
	check(not f._has_floating(1, "no_ally_takeover"), "with nothing else")


## The rest of the Storm Sensei sheet's new cards use mechanics already covered; this pins their
## data to the printed text.
func test_storm_sensei_cards_read_as_printed() -> void:
	var lib: CardLibrary = shipped()
	var duelist: Array[CardDef] = []
	for i in range(63, 67):
		duelist.append(lib.get_def("personality_%d" % i))
	eq(duelist.map(func(d: CardDef) -> int: return int(d.raw.get("surge", 0))), [2, 3, 3, 3], "the printed Surge of all four levels")
	var two: Dictionary = duelist[1].raw["power"]
	check(bool(two["attack"].get("focused", false)) and int(two["attack"].get("printed_life", 0)) == 5, "level 2 is a Focused 5-wound Art")
	eq(str(two["effects"][0].get("card_type", "")), "drill_or_ally", "that discards an Ally or a Drill on a hit")
	eq(str(duelist[2].raw["power"]["effects"][0].get("op", "")), "set_fervor", "level 3 zeroes their Fervor on a hit")
	eq(str(duelist[3].raw["power"]["effects"][0].get("op", "")), "capture_seal", "level 4 captures a Seal on a hit")
	var brute: CardDef = lib.get_def("personality_69")
	eq(int(brute.raw["power"]["attack"].get("printed_life", 0)), 7, "the Brute's Art does 7")
	eq(str(brute.raw["power"]["effects"][0].get("trigger", "")), "if_stopped", "and costs 3 Life Deck cards when stopped")
	eq(brute.alignment_only, "", "fielded by either side")
	var companion: CardDef = lib.get_def("personality_68")
	eq(str(companion.raw["power"]["effects"][0].get("to", "")), "discard", "the Companion's hit sends a card from the Life Deck to the discard pile")
	var catch: CardDef = lib.get_def("storm_art_26")
	check(catch.stops_kind("art", false) and not catch.stops_kind("strike", false), "Caught Current stops an Art")
	eq(catch.endurance, 2, "with Endurance 2")
	var guard: CardDef = lib.get_def("signature_art_17")
	check(guard.stops_kind("art", false) and guard.stops_kind("strike", false) and guard.remove_after_use, "Skillful Guard stops either kind, once")
	eq(lib.get_def("relic_05").raw.get("reserve_size", 0), 9, "the Relic's Reserve holds 9")


## "Namekian Heritage only. Shuffle the top or bottom 3 cards from your discard pile into your Life
## Deck."
func test_root_new_shoots_takes_the_top_or_bottom_three() -> void:
	var e: DuelEngine = real_engine(real_deck(["root_combat_08"], "pact", "root"), real_deck([], "vigil"))
	to_attack(e, 0)
	var pile: Array[CardInstance] = []
	for id in ["tide_drill_05", "tide_drill_06", "storm_drill_03", "storm_drill_04", "steel_drill_01", "steel_drill_04"]:
		pile.append(real_to_discard(e, 0, id))
	answer(e, &"use", uid_in_hand(e, 0, "root_combat_08"))
	eq(prompt_kind(e), &"pick_option", "top or bottom is asked")
	answer(e, &"pick_option", -1, "1")
	for i in range(3):
		eq(pile[i].zone, &"life_deck", "bottom card %d went back" % (i + 1))
	for i in range(3, 6):
		eq(pile[i].zone, &"discard", "top card %d stayed" % (i - 2))


## "All of your physical attacks do +2 power stages of damage for the remainder of Combat. Take a
## Dragon Ball in play and place it at the bottom of its owner's Life Deck." The CRD limits it to a
## Dragon Ball the opponent controls.
func test_root_swallowing_earth_puts_a_seal_under_its_deck() -> void:
	var e: DuelEngine = real_engine(real_deck(["root_combat_07"], "pact", "root"), real_deck([], "vigil"))
	var mine: CardInstance = real_inject(e, 0, "seal_08")
	var theirs: CardInstance = real_inject(e, 1, "seal_09")
	to_attack(e, 0)
	answer(e, &"use", uid_in_hand(e, 0, "root_combat_07"))
	eq(mine.zone, &"in_play", "the user's own Seal stays")
	eq(theirs.zone, &"life_deck", "the opponent's went to a Life Deck")
	eq(e.player(1).life_deck.back(), theirs, "its owner's, at the bottom")
	var total: int = 0
	for entry in e._modifiers_for(e.player(0), "own", "strike", null, {}):
		total += int((entry["m"] as Dictionary).get("stages", 0))
	eq(total, 2, "Strikes do +2 for the Combat")
	eq(e._modifiers_for(e.player(0), "own", "art", null, {}).size(), 0, "Arts do not")


## "Physical attack, or stops a physical attack" and "you may discard a card in your hand that can
## perform an energy attack to stop an energy attack. Raise your Main Personality's PUR by +2."
func test_root_guards_stop_their_kind() -> void:
	var e: DuelEngine = real_engine(real_deck([], "pact"), real_deck([], "vigil", "root"))
	var them: PlayerState = e.player(1)
	var guard: CardInstance = real_to_hand(e, 1, "root_strike_19")
	check(e._defense_usable(them, guard, "strike", false), "Oakheart Guard stops a Strike")
	check(not e._defense_usable(them, guard, "art", false), "not an Art")
	var surge: int = e.surge_of(them)
	var watch: CardInstance = real_inject(e, 1, "root_drill_06")
	eq(e.surge_of(them), surge + 2, "Frost Watch raises Surge by 2")
	e._move_to_discard(guard)
	for c in them.hand.duplicate():
		if c.def.is_attack() and c.def.attack_kind() == "art":
			e._move_to_discard(c)
	check(not e._defense_usable(them, watch, "art", false), "with no Art in hand it cannot stop")
	real_to_hand(e, 1, "root_art_12")
	check(e._defense_usable(them, watch, "art", false), "an Art in hand lets it stop an Art")
	check(not e._defense_usable(them, watch, "strike", false), "but never a Strike")


## "Focused physical attack doing +3. Empower 3. Your opponent cannot use Defense Shields for the
## remainder of Combat. Discard up to 3 of your opponent's Allies in play."
func test_root_stone_cleaver_bars_shields_and_takes_allies() -> void:
	var cleaver: CardDef = shipped().get_def("root_strike_18")
	for line in cleaver.effects:
		check(bool(line.get("after_empower", false)), "%s is printed after Empower" % str(line.get("op", "")))
	var e: DuelEngine = real_engine(real_deck([], "pact", "root"), real_deck([], "vigil", "storm"))
	var them: PlayerState = e.player(1)
	real_inject(e, 1, "storm_drill_01")
	check(not e._available_shields(them, "strike", false).is_empty(), "their Drill shields a Strike")
	e._apply_effect(cleaver.effects[0], 0, {}, null)
	check(e._available_shields(them, "strike", false).is_empty(), "no shield is left for the Combat")
	var ally: CardInstance = real_inject(e, 1, _an_ally_id())
	e._apply_effect(cleaver.effects[1], 0, {}, null)
	if prompt_kind(e) == &"pick_in_play":
		check(e.prompt.find(&"pick_none") != null, "\"up to\" lets them all stay")
		answer(e, &"pick_in_play", ally.uid)
	eq(ally.zone, &"discard", "the Ally was discarded")


## "Choose 1 of your opponent's Drills in play. Your opponent cannot use the power of that Drill for
## the remainder of the game. You may have up to 8 copies. Remove from the game after use."
func test_root_strangling_vine_silences_a_drill_for_the_game() -> void:
	var vine: CardDef = shipped().get_def("root_noncombat_05")
	eq(vine.limit_per_deck, 8, "eight copies are allowed")
	check(vine.remove_after_use, "and it leaves the game after use")
	var e: DuelEngine = real_engine(real_deck([], "pact", "root"), real_deck([], "vigil"))
	var them: PlayerState = e.player(1)
	var hard: CardInstance = real_inject(e, 1, "steel_drill_01")
	var other: CardInstance = real_inject(e, 1, "steel_drill_04")
	eq(e._modifiers_for(them, "own", "strike", null, {}).size(), 1, "their Drill adds to Strikes")
	e._apply_effect(vine.effects[0], 0, {}, null)
	eq(prompt_kind(e), &"pick_option", "the user picks which Drill")
	answer(e, &"pick_option", hard.uid)
	check(hard.silenced, "that Drill is silenced")
	check(not other.silenced, "the other is not")
	eq(hard.zone, &"in_play", "it stays in play")
	eq(e._modifiers_for(them, "own", "strike", null, {}).size(), 0, "and adds nothing")
	skip_to_turn(e, 3)
	check(hard.silenced, "for the rest of the game")


## "(Does not count towards Styled Drills.) Your attacks do +2 power stages of damage. The power stage
## costs of cards you use are reduced by 1, to a minimum of 1."
func test_root_sap_flow_discounts_costs_outside_the_drill_lock() -> void:
	var e: DuelEngine = real_engine(real_deck([], "pact", "root"), real_deck([], "vigil"))
	var me: PlayerState = e.player(0)
	real_inject(e, 0, "root_drill_05")
	eq(me.drill_school(), "", "it does not set the Drill school")
	real_inject(e, 0, "storm_drill_03")
	eq(me.drill_school(), "storm", "so a Storm Drill still does")
	eq(e._card_cost(me, 3), 2, "a cost of 3 becomes 2")
	eq(e._card_cost(me, 1), 1, "a cost of 1 stays 1")
	eq(e._cost_stages(shipped().get_def("root_art_12").attack, me), 1, "an Art costing 1 stays at 1")
	var total: int = 0
	for entry in e._modifiers_for(me, "own", "art", null, {}):
		total += int((entry["m"] as Dictionary).get("stages", 0))
	check(total >= 2, "attacks do +2")


## "Remove one of your allies from the game to raise your anger 2 levels" and "raise all of your
## Allies to their highest power stage ... discard 1 card from the top of your Life Deck for each Ally".
func test_root_fallen_oak_and_grove_kin_spend_allies() -> void:
	var oak: CardDef = shipped().get_def("root_noncombat_03")
	var e: DuelEngine = real_engine(real_deck([], "pact", "root"), real_deck([], "vigil"))
	var me: PlayerState = e.player(0)
	check(not e._can_play(me, oak), "Fallen Oak needs an Ally")
	var ally: CardInstance = real_inject(e, 0, _an_ally_id())
	check(e._can_play(me, oak), "with one in play it may be placed")
	me.fervor = 0
	# The turn's own prompt is still standing in this hand-driven test; the lines wait behind it.
	e.prompts.clear()
	e._enqueue([oak.effects[0]], "use", 0, {}, null)
	e._drain()
	if prompt_kind(e) == &"pick_in_play":
		answer(e, &"pick_in_play", ally.uid)
	e._drain()
	eq(ally.zone, &"removed", "the Ally left the game")
	eq(me.fervor, 2, "and Fervor rose 2")
	var f: DuelEngine = real_engine(real_deck([], "pact", "root"), real_deck([], "vigil"))
	var p: PlayerState = f.player(0)
	var a1: CardInstance = real_inject(f, 0, _an_ally_id())
	var a2: CardInstance = real_inject(f, 0, _an_ally_id())
	p.duelist.energy = 5
	var deck: int = p.life_deck.size()
	for line in shipped().get_def("root_noncombat_04").effects:
		f._apply_effect(line, 0, {}, null)
	f._drain()
	eq(a1.energy, CardInstance.MAX_STAGE, "the first Ally is at full")
	eq(a2.energy, CardInstance.MAX_STAGE, "and the second")
	check(f.may_ally_control(p), "an Ally may take control though the duelist is well above 1")
	eq(deck - p.life_deck.size(), 2, "and the owner lost a card per Ally")


## "When entering Combat, shuffle the top card from your discard pile into your Life Deck. If that
## card is a Namekian Style card, draw a card" and "draw the bottom card of your Life Deck. If it is
## a Namekian Style Card, you may show it to your opponent and draw another card from the bottom".
func test_root_compost_and_deeproot_masteries_draw_on_a_root_card() -> void:
	var compost: Dictionary = shipped().get_def("root_mastery_02").effects[0]
	for top_id in ["root_strike_04", "tide_drill_05"]:
		var e: DuelEngine = real_engine(real_deck([], "pact", "root"), real_deck([], "vigil"))
		var me: PlayerState = e.player(0)
		var top: CardInstance = real_to_discard(e, 0, top_id)
		var held: int = me.hand.size()
		e.prompts.clear()
		e._enqueue([compost], "entering_combat", 0, {}, null)
		e._drain()
		eq(top.zone, &"life_deck", "the top discard went into the deck")
		eq(me.hand.size() - held, 1 if top_id == "root_strike_04" else 0, "a draw only for a Root card (%s)" % top_id)
	var deep: Dictionary = shipped().get_def("root_mastery_03").effects[0]
	for bottom_id in ["root_strike_04", "tide_drill_05"]:
		var f: DuelEngine = real_engine(real_deck([], "pact", "root"), real_deck([], "vigil"))
		var p: PlayerState = f.player(0)
		var below: CardInstance = real_to_deck(f, 0, bottom_id)
		var next_below: CardInstance = p.life_deck[p.life_deck.size() - 2]
		f.prompts.clear()
		f._enqueue([deep], "entering_combat", 0, {}, null)
		f._drain()
		eq(below.zone, &"hand", "the bottom card was drawn (%s)" % bottom_id)
		if bottom_id == "root_strike_04":
			eq(prompt_kind(f), &"pick_option", "showing it is optional")
			answer(f, &"pick_option", -1, "yes")
			f._drain()
			check(has_event(f, &"cards_revealed"), "it was shown")
			eq(next_below.zone, &"hand", "and the next bottom card was drawn")
		else:
			eq(next_below.zone, &"life_deck", "no second draw for another school")


## "When one of your Non-Namekian Style cards goes to the discard pile, remove it from the game
## instead. All of your Namekian Style attacks gain 'If successful, place the bottom 2 cards of your
## discard pile on the bottom of your Life Deck and gain 3 power stages.'"
func test_root_sacred_grove_exiles_other_schools_and_grants_a_hit() -> void:
	var d: DeckList = real_deck([], "pact", "root")
	d.mastery_id = "root_mastery_04"
	var e: DuelEngine = real_engine(d, real_deck([], "vigil"))
	var other: CardInstance = real_to_hand(e, 0, "tide_strike_16")
	e._move_to_discard(other)
	eq(other.zone, &"removed", "another school's card leaves the game")
	var own: CardInstance = real_to_hand(e, 0, "root_strike_04")
	e._move_to_discard(own)
	eq(own.zone, &"discard", "a Root card is discarded")
	var theirs: CardInstance = real_to_hand(e, 1, "tide_strike_16")
	e._move_to_discard(theirs)
	eq(theirs.zone, &"discard", "the opponent's cards are untouched")
	var strike_card: CardInstance = real_to_hand(e, 0, "root_strike_05")
	var built: Dictionary = e._build_attack(0, strike_card, strike_card.def.attack, strike_card.def.effects, false, false, false, null, true)
	eq((built["effects"] as Array).size(), strike_card.def.effects.size() + 2, "a Root attack gains the two lines")
	var plain: CardInstance = e._instance(shipped().get_def("tide_strike_16"), 0, &"hand")
	var other_built: Dictionary = e._build_attack(0, plain, plain.def.attack, plain.def.effects, false, false, false, null, true)
	eq((other_built["effects"] as Array).size(), plain.def.effects.size(), "another school's attack gains nothing")


# --- The Storm review, 2026-09-23 ------------------------------------------

## "All energy attacks performed by your main personality do +1 life card damage if successful or
## cost 1 less power stage to perform to a minimum of 1. Orange style energy attacks do +1 life card
## damage if successful and cost 1 less power stage to perform to a minimum of 1, instead."
func test_storm_brewing_mastery_asks_wound_or_price() -> void:
	for pick in ["life", "cost", "storm"]:
		var d: DeckList = real_deck(["tide_art_02", "storm_art_07"], "pact", "storm")
		d.mastery_id = "storm_mastery_01"
		var e: DuelEngine = real_engine(d, real_deck([], "vigil"))
		var me: PlayerState = e.player(0)
		to_attack(e, 0)
		me.duelist.energy = 5
		var title: String = me.mastery.def.title
		if pick == "storm":
			answer(e, &"attack", uid_in_hand(e, 0, "storm_art_07"))
			check(e.prompt == null or str(e.prompt.context.get("purpose", "")) != "art_boost", "a Storm Art is not asked about")
		else:
			answer(e, &"attack", uid_in_hand(e, 0, "tide_art_02"))
			eq(str(e.prompt.context.get("purpose", "")), "art_boost", "another school's Art asks which half")
			eq(e.prompt.player, 0, "the attacker chooses")
			answer(e, &"pick_option", -1, pick)
		eq(me.duelist.energy, 3 if pick == "life" else 4, "%s: the price paid" % pick)
		settle(e, 12)
		eq(_added_by(e, title, "life"), 0 if pick == "cost" else 1, "%s: the wound added" % pick)
	var f_deck: DeckList = real_deck([], "pact", "storm")
	f_deck.mastery_id = "storm_mastery_01"
	var f: DuelEngine = real_engine(f_deck, real_deck([], "vigil"))
	var ally: CardInstance = real_inject(f, 0, _an_ally_id())
	check(f._art_boost(f.player(0), ally).is_empty(), "an Ally's Arts get nothing")
	f.player(0).controlling = ally
	eq(f._cost_stages(shipped().get_def("tide_art_02").attack, f.player(0)), 2, "and pay full price")


## "If your Storm Art is successful, your opponent may not use Strike cards during their next attack
## phase." A Mastery's lines run on the Mastery's own triggers, so the line is `on_success`: written
## as `if_successful` it never ran at all.
func test_storm_squall_mastery_locks_strikes_after_a_storm_art() -> void:
	for id in ["storm_art_07", "tide_art_02"]:
		var d: DeckList = real_deck([id], "pact", "storm")
		d.mastery_id = "storm_mastery_02"
		var e: DuelEngine = real_engine(d, real_deck([], "vigil"))
		to_attack(e, 0)
		e.player(0).duelist.energy = 5
		answer(e, &"attack", uid_in_hand(e, 0, id))
		settle(e, 12)
		var storm: bool = id.begins_with("storm")
		eq(e._forbidden(e.player(1), "strike_cards"), storm, "%s: a landed Art locks Strikes only when it is Storm" % id)


## Every Mastery line names a trigger the engine runs for a Mastery. Anything else sits in the data
## and never resolves, which is how the Squall lock went missing.
func test_every_mastery_line_runs_on_a_mastery_trigger() -> void:
	var runs: Array[String] = ["use", "on_attack", "on_success", "on_stopped", "entering_combat", "rejuvenation", "secondary"]
	for id in shipped().all_ids():
		var def: CardDef = shipped().get_def(id)
		if def.type != CardDef.Type.MASTERY:
			continue
		for e in def.effects:
			var trigger: String = str(e.get("trigger", "secondary"))
			check(runs.has(trigger), "%s: trigger '%s' never runs on a Mastery" % [id, trigger])
			if trigger == "secondary":
				check(not def.defense.is_empty(), "%s: a secondary line on a Mastery only runs when it defends" % id)


## The shipped Storm cards, each against the clause the review found it missing.
func test_storm_shipped_cards_match_their_printed_text() -> void:
	var e: DuelEngine = real_engine(real_deck([], "pact", "storm"), real_deck([], "vigil"))
	var me: PlayerState = e.player(0)
	# "Allows the attacker to pay 1 stage instead of 2 on any energy attack."
	real_inject(e, 0, "storm_drill_04")
	eq(e._cost_stages(shipped().get_def("tide_art_02").attack, me), 1, "a 2-cost Art costs 1")
	eq(e._cost_stages(shipped().get_def("storm_art_15").attack, me), 3, "a 3-cost Art is untouched")
	eq(e._cost_stages(shipped().get_def("storm_art_20").attack, me), 1, "and a 1-cost Art stays 1")
	# "Your opponent must pass in his next attack phase."
	e._apply_effect(shipped().get_def("storm_art_10").effects[0], 0, {}, null)
	check(e.player(1).pass_next_phase, "Stunning Bolt makes them pass, which counts toward ending Combat")
	check(not e.player(1).skip_next_attack_phase, "not skip")
	# "For the remainder of Combat, damage cannot be prevented. Empower 2.": printed before Empower.
	var mael: CardInstance = real_to_hand(e, 0, "storm_strike_01")
	var built: Dictionary = e._build_attack(0, mael, mael.def.attack, mael.def.effects, false, false, true, null, true)
	var kept: bool = false
	for line in built["effects"]:
		if str(line.get("what", "")) == "no_prevent":
			kept = true
	check(kept, "an Empowered Maelstrom keeps its no-prevent line")
	# "Search your Life Deck for an Energy Combat card, show it to your opponent."
	var found: CardInstance = real_to_deck(e, 0, "storm_art_07")
	e._search_take(me, found, shipped().get_def("storm_strike_02").effects[0]["then"][0])
	check(has_event(e, &"cards_revealed"), "Overcharge shows the Art it found")
	# "You may pay 2 power stages to search": a cost, which Free Current waives.
	var pay_line: Dictionary = shipped().get_def("storm_strike_02").effects[0]
	for case in ["short", "pays", "waived"]:
		var g: DuelEngine = real_engine(real_deck([], "pact", "storm"), real_deck([], "vigil"))
		var gp: PlayerState = g.player(0)
		gp.duelist.energy = 1 if case == "short" else 5
		if case == "waived":
			var rider: CardInstance = real_inject(g, 0, "storm_combat_02")
			rider.attached_to = gp.duelist
		g.prompts.clear()
		g._enqueue([pay_line], "secondary", 0, {}, null)
		g._drain()
		if case == "short":
			check(g.prompt == null, "with 1 Energy the cost cannot be paid, so nothing is asked")
			continue
		eq(str(g.prompt.context.get("purpose", "")), "pay_cost", "%s: the payment is offered" % case)
		answer(g, &"pick_option", -1, "yes")
		# The card's own cost: Free Current does not waive it (CRD ruling on Orange Gambit).
		eq(gp.duelist.energy, 3, "%s: the Energy paid" % case)
		eq(prompt_kind(g), &"pick_option", "%s: then the deck is searched" % case)
		check(bool(g.prompt.context.get("search", false)), "%s: it is the search" % case)
	# "All energy attacks this personality performs for the remainder of Combat do +2 life cards."
	e._apply_effect(shipped().get_def("storm_strike_09").effects[0], 0, {}, null)
	eq(e._modifiers_for(me, "own", "art", null, {}).size(), 1, "the duelist's Arts gain it")
	var ally: CardInstance = real_inject(e, 0, _an_ally_id())
	me.controlling = ally
	eq(e._modifiers_for(me, "own", "art", null, {}).size(), 0, "an Ally's do not")


# --- The Storm expansion, 2026-09-23 ---------------------------------------

## "When receiving damage from a physical attack, you may draw the bottom card of your discard pile"
## and "you may remove this Drill from the game when you stop a physical or energy attack to stop
## all of your opponent's attacks of the same type for the remainder of Combat."
func test_storm_backflash_and_grounding_drills_answer_the_defense() -> void:
	var e: DuelEngine = real_engine(real_deck([], "pact"), real_deck([], "vigil", "storm"))
	var them: PlayerState = e.player(1)
	real_inject(e, 1, "storm_drill_05")
	to_attack(e, 0)
	var oldest: CardInstance = real_to_discard(e, 1, "tide_drill_05")
	real_to_discard(e, 1, "tide_drill_06")
	answer(e, &"attack", uid_in_hand(e, 0, "root_strike_04"))
	settle(e, 12)
	eq(prompt_kind(e), &"pick_option", "the Strike's damage offers the Drill")
	eq(e.prompt.player, 1, "to the one who took it")
	answer(e, &"pick_option", -1, "yes")
	eq(oldest.zone, &"hand", "the bottom card of the pile was drawn")
	eq(oldest.owner, them.index, "their own")
	var f: DuelEngine = real_engine(real_deck([], "pact"), real_deck([], "vigil", "storm"))
	var ground: CardInstance = real_inject(f, 1, "storm_drill_07")
	f.prompts.clear()
	f._enqueue(ground.def.effects, "on_stop", 1, {"attack": {"kind": "art"}}, ground)
	f._drain()
	eq(prompt_kind(f), &"pick_option", "the stop offers the Drill")
	answer(f, &"pick_option", -1, "yes")
	eq(ground.zone, &"removed", "the Drill left the game")
	var held: Dictionary = f._floating_first(1, "stop_all")
	eq(str(held.get("kind", "")), "art", "and every Art against them is stopped this Combat")
	eq(shipped().get_def("storm_drill_07").limit_per_deck, 2, "two copies at most")


## "Once per combat, after you have performed a successful energy attack, search through defender's
## life deck for any card and discard it" and "your Main Personality's PUR is +1. Your Defense
## Shields can stop focused attacks."
func test_storm_seeking_spark_and_stormwall_drills() -> void:
	var e: DuelEngine = real_engine(real_deck([], "pact", "storm"), real_deck([], "vigil"))
	var spark: CardInstance = real_inject(e, 0, "storm_drill_06")
	e.prompts.clear()
	e._enqueue(spark.def.effects, "on_success", 0, {"attack": {"kind": "strike"}}, spark)
	e._drain()
	check(e.prompt == null, "a Strike does not wake it")
	e._enqueue(spark.def.effects, "on_success", 0, {"attack": {"kind": "art"}}, spark)
	e._drain()
	eq(prompt_kind(e), &"pick_option", "an Art does")
	check(e.prompt.context.has("library"), "their whole deck is shown")
	var taken: int = e.prompt.options[0].card
	answer(e, &"pick_option", taken)
	eq(e.card(taken).zone, &"discard", "the card was discarded")
	eq(e.card(taken).owner, 1, "from their deck")
	check(not e._drill_use_available(spark), "and it is spent for the Combat")
	var f: DuelEngine = real_engine(real_deck(["storm_strike_09"], "pact", "storm"), real_deck([], "vigil"))
	var them: PlayerState = f.player(1)
	real_inject(f, 1, "storm_drill_01")
	var surge: int = f.surge_of(them)
	var focused_card: CardInstance = real_to_hand(f, 0, "storm_strike_09")
	var a: Dictionary = f._build_attack(0, focused_card, focused_card.def.attack, focused_card.def.effects, false, false, false, null, true)
	f._apply_shields(them, a)
	check(not bool(a["stopped"]), "a Focused Strike walks through the Strike shield")
	real_inject(f, 1, "storm_drill_08")
	eq(f.surge_of(them), surge + 1, "Stormwall raises Surge by 1")
	var b: Dictionary = f._build_attack(0, focused_card, focused_card.def.attack, focused_card.def.effects, false, false, false, null, true)
	f.player(1).drills()[0].shield_used_combat = -1
	f._apply_shields(them, b)
	check(bool(b["stopped"]), "with Stormwall the shield stops it")


## "Search the top 4 cards of your Life Deck for a Drill and place it into play if possible",
## "you may search your Life Deck for any colorless Drill [or Storm Drill] and place it in play at the
## end of Combat", and "you do not have to discard any Drills in play when your Main Personality
## advances or loses a personality level."
func test_storm_gathering_front_lightning_rod_and_steady_current() -> void:
	var front: CardDef = shipped().get_def("storm_strike_13")
	check(bool(front.effects[0].get("after_empower", false)), "Gathering Front's look is printed after Empower")
	var e: DuelEngine = real_engine(real_deck(["storm_strike_14"], "pact", "storm"), real_deck([], "vigil"))
	var me: PlayerState = e.player(0)
	to_attack(e, 0)
	var rod_drill: CardInstance = real_to_deck(e, 0, "storm_drill_03")
	answer(e, &"attack", uid_in_hand(e, 0, "storm_strike_14"))
	check(e._has_floating(0, "at_combat_end"), "the search waits for the end of Combat")
	eq(rod_drill.zone, &"life_deck", "and nothing is placed yet")
	e.prompts.clear()
	e._begin_combat_end()
	e._drain()
	eq(prompt_kind(e), &"pick_option", "at the end of Combat the deck is searched")
	check(e.prompt.find(&"pick_option", rod_drill.uid) != null, "a Storm Drill is offered")
	answer(e, &"pick_option", rod_drill.uid)
	eq(rod_drill.zone, &"in_play", "and placed")
	var hits: Array[CardInstance] = e.search_candidates(me, shipped().get_def("storm_strike_14").effects[0]["params"]["effects"][0])
	for c in hits:
		check(c.def.school == "" or c.def.school == "storm", "%s is Freestyle or Storm" % c.def.title)
	var f: DuelEngine = real_engine(real_deck([], "pact", "storm"), real_deck([], "vigil"))
	var p: PlayerState = f.player(0)
	var kept: CardInstance = real_inject(f, 0, "storm_drill_03")
	f._apply_effect(shipped().get_def("storm_art_24").effects[0], 0, {}, null)
	f._aspect_up(p)
	eq(kept.zone, &"in_play", "a climb keeps the Drill")
	f._lose_aspect(p, 1)
	eq(kept.zone, &"in_play", "and so does a fall")


## "All of your physical attacks do +2 power stages of damage. If you perform a successful Orange
## Style physical attack, all other physical attacks you perform for the remainder of Combat do
## additional +1 life cards of damage" and "once per Combat during your Attacker Attacks phase, you
## may discard one of your Orange Style Drills in play to search your Life Deck for 2 different
## Drills and place them into play. During your Rejuvenation Step, you may place the top Drill in
## your discard pile on the bottom of your Life Deck."
func test_storm_gale_and_conductor_masteries() -> void:
	var d: DeckList = real_deck(["storm_strike_12"], "pact", "storm")
	d.mastery_id = "storm_mastery_03"
	var e: DuelEngine = real_engine(d, real_deck([], "vigil"))
	var me: PlayerState = e.player(0)
	var total: int = 0
	for entry in e._modifiers_for(me, "own", "strike", null, {}):
		total += int((entry["m"] as Dictionary).get("stages", 0))
	eq(total, 2, "Strikes do +2")
	to_attack(e, 0)
	answer(e, &"attack", uid_in_hand(e, 0, "storm_strike_12"))
	settle(e, 12)
	var life: int = 0
	for f in e.state.floating:
		if int(f.get("owner", -1)) == 0 and str(f.get("op", "")) == "modifier" and str(f.get("kind", "")) == "strike":
			life += int(f.get("life", 0))
	eq(life, 1, "a landed Storm Strike gives the other Strikes +1 wound")
	var c_deck: DeckList = real_deck([], "pact", "storm")
	c_deck.mastery_id = "storm_mastery_04"
	var g: DuelEngine = real_engine(c_deck, real_deck([], "vigil"))
	var p: PlayerState = g.player(0)
	to_attack(g, 0)
	check(g.prompt.find(&"use", p.mastery.uid) == null, "with no Storm Drill in play it is not offered")
	var spent: CardInstance = real_inject(g, 0, "storm_drill_03")
	var one: CardInstance = real_to_deck(g, 0, "storm_drill_01")
	real_to_deck(g, 0, "storm_drill_01")
	var two: CardInstance = real_to_deck(g, 0, "storm_drill_02")
	g._prompt_attack_action(p)
	answer(g, &"use", p.mastery.uid)
	eq(spent.zone, &"discard", "the Storm Drill was discarded")
	eq(prompt_kind(g), &"pick_option", "then the deck is searched")
	check(g.submit(Command.new(0, &"pick_option", -1, [one.uid, two.uid])), "two different Drills are taken")
	eq(one.zone, &"in_play", "the first went into play")
	eq(two.zone, &"in_play", "and the second")
	eq(prompt_kind(g), &"attack_action", "and the attack phase is still open")
	check(g.prompt.find(&"use", p.mastery.uid) == null, "once per Combat")
	# The Recover step: the top Drill of the pile, not the top card.
	var h: DuelEngine = real_engine(c_deck, real_deck([], "vigil"))
	var q: PlayerState = h.player(0)
	var pile_drill: CardInstance = real_to_discard(h, 0, "storm_drill_03")
	real_to_discard(h, 0, "root_strike_04")
	h.prompts.clear()
	h.state.active = 0
	h._recover()
	h._drain()
	eq(prompt_kind(h), &"pick_option", "the Mastery offers its line in the Recover step")
	answer(h, &"pick_option", -1, "yes")
	eq(pile_drill.zone, &"life_deck", "the Drill went under the deck")
	eq(q.life_deck.back(), pile_drill, "at the bottom")


# --- The Freestyle review, 2026-09-24 ---------------------------------------

## The Freestyle cards, each against the clause the review found it missing.
## A boss's special power sits outside its deck and off the table, and spends one of its uses each
## time: a Non-Combat's use from the attack phase, a counter in the respond window, a Drill always on.
func test_a_boss_power_is_used_from_outside_the_deck() -> void:
	if _shipped_table == null:
		_shipped_table = StrikeTable.load_from("res://data/strike_table.json")
	var f: DuelEngine = DuelEngine.new()
	f.shuffle_decks = false
	var decks: Array[DeckList] = [real_deck([], "pact"), real_deck([], "vigil")]
	f.setup(decks, shipped(), _shipped_table, 7)
	check(f.set_boss_power(0, "freestyle_noncombat_20"), "a banned Non-Combat is taken as a boss power")
	check(not f.set_boss_power(1, "personality_01"), "a personality is not")
	f.start()
	var boss: PlayerState = f.player(0)
	eq(boss.boss_power.zone, &"boss_power", "the power sits outside the deck and the table")
	check(not boss.in_play.has(boss.boss_power) and not boss.life_deck.has(boss.boss_power), "in neither")
	eq(SeatPlayer.of(boss, f).boss_power, boss.boss_power.uid, "and both seats are shown it")
	to_attack(f, 0)
	check(f.prompt.find(&"use", boss.boss_power.uid) != null, "the attack phase offers it")
	f.player(1).fervor = 0
	answer(f, &"use", boss.boss_power.uid)
	settle(f, 4, [&"decline"])
	eq(f.player(1).fervor, 3, "Tempers Leveled set the rival's Fervor to 3")
	eq(boss.boss_power_uses, 1, "one use spent")
	eq(boss.boss_power.zone, &"boss_power", "and the power is still held")
	boss.boss_power_uses = DuelEngine.BOSS_POWER_USES
	f._prompt_attack_action(boss)
	check(f.prompt.find(&"use", boss.boss_power.uid) == null, "spent out, it is no longer offered")
	# The counter works from outside the deck too, and stays held after it is spent once.
	var g: DuelEngine = DuelEngine.new()
	g.shuffle_decks = false
	var g_decks: Array[DeckList] = [real_deck(["storm_art_07"], "pact", "storm"), real_deck([], "vigil")]
	g.setup(g_decks, shipped(), _shipped_table, 7)
	g.set_boss_power(1, "freestyle_noncombat_19")
	g.start()
	var guard: PlayerState = g.player(1)
	to_attack(g, 0)
	var bolt: int = uid_in_hand(g, 0, "storm_art_07")
	answer(g, &"attack", bolt)
	check(g.prompt.find(&"counter", guard.boss_power.uid) != null, "the boss may answer the attack with its power")
	answer(g, &"counter", guard.boss_power.uid)
	eq(g.card(bolt).zone, &"removed", "the attack card left the game")
	eq(guard.boss_power_uses, 1, "one use spent")
	eq(guard.boss_power.zone, &"boss_power", "and the power is still held")


## Three cards on the CRD's banned list, built as adventure bombs: "Stop the effect of any
## non-Dragon Ball card and remove the card from the game. You may use this at any time", "All
## player's anger is set to 3", and "whenever you play a card from your hand, place the bottom 2
## cards of your discard pile on the bottom of your Life Deck to have your Main Personality gain 2".
func test_banned_bombs_counter_level_and_feed() -> void:
	for id in ["freestyle_noncombat_19", "freestyle_noncombat_20", "freestyle_combat_21"]:
		check(bool(shipped().get_def(id).raw.get("banned", false)), "%s is adventure-only" % id)
		eq(shipped().get_def(id).limit_per_deck, 1, "%s runs one copy" % id)
	# The counter answers an attack card before it is performed and takes it out of the game.
	var e: DuelEngine = real_engine(real_deck(["storm_art_07"], "pact", "storm"), real_deck([], "vigil"))
	var undone: CardInstance = real_inject(e, 1, "freestyle_noncombat_19")
	to_attack(e, 0)
	var bolt: int = uid_in_hand(e, 0, "storm_art_07")
	answer(e, &"attack", bolt)
	eq(prompt_kind(e), &"respond", "the defender is asked before the attack is performed")
	check(e.prompt.find(&"counter", undone.uid) != null, "and may answer with the card in play")
	answer(e, &"counter", undone.uid)
	eq(e.card(bolt).zone, &"removed", "the attack card left the game")
	check(not has_event(e, &"attack_declared"), "and was never performed")
	eq(undone.zone, &"discard", "the counter was spent")
	# Every player's Fervor is set to 3.
	var f: DuelEngine = real_engine(real_deck([], "pact"), real_deck([], "vigil"))
	f.player(0).fervor = 0
	f.player(1).fervor = 5
	for line in shipped().get_def("freestyle_noncombat_20").effects:
		f._apply_effect(line, 0, {}, null)
	eq(f.player(0).fervor, 3, "the user's Fervor is 3")
	eq(f.player(1).fervor, 3, "and so is the opponent's")
	# Each card played from hand afterwards offers the trade.
	var g: DuelEngine = real_engine(real_deck(["freestyle_combat_21", "storm_art_07"], "pact"), real_deck([], "vigil"))
	var gp: PlayerState = g.player(0)
	to_attack(g, 0)
	var low: CardInstance = real_to_discard(g, 0, "tide_drill_05")
	g.player(0).discard.erase(low)
	g.player(0).discard.insert(0, low)
	real_to_discard(g, 0, "tide_drill_06")
	answer(g, &"use", uid_in_hand(g, 0, "freestyle_combat_21"))
	settle(g, 4, [&"decline"])
	check(g._has_floating(0, "on_hand_play"), "the rest of Combat is set up")
	gp.duelist.energy = 2
	var played: CardInstance = g.card(uid_in_hand(g, 0, "root_strike_04"))
	g.prompts.clear()
	g._played_from_hand(gp, played)
	g._drain()
	eq(prompt_kind(g), &"pick_option", "playing a card offers the trade")
	answer(g, &"pick_option", -1, "yes")
	g._drain()
	eq(low.zone, &"life_deck", "the bottom discards went under the deck")
	eq(gp.duelist.energy, 4, "and the duelist gained 2")


## The personality cards, each against the clause or PUR the review found it missing.
func test_personalities_match_their_printed_cards() -> void:
	# Bojack: "Personalities with the Bojack Unbound Subset Symbol can take control of Combat, even
	# if this personality is 2 stages above 0 or higher", and +1 per such Ally in play.
	var sable_deck: DeckList = real_deck([], "pact", "", "Sable Draik")
	var e: DuelEngine = real_engine(sable_deck, real_deck([], "vigil"))
	var me: PlayerState = e.player(0)
	me.duelist.energy = 6
	var crew: CardInstance = real_inject(e, 0, "personality_40")
	var hireling: CardInstance = real_inject(e, 0, "personality_44")
	var allowed: Array[CardInstance] = e._control_allies(me)
	check(allowed.has(crew), "a Draik Ally may take control while Sable is above 1 Energy")
	check(not allowed.has(hireling), "Pim may not")
	real_inject(e, 1, "personality_43")
	var total: int = 0
	for entry in e._modifiers_for(me, "own", "strike", null, {}):
		total += e._modifier_amount(entry["m"], "stages", me)
	eq(total, 2, "Sable's +1 counts every Draik Ally in play, the rival's included, and not Pim")
	# "Your Allies get these modifiers too."
	me.controlling = crew
	total = 0
	for entry in e._modifiers_for(me, "own", "strike", null, {}):
		total += e._modifier_amount(entry["m"], "stages", me)
	eq(total, 2, "a Draik Ally in control gets Sable's modifiers")
	# Bram, Gnawing: "Your attacks do +1 Life", with no word for Allies, so an Ally's attacks go without.
	var gnawing: DeckList = real_deck([], "pact")
	gnawing.set_duelist(["personality_55", "personality_56", "personality_57"] as Array[String])
	var b: DuelEngine = real_engine(gnawing, real_deck([], "vigil"))
	var bram: PlayerState = b.player(0)
	eq(bram.duelist.def.id, "personality_55", "Bram is on Gnawing")
	eq(b._modifiers_for(bram, "own", "strike", null, {}).size(), 1, "Bram's own attacks carry his +1 Life")
	bram.controlling = real_inject(b, 0, "personality_40")
	eq(b._modifiers_for(bram, "own", "strike", null, {}).size(), 0, "an Ally in control does not")
	# "When you perform an attack, raise your anger 1 level. If Goku is in play, raise your anger 2 levels instead."
	var quarr: CardDef = shipped().get_def("personality_13")
	var rage: Dictionary = quarr.aspect_data(1)["constant"]["on_attack"][0]
	var q: DuelEngine = real_engine(real_deck([], "pact"), real_deck([], "vigil"))
	q.player(0).fervor = 0
	q._apply_effect(rage, 0, {}, null)
	eq(q.player(0).fervor, 1, "Quarr raises Fervor 1")
	real_inject(q, 1, "personality_50")
	q._apply_effect(rage, 0, {}, null)
	eq(q.player(0).fervor, 3, "and 2 with Edric in play on either side")
	eq(int(shipped().get_def("personality_14").aspect_data(2)["surge"]), 2, "Quarr's Enraged Aspect has the printed PUR 2")
	check(not shipped().get_def("personality_15").aspect_data(3)["power"].has("uses"), "Quarr's second use is earned, not printed")
	var g: DuelEngine = real_engine(real_deck([], "pact", "", "Halden Quarr"), real_deck([], "vigil"))
	var gp: PlayerState = g.player(0)
	gp.duelist.go_to_aspect(3)
	g._mark_power_used(gp.duelist)
	check(not g._power_available(gp, gp.duelist), "used once, Ironheart is spent")
	g._float(0, "power_second_use", "combat", {"source": gp.duelist.uid})
	check(g._power_available(gp, gp.duelist), "a first use off a Steel discard earns the second")
	# "You may draw up to 3 cards", "show it to your opponent", "you also may take the 2 bottom cards".
	check(bool(shipped().get_def("personality_20").aspect_data(5)["power"]["effects"][0].get("up_to", false)), "Caedan draws up to 3")
	check(bool(shipped().get_def("personality_36").aspect_data(2)["power"]["effects"][0].get("show", false)), "Emrys shows what he finds")
	check(bool(shipped().get_def("personality_44").aspect_data(1)["power"]["effects"][0].get("may", false)), "Pim may take the two")
	eq(str(shipped().get_def("personality_49").aspect_data(1)["power"]["effects"][0].get("per_bloodline", "")), "draconic", "Wren counts Draconic personalities only")
	# "Your Allies with Saiyan Heritage cannot be discarded or removed from the game": by anyone.
	var alder_deck: DeckList = real_deck([], "vigil", "", "Dame Alder Rooke")
	var f: DuelEngine = real_engine(alder_deck, real_deck([], "pact"))
	var kin: CardInstance = real_inject(f, 0, "personality_35")
	check(not f._in_play_candidates(f.player(0), "ally", true).has(kin), "Alder's Draconic Ally is safe from her own side's effects too")


## The signature cards, each against the clause the review found it missing.
func test_signature_cards_match_their_printed_text() -> void:
	var e: DuelEngine = real_engine(real_deck([], "pact"), real_deck([], "vigil"))
	var me: PlayerState = e.player(0)
	var them: PlayerState = e.player(1)
	# "Choose a player and remove his discard pile from the game."
	eq(str(shipped().get_def("signature_art_02").effects[0].get("choose_player", false)), "true", "Ashmark Leaves Nothing lets the user pick whose pile")
	# "You may shuffle any of your Allies that are removed from the game into your Life Deck."
	# The subset symbol is the Draik keyword: Pim and every other Ally are left out.
	var gone_a: CardInstance = e._instance(shipped().get_def("personality_40"), 0, &"removed")
	me.removed.append(gone_a)
	var gone_b: CardInstance = e._instance(shipped().get_def("personality_41"), 0, &"removed")
	me.removed.append(gone_b)
	var outsider: CardInstance = e._instance(shipped().get_def("personality_44"), 0, &"removed")
	me.removed.append(outsider)
	e.prompts.clear()
	e._apply_effect(shipped().get_def("signature_art_05").effects[2], 0, {}, null)
	eq(prompt_kind(e), &"pick_option", "Sable's Reckoning asks which")
	check(e.prompt.find(&"pick_none") != null, "and none is an answer")
	check(e.prompt.find(&"pick_option", outsider.uid) == null, "Pim is not a Draik and is not offered")
	answer(e, &"pick_option", gone_a.uid)
	eq(gone_a.zone, &"life_deck", "the chosen Ally went back")
	eq(gone_b.zone, &"removed", "the other stayed out")
	e.prompts.clear()
	e._choice = {}
	# "+2 life cards for each Ally in play with the subset symbol" names no side; "if you have at
	# least 2 Allies in play with the subset symbol" names yours.
	real_inject(e, 0, "personality_42")
	real_inject(e, 1, "personality_43")
	real_inject(e, 0, "personality_44")
	var volley: CardInstance = real_to_hand(e, 0, "freestyle_art_05")
	var built: Dictionary = e._build_attack(0, volley, volley.def.attack, volley.def.effects, false, false, false, null, true)
	var kin_life: int = 0
	for add in e._damage_calc(built)["adds"]:
		if str((add as Dictionary).get("source", "")).contains("Draik"):
			kin_life += int((add as Dictionary).get("life", 0))
	eq(kin_life, 4, "Knife Volley adds 2 per Draik Ally on either side, Pim not counted")
	check(not e._cond({"allies_tag_min": {"tag": "draik", "count": 2}}, 0, {}), "one Draik Ally of your own is short of two")
	real_inject(e, 0, "personality_41")
	check(e._cond({"allies_tag_min": {"tag": "draik", "count": 2}}, 0, {}), "two of them let Sable's Black Hands stay out")
	# "Attach this card to one of your personalities."
	eq(str(shipped().get_def("signature_art_10").effects[0].get("to", "")), "choose", "Sable's Lingering Curse picks its host")
	# "Stops the opponent from playing any other energy attack cards": a Power's Art is not a card.
	e._float(1, "forbid", "combat", {"what": "art_attack_cards"})
	check(not e._attack_allowed(them, shipped().get_def("storm_art_07")), "no Art from a card")
	check(e._attack_allowed(them, null, "art"), "a Power may still perform an Art")
	# "Prevent all damage from all attacks performed against you this Combat": no stop.
	eq(str(shipped().get_def("signature_combat_02").defense.get("stops", "")), "none", "Ashmark Will Not Break prevents, it does not stop")
	# "Shuffle 5 cards in your discard pile into your Life Deck": the user picks which.
	var coals: Dictionary = shipped().get_def("signature_noncombat_04").effects[1]
	check(str(coals.get("op", "")) == "search" and bool(coals.get("must", false)) and int(coals.get("amount", 0)) == 5, "Ashmark Stokes the Coals picks 5")
	# "You can only have one 'The Sword of Trunks' attached at a time."
	eq(int(shipped().get_def("signature_noncombat_06").attachment.get("limit_attached", 0)), 1, "one Heirloom Blade at a time")
	# "If used by Trunks or Kid Trunks, place a Trunks or Kid Trunks Named card from your discard."
	var quick: Dictionary = shipped().get_def("signature_strike_14").effects[1]
	check((quick["when"]["character"] as Array).has("Tavin Vale"), "Quickstep counts Tavin as well as Caedan")
	var tavin_card: CardInstance = e._instance(shipped().get_def("signature_strike_14"), 0, &"discard")
	check(e._search_matches(me, tavin_card, {"character": ["Caedan Vale", "Tavin Vale"]}, "hand"), "and finds either one's card")
	# "Remove 5 cards in your opponent's discard pile from the game": the user picks them.
	check(bool(shipped().get_def("signature_strike_19").effects[0].get("choose", false)), "Ashmark Scatters the Ashes picks its 5")
	# "If performed by a Main Personality with 'Android' in the title."
	eq(str(shipped().get_def("signature_art_11").effects[0]["when"].get("performed_by", "")), "duelist", "Sledge's Set Stance needs the duelist to perform it")
	# Named printed cards whose character has no name yet carry the placeholder.
	for id in ["freestyle_combat_17", "freestyle_noncombat_14", "grounds_03", "grounds_06"]:
		check(shipped().get_def(id).title.begins_with("PLACEHOLDER's "), "%s waits on a name" % id)
	# Named 2026-09-28: the Tourney team's mage.
	for id in ["freestyle_art_02", "freestyle_art_08", "freestyle_combat_16", "freestyle_noncombat_03", "freestyle_noncombat_15"]:
		var named: CardDef = shipped().get_def(id)
		check(named.title.begins_with("Voss' ") and named.character == "Aldo Voss", "%s leads with Aldo Voss" % id)


## A card on the CRD's banned list (Black Weakness Drill) is legal in adventure decks as a bomb and
## nowhere else, so no tournament or online deck may hold it.
func test_a_banned_card_is_an_adventure_bomb_only() -> void:
	var banned: CardDef = shipped().get_def("shade_drill_03")
	check(bool(banned.raw.get("banned", false)), "Forgetting Drill is on the banned list")
	eq(banned.limit_per_deck, 1, "and runs one copy as a bomb")
	var siege: DeckList = DeckList.load_from("res://data/decks/shade_mind_siege.json")
	check(not siege.cards.has("shade_drill_03"), "the tournament deck holds none")
	eq(DeckValidator.validate(siege, shipped()).size(), 0, "and is legal")
	siege.cards.append("shade_drill_03")
	check(DeckValidator.validate(siege, shipped()).has("'shade_drill_03' is banned outside adventure mode"), "adding it makes a tournament deck illegal")
	siege.mode = "adventure"
	check(not DeckValidator.validate(siege, shipped()).has("'shade_drill_03' is banned outside adventure mode"), "an adventure deck may run it")
	# A boss holds one banned card as a special power outside its deck, picked from the run seed
	# and the node (user, 2026-09-24); an ordinary fight holds none.
	var banned_ids: Array[String] = []
	for id in shipped().all_ids():
		if bool(shipped().defs[id].raw.get("banned", false)):
			banned_ids.append(id)
	var boss_row: Dictionary = {"node": "boss", "tier": "boss"}
	var picked: String = AdventureRules.boss_power_for(boss_row, 1234, "a1_boss", shipped())
	check(banned_ids.has(picked), "a boss gets a banned card: %s" % picked)
	eq(AdventureRules.boss_power_for(boss_row, 1234, "a1_boss", shipped()), picked, "the same run and node give the same power")
	var seen: Dictionary = {}
	for s in range(40):
		seen[AdventureRules.boss_power_for(boss_row, s, "a1_boss", shipped())] = true
	check(seen.size() > 1, "runs differ in the power they face")
	eq(AdventureRules.boss_power_for({"node": "duel", "tier": "t3"}, 1234, "a1_n3", shipped()), "", "an ordinary fight has none")
	for id in banned_ids:
		var none: DeckList = DeckList.load_from("res://data/adventure/opponents/shade_mind_siege_boss.json")
		check(not none.cards.has(id), "%s is not shuffled into a boss deck" % id)


func test_freestyle_cards_match_their_printed_text() -> void:
	var e: DuelEngine = real_engine(real_deck([], "pact"), real_deck([], "vigil"))
	var me: PlayerState = e.player(0)
	var them: PlayerState = e.player(1)
	# "Stop all energy attacks in this combat": the attacks against the user.
	eq(str(shipped().get_def("freestyle_art_01").defense.get("stop_all", "")), "art", "Dead Air stops every Art against its user")
	# "You may discard one of your Non-Combat cards in play to search ...": no discard, no search.
	var lob: Dictionary = shipped().get_def("freestyle_art_03").effects[0]
	check(not e._cond(lob["when"], 0, {}), "Lobbed Bolt offers nothing with no Non-Combat card in play")
	var drill_card: CardInstance = real_inject(e, 0, "storm_drill_03")
	check(e._cond(lob["when"], 0, {}), "a Drill in play counts as one")
	e.prompts.clear()
	e._enqueue([lob], "secondary", 0, {}, null)
	e._drain()
	answer(e, &"pick_option", -1, "yes")
	eq(drill_card.zone, &"discard", "the Drill was discarded")
	check(bool(e.prompt.context.get("search", false)), "and then the deck is searched")
	e.prompts.clear()
	e._choice = {}
	# "To have this attack do an additional +7 life cards": this attack only.
	var plain: CardInstance = real_to_hand(e, 0, "root_strike_04")
	e.state.attack = e._build_attack(0, plain, plain.def.attack, plain.def.effects, false, false, false, null, true)
	e._apply_effect({"op": "attack_bonus", "life": 7}, 0, {}, null)
	eq(int(e.state.attack["extra_life"]), 7, "Overreach adds to the attack in the air")
	e.state.attack = {}
	# "Draw the top 2 cards from your discard pile. Your opponent's Main Personality gains 5 power
	# stages. Remove from game after use." (CRD errata to Battle Pausing, which is restricted.)
	real_to_discard(e, 0, "tide_drill_05")
	real_to_discard(e, 0, "tide_drill_06")
	var held: int = me.hand.size()
	them.duelist.energy = 0
	for line in shipped().get_def("freestyle_combat_05").effects:
		e._apply_effect(line, 0, {}, null)
	eq(me.hand.size(), held + 2, "Respite: the user draws")
	eq(them.duelist.energy, 5, "and the opponent's duelist gains 5")
	check(shipped().get_def("freestyle_combat_05").remove_after_use, "removed after use")
	eq(shipped().get_def("freestyle_combat_05").limit_per_deck, 1, "one per deck")
	# "End Combat. Place the bottom card of your discard pile at the bottom of your Life Deck."
	var oldest: CardInstance = real_to_discard(e, 0, "tide_drill_05")
	e.player(0).discard.erase(oldest)
	e.player(0).discard.insert(0, oldest)
	e._apply_effect(shipped().get_def("freestyle_combat_18").effects[1], 0, {}, null)
	eq(oldest.zone, &"life_deck", "Parley: the user's own card goes back")
	# "Shuffle all of your opponent's Dragon Balls back into his Life Deck."
	var seal: CardInstance = real_inject(e, 1, "seal_08")
	e._apply_effect(shipped().get_def("freestyle_combat_08").effects[1], 0, {}, null)
	eq(seal.zone, &"life_deck", "Warding Call shuffles their Seals into their deck")
	# "You may only use this card in place of a defense. ... Stops a physical or energy attack and
	# stops all attacks for the remainder of Combat. ... If a Dragon Ball 7 from any Dragon Ball set is
	# in play, discard this card instead" (CRD errata to Mommy's Coming Dear).
	var rescue: CardDef = shipped().get_def("freestyle_noncombat_16")
	eq(str(rescue.defense.get("stops", "")), "any", "Kin's Rescue is a defense that stops a Strike or an Art")
	eq(str(rescue.defense.get("stop_all", "")), "any", "and every attack against its user after it")
	check(rescue.effects_for("use").is_empty(), "it is not used in the attack phase")
	check(not e._kept_by_seal(rescue), "with no Seal 7 in play it leaves the game")
	real_inject(e, 1, "seal_28")
	check(e._kept_by_seal(rescue), "any set's Seal 7, on either side, keeps it")
	# "Cards that stop an attack (including for the remainder of Combat) can only be played as a defense."
	check(not bool(shipped().get_def("freestyle_combat_01").raw.get("use_in_attack", false)), "Stillness is a defense only")
	eq(str(shipped().get_def("freestyle_combat_03").defense.get("stop_all", "")), "stopped", "Terms of the Pact stops all of the kind it stopped")
	# Restricted to one per deck (CRD restricted list), a sample.
	for id in ["freestyle_art_01", "freestyle_strike_01", "freestyle_combat_10", "freestyle_combat_16", "tide_strike_07", "pyre_strike_11"]:
		eq(shipped().get_def(id).limit_per_deck, 1, "%s is restricted to one" % id)
	# "When your opponent uses a card effect besides damage that makes you discard the top cards of
	# your Life Deck, you may discard this card from your hand to reduce the amount by 10."
	real_to_hand(e, 1, "freestyle_strike_05")
	e.prompts.clear()
	e._apply_effect({"op": "discard_life", "who": "opponent", "amount": 5}, 0, {}, null)
	eq(str(e.prompt.context.get("purpose", "")), "deck_loss_guard", "Last Ward is offered against a mill")
	eq(int(e.prompt.context.get("reduce", 0)), 10, "for 10 cards")
	e.prompts.clear()
	e._choice = {}
	# The rest are placement and timing words, read off the data.
	eq(str(shipped().get_def("freestyle_combat_10").effects[0].get("to", "")), "attack", "Old Trick's card is performed this phase")
	eq(str(shipped().get_def("freestyle_combat_15").raw.get("use_at", "")), "end_of_combat", "Reckless Ascent is used at the end of Combat")
	eq(str(shipped().get_def("freestyle_drill_01").raw.get("start_in_play", "")), "may", "Bravado Drill may start in play")
	check(bool(shipped().get_def("freestyle_noncombat_04").effects[0].get("show", false)), "Foresight shows its card")
	check(bool(shipped().get_def("freestyle_noncombat_07").effects[1].get("must", false)), "Provocation takes exactly 2")
	check(bool(shipped().get_def("freestyle_noncombat_13").effects[1].get("must", false)), "The Gate's Boon takes exactly 3")
	check(bool(shipped().get_def("freestyle_noncombat_10").raw.get("reserve_only", false)), "Defacement is Sensei Deck only")
	eq(str(shipped().get_def("freestyle_noncombat_10").effects[0].get("who", "")), "any", "and takes either side's Seal")
	eq(str(shipped().get_def("freestyle_strike_02").effects[0].get("who", "")), "any", "Clean Sweep reaches either side")
	eq(str(shipped().get_def("freestyle_strike_03").effects[2].get("who", "")), "any", "Headlong Plunge's Ally is either side's")
	eq(str(shipped().get_def("freestyle_art_05").raw.get("remain_by", "")), "ally", "Knife Volley's extra use is an Ally's")
	eq(str(shipped().get_def("freestyle_combat_16").effects[0]["effects"][0].get("op", "")), "show_checked", "Keen Eye shows the named card")


## "Use immediately after a Strike you perform becomes successful": the card is used inside battle
## step 8, the Strike then deals its damage and ends, and the defender's attack phase follows.
func test_a_follow_up_is_used_inside_the_attack_it_follows() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(["t_art", "t_art", "t_art"]), "pact"))
	var me: PlayerState = e.player(0)
	var follow: CardInstance = to_hand(e, 0, "t_follow_up")
	to_combat(e)
	var strike: CardInstance = e.card(uid_in_hand(e, 0, "t_strike"))
	var phases: int = e.state.attack_phase_count
	answer(e, &"attack", strike.uid)
	eq(prompt_kind(e), &"follow_up", "the landed Strike offers the follow-up")
	eq(str(e.prompt.context.get("window", "")), "own_successful_attack", "and names its window")
	eq(e.state.battle_step, 8, "asked inside battle step 8")
	eq(e.player(1).duelist.energy, 5, "before any damage is dealt")
	eq(e.integrity_problem(), "", "the Strike in the air is not stranded")
	var hand_before: int = me.hand.size()
	var from: int = e.events.size()
	answer(e, &"use", follow.uid)
	var drew: int = -1
	var ended: int = -1
	for i in range(from, e.events.size()):
		var ev: GameEvent = e.events[i]
		if ev.type == &"draw" and int(ev.data.get("player", -1)) == 0 and drew < 0:
			drew = i
		elif ev.type == &"attack_end" and ended < 0:
			ended = i
	check(drew >= 0, "the follow-up drew its card")
	check(ended > drew, "and the attack ended after that: draw at %d, attack_end at %d" % [drew, ended])
	eq(me.hand.size(), hand_before, "one card used, one drawn")
	eq(e.player(1).duelist.energy, 3, "the Strike still dealt its 2 stages")
	eq(int(e.state.last_attack.get("stages_dealt", -1)), 2, "and its outcome says so")
	eq(follow.zone, &"discard", "the follow-up is discarded after use")
	eq(strike.zone, &"discard", "the Strike is discarded after use")
	check(e.state.attack.is_empty(), "no attack is left in the air")
	eq(e.integrity_problem(), "", "every card is where its zone says")
	eq(prompt_kind(e), &"attack_action", "an attack phase follows")
	eq(e.prompt.player, 1, "and it is the defender's")
	eq(e.state.attack_phase_count, phases + 1, "only the Strike's attack phase went by")


## Declining the follow-up keeps the card in hand and lets the Strike finish as it would have.
func test_declining_a_follow_up_leaves_the_attack_as_it_was() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(["t_art", "t_art", "t_art"]), "pact"))
	var me: PlayerState = e.player(0)
	var follow: CardInstance = to_hand(e, 0, "t_follow_up")
	to_combat(e)
	var strike: CardInstance = e.card(uid_in_hand(e, 0, "t_strike"))
	answer(e, &"attack", strike.uid)
	eq(prompt_kind(e), &"follow_up", "the window opens")
	var hand_before: int = me.hand.size()
	var deck_before: int = me.life_deck.size()
	answer(e, &"decline")
	eq(follow.zone, &"hand", "the follow-up stays in hand")
	eq(me.hand.size(), hand_before, "the hand is unchanged")
	eq(me.life_deck.size(), deck_before, "and nothing was drawn")
	eq(e.player(1).duelist.energy, 3, "the Strike dealt its 2 stages")
	check(has_event(e, &"attack_end"), "the attack ended")
	eq(strike.zone, &"discard", "the Strike is discarded after use")
	check(e.state.attack.is_empty(), "no attack is left in the air")
	eq(e.integrity_problem(), "", "every card is where its zone says")
	eq(prompt_kind(e), &"attack_action", "an attack phase follows")
	eq(e.prompt.player, 1, "and it is the defender's")


## A card that fell out of every list is named: one left in `resolving` with no attack in the air
## and nothing queued to finish it, and one whose zone names a pile that no longer holds it.
func test_the_integrity_check_catches_a_card_in_no_list() -> void:
	var e: DuelEngine = engine(deck(filler()), deck(filler(), "pact"))
	eq(e.integrity_problem(), "", "a fresh duel is sound")
	var held: CardInstance = e.player(0).hand[0]
	e._erase_from_zone(held)
	held.zone = &"resolving"
	check(e.integrity_problem().contains("stranded in resolving"), "a card left resolving is named: %s" % e.integrity_problem())
	e._enqueue([{"trigger": "secondary", "op": "finish_source"}], "secondary", 0, {}, held)
	eq(e.integrity_problem(), "", "one whose finish is still queued is mid-resolution")
	e._queue.clear()
	e._finish_card(held, false)
	eq(held.zone, &"discard", "spent, it reaches the discard pile")
	eq(e.integrity_problem(), "", "and the duel is sound again")
	var lost: CardInstance = e.player(1).life_deck[0]
	e.player(1).life_deck.erase(lost)
	check(e.integrity_problem().contains("in no zone list"), "a card its pile lost is named: %s" % e.integrity_problem())


## The duel in progress rides in the run save, and JSON's floats come back as the ints a replay has
## to match.
func test_an_adventure_run_saves_its_duel_history() -> void:
	var run: AdventureRun = AdventureRun.begin("pyre_beatdown_start", 4242)
	check(run != null, "the starter resolves into a run")
	if run == null:
		return
	eq(run.duel_history.size(), 0, "a new run has no duel in progress")
	run.status = "stage"
	run.duel_history = [
		{"player": 0, "type": "reserve_done", "card": -1, "value": null},
		{"player": 1, "type": "pay", "card": -1, "value": 3},
		{"player": 0, "type": "discard_choice", "card": -1, "value": [12, 15]},
		{"player": 0, "dev": {"op": "draw", "amount": 1}},
	]
	var copy: AdventureRun = AdventureRun.from_dict(JSON.parse_string(JSON.stringify(run.to_dict())))
	eq(copy.duel_history, run.duel_history, "the history survives JSON")
	eq(typeof(copy.duel_history[1]["value"]), TYPE_INT, "a paid amount comes back an int")
	eq(typeof((copy.duel_history[2]["value"] as Array)[0]), TYPE_INT, "and so do the uids of a batch")
	eq(typeof((copy.duel_history[3]["dev"] as Dictionary)["amount"]), TYPE_INT, "and a dev effect's amount")
	AdventureSave.path_override = ADVENTURE_SAVE_PATH
	check(AdventureSave.store(run), "the run writes to disk")
	var loaded: AdventureRun = AdventureSave.load_run()
	check(loaded != null, "the save parses back into a run")
	if loaded != null:
		eq(loaded.duel_history, run.duel_history, "the history came back whole from the file")
	AdventureSave.clear()
	AdventureSave.path_override = ""


## A referee set up the same way and fed another's history, through the run save, stands exactly
## where that one stands, dev effects included. Its first update logs the current turn without
## animating it, and a host's later start() leaves it in place.
func test_a_referee_rebuilt_from_its_history_stands_in_the_same_place() -> void:
	var decks: Array[DeckList] = [deck(filler(["t_art", "t_taunt", "t_parry", "t_seal_1", "t_pay_art", "t_empower_art"], 40)),
		deck(filler(["t_guard", "t_ward"], 40), "pact")]
	var original: Referee = Referee.new()
	original.setup(decks, lib, table, 91)
	original.start()
	var heard: Array[Dictionary] = []
	original.command_applied.connect(func(_seat: int, command: Dictionary) -> void: heard.append(command))
	var picker: RandomNumberGenerator = RandomNumberGenerator.new()
	picker.seed = 19
	var dev_applied: bool = false
	for step in range(80):
		if original.is_over() or (dev_applied and original.engine.state.turn >= 3):
			break
		var seat: int = original.engine.prompt.player
		if not dev_applied and step >= 10 and DuelEngine.DEV_SAFE_PROMPTS.has(original.engine.prompt.kind):
			dev_applied = original.dev({"player": seat, "effect": {"op": "draw", "amount": 1}}) == ""
		if original.is_over():
			break
		seat = original.engine.prompt.player
		var options: Array[Command] = original.engine.prompt.options
		eq(original.submit(seat, options[picker.randi_range(0, options.size() - 1)].to_dict()), "", "a listed option is accepted")
	original.take_updates()
	check(dev_applied, "a dev effect went into the history")
	check(original.engine.state.turn > 1, "the duel is past its first turn")
	eq(heard.size(), original.history.size(), "every entry was announced")
	var saved: AdventureRun = AdventureRun.new()
	saved.duel_history.assign(original.history)
	var reloaded: AdventureRun = AdventureRun.from_dict(JSON.parse_string(JSON.stringify(saved.to_dict())))
	var rebuilt: Referee = Referee.new()
	rebuilt.setup(decks, lib, table, 91)
	eq(rebuilt.replay(reloaded.duel_history), "", "the history replays after a trip through the save")
	rebuilt.start()
	eq(rebuilt.history, original.history, "the rebuilt referee holds the same history")
	for seat in range(2):
		check(JSON.stringify(rebuilt.view_for(seat).to_dict()) == JSON.stringify(original.view_for(seat).to_dict()),
			"seat %d sees the same table" % seat)
	check(original.engine.prompt != null and rebuilt.engine.prompt != null,
		"both wait on a decision (over %s, turn %d)" % [str(original.is_over()), original.engine.state.turn])
	if original.engine.prompt == null or rebuilt.engine.prompt == null:
		return
	eq(rebuilt.engine.prompt.describe(), original.engine.prompt.describe(), "the same decision is pending")
	var first: Array[SeatUpdate] = rebuilt.take_updates()
	var animated: int = 0
	for l in first[0].lines:
		if l.has("data"):
			animated += 1
	eq(animated, 0, "the replayed turn reaches the client as log lines only")
	check(not first[0].lines.is_empty() and str(first[0].lines[0].get("type", "")) == "turn_start",
		"starting at the current turn")
	var seat_next: int = original.engine.prompt.player
	var wire: Dictionary = original.engine.prompt.options[0].to_dict()
	eq(original.submit(seat_next, wire), "", "the original takes the next command")
	eq(rebuilt.submit(seat_next, wire), "", "and so does the rebuilt one")
	check(JSON.stringify(rebuilt.view_for(0).to_dict()) == JSON.stringify(original.view_for(0).to_dict()),
		"and both land on the same table")


## Game over records the duel on the run's node; the Continue click after it records nothing more.
func test_a_duel_result_is_recorded_once() -> void:
	var map: AdventureMap = AdventureMap.generate("pyre_beatdown_start", 7)
	var run: AdventureRun = AdventureRun.begin("pyre_beatdown_start", 7)
	check(run.walk_to_next_duel(map), "the run steps onto its first duel")
	run.duel_history = [{"player": 0, "type": "reserve_done", "card": -1, "value": null}]
	var story: AdventureStoryLog = AdventureStoryLog.new()
	var collection: AdventureCollection = AdventureCollection.new()
	var unlocks: AdventureUnlocks = AdventureUnlocks.new()
	var progress: AdventureProgress = AdventureProgress.new()
	var wallet: AdventureWallet = AdventureWallet.new()
	var results: Array[Dictionary] = AdventureRewards.record_duel(run, map, shipped(), true, null,
		story, collection, unlocks, progress, wallet)
	eq(run.status, "reward", "the win moves the run on to its bundles")
	check(wallet.motes > 0, "and pays Motes")
	check(not results.is_empty(), "and reports what it gave")
	eq(run.duel_history.size(), 0, "the finished duel's history is dropped")
	var motes: int = wallet.motes
	var ledger: int = wallet.ledger.size()
	var offer: Array[String] = run.pending_offer.duplicate()
	var pairs: String = JSON.stringify(story.pairs)
	var again: Array[Dictionary] = AdventureRewards.record_duel(run, map, shipped(), true, null,
		story, collection, unlocks, progress, wallet)
	check(again.is_empty(), "a second record reports nothing")
	eq(wallet.motes, motes, "and pays nothing more")
	eq(wallet.ledger.size(), ledger, "with no second ledger line")
	eq(run.pending_offer, offer, "the bundle offer is not drawn again")
	eq(JSON.stringify(story.pairs), pairs, "the story log counts the duel once")
	eq(run.status, "reward", "and the run stays where it was")


## Conceding goes through the loss path: the run ends at its settlement and the duel's saved
## history is dropped, so nothing reopens the duel.
func test_a_conceded_duel_is_a_loss_and_leaves_no_history() -> void:
	var map: AdventureMap = AdventureMap.generate("pyre_beatdown_start", 7)
	var run: AdventureRun = AdventureRun.begin("pyre_beatdown_start", 7)
	check(run.walk_to_next_duel(map), "the run steps onto its first duel")
	run.duel_history = [{"player": 0, "type": "reserve_done", "card": -1, "value": null},
		{"player": 1, "type": "reserve_done", "card": -1, "value": null}]
	var story: AdventureStoryLog = AdventureStoryLog.new()
	var wallet: AdventureWallet = AdventureWallet.new()
	var results: Array[Dictionary] = AdventureRewards.record_duel(run, map, shipped(), false, null,
		story, AdventureCollection.new(), AdventureUnlocks.new(), AdventureProgress.new(), wallet)
	check(results.is_empty(), "a loss gives nothing")
	eq(run.status, "settle", "the run goes to its settlement")
	eq(run.outcome, "lost", "as a loss")
	eq(run.duel_history.size(), 0, "and the duel's history is gone")
	eq(wallet.motes, 0, "a loss pays no Motes")
	var row: Dictionary = story.pairs.values()[0] if story.pairs.size() == 1 else {}
	eq(int(row.get("lost", 0)), 1, "the story log counts the loss")


## A Drill with a defense blocks from play and is still in play afterwards, ready for the next
## Combat. A copy still in hand is never offered, because it has not been placed.
func test_a_drill_blocks_from_play_and_stays_there() -> void:
	var def: CardDef = CardDef.from_dict({"id": "t_blocking_drill", "title": "Test Blocking Drill", "type": "drill", "defense": {"stops": "strike"}})
	var e: DuelEngine = engine(deck(filler([], 20)), deck(filler([], 20), "pact"))
	var them: PlayerState = e.player(1)
	var held: CardInstance = e._instance(def, 1, &"hand")
	them.hand.append(held)
	var drill: CardInstance = e._instance(def, 1, &"in_play")
	them.in_play.append(drill)
	to_combat(e)
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike"))
	eq(prompt_kind(e), &"defense", "the Strike opens the defence window")
	check(e.prompt.find(&"defend", held.uid) == null, "the Drill in hand is not offered")
	answer(e, &"defend", drill.uid)
	check(bool(e.state.last_attack.get("stopped", false)), "the Drill in play stopped the Strike")
	eq(drill.zone, &"in_play", "and is still in play")
	check(them.in_play.has(drill), "in its owner's in-play list")
	eq(held.zone, &"hand", "the copy in hand never moved")
	eq(e.integrity_problem(), "", "every card is where its zone says")
	var first_combat: int = e.state.combat_count
	skip_to_turn(e, 2)
	to_attack(e, 0)
	check(e.state.combat_count > first_combat, "a later Combat")
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike"))
	eq(prompt_kind(e), &"defense", "the next Strike opens the window again")
	check(e.prompt.find(&"defend", drill.uid) != null, "and the Drill is offered again")
	answer(e, &"defend", drill.uid)
	check(bool(e.state.last_attack.get("stopped", false)), "it stops this Strike too")
	eq(drill.zone, &"in_play", "and stays in play")
	check(them.in_play.has(drill), "in its owner's in-play list")
	eq(e.integrity_problem(), "", "every card is still where its zone says")


## A Non-Combat card that stops attacks does so from play. Placed in the Non-Combat step it is a
## legal defense; a copy still in hand is not.
func test_a_non_combat_blocks_only_once_placed() -> void:
	var e: DuelEngine = engine(deck(filler(["t_noncombat_parry", "t_noncombat_parry"], 20)), deck(filler([], 20), "pact"))
	var me: PlayerState = e.player(0)
	eq(prompt_kind(e), &"non_combat", "the Non-Combat step opens on the two parries")
	var placed: CardInstance = e.card(uid_in_hand(e, 0, "t_noncombat_parry"))
	answer(e, &"place", placed.uid)
	eq(placed.zone, &"in_play", "one parry is placed")
	var held: CardInstance = e.card(uid_in_hand(e, 0, "t_noncombat_parry"))
	check(held != null, "the other is still in hand")
	answer(e, &"done")
	answer(e, &"declare")
	answer(e, &"pass")
	answer(e, &"attack", uid_in_hand(e, 1, "t_strike"))
	eq(prompt_kind(e), &"defense", "their Strike opens the defence window")
	check(e.prompt.find(&"defend", placed.uid) != null, "the placed parry is offered")
	check(e.prompt.find(&"defend", held.uid) == null, "the one in hand is not")
	answer(e, &"defend", placed.uid)
	check(bool(e.state.last_attack.get("stopped", false)), "the parry stopped the Strike")
	eq(me.fervor, 1, "its own line resolved")
	eq(placed.zone, &"discard", "and it is discarded after use")
	check(not me.in_play.has(placed), "no longer in play")
	eq(held.zone, &"hand", "the copy in hand never moved")
	eq(e.integrity_problem(), "", "every card is where its zone says")


## Once in play, a Non-Combat that blocks is spent the way its text says: removed from the game,
## or put on the bottom of its owner's Life Deck.
func test_a_non_combat_block_goes_where_its_text_says() -> void:
	var removed_def: CardDef = CardDef.from_dict({"id": "t_parry_removed", "title": "Test Vanishing Parry", "type": "non_combat",
		"defense": {"stops": "strike"}, "remove_after_use": true})
	var bottom_def: CardDef = CardDef.from_dict({"id": "t_parry_bottom", "title": "Test Returning Parry", "type": "non_combat",
		"defense": {"stops": "strike"}, "bottom_after_use": true})
	var e: DuelEngine = engine(deck(filler([], 20)), deck(filler([], 20), "pact"))
	var them: PlayerState = e.player(1)
	var gone: CardInstance = e._instance(removed_def, 1, &"in_play")
	them.in_play.append(gone)
	var back: CardInstance = e._instance(bottom_def, 1, &"in_play")
	them.in_play.append(back)
	to_combat(e)
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike"))
	answer(e, &"defend", gone.uid)
	check(bool(e.state.last_attack.get("stopped", false)), "the first parry stopped the Strike")
	eq(gone.zone, &"removed", "and was removed from the game")
	check(them.removed.has(gone) and not them.in_play.has(gone), "out of play, in the removed pile")
	eq(e.integrity_problem(), "", "every card is where its zone says")
	answer(e, &"pass")
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike"))
	answer(e, &"defend", back.uid)
	check(bool(e.state.last_attack.get("stopped", false)), "the second parry stopped the next Strike")
	eq(back.zone, &"life_deck", "and went back to the Life Deck")
	eq(them.life_deck.back(), back, "at the bottom")
	check(not them.in_play.has(back), "out of play")
	eq(e.integrity_problem(), "", "every card is still where its zone says")


## A placed Non-Combat that "stops all attacks for the remainder of Combat" keeps stopping them
## after it has left play.
func test_a_placed_stop_all_non_combat_stops_the_rest_of_combat() -> void:
	var rescue_def: CardDef = CardDef.from_dict({"id": "t_rescue", "title": "Test Rescue", "type": "non_combat",
		"defense": {"stops": "any", "stop_all": "any"}, "remove_after_use": true})
	var e: DuelEngine = engine(deck(filler([], 20)), deck(filler([], 20), "pact"))
	var them: PlayerState = e.player(1)
	var rescue: CardInstance = e._instance(rescue_def, 1, &"in_play")
	them.in_play.append(rescue)
	to_combat(e)
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike"))
	answer(e, &"defend", rescue.uid)
	check(bool(e.state.last_attack.get("stopped", false)), "the rescue stopped the Strike")
	eq(rescue.zone, &"removed", "and was removed from the game")
	eq(e.integrity_problem(), "", "every card is where its zone says")
	answer(e, &"pass")
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike"))
	check(bool(e.state.last_attack.get("stopped", false)), "the next Strike of the Combat is stopped too")
	eq(prompt_kind(e), &"attack_action", "with no defence asked for")
	eq(them.duelist.energy, 5, "so nothing landed all Combat")
	eq(e.integrity_problem(), "", "every card is still where its zone says")


## A Combat card that stops a Strike and, if the defending personality carries a keyword, takes a
## card with that keyword back from the discard pile. It is used from hand as a defence, the rider
## reads the defender's personality in control, and the card is removed from the game. It is never
## an attack-phase action, because its line belongs to the stop.
func test_a_combat_block_runs_its_rider_as_part_of_the_stop() -> void:
	var def: CardDef = CardDef.from_dict({"id": "t_kind_block", "title": "Test Kind Block", "type": "combat",
		"defense": {"stops": "strike"}, "remove_after_use": true, "tags": ["marked"],
		"effects": [{"op": "search", "tag": "marked", "source": "discard", "to": "hand", "when": {"in_control_tag": "marked"}}]})
	for tagged in [true, false]:
		var theirs: DeckList = deck(filler([], 20), "pact", "", "", 3, "tf_marked_lord") if tagged else deck(filler([], 20), "pact")
		var e: DuelEngine = engine(deck(filler([], 20)), theirs)
		var them: PlayerState = e.player(1)
		var mine: CardInstance = e._instance(def, 0, &"hand")
		e.player(0).hand.append(mine)
		var block: CardInstance = e._instance(def, 1, &"hand")
		them.hand.append(block)
		var kept: CardInstance = to_discard(e, 1, "t_marked_blow")
		to_combat(e)
		if e.prompt != null and e.prompt.player != 0:
			answer(e, &"pass")   # the first-player rule handed the phase to the other side
		eq(prompt_kind(e), &"attack_action", "our attack phase")
		check(e.prompt.find(&"use", mine.uid) == null, "the block is not an attack-phase use")
		answer(e, &"attack", uid_in_hand(e, 0, "t_strike"))
		eq(prompt_kind(e), &"defense", "their defence window")
		check(e.prompt.find(&"defend", block.uid) != null, "the block is offered from hand")
		answer(e, &"defend", block.uid)
		check(bool(e.state.last_attack.get("stopped", false)), "it stopped the Strike")
		eq(block.zone, &"removed", "and was removed from the game")
		if tagged:
			eq(kept.zone, &"hand", "a Marked defender took the Marked card back")
		else:
			eq(kept.zone, &"discard", "an unmarked defender took nothing")
		eq(e.integrity_problem(), "", "every card is where its zone says")


## A forbid on Non-Combat cards or on Drills also shuts off blocking with one already in play, for
## as long as the forbid lasts.
func test_a_forbidden_non_combat_or_drill_cannot_block_from_play() -> void:
	var drill_def: CardDef = CardDef.from_dict({"id": "t_blocking_drill", "title": "Test Blocking Drill", "type": "drill", "defense": {"stops": "strike"}})
	var e: DuelEngine = engine(deck(filler([], 20)), deck(filler([], 20), "pact"))
	var them: PlayerState = e.player(1)
	var parry: CardInstance = inject(e, 1, "t_noncombat_parry")
	var drill: CardInstance = e._instance(drill_def, 1, &"in_play")
	them.in_play.append(drill)
	to_combat(e)
	check(e._defense_usable(them, parry, "strike", false), "the placed parry can block")
	check(e._defense_usable(them, drill, "strike", false), "and so can the Drill")
	e._apply_effect({"op": "forbid", "who": "opponent", "what": "non_combats", "duration": "combat"}, 0, {}, null)
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike"))
	eq(prompt_kind(e), &"defense", "the Strike opens the defence window")
	check(e.prompt.find(&"defend", parry.uid) == null, "a forbidden Non-Combat is not offered")
	check(e.prompt.find(&"defend", drill.uid) != null, "the Drill still is")
	answer(e, &"no_defense")
	e._apply_effect({"op": "forbid", "who": "opponent", "what": "drills", "duration": "combat"}, 0, {}, null)
	check(not e._defense_usable(them, drill, "strike", false), "a forbidden Drill cannot block")
	skip_to_turn(e, 2)
	check(e._defense_usable(them, parry, "strike", false), "the Non-Combat forbid lapsed with the Combat")
	check(e._defense_usable(them, drill, "strike", false), "and so did the Drill forbid")
	to_attack(e, 0)
	answer(e, &"attack", uid_in_hand(e, 0, "t_strike"))
	eq(prompt_kind(e), &"defense", "the next Combat's Strike opens the window")
	check(e.prompt.find(&"defend", parry.uid) != null, "the parry is offered again")
	check(e.prompt.find(&"defend", drill.uid) != null, "and so is the Drill")
	eq(e.integrity_problem(), "", "every card is where its zone says")


## When the Double Power Rule does not decide, the opener is drawn from the duel's seeded stream:
## the same seed opens with the same seat, and the Vigil deck has no claim on the first turn.
func test_chance_picks_the_opener_from_the_seed() -> void:
	var openers: Dictionary = {}
	for s in range(1, 9):
		var first: int = -1
		for attempt in range(2):
			var e: DuelEngine = DuelEngine.new()
			e.shuffle_decks = false
			var pair: Array[DeckList] = [deck(filler(), "vigil"), deck(filler(), "pact")]
			e.setup(pair, lib, table, s)
			eq(str(setup_event(e).get("reason", "")), "chance", "seed %d: chance decides" % s)
			eq(int(setup_event(e).get("first", -1)), e.state.active, "seed %d: the setup event names the opener" % s)
			if attempt == 0:
				first = e.state.active
			else:
				eq(e.state.active, first, "seed %d opens with the same seat both times" % s)
		openers[first] = true
	check(openers.has(0) and openers.has(1), "across eight seeds both seats open: %s" % str(openers.keys()))


## `set_first_player` hands the first turn to the named seat whatever Double Power or chance
## decided, keeps the Double Power Energy change, and the setup event says it was forced.
func test_a_forced_opener_overrides_double_power_and_chance() -> void:
	var e: DuelEngine = DuelEngine.new()
	e.shuffle_decks = false
	var pair: Array[DeckList] = [deck(filler(), "vigil", "", "", 3, "tf_giant"), deck(filler(), "vigil", "", "", 3, "tf_pageboy")]
	e.setup(pair, lib, table, 1)
	eq(e.state.active, 1, "Double Power picks the weaker duelist")
	e.set_first_player(0)
	eq(e.state.active, 0, "the forced seat opens instead")
	eq(e.player(0).duelist.energy, 2, "the Double Power Energy change still stands")
	eq(e.player(1).duelist.energy, CardInstance.MAX_STAGE, "on both sides")
	eq(int(setup_event(e).get("first", -1)), 0, "the setup event names the forced seat")
	eq(str(setup_event(e).get("reason", "")), "forced", "and says why")
	for ev in e.events:
		if ev.type == &"setup":
			eq(CardText.event_line(ev, e), "Test vigil opens the duel (set by the match).", "the log names the forced opener")
	e.start()
	eq(e.prompt.player, 0, "the first decision of the duel is theirs")
	# Over chance, through a Referee, whose setup event also carries the table as it stood.
	var r: Referee = Referee.new()
	var plain: Array[DeckList] = [deck(filler(), "vigil"), deck(filler(), "pact")]
	r.setup(plain, lib, table, 1)
	var drawn: int = r.engine.state.active
	r.engine.set_first_player(1 - drawn)
	eq(r.engine.state.active, 1 - drawn, "a forced seat overrides chance too")
	for ev in r.engine.events:
		if ev.type == &"setup":
			eq(str(ev.data.get("reason", "")), "forced", "the reason is forced")
			eq(int(ev.state.get("active", -1)), 1 - drawn, "and the stamped table shows the forced seat")
	r.start()
	eq(r.engine.state.active, 1 - drawn, "and it opens the duel")


# --- Match records ----------------------------------------------------------

## A duel played with random legal choices behind a DuelHost that keeps its record, the way the duel
## server and Session keep one. `force_other` hands the first turn to the seat the rules did not
## pick; `adventure` runs it on two lives against one with the Seal point, as an adventure duel
## does. A deck built in code goes into the record inline. Stops after `limit` commands.
func recorded_duel(decks: Array[DeckList], library: CardLibrary, strike: StrikeTable, seed_value: int,
		force_other: bool, adventure: bool = false, limit: int = 3000) -> DuelHost:
	var referee: Referee = Referee.new()
	referee.setup(decks, library, strike, seed_value, ["Ada", "Bryn"])
	if adventure:
		referee.engine.set_lives([2, 1])
		referee.engine.set_points_options(true, false)
	if force_other:
		referee.engine.set_first_player(1 - referee.engine.state.active)
	var host: DuelHost = DuelHost.new()
	host.setup(referee, [])
	host.record = MatchRecord.begin(referee, decks, "adventure" if adventure else "hotseat", "client")
	for seat in range(2):
		if decks[seat].id == "":
			host.record.seats[seat]["list"] = MatchRecord.deck_dict(decks[seat])
	host.start()
	var picker: RandomNumberGenerator = RandomNumberGenerator.new()
	picker.seed = seed_value
	for step in range(limit):
		if host.is_over():
			break
		var p: Prompt = referee.engine.prompt
		host.apply(p.player, p.options[picker.randi_range(0, p.options.size() - 1)].to_dict())
	return host


## A record read back from its own line is the same record: every field, the ints JSON turned into
## floats back as ints, and the canonical text a signature covers unchanged.
func test_a_match_record_comes_back_whole_from_its_line() -> void:
	var decks: Array[DeckList] = [deck(filler(["t_art", "t_parry"], 30)), deck(filler(["t_guard"], 30), "pact")]
	var host: DuelHost = recorded_duel(decks, lib, table, 57, false)
	var record: MatchRecord = host.record
	check(host.is_over() and record.has_result(), "the random duel ran to its end")
	eq(record.commands.size(), host.referee.history.size(), "every accepted command is in the record")
	eq(int(record.result["winner"]), host.referee.engine.state.winner, "with the rules' winner")
	eq(str(record.result["reason"]), host.referee.engine.state.win_reason, "and their reason")
	eq(int(record.result["turns"]), host.referee.engine.state.turn, "and the turn it ended on")
	eq(str(record.first["reason"]), "chance", "the opener and why come from the setup event")
	var ordered: bool = true
	for i in range(1, record.commands.size()):
		ordered = ordered and int(record.commands[i]["at"]) >= int(record.commands[i - 1]["at"])
	check(ordered, "each command carries its time since the deal, in order")
	eq(record.id.length(), 16, "the id is 16 hex characters")
	var text: String = record.line()
	var parsed: Variant = JSON.parse_string(text)
	var back: MatchRecord = MatchRecord.from_dict(parsed)
	check(back != null, "the line loads back: %s" % MatchRecord.problem_of(parsed))
	if back == null:
		return
	eq(back.line(), text, "and writes out the same line")
	eq(MatchRecord.canonical(parsed), MatchRecord.canonical(record.to_dict()), "the signed text survives a trip through JSON")
	check(not MatchRecord.canonical(record.to_dict()).contains("\"sig\""), "and leaves the signature out")
	eq(typeof(back.commands[0]["card"]), TYPE_INT, "a command's card comes back an int")
	eq(JSON.stringify(back.seats), JSON.stringify(record.seats), "the seats and their inline decks come back")
	eq(back.first, record.first, "and so does the opener")


## `setup_referee` and `Referee.replay` stand exactly where the recorded duel ended: catalog decks
## by id and decks inline, a forced opener, and adventure lives with the Seal point.
func test_a_match_record_rebuilds_its_duel_for_replay() -> void:
	var strike: StrikeTable = StrikeTable.load_from("res://data/strike_table.json")
	var catalog: Array[DeckList] = [DeckList.load_from("res://data/decks/steel_beatdown.json"),
		DeckList.load_from("res://data/decks/tide_deepwater.json")]
	eq(catalog[0].id, "steel_beatdown", "a deck loaded from its file knows its id")
	var inline: Array[DeckList] = [deck(filler(["t_art", "t_parry", "t_seal_1"], 30)), deck(filler(["t_guard", "t_ward"], 30), "pact")]
	var cases: Array = [["catalog", catalog, shipped(), strike, false], ["inline", inline, lib, table, true]]
	for case in cases:
		var label: String = case[0]
		var host: DuelHost = recorded_duel(case[1], case[2], case[3], 811, true, case[4])
		var record: MatchRecord = host.record
		check(record.has_result(), "%s: the duel ran to its end" % label)
		eq(str(record.first["reason"]), "forced", "%s: the record says the opener was forced" % label)
		eq(str(record.seats[0].get("deck", "")), catalog[0].id if label == "catalog" else "", "%s: the deck is named by id" % label)
		eq(record.seats[0].has("list"), label == "inline", "%s: and inline only when it has no file" % label)
		var back: MatchRecord = MatchRecord.from_dict(JSON.parse_string(record.line()))
		check(back != null, "%s: the record loads back" % label)
		if back == null:
			continue
		var rebuilt: Referee = back.setup_referee(case[2], case[3])
		check(rebuilt != null, "%s: the record sets up a referee" % label)
		if rebuilt == null:
			continue
		eq(rebuilt.engine.state.active, int(record.first["seat"]), "%s: which opens with the recorded seat" % label)
		eq(rebuilt.engine.state.points_to_win, host.referee.engine.state.points_to_win, "%s: on the recorded lives" % label)
		eq(rebuilt.replay(back.commands), "", "%s: every recorded command replays" % label)
		eq(rebuilt.engine.state.winner, int(record.result["winner"]), "%s: to the recorded winner" % label)
		for seat in range(2):
			check(JSON.stringify(rebuilt.view_for(seat).to_dict()) == JSON.stringify(host.referee.view_for(seat).to_dict()),
				"%s: seat %d sees the same final table" % [label, seat])


## The loader takes nothing it cannot check: a wrong type anywhere, a version it does not know, more
## commands than any duel plays, a key it does not know, a signature on a client record or none on
## a server record, a deck id that could leave the deck folders, a name with markup.
func test_the_match_record_loader_refuses_what_it_cannot_check() -> void:
	var decks: Array[DeckList] = [deck(filler([], 20)), deck(filler([], 20), "pact")]
	var host: DuelHost = recorded_duel(decks, lib, table, 5, false, false, 12)
	host.end(1, "concede")
	var base: Dictionary = JSON.parse_string(host.record.line())
	eq(MatchRecord.problem_of(base), "", "a conceded duel's record loads, whole numbers read as floats")
	check(not (base["commands"] as Array).is_empty(), "with commands to tamper with")
	if (base["commands"] as Array).is_empty():
		return
	var edits: Array = [
		["a seed written as text", func(d: Dictionary) -> void: d["seed"] = "5"],
		["a name that is a number", func(d: Dictionary) -> void: d["seats"][0]["name"] = 5],
		["a command's card as text", func(d: Dictionary) -> void: d["commands"][0]["card"] = "x"],
		["a winner who is no seat", func(d: Dictionary) -> void: d["result"]["winner"] = 2],
		["a result reason it does not know", func(d: Dictionary) -> void: d["result"]["reason"] = "vibes"],
		["a fractional turn count", func(d: Dictionary) -> void: d["result"]["turns"] = 3.5],
		["version 3", func(d: Dictionary) -> void: d["v"] = 3],
		["the version as text", func(d: Dictionary) -> void: d["v"] = "1"],
		["an unknown key", func(d: Dictionary) -> void: d["extra"] = 1],
		["an extra key on a command", func(d: Dictionary) -> void: d["commands"][0]["note"] = "x"],
		["a batch of 129 uids", func(d: Dictionary) -> void: d["commands"][0]["value"] = range(129)],
		["a signed client record", func(d: Dictionary) -> void: d["sig"] = "ab".repeat(32)],
		["an unsigned server record", func(d: Dictionary) -> void: d["origin"] = "server"],
		["a deck id with a path in it", func(d: Dictionary) -> void: d["seats"][0]["deck"] = "../decks/x"],
		["a name with markup", func(d: Dictionary) -> void: d["seats"][1]["name"] = "[b]Bryn[/b]"],
		["a name past the cap", func(d: Dictionary) -> void: d["seats"][1]["name"] = "x".repeat(MatchRecord.NAME_MAX + 1)],
		["a dev entry under dev false", func(d: Dictionary) -> void: d["commands"].append({"player": 0, "dev": {"op": "draw", "amount": 1}, "at": 5})],
		["an opener who is no seat", func(d: Dictionary) -> void: d["first"]["seat"] = 2],
		["no lives", func(d: Dictionary) -> void: d["rules"]["lives"] = [0, 1]],
		["a guest id with a space", func(d: Dictionary) -> void: d["rules"]["guest"] = ["bad id", ""]],
		["one seat", func(d: Dictionary) -> void: d["seats"].pop_back()],
	]
	for edit in edits:
		var copy: Dictionary = base.duplicate(true)
		(edit[1] as Callable).call(copy)
		check(MatchRecord.from_dict(copy) == null, "refused: %s" % edit[0])
	var oversized: Dictionary = base.duplicate(true)
	var many: Array = []
	for i in range(MatchRecord.MAX_COMMANDS + 1):
		many.append(base["commands"][0])
	oversized["commands"] = many
	check(MatchRecord.problem_of(oversized).begins_with("more than"), "refused: more than %d commands" % MatchRecord.MAX_COMMANDS)
	check(MatchRecord.from_dict("a record") == null and MatchRecord.from_dict(null) == null, "refused: something that is not an object")


## Client records land where `dir_override` points, one line each, and a file keeps only its last
## lines. A record the client wrote about its own duel carries no signature.
func test_client_match_records_keep_their_last_lines_where_they_are_pointed() -> void:
	var dir: String = "user://test_match_records"
	MatchRecord.dir_override = dir
	for file_name in [MatchRecord.LOCAL_FILE, "trim.jsonl"]:
		if FileAccess.file_exists(dir.path_join(file_name)):
			DirAccess.remove_absolute(dir.path_join(file_name))
	for i in range(5):
		eq(MatchRecord.keep_line("trim.jsonl", "line %d" % i, 3), "", "line %d is written" % i)
	var kept: PackedStringArray = FileAccess.get_file_as_string(dir.path_join("trim.jsonl")).split("\n", false)
	eq(Array(kept), ["line 2", "line 3", "line 4"], "only the last three lines stay")
	check(not FileAccess.file_exists(dir.path_join("trim.jsonl.tmp")), "and no temporary file is left behind")
	var decks: Array[DeckList] = [deck(filler([], 20)), deck(filler([], 20), "pact")]
	var host: DuelHost = recorded_duel(decks, lib, table, 9, false, false, 8)
	host.end(0, "concede")
	eq(MatchRecord.keep_line(MatchRecord.LOCAL_FILE, host.record.line()), "", "an offline record is written")
	var local: PackedStringArray = FileAccess.get_file_as_string(dir.path_join(MatchRecord.LOCAL_FILE)).split("\n", false)
	eq(local.size(), 1, "as one line")
	var back: MatchRecord = MatchRecord.from_dict(JSON.parse_string(local[0])) if local.size() == 1 else null
	check(back != null and back.origin == "client" and back.sig == "", "a client record with no signature")
	check(back != null and str(back.result["reason"]) == "concede" and int(back.result["winner"]) == 0, "carrying its concession")
	for file_name in [MatchRecord.LOCAL_FILE, "trim.jsonl"]:
		DirAccess.remove_absolute(dir.path_join(file_name))
	DirAccess.remove_absolute(dir)
	MatchRecord.dir_override = ""


# --- Match stats ------------------------------------------------------------

## A finished record built through the MatchRecord API with no duel behind it, loaded back from its
## own line the way the stats tool reads one. `decks` are the catalog ids in seat 0 and seat 1.
func stats_record(decks: Array[String], winner: int, reason: String, turns: int, opener: int, catalog: String = "",
		record_origin: String = "server", mode: String = "code", day: String = "2026-09-26") -> MatchRecord:
	var r: MatchRecord = MatchRecord.new()
	r.id = Crypto.new().generate_random_bytes(8).hex_encode()
	r.origin = record_origin
	r.mode = mode
	r.catalog = catalog
	r.protocol = 3
	r.started = Time.get_unix_time_from_datetime_string(day + "T12:00:00")
	r.first = {"seat": opener, "reason": "chance"}
	r.rules = {"lives": [1, 1], "seal_point": false, "second_life": false, "guest": ["", ""], "boss_power": ["", ""]}
	for seat in range(2):
		r.seats.append({"identity": "", "name": "Test %d" % seat, "deck": decks[seat], "ai": ""})
	for i in range(turns * 3):
		r.add_command({"player": i % 2, "type": "pass", "card": -1, "value": null}, i * 1000)
	r.result = {"winner": winner, "reason": reason, "turns": turns, "duration_ms": turns * 60000, "points": [0, 0]}
	r.sig = "ab".repeat(32) if record_origin == "server" else ""
	var parsed: Variant = JSON.parse_string(r.line())
	var back: MatchRecord = MatchRecord.from_dict(parsed)
	check(back != null, "the synthetic record loads: %s" % MatchRecord.problem_of(parsed))
	return back if back != null else r


## Each deck's duels, wins, end reasons and means, counted from whichever seat it sat in, with the
## win rate's range from SimReport's Wilson interval, printed the way matchlab prints it.
func test_match_stats_count_each_deck_and_its_wilson_range() -> void:
	var ab: Array[String] = ["alpha", "beta"]
	var ba: Array[String] = ["beta", "alpha"]
	var stats: MatchStats = MatchStats.new()
	for r in [stats_record(ab, 0, "survival", 6, 0), stats_record(ba, 1, "seal", 8, 0),
			stats_record(ab, 1, "concede", 4, 1), stats_record(ab, 0, "ascension", 10, 1)]:
		check(stats.add(r), "a signed code-room record counts by default")
	var decks: Dictionary = stats.group_of("").get("decks", {})
	var alpha: Dictionary = decks.get("alpha", {})
	var beta: Dictionary = decks.get("beta", {})
	eq(int(alpha.get("duels", 0)), 4, "alpha sat in four duels")
	eq(int(alpha.get("won", 0)), 3, "and won three")
	var win_by: Dictionary = alpha.get("win_by", {})
	eq([int(win_by.get("survival", 0)), int(win_by.get("seal", 0)), int(win_by.get("ascension", 0))], [1, 1, 1], "one by each rules route")
	eq(int((alpha.get("loss_to", {}) as Dictionary).get("concede", 0)), 1, "and lost the fourth by conceding")
	eq(int((beta.get("win_by", {}) as Dictionary).get("concede", 0)), 1, "which beta has as a win by concession")
	var summary: Dictionary = stats.to_json()["groups"][0]["decks"]["alpha"]
	var bounds: Array[float] = SimReport.wilson(3, 4)
	check(is_equal_approx(float(summary["win_low"]), bounds[0]) and is_equal_approx(float(summary["win_high"]), bounds[1]),
		"the range is the Wilson interval for 3 of 4")
	check(is_equal_approx(float(summary["mean_turns"]), 7.0) and is_equal_approx(float(summary["mean_minutes"]), 7.0),
		"seven turns and seven minutes on average")
	check(is_equal_approx(float(summary["mean_decisions"]), 21.0), "and 21 decisions, every command counted")
	check(stats.to_text().contains("75.0% (30.1-95.4)"), "the text prints the rate and range as matchlab does")


## The grid counts every duel from both seats: alpha against beta and beta against alpha hold the
## same duels whichever seat each deck sat in, and their wins add up to them. A mirror stays out of
## the grid and the deck rows, as matchlab never plays one.
func test_match_stats_read_the_matchup_grid_the_same_from_both_seats() -> void:
	var ab: Array[String] = ["alpha", "beta"]
	var ba: Array[String] = ["beta", "alpha"]
	var aa: Array[String] = ["alpha", "alpha"]
	var ag: Array[String] = ["alpha", "gamma"]
	var stats: MatchStats = MatchStats.new()
	for r in [stats_record(ab, 0, "survival", 5, 0), stats_record(ab, 1, "survival", 5, 0),
			stats_record(ba, 0, "seal", 5, 0), stats_record(ba, 1, "seal", 5, 0),
			stats_record(ab, 0, "survival", 5, 1), stats_record(aa, 0, "survival", 5, 0), stats_record(ag, 1, "survival", 5, 0)]:
		stats.add(r)
	var group: Dictionary = stats.group_of("")
	var grid: Dictionary = group.get("matchup", {})
	var ab_cell: Array = (grid.get("alpha", {}) as Dictionary).get("beta", [0, 0])
	var ba_cell: Array = (grid.get("beta", {}) as Dictionary).get("alpha", [0, 0])
	eq(int(ab_cell[1]), 5, "alpha against beta holds all five duels, from either seat")
	eq(int(ba_cell[1]), 5, "and so does beta against alpha")
	eq(int(ab_cell[0]), 3, "alpha won three of them")
	eq(int(ab_cell[0]) + int(ba_cell[0]), 5, "and the two cells' wins add up to the duels")
	check(not (grid.get("alpha", {}) as Dictionary).has("alpha"), "a mirror has no cell")
	eq(int(group.get("mirrors", 0)), 1, "it is counted as a mirror")
	eq(int((group["decks"]["alpha"] as Dictionary)["duels"]), 6, "and left out of alpha's row, which holds the beta and gamma duels")
	check(stats.to_text().contains("row \\ column"), "the text prints the grid")


## The first player's rate counts the duels with a winner, mirrors included; per deck it splits by
## whether the deck went first or second.
func test_match_stats_give_the_first_player_rate_overall_and_per_deck() -> void:
	var ab: Array[String] = ["alpha", "beta"]
	var ba: Array[String] = ["beta", "alpha"]
	var aa: Array[String] = ["alpha", "alpha"]
	var stats: MatchStats = MatchStats.new()
	for r in [stats_record(ab, 0, "survival", 5, 0), stats_record(ab, 1, "survival", 5, 1), stats_record(ba, 1, "seal", 5, 0),
			stats_record(ab, -1, "abandoned", 3, 0), stats_record(aa, 1, "survival", 5, 1)]:
		stats.add(r)
	var group: Dictionary = stats.group_of("")
	eq(group.get("first"), [3, 4], "the opener won three of the four duels with a winner")
	var alpha: Dictionary = group["decks"]["alpha"]
	var beta: Dictionary = group["decks"]["beta"]
	eq(alpha["first"], [1, 1], "alpha won the one duel it opened")
	eq(alpha["second"], [1, 2], "and one of the two it did not")
	eq(beta["first"], [1, 2], "beta won one of the two it opened")
	eq(beta["second"], [0, 1], "and lost the one it did not")
	check(stats.to_text().contains("the seat that went first won 3 of 4"), "the text says so")


## Concessions bucket by the turn they came on, every result reason gets its share of the duels,
## and disconnects and reconnects read per 100 duels.
func test_match_stats_bucket_concessions_and_share_out_the_endings() -> void:
	var ab: Array[String] = ["alpha", "beta"]
	var records: Array[MatchRecord] = []
	for turn in [1, 2, 3, 5, 6, 9]:
		records.append(stats_record(ab, 1, "concede", turn, 0))
	records.append(stats_record(ab, 0, "timeout", 4, 0))
	records.append(stats_record(ab, 1, "left", 4, 0))
	records.append(stats_record(ab, -1, "abandoned", 4, 0))
	records.append(stats_record(ab, 0, "survival", 4, 0))
	records[6].disconnects.assign([1, 0])
	records[7].disconnects.assign([2, 1])
	records[7].reconnects.assign([1, 0])
	var stats: MatchStats = MatchStats.new()
	for r in records:
		stats.add(r)
	eq(stats.group_of("")["concede_turns"], [2, 2, 2], "turns 1-2, 3-5 and 6+ hold two concessions each")
	var summary: Dictionary = stats.to_json()["groups"][0]
	check(is_equal_approx(float(summary["disconnects_per_100"]), 40.0) and is_equal_approx(float(summary["reconnects_per_100"]), 10.0),
		"four disconnects and one reconnect in ten duels read 40 and 10 per 100")
	var text: String = stats.to_text()
	for share in [["concede", 6, 60.0], ["timeout", 1, 10.0], ["left", 1, 10.0], ["abandoned", 1, 10.0], ["seal", 0, 0.0]]:
		var line: String = "%-10s %6d %6.1f%%" % share
		check(text.contains(line), "the endings table reads %s" % line)
	check(text.contains("conceded on turn 1-2: 2, 3-5: 2, 6+: 2"), "the text gives the concession buckets")
	check(text.contains("per 100 duels: 40.0 disconnects, 10.0 reconnects"), "and the connection counts")


## Records group by catalog hash, oldest period first, and each group says how many records it
## holds. A catalog prefix keeps one period, and the group this build runs is marked.
func test_match_stats_group_records_by_catalog() -> void:
	var ab: Array[String] = ["alpha", "beta"]
	var older: String = "a".repeat(64)
	var newer: String = "b".repeat(64)
	var records: Array[MatchRecord] = [stats_record(ab, 0, "survival", 5, 0, newer, "server", "code", "2026-09-25"),
		stats_record(ab, 1, "survival", 5, 0, older, "server", "code", "2026-09-20"),
		stats_record(ab, 0, "seal", 5, 0, older, "server", "code", "2026-09-21"),
		stats_record(ab, 1, "seal", 5, 1, newer, "server", "code", "2026-09-26"),
		stats_record(ab, 0, "survival", 5, 1, older, "server", "code", "2026-09-22")]
	var stats: MatchStats = MatchStats.new()
	stats.current_catalog = newer
	for r in records:
		stats.add(r)
	eq(stats.groups.size(), 2, "two catalogs make two groups")
	eq(int(stats.group_of(older).get("records", 0)), 3, "the older one holds three records")
	eq(int(stats.group_of(newer).get("records", 0)), 2, "the newer one two")
	var text: String = stats.to_text()
	var older_at: int = text.find("=== catalog aaaaaaaaaaaa: 3 records, 2026-09-20 to 2026-09-22 ===")
	var newer_at: int = text.find("=== catalog bbbbbbbbbbbb: 2 records, 2026-09-25 to 2026-09-26, this build ===")
	check(older_at >= 0 and newer_at > older_at, "each block opens with its count and dates, oldest first, this build's marked")
	var one: MatchStats = MatchStats.new()
	one.catalog_prefix = "bbb"
	for r in records:
		one.add(r)
	eq(one.groups.keys(), [newer], "a catalog prefix keeps one period")
	eq(int(one.skipped.get("another catalog", 0)), 3, "and files the rest under another catalog")


## Left out by default, and said why: a record with a dev effect, a client's own record, a mode the
## filter does not name, a day before --since, a line that is not JSON or not a record, and with a
## key, a server record changed after it was signed. A client record counts once asked for.
func test_match_stats_skip_dev_client_and_unverified_records() -> void:
	var ab: Array[String] = ["alpha", "beta"]
	var stats: MatchStats = MatchStats.new()
	stats.since = "2026-09-21"
	var dev_record: MatchRecord = stats_record(ab, 0, "survival", 5, 0)
	dev_record.add_command({"player": 0, "dev": {"op": "draw", "amount": 1}}, 5)
	var client: MatchRecord = stats_record(ab, 0, "survival", 5, 0, "", "client", "vs_ai")
	check(not stats.add(dev_record), "a dev record is skipped")
	check(not stats.add(client), "a client record is skipped by default")
	check(not stats.add(stats_record(ab, 0, "survival", 5, 0, "", "server", "lan")), "a mode outside ranked, casual and code is skipped")
	check(not stats.add(stats_record(ab, 0, "survival", 5, 0, "", "server", "code", "2026-09-20")), "a day before --since is skipped")
	check(not stats.add_line("{not json"), "a broken line is skipped")
	var named: Dictionary = JSON.parse_string(stats_record(ab, 0, "survival", 5, 0).line())
	named["seats"][1]["name"] = "[b]Bryn[/b]"
	check(not stats.add_line(JSON.stringify(named)), "a line the loader refuses is skipped")
	check(stats.add_line(stats_record(ab, 0, "survival", 5, 0).line()), "a signed code-room line counts")
	eq(stats.counted(), 1, "one record counted")
	for reason in ["dev", "origin client", "mode lan", "before --since", "not JSON", "refused: seat name"]:
		eq(int(stats.skipped.get(reason, 0)), 1, "one skipped as %s" % reason)
	check(stats.to_text().contains("skipped     1  origin client"), "the text says what was skipped and why")

	var mine: MatchStats = MatchStats.new()
	mine.origin = "all"
	mine.modes.assign(["vs_ai"])
	check(mine.add(client), "asked for, a client vs AI record counts")

	var dir: String = "user://test_match_stats"
	var signer: MatchLog = MatchLog.new()
	eq(signer.open(dir), "", "a signing key is made")
	var signed: MatchRecord = stats_record(ab, 0, "survival", 5, 0)
	signer.sign_record(signed)
	var forged: MatchRecord = MatchRecord.from_dict(JSON.parse_string(signed.line()))
	forged.result["winner"] = 1
	var checked: MatchStats = MatchStats.new()
	checked.verifier = signer
	check(checked.add(signed), "a record the key signed counts under --secret")
	check(not checked.add(forged), "one changed after signing does not")
	eq(int(checked.skipped.get("signature does not match --secret", 0)), 1, "and is filed as a bad signature")
	DirAccess.remove_absolute(dir.path_join(MatchLog.KEY_FILE))
	DirAccess.remove_absolute(dir.path_join(MatchLog.MATCHES_DIR))
	DirAccess.remove_absolute(dir)


## The card pass replays each duel from its record and counts the cards put to use. Every count
## matches what the live referee saw, a duel counts once per seat that played a card, and its win
## rate follows that seat's result. A record made on another catalog is not replayed.
func test_match_stats_count_the_cards_of_two_replayed_duels() -> void:
	var decks: Array[DeckList] = [deck(filler(["t_art", "t_parry"], 30)), deck(filler(["t_guard"], 30), "pact")]
	var full: DuelHost = recorded_duel(decks, lib, table, 57, false)
	var short: DuelHost = recorded_duel(decks, lib, table, 23, false, false, 40)
	short.end(1, "concede")
	var stats: MatchStats = MatchStats.new()
	stats.origin = "all"
	stats.modes.assign(["hotseat"])
	stats.library = lib
	stats.strike_table = table
	var elsewhere: MatchStats = MatchStats.new()
	elsewhere.origin = "all"
	elsewhere.modes.assign(["hotseat"])
	elsewhere.library = lib
	elsewhere.strike_table = table
	elsewhere.current_catalog = "c".repeat(64)
	var expected: Dictionary = {}
	for host in [full, short]:
		var record: MatchRecord = (host as DuelHost).record
		var referee: Referee = (host as DuelHost).referee
		check(record.has_result(), "the duel has a result")
		var winner: int = int(record.result["winner"])
		var seen: Array[Dictionary] = [{}, {}]
		for entry in referee.history:
			if entry.has("dev") or not MatchStats.PLAY_TYPES.has(str(entry["type"])):
				continue
			var seat: int = int(entry["player"])
			var card: CardInstance = referee.engine.card(int(entry["card"]))
			if card == null or card.owner != seat:
				continue
			if not expected.has(card.def.id):
				expected[card.def.id] = {"played": 0, "duels": 0, "won": 0}
			expected[card.def.id]["played"] = int(expected[card.def.id]["played"]) + 1
			seen[seat][card.def.id] = true
		for seat in range(2):
			for id in seen[seat].keys():
				expected[id]["duels"] = int(expected[id]["duels"]) + 1
				expected[id]["won"] = int(expected[id]["won"]) + (1 if winner == seat else 0)
		var back: MatchRecord = MatchRecord.from_dict(JSON.parse_string(record.line()))
		check(stats.add(back), "the recorded duel counts")
		elsewhere.add(back)
	var group: Dictionary = stats.group_of("")
	eq(int(group.get("cards_replayed", 0)), 2, "both duels replay")
	eq(int(group.get("cards_failed", 0)), 0, "and neither fails")
	check(not expected.is_empty(), "the duels put cards to use")
	eq(JSON.stringify(group.get("cards", {}), "", true), JSON.stringify(expected, "", true), "every card's plays, duels and wins match the live duels")
	check(stats.to_text().contains("CARDS  (2 duels replayed"), "the text has the card table")
	eq(int(elsewhere.group_of("").get("cards_other_catalog", 0)), 2, "records on another catalog are not replayed")
	check((elsewhere.group_of("").get("cards", {}) as Dictionary).is_empty(), "and count no cards")


## 30 s for a decision, 45 s for one that shows a pile or takes several cards, 60 s for the
## Reserve swap at setup.
func test_a_decision_clock_gives_each_kind_of_prompt_its_time() -> void:
	eq(DuelClock.decision_ms(&"defense", {}), 30000, "a plain decision")
	eq(DuelClock.decision_ms(&"keep", {"batch_max": 1}), 30000, "one card at a time")
	eq(DuelClock.decision_ms(&"discard_choice", {"batch_max": 2}), 45000, "several cards at once")
	eq(DuelClock.decision_ms(&"pick_option", {"library": true}), 45000, "a look through the Life Deck")
	eq(DuelClock.decision_ms(&"name_card", {}), 45000, "naming a card")
	eq(DuelClock.decision_ms(&"reserve", {"batch_max": 6}), 60000, "the Reserve swap")


## The decision timer counts down, warns for its last 10 s, then the bank drains; the seat is out
## when both are gone. An answer on the bank keeps what is left of it.
func test_a_decision_clock_warns_then_drains_the_bank() -> void:
	var clock: DuelClock = DuelClock.new()
	eq(clock.state(0, 0), {"left_ms": 0, "bank_ms": 60000, "phase": "off"}, "a seat owing nothing has no timer and a 60 s bank")
	clock.start(0, &"attack_action", {}, 1000)
	eq(clock.state(0, 1000), {"left_ms": 30000, "bank_ms": 60000, "phase": "run"}, "30 s on the timer")
	eq(clock.state(0, 20999)["phase"], "run", "above 10 s it runs")
	eq(clock.state(0, 21000), {"left_ms": 10000, "bank_ms": 60000, "phase": "warn"}, "the last 10 s warn")
	eq(clock.state(0, 31000), {"left_ms": 0, "bank_ms": 60000, "phase": "bank"}, "then the bank takes over")
	eq(clock.state(0, 61000)["bank_ms"], 30000, "and drains only after the timer is gone")
	eq(clock.out_at(0), 91000, "timer and bank are gone together at 91 s")
	eq(clock.tick(90999), [] as Array[int], "a millisecond before, nobody is out")
	eq(clock.tick(91000), [0] as Array[int], "then the seat is out")
	clock.stop(0, 41000)
	eq(clock.state(0, 50000), {"left_ms": 0, "bank_ms": 50000, "phase": "off"}, "an answer 10 s into the bank keeps the other 50 s")
	eq(clock.tick(500000), [] as Array[int], "and a stopped clock never runs out")
	clock.start(0, &"declare", {}, 60000)
	eq(clock.out_at(0), 60000 + 30000 + 50000, "the next decision runs on what the bank kept")


## 60 s at the deal, 10 s more at each of the seat's own turn starts, never above 120 s, also
## while the bank is draining.
func test_a_decision_clock_banks_time_at_each_own_turn_up_to_the_cap() -> void:
	var clock: DuelClock = DuelClock.new()
	clock.bank_turn(0, 0)
	eq(clock.bank_left(0, 0), 70000, "one turn start adds 10 s")
	eq(clock.bank_left(1, 0), 60000, "to that seat only")
	for i in range(10):
		clock.bank_turn(0, 0)
	eq(clock.bank_left(0, 0), 120000, "capped at 120 s")
	clock.start(1, &"defense", {}, 0)
	clock.bank_turn(1, 40000)
	eq(clock.bank_left(1, 40000), 60000, "10 s drained, then 10 s banked")
	eq(clock.out_at(1), 30000 + 70000, "which moves the seat's end out by the 10 s")
	clock.bank_turn(9, 0)
	eq([clock.bank_left(0, 0), clock.bank_left(1, 40000)], [120000, 60000], "a seat that is no seat changes nothing")


## Each seat's clock runs on its own, as in the simultaneous Reserve swap and Discard step: one
## answering leaves the other running, the earlier deadline is out first, and an exact tie comes
## back as both seats with the same end.
func test_decision_clocks_run_per_seat_and_the_earlier_deadline_loses() -> void:
	var clock: DuelClock = DuelClock.new()
	clock.start(0, &"keep", {}, 0)
	clock.start(1, &"keep", {}, 5000)
	clock.stop(0, 10000)
	eq(clock.state(1, 10000), {"left_ms": 25000, "bank_ms": 60000, "phase": "run"}, "seat 2 runs on when seat 1 answers")
	eq(clock.tick(95000), [1] as Array[int], "and only seat 2 can run out")
	var race: DuelClock = DuelClock.new()
	race.start(1, &"keep", {}, 0)
	race.start(0, &"keep", {}, 1)
	eq(race.tick(200000), [1, 0] as Array[int], "the earlier deadline comes first")
	var tie: DuelClock = DuelClock.new()
	tie.start(0, &"reserve", {}, 0)
	tie.start(1, &"reserve", {}, 0)
	eq(tie.tick(120000).size(), 2, "both out at once")
	eq(tie.out_at(0), tie.out_at(1), "at the same moment, which is the tie that ends a duel with no winner")


## An armed decision counts nothing until its panel is reported open, or its 10 s grace is over;
## a report after the grace does not buy time back.
func test_a_decision_clock_waits_for_its_panel_or_its_grace() -> void:
	var clock: DuelClock = DuelClock.new()
	clock.arm(0, &"declare", {}, 0)
	clock.arm(1, &"declare", {}, 0)
	eq(clock.state(0, 5000)["phase"], "off", "armed is not running")
	clock.shown(0, 3000)
	eq(clock.state(0, 3000), {"left_ms": 30000, "bank_ms": 60000, "phase": "run"}, "the panel starts it")
	eq(clock.tick(9999), [] as Array[int], "within the grace")
	eq(clock.state(1, 9999)["phase"], "off", "the other seat still waits for its panel")
	clock.tick(12000)
	eq(clock.state(1, 12000)["left_ms"], 28000, "the grace started it at 10 s, not when the tick came")
	clock.arm(1, &"declare", {}, 20000)
	clock.shown(1, 45000)
	eq(clock.state(1, 45000)["left_ms"], 15000, "a late report starts it from the end of the grace")
	clock.shown(0, 50000)
	eq(clock.out_at(0), 3000 + 30000 + 60000, "a report for a running clock changes nothing")


## A seat whose client lost its table gets it back from `Referee.catch_up`: the view and prompt its
## last update carried, this turn's lines from its `turn_start` on with nothing to animate, and
## nothing taken from the next update either seat gets. A referee rebuilt by `replay` catches up
## the same way.
func test_a_catch_up_gives_a_seat_its_view_prompt_and_this_turn() -> void:
	var decks: Array[DeckList] = [deck(filler(["t_art", "t_parry"], 40)), deck(filler(["t_guard"], 40), "pact")]
	var live: Referee = Referee.new()
	live.setup(decks, lib, table, 33)
	var twin: Referee = Referee.new()
	twin.setup(decks, lib, table, 33)
	live.start()
	twin.start()
	var last: Array[SeatUpdate] = live.take_updates()
	twin.take_updates()
	var picker: RandomNumberGenerator = RandomNumberGenerator.new()
	picker.seed = 7
	var refused: int = 0
	for step in range(120):
		if live.is_over() or live.engine.state.turn >= 3:
			break
		var p: Prompt = live.engine.prompt
		var wire: Dictionary = p.options[picker.randi_range(0, p.options.size() - 1)].to_dict()
		if live.submit(p.player, wire) != "" or twin.submit(p.player, wire) != "":
			refused += 1
		last = live.take_updates()
		twin.take_updates()
	eq(refused, 0, "every listed option was taken")
	check(not live.is_over() and live.engine.state.turn >= 2, "the duel is past its first turn (turn %d)" % live.engine.state.turn)
	for seat in range(2):
		var caught: SeatUpdate = live.catch_up(seat)
		eq(JSON.stringify(caught.view.to_dict()), JSON.stringify(last[seat].view.to_dict()), "seat %d gets the view it last had" % seat)
		eq(caught.prompt.to_dict() if caught.prompt != null else {}, last[seat].prompt.to_dict() if last[seat].prompt != null else {},
			"seat %d gets the prompt it last had" % seat)
		var animated: int = 0
		var turn_starts: int = 0
		for line in caught.lines:
			if line.has("data"):
				animated += 1
			if str(line.get("type", "")) == "turn_start":
				turn_starts += 1
		eq(animated, 0, "seat %d reads this turn as log lines only" % seat)
		check(not caught.lines.is_empty() and str(caught.lines[0].get("type", "")) == "turn_start" and turn_starts == 1,
			"seat %d's lines run from this turn's start" % seat)
	var p_next: Prompt = live.engine.prompt
	var next_wire: Dictionary = p_next.options[0].to_dict()
	live.submit(p_next.player, next_wire)
	twin.submit(p_next.player, next_wire)
	var after: Array[SeatUpdate] = live.take_updates()
	var twin_after: Array[SeatUpdate] = twin.take_updates()
	for seat in range(2):
		eq(JSON.stringify(after[seat].to_dict()), JSON.stringify(twin_after[seat].to_dict()),
			"seat %d's next update is the one it would have had without a catch-up" % seat)
	var rebuilt: Referee = Referee.new()
	rebuilt.setup(decks, lib, table, 33)
	eq(rebuilt.replay(live.history), "", "the history replays")
	rebuilt.take_updates()
	for seat in range(2):
		eq(JSON.stringify(rebuilt.catch_up(seat).to_dict()), JSON.stringify(live.catch_up(seat).to_dict()),
			"a referee rebuilt by replay catches seat %d up the same way" % seat)


# --- Match replay -------------------------------------------------------------

## A random duel to the end, its record read back from its own line as a replay file gives it.
func replay_duel() -> DuelHost:
	var decks: Array[DeckList] = [deck(filler(["t_art", "t_parry"], 30)), deck(filler(["t_guard"], 30), "pact")]
	return recorded_duel(decks, lib, table, 57, false)


func replay_record(host: DuelHost) -> MatchRecord:
	return MatchRecord.from_dict(JSON.parse_string(host.record.line()))


func final_views(views: Array[SeatView]) -> String:
	return JSON.stringify(views[0].to_dict()) + JSON.stringify(views[1].to_dict())


## Stepping a record to its last entry stands on the table the live duel ended on, seat by seat,
## with the recorded result. Every step hands out both seats' updates and the full one, carrying
## animation data and stamps as the live updates did.
func test_a_replay_stepped_to_its_end_stands_where_the_duel_ended() -> void:
	var host: DuelHost = replay_duel()
	var record: MatchRecord = replay_record(host)
	check(record != null and record.has_result(), "the duel's record loads with its result")
	if record == null:
		return
	var cursor: ReplayCursor = ReplayCursor.new(record, lib, table)
	eq(cursor.stopped, "", "every entry replays")
	eq(cursor.total, record.commands.size(), "the silent pass counts every entry")
	eq(cursor.opening.size(), 3, "the deal comes as both seats' updates and the full one")
	check(not cursor.turns.is_empty() and int(cursor.turns[0]["turn"]) == 1, "the silent pass indexes the turns from turn 1")
	var steps: int = 0
	var animated: int = 0
	while not cursor.at_end:
		var updates: Array[SeatUpdate] = cursor.step()
		if updates.size() != 3:
			break
		steps += 1
		for line in updates[0].lines:
			if line.has("data") and line.has("state"):
				animated += 1
	eq(steps, record.commands.size(), "one step per entry")
	check(animated > 0, "the steps carry animation data and stamps")
	eq(final_views([cursor.view(0), cursor.view(1)]), final_views([host.referee.view_for(0), host.referee.view_for(1)]),
		"both seats see the table the duel ended on")
	eq(cursor.view(0).winner, int(record.result["winner"]), "with the recorded winner")
	eq(cursor.view(0).win_reason, str(record.result["reason"]), "and the recorded reason")
	eq(cursor.step().size(), 0, "a step past the end does nothing")


## A jump to a turn rebuilds silently and shows each view the table stepping there shows, with this
## turn's lines as a catch-up that animates nothing, and plays on level with the stepped cursor.
func test_a_replay_jump_shows_the_table_stepping_there_shows() -> void:
	var record: MatchRecord = replay_record(replay_duel())
	var stepped: ReplayCursor = ReplayCursor.new(record, lib, table)
	var jumped: ReplayCursor = ReplayCursor.new(record, lib, table)
	check(stepped.turns.size() >= 3, "the duel runs past its second turn (%d turns)" % stepped.turns.size())
	var turn: int = int(stepped.turns[stepped.turns.size() / 2]["turn"])
	var target: int = stepped.turn_index(turn)
	check(target > 0, "turn %d opens at entry %d" % [turn, target])
	var last: Array[SeatUpdate] = stepped.opening
	while stepped.position < target:
		last = stepped.step()
	var caught: Array[SeatUpdate] = jumped.seek(target)
	eq(jumped.position, target, "the jump lands on the entry asked for")
	eq(jumped.current_turn(), turn, "in the turn asked for")
	eq(caught.size(), 3, "with a catch-up per view")
	for index in range(caught.size()):
		eq(JSON.stringify(caught[index].view.to_dict()), JSON.stringify(last[index].view.to_dict()), "view %d matches stepping there" % index)
		eq(caught[index].prompt.to_dict() if caught[index].prompt != null else {}, last[index].prompt.to_dict() if last[index].prompt != null else {},
			"and so does its prompt")
		var animated: bool = false
		for line in caught[index].lines:
			animated = animated or line.has("data")
		check(not animated and not caught[index].lines.is_empty() and str(caught[index].lines[0].get("type", "")) == "turn_start",
			"view %d reads this turn from its start with nothing to animate" % index)
	eq(jumped.step().size(), 3, "the jumped cursor plays on")
	stepped.step()
	eq(final_views([jumped.view(0), jumped.view(1)]), final_views([stepped.view(0), stepped.view(1)]), "level with the stepped one")
	eq(jumped.turn_index(999), -1, "a turn the record never reaches has no entry")


## Back rebuilds one entry earlier, and the step after it hands out the updates the first pass did.
func test_a_replay_step_back_then_forward_returns_to_the_same_table() -> void:
	var cursor: ReplayCursor = ReplayCursor.new(replay_record(replay_duel()), lib, table)
	var target: int = cursor.total / 2
	var before: Array[SeatUpdate] = []
	while cursor.position < target:
		before = cursor.step()
	var back: Array[SeatUpdate] = cursor.back()
	eq(cursor.position, target - 1, "back is one entry earlier")
	eq(back.size(), 3, "with a catch-up per view")
	var again: Array[SeatUpdate] = cursor.step()
	eq(cursor.position, target, "the step after it returns")
	for index in range(mini(again.size(), before.size())):
		eq(JSON.stringify(again[index].to_dict()), JSON.stringify(before[index].to_dict()), "update %d is the one the first pass gave" % index)


## The full-information view fills in every card, and its lines name every card either seat's own
## lines leave as "a card", every draw included. The seat views stay masked as their players saw.
func test_a_full_information_replay_names_every_card() -> void:
	var cursor: ReplayCursor = ReplayCursor.new(replay_record(replay_duel()), lib, table)
	var masked: int = 0
	var unnamed: int = 0
	var draws: int = 0
	var draws_named: int = 0
	var updates: Array[SeatUpdate] = cursor.opening
	while updates.size() == 3:
		var full: SeatUpdate = updates[ReplayCursor.ALL]
		for i in range(full.lines.size()):
			var line: String = str(full.lines[i].get("line", ""))
			for seat in range(2):
				if str(updates[seat].lines[i].get("line", "")).contains("a card"):
					masked += 1
					if line.contains("a card"):
						unnamed += 1
			if str(full.lines[i].get("type", "")) == "draw":
				draws += 1
				if not line.ends_with(" draws."):
					draws_named += 1
		updates = cursor.step()
	check(masked > 0, "the seats' own lines leave cards unnamed (%d lines)" % masked)
	eq(unnamed, 0, "the full lines name every one of them")
	check(draws > 0 and draws_named == draws, "and every card drawn (%d of %d)" % [draws_named, draws])
	cursor.seek(cursor.total / 2)
	var full_view: SeatView = cursor.view(0, true)
	var hidden: int = 0
	for c in full_view.cards.values():
		if (c as SeatCard).hidden():
			hidden += 1
	eq(hidden, 0, "the full view fills in every card")
	check(not full_view.player(1).hand.is_empty(), "the far hand is there to show")
	for seat in range(2):
		var own: SeatView = cursor.view(seat)
		var masks: bool = not own.player(seat).life_deck.is_empty()
		for uid in own.player(seat).life_deck + own.player(1 - seat).hand:
			masks = masks and own.card(uid).hidden()
		check(masks, "seat %d's own view still hides its Life Deck and the other hand" % seat)


## A record a client wrote and the same game as the server signs it replay to the same table, and a
## record file gives back the line asked for by id, its last line, or a whole `.replay.json`.
func test_a_replay_reads_client_and_server_records_from_their_files() -> void:
	var host: DuelHost = replay_duel()
	var client_line: String = host.record.line()
	var as_server: Dictionary = JSON.parse_string(client_line)
	as_server["origin"] = "server"
	as_server["sig"] = "ab".repeat(32)
	as_server["id"] = "0123456789abcdef"
	var dir: String = "user://test_replay_files"
	DirAccess.make_dir_recursive_absolute(dir)
	var jsonl: String = dir.path_join("records.jsonl")
	var single: String = dir.path_join("%s.replay.json" % host.record.id)
	var file: FileAccess = FileAccess.open(jsonl, FileAccess.WRITE)
	file.store_string(client_line + "\n" + JSON.stringify(as_server) + "\n")
	file.close()
	file = FileAccess.open(single, FileAccess.WRITE)
	file.store_string(client_line)
	file.close()
	var by_id: MatchRecord = MatchRecord.load_file(jsonl, host.record.id)
	var last: MatchRecord = MatchRecord.load_file(jsonl)
	var whole: MatchRecord = MatchRecord.load_file(single)
	check(by_id != null and by_id.origin == "client", "the client line loads by its id")
	check(last != null and last.origin == "server", "the last line loads when no id is given: %s" % MatchRecord.file_problem(jsonl))
	check(whole != null and whole.id == host.record.id, "a .replay.json loads whole")
	check(MatchRecord.file_problem(jsonl, "ffffffffffffffff").begins_with("no record"), "an id the file lacks is refused")
	check(MatchRecord.file_problem(dir.path_join("none.jsonl")).begins_with("there is no file"), "and so is a file that is not there")
	for path in [jsonl, single]:
		DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(dir)
	if by_id == null or last == null:
		return
	var finals: Array[String] = []
	for r: MatchRecord in [by_id, last]:
		var cursor: ReplayCursor = ReplayCursor.new(r, lib, table)
		while not cursor.at_end and not cursor.step().is_empty():
			pass
		finals.append(final_views([cursor.view(0), cursor.view(1)]))
	eq(finals[0], finals[1], "the client record and the server record replay to the same table")
	eq(finals[0], final_views([host.referee.view_for(0), host.referee.view_for(1)]), "the one the duel ended on")


## The peers of each pair `MatchQueue.pair` returned, in order.
func queue_pairs(pairs: Array) -> Array:
	var out: Array = []
	for two: Array in pairs:
		out.append([int(two[0]["peer"]), int(two[1]["peer"])])
	return out


func queue_peers(q: MatchQueue) -> Array:
	var out: Array = []
	for entry: Dictionary in q.entries:
		out.append(int(entry["peer"]))
	return out


## Find a duel pairs the two who have waited longest, each with how long it waited.
func test_queue_pairs_two_oldest_first() -> void:
	var q: MatchQueue = MatchQueue.new()
	q.join(11, 100)
	eq(q.pair(150).size(), 0, "one player waiting is no pair")
	q.join(12, 200)
	q.join(13, 300)
	var pairs: Array = q.pair(400)
	eq(queue_pairs(pairs), [[11, 12]], "of three waiting, the two oldest pair")
	if pairs.size() == 1:
		eq([int(pairs[0][0]["waited_ms"]), int(pairs[0][1]["waited_ms"])], [300, 200], "each with its wait")
	eq(queue_peers(q), [13], "and the third keeps waiting")


func test_queue_ignores_duplicate_join() -> void:
	var q: MatchQueue = MatchQueue.new()
	check(q.join(21, 100), "a first join is taken")
	check(not q.join(21, 500), "a second join from the same peer is not")
	eq(q.size(), 1, "the peer waits once")
	eq(q.waiting(21, 600), 500, "from its first join")
	eq(q.pair(600).size(), 0, "and is never paired with itself")


func test_queue_forgets_a_leaver() -> void:
	var q: MatchQueue = MatchQueue.new()
	q.join(31, 100)
	q.join(32, 200)
	check(q.leave(31), "a waiting peer leaves")
	check(not q.leave(31), "a peer not waiting cannot leave again")
	eq(q.waiting(31, 300), -1, "and is not waiting")
	q.join(33, 300)
	eq(queue_pairs(q.pair(400)), [[32, 33]], "the next two pair without it")


## A player whose opponent left before the deal goes back in line at its first join time.
func test_requeue_keeps_join_time() -> void:
	var q: MatchQueue = MatchQueue.new()
	q.join(41, 100)
	q.join(42, 200)
	eq(queue_pairs(q.pair(250)), [[41, 42]], "the first two pair")
	q.join(43, 300)
	q.join(44, 350)
	q.requeue(41, 100)
	eq(queue_peers(q), [41, 43, 44], "the re-queued player is ahead of those who joined after it")
	eq(q.waiting(41, 500), 400, "counting from its first join")
	q.requeue(41, 100)
	eq(queue_peers(q), [41, 43, 44], "a second re-queue moves it rather than adding it twice")
	q.requeue(45, 350)
	eq(queue_peers(q), [41, 43, 45, 44], "a tie on the join time goes to the re-queued player")
	eq(queue_pairs(q.pair(500)), [[41, 43], [45, 44]], "and pairing takes them in that order")


func test_queue_holds_pairs_at_the_duel_cap() -> void:
	var q: MatchQueue = MatchQueue.new()
	for i in range(4):
		q.join(51 + i, 100 * (i + 1))
	eq(q.pair(500, 0).size(), 0, "no room under the duel cap: no pair")
	eq(queue_peers(q), [51, 52, 53, 54], "and everyone keeps their place")
	eq(queue_pairs(q.pair(500, 1)), [[51, 52]], "room for one duel: the oldest two pair")
	eq(queue_pairs(q.pair(500)), [[53, 54]], "no cap: the rest pair")


func test_queue_drops_after_max_wait() -> void:
	var q: MatchQueue = MatchQueue.new()
	var max_wait: int = 30 * 60 * 1000
	q.join(61, 0)
	q.join(62, 1000)
	eq(q.drop_stale(max_wait - 1, max_wait).size(), 0, "nobody is dropped short of the wait")
	var dropped: Array[int] = q.drop_stale(max_wait, max_wait)
	eq(dropped.size() == 1 and dropped[0] == 61, true, "the first joiner is dropped at the wait")
	eq(queue_peers(q), [62], "and the later one still waits")
	dropped = q.drop_stale(max_wait + 1000, max_wait)
	eq(dropped.size() == 1 and dropped[0] == 62, true, "until its own wait is up")
	eq(q.size(), 0, "then nobody waits")


# --- Identity -----------------------------------------------------------------

const IDENTITY_DIR: String = "user://test_identity"


func clear_identity_dir() -> void:
	var dir: DirAccess = DirAccess.open(IDENTITY_DIR)
	if dir == null:
		return
	for file_name in dir.get_files():
		DirAccess.remove_absolute(IDENTITY_DIR.path_join(file_name))
	DirAccess.remove_absolute(IDENTITY_DIR)


## An install's identity is made and stored on first use and loads with the same id after; its
## signature checks only for its own bytes under its own key; a key file that cannot be read is set
## aside, never overwritten, and a new identity takes its place.
func test_an_identity_keeps_its_key_and_signs_only_its_own_bytes() -> void:
	clear_identity_dir()
	var file: String = IDENTITY_DIR.path_join("identity.key")
	var made: Identity = Identity.load_or_make(file)
	check(FileAccess.file_exists(file), "a first use stores the key")
	check(made.id().length() == 64 and made.id().is_valid_hex_number(), "the id is 64 hex characters: %s" % made.id())
	eq(made.id(), made.public_pem().sha256_text(), "the SHA-256 of the public key as PEM")
	eq(Identity.id_of(made.public_pem()), made.id(), "and the same when worked out from the PEM alone")
	check(made.public_pem().begins_with("-----BEGIN PUBLIC KEY-----") and not made.public_pem().contains("PRIVATE"),
		"the public half carries nothing private")
	var loaded: Identity = Identity.load_or_make(file)
	eq(loaded.id(), made.id(), "a later load gives the same identity")
	var message: PackedByteArray = "nonce, protocol, catalog".to_utf8_buffer()
	var sig: PackedByteArray = made.sign(message)
	check(Identity.verify(made.public_pem(), message, sig), "a signature checks under its own key")
	check(Identity.verify(made.public_pem(), message, loaded.sign(message)), "and the loaded key signs as the stored one")
	var tampered: PackedByteArray = message.duplicate()
	tampered[0] ^= 1
	check(not Identity.verify(made.public_pem(), tampered, sig), "a changed message fails")
	var bent: PackedByteArray = sig.duplicate()
	bent[10] ^= 1
	check(not Identity.verify(made.public_pem(), message, bent), "a changed signature fails")
	var other: Identity = Identity.generate()
	check(not Identity.verify(other.public_pem(), message, sig) and other.id() != made.id(), "another key's signature fails")
	check(not Identity.verify("not a key", message, sig) and not Identity.verify(made.public_pem(), message, PackedByteArray()),
		"a malformed key or an empty signature fails")
	eq(Identity.id_of("-----BEGIN PUBLIC KEY-----\njunk\n-----END PUBLIC KEY-----\n"), "", "a malformed public key has no id")

	var junk: FileAccess = FileAccess.open(file, FileAccess.WRITE)
	junk.store_string("this is not a key")
	junk.close()
	var fresh: Identity = Identity.load_or_make(file)
	check(fresh.id() != made.id() and fresh.id().length() == 64, "a corrupt key file gives way to a new identity")
	var set_aside: Array[String] = []
	for file_name in DirAccess.get_files_at(IDENTITY_DIR):
		if file_name.begins_with("identity.key.bad-"):
			set_aside.append(file_name)
	var kept: String = FileAccess.get_file_as_string(IDENTITY_DIR.path_join(set_aside[0])) if set_aside.size() == 1 else ""
	check(set_aside.size() == 1 and kept == "this is not a key", "the corrupt file is set aside whole, not overwritten: %s" % str(set_aside))
	eq(Identity.load_or_make(file).id(), fresh.id(), "and the new identity is the one stored from then on")
	clear_identity_dir()


# --- Ranked -------------------------------------------------------------------

const RATING_GOLDEN: String = "res://tests/fixtures/rating_golden.json"
const RANKED_DIR: String = "user://test_ranked"


func clear_ranked_dir() -> void:
	if not DirAccess.dir_exists_absolute(RANKED_DIR):
		return
	for file_name in DirAccess.get_files_at(RANKED_DIR):
		DirAccess.remove_absolute(RANKED_DIR.path_join(file_name))
	DirAccess.remove_absolute(RANKED_DIR)


func near(actual: float, expected: float, tolerance: float, msg: String) -> void:
	check(absf(actual - expected) <= tolerance, "%s: expected %.12f, got %.12f" % [msg, expected, actual])


## The port gives what openskill's PlackettLuce gives with the same constants, to 1e-9, for every
## case the golden file holds: new players, settled ones, upsets and a run of ten matches.
func test_the_rating_port_matches_the_openskill_golden_fixture() -> void:
	check(FileAccess.file_exists(RATING_GOLDEN), "the golden file is there")
	var golden: Variant = JSON.parse_string(FileAccess.get_file_as_string(RATING_GOLDEN))
	var cases: Array = (golden as Dictionary).get("cases", []) if golden is Dictionary else []
	check(cases.size() >= 20, "it holds at least 20 cases: %d" % cases.size())
	for item: Variant in cases:
		var c: Dictionary = item
		var after: Array[Dictionary] = Rating.rate(c["winner"], c["loser"])
		for i in range(2):
			var want: Dictionary = (c["after"] as Array)[i]
			var label: String = "%s, %s" % [str(c["name"]), "winner" if i == 0 else "loser"]
			near(float(after[i]["mu"]), float(want["mu"]), 1e-9, label + " mu")
			near(float(after[i]["sigma"]), float(want["sigma"]), 1e-9, label + " sigma")
			near(Rating.ordinal(float(after[i]["mu"]), float(after[i]["sigma"])), float(want["ordinal"]), 1e-9, label + " ordinal")
	var first: Array[Dictionary] = Rating.rate(Rating.fresh(), Rating.fresh())
	near(float(first[0]["mu"]), 27.64, 0.005, "a new winner against a new loser goes to 27.64")
	near(float(first[0]["sigma"]), 8.07, 0.005, "with sigma 8.07")
	near(float(first[1]["mu"]), 22.36, 0.005, "and the loser to 22.36")


func test_a_rating_shows_forty_times_its_ordinal_and_is_provisional_while_unsure() -> void:
	var first: Array[Dictionary] = Rating.rate(Rating.fresh(), Rating.fresh())
	eq(Rating.shown(Rating.MU, Rating.SIGMA), 0, "a new player shows 0")
	eq(Rating.shown(float(first[0]["mu"]), float(first[0]["sigma"])), 138, "the first match won shows 138")
	eq(Rating.shown(float(first[1]["mu"]), float(first[1]["sigma"])), 0, "the first match lost stays at 0")
	eq(Rating.shown(30.0, 2.0), 960, "40 times mu less three sigma")
	check(Rating.provisional(Rating.SIGMA) and Rating.provisional(6.01), "provisional while sigma is above 6")
	check(not Rating.provisional(6.0) and not Rating.provisional(4.1), "and settled from 6 down")


## Applied results land in the file and read back the same; a rebuild from the records in order
## gives the same ratings, skipping games that did not decide a match, matches with no winner and
## casual records. A file that is not a ratings file is refused, not overwritten.
func test_the_ratings_store_round_trips_and_rebuilds_from_the_records() -> void:
	clear_ranked_dir()
	DirAccess.make_dir_recursive_absolute(RANKED_DIR)
	var a: String = "a".repeat(64)
	var b: String = "b".repeat(64)
	var c: String = "c".repeat(64)
	var store: RatingsStore = RatingsStore.new()
	eq(store.open(RANKED_DIR), "", "a data directory with no ratings file opens empty")
	eq(store.get_or_new(a), {"mu": Rating.MU, "sigma": Rating.SIGMA, "games": 0, "wins": 0, "last_played": 0}, "an unknown identity reads as new")
	check(store.entries.is_empty(), "and is not stored by reading it")
	var change: Dictionary = store.apply(a, b, 1000)
	var expected: Array[Dictionary] = Rating.rate(Rating.fresh(), Rating.fresh())
	eq(str(change.get("problem", "?")), "", "the file is written")
	eq(change["winner"]["before"], Rating.fresh(), "the winner's rating before")
	near(float(change["winner"]["after"]["mu"]), float(expected[0]["mu"]), 1e-12, "and after")
	eq([int(store.entries[a]["games"]), int(store.entries[a]["wins"]), int(store.entries[b]["games"]), int(store.entries[b]["wins"])],
		[1, 1, 1, 0], "one match each, one win to the winner")
	eq(int(store.entries[b]["last_played"]), 1000, "both stamped with when")
	store.apply(b, c, 2000)
	store.apply(a, c, 3000)
	check(store.apply(a, a, 4000).is_empty() and int(store.entries[a]["games"]) == 2, "an identity against itself is never rated")
	var reopened: RatingsStore = RatingsStore.new()
	eq(reopened.open(RANKED_DIR), "", "the file opens again")
	eq(JSON.stringify(reopened.entries, "", true, true), JSON.stringify(store.entries, "", true, true), "with every rating exactly as saved")
	check(not FileAccess.file_exists(RANKED_DIR.path_join(RatingsStore.FILE + ".tmp")), "and no temporary file left")

	var records: Array = []
	var played: Array = [[a, b, 0], [b, c, 0], [a, c, 1]]
	for i in range(played.size()):
		var game_one: MatchRecord = ranked_record([str(played[i][0]), str(played[i][1])], 1, 0, {}, 900 + i * 1000)
		var deciding: MatchRecord = ranked_record([str(played[i][0]), str(played[i][1])], 2, 0,
			{"winner": 0, "wins": [2, 0], "reason": "concede"}, 1000 + i * 1000, game_one.match_id)
		records.append_array([game_one, deciding])
	var no_winner: MatchRecord = ranked_record([a, c], 1, -1, {"winner": -1, "wins": [0, 0], "reason": "abandoned"}, 5000)
	var casual: MatchRecord = ranked_record([c, a], 1, 0, {"winner": 0, "wins": [1, 0], "reason": "survival"}, 6000)
	casual.mode = "casual"
	records.append_array([no_winner, casual, "not a record"])
	var rebuilt: RatingsStore = RatingsStore.new()
	eq(rebuilt.rebuild(records), 3, "a rebuild applies the three decided matches with a winner")
	eq(JSON.stringify(rebuilt.entries, "", true, true), JSON.stringify(store.entries, "", true, true), "and ends where the live store did")

	var junk: FileAccess = FileAccess.open(RANKED_DIR.path_join(RatingsStore.FILE), FileAccess.WRITE)
	junk.store_string("{\"%s\": {\"mu\": \"high\"}}" % a)
	junk.close()
	check(RatingsStore.new().open(RANKED_DIR) != "", "a malformed ratings file is refused")
	clear_ranked_dir()


## A ranked server record between two identities, as the tests need one: seat 0 `ids[0]`.
func ranked_record(ids: Array[String], game: int, winner: int, match_result: Dictionary, started: int, match_id: String = "") -> MatchRecord:
	var ab: Array[String] = ["alpha", "beta"]
	var r: MatchRecord = stats_record(ab, winner, "concede" if winner >= 0 else "abandoned", 3, 0, "", "server", "ranked")
	r.match_id = match_id if match_id != "" else r.id
	r.game = game
	r.started = started
	r.match_result = match_result.duplicate(true)
	for seat in range(2):
		r.seats[seat]["identity"] = ids[seat]
	return r


## The first leave is a warning; each one after it keeps the identity out for longer, from 2 minutes
## up to an hour, counted from that leave. A day without a leave clears the count, and the file
## keeps timestamps only.
func test_the_leaver_ladder_climbs_and_clears_after_a_day() -> void:
	clear_ranked_dir()
	DirAccess.make_dir_recursive_absolute(RANKED_DIR)
	var id: String = "d".repeat(64)
	var conduct: Conduct = Conduct.new()
	eq(conduct.open(RANKED_DIR), "", "a data directory with no conduct file opens empty")
	var t: int = 1_800_000_000
	eq(conduct.cooldown_left_ms(id, t), 0, "nobody starts on a cooldown")
	eq(conduct.leave(id, t), 0, "the first leave is a warning")
	eq(conduct.cooldown_left_ms(id, t + 1), 0, "with no time out of the queue")
	eq(conduct.next_cost_ms(id, t + 1), 120000, "and says the next one costs 2 minutes")
	var costs: Array[int] = []
	for i in range(6):
		t += 600
		costs.append(conduct.leave(id, t))
	eq(costs, [120000, 300000, 900000, 1800000, 3600000, 3600000], "then 2, 5, 15, 30 and 60 minutes, and 60 after")
	eq(conduct.cooldown_left_ms(id, t + 1), 3599000, "counted from the last leave")
	eq(Conduct.wait_text(conduct.cooldown_left_ms(id, t + 1)), "59:59", "and read as minutes and seconds")
	eq(Conduct.wait_text(299001), "5:00", "rounded up to the second")
	eq(conduct.cooldown_left_ms(id, t + 3600), 0, "an hour on it is over")
	var reopened: Conduct = Conduct.new()
	eq(reopened.open(RANKED_DIR), "", "the file opens again")
	eq(reopened.count(id, t + 3600), 7, "with every leave in the run")
	var text: String = FileAccess.get_file_as_string(RANKED_DIR.path_join(Conduct.FILE))
	check(text.contains(id) and not text.contains("mu") and not text.contains("name"), "holding the identity and its timestamps only")
	var day_later: int = t + Conduct.CLEAR_AFTER_S
	eq(reopened.count(id, day_later), 0, "a day without a leave clears the count")
	eq(reopened.leave(id, day_later), 0, "so the next leave is a warning again")
	clear_ranked_dir()


func ranked_queue() -> MatchQueue:
	var q: MatchQueue = MatchQueue.new()
	q.rated = true
	return q


## A rated queue pairs two players only while one of them accepts the gap: 3 mu at once, 3 more for
## each 30 seconds waited, anyone after 90 seconds. The oldest player takes the oldest opponent it
## accepts, and an identity never meets itself.
func test_the_ranked_queue_pairs_on_mu_within_a_widening_window() -> void:
	var q: MatchQueue = ranked_queue()
	near(MatchQueue.window_mu(0), 3.0, 1e-9, "a player accepts 3 mu at once")
	near(MatchQueue.window_mu(60000), 9.0, 1e-9, "9 after a minute")
	check(is_inf(MatchQueue.window_mu(90000)), "and anyone after 90 seconds")
	q.join(71, 0, 25.0, "a")
	q.join(72, 0, 34.0, "b")
	eq(q.pair(0).size(), 0, "9 mu apart they do not pair at once")
	eq(q.pair(59999).size(), 0, "nor a millisecond short of a minute")
	var pairs: Array = q.pair(60000)
	eq(queue_pairs(pairs), [[71, 72]], "at a minute the window reaches them")
	if pairs.size() == 1:
		eq([int(pairs[0][0]["waited_ms"]), int(pairs[0][1]["waited_ms"])], [60000, 60000], "each with its wait")
	q.join(73, 0, 25.0, "c")
	q.join(74, 1000, 60.0, "d")
	eq(q.pair(89999).size(), 0, "35 mu apart nobody pairs short of 90 seconds")
	eq(queue_pairs(q.pair(90000)), [[73, 74]], "and at 90 seconds the one who waited that long takes anyone")
	q.join(75, 0, 25.0, "e")
	q.join(76, 1, 40.0, "f")
	q.join(77, 2, 26.0, "g")
	eq(queue_pairs(q.pair(2)), [[75, 77]], "the oldest takes the oldest opponent inside its window")
	eq(queue_peers(q), [76], "and the one outside keeps waiting")
	q.clear()
	q.join(78, 0, 25.0, "h")
	q.join(79, 0, 25.0, "h")
	eq(q.pair(200000).size(), 0, "one identity never meets itself")
	var casual: MatchQueue = MatchQueue.new()
	casual.join(81, 0, 25.0, "i")
	casual.join(82, 0, 60.0, "i")
	eq(queue_pairs(casual.pair(0)), [[81, 82]], "a casual queue still pairs the two oldest, rating or not")


## The same two are not paired twice in a row until both have waited a minute; with anyone else to
## pair, each meets someone new.
func test_the_ranked_queue_does_not_pair_the_same_two_twice_in_a_row() -> void:
	var q: MatchQueue = ranked_queue()
	q.join(91, 0, 25.0, "a")
	q.join(92, 0, 25.0, "b")
	eq(queue_pairs(q.pair(0)), [[91, 92]], "two new players pair")
	q.join(91, 1000, 25.0, "a")
	q.join(92, 1000, 25.0, "b")
	eq(q.pair(1000).size(), 0, "straight back in, the same two do not pair again")
	eq(q.pair(60999).size(), 0, "nor a millisecond short of a minute")
	eq(queue_pairs(q.pair(61000)), [[91, 92]], "after a minute with nobody else, they do")
	q.join(91, 70000, 25.0, "a")
	q.join(92, 70000, 25.0, "b")
	q.join(93, 70001, 25.0, "c")
	eq(queue_pairs(q.pair(70001)), [[91, 93]], "with a third player waiting, each meets someone new")
	eq(queue_peers(q), [92], "and the other waits")


## A version 2 record carries its match id, game number, and on the deciding game the match's result
## and both ratings, and reads back whole. A version 1 line still loads and writes back as the same
## line, so its signature still checks. Version 1 cannot carry the new fields, and a malformed match
## or rating is refused.
func test_a_version_2_record_carries_its_match_and_a_version_1_record_still_loads() -> void:
	var ids: Array[String] = ["a".repeat(64), "b".repeat(64)]
	var r: MatchRecord = ranked_record(ids, 2, 1, {"winner": 1, "wins": [0, 2], "reason": "concede"}, 1000, "0123456789abcdef")
	var rated: Array[Dictionary] = Rating.rate(Rating.fresh(), Rating.fresh())
	r.seats[1]["rating"] = {"before": Rating.fresh(), "after": rated[0]}
	r.seats[0]["rating"] = {"before": Rating.fresh(), "after": rated[1]}
	var line: String = r.line()
	var back: MatchRecord = MatchRecord.from_dict(JSON.parse_string(line))
	check(back != null, "a ranked record loads: %s" % MatchRecord.problem_of(JSON.parse_string(line)))
	if back != null:
		eq([back.v, back.match_id, back.game, back.mode], [2, "0123456789abcdef", 2, "ranked"], "with its version, match id, game and mode")
		eq([int(back.match_result["winner"]), str(back.match_result["wins"]), str(back.match_result["reason"])], [1, "[0, 2]", "concede"],
			"its match result")
		near(float(back.seats[1]["rating"]["after"]["mu"]), float(rated[0]["mu"]), 1e-12, "and the winner's rating after")
		eq(back.line(), line, "and writes back as the same line")
	var decks: Array[String] = ["alpha", "beta"]
	var plain: MatchRecord = stats_record(decks, 0, "survival", 3, 0)
	var plain_dict: Dictionary = JSON.parse_string(plain.line())
	eq([plain.v, str(plain_dict["match_id"]), int(plain_dict["game"]), plain_dict.has("match")], [2, plain.id, 1, false],
		"a game of one is its own match, game 1, with no match object")
	var old: Dictionary = plain_dict.duplicate(true)
	old["v"] = 1
	old.erase("match_id")
	old.erase("game")
	var old_back: MatchRecord = MatchRecord.from_dict(JSON.parse_string(JSON.stringify(old)))
	check(old_back != null and old_back.v == 1 and old_back.game == 1 and old_back.match_id == old_back.id,
		"a version 1 record still loads: %s" % MatchRecord.problem_of(old))
	if old_back != null:
		eq(MatchRecord.canonical(old_back.to_dict()), MatchRecord.canonical(old), "and writes back as version 1, so its signed text is unchanged")
	var base: Dictionary = JSON.parse_string(line)
	var edits: Array = [
		["a version 1 record with a match id", func(d: Dictionary) -> void: d["v"] = 1],
		["game 4", func(d: Dictionary) -> void: d["game"] = 4],
		["game 0", func(d: Dictionary) -> void: d["game"] = 0],
		["a match id that is not 16 hex", func(d: Dictionary) -> void: d["match_id"] = "match"],
		["a match with a reason it does not know", func(d: Dictionary) -> void: d["match"]["reason"] = "vibes"],
		["a match winner who is no seat", func(d: Dictionary) -> void: d["match"]["winner"] = 2],
		["a match with an extra key", func(d: Dictionary) -> void: d["match"]["best_of"] = 3],
		["a rating as text", func(d: Dictionary) -> void: d["seats"][0]["rating"]["after"]["mu"] = "high"],
		["a rating with no sigma", func(d: Dictionary) -> void: d["seats"][0]["rating"]["before"].erase("sigma")],
		["a rating with sigma 0", func(d: Dictionary) -> void: d["seats"][0]["rating"]["before"]["sigma"] = 0],
	]
	for edit in edits:
		var copy: Dictionary = base.duplicate(true)
		(edit[1] as Callable).call(copy)
		check(MatchRecord.from_dict(copy) == null, "refused: %s" % edit[0])


## Ranked records count by match as well as by game: each deck's match win rate from both seats,
## the matches won 2-0, 2-1 and ended early, and how often the game 1 winner took the match. Other
## records print no ranked block.
func test_match_stats_count_ranked_matches_by_deck_and_by_score() -> void:
	var ab: Array[String] = ["alpha", "beta"]
	var ba: Array[String] = ["beta", "alpha"]
	var stats: MatchStats = MatchStats.new()
	var plays: Array = [
		# deck order, match, game, game winner, game reason, match result on the deciding game
		[ab, "0000000000000001", 1, 0, "survival", {}],
		[ab, "0000000000000001", 2, 0, "seal", {"winner": 0, "wins": [2, 0], "reason": "seal"}],
		[ab, "0000000000000002", 1, 1, "survival", {}],
		[ab, "0000000000000002", 2, 0, "survival", {}],
		[ab, "0000000000000002", 3, 0, "concede", {"winner": 0, "wins": [2, 1], "reason": "concede"}],
		[ba, "0000000000000003", 1, 0, "survival", {}],
		[ba, "0000000000000003", 2, 1, "survival", {}],
		[ba, "0000000000000003", 3, 0, "ascension", {"winner": 0, "wins": [2, 1], "reason": "ascension"}],
		[ab, "0000000000000004", 1, 0, "survival", {}],
		[ab, "0000000000000004", 2, 1, "timeout", {"winner": 1, "wins": [1, 1], "reason": "timeout"}],
	]
	for play: Array in plays:
		var r: MatchRecord = stats_record(play[0], int(play[3]), str(play[4]), 5, 0, "", "server", "ranked")
		r.match_id = str(play[1])
		r.game = int(play[2])
		r.match_result = (play[5] as Dictionary).duplicate(true)
		check(stats.add(MatchRecord.from_dict(JSON.parse_string(r.line()))), "a ranked record counts by default")
	var ranked: Dictionary = stats.group_of("")["ranked"]
	eq([int(ranked["games"]), int(ranked["matches"])], [10, 4], "ten games, four matches")
	eq(ranked["decks"]["alpha"], [2, 4], "alpha won two of its four matches, from either seat")
	eq(ranked["decks"]["beta"], [2, 4], "and so did beta")
	eq([int(ranked["two_nil"]), int(ranked["two_one"]), int(ranked["short"])], [1, 2, 1], "one 2-0, two 2-1, one ended early")
	var text: String = stats.to_text()
	check(text.contains("RANKED  (4 matches decided from 10 games"), "the text has a ranked block")
	check(text.contains("won 2-0: 1 (25.0%), won 2-1: 2 (50.0%), ended early: 1 (25.0%)"), "with the scores")
	check(text.contains("the game 1 winner took the match 2 of 4"), "and the game 1 winner's share")
	var summary: Dictionary = stats.to_json()["groups"][0]
	check(summary.has("ranked") and int(summary["ranked"]["game_one_takes"]["won"]) == 2, "the JSON carries it too")
	var casual: MatchStats = MatchStats.new()
	casual.add(stats_record(ab, 0, "survival", 5, 0))
	check(not casual.to_text().contains("RANKED") and not casual.to_json()["groups"][0].has("ranked"), "a report with no ranked record prints no ranked block")


## A match conceded as a whole says "concede_match" in the deciding record's match while that game
## says "concede". The loader takes the reason there and nowhere else, and the stats tool counts
## such a match exactly as it counts one ended by a concession.
func test_a_match_conceded_as_a_whole_loads_and_counts_like_a_concession() -> void:
	var ab: Array[String] = ["alpha", "beta"]
	var plays: Array = [
		# match, game, game winner, match result on the deciding game
		["0000000000000011", 1, 1, {}],
		["0000000000000011", 2, 0, {}],
		["0000000000000011", 3, 0, {"winner": 0, "wins": [2, 1], "reason": "concede_match"}],
		["0000000000000012", 1, 0, {"winner": 0, "wins": [1, 0], "reason": "concede_match"}],
	]
	var whole: MatchStats = MatchStats.new()
	var game: MatchStats = MatchStats.new()
	for play: Array in plays:
		for reason: String in ["concede_match", "concede"]:
			var r: MatchRecord = stats_record(ab, int(play[2]), "concede", 5, 0, "", "server", "ranked")
			r.match_id = str(play[0])
			r.game = int(play[1])
			r.match_result = (play[3] as Dictionary).duplicate(true)
			if not r.match_result.is_empty():
				r.match_result["reason"] = reason
			var back: MatchRecord = MatchRecord.from_dict(JSON.parse_string(r.line()))
			check(back != null, "a ranked record whose match ends %s loads" % reason)
			if back != null:
				var into: MatchStats = whole if reason == "concede_match" else game
				check(into.add(back), "and counts")
				if not back.match_result.is_empty():
					eq([str(back.match_result["reason"]), str(back.result["reason"])], [reason, "concede"], "with the match's reason and the game's")
	var ranked: Dictionary = whole.group_of("")["ranked"]
	eq([int(ranked["matches"]), int(ranked["two_one"]), int(ranked["short"])], [2, 1, 1], "a conceded match counts by its score: one 2-1, one ended early")
	eq(ranked["decks"]["alpha"], [2, 2], "for the deck that won it")
	eq(whole.to_text(), game.to_text(), "the report reads the same as for matches ended by a concession")
	var line: Dictionary = JSON.parse_string(stats_record(ab, 0, "concede", 5, 0, "", "server", "ranked").line())
	line["result"]["reason"] = "concede_match"
	check(MatchRecord.from_dict(line) == null, "a game's own result cannot say concede_match")
