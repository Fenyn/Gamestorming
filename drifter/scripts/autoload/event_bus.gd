extends Node

# Dice
signal dice_rolled()
signal die_settled(cell_index: int, face_value: int)
signal all_dice_settled(values: Array[int])
signal die_socketed(cell_index: int, module_index: int, socket_index: int)

# Modules
signal module_fired(module_index: int, effect_type: int, total_value: int, pip_total: int)

# Rerolls
signal reroll_requested()
signal reroll_used(remaining: int)

# Turn flow
signal player_turn_started()
signal player_turn_ended()
signal creature_turn_started()
signal creature_turn_ended()
signal creature_intent_revealed(intent: IntentData)

# HP / status
signal drifter_hp_changed(current: int, max_val: int)
signal drifter_shield_changed(current: int)
signal creature_hp_changed(creature_index: int, current: int, max_val: int)
signal status_applied(target: String, effect_type: int, stacks: int)
signal status_expired(target: String, effect_type: int)

# Combat result
signal combat_won()
signal combat_lost()
signal salvage_chosen(item_type: String, item_id: String)

# Expedition
signal expedition_started()
signal expedition_node_selected(node_index: int)
signal expedition_completed()

# Screen transitions
signal screen_transition_requested(target_scene: String)

# Camp / meta
signal data_logs_earned(amount: int)
