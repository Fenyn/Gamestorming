extends Node


# --- Time ---
signal hour_changed(hour: int)
signal day_started(day: int)
signal day_ended(day: int)
signal season_ended(season: int)

# --- Farming ---
signal crop_planted(tile_pos: Vector2i, crop_id: String)
signal crop_watered(tile_pos: Vector2i)
signal crop_tended(tile_pos: Vector2i)
signal crop_harvested(tile_pos: Vector2i, crop_id: String, quality: float)

# --- Quota / Directives ---
signal food_added(amount: int)
signal cargo_shipped(items: Dictionary)
signal directive_completed(directive_id: String)
signal directive_failed(directive_id: String)

# --- Progression ---
signal milestone_unlocked(milestone_id: String)
signal sub_milestone_unlocked(sub_id: String)
signal module_unlocked(module_id: String)

# --- Automation ---
signal automation_activated(automation_id: String)
signal worm_task_completed(tile_pos: Vector2i, task: String)
signal bee_delivery_completed(from: String, to: String, item_id: String)

# --- Story ---
signal story_entry_unlocked(entry_id: String)
signal terminal_opened()
signal terminal_closed()

# --- Contacts ---
signal contact_message_received(contact_id: String, message_index: int)
signal comms_opened()
signal comms_closed()

# --- Inventory ---
signal inventory_changed()

# --- Tools ---
signal tool_switched(tool_id: String)

# --- UI ---
signal interact_hint_changed(text: String)
signal notification_requested(message: String)

# --- Screen / Scene ---
signal screen_transition_requested(target: String)
