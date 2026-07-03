extends Node


# --- Time ---
signal hour_changed(hour: int)
signal day_started(day: int)
signal day_ended(day: int)
signal season_ended(season: int)
signal ship_jumped(season_name: String)

# --- Farming ---
signal crop_planted(tile_pos: Vector2i, crop_id: String)
signal crop_watered(tile_pos: Vector2i)
signal crop_tended(tile_pos: Vector2i)
signal crop_harvested(tile_pos: Vector2i, crop_id: String, quality: float)

# --- Supply / Directives ---
signal cargo_shipped(items: Dictionary)
signal directive_completed(directive_id: String)

# --- Progression ---
signal milestone_unlocked(milestone_id: String)
signal sub_milestone_unlocked(sub_id: String)
signal module_unlocked(module_id: String)

# --- Story ---
signal story_entry_unlocked(entry_id: String)
signal terminal_opened()
signal terminal_closed()

# --- Crew ---
signal contact_message_received(contact_id: String, message_index: int)
signal crew_relationship_changed(crew_id: String, level: int)
signal comms_opened()
signal comms_closed()

# --- Inventory ---
signal inventory_changed()

# --- Energy ---
signal energy_changed(current: float, max_energy: float)

# --- Tools ---
signal tool_switched(tool_id: String)

# --- UI ---
signal interact_hint_changed(text: String)
signal notification_requested(message: String)

# --- Screen / Scene ---
signal screen_transition_requested(target: String)
