extends Node

# Time
signal hour_changed(hour: int)
signal day_started(day: int)
signal day_ended(day: int)
signal month_ended(month: int)

# Economy
signal money_changed(new_amount: float, delta: float)
signal item_sold(item_id: String, price: float)
signal item_purchased(item_id: String, price: float)
signal bill_due(amount: float)
signal bill_paid(amount: float)
signal bill_missed(consecutive_misses: int)

# Needs
signal need_changed(need_type: String, value: float)
signal need_critical(need_type: String)
signal player_collapsed()

# Camaro
signal part_installed(part_id: String)
signal camaro_progress_changed(installed: int, total: int)
signal camaro_complete()

# Homestead
signal upgrade_inspected(upgrade_id: String)
signal material_deposited(upgrade_id: String, material_id: String)
signal upgrade_stage_completed(upgrade_id: String, stage: int)
signal upgrade_completed(upgrade_id: String)

# NPC
signal dialogue_started(npc_id: String)
signal dialogue_ended(npc_id: String)
signal friendship_changed(npc_id: String, level: int)

# Items
signal item_picked_up(item: Node3D)
signal item_dropped(item: Node3D)

# Mini-games
signal mini_game_started(game_type: String)
signal mini_game_ended(game_type: String, quality: float)

# Scene transitions
signal scene_transition_requested(target: String)

# Save
signal save_completed()
signal load_completed()
