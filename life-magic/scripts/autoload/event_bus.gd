extends Node

# Beats
signal tick_fired(tick_number: int)

# Heart rate
signal heart_rate_updated(bpm: float, hr_factor: float)
signal heart_rate_source_changed(source: String)
signal heartbeat_fired()

# Currency
signal mana_changed(new_amount: float, delta: float)
signal season_tokens_changed(new_amount: int)

# Generators
signal generator_purchased(tier: int, new_count: float)
signal generator_production_tick(tier: int, produced: float)
signal generator_unlocked(tier: int)

# Sanctum / Sigils
signal plot_unlocked(plot_id: String)
signal plot_seed_planted(plot_id: String, slot_index: int)
signal plot_tend_changed(plot_id: String)
signal plot_growth_tick()
signal plot_full_bloom(plot_id: String, bloom_count: int)

# Special triggers
signal cascade_echo_triggered(tier: int)
signal harmonic_beat_triggered()
signal bloom_burst_triggered(plot_id: String)

# Milestones
signal milestone_earned(milestone_id: String)

# Vitality
signal vitality_changed(new_amount: float)

# Surges
signal surge_opportunity(surge_id: String)
signal surge_completed(surge_id: String)
signal surge_expired(surge_id: String)
signal surge_effect_started(surge_id: String, duration: float)
signal surge_effect_ended(surge_id: String)

# Prestige
signal loop_progress_updated(current: float, required: float)
signal loop_completed(total_loops: int)
signal seasonal_rebirth_executed(tokens_earned: int)
signal blessing_purchased(blessing_id: String, new_level: int)

# Save
signal save_completed()
signal load_completed()

# UI
signal show_panel(panel_name: String)
signal notification(message: String, type: String)
